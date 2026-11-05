# Barqlo Sales Brain — Production Setup

How to configure the exported n8n workflows on a **compatible database that already has the required schema**. This is an integration/runbook, **not yet a one-command installation**: no SQL migrations or reproducible full-environment deployment are published in this repository.

The workflow inventory is based on the 2026-11-05 read-only n8n exports in `workflows/`; source filenames and reported SHA-256 fingerprints are in `workflows/MANIFEST.txt`. The exports reference n8n credentials **by name**, not credential values. Some workflow exports also contain webhook paths/URLs and identifiers; these are not secret credentials.

## What you are setting up

One central brain plus one lightweight adapter per channel, backed by
PostgreSQL, with Meta's Muse Spark drafting every reply:

- **The brain** (`workflows/barqlo-brain-guard-v1-CANDIDATE.json`, 24 nodes).
  A Webhook trigger (`POST`, path `barqlo-brain-v5`) receives one message,
  identifies the tenant from the channel's database row and the role from
  the member row, normalizes the Arabic, loads the tenant's data, drafts a
  reply with Muse Spark, verifies the draft against the real data with
  deterministic rules, corrects it once if needed, then replies. Every
  generated/verified reply paths are routed through the `Write Audit and Usage` node. **Early gate-blocked/suspended requests can return directly without that central audit node**; do not assume one `reply_audit` row for every inbound POST.
- **The adapters** (`workflows/telegram-adapter-sharq.json`,
  `telegram-adapter-saqr.json`, `telegram-adapter-hazaa.json`, 11 nodes
  each). One per Telegram channel. Each receives the Telegram update and
  calls the brain's webhook, then sends the brain's reply back.
- **Supporting workflows.** `instruction-validator.json` (12 nodes) and
  `instruction-validator-errors.json` (2 nodes) validate owner
  instructions; `stale-alert.json` (5 nodes) alerts when a validation
  stays pending too long; `tenant-activation.json` (14 nodes) and
  `owner-data-intake.json` (9 nodes) handle onboarding;
  `barqlo-request-status-notify.json` (8 nodes), `follow-up.json`
  (5 nodes) and `admin-ops.json` (11 nodes) handle operations.
- **Previous version.** `barqlo-brain-main-v2-CANDIDATE14.json` (24 nodes)
  is the brain version the demo video and the live-verification record
  document. `barqlo-brain-main-v2-DRAFT.json` (22 nodes) is a draft copy —
  do not activate it.

## What you need before you start

| Service | Used for |
| --- | --- |
| n8n (Cloud or self-hosted; verify node compatibility on your version) | Runs the workflows. Source exports were made on n8n Cloud on 2026-11-05. |
| PostgreSQL (Supabase in the original setup) | The single source of truth: tenants, channels, members, customers, catalog, conversations, audit rows. |
| Meta Model API access | Muse Spark (`muse-spark-1.3`) drafts every reply. Endpoint: `https://api.meta.ai/v1/chat/completions`. |
| Telegram bots (via BotFather) | One bot per channel (restaurant, real estate, clinic in the original setup). |

## Step 1 — Prepare the database

