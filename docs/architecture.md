# Architecture — barqlo Sales Brain

## The pipeline (one turn)

Every inbound message walks the same stages, in this order. In production the
stages are nodes of a single n8n workflow; in this repo's demo they are the
functions in `demo/demo.js`.

1. **Webhook / adapter.** A lightweight adapter per channel receives the
   message and forwards it to the brain over one unified message contract.
   The brain never branches on the channel.
2. **Identify tenant by channel.** The tenant is resolved from the channel's
   database row. No tenant is ever inferred from message text.
3. **Identify role and gate.** The role (owner / customer) is resolved from a
   database row every time, defaulting to customer on any doubt. The gate runs
   before drafting: owner-only content is never drafted for a customer.
4. **Normalize Arabic.** The text passes through `normalizeArabic()` before
   any matching: hamza/alef variants become one letter, ة/ه become one,
   ى/ي become one, diacritics and tatweel are stripped.
5. **Store inbound message.** The raw message is stored for history and audit.
6. **Load tenant data.** The tenant's items, policies, services and history
   are loaded from PostgreSQL, scoped by `tenant_id` on every query.
7. **Build reply prompt.** The prompt carries the loaded data and the role —
   the model sees only this tenant's data.
8. **Prepare reply draft (Muse Spark).** One HTTP call to Meta's Model API
   (`api.meta.ai/v1/chat/completions`, model `muse-spark-1.3`, temperature
   0.3, Header Auth credential, 60-second timeout — values read from a live
   export of the production workflow on 2026-11-05). The model drafts; it
   never sends.
9. **Verify reply (deterministic).** Fixed rules, no model judgment:
   - `price_real` — every price in the draft must exist in the loaded data.
   - `unit_real` — every unit/project number must exist in the data.
   - `no_denial_without_search` — no refusal without a real search first.
   - `counts_match` — any count cited must equal the database total.
   - `no_all_from_sample` — no "all" claimed from a partial sample.
   - `gap_honesty` — missing data is stated honestly, never invented.
   - `role_separation` — no owner content in a customer reply.
10. **Route by verdict.** `allowed` goes to the final reply. A failed draft
    gets exactly **one** correction attempt with specific feedback, then
    re-verification.
11. **Fallback and owner alert.** A draft that still fails becomes an honest
    fallback reply, an owner alert, and an audit record. Nothing invented is
    ever sent.
12. **Write audit and usage, respond.** Verdict, correction flag, cost and
    latency are written to the audit log; the reply goes back to the adapter.

## Identity and isolation rules

- Identity comes only from database rows: tenant from the channel row, role
  from the membership row, customer from the customers row scoped to the same
  tenant. Zero identity from message text or sender claims.
- Role is resolved from the database row every time. Any doubt or query error
  defaults to customer, and the failure is logged, never silenced.
- No tenant's data, history or customers ever mix. Every data query is
  scoped by `tenant_id`.
- State is read from the database on every turn. The production deployment
  runs with response caching disabled, so no reply is ever served from stale
  state.

## Sectors as data, not code

Sector knowledge (real estate, clinics, restaurants, …) lives in config and
data rows — services, policies, attributes — not in sector-specific branches.
The brain and its pipeline never change between sectors; each sector loads its
own knowledge into the same brain. That is what makes the system expandable
without a workflow copy per tenant.

## The owner path

Owner commands are understood in natural phrasing ("send me today's summary",
"message the customer about …") and executed against the right customer's
data. Owner alerts — hot lead, purchase intent, critical ticket, verification
failure — go only to the owner, in the moment. Negotiation happens only
inside the owner's configured bounds; outside them, the brain escalates with a
ready summary instead of an empty handover. Owner data is shown complete and
detailed, split across messages rather than compressed.

## Demo vs production

| Concern | Demo (`demo/`) | Production |
|---|---|---|
| Draft | Deterministic stand-in (offline) | Muse Spark via Meta Model API |
| Verify / correct / gate / audit | Same rule shapes as production | Deterministic code nodes |
| Data | Fabricated `sample-data.json` | PostgreSQL, tenant-scoped |
| Channels | One fake channel row | Telegram/WhatsApp/Instagram/Messenger/web adapters |
| Secrets | None exist | n8n credentials, never in code |

## Verified production facts (live export + inspection, 2026-11-05)

- Single workflow, 24 nodes; production webhook path `barqlo-brain-v5`
  (export downloaded 2026-11-05 02:20 EET, 261,326 bytes, workflow id
  `lz76eFOdmCaEMygs`).
- Draft call: `POST api.meta.ai/v1/chat/completions`, `muse-spark-1.3`,
  temperature 0.3, Header Auth, 60-second timeout.
- Execution records inspected read-only 01:42–01:52 EET on 2026-11-05 (no
  messages sent): the same workflow served all three live demo tenants with
  role-gated digests, a corrected-then-allowed reply, and a
  blocked-then-fallback reply with owner alert. Per-execution costs USD
  0.013–0.043. Full record: `docs/live-verification-2026-11-05.md`.
- Scope notes, stated plainly: the live export still contains read limits in
  the tenant-data load (latest customer requests capped, area items capped),
  so uncapped whole-data visibility is not the live behavior and is not
  claimed. Arabic normalization runs in one early node and normalized forms
  were observed, but the unification of all divergent normalization copies
  is not complete and is not claimed.
