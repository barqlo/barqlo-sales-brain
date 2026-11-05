-- BARQLO historical migration (schema / function definition; original SQL retained)
-- Source: remote supabase_migrations.schema_migrations (read-only extraction 2026-11-05)
-- Recorded version: 20261103232023
-- Recorded name: tenant_market_currency_and_item_guard
-- Not standalone: requires the earlier BARQLO database baseline, which is NOT in this repo.
-- Do not run these migrations against the live production database.

ALTER TABLE public.tenants ADD COLUMN market_code text NOT NULL DEFAULT 'EG'; ALTER TABLE public.tenants ADD COLUMN currency_code text NOT NULL DEFAULT 'EGP'; ALTER TABLE public.tenants ADD CONSTRAINT tenants_market_currency_check CHECK ((market_code = 'EG' AND currency_code = 'EGP') OR (market_code = 'SA' AND currency_code = 'SAR')); ALTER TABLE public.items ALTER COLUMN currency DROP DEFAULT; CREATE FUNCTION public.set_item_currency_from_tenant() RETURNS trigger LANGUAGE plpgsql SET search_path = '' AS $$ DECLARE v_currency text; BEGIN SELECT t.currency_code INTO v_currency FROM public.tenants t WHERE t.id = NEW.tenant_id; IF NOT FOUND THEN RAISE EXCEPTION 'tenant_not_found'; END IF; IF NEW.currency IS NULL OR btrim(NEW.currency) = '' THEN NEW.currency := v_currency; END IF; IF NEW.currency <> v_currency THEN RAISE EXCEPTION 'item_currency_mismatch: expected %, got %', v_currency, NEW.currency; END IF; RETURN NEW; END; $$; CREATE TRIGGER trg_items_currency_guard BEFORE INSERT OR UPDATE OF tenant_id, currency ON public.items FOR EACH ROW EXECUTE FUNCTION public.set_item_currency_from_tenant();
