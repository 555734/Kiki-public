/**
 * Purchase verification for the full-version unlock.
 *
 * Bolted onto the signalling Worker rather than given a Worker of its own: it
 * is three routes and a table, it is on the same free plan, and one deployment
 * is one thing to keep alive. Gameplay still never comes here -- the co-op
 * session is peer to peer over EOS. This is touched once when somebody buys,
 * and about once a month after that.
 *
 * What it does:
 *
 *   POST /entitlement/verify     a store receipt  -> a signed entitlement token
 *   POST /entitlement/renew      an old token     -> a fresher one
 *   POST /entitlement/dev-enrol  a phrase         -> a developer token
 *   POST /entitlement/review-enrol a reviewer code -> a limited review token
 *   GET  /entitlement/health     alive; with the admin secret, what it can reach
 *   GET  /entitlement/recent     the last requests (admin secret only)
 *   GET  /entitlement/apple-check the App Store credential check (admin only)
 *
 * Why a token at all, rather than the game asking "is this person allowed?"
 * every time: the answer has to work with the aeroplane mode, and it has to
 * work on the OTHER player's device, which cannot ask Apple about a purchase
 * made on Google. A short-lived signed statement travels and survives; a
 * server lookup does neither.
 *
 * Secrets live here and only here. The app ships the public half of the
 * signing key and nothing else -- no service account, no .p8, no bundle of
 * store credentials that an APK could be unzipped for.
 */

const TOKEN_VERSION = 1;
const DAY = 86400;
const FULL_TTL = 30 * DAY;
/** Short on purpose: deleting DEV_ENROL_SECRET ends developer access within a
 *  week, with no app update and nothing to recall from anybody's phone. */
const DEV_TTL = 7 * DAY;
/** How long a verified purchase is believed without asking the store again.
 *  This is the whole of the "call the store API less" requirement: a player
 *  renewing monthly costs one Google/Apple call a month, not one per launch. */
const RECHECK_AFTER = 7 * DAY;
/** How many times one purchase may be moved to a different device inside one
 *  token lifetime. A move cannot recall the token the old device still holds
 *  (the client checks tokens offline, for up to FULL_TTL), so every move leaves
 *  one more device able to play until its own token runs out. The cap bounds
 *  that: at most REBIND_LIMIT + 1 devices hold a live token for one purchase.
 *  Generous on purpose -- a reinstall is a new device id and is a real use. */
const REBIND_LIMIT = 4;
const DEFAULT_DEV_MAX = 2;
const DEFAULT_REVIEW_MAX = 5;
const PRODUCT_ID = "full_unlock";
// Both Play listings use the same product ID. Google, rather than an
// untrusted client parameter, determines which package issued a token.
const ANDROID_PACKAGES = ["com.sasakiful.melosgame", "com.sasakiful.melos"];
const IOS_BUNDLE = "com.sasakiful.sidesky";

const APPLE_PRODUCTION = "https://api.storekit.itunes.apple.com";
const APPLE_SANDBOX = "https://api.storekit-sandbox.itunes.apple.com";

function json(body, status = 200) {
  return new Response(JSON.stringify(body), {
    status,
    headers: { "content-type": "application/json", "access-control-allow-origin": "*" },
  });
}

