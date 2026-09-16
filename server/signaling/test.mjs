/**
 * Exercises the room lifecycle against a locally running worker.
 *
 *   npm run dev     # in one shell
 *   npm test        # in another
 *
 * Checks the things that are easy to get wrong and invisible until two real
 * phones fail to meet: that the second peer is told it is the guest, that the
 * host is told when its partner arrives, that messages reach the other side
 * unmodified, that a third peer is refused, and that a departure is announced.
 */
const BASE = process.env.SIGNALLING_URL ?? "http://localhost:8787";

let failures = 0;
function check(ok, what) {
  console.log(`  ${ok ? "ok  " : "FAIL"}  ${what}`);
  if (!ok) failures++;
}
/**
 * Sockets are wrapped in a queue the moment they are created, because messages
 * that arrive before a listener is attached are simply gone -- there is no
 * backlog on a WebSocket. The server announces "peer-joined" to the host while
 * the *guest* is still connecting, so a test that waits for it afterwards misses
 * it every time. Real clients have to be written the same way round.
 */
function connect(url) {
  const ws = new WebSocket(url);
  const queue = [];
  let waiting = null;
  ws.addEventListener("message", (e) => {
    const msg = JSON.parse(e.data);
    if (waiting) { const w = waiting; waiting = null; w(msg); } else { queue.push(msg); }
  });
  ws.next = () =>
    new Promise((resolve, reject) => {
      if (queue.length) return resolve(queue.shift());
      const timer = setTimeout(() => reject(new Error("timed out waiting for a message")), 4000);
      waiting = (m) => { clearTimeout(timer); resolve(m); };
    });
  ws.opened = new Promise((resolve, reject) => {
    ws.addEventListener("open", resolve, { once: true });
    ws.addEventListener("error", reject, { once: true });
  });
  // Attached at creation, for the same reason the message queue is: a close
  // that lands while the test is awaiting something else has no backlog to sit
  // in, and a listener added afterwards never hears it.
  ws.closed = new Promise((resolve) => {
    ws.addEventListener("close", () => resolve(true), { once: true });
    ws.addEventListener("error", () => resolve(true), { once: true });
  });
  return ws;
}
const next = (ws) => ws.next();
const closedWithin = (ws, ms) =>
  Promise.race([ws.closed, new Promise((r) => setTimeout(() => r(false), ms))]);

const health = await (await fetch(`${BASE}/health`)).json();
check(health.ok === true, "GET /health");

const room = await (await fetch(`${BASE}/room`, { method: "POST" })).json();
check(/^[2-9A-HJ-NP-Z]{6}$/.test(room.code), `POST /room returns a readable code (${room.code})`);

const wsUrl = `${BASE.replace(/^http/, "ws")}/room/${room.code}`;
const host = connect(wsUrl);
await host.opened;
check((await next(host)).role === "host", "the first peer is the host");

const guest = connect(wsUrl);
await guest.opened;
const guestHello = await next(guest);
check(guestHello.role === "guest", "the second peer is the guest");
check(guestHello.peers === 2, "the guest is told the room now holds two");
check((await next(host)).t === "peer-joined", "the host is told its partner arrived");

// Relay, in both directions, unmodified.
const offer = { t: "offer", sdp: "v=0\r\no=- 1 2 IN IP4 127.0.0.1\r\n" };
host.send(JSON.stringify(offer));
check(JSON.stringify(await next(guest)) === JSON.stringify(offer), "offer reaches the guest intact");
const answer = { t: "answer", sdp: "v=0\r\na=answer\r\n" };
guest.send(JSON.stringify(answer));
check(JSON.stringify(await next(host)) === JSON.stringify(answer), "answer reaches the host intact");

// A third peer must be refused rather than silently joining and confusing the
// two who are already negotiating. Node's fetch will not let us send an
// Upgrade header by hand, so this opens a real socket and expects it to fail.
const third = new WebSocket(wsUrl);
const thirdOutcome = await new Promise((resolve) => {
  const timer = setTimeout(() => resolve("accepted"), 3000);
  third.addEventListener("error", () => { clearTimeout(timer); resolve("refused"); }, { once: true });
  third.addEventListener("close", () => { clearTimeout(timer); resolve("refused"); }, { once: true });
  third.addEventListener("message", () => { clearTimeout(timer); resolve("accepted"); }, { once: true });
});
check(thirdOutcome === "refused", `a third peer is refused (got "${thirdOutcome}")`);

