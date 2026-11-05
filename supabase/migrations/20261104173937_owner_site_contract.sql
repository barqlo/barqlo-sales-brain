-- BARQLO historical migration (schema / function definition; original SQL retained)
-- Source: remote supabase_migrations.schema_migrations (read-only extraction 2026-11-05)
-- Recorded version: 20261104173937
-- Recorded name: owner_site_contract
-- Not standalone: requires the earlier BARQLO database baseline, which is NOT in this repo.
-- Do not run these migrations against the live production database.

-- BARQLO owner site data contract. No credentials or channel secrets are exposed.
begin;

create or replace function public.owner_can_manage(p_tenant_id uuid)
returns boolean language sql stable security definer set search_path = ''
as $$
  select auth.uid() is not null and exists (
    select 1 from public.dashboard_members dm
    where dm.user_id = auth.uid()
      and dm.tenant_id = p_tenant_id
      and dm.role = 'owner'
  );
$$;
revoke all on function public.owner_can_manage(uuid) from public, anon;
grant execute on function public.owner_can_manage(uuid) to authenticated;

create or replace function public.owner_available_sectors()
returns table(code text, name_ar text, name_en text)
language sql stable security definer set search_path = ''
as $$
  select s.code, s.name_ar, s.name_en
  from public.sectors s
  where s.is_active
    and exists (select 1 from public.sector_packs p
                where p.sector_code = s.code and p.is_active)
  order by s.name_ar;
$$;
revoke all on function public.owner_available_sectors() from public;
grant execute on function public.owner_available_sectors() to anon, authenticated;

create or replace function public.owner_register_business(
  p_business_name text, p_sector_code text, p_slug text, p_market_code text default 'EG'
) returns uuid language plpgsql security definer set search_path = ''
as $$
declare
  v_user uuid := auth.uid();
  v_tenant uuid;
  v_market text := upper(coalesce(p_market_code, 'EG'));
  v_slug text := lower(btrim(coalesce(p_slug, '')));
begin
  if v_user is null or not exists (
    select 1 from auth.users u
    where u.id = v_user and u.email_confirmed_at is not null
      and (u.banned_until is null or u.banned_until < now())
  ) then raise exception 'verified_login_required'; end if;
  if char_length(btrim(coalesce(p_business_name, ''))) not between 2 and 160
    then raise exception 'invalid_business_name'; end if;
  if v_slug !~ '^[a-z0-9][a-z0-9-]{2,62}$'
    then raise exception 'invalid_slug'; end if;
  if v_market not in ('EG', 'SA') then raise exception 'invalid_market'; end if;
  if not exists (
    select 1 from public.sectors s
    join public.sector_packs p on p.sector_code = s.code and p.is_active
    where s.code = p_sector_code and s.is_active
  ) then raise exception 'sector_not_ready'; end if;

  insert into public.tenants
    (business_name, sector_code, slug, status, data_mode, market_code, currency_code)
  values
    (btrim(p_business_name), p_sector_code, v_slug, 'trial', 'real',
     v_market, case when v_market = 'EG' then 'EGP' else 'SAR' end)
  returning id into v_tenant;
  insert into public.dashboard_members
    (user_id, tenant_id, role, permissions)
  values
    (v_user, v_tenant, 'owner',
     '["ops_fields.edit","replies.view","reports.view","instructions.propose"]'::jsonb);
  insert into public.tenant_pack_settings (tenant_id, pack_update_mode)
    values (v_tenant, 'auto');
  insert into public.tenant_voice_settings (tenant_id, dialect, tone, formality)
    values (v_tenant, case when v_market = 'EG' then 'مصري' else 'خليجي' end,
            'neutral', 'neutral');
  insert into public.tenant_profiles (tenant_id) values (v_tenant);
  insert into public.admin_audit
    (tenant_id, action, target, details, actor_id, actor_type)
  values
    (v_tenant, 'tenant_self_signup', v_tenant::text,
     jsonb_build_object('sector_code', p_sector_code, 'market_code', v_market),
     v_user, 'owner');
  return v_tenant;
end;
$$;
revoke all on function public.owner_register_business(text,text,text,text) from public, anon;
grant execute on function public.owner_register_business(text,text,text,text) to authenticated;

create or replace function public.owner_channel_summary(p_tenant_id uuid)
returns jsonb language plpgsql stable security definer set search_path = ''
as $$
declare v_result jsonb;
begin
  if not public.owner_can_manage(p_tenant_id) then raise exception 'forbidden'; end if;
  select coalesce(jsonb_agg(jsonb_build_object(
    'id', c.id, 'channel_type', c.channel_type, 'provider', c.provider,
    'external_id', c.external_id, 'active', c.active
  ) order by c.channel_type, c.id), '[]'::jsonb)
  into v_result from public.channels c where c.tenant_id = p_tenant_id;
  return v_result;
end;
$$;
revoke all on function public.owner_channel_summary(uuid) from public, anon;
grant execute on function public.owner_channel_summary(uuid) to authenticated;

create or replace function public.enforce_catalog_sector()
returns trigger language plpgsql security invoker set search_path = ''
as $$
declare v_sector text;
begin
  select t.sector_code into v_sector from public.tenants t where t.id = new.tenant_id;
  if v_sector is null or new.sector_code is distinct from v_sector
    then raise exception 'catalog_sector_mismatch'; end if;
  if char_length(btrim(new.name)) not between 2 and 200
    then raise exception 'invalid_catalog_name'; end if;
  return new;
