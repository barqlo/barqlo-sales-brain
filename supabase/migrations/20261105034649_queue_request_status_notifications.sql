-- BARQLO historical migration (schema / function definition; original SQL retained)
-- Source: remote supabase_migrations.schema_migrations (read-only extraction 2026-11-05)
-- Recorded version: 20261105034649
-- Recorded name: queue_request_status_notifications
-- Not standalone: requires the earlier BARQLO database baseline, which is NOT in this repo.
-- Do not run these migrations against the live production database.

create or replace function public.queue_request_status_notification() returns trigger language plpgsql security definer set search_path = '' as $$ begin if new.status is distinct from old.status and new.status in ('confirmed','completed','cancelled') then insert into public.request_notifications (tenant_id,request_id,event_status) values (new.tenant_id,new.id,new.status) on conflict (request_id,event_status) do nothing; end if; return new; end; $$; revoke all on function public.queue_request_status_notification() from public, anon, authenticated; drop trigger if exists trg_queue_request_status_notification on public.customer_requests; create trigger trg_queue_request_status_notification after update of status on public.customer_requests for each row execute function public.queue_request_status_notification();
