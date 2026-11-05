-- BARQLO historical migration (schema / function definition; original SQL retained)
-- Source: remote supabase_migrations.schema_migrations (read-only extraction 2026-11-05)
-- Recorded version: 20261103232429
-- Recorded name: 20261103232330_booking_fee_market_guard_and_policy_reactivation
-- Not standalone: requires the earlier BARQLO database baseline, which is NOT in this repo.
-- Do not run these migrations against the live production database.

CREATE OR REPLACE FUNCTION public.validate_booking_fee_currency()
RETURNS trigger
LANGUAGE plpgsql
SET search_path = ''
AS $$
DECLARE
  expected_currency text;
BEGIN
  IF NEW.policy_key = 'booking_fee' AND NEW.is_active THEN
    SELECT t.currency_code INTO expected_currency
    FROM public.tenants AS t
    WHERE t.id = NEW.tenant_id;
    IF expected_currency IS NULL THEN
      RAISE EXCEPTION 'unknown_tenant_for_booking_fee';
    END IF;
    IF jsonb_typeof(NEW.policy_value) <> 'object'
       OR NEW.policy_value->>'currency' IS DISTINCT FROM expected_currency
       OR jsonb_typeof(NEW.policy_value->'value') <> 'number'
       OR (NEW.policy_value->>'value')::numeric < 0 THEN
      RAISE EXCEPTION 'booking_fee_must_have_nonnegative_value_in_tenant_currency: %', expected_currency;
    END IF;
  END IF;
  RETURN NEW;
END;
$$;
CREATE TRIGGER trg_booking_fee_currency_guard
BEFORE INSERT OR UPDATE OF tenant_id, policy_key, policy_value, is_active
ON public.policies
FOR EACH ROW
EXECUTE FUNCTION public.validate_booking_fee_currency();

CREATE OR REPLACE FUNCTION public.update_policy_field(p_key text, p_value jsonb)
RETURNS TABLE(id uuid, tenant_id uuid, policy_key text, policy_value jsonb, is_active boolean, updated_at timestamp with time zone)
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path TO ''
AS $function$
#variable_conflict use_column
DECLARE
  v_tenant_id uuid;
  v_role text;
BEGIN
  SELECT dm.tenant_id, dm.role INTO v_tenant_id, v_role
    FROM public.dashboard_members dm WHERE dm.user_id = auth.uid();
  IF NOT FOUND THEN RAISE EXCEPTION 'not_a_member: no dashboard membership for this user'; END IF;
  IF EXISTS (SELECT 1 FROM public.dashboard_members dm2 WHERE dm2.user_id = auth.uid() AND dm2.tenant_id <> v_tenant_id) THEN RAISE EXCEPTION 'ambiguous_membership: user belongs to more than one tenant'; END IF;
  IF v_role <> 'owner' THEN RAISE EXCEPTION 'forbidden: owner role required'; END IF;
  IF p_key !~ '^[a-z][a-z0-9_]*$' THEN RAISE EXCEPTION 'invalid policy key'; END IF;
  INSERT INTO public.policies (tenant_id, policy_key, policy_value)
    VALUES (v_tenant_id, p_key, p_value)
    ON CONFLICT (tenant_id, policy_key) DO UPDATE
      SET policy_value = EXCLUDED.policy_value, is_active = true, updated_at = now();
  INSERT INTO public.admin_audit (tenant_id, action, target, details, actor_id, actor_type)
    VALUES (v_tenant_id, 'policy_field_update', p_key,
            jsonb_build_object('policy_key', p_key, 'policy_value', p_value), auth.uid(), 'owner');
  RETURN QUERY
    SELECT p.id, p.tenant_id, p.policy_key::text, p.policy_value, p.is_active, p.updated_at
    FROM public.policies p WHERE p.tenant_id = v_tenant_id AND p.policy_key = p_key;
END;
$function$;
