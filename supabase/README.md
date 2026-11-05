# BARQLO — Recorded Supabase SQL Migrations

This folder contains the **18 SQL migrations stored in the migration-history table** of the connected **BarqBrainv1** Supabase project, extracted **read-only on 2026-11-05**. Each `*.sql` file preserves the original recorded `statements` for its version, with an informational header. There are **no exported database rows, customer conversations, API keys, passwords, or token values** in this package.

## Critical scope limit: missing original baseline

These are **historical incremental migrations**, NOT a complete database schema, and they are **not a one-command clean install**. The earliest recorded migration here is **20261103232023 (3 November 2026)**. The original BARQLO database predates these entries and contains tables, functions, triggers and policies that were created earlier and are **not recreated by these files alone**.

In particular, a new Supabase project cannot import just these 18 files and expect the full application to work. Some migrations may fail without their original table/function dependencies. Do **not** replay them against the live production project: they have already been applied there.

The script filenames are prefixed by the **actual recorded migration version**. Where the migration name itself began with another timestamp, the duplicated name prefix was removed from the filename only; the header records the original name.

## Correct path for a reproducible, from-scratch installation

1. Obtain a verified **schema-only baseline**, excluding all private data, using the official Supabase CLI against an authorized linked project. For example, from an environment where you have permission to perform a database dump:

   ```sh
   supabase db dump --linked --schema public -f supabase/schema.sql
   ```

   The command creates a **snapshot of the current schema**, not the historical pre-November baseline. It is an alternative starting point; **do not automatically replay these historical migrations on top of a current-schema snapshot**.
2. Prefer authentic pre-existing migrations (if recoverable) or a verified new baseline, then a separate, carefully tested migration strategy. Test on a **throwaway/local environment** before documenting an install as reproducible.
3. Check dependencies such as PostgreSQL extensions and any custom Supabase Auth/Storage/RLS objects. The historical files do not guarantee all roles, grants, or managed-schema customizations are captured.
4. Use `supabase migration list --linked` to inspect history; do not use `supabase db push` or `supabase db reset --linked` against live production just to validate documentation.

## Other references

- [Production setup](../PRODUCTION_SETUP.md) — configuration of n8n and the prerequisite database.
- [Hackathon source/evidence map](../HACKATHON_BUILD.md) — evidence claims and limits.
- [Workflow manifest](../workflows/MANIFEST.txt) — read-only n8n exports and their recorded hashes.

These migrations were retrieved **without making any changes** to the running Supabase database, n8n workflows or tenant data.
