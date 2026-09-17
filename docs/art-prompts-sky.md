# 1-S「THE OPEN SKY」素材生成プロンプト

画像生成 AI に投げるプロンプト集。**9 枚**。
出来たものを zip で渡してもらえれば、こちらで取り込み・リサイズ・
`Art.MANIFEST` への登録をします。

**1 枚も無くても 1-S は最後まで遊べます**（ベクター描画に落ちる）。
1-B と違って、このステージは**素材ゼロでもそこそこ見られます**——
既定のベクター空がそのまま「空」なので。なので**急ぎません**。優先度は 4 章。

---

## 1. 全体の約束（全プロンプト共通・必ず読んでください）

1-S は**雲の海の上**です。1-1 の真昼の緑とも、1-2／1-B の夜とも違う、
**夜明けの高空**——低い太陽、長い影、冷たい青と暖かい金の二色。

舞台は「昔だれかが空に架けた道の残骸」。石の島が点々と浮いていて、
その下には**何も無い**。下に地面が無いことが絵で伝わるのがいちばん大事です。

**すべてのプロンプトの先頭に、この段落を貼ってください。**

```
Side-scrolling 2D game asset, strict side view (orthographic profile, camera
exactly level with the subject, no perspective, no vanishing point, no ground
plane receding). Hand-painted storybook illustration with soft visible brush
texture, clean readable silhouette, thick soft outline. High-altitude dawn
palette: cool blue-grey stone in shadow, warm gold and pale rose where the low
sun catches an edge, thin cold air. Key light from the LOWER LEFT (the sun is
just above the cloud sea), cool sky-bounce from above. Fully transparent
background (PNG alpha), NO drop shadow, NO ground shadow, NO cast shadow, NO
background scenery, NO sky, NO clouds behind the subject, NO frame, NO text,
NO watermark, NO logo. Subject fills the canvas edge to edge with only a few
pixels of margin. Single subject, centred.
```

**技術的な約束（これが守られていないと使えません）**

| | |
|---|---|
| 形式 | **PNG・アルファ付き**（背景は完全透明）。panorama だけ JPG 可 |
| 影 | **焼き込まない**。接地影はゲーム側が動的に描いています |
| 視点 | **真横**。少しでも見下ろすと、置いたときに浮いて見えます |
| 余白 | 少なめ。こちらでアルファ境界に切り詰めます |
| 解像度 | 下の「推奨」以上なら何でも。大きいぶんには縮めます |
| 枚数 | 1 プロンプトにつき**何枚出してもらっても構いません**。選びます |

**光の向きが 1-B と逆です。** 1-B は上から（夜の月）、1-S は**下から**（雲海に沈む朝日）。
同じ世界の別の時間帯なので、ここは揃えないでください。

---

## 2. プロンプト（9 枚）

### ① 背景（パノラマ） — `sky/panorama.jpg`

**用途**：ステージ全体の背景。唯一の**不透明・JPG 可**な絵。
**推奨サイズ**：**2048 x 1152**（16:9。横に鏡貼りでタイルします）

```
Hand-painted 2D game background, high above a sea of clouds at dawn, strict
side-on flat stage view (the camera is level and very far away, no perspective
vanishing point). The lower half is an endless rolling cloud sea, lit gold and
rose from a low sun just below its horizon, with deep blue-grey shadowed
valleys between the cloud tops. The upper half is clear cold sky grading from
pale gold at the cloud line to deep blue at the top, with a few high thin
cirrus streaks and one faint morning star. Scattered far in the distance,
small silhouetted floating rock islands trailing long wisps of vapour, and the
broken remains of an ancient stone causeway that once ran between them. Very
soft, low contrast, MUTED and slightly out of focus — this is a distant
backdrop that characters will be drawn in front of. No characters, no
creatures, no foreground, no text.
```

> **必ず「少しぼけて・低コントラスト」**と指定してください。
> 背景がくっきりしていると、手前の島とランナーが沈みます。
> **雲の海が画面の下半分**にあることが、このステージの「落ちたら終わり」を
> 絵で言う唯一の要素です。

---

### ② 島の本体タイル — `sky/island_tile.png`

**用途**：浮島の断面。**上下左右つながるシームレスタイル**として使います。
**推奨サイズ**：512 x 512

```
Seamless tileable texture, flat-on, no perspective, no lighting gradient, no
shadow. The cut face of ancient weathered pale stone: horizontal strata of
grey-blue and warm sand-coloured rock, fine cracks, small embedded pebbles,
patches of pale lichen. Wind-scoured and smooth rather than jagged. Cool
neutral palette with a faint warm cast. MUST TILE SEAMLESSLY on all four
edges. Flat even illumination, no directional light.
```

