/**
 * SIDE / SKY signalling / relay server.
 *
 * Rooms are intentionally public: the shipped game must be able to reach them
 * without embedding a reusable secret in the client. Public source therefore
 * must not rely on hiding this endpoint. Instead, the edge applies a per-IP
 * connection-attempt limit before a request reaches a room Durable Object.
 */

const DEFAULT_ROOM_IDLE_MS = 10 * 60 * 1000;
const MAX_PEERS = 2;
const MAX_MESSAGE_BYTES = 1170;
const CODE_ALPHABET = "23456789ABCDEFGHJKLMNPQRSTUVWXYZ";
const CODE_LENGTH = 6;

// Abuse guard. Normal play uses only a handful of room connections, including
// reconnects. Thirty attempts per minute leaves a large safety margin for a
// household/NAT while preventing one IP from cheaply creating unbounded room
// traffic. Both values can be overridden as Worker environment variables.
const DEFAULT_RATE_WINDOW_MS = 60 * 1000;
const DEFAULT_RATE_MAX = 30;

function newRoomCode() {
  const bytes = crypto.getRandomValues(new Uint8Array(CODE_LENGTH));
  let out = "";
  for (const b of bytes) out += CODE_ALPHABET[b % CODE_ALPHABET.length];
  return out;
}

function json(body, status = 200) {
  return new Response(JSON.stringify(body), {
    status,
    headers: { "content-type": "application/json", "access-control-allow-origin": "*" },
  });
}

function clientIp(request) {
  // Cloudflare supplies CF-Connecting-IP in production. The fallbacks keep
  // wrangler/miniflare tests usable without weakening production behaviour.
  return request.headers.get("CF-Connecting-IP")
    || (request.headers.get("x-forwarded-for") || "").split(",")[0].trim()
    || "local-dev";
}

async function rateLimitResponse(request, env) {
  if (!env?.RATE_LIMITER) return null;

  const id = env.RATE_LIMITER.idFromName(clientIp(request));
  const response = await env.RATE_LIMITER.get(id).fetch("https://rate.local/check", {
    method: "POST",
  });
  if (response.status !== 429) return null;

  return json({ error: "too many connection attempts; try again shortly" }, 429);
}

export default {
  async fetch(request, env) {
    const url = new URL(request.url);

    if (request.method === "OPTIONS") {
      return new Response(null, {
        headers: {
          "access-control-allow-origin": "*",
          "access-control-allow-methods": "GET, POST, OPTIONS",
          "access-control-allow-headers": "content-type",
        },
      });
    }

    if (url.pathname === "/health") return json({ ok: true });

    // Any endpoint that can allocate or attach to a room is rate limited. The
    // check happens before touching ROOMS, so rejected abuse does not create a
    // room Durable Object or hold a WebSocket open.
    const roomPath = url.pathname.match(/^\/room\/([A-Z0-9]{4,12})$/);
    if ((url.pathname === "/room" && request.method === "POST") || roomPath) {
      const limited = await rateLimitResponse(request, env);
      if (limited) return limited;
    }

    // Legacy HTTP room creation endpoint. The current game generates its own
    // six-character code, but keeping this route preserves compatibility with
    // older test clients.
    if (url.pathname === "/room" && request.method === "POST") {
      const code = newRoomCode();
      return json({ code, ws: `${url.origin.replace(/^http/, "ws")}/room/${code}` });
    }

    if (roomPath) {
      const id = env.ROOMS.idFromName(roomPath[1]);
      return env.ROOMS.get(id).fetch(request);
    }

    return json({ error: "not found" }, 404);
  },
};

/** A socket that has been replaced by its own player returning. */
function isRetired(ws) {
  const att = ws.deserializeAttachment() || {};
  return att.retired === true;
}

