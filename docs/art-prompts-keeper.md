# 1-B「THE KEEPER」素材生成プロンプト

画像生成 AI に投げるプロンプト集。**13 枚**。
出来たものを zip で渡してもらえれば、こちらで取り込み・リサイズ・
`Art.MANIFEST` への登録をします。

**1 枚も無くても 1-B は最後まで遊べます**（ベクター描画に落ちる）。
なので**気に入ったものだけ、届いた順に**差し替えていけます。優先度は 4 章。

---

## 1. 全体の約束（全プロンプト共通・必ず読んでください）

1-B は **1-2「THE HOLLOW OUTSKIRTS」の門の内側**という設定です。
だから**絵の世界は 1-2 と地続き**——夜、沈んだ青緑、灯りだけが暖色。
すでにある `assets/horror/` の絵（荷車・墓石・提灯・茨・門）と
並べて違和感がないことが、1 枚 1 枚の出来より大事です。

**すべてのプロンプトの先頭に、この段落を貼ってください。**

```
Side-scrolling 2D game asset, strict side view (orthographic profile, camera
exactly level with the subject, no perspective, no vanishing point, no ground
plane receding). Hand-painted storybook illustration with soft visible brush
texture, clean readable silhouette, thick soft outline. Night scene palette:
desaturated blue-green shadows, cold grey stone, warm amber only where there is
fire or magic. Key light from the upper LEFT, cool rim light from the upper
right. Fully transparent background (PNG alpha), NO drop shadow, NO ground
shadow, NO cast shadow on the floor, NO background scenery, NO frame, NO text,
NO watermark, NO logo. Subject fills the canvas edge to edge with only a few
pixels of margin. Single subject, centred.
```

**技術的な約束（これが守られていないと使えません）**

| | |
|---|---|
| 形式 | **PNG・アルファ付き**（背景は完全透明）。panorama だけ JPG 可 |
| 影 | **焼き込まない**。接地影はゲーム側が動的に描いています |
| 視点 | **真横**。少しでも見下ろすと、地面に置いたとき浮いて見えます |
| 余白 | 少なめ。こちらでアルファ境界に切り詰めます |
| 解像度 | 下の「推奨」以上なら何でも。大きいぶんには縮めます |
| 枚数 | 1 プロンプトにつき**何枚出してもらっても構いません**。選びます |

**向き**：キャラクター系は**すべて左向き**（画面の左を向いて立つ）で
出してください。右向きはコード側で反転します。
左右で別々に描くと、反転のたびに光源が裏返って気持ち悪くなります。

---

## 2. プロンプト（13 枚）

### ① 番人・立ち／歩き — `keeper/keeper_stand.png`

**用途**：ボスの基本姿勢。アリーナをゆっくり歩いてランナーに寄ってくる。
**推奨サイズ**：1024 x 820 くらい（ゲーム内では 168 x 134px で描画）

```
<共通段落>

A colossal stone-and-iron guardian construct standing in profile, facing LEFT.
Four heavy legs like a siege beast, a low broad armoured body, a blunt head
plated with riveted iron and lowered between hunched shoulders. Body proportions
WIDE and LOW, roughly 1.2 times as wide as it is tall, built like a battering
ram rather than a giant humanoid. Ancient carved granite slabs bound with rusted
iron bands and thick chains. Moss and dried vines in the seams. Dead cold eyes,
two narrow amber slits under the brow. On its BACK, between the shoulders, a
sealed circular hatch of overlapping iron plates, shut tight, with a faint amber
glow leaking from the seams. Heavy, patient, immovable. Standing at rest, weight
settled, head level.
```

> **なぜこの形か**：横スクロールで「突進してくる」を読ませるには、
> シルエットが**縦より横に長い**必要があります。人型の巨人は迫力は出ますが、
> 突進の姿勢が読めません。四つ脚・低重心・前が重い、が正解。
> 背中のハッチが 2 章のルール 2（炉心）そのものなので、**閉じた状態**で。

---

### ② 番人・予告（構え） — `keeper/keeper_brace.png`

**用途**：突進の 0.85 秒前。ランナーは**この絵を見てから**柱の裏に走ります。
**この 1 枚がステージで一番重要**です。①と見間違えたら死にます。
**推奨サイズ**：①と同じ