function b64urlEncode(bytes) {
  let binary = "";
  for (const b of new Uint8Array(bytes)) binary += String.fromCharCode(b);
  return btoa(binary).replace(/\+/g, "-").replace(/\//g, "_").replace(/=+$/, "");
}

function b64urlDecode(text) {
  const padded = text.replace(/-/g, "+").replace(/_/g, "/")
    + "=".repeat((4 - (text.length % 4)) % 4);
  const binary = atob(padded);
  const out = new Uint8Array(binary.length);
  for (let i = 0; i < binary.length; i++) out[i] = binary.charCodeAt(i);
  return out;
}

function pemBody(pem) {
  return pem.replace(/-----BEGIN [^-]+-----/, "")
    .replace(/-----END [^-]+-----/, "")
    .replace(/\s+/g, "");
}

function pemToArrayBuffer(pem) {
  const raw = atob(pemBody(pem));
  const out = new Uint8Array(raw.length);
  for (let i = 0; i < raw.length; i++) out[i] = raw.charCodeAt(i);
  return out.buffer;
}

// ----------------------------------------------------------------- our token

/**
 * RSA-2048 with PKCS#1 v1.5 and SHA-256.
 *
 * Ed25519 would be the modern choice and it is not available: Godot's
 * Crypto.verify() only checks RSA, and the client is where this has to be
 * checked. The signature is over the raw payload bytes, so the client hashes
 * exactly what it decoded and there is no canonical-JSON problem to get wrong.
 */
async function signingKey(env) {
  if (!env.ENTITLEMENT_SIGNING_KEY) throw new Error("no signing key configured");
  return crypto.subtle.importKey(
    "pkcs8",
    pemToArrayBuffer(env.ENTITLEMENT_SIGNING_KEY),
    { name: "RSASSA-PKCS1-v1_5", hash: "SHA-256" },
    false,
    ["sign"],
  );
}

async function mintToken(env, { puid, kind, platform, ttl }) {
  const now = Math.floor(Date.now() / 1000);
  const payload = new TextEncoder().encode(JSON.stringify({
    v: TOKEN_VERSION,
    kind,
    puid,
    plat: platform,
    iat: now,
    exp: now + ttl,
  }));
  const signature = await crypto.subtle.sign(
    "RSASSA-PKCS1-v1_5", await signingKey(env), payload);
  return `${b64urlEncode(payload)}.${b64urlEncode(signature)}`;
}

/** The public half of the signing key, derived from the private half this
 *  Worker already holds, so there is one secret to configure and no second one
 *  to drift out of step. Kept per isolate: importing a 2048-bit key is not
 *  free and the key does not change under a running Worker. */
const publicKeys = new Map();

async function verifyKey(env) {
  const pem = env.ENTITLEMENT_SIGNING_KEY;
  if (!pem) throw new Error("no signing key configured");
  if (!publicKeys.has(pem)) {
    const priv = await crypto.subtle.importKey(
      "pkcs8", pemToArrayBuffer(pem),
      { name: "RSASSA-PKCS1-v1_5", hash: "SHA-256" }, true, ["sign"]);
    const jwk = await crypto.subtle.exportKey("jwk", priv);
    publicKeys.set(pem, await crypto.subtle.importKey(
      "jwk", { kty: "RSA", n: jwk.n, e: jwk.e, alg: "RS256", ext: true },
      { name: "RSASSA-PKCS1-v1_5", hash: "SHA-256" }, false, ["verify"]));
  }
  return publicKeys.get(pem);
}

/**
 * Check a token we issued, the way the app does: the signature over the raw
 * payload bytes, then the version, the kind, the expiry and the device. Returns
 * the claims, or null for anything that does not pass -- there is no partial
 * success.
 *
 * Reading the payload without checking the signature used to be enough
 * because renew() looks every claim up in our own table anyway. It is checked
 * here all the same: an API that accepts a signed token should not depend on
 * every future route remembering to distrust the unsigned fields.
 */
async function verifyToken(env, token) {
  try {
    const parts = String(token).split(".");
    if (parts.length !== 2) return null;
    const payload = b64urlDecode(parts[0]);
    const signature = b64urlDecode(parts[1]);
    if (payload.length === 0 || signature.length === 0) return null;
    if (!await crypto.subtle.verify(
      "RSASSA-PKCS1-v1_5", await verifyKey(env), signature, payload)) return null;
    const claims = JSON.parse(new TextDecoder().decode(payload));
    if (!claims || typeof claims !== "object") return null;
    if (claims.v !== TOKEN_VERSION) return null;
    if (claims.kind !== "full" && claims.kind !== "dev") return null;
    if (!(Number(claims.exp) > Date.now() / 1000)) return null;
    if (typeof claims.puid !== "string" || claims.puid === "") return null;
    return claims;
  } catch {
    return null;
  }
}

// ------------------------------------------------------------- Google Play

async function googleAccessToken(env) {
  const account = JSON.parse(env.GOOGLE_SERVICE_ACCOUNT);
  const now = Math.floor(Date.now() / 1000);
  const header = b64urlEncode(new TextEncoder().encode(
    JSON.stringify({ alg: "RS256", typ: "JWT" })));
  const claims = b64urlEncode(new TextEncoder().encode(JSON.stringify({
    iss: account.client_email,
    scope: "https://www.googleapis.com/auth/androidpublisher",
    aud: "https://oauth2.googleapis.com/token",
    iat: now,
    exp: now + 3600,
  })));
  const key = await crypto.subtle.importKey(
    "pkcs8",
    pemToArrayBuffer(account.private_key),
    { name: "RSASSA-PKCS1-v1_5", hash: "SHA-256" },
    false,
    ["sign"],
  );
  const signature = b64urlEncode(await crypto.subtle.sign(
    "RSASSA-PKCS1-v1_5", key, new TextEncoder().encode(`${header}.${claims}`)));

  const response = await fetch("https://oauth2.googleapis.com/token", {
    method: "POST",
    headers: { "content-type": "application/x-www-form-urlencoded" },
    body: new URLSearchParams({
      grant_type: "urn:ietf:params:oauth:grant-type:jwt-bearer",
      assertion: `${header}.${claims}.${signature}`,
    }),
  });
  if (!response.ok) throw new Error(`google auth ${response.status}`);
  return (await response.json()).access_token;
}

/**
 * Ask Google about one purchase, and acknowledge it while we are here.
 *
 * The acknowledgement is the part that is easy to leave out and expensive to
 * leave out: Google refunds any purchase nobody acknowledges within three
 * days. It is done HERE rather than on the phone because this is the first
 * moment the purchase is known to be real, and because a player who closes the
 * app on the receipt screen must not lose a game they paid for.
 */
async function askGoogle(env, purchaseToken) {
  const access = await googleAccessToken(env);
  for (const packageName of ANDROID_PACKAGES) {
    const base = "https://androidpublisher.googleapis.com/androidpublisher/v3/applications"
      + `/${packageName}/purchases/products/${PRODUCT_ID}/tokens/${encodeURIComponent(purchaseToken)}`;
    const response = await fetch(base, { headers: { authorization: `Bearer ${access}` } });
    if (response.status === 404) continue;
    if (!response.ok) throw new Error(`google ${response.status}`);
    const purchase = await response.json();
    // 0 purchased, 1 cancelled, 2 pending. Only 0 is a sale.
    if (Number(purchase.purchaseState) !== 0) {
      return { ok: false, reason: purchase.purchaseState === 2 ? "pending" : "cancelled" };
    }
    if (Number(purchase.acknowledgementState) === 0) {
      const acknowledged = await fetch(`${base}:acknowledge`, {
        method: "POST",
        headers: { authorization: `Bearer ${access}`, "content-type": "application/json" },
        body: "{}",
      });
      if (!acknowledged.ok) throw new Error(`google acknowledge ${acknowledged.status}`);
    }
    return { ok: true, orderId: purchase.orderId || "" };
  }
  return { ok: false, reason: "not-found" };
}

// ------------------------------------------------------------------- Apple

async function appleToken(env) {
  const key = await crypto.subtle.importKey(
    "pkcs8",
    pemToArrayBuffer(env.APPLE_ASC_KEY),
    { name: "ECDSA", namedCurve: "P-256" },
    false,
    ["sign"],
  );
  const now = Math.floor(Date.now() / 1000);
  const header = b64urlEncode(new TextEncoder().encode(JSON.stringify({
    alg: "ES256", kid: env.APPLE_ASC_KEY_ID, typ: "JWT",
  })));
  const claims = b64urlEncode(new TextEncoder().encode(JSON.stringify({
    iss: env.APPLE_ASC_ISSUER_ID,
    iat: now,
    exp: now + 1200,
    aud: "appstoreconnect-v1",
    bid: IOS_BUNDLE,
  })));
  const signature = b64urlEncode(await crypto.subtle.sign(
    { name: "ECDSA", hash: "SHA-256" }, key,
    new TextEncoder().encode(`${header}.${claims}`)));
  return `${header}.${claims}.${signature}`;
}

/**
 * The App Store Server API, not verifyReceipt: Apple has retired the latter,
 * and a transaction id is what StoreKit 1 gives us anyway.
 *
 * Production is asked first and sandbox second, which is Apple's own
 * recommended order and is what makes one build work for both a reviewer and a
 * paying customer without a flag deciding which store it believes in.
 */
async function askApple(env, transactionId) {
  const jwt = await appleToken(env);
  for (const base of [APPLE_PRODUCTION, APPLE_SANDBOX]) {
    const response = await fetch(
      `${base}/inApps/v1/transactions/${encodeURIComponent(transactionId)}`,
      { headers: { authorization: `Bearer ${jwt}` } });
    console.log(`apple ${base === APPLE_SANDBOX ? "sandbox" : "production"} `
      + `transaction ${transactionId}: ${response.status}`);
    if (response.status === 404) continue;
    if (!response.ok) throw new Error(`apple ${response.status}`);
    const body = await response.json();
    // The transaction comes back as a JWS that Apple signed. We read the
    // payload rather than re-verifying the chain: it arrived over TLS from an
    // endpoint that required our own private key to talk to at all. Verifying
    // the x5c chain as well would be stricter and is noted in
    // docs/monetization.md as the thing to add if this is ever exposed more
    // widely than one product id.
    const claims = JSON.parse(new TextDecoder().decode(
      b64urlDecode(String(body.signedTransactionInfo).split(".")[1])));
    if (claims.productId !== PRODUCT_ID) return { ok: false, reason: "wrong-product" };
    if (claims.revocationDate) return { ok: false, reason: "refunded" };
    return { ok: true, orderId: String(claims.originalTransactionId || transactionId) };
  }
  return { ok: false, reason: "not-found" };
}

// --------------------------------------------------------------- the routes

// An iOS purchase is keyed by its ORIGINAL transaction id. StoreKit 1 hands
// every restore a brand-new transaction id, so keying by transaction_id made a
// reinstall's restore a stranger to its own purchase. For the purchase itself
// the two ids are the same, so rows written before this change still match.
function receiptKey(body) {
  if (body.platform === "android") return `android:${body.purchase_token || ""}`;
  if (body.platform === "ios") {
    return `ios:${body.original_transaction_id || body.transaction_id || ""}`;
  }
  return "";
}

// A health check of everything purchase verification depends on, for CI to
// run after every deploy and for whoever is debugging a purchase:
//
//   apple    asks Apple about a transaction that cannot exist: 404 means the
//            key works; 401 means it is the wrong key or issuer
//   google   gets a Play API token and asks about a purchase token that cannot
//            exist, for every package: 400/404 means the service account is
//            accepted for that app; 401/403 means it is not
//   signing  the sha256 of the public half of ENTITLEMENT_SIGNING_KEY, to
//            compare with the app's entitlement_key.json
//
// Nothing secret is returned: statuses, which settings are absent, and a
// public-key fingerprint.
export async function appleCheck(env) {
  const missing = ["APPLE_ASC_KEY", "APPLE_ASC_KEY_ID", "APPLE_ASC_ISSUER_ID"]
    .filter((name) => !env[name]);
  if (missing.length) return { ok: false, missing };
  let jwt;
  try {
    jwt = await appleToken(env);
  } catch (err) {
    return { ok: false, key: `unusable: ${String(err && err.name || "error")}` };
  }
  const statuses = {};
  for (const [name, base] of [["production", APPLE_PRODUCTION], ["sandbox", APPLE_SANDBOX]]) {
    try {
      const response = await fetch(`${base}/inApps/v1/transactions/2000000000000000`,
        { headers: { authorization: `Bearer ${jwt}` } });
      statuses[name] = response.status;
    } catch {
      statuses[name] = "unreachable";
    }
  }
  const ok = Object.values(statuses).every((s) => s === 404);
  return { ok, statuses };
}

export async function googleCheck(env) {
  if (!env.GOOGLE_SERVICE_ACCOUNT) return { ok: false, missing: ["GOOGLE_SERVICE_ACCOUNT"] };
  let access;
  try {
    access = await googleAccessToken(env);
  } catch (err) {
    return { ok: false, auth: String(err && err.message || err) };
  }
  const statuses = {};
  for (const packageName of ANDROID_PACKAGES) {
    try {
      const response = await fetch("https://androidpublisher.googleapis.com/androidpublisher/v3/"
        + `applications/${packageName}/purchases/products/${PRODUCT_ID}/tokens/health-check-token`,
      { headers: { authorization: `Bearer ${access}` } });
      statuses[packageName] = response.status;
    } catch {
      statuses[packageName] = "unreachable";
    }
  }
  // Every package must accept the account: askGoogle stops at the first
  // package that answers anything but 404, so one refusing package breaks all.
  const ok = Object.values(statuses).every((s) => s === 400 || s === 404 || s === 410);
  return { ok, statuses };
}

export async function signingCheck(env) {
  if (!env.ENTITLEMENT_SIGNING_KEY) return { ok: false, missing: ["ENTITLEMENT_SIGNING_KEY"] };
  try {
    const priv = await crypto.subtle.importKey("pkcs8",
      pemToArrayBuffer(env.ENTITLEMENT_SIGNING_KEY),
      { name: "RSASSA-PKCS1-v1_5", hash: "SHA-256" }, true, ["sign"]);
    const jwk = await crypto.subtle.exportKey("jwk", priv);
    const pub = await crypto.subtle.importKey("jwk",
      { kty: "RSA", n: jwk.n, e: jwk.e, alg: "RS256", ext: true },
      { name: "RSASSA-PKCS1-v1_5", hash: "SHA-256" }, true, ["verify"]);
    const spki = await crypto.subtle.exportKey("spki", pub);
    const digest = new Uint8Array(await crypto.subtle.digest("SHA-256", spki));
    const sha256 = [...digest].map((b) => b.toString(16).padStart(2, "0")).join("");
    return { ok: true, public_key_sha256: sha256 };
  } catch (err) {
    return { ok: false, key: `unusable: ${String(err && err.name || "error")}` };
  }
}

export async function health(env) {
  const [apple, google, signing] = await Promise.all(
    [appleCheck(env), googleCheck(env), signingCheck(env)]);
  return { ok: apple.ok && google.ok && signing.ok, apple, google, signing };
}

/** Constant-time comparison of two strings, by way of their digests so that
 *  neither the content nor the length of the secret shows in the timing. */
async function sameSecret(given, secret) {
  const digest = async (text) => new Uint8Array(
    await crypto.subtle.digest("SHA-256", new TextEncoder().encode(text)));
  const [a, b] = await Promise.all([digest(given), digest(secret)]);
  let difference = 0;
  for (let i = 0; i < a.length; i++) difference |= a[i] ^ b[i];
  return difference === 0;
}

/**
 * The operator's routes -- the store connectivity checks and the record of
 * recent purchase requests -- are for whoever holds ENTITLEMENT_ADMIN_SECRET.
 * Left open they let anybody spend our Apple and Google API quota and read
 * when purchases are being made. With no secret configured they stay closed.
 */
async function isAdmin(request, env) {
  if (!env.ENTITLEMENT_ADMIN_SECRET) return false;
  const given = (request.headers.get("authorization") || "").replace(/^Bearer\s+/i, "");
  return given !== "" && await sameSecret(given, env.ENTITLEMENT_ADMIN_SECRET);
}

export async function handleEntitlement(request, env, url) {
  if (request.method === "GET" && url.pathname === "/entitlement/health") {
    // Anybody may ask whether the Worker is up; only the operator may ask what
    // it can reach, which spends store API calls and names missing settings.
    if (!await isAdmin(request, env)) return json({ alive: true });
    return json(await health(env));
  }
  if (request.method === "GET" && ["/entitlement/apple-check", "/entitlement/recent"].includes(url.pathname)) {
    if (!await isAdmin(request, env)) return json({ message: "unauthorized" }, 401);
    if (url.pathname === "/entitlement/apple-check") return json(await appleCheck(env));
    if (!env.ENTITLEMENTS) return json({ message: "entitlements not configured" }, 503);
    const stub = env.ENTITLEMENTS.get(env.ENTITLEMENTS.idFromName("global"));
    return stub.fetch("https://entitlement.local/recent");
  }
  if (request.method !== "POST") return json({ message: "method not allowed" }, 405);
  let body;
  try {
    body = await request.json();
  } catch {
    return json({ message: "bad request" }, 400);
  }
  const puid = String(body.puid || "").slice(0, 64);
  if (!puid) return json({ message: "no device id" }, 400);
  if (!env.ENTITLEMENTS) return json({ message: "entitlements not configured" }, 503);

  const id = env.ENTITLEMENTS.idFromName("global");
  const route = url.pathname.slice("/entitlement/".length);
  return env.ENTITLEMENTS.get(id).fetch("https://entitlement.local/" + route, {
    method: "POST",
    headers: { "content-type": "application/json" },
    body: JSON.stringify({ ...body, puid }),
  });
}

/**
 * One instance, named "global", holding two small tables:
 *
 *   bind:<platform>:<receipt>  -> { puid, checkedAt, orderId }
 *   dev:<puid>                 -> { boundAt }
 *
 * A single instance rather than one per player because the tables are tiny and
 * because the duplicate check has to see everybody: the whole point of
 * bind:<receipt> is noticing that one purchase is being presented by a second
 * device.
 */
export class Entitlements {
  constructor(state, env) {
    this.state = state;
    this.env = env;
  }

  async fetch(request) {
    const url = new URL(request.url);
    if (url.pathname === "/recent") {
      return json({ recent: (await this.state.storage.get("recent")) || [] });
    }
    const body = await request.json();
    let response;
    switch (url.pathname) {
      case "/verify": response = await this.verify(body); break;
      case "/renew": response = await this.renew(body); break;
      case "/dev-enrol": response = await this.devEnrol(body); break;
      case "/review-enrol": response = await this.reviewEnrol(body); break;
      default: return json({ message: "not found" }, 404);
    }
    await this.remember(url.pathname, body, response);
    return response;
  }

  // The last few requests, kept so a failed purchase or restore on someone's
  // phone can be read back afterwards (GET /entitlement/recent) instead of
  // having to be watched live. Nothing identifying: the route, the platform,
  // the last four digits of the ids, and what was answered.
  async remember(route, body, response) {
    const tail = (v) => (v ? `…${String(v).slice(-4)}` : "");
    let answer = {};
    try { answer = await response.clone().json(); } catch { /* not JSON */ }
    const entry = {
      at: new Date().toISOString(),
      route,
      platform: String(body.platform || ""),
      transaction: tail(body.transaction_id || body.purchase_token),
      original: tail(body.original_transaction_id),
      status: response.status,
      outcome: answer.token ? "token" : String(answer.message || ""),
      apple: this.lastApple || "",
    };
    this.lastApple = "";
    const recent = (await this.state.storage.get("recent")) || [];
    recent.unshift(entry);
    await this.state.storage.put("recent", recent.slice(0, 30));
  }

  /**
   * Whether the purchase may move to `puid` now, and the moves it has made
   * inside the last token lifetime. A purchase that is already on `puid` is
   * not moving, however often it is asked about.
   */
  moves(existing, puid) {
    const now = Math.floor(Date.now() / 1000);
    const recent = ((existing && existing.moves) || []).filter((t) => now - t < FULL_TTL);
    const moving = !!existing && existing.puid !== puid;
    return { recent, moving, blocked: moving && recent.length >= REBIND_LIMIT };
  }

  tooManyMoves() {
    return json({
      message: "この購入は短い間に何度も別の端末へ移されています。しばらくしてからお試しください。",
    }, 429);
  }

  /** Point the purchase at `puid`, recording the move if it is one. */
  async bind(key, existing, puid, fields) {
    const { recent, moving } = this.moves(existing, puid);
    if (moving) recent.push(Math.floor(Date.now() / 1000));
    await this.state.storage.put(`bind:${key}`, { ...(existing || {}), ...fields, puid, moves: recent });
  }

  async verify(body) {
    const key = receiptKey(body);
    if (!key) return json({ message: "unknown platform" }, 400);
    const platform = String(body.platform);

    const existing = await this.state.storage.get(`bind:${key}`);
    const fresh = existing
      && Date.now() / 1000 - existing.checkedAt < RECHECK_AFTER;

    // The same receipt arriving from a different device is a reinstall or a
    // new phone, which is allowed and is the whole of "機種変更". It rebinds:
    // the purchase follows the store account, and the newest device is the one
    // the server renews for.
    //
    // What a move does NOT do is take the token off the device it left: the app
    // checks a token's signature offline and it stays good until it expires
    // (FULL_TTL), which is what lets the game run on a plane. So "one purchase,
    // one device" holds for renewal, not for the days a token has left, and the
    // honest limit is REBIND_LIMIT moves per token lifetime rather than a
    // promise the server cannot keep. Asked before the store is, so a refused
    // move costs no Google or Apple call.
    if (this.moves(existing, body.puid).blocked) return this.tooManyMoves();

    if (fresh) {
      await this.bind(key, existing, body.puid, {});
      return json({ token: await this.issue(body.puid, "full", platform) });
    }

    let answer;
    try {
      answer = await this.askStore(body);
    } catch (err) {
      // The store's own API is unreachable. If we have ever verified this
      // receipt, say yes on the strength of that; otherwise say "try later"
      // rather than "you did not buy this", because we do not know that.
      if (existing) {
        await this.bind(key, existing, body.puid, {});
        return json({ token: await this.issue(body.puid, "full", platform) });
      }
      return json({ message: String(err && err.message || err) }, 503);
    }

    if (!answer.ok) {
      console.log(`verify ${key}: refused (${answer.reason})`);
      if (existing) await this.state.storage.delete(`bind:${key}`);
      const message = answer.reason === "refunded" || answer.reason === "cancelled"
        ? "この購入は取り消されています。"
        : "購入が見つかりませんでした。";
      return json({ message, revoked: true }, 402);
    }

    await this.bind(key, existing, body.puid, {
      orderId: answer.orderId,
      checkedAt: Math.floor(Date.now() / 1000),
    });
    return json({ token: await this.issue(body.puid, "full", platform) });
  }

  /**
   * Extend a token without asking a store anything, which is what keeps the
   * store API call count to roughly one per purchase per month.
   */
  async renew(body) {
    const claims = await verifyToken(this.env, body.token);
    if (!claims) return json({ message: "bad token" }, 400);
    if (claims.puid !== body.puid) return json({ message: "not your token" }, 403);

    if (claims.kind === "dev") {
      const enrolled = await this.state.storage.get(`dev:${body.puid}`)
        || await this.state.storage.get(`review:${body.puid}`);
      // The revocation path for developers: the row is gone, so the token
      // simply stops being renewed and expires by itself within the week.
      if (!enrolled) return json({ revoked: true });
      return json({ token: await this.issue(body.puid, "dev", claims.plat || "") });
    }

    const entries = await this.state.storage.list({ prefix: "bind:" });
    for (const [key, value] of entries) {
      if (value.puid !== body.puid) continue;
      const platform = key.slice("bind:".length).split(":")[0];
      const stale = Date.now() / 1000 - value.checkedAt >= RECHECK_AFTER;
      if (!stale) return json({ token: await this.issue(body.puid, "full", platform) });
      // Long enough since the last look to be worth asking whether it has been
      // refunded in the meantime.
      return this.verify({
        puid: body.puid,
        platform,
        purchase_token: platform === "android" ? key.slice(`bind:android:`.length) : "",
        transaction_id: platform === "ios" ? key.slice(`bind:ios:`.length) : "",
      });
    }
    return json({ revoked: true });
  }

  /**
   * Bind a developer's device.
   *
   * The phrase is a Worker secret and is in no build, no repository and no
   * screenshot. The cap is what makes a leak survivable: the third device to
   * present the phrase is refused, so a phrase that escapes buys one stranger
   * a copy at most, and `wrangler secret delete DEV_ENROL_SECRET` plus
   * deleting these rows ends it within DEV_TTL.
   */
  async devEnrol(body) {
    if (!this.env.DEV_ENROL_SECRET) {
      return json({ message: "developer enrolment is closed" }, 403);
    }
    if (String(body.phrase || "") !== this.env.DEV_ENROL_SECRET) {
      return json({ message: "そのコードは使えません。" }, 403);
    }
    const already = await this.state.storage.get(`dev:${body.puid}`);
    if (!already) {
      const rows = await this.state.storage.list({ prefix: "dev:" });
      const max = Number(this.env.DEV_ENROL_MAX) || DEFAULT_DEV_MAX;
      if (rows.size >= max) {
        return json({ message: "開発者の登録枠がいっぱいです。" }, 403);
      }
      await this.state.storage.put(`dev:${body.puid}`, {
        boundAt: Math.floor(Date.now() / 1000),
      });
    }
    return json({ token: await this.issue(body.puid, "dev", String(body.platform || "")) });
  }

  /** Reviewer access is separate from the two developer slots. It is
   * explicitly documented in Play Console and can be revoked without an app
   * update. The code is a Worker secret, never embedded in the app bundle. */
  async reviewEnrol(body) {
    if (!this.env.REVIEW_ENROL_SECRET) {
      return json({ message: "review enrolment is closed" }, 403);
    }
    if (String(body.phrase || "") !== this.env.REVIEW_ENROL_SECRET) {
      return json({ message: "そのコードは使えません。" }, 403);
    }
    const key = `review:${body.puid}`;
    if (!await this.state.storage.get(key)) {
      const rows = await this.state.storage.list({ prefix: "review:" });
      const max = Number(this.env.REVIEW_ENROL_MAX) || DEFAULT_REVIEW_MAX;
      if (rows.size >= max) {
        return json({ message: "審査用の登録枠がいっぱいです。" }, 403);
      }
      await this.state.storage.put(key, { boundAt: Math.floor(Date.now() / 1000) });
    }
    return json({ token: await this.issue(body.puid, "dev", String(body.platform || "")) });
  }

  /**
   * The one call that leaves this Worker. Its own method so that a test can
   * answer for Google and Apple without the rest of verify() being replaced --
   * the rules above are the thing worth testing, and a test that stubs them
   * out is a test of itself.
   */
  async askStore(body) {
    if (String(body.platform) === "android") {
      return askGoogle(this.env, body.purchase_token);
    }
    // The original id first: it is the one Apple's server API is sure to
    // know. The restore's own id is only a fallback (an app from before the
    // plugin reported original_transaction_id sends nothing else).
    const ids = [...new Set([body.original_transaction_id, body.transaction_id]
      .filter((id) => id))];
    let answer = { ok: false, reason: "not-found" };
    const seen = [];
    try {
      for (const id of ids) {
        answer = await askApple(this.env, id);
        seen.push(`${answer.ok ? "ok" : answer.reason}`);
        if (answer.ok || answer.reason !== "not-found") break;
      }
    } catch (err) {
      seen.push(`error: ${String(err && err.message || err)}`);
      throw err;
    } finally {
      this.lastApple = seen.join(", ");
    }
    return answer;
  }

  async issue(puid, kind, platform) {
    return mintToken(this.env, {
      puid,
      kind,
      platform,
      ttl: kind === "dev" ? DEV_TTL : FULL_TTL,
    });
  }
}

export const _internals = {
  mintToken, verifyToken, receiptKey, b64urlEncode, b64urlDecode,
  FULL_TTL, DEV_TTL, RECHECK_AFTER, TOKEN_VERSION, REBIND_LIMIT,
};
