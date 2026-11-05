-- BARQLO historical migration (schema / function definition; original SQL retained)
-- Source: remote supabase_migrations.schema_migrations (read-only extraction 2026-11-05)
-- Recorded version: 20261105041211
-- Recorded name: owner_billing_summary_readonly
-- Not standalone: requires the earlier BARQLO database baseline, which is NOT in this repo.
-- Do not run these migrations against the live production database.

create or replace function public.owner_billing_summary(p_tenant_id uuid)
returns jsonb language plpgsql stable security definer set search_path = ''
as $$
declare v_result jsonb;
begin
  if auth.uid() is null or not exists (
    select 1 from public.dashboard_members dm
    where dm.user_id=auth.uid() and dm.tenant_id=p_tenant_id and dm.role='owner'
  ) then raise exception 'forbidden'; end if;
  select jsonb_build_object(
    'currency',t.currency_code,
    'balance',coalesce((select sum(case when l.kind='credit' then l.amount when l.kind='debit' then -l.amount else 0 end) from public.balance_ledger l where l.tenant_id=p_tenant_id and l.currency=t.currency_code),0),
    'credits',coalesce((select sum(l.amount) from public.balance_ledger l where l.tenant_id=p_tenant_id and l.kind='credit' and l.currency=t.currency_code),0),
    'debits',coalesce((select sum(l.amount) from public.balance_ledger l where l.tenant_id=p_tenant_id and l.kind='debit' and l.currency=t.currency_code),0),
    'usage_events',coalesce((select count(*) from public.usage_events u where u.tenant_id=p_tenant_id),0),
    'usage_cost_usd',coalesce((select sum(u.cost_usd) from public.usage_events u where u.tenant_id=p_tenant_id),0),
    'last_usage_at',(select max(u.created_at) from public.usage_events u where u.tenant_id=p_tenant_id),
    'billing_active',false
  ) into v_result from public.tenants t where t.id=p_tenant_id;
  if v_result is null then raise exception 'tenant not found'; end if;
  return v_result;
end;
$$;
revoke all on function public.owner_billing_summary(uuid) from public, anon, authenticated;
grant execute on function public.owner_billing_summary(uuid) to authenticated;