end;
$$;
revoke all on function public.enforce_catalog_sector() from public, anon, authenticated;
create trigger trg_items_sector_guard before insert or update of tenant_id, sector_code, name
  on public.items for each row execute function public.enforce_catalog_sector();
create trigger trg_projects_sector_guard before insert or update of tenant_id, sector_code, name
  on public.projects for each row execute function public.enforce_catalog_sector();
alter table public.items add constraint items_nonnegative_price check (price is null or price >= 0);

create or replace function public.audit_owner_site_change()
returns trigger language plpgsql security definer set search_path = ''
as $$
declare v_row jsonb := to_jsonb(new);
begin
  if auth.uid() is not null then
    insert into public.admin_audit
      (tenant_id, action, target, details, actor_id, actor_type)
    values
      ((v_row->>'tenant_id')::uuid,
       'owner_site_' || tg_op,
       coalesce(v_row->>'id', v_row->>'tenant_id'),
       jsonb_build_object('table', tg_table_name, 'operation', tg_op),
       auth.uid(), 'owner');
  end if;
  return new;
end;
$$;
revoke all on function public.audit_owner_site_change() from public, anon, authenticated;
create trigger trg_items_owner_site_audit after insert or update
  on public.items for each row execute function public.audit_owner_site_change();
create trigger trg_projects_owner_site_audit after insert or update
  on public.projects for each row execute function public.audit_owner_site_change();
create trigger trg_voice_owner_site_audit after insert or update
  on public.tenant_voice_settings for each row execute function public.audit_owner_site_change();
create trigger trg_profile_owner_site_audit after insert or update
  on public.tenant_profiles for each row execute function public.audit_owner_site_change();

grant select on public.dashboard_members to authenticated;
grant select on public.tenants, public.items, public.projects,
  public.policies, public.tenant_voice_settings, public.tenant_profiles,
  public.tenant_pack_settings, public.tenant_services to authenticated;
grant update (business_name) on public.tenants to authenticated;
grant insert (tenant_id, project_id, sector_code, name, kind, price, currency,
  area, status, attributes, data_origin, is_active) on public.items to authenticated;
grant update (project_id, name, kind, price, area, status, attributes,
  data_origin, is_active) on public.items to authenticated;
grant insert (tenant_id, sector_code, name, area, city, status, attributes,
  data_origin, is_active) on public.projects to authenticated;
grant update (name, area, city, status, attributes, data_origin, is_active)
  on public.projects to authenticated;
grant insert (tenant_id, dialect, tone, formality, greeting_style,
  preferred_words, avoided_words, voice_notes)
  on public.tenant_voice_settings to authenticated;
grant update (dialect, tone, formality, greeting_style,
  preferred_words, avoided_words, voice_notes)
  on public.tenant_voice_settings to authenticated;
grant insert (tenant_id, selling_preferences, owner_notes, previous_decisions)
  on public.tenant_profiles to authenticated;
grant update (selling_preferences, owner_notes, previous_decisions)
  on public.tenant_profiles to authenticated;

create policy tenants_owner_read on public.tenants for select to authenticated
  using (public.owner_can_manage(id));
create policy tenants_owner_update on public.tenants for update to authenticated
  using (public.owner_can_manage(id)) with check (public.owner_can_manage(id));
create policy items_owner_read on public.items for select to authenticated
  using (public.owner_can_manage(tenant_id));
create policy items_owner_insert on public.items for insert to authenticated
  with check (public.owner_can_manage(tenant_id));
create policy items_owner_update on public.items for update to authenticated
  using (public.owner_can_manage(tenant_id))
  with check (public.owner_can_manage(tenant_id));
create policy projects_owner_read on public.projects for select to authenticated
  using (public.owner_can_manage(tenant_id));
create policy projects_owner_insert on public.projects for insert to authenticated
  with check (public.owner_can_manage(tenant_id));
create policy projects_owner_update on public.projects for update to authenticated
  using (public.owner_can_manage(tenant_id))
  with check (public.owner_can_manage(tenant_id));
create policy policies_owner_read on public.policies for select to authenticated
  using (public.owner_can_manage(tenant_id));
create policy voice_owner_read on public.tenant_voice_settings for select to authenticated
  using (public.owner_can_manage(tenant_id));
create policy voice_owner_insert on public.tenant_voice_settings for insert to authenticated
  with check (public.owner_can_manage(tenant_id));
create policy voice_owner_update on public.tenant_voice_settings for update to authenticated
  using (public.owner_can_manage(tenant_id))
  with check (public.owner_can_manage(tenant_id));
create policy profile_owner_read on public.tenant_profiles for select to authenticated
  using (public.owner_can_manage(tenant_id));
create policy profile_owner_insert on public.tenant_profiles for insert to authenticated
  with check (public.owner_can_manage(tenant_id));
create policy profile_owner_update on public.tenant_profiles for update to authenticated
  using (public.owner_can_manage(tenant_id))
  with check (public.owner_can_manage(tenant_id));
create policy pack_owner_read on public.tenant_pack_settings for select to authenticated
  using (public.owner_can_manage(tenant_id));
create policy services_owner_read on public.tenant_services for select to authenticated
  using (public.owner_can_manage(tenant_id));

commit;
