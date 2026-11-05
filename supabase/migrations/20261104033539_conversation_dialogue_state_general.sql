-- BARQLO historical migration (schema / function definition; original SQL retained)
-- Source: remote supabase_migrations.schema_migrations (read-only extraction 2026-11-05)
-- Recorded version: 20261104033539
-- Recorded name: conversation_dialogue_state_general
-- Not standalone: requires the earlier BARQLO database baseline, which is NOT in this repo.
-- Do not run these migrations against the live production database.

alter table public.conversation_state add column if not exists dialogue_state jsonb not null default '{}'::jsonb;
alter table public.conversation_state add constraint conversation_state_dialogue_state_check check (jsonb_typeof(dialogue_state) = 'object' and pg_column_size(dialogue_state) <= 8192);
