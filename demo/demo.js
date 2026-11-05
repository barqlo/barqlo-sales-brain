// barqlo Sales Brain — offline demo of the two-agent core loop.
//
// Production: one n8n workflow calls Meta's Muse Spark
// (api.meta.ai/v1/chat/completions, model muse-spark-1.3) to DRAFT every reply,
// then a deterministic verifier checks the draft against the tenant's real data
// before anything is sent. This demo replaces ONLY the LLM draft step with a
// deterministic stand-in so it runs offline with no keys. The normalize,
// verify, correct-once, role-gate and audit logic mirrors production's shape.
//
// Run: node demo/demo.js   (Node 18+, no dependencies, no network)

'use strict';

const fs = require('fs');
const path = require('path');

const DATA = JSON.parse(
  fs.readFileSync(path.join(__dirname, 'sample-data.json'), 'utf8')
);

// ---------------------------------------------------------------------------
// 1. Arabic normalization — runs BEFORE any matching, exactly as in production.
//    Hamza/alef variants are one letter, ة/ه are one, ى/ي are one.
// ---------------------------------------------------------------------------
function normalizeArabic(text) {
  return String(text)
    .replace(/[أإآٱ]/g, 'ا')
    .replace(/ة/g, 'ه')
    .replace(/ى/g, 'ي')
    .replace(/[\u064B-\u0652\u0670]/g, '') // diacritics
    .replace(/ـ/g, '') // tatweel
    .replace(/\s+/g, ' ')
    .trim();
}

// ---------------------------------------------------------------------------
// 2. Identity — from the channel row only, never from what the sender claims.
// ---------------------------------------------------------------------------
function resolveIdentity(channelId, senderId) {
  const channel = DATA.channels.find((c) => c.id === channelId);
  if (!channel) return { role: 'customer', tenant: null, reason: 'unknown-channel' };
  const tenant = DATA.tenants.find((t) => t.id === channel.tenant_id);
  const role =
    tenant && senderId === tenant.owner_sender_id ? 'owner' : 'customer';
  return { role, tenant, reason: 'channel-row' };
}

// ---------------------------------------------------------------------------
// 3. Draft — deterministic stand-in for the Muse Spark draft call.
//    Scenario 3 deliberately drafts an invented price to exercise the verifier.
// ---------------------------------------------------------------------------
// Token match that ignores the definite article: "المشويات" matches "مشويات".
function tokens(text) {
  return normalizeArabic(text)
    .replace(/[؟?.,!]/g, ' ')
    .split(' ')
    .filter(Boolean)
    .map((w) => w.replace(/^ال/, ''));
}

function mentionsItem(normalized, itemName) {
  const input = new Set(tokens(normalized));
  return tokens(itemName).every((t) => input.has(t));
}

function draftReply(normalized, tenant, scenario) {
  if (scenario === 'flawed-draft') {
    return 'عندنا سوشي، وسعره 999 جنيه.';
  }
  const item = tenant.items.find((i) => mentionsItem(normalized, i.name));
  if (item) {
    return `${item.name} — ${item.available ? 'متاح' : 'غير متاح'} / السعر ${item.price} جنيه.`;
  }
  return 'الصنف اللي حضرتك سالت عنه مش موجود ضمن الاصناف المرفقه عندي دلوقتي، ومقدرش اقول سعره. تحب اساعدك بصنف تاني؟';
}

function draftOwnerDigest(tenant) {
  const available = tenant.items.filter((i) => i.available).length;
  return (
    `ملخص اليوم التشغيلي: اجمالي الاصناف المسجله: ${tenant.items.length} / ` +
    `المتاح منها: ${available} / الخدمات التشغيليه المسجله: ${tenant.services.length} / ` +
    `ملاحظه شفافيه: بيانات المبيعات والايراد اليومي غير مذكوره في البيانات المرفقه.`
  );
}

// ---------------------------------------------------------------------------
// 4. Deterministic verification — fixed rules, not model judgment.
// ---------------------------------------------------------------------------
function verifyDraft(draft, tenant) {
  const failures = [];
  // price_real: every "N جنيه" in the draft must match a real item price.
  const prices = [...draft.matchAll(/(\d+)\s*جنيه/g)].map((m) => Number(m[1]));
  const realPrices = tenant.items.map((i) => i.price);
  for (const p of prices) {
    if (!realPrices.includes(p)) failures.push(`price_real: ${p} not in data`);
  }
  // no_all_from_sample: "الكل" claims require citing every item.
  if (/الكل/.test(draft)) {
    const cited = tenant.items.filter((i) => draft.includes(i.name)).length;
    if (cited < tenant.items.length) failures.push('no_all_from_sample');
  }
  // counts_match: a cited item count must equal the database total.
  const countMatch = draft.match(/اجمالي الاصناف المسجله: (\d+)/);
  if (countMatch && Number(countMatch[1]) !== tenant.items.length) {
    failures.push('counts_match');
  }
  return failures;
}

