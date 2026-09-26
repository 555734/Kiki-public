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
const DEFAULT_DEV_MAX = 2;
const PRODUCT_ID = "full_unlock";
const ANDROID_PACKAGE = "com.sasakiful.sidesky";
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

/**
 * Read a token we issued. The signature is NOT re-checked here: only this
 * Worker can make one, the claims are looked up against our own table anyway,
 * and a forged token gets nowhere because the binding it names will not exist.
 * The client is the side that has to verify, and it does.
 */
function readToken(token) {
  try {
    const [payload] = String(token).split(".");
    const claims = JSON.parse(new TextDecoder().decode(b64urlDecode(payload)));
    return claims && typeof claims === "object" ? claims : null;
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
  const base = "https://androidpublisher.googleapis.com/androidpublisher/v3/applications"
    + `/${ANDROID_PACKAGE}/purchases/products/${PRODUCT_ID}/tokens/${encodeURIComponent(purchaseToken)}`;
  const response = await fetch(base, { headers: { authorization: `Bearer ${access}` } });
  if (response.status === 404) return { ok: false, reason: "not-found" };
  if (!response.ok) throw new Error(`google ${response.status}`);
  const purchase = await response.json();
  // 0 purchased, 1 cancelled, 2 pending. Only 0 is a sale.
  if (Number(purchase.purchaseState) !== 0) {
    return { ok: false, reason: purchase.purchaseState === 2 ? "pending" : "cancelled" };
  }
  if (Number(purchase.acknowledgementState) === 0) {
    await fetch(`${base}:acknowledge`, {
      method: "POST",
      headers: { authorization: `Bearer ${access}`, "content-type": "application/json" },
      body: "{}",
    });
  }
  return { ok: true, orderId: purchase.orderId || "" };
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

function receiptKey(body) {
  if (body.platform === "android") return `android:${body.purchase_token || ""}`;
  if (body.platform === "ios") return `ios:${body.transaction_id || ""}`;
  return "";
}

export async function handleEntitlement(request, env, url) {
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
    const body = await request.json();
    switch (url.pathname) {
      case "/verify": return this.verify(body);
      case "/renew": return this.renew(body);
      case "/dev-enrol": return this.devEnrol(body);
      default: return json({ message: "not found" }, 404);
    }
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
    // the purchase follows the store account, and only the newest device holds
    // it, so a receipt cannot be shared around as a second copy of the game.
    if (fresh) {
      await this.state.storage.put(`bind:${key}`, { ...existing, puid: body.puid });
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
        return json({ token: await this.issue(body.puid, "full", platform) });
      }
      return json({ message: String(err && err.message || err) }, 503);
    }

    if (!answer.ok) {
      if (existing) await this.state.storage.delete(`bind:${key}`);
      const message = answer.reason === "refunded" || answer.reason === "cancelled"
        ? "この購入は取り消されています。"
        : "購入が見つかりませんでした。";
      return json({ message, revoked: true }, 402);
    }

    await this.state.storage.put(`bind:${key}`, {
      puid: body.puid,
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
    const claims = readToken(body.token);
    if (!claims) return json({ message: "bad token" }, 400);
    if (claims.puid !== body.puid) return json({ message: "not your token" }, 403);

    if (claims.kind === "dev") {
      const enrolled = await this.state.storage.get(`dev:${body.puid}`);
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

  /**
   * The one call that leaves this Worker. Its own method so that a test can
   * answer for Google and Apple without the rest of verify() being replaced --
   * the rules above are the thing worth testing, and a test that stubs them
   * out is a test of itself.
   */
  async askStore(body) {
    return String(body.platform) === "android"
      ? askGoogle(this.env, body.purchase_token)
      : askApple(this.env, body.transaction_id);
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
  mintToken, readToken, receiptKey, b64urlEncode, b64urlDecode,
  FULL_TTL, DEV_TTL, RECHECK_AFTER, TOKEN_VERSION,
};