guest.close();
check((await next(host)).t === "peer-left", "the host is told when the guest leaves");
host.close();

// --- binary relay ---------------------------------------------------------
// The room began as a place for two peers to exchange SDP before connecting
// directly. It now carries the game itself, because a direct connection needs
// one side to have a reachable address and two people in different houses
// generally do not. So the bytes have to survive the trip untouched, and the
// ceiling has to actually stop an oversized one.
//
// connect() above parses every message as JSON, which binary is not, so these
// use their own socket.
function connectRaw(url) {
  const ws = new WebSocket(url);
  ws.binaryType = "arraybuffer";
  const queue = [];
  let waiting = null;
  ws.addEventListener("message", (e) => {
    if (waiting) { const w = waiting; waiting = null; w(e.data); } else { queue.push(e.data); }
  });
  ws.nextRaw = () =>
    new Promise((resolve, reject) => {
      if (queue.length) return resolve(queue.shift());
      const timer = setTimeout(() => reject(new Error("timed out")), 4000);
      waiting = (m) => { clearTimeout(timer); resolve(m); };
    });
  ws.opened = new Promise((resolve, reject) => {
    ws.addEventListener("open", resolve, { once: true });
    ws.addEventListener("error", reject, { once: true });
  });
  return ws;
}

const binRoom = await (await fetch(`${BASE}/room`, { method: "POST" })).json();
const binUrl = `${BASE.replace(/^http/, "ws")}/room/${binRoom.code}`;
const binA = connectRaw(binUrl);
await binA.opened;
await binA.nextRaw();                       // "joined"
const binB = connectRaw(binUrl);
await binB.opened;
await binB.nextRaw();                       // "joined"
await binA.nextRaw();                       // "peer-joined"

const sent = new Uint8Array([0, 13, 255, 1, 2, 3, 128, 64]);
binA.send(sent);
const got = new Uint8Array(await binB.nextRaw());
check(got.length === sent.length && got.every((v, i) => v === sent[i]),
  "a binary game packet arrives byte for byte");

const back = new Uint8Array([9, 8, 7]);
binB.send(back);
const echoed = new Uint8Array(await binA.nextRaw());
check(echoed.length === 3 && echoed[0] === 9 && echoed[2] === 7,
  "and the relay is symmetric");

// The cap matches EOS P2P's packet size so the two transports stay
// interchangeable; a relay that accepted more would work here and fail there.
binA.send(new Uint8Array(1171));
const refusal = JSON.parse(await binA.nextRaw());
check(refusal.t === "error" && /too large/.test(refusal.reason ?? ""),
  "an oversized packet is refused");

let leaked = false;
binB.addEventListener("message", () => { leaked = true; });
await new Promise((r) => setTimeout(r, 250));
check(!leaked, "and never reaches the other peer");

binA.close();
binB.close();

// --- coming back to a room you are already in ------------------------------
// The failure this covers is the one that made a player force-quit the game:
// a phone whose link died leaves a socket the server has not noticed, the room
// holds exactly two, and the returning player is refused by their own ghost.
const backRoom = await (await fetch(`${BASE}/room`, { method: "POST" })).json();
const backUrl = `${BASE.replace(/^http/, "ws")}/room/${backRoom.code}`;

// Roles are stated here. Without a stated role the relay falls back to arrival
// order, which the first half of this file covers.
const runner = connect(`${backUrl}?cid=runner-1&role=host`);
await runner.opened;
const runnerHello = await next(runner);
check(runnerHello.role === "host" && runnerHello.granted === true,
  "a device that asks to be the host is made the host");

const godGhost = connect(`${backUrl}?cid=god-1&role=guest`);
await godGhost.opened;
const ghostHello = await next(godGhost);
check(ghostHello.role === "guest" && ghostHello.granted === true,
  "and one that asks to be the guest is made the guest");
await next(runner);                                   // peer-joined

