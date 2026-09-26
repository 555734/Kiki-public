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
import { Entitlements, _internals } from "./entitlement.js";

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
  const claims = _internals.readToken(token);
  check(claims.v === _internals.TOKEN_VERSION && claims.kind === "full"
    && claims.puid === "device-a", "and carries the version, the kind and the device");
  check(claims.exp - claims.iat === _internals.FULL_TTL,
    "a purchase token lasts 30 days, so the game works on a plane");
  const devToken = await _internals.mintToken(env,
    { puid: "device-a", kind: "dev", platform: "android", ttl: _internals.DEV_TTL });
  const devClaims = _internals.readToken(devToken);
  check(devClaims.exp - devClaims.iat === _internals.DEV_TTL,
    "a developer token lasts a week, so withdrawing it needs no app update");
  check(_internals.readToken("nonsense") === null, "junk is not a token");

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

  console.log(failures === 0
    ? "entitlement worker tests: all checks passed"
    : `entitlement worker tests: ${failures} failed`);
  process.exit(failures === 0 ? 0 : 1);
}

main();
