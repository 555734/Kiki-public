/**
 * The entitlement rules, without a network and without a store.
 *
 *   node entitlement.test.mjs
 *
 * Unlike test.mjs this needs no running worker: the Durable Object is driven
 * directly with a fake storage map, and Google and Apple are replaced by a
 * function that answers however the test needs. That is deliberate -- the
 * things worth testing here are the RULES (one purchase, one device; a refund
 * revokes; a store outage does not; two developers and no more), and every one
 * of them is a decision this file makes rather than something a store tells us.
 *
 * What it cannot test is whether the real Google and Apple calls are shaped
 * correctly. Nothing off-device can. See docs/monetization.md for the list of
 * things only a real store account proves.
 */
import { webcrypto } from "node:crypto";
import { Entitlements, _internals, appleCheck, googleCheck, signingCheck, handleEntitlement } from "./entitlement.js";

if (!globalThis.crypto) globalThis.crypto = webcrypto;

let failures = 0;
function check(ok, what) {
  console.log(`  ${ok ? "ok  " : "FAIL"}  ${what}`);
  if (!ok) failures++;
}

/** The smallest thing that behaves like Durable Object storage. */
function fakeStorage() {
  const map = new Map();
  return {
    map,
    async get(key) { return map.get(key); },
    async put(key, value) { map.set(key, value); },
    async delete(key) { map.delete(key); },
    async list({ prefix }) {
      const out = new Map();
      for (const [key, value] of map) if (key.startsWith(prefix)) out.set(key, value);
      return out;
    },
  };
}

async function makeKeyPem() {
  const pair = await webcrypto.subtle.generateKey(
    { name: "RSASSA-PKCS1-v1_5", modulusLength: 2048,
      publicExponent: new Uint8Array([1, 0, 1]), hash: "SHA-256" },
    true, ["sign", "verify"]);
  const pkcs8 = Buffer.from(await webcrypto.subtle.exportKey("pkcs8", pair.privateKey));
  const spki = Buffer.from(await webcrypto.subtle.exportKey("spki", pair.publicKey));
  const wrap = (body, label) =>
    `-----BEGIN ${label}-----\n${body.toString("base64").replace(/(.{64})/g, "$1\n")}\n-----END ${label}-----\n`;
  return {
    privatePem: wrap(pkcs8, "PRIVATE KEY"),
    publicKey: pair.publicKey,
  };
}

function post(body) {
  return { json: async () => body };
}

