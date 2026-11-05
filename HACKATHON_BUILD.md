# BARQLO Sales Brain — Hackathon Build & Evidence Map

> This is a documentation of the submitted project and the code evidence currently published. It is not a claim that every repository file was already present at submission time, and it is not a replacement for the hackathon submission form.

## Project / scope

- **Project:** BARQLO Sales Brain — Arabic-native multi-tenant customer-operations brain.
- **Hackathon:** Meta Global AI Developer Hackathon 2026; Startup track, as described in the repository README.
- **Core AI:** Meta Model API, endpoint `https://api.meta.ai/v1/chat/completions`, model `muse-spark-1.3`; draft and optional correction calls are verified in the exported workflow definitions.
- **Platform:** n8n workflows, PostgreSQL (Supabase in the original environment), Telegram adapters, plus a separate offline demonstration.
- **Status distinction:** source exports describe implementations; dated execution evidence supports only the explicitly inspected window. The deployed system may change after an export.

## What the published source actually includes

| Component | Source | Purpose |
| --- | --- | --- |
| Central production brain | `workflows/barqlo-brain-guard-v1-CANDIDATE.json` | Inbound tenant lookup, role gate, Arabic normalization, scoped data load, Muse Spark draft, deterministic verification, optional correction, response and audit flow. 24 nodes; marked `active: true` **in the export**. |
| Previous brain version | `workflows/barqlo-brain-main-v2-CANDIDATE14.json` | Earlier 24-node version associated with the morning test report and video; marked `active: false` **in the exported file**. |
| Reference-only draft | `workflows/barqlo-brain-main-v2-DRAFT.json` | 22-node draft; **do not activate** as a production brain. |
| Telegram ingress/egress | `workflows/telegram-adapter-{sharq,saqr,hazaa}.json` | Three adapter exports; identify channel, build a common message contract, call the brain, return response. |
| Instruction governance | `workflows/instruction-validator.json`, `workflows/instruction-validator-errors.json`, `workflows/stale-alert.json` | Validation, error notification and stale-warning flows. |
| Tenant and operations | `workflows/tenant-activation.json`, `workflows/owner-data-intake.json`, `workflows/admin-ops.json`, `workflows/barqlo-request-status-notify.json`, `workflows/follow-up.json` | Onboarding, owner intake, administration, status notifications and follow-ups. |
| Offline runnable illustration | `demo/demo.js`, `demo/sample-data.json` | Node.js demonstration using **fabricated** data and a deterministic stand-in **instead of a live Muse Spark API call**. |
| Architecture / historical evidence | `docs/architecture.md`, `docs/live-verification-2026-11-05.md` | System explanation and a dated, scoped read-only execution inspection. |

The repository has **14 exported JSON files**, including two non-current brain snapshots; it is not evidence of 14 independently deployed, simultaneous services.

## Seven product promises mapped to checkable evidence

| Claim | Source evidence | What the evidence establishes / limitation |
| --- | --- | --- |
| One core brain across sectors | `workflows/barqlo-brain-main-v2-CANDIDATE14.json`; dated verification report | The inspection documented one brain workflow serving test tenants in restaurant, real-estate and clinic sectors; not a population-scale usage study. |
| Uses Meta Muse Spark | `Prepare Reply Draft`, `Correct Once` nodes in the current and previous brain JSON; execution report | Node configuration specifies `muse-spark-1.3`, with recorded per-execution costs in the historical window; no credentials are published. |
| Preparation and deterministic guard | `Prepare Reply Draft`, `Verify Reply Deterministic`, `Correct Once`, `Re-verify Corrected`, fallback routes | Actual code implements a draft/check/correct-once decision path. The historical report includes passed, corrected and blocked examples; not a formal correctness proof for every possible prompt. |
| Real database governs answers | `Identify Tenant by Channel`, `Load Tenant Data`, verifier code | Data is loaded for the tenant and guard checks compare claims against loaded rows. This is **not** a guarantee against every data hallucination or every unstored item. |
| Arabic-native handling | `Normalize Arabic` and downstream processing | Code normalizes Arabic variants and routes normalized text for matching. Language quality beyond covered examples requires ongoing testing. |
| Separation of owner/customer | database membership lookup, `Identify Role and Gate` | Role comes from database membership, not the sender's text; **current** guard additionally examines Arabic request text to block some customer requests for administrative data. |
| Three sectors shown live | historical execution report | Dated read-only inspection observed test identities in restaurant, real estate and clinic. Do not imply verified real customer traffic. |

## Dated evidence and what it does NOT prove

- **2026-11-05 00:35 EET:** the historical report identifies a previously published brain version.
- **2026-11-05 01:42–01:52 EET:** read-only examination of real n8n execution history, including allowed, corrected and blocked responses, documented in [`docs/live-verification-2026-11-05.md`](docs/live-verification-2026-11-05.md).
- **2026-11-05 17:00–17:07 EET:** separate read-only exports were taken according to [`workflows/MANIFEST.txt`](workflows/MANIFEST.txt). SHA-256 values fingerprint the files; they do not prove the time each component was originally authored.
- **2026-11-05:** the code and documentation were later added to this public repository. A later GitHub commit **is not evidence** that the published files formed part of the originally submitted snapshot, nor proof that late updates will be scored.
- The user reports submitting the entry before the deadline. The repository alone cannot independently verify the submission timestamp or provide a historical diff of all work done during the hackathon.
- A later run, a reviewer-specific test, or a clean-room deployment is **not** claimed here unless it has its own dated evidence.

## How a reviewer can inspect without production secrets

1. Read [`README.md`](README.md) for the high-level pitch and linked video.
2. Open the **current** brain and inspect `Prepare Reply Draft`, `Verify Reply Deterministic`, `Correct Once`, `Re-verify Corrected` and `Identify Role and Gate`.
3. Examine [`workflows/MANIFEST.txt`](workflows/MANIFEST.txt) and the supporting workflow JSON files.
4. Run the **offline illustration** with `node demo/demo.js` (Node.js 18+), without claiming it is a live model test.
5. Read [`docs/live-verification-2026-11-05.md`](docs/live-verification-2026-11-05.md) for evidence and its declared observation window.
6. Consult [`PRODUCTION_SETUP.md`](PRODUCTION_SETUP.md) for the integration prerequisites and the missing database-schema dependency.

## Database migration history (available with limits)

- [`supabase/migrations/`](supabase/migrations/) contains 18 recorded migrations extracted from the existing Supabase migration-history table on 2026-11-05, and [`supabase/README.md`](supabase/README.md) explains the source and dependencies.
- The original baseline schema predates these migrations and is **not** in the repository. These incremental scripts **do not demonstrate** a clean-room install, and do **not** by themselves show what code existed at the submission deadline.
- No tenant row data, customer messages or credential values were exported as part of this migration package.

## Scope of this document

This document maps **what is in the current repository** to its stated function and independently described historical observations. It does **not** invent a build chronology, assert uninspected 02:00–08:00 executions, claim a clean installation has passed, or change the production workflows. Any later evidence must name its date, workflow version and test scope.
