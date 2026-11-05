-- BARQLO historical migration (schema / function definition; original SQL retained)
-- Source: remote supabase_migrations.schema_migrations (read-only extraction 2026-11-05)
-- Recorded version: 20261104040213
-- Recorded name: per_channel_adapter_auth_secret
-- Not standalone: requires the earlier BARQLO database baseline, which is NOT in this repo.
-- Do not run these migrations against the live production database.

alter table public.channels add column if not exists adapter_secret text not null default encode(gen_random_bytes(32),'hex');
alter table public.channels add constraint channels_adapter_secret_length_check check (length(adapter_secret) = 64);
comment on column public.channels.adapter_secret is 'Per-channel internal adapter-to-brain authentication secret; never expose to customer-facing payloads.';
