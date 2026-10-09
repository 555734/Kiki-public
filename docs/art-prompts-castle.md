# 1-9「THE KING'S ROAD」素材生成プロンプト

画像生成 AI（ChatGPT など）に投げるプロンプト集。**20 枚**。
出来たものを zip で渡してもらえれば、こちらで取り込み・リサイズ・
`Art.MANIFEST` への登録をします。

1-9 は**動画（PV）に映すことを第一に設計した**ステージです。
王の城へ続く一本道で、ランナー一人では越えられない 8 つの難所が
一画面ずつ並び、ガーディアンの指がそれを一つずつ開けていきます。

| 区間 | 難所 | 指でやること |
|---|---|---|
| 1 | 崩れ落ちた石橋（谷） | 線を引いて橋にする |
| 2 | コウモリの群れのトンネル | 払う |
| 3 | 城壁の大砲 | 弾をつまんで返す |
| 4 | 坂を転がり落ちてくる大岩 | 押さえる |
| 5 | 落とし格子と、追ってくる番犬 | 持ち上げ、くぐったら落とす |
| 6 | 真っ暗な地下牢 | 指で照らす |
| 7 | 跳び越えられない城壁 | パチンコで飛ばす |
| 8 | 出口をふさぐ石の巨像 | 弾き飛ばす |

**1 枚も無くても 1-9 は最後まで遊べます**（コードで描いた絵に落ちる）。
気に入ったものだけ、届いた順に差し替えていけます。優先度は 4 章。

---

## 1. 全体の約束（全プロンプト共通・必ず読んでください）

動画で一瞬で読めることがいちばん大事です。**くっきり・明るく・大きなシルエット**。
細かい描き込みより、離れて見て何か分かることを優先してください。

**すべてのプロンプトの先頭に、この段落を貼ってください。**

```
Side-scrolling 2D game asset, strict side view (orthographic profile, camera
exactly level with the subject, no perspective, no vanishing point). Bright
storybook cartoon illustration for a mobile game trailer: bold clean
silhouette, thick dark-brown outline, soft cel shading with a gentle gradient,
saturated midday colours. Readability first: big simple shapes, little fine
detail, strong contrast between the subject and its outline. Key light from
the upper LEFT. Fully transparent background (PNG alpha), NO drop shadow, NO
ground shadow, NO background scenery, NO frame, NO text, NO watermark, NO
logo. Subject fills the canvas edge to edge with only a few pixels of margin.
Single subject, centred.
```

**技術的な約束（これが守られていないと使えません）**

| | |
|---|---|
| 形式 | **PNG・アルファ付き**（背景は完全透明）。①の背景だけ JPG 可 |
| 影 | **焼き込まない**。接地影はゲーム側が描いています |
| 視点 | **真横**。少しでも見下ろすと、地面に置いたとき浮いて見えます |
| 向き | 生き物・大砲は**左向き**で統一（右向きはこちらで反転します） |
| 解像度 | 下の「推奨」以上なら何でも。大きいぶんには縮めます |
| 枚数 | 1 プロンプトにつき何枚出してもらっても構いません。選びます |

**同じ世界に見えることが 1 枚 1 枚の出来より大事です。** 2 枚目以降は
気に入った 1 枚目を添えて「この絵と同じタッチで」と頼んでください。

---

## 2. 背景と地面

### ① 背景（パノラマ） — `castle/panorama.jpg`

**推奨サイズ**：2048 x 1152（16:9。横に鏡貼りでタイルします）

```
Hand-painted 2D game background, strict side-on flat stage view (the camera is
level and far away, no perspective). A sunny midday landscape: rolling green
hills, a winding road, and on a hill in the far distance a fairytale stone
castle with round towers and red pennants. Big soft white clouds in a clear
bright blue sky. Very soft, low contrast, slightly out of focus — a distant
backdrop that characters are drawn in front of. No characters, no foreground,
no text. Opaque image (this one is NOT transparent).
```

