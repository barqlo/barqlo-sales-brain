# barqlo Sales Brain

One Arabic-native AI brain that runs a company's entire customer operation.
Not a bot per workflow, not a workflow per company: one central brain — one memory,
one judgment — that every channel and every sector plugs into.

Built by Mahmoud Hazaa (Banha, Qalyubia, Egypt) for the Meta Global AI Developer
Hackathon 2026, Startup track. Live site: https://barqlo.pages.dev

## The problem

Small and mid-size businesses across the Middle East drown in customer messages
they cannot answer fast enough — in Arabic, across WhatsApp, Telegram, Instagram,
Messenger and web chat. The usual fix is a pile of disconnected bots: one per
workflow, one per company, each with its own memory, each free to invent an
answer. Leads get lost to spelling variants (انا / أنا / إنا treated as different
words), prices get hallucinated, and the owner finds out too late.

## The solution

One brain, two agents, and a database that decides:

1. **One brain.** Every message from every channel enters one unified message
   contract. Identity comes from the channel's database row — never from what
   the sender claims. Tenant data never mixes: each company's data, history and
   customers stay isolated.
2. **Two agents.** A Preparation agent drafts every reply. A Verification agent
   checks the draft against the business's real data and policies with
   deterministic rules — real prices only, real unit/project numbers, no denial
   without a real search, counts that match database totals, no "all" claimed
   from a sample, gaps stated honestly. One correction attempt with specific
   feedback, then re-verification. A reply that still fails goes to an honest
   fallback, an owner alert, and an audit record — it is never sent as-is.
3. **The database decides.** The AI proposes; the database decides. The model is
   forbidden from inventing units, prices or availability.
4. **Arabic-native.** A normalization layer runs before any Arabic matching:
   hamza/alef variants are one letter, ة/ه are one, ى/ي are one — plus Egyptian
   and Gulf dialect understanding, intent detection, and extraction of name,
   phone, budget, city and interest from free conversation.
5. **Owner and customer, strictly separated.** A separate owner path understands
   natural-phrasing commands ("send me today's summary") and owner alerts go
   only to the owner. The same sentence is interpreted differently by role:
   a digest request from the owner returns an operational summary; from a
   customer it never returns owner data.

The same brain runs every sector. Sector knowledge lives in data and config
rows, not in sector-specific code: real estate, clinics, restaurants and more
load their knowledge into the same brain.

## Meta AI usage

The brain uses Meta's Muse Spark through the Meta Model API. The
production export has a draft HTTP node and an optional correction HTTP node
that call:

- Endpoint: `https://api.meta.ai/v1/chat/completions`
- Model: `muse-spark-1.3` (temperature 0.3)
- Auth: a single Header Auth credential
- Timeout: 60 seconds

The model drafts replies only. Every draft passes the deterministic verifier
before anything is sent. No reply is ever generated from the model alone.

## Demo video

