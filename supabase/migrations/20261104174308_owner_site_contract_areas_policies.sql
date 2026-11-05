-- BARQLO historical migration (schema / function definition; original SQL retained)
-- Source: remote supabase_migrations.schema_migrations (read-only extraction 2026-11-05)
-- Recorded version: 20261104174308
-- Recorded name: owner_site_contract_areas_policies
-- Not standalone: requires the earlier BARQLO database baseline, which is NOT in this repo.
-- Do not run these migrations against the live production database.

-- Extend the owner contract to location data and validated business policies.
begin;

create or replace function public.audit_owner_site_change()
returns trigger language plpgsql security definer set search_path = ''
as $$
declare
  v_row jsonb := to_jsonb(new);
  v_tenant uuid;
begin
  if auth.uid() is null then return new; end if;
  if tg_table_name = 'area_places' then
    select a.tenant_id into v_tenant
      from public.areas a where a.id = (v_row->>'area_id')::uuid;
  else
    v_tenant := coalesce(v_row->>'tenant_id', v_row->>'id')::uuid;
  end if;
  insert into public.admin_audit
    (tenant_id, action, target, details, actor_id, actor_type)
  values
    (v_tenant, 'owner_site_' || tg_op,
     coalesce(v_row->>'id', v_row->>'tenant_id'),
     jsonb_build_object('table', tg_table_name, 'operation', tg_op),
     auth.uid(), 'owner');
  return new;
end;
$$;
revoke all on function public.audit_owner_site_change() from public, anon, authenticated;
create trigger trg_tenants_owner_site_audit after update of business_name
  on public.tenants for each row execute function public.audit_owner_site_change();

alter table public.areas add constraint areas_lat_range
  check (lat is null or lat between -90 and 90);
alter table public.areas add constraint areas_lng_range
  check (lng is null or lng between -180 and 180);
alter table public.area_places add constraint area_places_distance_nonnegative
  check (distance_km >= 0 and minutes >= 0);
create trigger trg_areas_tenant_lock before update on public.areas
  for each row execute function public.prevent_tenant_change();
create trigger trg_areas_owner_site_audit after insert or update on public.areas
  for each row execute function public.audit_owner_site_change();
create trigger trg_area_places_owner_site_audit after insert or update on public.area_places
  for each row execute function public.audit_owner_site_change();

grant select on public.areas, public.area_places to authenticated;
grant insert (tenant_id, city, district, tagline, description, lifestyle,
  best_for, noise_level, greenery, traffic_note, pros, cons, planned_dev,
  lat, lng, data_origin, is_active) on public.areas to authenticated;
grant update (city, district, tagline, description, lifestyle, best_for,
  noise_level, greenery, traffic_note, pros, cons, planned_dev, lat, lng,
  data_origin, is_active) on public.areas to authenticated;
grant insert (area_id, place_type, name, distance_km, minutes, data_origin,
  is_active) on public.area_places to authenticated;
grant update (place_type, name, distance_km, minutes, data_origin, is_active)
  on public.area_places to authenticated;
create policy areas_owner_read on public.areas for select to authenticated
  using (public.owner_can_manage(tenant_id));
create policy areas_owner_insert on public.areas for insert to authenticated
  with check (public.owner_can_manage(tenant_id));
create policy areas_owner_update on public.areas for update to authenticated
  using (public.owner_can_manage(tenant_id))
  with check (public.owner_can_manage(tenant_id));
create policy area_places_owner_read on public.area_places for select to authenticated
  using (exists (select 1 from public.areas a
                 where a.id = area_id and public.owner_can_manage(a.tenant_id)));
create policy area_places_owner_insert on public.area_places for insert to authenticated
  with check (exists (select 1 from public.areas a
                      where a.id = area_id and public.owner_can_manage(a.tenant_id)));
create policy area_places_owner_update on public.area_places for update to authenticated
  using (exists (select 1 from public.areas a
                 where a.id = area_id and public.owner_can_manage(a.tenant_id)))
  with check (exists (select 1 from public.areas a
                      where a.id = area_id and public.owner_can_manage(a.tenant_id)));

create or replace function public.validate_policy_payload()
returns trigger language plpgsql security invoker set search_path = ''
as $$
declare v_number numeric;
begin
  if length(new.policy_value::text) > 8000 then
    raise exception 'policy_value_too_large';
  end if;
  if new.policy_key in ('booking_fee','max_discount_pct','cash_discount_pct',
                        'min_down_payment_pct','max_installments') then
    if jsonb_typeof(new.policy_value) <> 'object'
       or jsonb_typeof(new.policy_value->'value') <> 'number'
      then raise exception 'invalid_numeric_policy'; end if;
    v_number := (new.policy_value->>'value')::numeric;
    if new.policy_key = 'booking_fee' and (v_number < 0 or v_number > 10000000)
      then raise exception 'invalid_booking_fee'; end if;
    if new.policy_key in ('max_discount_pct','cash_discount_pct',
                          'min_down_payment_pct')
       and (v_number < 0 or v_number > 100)
      then raise exception 'invalid_percentage_policy'; end if;
    if new.policy_key = 'max_installments'
       and (v_number < 0 or v_number > 600 or v_number <> trunc(v_number))
      then raise exception 'invalid_installments_policy'; end if;
  end if;
  if new.policy_key = 'bot_may_diagnose' and new.policy_value <> 'false'::jsonb
    then raise exception 'bot_diagnosis_forbidden'; end if;
  return new;
end;
$$;
revoke all on function public.validate_policy_payload() from public, anon, authenticated;
create trigger trg_validate_policy_payload
  before insert or update of policy_key, policy_value on public.policies
  for each row execute function public.validate_policy_payload();

create or replace function public.owner_set_policy(
  p_tenant_id uuid, p_key text, p_value jsonb
) returns jsonb language plpgsql security definer set search_path = ''
as $$
declare v_policy public.policies%rowtype;
begin
  if not public.owner_can_manage(p_tenant_id) then raise exception 'forbidden'; end if;
  if p_key is null or p_key !~ '^[a-z][a-z0-9_-]{0,79}$'
    then raise exception 'invalid_policy_key'; end if;
  if p_value is null then raise exception 'invalid_policy_value'; end if;
  insert into public.policies(tenant_id, policy_key, policy_value, is_active)
    values (p_tenant_id, p_key, p_value, true)
    on conflict (tenant_id, policy_key) do update
      set policy_value = excluded.policy_value, is_active = true, updated_at = now()
    returning * into v_policy;
  insert into public.admin_audit
    (tenant_id, action, target, details, actor_id, actor_type)
    values (p_tenant_id, 'owner_policy_update', p_key,
            jsonb_build_object('policy_key', p_key), auth.uid(), 'owner');
  return jsonb_build_object('id', v_policy.id, 'tenant_id', v_policy.tenant_id,
    'policy_key', v_policy.policy_key, 'policy_value', v_policy.policy_value,
    'is_active', v_policy.is_active);
end;
$$;
revoke all on function public.owner_set_policy(uuid,text,jsonb) from public, anon;
grant execute on function public.owner_set_policy(uuid,text,jsonb) to authenticated;

commit;
