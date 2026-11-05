-- BARQLO historical migration (schema / function definition; original SQL retained)
-- Source: remote supabase_migrations.schema_migrations (read-only extraction 2026-11-05)
-- Recorded version: 20261104175008
-- Recorded name: owner_site_membership_read
-- Not standalone: requires the earlier BARQLO database baseline, which is NOT in this repo.
-- Do not run these migrations against the live production database.

-- Existing dashboard_members admin policy reads this RLS-protected table.
-- Authenticated users can only see their own platform_admins row.
begin;
grant select on public.platform_admins to authenticated;
commit;
