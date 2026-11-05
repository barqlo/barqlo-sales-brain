-- BARQLO historical migration (schema / function definition; original SQL retained)
-- Source: remote supabase_migrations.schema_migrations (read-only extraction 2026-11-05)
-- Recorded version: 20261104174924
-- Recorded name: owner_site_policy_registry_definer
-- Not standalone: requires the earlier BARQLO database baseline, which is NOT in this repo.
-- Do not run these migrations against the live production database.

-- The registry trigger reads admin membership while preserving auth.uid().
-- SECURITY DEFINER lets it inspect that table without granting owners access.
begin;
create or replace function public.enforce_owner_policy_registry()
returns trigger language plpgsql security definer set search_path = ''
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
commit;