> これだけは**平らなテクスチャ**です（他と違います）。
> 光の方向・影は入れないでください。タイルの継ぎ目が出ます。

---

### ③ 島の縁（草の帯） — `sky/island_cap.png`

**用途**：島の上面。②の上に横方向へタイルして「地面の口」を作ります。
**推奨サイズ**：512 x 160（**横につながること**。上下はつながらなくて構いません）

```
Seamless horizontally tileable strip, seen in strict side view, showing the TOP
EDGE of a stone island: a band of short wind-flattened pale grass and cushion
moss growing on a thin layer of soil, with the soil's under-edge visible as a
darker line along the bottom of the strip. A few tiny wind-bent tufts and one
or two small pale flowers. The grass is dry silver-green, not lush. The top
surface line is roughly flat with gentle undulation — this is something a
character stands on. MUST TILE SEAMLESSLY left to right. Transparent above the
grass line.
```

> **上面のラインはほぼ水平**にしてください。ここが当たり判定の面です。
> 大きく波打っていると、平らな床に立っているのに絵が斜めに見えます。

---

### ④ 島の底（keel） — `sky/keel.png`

**用途**：島の下にぶら下がる岩。**「下に地面が無い」を絵で言う要**で、
このステージで**いちばん重要な 1 枚**です。
**推奨サイズ**：900 x 700

```
<共通段落>

The underside of a floating stone island, seen in strict side view: a broad
flat top edge (where it meets the island above) narrowing downward into a
ragged tapering keel of pale weathered rock, like the bottom of an iceberg
made of stone. Strata run horizontally across it. Long roots and dry vines
trail from the underside. Two heavy rusted iron chains hang from ring bolts
set into the rock, broken off short, swinging in the wind. A few small loose
stones caught in the roots. Nothing below it — the keel simply ends in the
air. Wider at the top than at the bottom, roughly 1.3 wide to 1 tall.
```

> **上辺がまっすぐで広く、下に向かって細くなる**こと。
> ゲームでは島の当たり判定の真下に貼るので、上辺の幅＝島の幅として使います。
> 鎖は「浮いている」と「昔ここに何かを繋いでいた」の両方を言ってくれるので、
> 入れてもらえると助かります。

---

### ⑤ 上昇気流 — `sky/updraft.png`

**用途**：このステージの**唯一の新要素**。中に入ると落下が上昇に変わる縦の帯。
ランナーが空中で「入るか避けるか」を判断する対象なので、
**遠くからでも帯だと分かる**必要があります。
**推奨サイズ**：512 x 1536（**縦長**。ゲーム内では縦に引き伸ばしてタイルします）

```
<共通段落>

A vertical column of rising wind, seen in strict side view, isolated on
transparent background. Tall and narrow, filling the frame top to bottom.
Made of upward-streaming ribbons of pale warm light and thin vapour, brightest
along the two edges of the column and more transparent in the middle so a
character inside it stays readable. Small leaves, dust motes and pale petals
caught in the flow and carried upward, densest near the bottom. The streaks
lean very slightly and lengthen toward the top. Warm gold against nothing.
Soft, airy, translucent — NOT fire, NOT smoke, NOT a solid beam.
```

> **真ん中は薄く、両端が明るく。** ランナーが帯の中にいるとき、
> 帯がランナーを隠してしまうと何も読めなくなります。
> **上向きの流れ**が静止画でも分かるように（粒が上に伸びる／上ほど長い）。

---

### ⑥ 風見 — `sky/streamer.png`

**用途**：島に立つ細い柱と吹き流し。**目印**です——
二人が「2本目の吹き流しのところ」と言えるように置きます。
風の向きも読めるので、上昇気流の予告にもなります。
**推奨サイズ**：420 x 800

```
<共通段落>

A tall slender weathered wooden pole standing upright, seen in strict side
view, with three long narrow cloth streamers tied near its top, blown out
horizontally to the right by a steady wind. The cloth is faded pale gold and
dusty rose, frayed at the tips, translucent where the low sun passes through
it. A simple iron ring and a short length of rope near the top. The pole is
bare, grey, wind-polished, planted in a small cairn of stones at its base.
```

> **吹き流しは必ず横に伸ばして**（風が吹いている状態で）。
> だらんと垂れていると、ただの棒になって目印として弱くなります。

---

