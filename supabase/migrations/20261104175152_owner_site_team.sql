-- BARQLO historical migration (schema / function definition; original SQL retained)
-- Source: remote supabase_migrations.schema_migrations (read-only extraction 2026-11-05)
-- Recorded version: 20261104175152
-- Recorded name: owner_site_team
-- Not standalone: requires the earlier BARQLO database baseline, which is NOT in this repo.
-- Do not run these migrations against the live production database.

-- Team membership for existing, confirmed Auth accounts. Email invitation
-- and staff-facing data routes are separate site/server work.
begin;

create or replace function public.owner_team_list(p_tenant_id uuid)
returns table(user_id uuid, email text, role text, permissions jsonb, created_at timestamptz)
language plpgsql security definer set search_path = '' as $$
begin
  if not public.owner_can_manage(p_tenant_id) then raise exception 'forbidden'; end if;
  return query select dm.user_id, u.email::text, dm.role, dm.permissions, dm.created_at
    from public.dashboard_members dm join auth.users u on u.id=dm.user_id
    where dm.tenant_id=p_tenant_id order by dm.created_at, dm.user_id;
end; $$;

create or replace function public.owner_team_add_existing(
  p_tenant_id uuid, p_email text, p_role text, p_permissions jsonb default '[]'::jsonb
) returns jsonb language plpgsql security definer set search_path = '' as $$
declare v_user auth.users%rowtype; v_permission text; v_allowed text[];
begin
  if not public.owner_can_manage(p_tenant_id) then raise exception 'forbidden'; end if;
  if p_email is null or length(p_email)>320 or p_role not in ('staff','viewer')
     or p_permissions is null or jsonb_typeof(p_permissions)<>'array'
     or jsonb_array_length(p_permissions)>4 then raise exception 'invalid_team_member'; end if;
  if p_role='staff' then
    v_allowed:=array['ops_fields.edit','replies.view','reports.view','instructions.propose'];
  else
    v_allowed:=array['replies.view','reports.view'];
  end if;
  for v_permission in select jsonb_array_elements_text(p_permissions) loop
    if not v_permission=any(v_allowed) then raise exception 'invalid_permission'; end if;
  end loop;
  select * into v_user from auth.users u where lower(u.email)=lower(trim(p_email)) limit 1;
  if not found or v_user.email_confirmed_at is null or v_user.banned_until>now()
    then raise exception 'confirmed_account_required'; end if;
  if v_user.id=auth.uid() or exists
    (select 1 from public.platform_admins pa where pa.user_id=v_user.id)
    then raise exception 'invalid_team_member'; end if;
  if exists (select 1 from public.dashboard_members dm
             where dm.user_id=v_user.id and dm.tenant_id=p_tenant_id and dm.role='owner')
    then raise exception 'cannot_change_owner'; end if;
  insert into public.dashboard_members(user_id,tenant_id,role,permissions,granted_by)
    values(v_user.id,p_tenant_id,p_role,p_permissions,auth.uid())
    on conflict(user_id,tenant_id) do update
      set role=excluded.role, permissions=excluded.permissions, granted_by=auth.uid();
  insert into public.admin_audit(tenant_id,action,target,details,actor_id,actor_type)
    values(p_tenant_id,'owner_team_upsert',v_user.id::text,
           jsonb_build_object('role',p_role,'permissions',p_permissions),auth.uid(),'owner');
  return jsonb_build_object('user_id',v_user.id,'email',v_user.email,
                            'role',p_role,'permissions',p_permissions);
end; $$;

create or replace function public.owner_team_remove(p_tenant_id uuid,p_user_id uuid)
returns boolean language plpgsql security definer set search_path = '' as $$
declare v_removed boolean;
begin
  if not public.owner_can_manage(p_tenant_id) then raise exception 'forbidden'; end if;
  delete from public.dashboard_members dm where dm.tenant_id=p_tenant_id
    and dm.user_id=p_user_id and dm.role in ('staff','viewer');
  v_removed:=found;
  if v_removed then
    insert into public.admin_audit(tenant_id,action,target,details,actor_id,actor_type)
      values(p_tenant_id,'owner_team_remove',p_user_id::text,'{}'::jsonb,auth.uid(),'owner');
  end if;
  return v_removed;
end; $$;

revoke all on function public.owner_team_list(uuid) from public,anon;
revoke all on function public.owner_team_add_existing(uuid,text,text,jsonb) from public,anon;
revoke all on function public.owner_team_remove(uuid,uuid) from public,anon;
grant execute on function public.owner_team_list(uuid) to authenticated;
grant execute on function public.owner_team_add_existing(uuid,text,text,jsonb) to authenticated;
grant execute on function public.owner_team_remove(uuid,uuid) to authenticated;
commit;
