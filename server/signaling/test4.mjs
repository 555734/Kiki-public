/**
 * The four-peer versus room, against a locally running worker.
 *
 *   npm run dev     # in one shell
 *   node test4.mjs  # in another
 *
 * The cooperative room refuses a third peer and forwards every message to
 * everyone. A versus room has to do neither: it seats four, gives each of them
 * a stable index, and routes by a destination byte. Those are the things that
 * are invisible until four real devices fail to meet, so they are checked here
 * rather than trusted.
 */
const BASE = process.env.SIGNALLING_URL ?? "http://localhost:8787";
const BROADCAST = 0xff;

let failures = 0;
function check(ok, what) {
  console.log(`  ${ok ? "ok  " : "FAIL"}  ${what}`);
  if (!ok) failures++;
}

/**
 * Both kinds of message are queued the moment the socket exists: the control
 * JSON the room sends, and the binary frames the peers send each other. A
 * listener attached later has already missed them -- a WebSocket has no
 * backlog, and the room announces a join while the joiner is still connecting.
 */
function connect(url) {
  const ws = new WebSocket(url);
  ws.binaryType = "arraybuffer";
  const control = [];
  const frames = [];
  let waitingControl = null;
  let waitingFrame = null;
  ws.addEventListener("message", (e) => {
    if (typeof e.data === "string") {
      const msg = JSON.parse(e.data);
      if (waitingControl) { const w = waitingControl; waitingControl = null; w(msg); }
      else control.push(msg);
      return;
    }
    const bytes = new Uint8Array(e.data);
    if (waitingFrame) { const w = waitingFrame; waitingFrame = null; w(bytes); }
    else frames.push(bytes);
  });
  const next = (queue, setWaiting) => () =>
    new Promise((resolve, reject) => {
      if (queue.length) return resolve(queue.shift());
      const timer = setTimeout(() => reject(new Error("timed out")), 4000);
      setWaiting((m) => { clearTimeout(timer); resolve(m); });
    });
  ws.nextControl = next(control, (f) => { waitingControl = f; });
  ws.nextFrame = next(frames, (f) => { waitingFrame = f; });
  ws.pendingFrames = () => frames.length;
  ws.opened = new Promise((resolve, reject) => {
    ws.addEventListener("open", resolve);
    ws.addEventListener("error", reject);
  });
  return ws;
}

const wsBase = BASE.replace(/^http/, "ws");
const code = "V" + Math.floor(Math.random() * 90000 + 10000);
const join = (cid) => connect(`${wsBase}/room4/${code}?cid=${cid}`);

const sleep = (ms) => new Promise((r) => setTimeout(r, ms));

/** Opens a socket to a full room and reports whether it was turned away. */
function refused(url) {
  const ws = new WebSocket(url);
  return new Promise((resolve) => {
    const timer = setTimeout(() => resolve(false), 3000);
    const no = () => { clearTimeout(timer); resolve(true); };
    const yes = () => { clearTimeout(timer); resolve(false); };
    ws.addEventListener("error", no, { once: true });
    ws.addEventListener("close", no, { once: true });
    ws.addEventListener("message", yes, { once: true });
  });
}

async function main() {
  console.log(`versus relay room ${code}`);

  const peers = [];
  const joined = [];
  for (let i = 0; i < 4; i++) {
    const ws = join(`dev-${i}`);
    await ws.opened;
    peers.push(ws);
    joined.push(await ws.nextControl());
    // Drain the peer-joined notices the earlier sockets get, so later reads
    // are not answering an older question.
    // The earlier sockets each get a peer-joined notice; let them land so a
    // later read is not answering an older question.
    await sleep(60);
  }

  check(joined.length === 4, "four peers were let in");
  const indices = joined.map((j) => j.index);
  check(JSON.stringify(indices) === "[0,1,2,3]",
    `and given the indices 0,1,2,3 (got ${indices.join(",")})`);
  check(joined[0].role === "host", "the first peer is the host");
  check(joined.every((j) => j.cap === 4), "and every one of them is told the room holds four");

  // A fifth is refused, exactly as a third is in a co-op room. Node's fetch
  // will not send an Upgrade header by hand, so this opens a real socket and
  // expects it to fail -- the same way test.mjs checks the co-op limit.
  check(await refused(`${wsBase}/room4/${code}`), "a fifth peer is turned away");

  // Addressed delivery: peer 0 -> peer 2 only.
  const directed = new Uint8Array([2, 42, 7, 7, 7]);
  peers[0].send(directed);
  const got2 = await peers[2].nextFrame();
  check(got2[0] === 0, "a directed frame arrives stamped with the SENDER's index");
  check(got2[1] === 42 && got2[4] === 7, "with the rest of it untouched");
  await sleep(120);
  check(peers[1].pendingFrames() === 0 && peers[3].pendingFrames() === 0,
    "and nobody else receives it");

  // Broadcast reaches the other three and not the sender.
  const shout = new Uint8Array([BROADCAST, 99, 1]);
  peers[1].send(shout);
  const a = await peers[0].nextFrame();
  const b = await peers[2].nextFrame();
  const c = await peers[3].nextFrame();
  check(a[0] === 1 && b[0] === 1 && c[0] === 1,
    "a broadcast reaches the other three, stamped with the sender");
  await sleep(120);
  check(peers[1].pendingFrames() === 0, "and does not come back to the sender");

  // Losing one and coming back reclaims the same index, which is what makes a
  // seat survive a reconnect.
  peers[2].close();
  await sleep(200);
  const again = join("dev-2");
  await again.opened;
  const back = await again.nextControl();
  check(back.index === 2, `a returning peer reclaims index 2 (got ${back.index})`);

  // The co-op room is untouched: still two, still no routing byte.
  const coop = [connect(`${wsBase}/room/${code}`), null];
  await coop[0].opened;
  await coop[0].nextControl();
  coop[1] = connect(`${wsBase}/room/${code}`);
  await coop[1].opened;
  const guest = await coop[1].nextControl();
  check(guest.role === "guest", "a cooperative room still seats a host and a guest");
  check(await refused(`${wsBase}/room/${code}`), "and still refuses a third");

  for (const p of [...peers, again, ...coop]) { try { p.close(); } catch {} }
  console.log(failures === 0 ? "\nversus relay: all checks passed"
    : `\nversus relay: ${failures} FAILED`);
  process.exit(failures === 0 ? 0 : 1);
}

main().catch((e) => { console.error(e); process.exit(1); });