### ⑦ 石の門（アーチ） — `sky/arch.png`

**用途**：もうひとつの**目印**。大きくて数えやすいものが欲しいので。
昔この空に道があった、という設定を言う役でもあります。
**推奨サイズ**：1000 x 900

```
<共通段落>

A ruined free-standing stone archway, seen in strict side view (flat-on, as a
flat silhouette filling the frame). Two heavy square pillars of pale weathered
stone carrying a cracked horizontal lintel, with a worn carved band of simple
geometric relief along it. One pillar is broken and shorter than the other,
its top edge jagged. Pale lichen in the joints, dry vines climbing one side.
Through the archway, pure transparency — do NOT paint anything inside or
behind the opening. Ancient, monumental, half-fallen.
```

> **アーチの内側は必ず透明**にしてください。向こう側の空が抜けて見えるのが
> 正しい絵です。**左右で高さを変えて**もらえると、反転して並べたときに
> 「2つ目」「3つ目」が言い分けられます。

---

### ⑧ ゴールの灯台 — `sky/beacon.png`

**用途**：最後の島に立つゴール。ステージ全体を通して**遠くに見えている**もの。
**推奨サイズ**：600 x 1100

```
<共通段落>

A tall slender stone beacon tower standing upright, seen in strict side view.
A narrow tapering shaft of pale weathered stone with a spiral of shallow steps
carved around it, topped by an open iron cage holding a bright warm flame. A
thin banner hangs from a bracket below the cage. Small arched openings down
the shaft glow faintly from within. The flame is the brightest thing in the
image and casts warm light onto the stone immediately around it. Welcoming,
distant, a destination.
```

> **炎が一番明るいもの**であること。ステージの最初から地平に見えていて、
> 「あそこまで行く」と分かるのがこの絵の仕事です。

---

### ⑨ 空の敵 — `sky/flyer.png`

**用途**：飛行敵。ランナーの飛行線の上にいて、射出の前に撃っておく相手。
**推奨サイズ**：700 x 500

```
<共通段落>

A hostile flying creature seen in strict side view, facing LEFT. A wind-borne
predator built like a manta or a kite: a broad flat wedge-shaped body, two
long swept membrane wings held out wide, a short blunt head with a single
narrow amber eye, and two thin ribbon tails trailing behind. The membrane is
translucent pale grey-blue with darker veins, catching the low sun along its
leading edges. No legs, no feathers. Wider than it is tall, roughly 1.4 to 1.
Silent, gliding, unpleasant.
```

> **左向き**で（キャラクター系は全部左向き。右向きはコード側で反転します）。
> 横長のシルエットにしてください。縦長だと、飛行中のランナーと
> すれ違うときに当たり判定がどこにあるか読めません。

---

## 3. 渡し方

zip の中は**フォルダ分けなし・ファイル名そのまま**で構いません。
①〜⑨の**番号をファイル名の頭**に付けてもらえると確実です。

```
sky-art.zip
├── 01_panorama.jpg
├── 02_island_tile.png
├── 03_island_cap.png
├── 04a_keel.png
├── 04b_keel.png
├── 05_updraft.png
└── ...
```

1 つのプロンプトから複数枚出した場合は `04a` `04b` のように。**選びます。**

## 4. 優先度（時間が無いとき、この順で）

| 順 | 枚 | 無いとどうなるか |
|---|---|---|
| 1 | ④**島の底** / ⑤**上昇気流** | この 2 枚がステージのルールそのもの。「下に何も無い」と「ここに入ると上がる」 |
| 2 | ①背景 | 画面の半分。雲の海が無いと、ただの青い空になります |
| 3 | ②島のタイル / ③島の縁 | 島が 1-1 の茶色い土のままだと、高空に見えません |
| 4 | ⑥風見 / ⑦アーチ | 目印。二人が場所を名指しできるかどうかに効きます |
| 5 | ⑧灯台 / ⑨空の敵 | 最後で構いません |

## 5. こちらの取り込み手順（参考）

1. アルファ境界に切り詰め（**光の暈は少し残す**——切ると光が痩せます）
2. 乗算済みピクセルでリサイズ（ストレートアルファで縮めると輪郭が黒く縁取られます）
3. `assets/sky/` に配置し、`Art.MANIFEST` に登録、`Art.PENDING` から行を削除
4. `tools/verify.sh` の素材監査が「登録簿の全テクスチャが実在するか」を見ます。
   **PENDING に残したままファイルを置くとテストが落ちます**（そういう作りにしてあります）