// ---------------------------------------------------------------------------
// 5. One correction — strip unverified prices, add an honesty note, re-verify.
// ---------------------------------------------------------------------------
function correctOnce(draft, tenant, normalized) {
  // If the asked item is not in the data, the only honest correction is the
  // gap-honest reply — no price, no availability claim.
  const item = tenant.items.find((i) => mentionsItem(normalized, i.name));
  if (!item) {
    return 'الصنف اللي حضرتك سالت عنه مش موجود ضمن الاصناف المرفقه عندي دلوقتي، ومقدرش اقول سعره. تحب اساعدك بصنف تاني؟';
  }
  const realPrices = tenant.items.map((i) => i.price);
  return draft.replace(/(\d+)\s*جنيه/g, (m, n) =>
    realPrices.includes(Number(n)) ? m : 'السعر غير مذكور في البيانات المرفقه'
  );
}

const FALLBACK =
  'المعلومه دي مش متوفره في البيانات الحاليه عندي. تحب اساعدك في حاجه تانيه من اللي عندنا؟';

// ---------------------------------------------------------------------------
// 6. One turn through the pipeline.
// ---------------------------------------------------------------------------
function runTurn({ label, channelId, senderId, text, scenario }) {
  const normalized = normalizeArabic(text);
  const { role, tenant } = resolveIdentity(channelId, senderId);
  let draft;
  let corrected = false;
  let failures = [];

  // Role gate runs BEFORE drafting: owner-only content is never drafted for customers.
  const isDigestRequest = /ملخص/.test(normalized);
  if (isDigestRequest && role !== 'owner') {
    draft = '(no draft: role gate — owner content is never drafted for customers)';
    console.log(`\n### ${label}\ninput: ${text}\nrole: ${role}\nverdict: blocked (role gate)\nreply: ${FALLBACK}`);
    console.log(JSON.stringify({ scenario: label, role, verdict: 'blocked', corrected: false, audit: 'owner_alert=false, fallback sent, no owner data in reply' }));
    return;
  }

  draft = isDigestRequest ? draftOwnerDigest(tenant) : draftReply(normalized, tenant, scenario);
  const firstFailures = verifyDraft(draft, tenant);

  let verdict = 'allowed';
  if (firstFailures.length > 0) {
    draft = correctOnce(draft, tenant, normalized);
    corrected = true;
    failures = verifyDraft(draft, tenant);
    verdict = failures.length > 0 ? 'blocked' : 'allowed';
  }

  const reply = verdict === 'allowed' ? draft : FALLBACK;
  console.log(`\n### ${label}\ninput: ${text}\nrole: ${role}\ndraft: ${draft}\nverdict: ${verdict}${corrected ? ' (corrected once)' : ''}\nreply: ${reply}`);
  console.log(JSON.stringify({
    scenario: label, role, verdict, corrected,
    checks_failed_first_pass: firstFailures.length,
    audit: 'verdict recorded, cost=0 (offline demo), no owner data leaked to customers',
  }));
}

// ---------------------------------------------------------------------------
// Scenarios — all data fabricated; nothing here touches a live system.
// ---------------------------------------------------------------------------
const CHANNEL = DATA.channels[0].id;
const CUSTOMER = 'sender-demo-customer';
const OWNER = DATA.tenants[0].owner_sender_id;

runTurn({ label: '1-real-price', channelId: CHANNEL, senderId: CUSTOMER, text: 'بكام المشويات المشكله؟' });
runTurn({ label: '2-gap-honesty', channelId: CHANNEL, senderId: CUSTOMER, text: 'عندكم سوشي؟ بكام؟' });
runTurn({ label: '3-flawed-draft-corrected', channelId: CHANNEL, senderId: CUSTOMER, text: 'عندكم سوشي؟ بكام؟', scenario: 'flawed-draft' });
runTurn({ label: '4a-digest-as-customer', channelId: CHANNEL, senderId: CUSTOMER, text: 'ابعتلي ملخص النهارده' });
runTurn({ label: '4b-digest-as-owner', channelId: CHANNEL, senderId: OWNER, text: 'ابعتلي ملخص النهارده' });

console.log('\nDone. All scenarios ran offline: no keys, no network, no live data.');