> 背景だけは**共通段落を貼らないで**ください（透明にしないため）。
> **少しぼけて低コントラスト**が必須です。くっきりしているとランナーが沈みます。

### ② 地面の本体タイル — `castle/ground_tile.png`

**推奨サイズ**：512 x 512

```
Seamless tileable texture, flat-on, no perspective, no lighting gradient, no
shadow. Packed earth and fitted old cobblestones seen in cross-section, warm
sandy browns and soft greys, a few small roots and pebbles. MUST TILE
SEAMLESSLY on all four edges. Flat even illumination. Opaque.
```

> 共通段落は**貼らない**でください（平らなテクスチャです）。

### ③ 地面の上面（道） — `castle/ground_cap.png`

**推奨サイズ**：512 x 160（**横につながること**）

```
Seamless horizontally tileable strip, strict side view, showing the TOP EDGE
of a castle road: a flat band of pale paving stones with a thin strip of
bright green grass and a few tiny flowers along the top, a darker line along
the bottom. The top surface is FLAT and level — a character stands on it.
MUST TILE SEAMLESSLY left to right. Transparent above the grass line.
```

> **上面のラインは水平に**。ここが当たり判定の面です。

### ④ 崩れた石橋の端 — `castle/bridge_end.png`

**推奨サイズ**：400 x 400

```
<共通段落>

The broken end of an old stone bridge, seen in strict side view: the paved
deck on top, two courses of fitted stone blocks below it, and the right-hand
end snapped off in a jagged break with a few loose stones about to fall. The
top surface is flat and level. The broken edge is on the RIGHT.
```

> 谷の左岸に使い、右岸には反転して使います。

---

## 3. 難所ごとの絵

### ⑤ コウモリ（2 枚） — `castle/bat_0.png` / `castle/bat_1.png`

**推奨サイズ**：256 x 192 / 枚

```
<共通段落>

A small round purple bat, cute but mischievous, big yellow eyes, tiny fangs,
facing LEFT. Pose A: wings raised high above the body.
```

```
（同じ絵を添えて）Same bat, same style. Pose B: wings swept down below the body.
```

> 2 枚で羽ばたきになります。**同じ大きさ・同じ位置**で描いてもらってください。

### ⑥ 大砲（2 枚） — `castle/cannon_idle.png` / `castle/cannon_fire.png`

**推奨サイズ**：320 x 256 / 枚

```
<共通段落>

A stubby black iron castle cannon on a small wooden carriage with two wheels,
barrel pointing LEFT, a brass band round the muzzle. Pose A: idle.
```

```
（同じ絵を添えて）Same cannon, same style. Pose B: the moment of firing — a
round puff of white smoke and a bright orange flash at the muzzle, the cannon
recoiling slightly to the right.
```

### ⑦ 砲弾 — `castle/cannonball.png`

**推奨サイズ**：128 x 128

```
<共通段落>

A single round black iron cannonball with a hot orange glow on its leading
(left) side and three short white speed streaks trailing behind it to the
right.
```

### ⑧ 大岩 — `castle/boulder.png`

**推奨サイズ**：400 x 400

```
<共通段落>

A huge round boulder of grey stone with patches of green moss and deep
cracks, slightly lumpy, very heavy-looking. Perfectly side-on so it reads as
a circle. No ground under it.
```

### ⑨ 門の石組み — `castle/gate_arch.png`

**推奨サイズ**：600 x 900

```
<共通段落>

A castle gatehouse seen in strict side view, from the side the road comes in:
two tall square stone towers joined by a heavy stone lintel at the top, with a
tall empty doorway between them (the doorway itself is TRANSPARENT — nothing
in it). Crenellations along the top and one small red pennant. The doorway is
about one third of the total width.
```

> 扉の部分は**透明**にしてください。格子（⑩）が後ろで上下します。