```
<共通段落>

The same colossal four-legged stone-and-iron guardian construct, in profile,
facing LEFT, now BRACING to charge. Front legs planted wide and dug into the
ground, hind legs coiled, the whole body dropped low and pitched forward, head
rammed down almost to the ground so the armoured skull leads. Chains pulled
taut. The amber eye-slits flared BRIGHT, hot orange-white. Bright amber light
bleeding from every seam in the granite as pressure builds inside. Small stones
and dust lifting off the ground around the planted feet. Coiled violence, one
instant before release. Same character, same materials, same palette as the
standing pose.
```

> **なぜ**：予告は**色でも姿勢でも**分かる必要があります。
> 立ち姿は「目が細く暗い・頭は水平」、構えは「目が白く光る・頭が地面すれすれ」。
> 片方だけ見えても（＝縮小されても、明滅していても）区別がつくように。

---

### ③ 番人・突進 — `keeper/keeper_charge.png`

**用途**：突進中（660px/秒、0.5〜1.2 秒）。
**推奨サイズ**：①と同じ、やや横長でも可

```
<共通段落>

The same colossal four-legged stone-and-iron guardian construct, in profile,
facing LEFT, at FULL CHARGE. Body stretched out horizontally, all four legs
extended mid-stride, head and shoulder armour thrust forward as a ram. Chains
streaming back. Amber light blazing from the seams and trailing behind. Motion
is carried by the POSE, not by motion blur: keep every edge crisp and readable.
Same character, same materials, same palette.
```

> **モーションブラーは入れないでください。** ゲーム側でスケール・傾き・
> 残像を動的に足します。ブラーが焼き込まれていると二重にかかります。

---

### ④ 番人・よろけ（炉心が開いている） — `keeper/keeper_reel.png`

**用途**：柱／壁に激突したあとの 1.8〜2.6 秒。**ガーディアンが撃つ唯一の瞬間**。
**推奨サイズ**：①と同じ

```
<共通段落>

The same colossal four-legged stone-and-iron guardian construct, in profile,
facing LEFT, STAGGERED and reeling after slamming head-first into stone. Head
thrown down and to the left, front legs buckled and splayed, body slumped so the
BACK is tilted up and clearly presented to the viewer. Cracks spider across the
head armour, dust falling from the shoulders. The circular hatch between the
shoulders is now WIDE OPEN, its iron plates folded back like petals, revealing a
molten amber-white core burning inside, casting warm light up onto the
surrounding stone. The eye-slits have gone DIM and dull. Dazed, exposed,
vulnerable. Same character, same materials, same palette.
```

> **背中が見えていることが全て。** ガーディアンはこの絵の「開いた穴」に
> 照準を置きます。穴は**体の輪郭のなるべく高い位置・中央より後ろ**に。
> 低すぎると能力ボタンの帯の下に入ります（`docs/status.md` 4 章の実例）。

---

### ⑤ 炉心（単体） — `keeper/core.png`

**用途**：④の背中に**別レイヤーで重ねて**脈打たせます。命中で閉じる演出もここ。
**推奨サイズ**：512 x 512

```
<共通段落>

A single glowing machine core seen head-on, isolated on transparent background.
A circular iron socket with eight overlapping plates folded back like petals,
and inside it a molten amber-white furnace heart, cracked and seething, with
thin white-hot fissures. Rim of scorched blackened iron. Strong warm glow
radiating outward with a soft halo. Nothing else in frame. Perfectly circular
overall shape.
```

> 円形・正面向きでお願いします。ゲーム側で拡縮と明滅をかけます。
> **ハローを少し多めに**残してください（切り出しで光が痩せます）。

---

### ⑥ 石の防壁 — `keeper/barricade.png`

**用途**：一幕で 2 枚、二幕で 1 枚立っている突進止め。
**ランナーは跳び越えて、上に立てます。**
**推奨サイズ**：560 x 1024（やや縦長。ゲーム内 70 x 128px）

```
<共通段落>

A single short, thick ancient stone barricade wall standing upright, seen in
strict side view, filling the frame. Proportions roughly 1 wide to 1.8 tall --
a chest-high defensive block, NOT a tall column. Weathered grey-green granite
blocks stacked and mortared, chipped corners, one broken corner at the top left.
A flat capping course along the top, slightly proud of the shaft, clearly
something a person could stand on. Moss in the joints, a few dead vines. Two
rusted iron rings bolted into the face. Solid, heavy, structural. Scarred and
dented in the middle of the face, as though something very large has run into it
before.
```

