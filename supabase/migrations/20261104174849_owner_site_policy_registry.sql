-- BARQLO historical migration (schema / function definition; original SQL retained)
-- Source: remote supabase_migrations.schema_migrations (read-only extraction 2026-11-05)
-- Recorded version: 20261104174849
-- Recorded name: owner_site_policy_registry
-- Not standalone: requires the earlier BARQLO database baseline, which is NOT in this repo.
-- Do not run these migrations against the live production database.

-- Admin-maintained policy vocabulary. New sectors add rows, not new owner code.
begin;

create table public.sector_policy_fields (
  sector_code text not null references public.sectors(code),
  policy_key text not null,
  value_type text not null check (value_type in ('string','number','boolean','object','array')),
  owner_editable boolean not null default true,
  created_at timestamptz not null default now(),
  primary key (sector_code, policy_key)
);
alter table public.sector_policy_fields enable row level security;
grant select on public.sector_policy_fields to authenticated;
create policy sector_policy_fields_read on public.sector_policy_fields
  for select to authenticated using (true);

insert into public.sector_policy_fields(sector_code, policy_key, value_type)
select t.sector_code, p.policy_key,
       case when p.policy_key in ('booking_fee','max_discount_pct',
                                  'cash_discount_pct','min_down_payment_pct',
                                  'max_installments') then 'object'
            else min(jsonb_typeof(p.policy_value)) end
from public.policies p
join public.tenants t on t.id = p.tenant_id
group by t.sector_code, p.policy_key;

create or replace function public.enforce_owner_policy_registry()
returns trigger language plpgsql security invoker set search_path = ''
as $$
begin
  if auth.uid() is null or exists (
    select 1 from public.platform_admins pa where pa.user_id = auth.uid()
  ) then return new; end if;
  if not exists (
    select 1 from public.sector_policy_fields f
    join public.tenants t on t.sector_code = f.sector_code
    where t.id = new.tenant_id
      and f.policy_key = new.policy_key
      and f.owner_editable
      and f.value_type = jsonb_typeof(new.policy_value)
  ) then raise exception 'policy_field_not_allowed'; end if;
  return new;
end;
$$;
revoke all on function public.enforce_owner_policy_registry() from public, anon, authenticated;
create trigger trg_owner_policy_registry
  before insert or update of tenant_id, policy_key, policy_value
  on public.policies for each row execute function public.enforce_owner_policy_registry();

commit;