The brain reads and writes PostgreSQL. The tables it touches (read from
the brain's own SQL) include:

- **Tenancy and identity:** `tenants`, `channels`, `tenant_members`,
  `tenant_profiles`
- **Customers and conversations:** `customers`, `customer_profiles`,
  `customer_identities`, `conversations`, `conversation_state`, `messages`
- **Catalog:** `items`, `areas`, `area_places`, `services`, `policies`,
  `projects`, `sector_packs`, `sector_pack_versions`
- **Brain state and audit:** `reply_audit`, `response_cache`,
  `platform_config`, `usage_daily`, `usage_events`
- **Tenant settings:** `tenant_services`, `tenant_pack_settings`,
  `tenant_custom_instructions`, `tenant_voice_settings`, `dialect_lex`

**SQL migrations are not in this repo.** The database must already have compatible tables, columns, constraints, privileges, and functions. The exported SQL is evidence of the queries used; **it is not a complete database schema** and cannot bootstrap the database by itself. In addition to tables, the workflow SQL references routines such as `public.is_tenant_suspended(...)`, `public.tenant_balance(...)`, and `public.set_instruction_status(...)`; the onboarding flow uses PostgreSQL `crypt(...)` / `gen_salt(...)` functionality, so required extensions and privileges must exist.

Set up at least one test tenant, a matching active `channels` row (including the adapter authentication value required by `Identify Tenant by Channel`), and a `tenant_members` row for the test owner. Tenant and role identity come from database rows, not claims in message text. **Do not export the production database or customer records as a substitute for a schema migration.**

## Step 2 — Create the credentials in n8n (names only)

Create these credentials in your n8n instance with your own values. The
values are entered in n8n only, never in a file.

| Credential name in the workflows | Type | Value comes from |
| --- | --- | --- |
| `BarqBrainv1 Postgres` | Postgres | Your Supabase/Postgres connection (host, port, database, user, password, SSL). |
| `Header Auth account` | HTTP Header Auth | Your Meta Model API key, sent as the authorization header. |
| `n8n:telegram_sharq` | Telegram | The restaurant channel bot token from BotFather. |
| `n8n:telegram_saqr` | Telegram | The real-estate channel bot token from BotFather. |
| `n8n:telegram_hazaa` | Telegram | The clinic channel bot token from BotFather. |
| `n8n:telegram_alerts` | Telegram | Alert-bot token (for `stale-alert` and the validator error workflow). |
| `n8n:telegram_mskn` | Telegram | Telegram credential referenced by the request-status notification workflow. |
| `validator_webhook_secret` | HTTP Header Auth | Header-auth credential for `instruction-validator.json`. |
| `stale_alert_secret` | HTTP Header Auth | Header-auth credential for `stale-alert.json`. |

These names were checked against credential references in the exported JSON. n8n credential references may include original-instance IDs; **reselect the matching local credential in each imported node**. Never publish a credential's actual value.

## Step 3 — Import the workflows

The files in `workflows/` are n8n exports with original-instance metadata (`id`, `versionId`, `active`, and related fields). Use **Import from File** in a fresh n8n instance, then check node compatibility, references, and credentials. If the instance rejects or conflicts with metadata in a raw export, create a portable copy that retains the workflow definition keys below and omits instance-specific identifiers. **Do not edit the evidence exports in the repository** just to import them elsewhere.

```json
{"name": "...", "nodes": [...], "connections": {...}, "settings": {...}}
```

Import order:

1. The brain first (`barqlo-brain-guard-v1-CANDIDATE.json`).
2. Then the three adapters.
3. Then the supporting workflows you need.

Only one active workflow should own the `barqlo-brain-v5` production webhook path on one n8n instance. Publish/activate the selected brain, then the adapters; **do not activate the previous or draft brain at the same path**. The repo contains **14 JSON snapshots**, including two brain versions kept for reference; these are not 14 separate production services. Imported `active` flags from JSON **do not prove current live status**.

## Step 4 — Point the adapters at your instance

Each adapter's **Call Brain** node posts to the original instance:

```text
https://barql0.app.n8n.cloud/webhook/barqlo-brain-v5
```

Replace the host with your own n8n instance's host, keeping the path
`barqlo-brain-v5`. The brain's own trigger node carries only the path,
so it needs no change. The Meta endpoint
(`https://api.meta.ai/v1/chat/completions`, model `muse-spark-1.3`,
temperature `0.3`, timeout 60 seconds) is already correct in the brain
file.

## Step 5 — Verify it works

1. Publish the brain, then the adapters. Confirm the brain shows as
   active/published and the webhook path is registered to it.
2. Send a test message on a **test tenant** through one Telegram bot —
   never test on a real tenant.
3. Open the brain's Executions list. A healthy run succeeds end to end
   and returns a reply built from real data.
4. Inspect `reply_audit` for **generated/verified reply paths**, including the model (`muse-spark-1.3`), verdict, usage/cost and owner-alert fields as populated. A request blocked at the initial gate may go straight to `Respond to Webhook` and **need not create a `reply_audit` row in this exported workflow**.
5. Test the guard, not just the happy path: ask about an item that does
   not exist (the reply must say so honestly, never invent a price), and
   send an owner command from a customer account (it must get the generic
   fallback, zero owner data).

**Observed evidence, not a new test:** the dated read-only inspection in [`docs/live-verification-2026-11-05.md`](docs/live-verification-2026-11-05.md) covers **01:42–01:52 EET on 2026-11-05** and reports per-execution recorded costs of approximately **USD 0.0133–0.0425**. It documents both allowed outcomes and a blocked invented-price outcome, plus a corrected-then-allowed outcome. It **does not establish** that the latest six production executions at a later hour were all allowed or price-correct. Do not present that separate claim without a dated execution list.

## Quotas, costs and limits

- **n8n executions.** Check your own plan's execution limits and remaining allowance. Quotas and historical usage are instance-specific; the exported workflows do not establish a current quota.
- **Meta API.** Every brain execution calls Muse Spark once (plus one
  more call when a correction happens). Budget for it; the per-execution
  costs above are the observed range.
- **Cache.** A cache hit is gated by the database setting `platform_config.cache_enabled`. The export **does not prove the present value of that database setting**. Before testing guarantees for live output, confirm it is `false`: a cached reply takes the `Build Cached Response` route instead of rerunning the draft verifier.

## Security notes — read before exposing anything

- **Webhook boundary.** The brain trigger has no built-in n8n webhook authentication in this export, **but** `Identify Tenant by Channel` checks an adapter secret against the channel row. These are two different layers; do not mistake the SQL check for n8n-level authentication. Confirm gateway/instance protection before exposing an endpoint publicly. `admin-ops`, `tenant-activation`, `owner-data-intake`, and the notification webhook also require a separate boundary review.
- **Never put a credential value in a file.** The workflow files contain
  credential names only. If you fork this repo, keep it that way.
- **Test tenants only for testing.** Demo tenants are real tenants in
  the original setup. Never send test messages to them.

## What is not in this repo

- SQL migrations for the schema in Step 1.
- The live database or any of its data.
- Any credential value, bot token or API key.
- A fully automated, independently verified clean-install test.
- The n8n Cloud account itself — you bring your own instance.

## Evidence and scope

- [`workflows/MANIFEST.txt`](workflows/MANIFEST.txt): exported filenames, workflow IDs, reported sizes and SHA-256 fingerprints.
- [`docs/live-verification-2026-11-05.md`](docs/live-verification-2026-11-05.md): dated historical inspection; it is **not** an ongoing health check.
- [`HACKATHON_BUILD.md`](HACKATHON_BUILD.md): source-to-claim mapping and scope of the evidence.
- These instructions document configuration and validation steps; **they do not mean a clean install was performed as part of preparing this document**.