> **高すぎないこと**が一番大事です。ゲームではこれが 128px、ランナーの背が
> 46px、ジャンプが 162px——つまり**ランナーは軽く跳び越えます**。
> 塔のように描かれると「越えられない壁」に見えてしまい、それは
> このステージが一度やらかして作り直した失敗そのものです
> （`docs/stage-keeper.md` 3 章）。
> 「ぶつかった跡」を入れてもらえると、何のための物か絵だけで伝わります。

---

### ⑦ 崩れた防壁 — `keeper/barricade_rubble.png`

**用途**：幕の切り替わりで番人が壊した跡。**「もう頼れない」を絵で言う**もの。
**推奨サイズ**：600 x 320

```
<共通段落>

The shattered remains of the same ancient stone barricade, seen in strict side
view. Only the lowest third is still standing, snapped off with a jagged
diagonal break face showing fresh pale stone against the weathered green-grey
outside. Broken blocks and rubble heaped around the base, dust still settling,
one bent rusted iron ring torn loose. Same granite, same moss, same palette as
the intact barricade. Low and wide composition, about twice as wide as it is
tall.
```

> ⑥と**同じ石・同じ苔**でお願いします。並べて「これがあれの残骸だ」と
> 分かることが目的の絵です。

---

### ⑧ 衝撃波 — `keeper/shockwave.png`

**用途**：二幕以降、番人が空振りしたあと地面を走る波。ランナーは飛んで避ける。
**推奨サイズ**：512 x 256

```
<共通段落>

A ground shockwave travelling to the LEFT, seen in strict side view, isolated on
transparent background. A low crescent-shaped ridge of upheaved earth and
cracked flagstone, about four times as wide as it is tall, with dust and small
stones thrown up along its leading edge, and a thin seam of amber light glowing
in the cracks at its base. The crest is HIGHEST at the leading (left) edge and
tapers away to the right. Energy and debris, not fire. Nothing else in frame.
```

> **高さは低く**（幅の 1/4 程度）。高く描くと「飛べば避けられる」が
> 絵から伝わらなくなります。

---

### ⑨ 落とし格子（門） — `keeper/portcullis.png`

**用途**：アリーナ右端。番人が倒れると上がってゴールへ通じる。
**推奨サイズ**：600 x 1200（縦長）

```
<共通段落>

A massive iron portcullis gate seen in strict side view (flat-on, as a flat
grille filling the frame), closed. Thick vertical iron bars with spiked lower
ends, three heavy horizontal crossbars riveted across them, deep rust and
pitting, streaks of old rain. Behind the bars, pure transparency (do NOT paint
anything behind the gate). A heavy stone lintel block across the very top with
carved worn relief. Cold grey-blue iron, no warm light on this object.
```

> **格子の隙間は必ず透明**にしてください。上がったとき、後ろの景色が
> 抜けて見えるのが正しい絵です。

---

### ⑩ 背景（パノラマ） — `keeper/panorama.jpg`

**用途**：アリーナ全体の背景。唯一の**不透明・JPG 可**な絵。
**推奨サイズ**：**2048 x 1152**（16:9。横に鏡貼りでタイルします）

```
Hand-painted 2D game background, night, strict side-on flat stage view (no
perspective vanishing point, the camera is level and far away). The inner
courtyard of a drowned, abandoned stone village, seen from outside the arena
floor: a high cracked stone curtain wall running left to right across the whole
image, buttresses, boarded windows, a few guttering amber lanterns hung on iron
hooks, tattered banners, dead ivy. Above the wall, a heavy overcast night sky
with a pale cold moon behind thin cloud, and the silhouettes of leaning rooftops
and a broken bell tower. Desaturated blue-green palette, warm amber only from
the lanterns. Slightly out of focus, low contrast, MUTED — this is a distant
backdrop that characters will be drawn in front of. No characters, no creatures,
no foreground floor, no text.
```

