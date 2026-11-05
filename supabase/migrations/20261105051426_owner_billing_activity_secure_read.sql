-- BARQLO historical migration (schema / function definition; original SQL retained)
-- Source: remote supabase_migrations.schema_migrations (read-only extraction 2026-11-05)
-- Recorded version: 20261105051426
-- Recorded name: owner_billing_activity_secure_read
-- Not standalone: requires the earlier BARQLO database baseline, which is NOT in this repo.
-- Do not run these migrations against the live production database.

create or replace function public.owner_billing_activity(p_tenant_id uuid, p_limit integer default 30)
returns jsonb language plpgsql stable security definer set search_path = ''
as $$
declare result jsonb;
begin
  if auth.uid() is null or not exists (
    select 1 from public.dashboard_members dm
    where dm.user_id=auth.uid() and dm.tenant_id=p_tenant_id and dm.role='owner'
  ) then raise exception 'forbidden' using errcode='42501'; end if;
  if p_limit is null or p_limit < 1 or p_limit > 50 then raise exception 'invalid limit'; end if;
  select jsonb_build_object(
    'ledger', coalesce((
      select jsonb_agg(jsonb_build_object('id',l.id,'kind',l.kind,'amount',l.amount,'currency',l.currency,'reason',l.reason,'created_at',l.created_at) order by l.created_at desc,l.id desc)
      from (select id,kind,amount,currency,reason,created_at from public.balance_ledger where tenant_id=p_tenant_id order by created_at desc,id desc limit p_limit) l
    ),'[]'::jsonb),
    'usage', coalesce((
      select jsonb_agg(jsonb_build_object('id',u.id,'model',u.model,'cost_usd',u.cost_usd,'created_at',u.created_at) order by u.created_at desc,u.id desc)
      from (select id,model,cost_usd,created_at from public.usage_events where tenant_id=p_tenant_id order by created_at desc,id desc limit p_limit) u
    ),'[]'::jsonb)
  ) into result;
  return result;
end; $$;
revoke all on function public.owner_billing_activity(uuid,integer) from public,anon;
grant execute on function public.owner_billing_activity(uuid,integer) to authenticated;
