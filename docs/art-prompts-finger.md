# ガーディアンの「指」素材生成プロンプト

画像生成 AI（ChatGPT など）に投げるプロンプト集。**5 枚**。
出来たものを zip で渡してもらえれば、こちらで取り込み・リサイズ・
`Art.MANIFEST` への登録をします。

**1 枚も無くても指の操作は全部遊べます**（コードで描いた指に落ちる）。
なので、気に入ったものだけ届いた順に差し替えていけます。

---

## 1. 全体の約束（全プロンプト共通・必ず読んでください）

指は**ガーディアン（ORION）の手**です。ガーディアンには体が無く、
足場も壁も**青く光るホログラム**として現れます（`assets/ui/icon_platform.png`、
`assets/ui/portrait_orion.png` の青）。指も同じ素材でできている、という見え方にします。

画面上では**小さく**（高さ 60〜90px 程度）表示されるので、
細部より**一目でポーズが分かるシルエット**が大事です。

**すべてのプロンプトの先頭に、この段落を貼ってください。**

```
2D game UI asset for a mobile game. A single stylised cartoon hand made of
translucent glowing cyan hologram light (colour #35D6FF), like a hand sculpted
from glass and light: bright white-cyan core along the edges and fingertips,
softer see-through cyan in the middle, a thin bright rim, a faint outer glow.
Four fingers and a thumb, simple rounded chunky proportions, friendly, no
nails, no skin texture, no wrinkles. Clean readable silhouette that reads at
64 pixels tall. Fully transparent background (PNG alpha), NO drop shadow, NO
background, NO frame, NO text, NO watermark, NO logo, NO sleeve, NO arm beyond
the wrist (the hand fades out at the wrist). Single subject, centred, filling
the canvas with only a few pixels of margin.
```

**技術的な約束（これが守られていないと使えません）**

| | |
|---|---|
| 形式 | **PNG・アルファ付き**（背景は完全透明） |
| 影 | **焼き込まない** |
| 向き | **指先が画面の左上を向く**（スマホのカーソルと同じ向き）。①〜⑤で揃える |
| 解像度 | 512 x 512 以上なら何でも。大きいぶんには縮めます |
| 枚数 | 1 プロンプトにつき何枚出してもらっても構いません。選びます |

**①〜⑤は同じ手に見えることがいちばん大事です。** 1 枚目が気に入ったら、
2 枚目以降は「この画像と同じ手で、ポーズだけ変えて」と画像を添えて頼んでください。

---

## 2. プロンプト（5 枚）

### ① 指さし — `finger/point.png`

**用途**：ふだんのカーソル。線を引く、タップする。

```
Pose: index finger extended and pointing up-left, the other fingers curled
into the palm, thumb resting along the side. As if about to tap a phone screen.
```

### ② つまむ — `finger/pinch.png`

**用途**：敵の弾をつまんで弾き返す。

```
Pose: thumb and index fingertip pinched together at the upper-left, holding
something tiny between them; the other three fingers loosely curled.
```

### ③ 押さえる — `finger/press.png`

**用途**：転がってくる岩を長押しで止める、鉄格子を引き上げる。

```
Pose: index and middle finger extended together, pressing firmly forward
(up-left), slightly bent at the tip as if pushing down hard on something.
```

### ④ はじく — `finger/flick.png`

**用途**：巨大ゴーレムを指で弾き飛ばす、ランナーをパチンコで飛ばす。

```
Pose: a flick. The index finger is snapping straight out toward the upper-left
from behind the thumb, as if flicking a marble. Add three short white speed
streaks behind the fingertip.
```

### ⑤ 払う — `finger/swipe.png`

**用途**：コウモリの群れを払い飛ばす。

```
Pose: open flat hand, fingers together, palm facing the viewer, tilted as if
sweeping quickly across the screen from right to left. Add a soft motion-blur
trail of cyan light behind the hand.
```

---

## 3. 優先度

① 指さし ＞ ④ はじく ＞ ② つまむ ＞ ③ 押さえる ＞ ⑤ 払う

① が来るだけで、トレイラーの「指が現れる」場面は絵になります。
