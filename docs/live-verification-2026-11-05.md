# Live verification — 2026-11-05

How the seven promises were checked against the live production system, what
was observed execution by execution, and what is deliberately NOT claimed.

## Method and limits

- **Window:** 2026-11-05, 01:42–01:52 EET. No fresh live proof exists beyond
  02:36 EET that morning.
- **Method:** read-only inspection of the production workflow's execution
  records in the n8n executions viewer. No test messages were sent, no
  executions were triggered, nothing was modified.
- **Identities:** only two identities appear in the inspected executions —
  the owner identity on all three bots, and one test identity on all three
  bots. This was testing, not real customers. No real customer names, phone
  numbers or conversations appear in this record.
- **Not examined:** a newer restaurant execution timestamped 02:34:56 EET
  appeared during reading and was outside the window; it was not examined.
- **Sources:** the live workflow export downloaded 2026-11-05 02:20 EET
  (24 nodes, webhook path `barqlo-brain-v5`, model `muse-spark-1.3`,
  60-second timeout) and the execution records below. The verified
  workflow is the version Mahmoud published himself from the n8n editor at
  00:35 EET on 2026-11-05 (versionId `def755d2`). The three fixes in the
  code-evidence section below are his hand work in that version; this
  record verifies them from the exported file.

## Executions observed

Times are EET (UTC+2) on 2026-11-05. Each brain execution is paired with an
adapter execution; both succeeded. "Cost" is the recorded cost of the brain
execution in USD, where the inspection notes recorded it exactly.

### Real estate tenant

- **01:42:06 — customer.** Message stating a name and an 8M EGP budget for
  New Cairo. Single-unit resolution: unit A-203, 7.2M EGP, immediate
  delivery, full finish, 150 m, 3 rooms, 2 baths; other options deferred
  until this unit is settled; pending state "choosing the preferred unit".
  Verdict: allowed, high confidence. Cost: 0.02576275.
- **01:51:45 — owner.** Digest request returned an operational digest:
  6 projects, 47 units/land, 37 available, land 6 total / 4 available,
  5 services, project distribution. Verdict: allowed. Cost: 0.02328925.

### Clinic tenant

- **01:44:00 — customer.** Asked the price and days of the initial
  examination and evaluation with Dr. Ahmed Hazaa. Reply: 800 EGP,
  60 minutes, Saturday / Monday / Wednesday. Verdict: allowed, high
  confidence. Cost: 0.01668. First live clinic content observed.
- **01:51:52 — owner.** Digest request returned an operational digest:
  13 services (12 available), 2 doctors (1 available), 2 clinics, with a
  transparency note that bookings/revenue data was not in the attached
  data. Verdict: allowed, high confidence. Cost: 0.0200205.

### Restaurant tenant

- **01:44:46 — customer.** "Do you have sushi? How much?" The item is not
  in the data. Reply: honest gap — the item is absent, no price given.
  Verdict: allowed, low confidence. Cost within the window range below.
- **01:45:16 — customer.** The same digest sentence the owner later used
  ("send me today's summary"). The draft named a stored customer and gave
  wrong prices (rice 110 vs the real 55; water 30 vs the real 15).
  Verification failed twice on the real-price rule. Verdict: blocked;
  a generic fallback with zero order data was sent, and the owner alert
  fired. Cost within the window range below.
- **01:51:39 — owner.** The same digest sentence returned a long
  operational digest (two branches, 71 items available, 5 services, with a
  transparency note on missing sales data). First verdict: correct, with
  two checks failing; corrected once, then allowed. Cost: 0.0425355.

Per-execution costs across the inspected brain executions ranged from USD
0.0133 to USD 0.0425.

Corroboration: a screenshot of the `reply_audit` table for the restaurant
tenant taken the same morning shows 3 rows for model `muse-spark-1.3`
(costs 0.037246 / 0.013328 / 0.018551; statuses blocked / passed / passed;
timestamps 23:41–23:45 UTC, i.e. 01:41–01:45 EET), matching the inspection
window exactly.

## Behavioral findings