### ⑩ 落とし格子 — `castle/gate_bars.png`

**推奨サイズ**：200 x 800

```
<共通段落>

A tall iron portcullis grate seen flat-on: thick vertical black iron bars with
sharp pointed ends at the bottom, held together by three horizontal iron
cross-bands with rivets. Tall and narrow, about 1 wide to 4 tall.
```

### ⑪ 番犬（2 枚） — `castle/hound_0.png` / `castle/hound_1.png`

**推奨サイズ**：400 x 300 / 枚

```
<共通段落>

The castle's guard hound: a big dark-grey hound wearing a spiked iron collar
and a small iron helmet, red glowing eyes, mouth open showing teeth, running
toward the LEFT. Menacing but cartoonish, not gory. Pose A: legs stretched
out mid-stride.
```

```
（同じ絵を添えて）Same hound, same style. Pose B: legs gathered under the body
mid-stride.
```

> ランナーを追いかけてくる追跡者です。**ランナーの約 2 倍の大きさ**の想定です。

### ⑫ 地下牢の壁 — `castle/dungeon_wall.png`

**推奨サイズ**：512 x 512

```
Seamless tileable texture, flat-on, no perspective, no shadow. Old dungeon
wall of large rough dark stone blocks with mossy mortar, deep blue-grey and
green, a few iron rings set into the stones. MUST TILE SEAMLESSLY on all four
edges. Flat even illumination. Opaque.
```

> 共通段落は**貼らない**でください。暗い部屋は、ゲーム側がこの上をさらに暗くします。

### ⑬ 消えた松明 — `castle/torch.png`

**推奨サイズ**：160 x 320

```
<共通段落>

An unlit iron wall torch on a bracket, the top of the torch charred black with
a thin curl of smoke, mounted on nothing (the bracket ends at the left edge).
```

### ⑭ 城壁 — `castle/keep_wall.png`

**推奨サイズ**：512 x 512

```
Seamless tileable texture, flat-on, no perspective, no shadow. A sheer castle
wall of large smooth pale sandstone blocks, very regular courses, a few
cracks and ivy tendrils. MUST TILE SEAMLESSLY on all four edges. Flat even
illumination. Opaque.
```

> 共通段落は**貼らない**でください。

### ⑮ 石の巨像（2 枚） — `castle/golem_idle.png` / `castle/golem_hit.png`

**推奨サイズ**：600 x 700 / 枚

```
<共通段落>

A giant stone guardian statue come to life: a blocky knight made of grey
stone blocks with moss in the cracks, a glowing blue gem in its chest, round
glowing eyes, holding a huge stone shield, facing LEFT. Pose A: standing
guard, feet planted, blocking the way. About three times the height of a
person.
```

```
（同じ絵を添えて）Same stone guardian, same style. Pose B: knocked off its feet,
tumbling backwards through the air, arms flung out, eyes as surprised X marks,
a few stone chips flying off.
```

> 指で弾き飛ばされる、ステージ最後の見せ場です。**ポーズ B が動画で一番目立ちます。**

### ⑯ ゴール（城の大扉） — `castle/goal_door.png`

**推奨サイズ**：600 x 700

```
<共通段落>

The great wooden double door of a castle, seen flat-on in strict side view,
set in a stone archway, with iron studs and two big iron rings, both doors
standing half open with warm golden light spilling out between them. A red
banner with a gold crown hangs above the arch.
```

---

## 4. 優先度

1. ① 背景・② 地面タイル・③ 地面の上面 —— 画面の大半を占めます
2. ⑪ 番犬・⑮ 石の巨像 —— 動画の山場
3. ⑤ コウモリ・⑥ 大砲・⑨⑩ 門と格子・⑧ 大岩
4. 残り（④ ⑦ ⑫ ⑬ ⑭ ⑯）

上の 3 枚が来るだけで、1-9 の見た目はほぼ変わります。