async function main() {
  const { privatePem, publicKey } = await makeKeyPem();
  const env = { ENTITLEMENT_SIGNING_KEY: privatePem, DEV_ENROL_SECRET: "open-sesame" };

  // --- the token itself ----------------------------------------------------
  const token = await _internals.mintToken(env,
    { puid: "device-a", kind: "full", platform: "android", ttl: _internals.FULL_TTL });
  const [payload, signature] = token.split(".");
  check(
    await webcrypto.subtle.verify("RSASSA-PKCS1-v1_5", publicKey,
      _internals.b64urlDecode(signature), _internals.b64urlDecode(payload)),
    "a minted token verifies against the public half of the signing key");
  const claims = await _internals.verifyToken(env, token);
  check(claims.v === _internals.TOKEN_VERSION && claims.kind === "full"
    && claims.puid === "device-a", "and carries the version, the kind and the device");
  check(claims.exp - claims.iat === _internals.FULL_TTL,
    "a purchase token lasts 30 days, so the game works on a plane");
  const devToken = await _internals.mintToken(env,
    { puid: "device-a", kind: "dev", platform: "android", ttl: _internals.DEV_TTL });
  const devClaims = await _internals.verifyToken(env, devToken);
  check(devClaims.exp - devClaims.iat === _internals.DEV_TTL,
    "a developer token lasts a week, so withdrawing it needs no app update");
  check(await _internals.verifyToken(env, "nonsense") === null, "junk is not a token");

  // The Worker checks what it is handed as the app does, not just reads it.
  const other = await makeKeyPem();
  const foreign = await _internals.mintToken({ ENTITLEMENT_SIGNING_KEY: other.privatePem },
    { puid: "device-a", kind: "full", platform: "android", ttl: _internals.FULL_TTL });
  check(await _internals.verifyToken(env, foreign) === null,
    "a token signed with some other key is refused");
  const forged = `${_internals.b64urlEncode(new TextEncoder().encode(JSON.stringify(
    { ...claims, puid: "device-z" })))}.${signature}`;
  check(await _internals.verifyToken(env, forged) === null,
    "a token whose payload was edited after signing is refused");
  const expired = await _internals.mintToken(env,
    { puid: "device-a", kind: "full", platform: "android", ttl: -60 });
  check(await _internals.verifyToken(env, expired) === null, "an expired token is refused");
  const odd = await _internals.mintToken(env,
    { puid: "device-a", kind: "root", platform: "android", ttl: 600 });
  check(await _internals.verifyToken(env, odd) === null, "a token of an unknown kind is refused");
  check(await _internals.verifyToken(env, `${token}.extra`) === null,
    "a token with extra parts is refused");
  const nobody = await _internals.mintToken(env,
    { puid: "", kind: "full", platform: "android", ttl: 600 });
  check(await _internals.verifyToken(env, nobody) === null, "a token naming nobody is refused");

  // --- one purchase, one device -------------------------------------------
  let storeAnswer = { ok: true, orderId: "GPA.1" };
  let storeCalls = 0;
  const storage = fakeStorage();
  const unit = new Entitlements({ storage }, env);
  // Only the call that leaves the Worker is replaced. Everything the rules
  // depend on -- the binding table, the recheck window, the outage branch --
  // is the shipped code.
  unit.askStore = async function () {
    storeCalls++;
    if (storeAnswer.outage) throw new Error("store unreachable");
    return storeAnswer;
  };

  const receipt = { platform: "android", purchase_token: "tok-1", puid: "device-a" };
  let answer = await (await unit.verify(receipt)).json();
  check(!!answer.token, "a real purchase produces a token");
  check(storeCalls === 1, "and asked the store exactly once");

  await unit.verify(receipt);
  check(storeCalls === 1,
    "asking again inside the recheck window does not call the store again");

  // A new phone with the same store account presents the same receipt.
  await unit.verify({ ...receipt, puid: "device-b" });
  check(storage.map.get("bind:android:tok-1").puid === "device-b",
    "the same receipt on a new device moves the purchase to it");
  check(storage.map.size === 1,
    "and does not become a second copy of the game");

  // A move leaves the old device's token alive: the app checks it offline for
  // up to FULL_TTL. What the server can do is stop renewing it, and stop the
  // purchase being walked across more than REBIND_LIMIT devices.
  const tokenOnA = (await (await unit.verify({ ...receipt, puid: "device-a" })).json()).token;
  const tokenOnB = (await (await unit.verify({ ...receipt, puid: "device-b" })).json()).token;
  check(!!await _internals.verifyToken(env, tokenOnA),
    "the token the old device holds still verifies after the purchase moves");
  const renewOld = await (await unit.renew({ token: tokenOnA, puid: "device-a" })).json();
  check(renewOld.revoked === true, "but the old device is no longer renewed");
  check(!!(await (await unit.renew({ token: tokenOnB, puid: "device-b" })).json()).token,
    "and the device the purchase moved to is");
  storeCalls = 0;
  const walked = fakeStorage();
  const walker = new Entitlements({ storage: walked }, env);
  walker.askStore = unit.askStore;
  const walking = { platform: "android", purchase_token: "tok-walk" };
  await walker.verify({ ...walking, puid: "w0" });
  let moved = 0;
  for (let i = 1; i <= _internals.REBIND_LIMIT; i++) {
    if ((await walker.verify({ ...walking, puid: `w${i}` })).ok) moved++;
  }
  check(moved === _internals.REBIND_LIMIT, "a purchase can move REBIND_LIMIT times");
  storeCalls = 0;
  walked.map.get("bind:android:tok-walk").checkedAt = 0;
  const beyond = await walker.verify({ ...walking, puid: "w-extra" });
  check(beyond.status === 429 && walked.map.get("bind:android:tok-walk").puid === `w${_internals.REBIND_LIMIT}`,
    "the next move is refused and the purchase stays where it was");
  check(storeCalls === 0, "and a refused move costs no store call");
  check((await walker.verify({ ...walking, puid: `w${_internals.REBIND_LIMIT}` })).ok,
    "the device that holds it can still ask, however often");
  for (const t of walked.map.get("bind:android:tok-walk").moves.keys()) {
    walked.map.get("bind:android:tok-walk").moves[t] -= _internals.FULL_TTL + 1;
  }
  check((await walker.verify({ ...walking, puid: "w-later" })).ok,
    "moves older than a token lifetime no longer count");

  // The operator's routes need the admin secret; the public one only says it is up.
  const adminEnv = { ...env, ENTITLEMENT_ADMIN_SECRET: "let-me-in" };
  const ask = (path, headers = {}, e = adminEnv) => handleEntitlement(
    new Request(`https://x.test${path}`, { headers }), e, new URL(`https://x.test${path}`));
  const publicHealth = await (await ask("/entitlement/health")).json();
  check(publicHealth.alive === true && publicHealth.signing === undefined,
    "the public health check says only that the Worker is up");
  const wrongHealth = await (await ask("/entitlement/health", { authorization: "Bearer nope" })).json();
  check(wrongHealth.signing === undefined, "and so does one with the wrong secret");
  const adminHealth = await (await ask("/entitlement/health",
    { authorization: "Bearer let-me-in" })).json();
  check(adminHealth.signing && adminHealth.signing.ok === true,
    "the admin secret opens the full report");
  check((await ask("/entitlement/recent")).status === 401, "recent requests need the secret");
  check((await ask("/entitlement/apple-check")).status === 401, "so does the Apple check");
  check((await ask("/entitlement/recent", { authorization: "Bearer let-me-in" })).status === 503,
    "with it, they are answered (503 here: no Durable Object in this test)");
  check((await ask("/entitlement/recent", { authorization: "Bearer let-me-in" }, env)).status === 401,
    "with no secret configured the routes stay closed, whatever is sent");

  // --- refunds -------------------------------------------------------------
  storeAnswer = { ok: false, reason: "refunded" };
  storage.map.get("bind:android:tok-1").checkedAt = 0;
  const refunded = await unit.verify({ ...receipt, puid: "device-b" });
  check(refunded.status === 402 && (await refunded.json()).revoked === true,
    "a refunded purchase is revoked");
  check(!storage.map.has("bind:android:tok-1"), "and its binding is forgotten");

  // --- the store being down is not a refund --------------------------------
  storeAnswer = { ok: true, orderId: "GPA.2" };
  await unit.verify({ platform: "android", purchase_token: "tok-2", puid: "device-c" });
  storage.map.get("bind:android:tok-2").checkedAt = 0;
  storeAnswer = { ok: false, outage: true };
  const duringOutage = await unit.verify(
    { platform: "android", purchase_token: "tok-2", puid: "device-c" });
  check(duringOutage.ok && !!(await duringOutage.json()).token,
    "a buyer keeps playing while the store's API is unreachable");
  const strangerDuringOutage = await unit.verify(
    { platform: "android", purchase_token: "never-seen", puid: "device-d" });
  check(strangerDuringOutage.status === 503,
    "but an unseen receipt during an outage is 'try later', not 'you bought it'");

  // --- iOS: a reinstall's restore -----------------------------------------
  // StoreKit 1 gives every restore a NEW transaction id; the purchase is its
  // original. The binding is keyed by the original, so a restore finds it.
  storeAnswer = { ok: true, orderId: "1000000001" };
  storeCalls = 0;
  const bought = { platform: "ios", transaction_id: "1000000001",
    original_transaction_id: "1000000001", puid: "phone-1" };
  check(!!(await (await unit.verify(bought)).json()).token, "an iOS purchase produces a token");
  const restored = { platform: "ios", transaction_id: "2000000099",
    original_transaction_id: "1000000001", puid: "phone-1-reinstalled" };
  const restoredAnswer = await (await unit.verify(restored)).json();
  check(!!restoredAnswer.token && storeCalls === 1,
    "a restore after reinstalling finds the purchase by its original id");
  check(storage.map.get("bind:ios:1000000001").puid === "phone-1-reinstalled",
    "and the purchase moves to the reinstalled app");
  check(_internals.receiptKey({ platform: "ios", transaction_id: "1000000001" })
      === "ios:1000000001",
    "a purchase recorded before the original id was sent keeps its key");

  // Apple is asked with the original id first, and the restore's own id only
  // if Apple does not know the original.
  const ec = await webcrypto.subtle.generateKey(
    { name: "ECDSA", namedCurve: "P-256" }, true, ["sign", "verify"]);
  const pkcs8 = Buffer.from(await webcrypto.subtle.exportKey("pkcs8", ec.privateKey));
  const ascPem = `-----BEGIN PRIVATE KEY-----\n${pkcs8.toString("base64")}\n-----END PRIVATE KEY-----`;
  const apple = new Entitlements({ storage: fakeStorage() },
    { ...env, APPLE_ASC_KEY: ascPem, APPLE_ASC_KEY_ID: "K", APPLE_ASC_ISSUER_ID: "I" });
  const asked = [];
  const realFetch = globalThis.fetch;
  const signed = (claims) => ({ signedTransactionInfo:
    `x.${_internals.b64urlEncode(new TextEncoder().encode(JSON.stringify(claims)))}.y` });
  globalThis.fetch = async (url) => {
    const id = decodeURIComponent(String(url).split("/").pop());
    asked.push(id);
    if (id === "1000000001") {
      return new Response(JSON.stringify(signed(
        { productId: "full_unlock", originalTransactionId: "1000000001" })), { status: 200 });
    }
    return new Response("{}", { status: 404 });
  };
  const viaOriginal = await apple.askStore(restored);
  check(viaOriginal.ok && asked[0] === "1000000001",
    "Apple is asked about the original transaction first");
  asked.length = 0;
  const swapped = await apple.askStore({ platform: "ios",
    original_transaction_id: "3000000000", transaction_id: "1000000001" });
  check(swapped.ok && asked.includes("1000000001"),
    "and about the restore's own id when Apple does not know the original");
  asked.length = 0;
  const nowhere = await apple.askStore({ platform: "ios", transaction_id: "4000000000" });
  check(!nowhere.ok && nowhere.reason === "not-found",
    "an id Apple knows nowhere is not found");
  // The credential check: Apple's 404 for a made-up id means the key works.
  globalThis.fetch = async () => new Response("{}", { status: 404 });
  const good = await appleCheck(apple.env);
  check(good.ok && good.statuses.production === 404, "apple-check passes with a working key");
  globalThis.fetch = async () => new Response("{}", { status: 401 });
  const bad = await appleCheck(apple.env);
  check(!bad.ok && bad.statuses.sandbox === 401, "and reports Apple's 401 for a wrong key");
  const none = await appleCheck(env);
  check(!none.ok && none.missing.includes("APPLE_ASC_KEY"), "and names a missing setting");
  globalThis.fetch = realFetch;

  // --- health: the signing key's public half, and a missing Google account --
  const signing = await signingCheck(env);
  const spki = new Uint8Array(await webcrypto.subtle.exportKey("spki", publicKey));
  const expected = Buffer.from(await webcrypto.subtle.digest("SHA-256", spki)).toString("hex");
  check(signing.ok && signing.public_key_sha256 === expected,
    "health reports the fingerprint of the signing key's public half");
  check(!(await signingCheck({})).ok, "and a missing signing key");
  const noGoogle = await googleCheck({});
  check(!noGoogle.ok && noGoogle.missing.includes("GOOGLE_SERVICE_ACCOUNT"),
    "and a missing Google service account");

  // --- the record of recent requests ---------------------------------------
  const logged = new Entitlements({ storage: fakeStorage() }, env);
  logged.askStore = async () => ({ ok: false, reason: "not-found" });
  await logged.fetch(new Request("https://entitlement.local/verify", { method: "POST",
    body: JSON.stringify({ platform: "ios", transaction_id: "2000000099",
      original_transaction_id: "1000000001", puid: "p" }) }));
  const recent = (await (await logged.fetch(
    new Request("https://entitlement.local/recent"))).json()).recent;
  check(recent.length === 1 && recent[0].status === 402 && recent[0].transaction === "…0099"
      && recent[0].original === "…0001" && !JSON.stringify(recent).includes("1000000001"),
    "a refused restore is recorded, with only the ids' last digits");

  // --- developers ----------------------------------------------------------
  const clean = fakeStorage();
  const dev = new Entitlements({ storage: clean }, { ...env, DEV_ENROL_MAX: 2 });
  check((await (await dev.devEnrol({ phrase: "wrong", puid: "d1" })).json()).message !== undefined,
    "a wrong phrase enrols nobody");
  check(!!(await (await dev.devEnrol({ phrase: "open-sesame", puid: "d1" })).json()).token,
    "the phrase enrols the first developer");
  check(!!(await (await dev.devEnrol({ phrase: "open-sesame", puid: "d2" })).json()).token,
    "and the second");
  const third = await dev.devEnrol({ phrase: "open-sesame", puid: "d3" });
  check(third.status === 403, "the third device is refused, so a leaked phrase is bounded");
  check(!!(await (await dev.devEnrol({ phrase: "open-sesame", puid: "d1" })).json()).token,
    "an already-enrolled developer can re-enrol on the same device");

  const closed = new Entitlements({ storage: fakeStorage() },
    { ENTITLEMENT_SIGNING_KEY: privatePem });
  check((await closed.devEnrol({ phrase: "open-sesame", puid: "d1" })).status === 403,
    "deleting DEV_ENROL_SECRET closes enrolment with no app update");

  const devTok = await dev.issue("d1", "dev", "android");
  const renewed = await dev.renew({ token: devTok, puid: "d1" });
  check(!!(await renewed.json()).token, "an enrolled developer's token renews");
  await clean.delete("dev:d1");
  const revoked = await dev.renew({ token: devTok, puid: "d1" });
  check((await revoked.json()).revoked === true,
    "deleting the row stops the renewal, so developer access expires within the week");

  const notYours = await dev.renew({ token: devTok, puid: "somebody-else" });
  check(notYours.status === 403, "a token presented by a different device is refused");

  // Reviewer access has its own limit and does not consume developer slots.
  const review = new Entitlements({ storage: clean },
    { ...env, REVIEW_ENROL_SECRET: "review-only", REVIEW_ENROL_MAX: 2 });
  check((await review.reviewEnrol({ phrase: "wrong", puid: "r1" })).status === 403,
    "a wrong reviewer code grants nothing");
  const reviewerAnswer = await (await review.reviewEnrol(
    { phrase: "review-only", puid: "r1" })).json();
  check(!!reviewerAnswer.token && !!(await (await review.renew(
    { token: reviewerAnswer.token, puid: "r1" })).json()).token,
    "a reviewer receives a renewable signed entitlement");
  await review.reviewEnrol({ phrase: "review-only", puid: "r2" });
  check((await review.reviewEnrol({ phrase: "review-only", puid: "r3" })).status === 403,
    "reviewer registration stops at its separate device cap");

  console.log(failures === 0
    ? "entitlement worker tests: all checks passed"
    : `entitlement worker tests: ${failures} failed`);
  process.exit(failures === 0 ? 0 : 1);
}

main();