1. **Same text, interpreted by role.** The digest sentence returned an
   operational summary to the owner and was blocked as a customer request
   for owner data. This is the sharpest observed proof of owner/customer
   separation.
2. **Correction + re-verification loop, seen twice.** One draft was
   corrected and then allowed; one draft failed correction and was blocked
   with a fallback and an owner alert.
3. **Transparency notes are consistent.** Replies state plainly when data
   (sales, revenue, bookings) is not in the attached data.
4. **No message splitting observed.** An adapter version tag about balancing
   long replies was shown, but every checked sent reply was a single
   message. Reported as shown; no conclusion is drawn from it.

## Code evidence (live export, 2026-11-05 02:20 EET)

Read from the exported workflow file, not from any description:

1. **Arabic normalization — one copy, consumed downstream.** The
   Normalize Arabic node contains the workflow's single `normalizeArabic`
   (its own comment: "SINGLE copy of normalizeArabic in the whole
   workflow. No other node re-implements it; later nodes use
   normalized_message from this node"). Keywords, classification and
   intent are built from the normalized text, never from raw text.
   Downstream, Verify Reply Deterministic and Re-verify Corrected
   reference `normalized_message` 4 times each and `raw_message` zero
   times. Every Arabic match in the workflow either runs on the
   normalized text or enumerates the spelling variants in the pattern
   itself; no match depends on a single unnormalized spelling.
2. **Price bound to its row.** The verifier builds one evidence row per
   attached item (name, code, price, per-square-meter price, reservation,
   percents, currency) and the price check passes a cited price only when
   it equals the chosen row's price AND the unit matches; the failure
   message names the row, the attached price and the attached unit. A
   separate number-role check judges every money number by its role
   (item price, fee, percent), so a fee stated as a price fails.
3. **Owner commands gated by role, not words.** Identify Role and Gate
   takes the role only from the `tenant_members` row (`member_role`,
   default customer) and the gate only from row fields (status,
   suspension, balance). It contains zero Arabic characters and zero
   keyword matching, and it runs before drafting. The Switch routes on
   the gate flag. Corroboration: a 2026-11-02 guard audit of six
   executions found every role matching its membership row, default
   customer, no wrong blocks.

## The seven promises — verdicts

Evidence dates are stated with every verdict.

1. **ONE brain — PROVEN** (structure from the live export + the executions
   above: one workflow, one memory, one judgment across three sectors).
2. **Core rebuilt on Muse Spark — PROVEN** (endpoint, model, auth and
   timeout from the fresh export; live costs in audit rows).
3. **Two-agent architecture — PROVEN** (verify / correct / re-verify /
   fallback / alert all observed in the executions above).
4. **Three sectors live — PROVEN operationally** (real estate, clinic,
   restaurant all served in the window, including first live clinic
   content; caveat: test identities, not real customers).
5. **Arabic-native — PROVEN.** Single-copy normalization in the current
   version, consumed downstream (code evidence § above), plus normalized
   forms observed live. Implemented by Mahmoud in the editor.
6. **Never invents data — PROVEN.** Row-bound price checks in code
   (evidence § above) plus live behavior: blocked invented prices and
   honest gap answers observed. The data-load step applies read limits
   (latest customer requests capped at 5, area items capped at 20); the
   guarantee is enforced per loaded row, and the limits are a load fact,
   not a gap in the guarantee.
7. **Owner/customer separation — PROVEN** (role from the database row,
   keyword-free gate before drafting, role-gated digests, blocked
   customer digest, zero owner data sent to the customer).

## What is not claimed

- No real customers: all inspected traffic was the owner identity and one
  test identity.
- No proof beyond the stated window.
- The application document's older figures (a 227-node prototype count, a
  45-second timeout, a token cap) describe earlier states and are not
  asserted as the live state. The live state is the 24-node workflow,
  60-second timeout, and model above, read from the 2026-11-05 export.

## Known limits (facts, not verdicts)

- The data-load step caps how many rows load (latest customer requests 5,
  area items 20). This bounds volume, not correctness: the never-invents
  checks run against every loaded row.