export class RateLimiter {
  constructor(state, env) {
    this.state = state;
    this.windowMs = Number(env?.RATE_LIMIT_WINDOW_MS) || DEFAULT_RATE_WINDOW_MS;
    this.max = Number(env?.RATE_LIMIT_MAX) || DEFAULT_RATE_MAX;
  }

  async fetch(request) {
    if (request.method !== "POST") return json({ error: "method not allowed" }, 405);

    const now = Date.now();
    let bucket = await this.state.storage.get("bucket");
    if (!bucket || now - bucket.startedAt >= this.windowMs) {
      bucket = { startedAt: now, count: 0 };
    }

    if (bucket.count >= this.max) {
      await this.state.storage.setAlarm(now + this.windowMs * 2);
      return json({ error: "rate limited" }, 429);
    }

    bucket.count += 1;
    await this.state.storage.put("bucket", bucket);
    await this.state.storage.setAlarm(now + this.windowMs * 2);
    return new Response(null, { status: 204 });
  }

  async alarm() {
    await this.state.storage.deleteAll();
  }
}

export class Room {
  constructor(state, env) {
    this.state = state;
    this.idleMs = Number(env?.ROOM_IDLE_MS) || DEFAULT_ROOM_IDLE_MS;
  }

  async fetch(request) {
    if (request.headers.get("Upgrade") !== "websocket") {
      return json({ error: "expected a websocket upgrade" }, 426);
    }
    const url = new URL(request.url);
    const cid = (url.searchParams.get("cid") || "").slice(0, 32);
    const askedFor = url.searchParams.get("role");
    const wanted = askedFor === "host" || askedFor === "guest" ? askedFor : null;

    let existing = this.state.getWebSockets();

    if (cid) {
      for (const peer of existing) {
        const att = peer.deserializeAttachment() || {};
        if (att.cid !== cid) continue;
        peer.serializeAttachment({ role: null, cid: null, retired: true });
        try { peer.close(4001, "replaced by the same player"); } catch (e) { /* already gone */ }
      }
      existing = this.state.getWebSockets().filter((p) => !isRetired(p));
    }

    if (existing.length >= MAX_PEERS) {
      return json({ error: "room is full" }, 409);
    }

    const taken = new Set(existing.map((p) => (p.deserializeAttachment() || {}).role));
    const free = ["host", "guest"].filter((r) => !taken.has(r));
    const role = wanted && free.includes(wanted) ? wanted : free[0];

    const pair = new WebSocketPair();
    const [client, server] = Object.values(pair);
    this.state.acceptWebSocket(server);

    server.serializeAttachment({ role, cid });
    server.send(JSON.stringify({
      t: "joined", role, peers: existing.length + 1,
      granted: role === wanted,
    }));

    for (const peer of existing) {
      peer.send(JSON.stringify({ t: "peer-joined", peers: existing.length + 1 }));
    }

    await this.state.storage.setAlarm(Date.now() + this.idleMs);
    return new Response(null, { status: 101, webSocket: client });
  }

  /** Forward verbatim to the other peer, text or binary, unread. */
  webSocketMessage(ws, message) {
    const size = typeof message === "string" ? message.length : message.byteLength;
    if (size > MAX_MESSAGE_BYTES) {
      ws.send(JSON.stringify({ t: "error", reason: "message too large" }));
      return;
    }
    for (const peer of this.state.getWebSockets()) {
      if (peer !== ws && !isRetired(peer)) peer.send(message);
    }
  }

  webSocketError(ws) {
    this.webSocketClose(ws);
  }

  async alarm() {
    const live = this.state.getWebSockets().filter((p) => !isRetired(p));
    if (live.length > 0) {
      await this.state.storage.setAlarm(Date.now() + this.idleMs);
      return;
    }
    await this.state.storage.deleteAll();
  }

  async webSocketClose(ws) {
    if (isRetired(ws)) return;
    for (const peer of this.state.getWebSockets()) {
      if (peer !== ws && !isRetired(peer)) peer.send(JSON.stringify({ t: "peer-left" }));
    }
  }
}
