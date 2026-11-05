-- BARQLO historical migration (schema / function definition; original SQL retained)
-- Source: remote supabase_migrations.schema_migrations (read-only extraction 2026-11-05)
-- Recorded version: 20261104035644
-- Recorded name: active_channel_global_uniqueness_guard
-- Not standalone: requires the earlier BARQLO database baseline, which is NOT in this repo.
-- Do not run these migrations against the live production database.

create unique index if not exists channels_one_active_tenant_per_external_identity on public.channels (provider, external_id) where active = true;