// The guardian's phone goes into a pocket. The socket is still open as far as
// the server knows, so the room is full -- and this is the moment that used to
// be unrecoverable.
const godAgain = connect(`${backUrl}?cid=god-1&role=guest`);
await godAgain.opened;
const againHello = await next(godAgain);
check(againHello.role === "guest",
  `the same player coming back is let in, as the guest (got "${againHello.role}")`);
check(againHello.granted === true, "with the role they asked for");

// What matters is that the ghost is out of the way, not the exact moment its
// close frame lands -- a server-initiated close is best effort. So this asserts
// the effects the game depends on: the new socket carries the traffic and the
// old one carries none.
let ghostHeard = false;
godGhost.addEventListener("message", () => { ghostHeard = true; });
runner.send(JSON.stringify({ t: "ping-after-return" }));
const afterReturn = await next(godAgain);
check(afterReturn.t === "ping-after-return",
  "and the returning socket is the one that now carries the traffic");
await new Promise((r) => setTimeout(r, 400));
check(!ghostHeard, "while the socket they left behind receives nothing");

// The ghost's eventual close must not be announced as the partner leaving:
// that player is already back.
let falseDeparture = false;
runner.addEventListener("message", (e) => {
  if (JSON.parse(e.data).t === "peer-left") falseDeparture = true;
});
await new Promise((r) => setTimeout(r, 600));
check(!falseDeparture, "and its departure is not reported as the partner leaving");

// The seat is still one seat: a genuinely different third device is refused.
const stranger = new WebSocket(`${backUrl}?cid=stranger-1&role=guest`);
const strangerOutcome = await new Promise((resolve) => {
  const timer = setTimeout(() => resolve("accepted"), 3000);
  stranger.addEventListener("error", () => { clearTimeout(timer); resolve("refused"); }, { once: true });
  stranger.addEventListener("close", () => { clearTimeout(timer); resolve("refused"); }, { once: true });
  stranger.addEventListener("message", () => { clearTimeout(timer); resolve("accepted"); }, { once: true });
});
check(strangerOutcome === "refused",
  `a different device is still refused (got "${strangerOutcome}")`);

runner.close();
godAgain.close();

// --- a room does not hang up on a game that is still being played ----------
// The room used to close itself ten minutes after the first player arrived,
// whatever was happening inside it. Run against a worker whose idle window is
// a few seconds (see npm run dev:fast) this watches a room live through
// several of them while its two players are still there.
const IDLE_MS = Number(process.env.ROOM_IDLE_MS ?? 0);
if (IDLE_MS > 0) {
  const longRoom = await (await fetch(`${BASE}/room`, { method: "POST" })).json();
  const longUrl = `${BASE.replace(/^http/, "ws")}/room/${longRoom.code}`;
  const a = connect(`${longUrl}?cid=long-a&role=host`);
  await a.opened; await next(a);
  const b = connect(`${longUrl}?cid=long-b&role=guest`);
  await b.opened; await next(b); await next(a);

  // The observable is the "expired" the room sends on its way out, not the
  // socket's readyState: a server-initiated close is best effort here and can
  // sit unflushed for seconds, so readyState stays OPEN through an expiry that
  // really did happen. The message is what actually arrives.
  let expired = false;
  for (const ws of [a, b]) {
    ws.addEventListener("message", (e) => {
      if (JSON.parse(e.data).t === "expired") expired = true;
    });
  }
  const survive = IDLE_MS * 3 + 1500;
  await new Promise((r) => setTimeout(r, survive));
  check(!expired, `the room did not expire under the players after ${survive}ms `
    + `(${(survive / IDLE_MS).toFixed(1)}x the idle window)`);

  a.send(JSON.stringify({ t: "still-here" }));
  const heard = await next(b);
  check(heard.t === "still-here", `and the room still relays (got "${heard.t}")`);
  a.close(); b.close();
} else {
  console.log("  --    room-expiry check skipped (set ROOM_IDLE_MS to run it)");
}

console.log(failures === 0 ? "\nall signalling checks passed" : `\n${failures} FAILED`);
process.exit(failures === 0 ? 1 * 0 : 1);