[Watch the demo (2:23, English)](https://drive.google.com/file/d/1YpCzRH_6SrUh_qvQFc8GrTQOuQCvqNk1/view?usp=drivesdk)

Recorded 2026-11-05 from the live system. It walks the seven promises one by
one, each with its evidence: the audit rows showing model `muse-spark-1.3`,
the two-agent guard drawn from the production workflow's real node names, the
three live sector digests, the gap test (a question about an item that does
not exist, answered without inventing a price), the blocked invented-price
audit row, the owner/customer separation, and the owner workspace with staff
accounts. An Arabic-narrated version (2:33) shows the same evidence. No real
customer data and no credentials appear in the video.

## The demo in this repo

`demo/` runs the core loop offline with no keys, no network and no dependencies
(Node 18+). The draft step uses a small deterministic stand-in so the demo runs
anywhere; the normalize, verify, correct-once, role-gate and audit logic mirrors
production's shape.

```sh
node demo/demo.js
```

It runs five scenarios against fabricated sample data and prints each draft,
its verdict, any correction, the final reply, and an audit line:

1. A customer asks the price of an item that exists — real price, allowed.
2. A customer asks about an item that does not exist — honest gap, allowed.
3. A flawed draft invents a price — the verifier rejects it, one correction
   strips the invented price and adds an honesty note, re-verification allows it.
4. The same digest sentence from a customer — the role gate blocks owner
   content, a generic fallback is sent, zero owner data.
5. The same digest sentence from the owner — the digest is allowed.

## Live verification — 2026-11-05

On the morning of 2026-11-05 (01:42–01:52 EET), the production workflow's
execution records were inspected read-only — no test messages were sent. The
code facts below were read from the live export of the version Mahmoud
published himself at 00:35 EET. The full record, execution by execution, is in
`docs/live-verification-2026-11-05.md`. In short:

- **One brain, three sectors.** The same 24-node workflow served a
  real-estate tenant, a clinic tenant and a restaurant tenant, with
  role-gated digests for the owner and blocked owner content for the
  customer.
- **Muse Spark.** Every inspected brain execution ran `muse-spark-1.3`
  through the Meta Model API, with per-execution costs of USD 0.013–0.043
  recorded in audit rows.
- **Two agents.** A flawed draft with invented prices failed verification
  twice and was blocked with a fallback and an owner alert; another draft
  was corrected once and then allowed.
- **Arabic-native — PROVEN in the current version.** One Normalize Arabic
  node holds the single copy of `normalizeArabic` in the whole workflow
  (its own code says so), and every later node matches against its
  `normalized_message` output — never against raw text, except two slot
  reads that enumerate the spelling variants in the pattern itself.
  Implemented by Mahmoud in the editor and published 2026-11-05 00:35 EET;
  verified from the live export.
- **Never invents — PROVEN.** The verifier binds every cited price to its
  own row (price AND unit must match the attached row) and judges every
  money number by its role. Live behavior matches: a draft with wrong
  prices was blocked twice and never sent.
- **Separation — historically observed, with a version distinction.**
  The owner/customer role comes only from a database membership row, never
  from what the sender types. The current `barqlo-brain-guard-v1-CANDIDATE`
  also checks some Arabic customer requests for administrative subjects
  before drafting; request-text checks can **deny** privileged content but
  cannot **grant** an owner role. The older, keyword-free role-gate finding
  in the dated verification record applies to the older version inspected
  there. That historical test returned an owner digest to an owner and
  withheld owner data from a customer.

The inspection used test identities, not real customers, and covers only the
window stated in the verification record.

## Production workflows

`workflows/` holds the n8n workflow definitions exported read-only from
n8n Cloud on 2026-11-05 (17:00–17:07 EET) — the exact files verified that
day, with SHA-256 fingerprints in `workflows/MANIFEST.txt`:

- `barqlo-brain-guard-v1-CANDIDATE.json` — the live brain (24 nodes),
  serving the `barqlo-brain-v5` webhook path.
- `barqlo-brain-main-v2-CANDIDATE14.json` — the previous brain version
  (24 nodes), the one the demo video and the live-verification record
  document.
- `telegram-adapter-sharq.json`, `telegram-adapter-saqr.json`,
  `telegram-adapter-hazaa.json` — one lightweight adapter per Telegram
  channel, each calling the brain's webhook.
- `instruction-validator.json`, `instruction-validator-errors.json`,
  `stale-alert.json` — the validation and monitoring workflows.
- `tenant-activation.json`, `owner-data-intake.json`,
  `barqlo-request-status-notify.json`, `follow-up.json`, `admin-ops.json` —
  supporting operations workflows.
- `barqlo-brain-main-v2-DRAFT.json` — a draft copy of the brain
  (22 nodes), kept for reference.

No credentials appear in these files: database, Telegram and header-auth
credentials are referenced by name only.

## Reviewer documentation

- [`PRODUCTION_SETUP.md`](PRODUCTION_SETUP.md) — n8n imports, credential-reference inventory, database prerequisites, test steps and known limits; **SQL migrations are not included**, so this is not a one-command clean install.
- [`HACKATHON_BUILD.md`](HACKATHON_BUILD.md) — source-to-claim mapping, dated evidence, and what cannot be established from a later commit.
- [`LICENSE`](LICENSE) — MIT license for repository code; commercial reuse is permitted under its terms.

## Repository structure

```text
README.md               This file.
PRODUCTION_SETUP.md     Production integration steps and documented prerequisites.
HACKATHON_BUILD.md      Evidence map and hackathon-build scope.
LICENSE                 MIT license for the published repository code.
demo/demo.js            The offline demo of the two-agent core loop.
demo/sample-data.json   Fabricated tenant data (invented restaurant, prices,
                        policies). Nothing real.
docs/architecture.md    Pipeline, identity rules, verification rules, and how
                        the demo maps to the production system.
docs/live-verification-2026-11-05.md
                        Execution-by-execution record of the 2026-11-05 live
                        inspection: what was observed, and what was not
                        claimed.
workflows/              The production n8n workflows, exported 2026-11-05
                        (read-only export, nothing changed): the live brain,
                        the previous brain version, the three Telegram
                        adapters, and the supporting workflows. See
                        workflows/MANIFEST.txt for IDs and fingerprints.
.gitignore              Keeps secrets and local artifacts out of the repo.
```

## Honesty notes

- All sample data in this repo is fabricated. No real customer names, phone
  numbers, prices or conversations appear anywhere here.
- Nothing in this repo calls a live system, and it contains no credentials,
  tokens or keys — credentials are referenced by name only. The workflow
  files do contain the production webhook URL and the Meta Model API
  endpoint, both already stated in this README.
- Production runs as a single n8n workflow backed by PostgreSQL, with one
  lightweight adapter per channel. The workflow's node count, endpoint, model
  and timeout stated in `docs/architecture.md` were read from a live export.
- The live-verification record states its inspection window and its limits.
  Do not treat later exports or post-deadline documentation commits as proof
  that they were part of the original submitted snapshot. The present guard
  may have different customer request-blocking logic from the earlier one.
