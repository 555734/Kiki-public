# Signalling server

Introduces two players to each other, then gets out of the way.

Once their WebRTC connection is established, all gameplay travels peer to peer
and this server sees none of it. That is the whole reason it can live in a free
tier: it never carries the traffic that would cost money.

See [`docs/netcode.md`](../../docs/netcode.md) for why the game is built this
way — in particular why the **runner's device** is the authority rather than
whoever created the room.

## What it does

```
POST /room          -> { code: "K7F2QX", ws: "wss://.../room/K7F2QX" }
WS   /room/:code    -> the signalling channel
GET  /health        -> { ok: true }
```

Messages are relayed verbatim to the other peer and never read or stored:

| message | direction | meaning |
|---|---|---|
| `{t:"joined", role, peers}` | server → peer | you are the host or the guest |
| `{t:"peer-joined", peers}` | server → host | your partner arrived; start offering |
| `{t:"offer", sdp}` | host → guest | |
| `{t:"answer", sdp}` | guest → host | |
| `{t:"ice", candidate}` | both ways | trickled ICE |
| `{t:"peer-left"}` | server → peer | the other side dropped |
| `{t:"expired"}` | server → both | the room sat empty for ten minutes |

Joining takes two optional query parameters: `?cid=<device>&role=host|guest`.
The id lets a player who is coming back be recognised — the socket they left
behind is retired on the spot rather than holding their own seat against them —
and the role is granted whenever it is free, so a returning guardian is not told
they are the host of an empty room. Without them the relay falls back to
arrival order, which is what the first half of `test.mjs` covers.

Rules: two peers per room, a third is refused; rooms expire after ten minutes
**of having nobody in them** — an occupied room re-arms its own alarm, so a game
is never hung up on from the server side, however long it runs;
messages over 64 KB are rejected. Room codes avoid vowels and `0/O/1/I` because
people read them aloud across a table.

## Running it

```bash
npm install
npm run dev      # http://localhost:8787, Durable Objects and all, offline
npm test         # exercises the room lifecycle against the local worker
```

## Deploying

**Cloudflare Workers** (what `wrangler.toml` is set up for):

```bash
npx wrangler login
npx wrangler deploy
```

The room is a Durable Object so both peers reach the same instance whichever
edge location they hit, and WebSocket hibernation means an idle room — which is
most of a session's wall-clock life — costs nothing.

**Deno Deploy** works just as well if you would rather not use Cloudflare; the
room becomes a `BroadcastChannel` keyed by the room code instead of a Durable
Object. The protocol above does not change.

## Cost

One session is two WebSocket connections, about twenty small JSON messages,
under 20 KB total, lasting roughly ten seconds.

| sessions per day | requests per day | against a 100k/day free tier |
|---|---|---|
| 10 | ~40 | 0.04% |
| 1,000 | ~4,000 | 4% |
| 25,000 | ~100,000 | at the limit |

So it stays free to somewhere around twenty thousand sessions a day. For two
people playing together it is free by a very wide margin.

Free-tier terms change, so check the current ones before standing this up.

## What is deliberately missing

**TURN.** Two players behind symmetric NATs cannot connect with STUN alone —
in practice about one pair in five. Relaying their traffic through a TURN
server is the one part of this that cannot be free, so it is not here. Until it
is, a failed connection should say "try again on the same Wi-Fi", which is
where this game is most likely to be played anyway.

**Game logic.** None, and none is planned. The moment the server holds state or
forwards gameplay, every packet becomes metered.

## これは中継サーバーでもあります

もともとは2人が直接つなぐための「待ち合わせ場所」でしたが、いまは**ゲームの通信そのもの**も
中継します。直接つなぐにはどちらかが外から届くアドレスを持っている必要があり、
家庭のルーターの内側にいる2人はどちらも持っていないためです。

部屋は中身を一切読みません。テキスト（2人の内輪の連絡）もバイナリ（ゲーム）も、
そのまま相手へ渡すだけです。上限は **1170 バイト**——EOS P2P のパケット上限に
合わせてあります。ここだけ大きくすると、EOS に差し替えたときに動かなくなるからです。

### 立て方（無料・5分）

```bash
npm install
npx wrangler login      # Cloudflare の無料アカウント
npx wrangler deploy     # → https://side-sky.<あなた>.workers.dev
```

出た URL をゲームの「中継サーバーのURL」欄に入れてください。

### 検証

```bash
npm run dev             # 別のシェルで
npm test                # 部屋のライフサイクル＋バイナリ中継
```

Godot 側からも同じサーバーに対して実地確認できます（`npm run dev` を動かしたまま）：

```bash
godot --headless --path ../.. res://test/ws_probe.tscn
```

2本の `WebSocketTransport` を実際に繋ぎ、**両方向のパケットが正しいチャネルで
無傷で届く**ことを確認します。モックではなく本物のソケット・本物の中継・本物の
フレーミングを通します。

