-- BARQLO historical migration (schema / function definition; original SQL retained)
-- Source: remote supabase_migrations.schema_migrations (read-only extraction 2026-11-05)
-- Recorded version: 20261105040757
-- Recorded name: dispatch_request_status_notifications
-- Not standalone: requires the earlier BARQLO database baseline, which is NOT in this repo.
-- Do not run these migrations against the live production database.

create schema if not exists private;
revoke all on schema private from public, anon, authenticated;
alter table public.request_notifications
  add column if not exists dispatch_attempts integer not null default 0;
create or replace function private.dispatch_request_notification(p_id uuid)
returns bigint language plpgsql security definer set search_path = ''
as $$
declare
  v_id uuid;
  v_tenant uuid;
  v_secret text;
  v_http_id bigint;
begin
  update public.request_notifications rn
     set last_dispatch_at = now(),
         dispatch_attempts = rn.dispatch_attempts + 1
    from public.customer_requests cr,
         public.conversations cv,
         public.channels ch
   where rn.id = p_id
     and rn.delivery_status = 'pending'
     and rn.dispatch_attempts < 5
     and (rn.last_dispatch_at is null or rn.last_dispatch_at < now() - interval '1 minute')
     and cr.id = rn.request_id and cr.tenant_id = rn.tenant_id
     and cr.status = rn.event_status
     and cv.id = cr.conversation_id and cv.tenant_id = rn.tenant_id
     and cv.channel = 'telegram'
     and ch.tenant_id = rn.tenant_id and ch.provider = 'telegram'
     and ch.active = true and ch.adapter_secret is not null
     and (select count(*) from public.channels c
           where c.tenant_id = rn.tenant_id and c.provider = 'telegram' and c.active = true) = 1
     and exists (select 1 from public.customer_identities ci
                  where ci.tenant_id = rn.tenant_id and ci.customer_id = cr.customer_id
                    and ci.provider = 'telegram')
   returning rn.id, rn.tenant_id, ch.adapter_secret into v_id, v_tenant, v_secret;
  if v_id is null then return null; end if;
  select net.http_post(
    url := 'https://barql0.app.n8n.cloud/webhook/barqlo-request-status-v1-8c7de7fd',
    body := jsonb_build_object('notification_id', v_id, 'tenant_id', v_tenant, 'secret', v_secret),
    headers := '{"Content-Type":"application/json"}'::jsonb
  ) into v_http_id;
  return v_http_id;
end;
$$;
revoke all on function private.dispatch_request_notification(uuid) from public, anon, authenticated;
create or replace function private.request_notification_insert_dispatch()
returns trigger language plpgsql security definer set search_path = ''
as $$
begin
  perform private.dispatch_request_notification(new.id);
  return new;
end;
$$;
revoke all on function private.request_notification_insert_dispatch() from public, anon, authenticated;
drop trigger if exists trg_request_notification_dispatch on public.request_notifications;
create trigger trg_request_notification_dispatch
after insert on public.request_notifications
for each row execute function private.request_notification_insert_dispatch();
create or replace function private.retry_request_notifications()
returns void language plpgsql security definer set search_path = ''
as $$
declare v_id uuid;
begin
  update public.request_notifications rn
     set delivery_status = 'failed',
         last_error = 'Send result uncertain; manual review required'
   where rn.delivery_status = 'sending'
     and rn.lease_until < now();
  update public.request_notifications rn
     set delivery_status = 'failed',
         last_error = 'Request status changed before dispatch'
    from public.customer_requests cr
   where rn.delivery_status = 'pending'
     and rn.request_id = cr.id and cr.tenant_id = rn.tenant_id
     and cr.status <> rn.event_status;
  update public.request_notifications rn
     set delivery_status = 'failed',
         last_error = 'Webhook dispatch did not claim after five attempts'
   where rn.delivery_status = 'pending'
     and rn.dispatch_attempts >= 5
     and rn.last_dispatch_at < now() - interval '1 minute';
  for v_id in
    select rn.id from public.request_notifications rn
    where rn.delivery_status = 'pending'
      and rn.dispatch_attempts < 5
      and (rn.last_dispatch_at is null or rn.last_dispatch_at < now() - interval '1 minute')
    order by rn.created_at limit 50
  loop
    perform private.dispatch_request_notification(v_id);
  end loop;
end;
$$;
revoke all on function private.retry_request_notifications() from public, anon, authenticated;
select cron.schedule('barqlo-request-notifications', '* * * * *', 'select private.retry_request_notifications();');
