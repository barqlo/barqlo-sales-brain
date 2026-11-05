-- BARQLO historical migration (schema / function definition; original SQL retained)
-- Source: remote supabase_migrations.schema_migrations (read-only extraction 2026-11-05)
-- Recorded version: 20261104174541
-- Recorded name: owner_site_contract_services_instructions
-- Not standalone: requires the earlier BARQLO database baseline, which is NOT in this repo.
-- Do not run these migrations against the live production database.

-- New tenants get explicit inactive services; owners may propose guarded instructions.
begin;

create or replace function public.seed_tenant_services()
returns trigger language plpgsql security definer set search_path = ''
as $$
begin
  insert into public.tenant_services(tenant_id, service_code, is_active, config)
    select new.id, s.code, false, '{}'::jsonb
    from public.services s where s.is_active
    on conflict (tenant_id, service_code) do nothing;
  return new;
end;
$$;
revoke all on function public.seed_tenant_services() from public, anon, authenticated;
create trigger trg_seed_tenant_services after insert on public.tenants
  for each row execute function public.seed_tenant_services();

alter function public.log_custom_instructions_change() security definer;
alter function public.log_custom_instructions_change() set search_path = '';
revoke all on function public.log_custom_instructions_change() from public, anon, authenticated;

alter table public.tenant_custom_instructions
  drop constraint tenant_custom_instructions_applies_to_sector_check;
alter table public.tenant_custom_instructions
  add constraint tenant_custom_instructions_sector_fkey
  foreign key (applies_to_sector) references public.sectors(code);

create or replace function public.enforce_instruction_sector()
returns trigger language plpgsql security invoker set search_path = ''
as $$
declare v_sector text;
begin
  if new.applies_to_sector is null then return new; end if;
  select t.sector_code into v_sector from public.tenants t where t.id = new.tenant_id;
  if new.applies_to_sector is distinct from v_sector
    then raise exception 'instruction_sector_mismatch'; end if;
  return new;
end;
$$;
revoke all on function public.enforce_instruction_sector() from public, anon, authenticated;
create trigger trg_instruction_sector_guard
  before insert or update of tenant_id, applies_to_sector
  on public.tenant_custom_instructions
  for each row execute function public.enforce_instruction_sector();

grant select on public.tenant_custom_instructions to authenticated;
grant insert (tenant_id, instruction_text, category, priority,
  applies_to_sector, bound_key, bound_value, bound_operator)
  on public.tenant_custom_instructions to authenticated;
grant update (instruction_text, category, priority, applies_to_sector,
  bound_key, bound_value, bound_operator, is_active)
  on public.tenant_custom_instructions to authenticated;
create policy instructions_owner_read on public.tenant_custom_instructions
  for select to authenticated using (public.owner_can_manage(tenant_id));
create policy instructions_owner_insert on public.tenant_custom_instructions
  for insert to authenticated with check (public.owner_can_manage(tenant_id));
create policy instructions_owner_update on public.tenant_custom_instructions
  for update to authenticated using (public.owner_can_manage(tenant_id))
  with check (public.owner_can_manage(tenant_id));

commit;