> **必ず「少しぼけて・低コントラスト」**と指定してください。
> 背景がくっきりしていると、手前のキャラが背景に沈みます。
> `assets/bg/horror_stage_1_2.jpg` と並べて、同じ夜に見えるように。

---

### ⑪ 床タイル（石畳） — `keeper/flagstone.png`

**用途**：アリーナの床。`horror` の泥地とは変えて「闘技場」を出します。
**推奨サイズ**：512 x 512（**上下左右つながるシームレスタイル**）

```
Seamless tileable texture, top-down flat, no perspective, no lighting gradient,
no shadow. Ancient dark flagstone paving: irregular rectangular grey-green stone
slabs with worn rounded edges, deep mortar joints, hairline cracks, patches of
wet moss and standing rainwater in the low spots, a few slabs chipped or missing
with dark earth beneath. Desaturated cold palette. MUST TILE SEAMLESSLY on all
four edges. Flat even illumination.
```

> これだけは**真上から見た平らなテクスチャ**です（他と違います）。
> 光の方向・影は入れないでください。タイルの継ぎ目が出ます。

---

### ⑫ 篝火 — `keeper/brazier.png`

**用途**：アリーナの飾り。暗い画面に暖色の点を置いて、闘技場らしさを出します。
**推奨サイズ**：512 x 700

```
<共通段落>

A tall iron brazier standing in strict side view: a three-legged wrought-iron
stand supporting a shallow bowl of burning coals, with low orange flames and
drifting embers rising. Rusted iron, scorched black around the bowl, a heap of
glowing amber coals. The flame is small and steady, not a bonfire. Warm amber
light pooling on the iron itself.
```

---

### ⑬ 瓦礫 — `keeper/rubble.png`

**用途**：アリーナの飾り（複数箇所に縮尺を変えて置きます）。
**推奨サイズ**：600 x 300

```
<共通段落>

A low heap of broken masonry rubble in strict side view: shattered grey-green
stone blocks, snapped timber beams, a bent iron bar, dust and gravel. Moss on
the older pieces. Low wide composition, roughly twice as wide as it is tall.
Same stone and palette as the ancient pillar.
```

---

## 3. 渡し方

zip の中は**フォルダ分けなし・ファイル名そのまま**で構いません。
こちらで判別できるよう、**上の①〜⑬の番号**をファイル名の頭に付けてもらえると
確実です（例：`04_keeper_reel_a.png`）。

1 つのプロンプトから複数枚出した場合は `04a` `04b` のように。**選びます。**

```
keeper-art.zip
├── 01_keeper_stand.png
├── 02_keeper_brace.png
├── 03_keeper_charge.png
├── 04a_keeper_reel.png
├── 04b_keeper_reel.png
├── 05_core.png
├── ...
└── 10_panorama.jpg
```

## 4. 優先度（時間が無いとき、この順で）

| 順 | 枚 | 無いとどうなるか |
|---|---|---|
| 1 | ②**構え** / ④**よろけ** | この 2 枚が戦いのルールそのもの。ベクターでも読めるようには描いてありますが、**絵の差がいちばん効くのはここ** |
| 2 | ①立ち / ③突進 | ②④だけ絵だと、ボスが 2 枚の紙芝居に見えます |
| 3 | ⑩背景 | 画面の半分。ここが替わると別ステージに見えます |
| 4 | ⑥防壁 / ⑦崩れた防壁 | 三幕の「もう無い」が絵で伝わる |
| 5 | ⑤炉心 / ⑧衝撃波 | 動くもの。ベクターでもそこそこ見られます |
| 6 | ⑨門 / ⑪床 / ⑫篝火 / ⑬瓦礫 | 飾り。最後で構いません |

## 5. こちらの取り込み手順（参考）

1. アルファ境界に切り詰め（**光の暈は少し残す**——切ると光が痩せます）
2. 乗算済みピクセルでリサイズ（ストレートアルファで縮めると輪郭が黒く縁取られます）
3. `assets/keeper/` に配置し、`Art.MANIFEST` に登録
4. `tools/verify.sh` の素材監査が「登録簿の全テクスチャが実在するか」を見ます

①〜④は**足元を揃えて 1 枚のキャンバスに載せ直します**（ランナーの 8 ポーズと
同じ処理）。ポーズごとに別々に縮めると、状態が変わるたびに番人の背が伸び縮みします。
