# キャラクターのアニメーション素材 生成プロンプト

ChatGPT などの画像生成に送るためのプロンプト集です。全部で**シート 10 枚**あります。

## なぜ必要か

今のキャラクターが不自然なのは、**動きの絵がほとんど無い**からです。

- **ランナー**：「走る」絵が 1 枚しかありません。それを上下に揺らして滑らせているだけです。
  やられた時も、1 枚の絵をくるくる回しているだけです。
- **1-9 の敵**：ほとんどが 1〜2 枚の絵か、コードで描いた四角形です。
  番犬・コウモリ・大岩は、他のステージの絵を借りています。

そこで、**コマ送りのアニメーション（スプライトシート）**を作ってもらいます。
1 枚の画像に何コマか並べてもらえれば、切り分けとゲームへの組み込みはこちらでやります。

背景・地面・門・地下牢・城壁・扉は、引き続き `docs/art-prompts-castle.md` のものを使います。
ただし、次の 4 つはこのファイルのシートに**置き換え**ます。

- ⑤ コウモリ
- ⑥ 大砲
- ⑪ 番犬
- ⑮ 石の巨像

---

## 0. 送り方（大事）

1. **ランナーのシートには、毎回 `docs/art-ref/runner_reference.png` を添付してください。**
   今のゲームの主人公です。この見た目から変わってしまうと使えません。
2. どのシートも、プロンプトの先頭に**下の共通段落**を貼ってください。
3. 番犬・巨像などの 2 枚目以降は、気に入った 1 枚目を添付して
   「この絵と同じキャラクター・同じタッチで」と頼んでください。
4. コマ数や並び方が指定どおりでなくても、**同じ大きさ・同じ足の位置**さえ守られていれば使えます。
   何回か出し直して、いちばん揃っているものを選んでください。

### 共通段落（全シートの先頭に貼る）

```
2D side-scrolling game SPRITE SHEET for frame-by-frame animation. Strict side
view: the camera is exactly level with the character, no perspective, no
three-quarter view. Bright storybook cartoon style: clean dark outline, soft
cel shading, saturated midday colours, key light from the upper left.
Fully transparent background (PNG alpha). NO shadow, NO ground line, NO
text, NO numbers, NO frame borders, NO watermark.
LAYOUT RULES (most important): the frames sit in a regular grid of equal
cells with clear empty space between them, read left to right, then top to
bottom. Nothing crosses into a neighbouring cell. The character is EXACTLY
THE SAME SIZE in every frame, and its feet rest on the SAME baseline near the
bottom of every cell. Only the pose changes from frame to frame, so the
frames play back as smooth animation.
```

### ランナーの見た目（ランナーの 6 枚で、共通段落の次に貼る）

```
THE CHARACTER (match the attached reference exactly): a small chibi boy hero,
head about 40% of his height, spiky dark-brown hair, big simple black oval
eyes, a long red scarf whose two ends trail behind him, white short-sleeved
shirt, blue overalls with a brown belt and a gold buckle, brown gloves,
brown boots. He FACES RIGHT in every frame.
```

---

## 1. ランナー（6 枚）

### R1 走り — `runner_run`（8 コマ / 2 段 × 4）★最優先

```
<共通段落>
<ランナーの見た目>

A looping RUN CYCLE in 8 frames, 2 rows of 4. A full stride: frame 1 right
foot contact, 2 down (knees bent, body lowest), 3 passing (left leg swinging
through), 4 up (body highest, pushing off), 5 left foot contact, 6 down,
7 passing, 8 up. Arms swing opposite to the legs, body leans slightly
forward, the scarf streams behind and ripples a little differently in each
frame. Frame 8 must flow back into frame 1.
```

### R2 待機 — `runner_idle`（4 コマ / 1 段 × 4）

```
<共通段落>
<ランナーの見た目>

An IDLE loop in 4 frames, 1 row of 4. Standing relaxed, feet apart,
breathing: the shoulders rise slightly in frames 2-3 and settle in frame 4.
The scarf ends sway gently. He blinks (eyes closed) in frame 3 only.
```

### R3 ジャンプ — `runner_jump`（6 コマ / 2 段 × 3）

```
<共通段落>
<ランナーの見た目>

A JUMP in 6 frames, 2 rows of 3: 1 crouch before take-off (knees deeply
bent), 2 take-off (one leg pushing, arms swinging up), 3 rising (knees
tucked, fists up), 4 top of the jump (body stretched, scarf floating up),
5 falling (arms out for balance, scarf blown upward), 6 landing (deep
squat, arms forward).
```

### R4 やられ — `runner_hurt`（6 コマ / 2 段 × 3）

```
<共通段落>
<ランナーの見た目>

Getting knocked out, cartoon style and NOT violent, in 6 frames, 2 rows of
3: 1 startled flinch (eyes wide, hands up), 2 knocked backwards off his
feet, 3 tumbling in the air (upside down), 4 tumbling (on his side),
5 landed flat on his back, 6 lying dazed with little spinning stars over
his head. No blood, no injury.
```

### R5 リアクション — `runner_react`（6 コマ / 2 段 × 3）

```
<共通段落>
<ランナーの見た目>

Six separate REACTION poses, 2 rows of 3 (each one stands on its own,
they are not one motion): 1 glancing back over his shoulder in fear,
still facing right; 2 skidding to a stop in front of something, leaning
back, one foot braced; 3 looking up in surprise, mouth open; 4 pointing
forward eagerly; 5 fist pump, cheering; 6 waving up at someone, grinning.
```

### R6 飛ばされる — `runner_launch`（4 コマ / 1 段 × 4）

```
<共通段落>
<ランナーの見た目>

Being thrown high into the air (by a friendly giant hand, but draw only
the boy), in 4 frames, 1 row of 4: 1 launched upward, both arms stretched
straight up, legs together, a big excited grin; 2 tucked into a ball
mid-flip; 3 unfurling, arms and legs spread wide; 4 reaching one hand
forward to grab a ledge, scarf whipping behind.
```

---

## 2. 1-9 の敵（4 枚）

番犬・コウモリ・巨像は**左向き**で描いてください（ランナーと向かい合うため）。

### E1 番犬 — `castle_hound`（8 コマ / 2 段 × 4）

**ランナーの約 2 倍の大きさ**のつもりで描いてもらってください。

```
<共通段落>

THE CHARACTER: the castle's guard hound, a big dark-grey cartoon hound with
a spiked iron collar and a small iron helmet, glowing red eyes, menacing
but cartoonish and a little goofy, never gory. It FACES LEFT in every frame.

8 frames, 2 rows of 4. Row 1 is a looping GALLOP: 1 front legs reaching
forward, 2 all legs gathered under the body, 3 back legs pushing, 4 fully
stretched out, ears flapping. Row 2 is four separate poses: 5 lunging
forward with jaws open; 6 slamming face-first into iron bars, squashed,
eyes spinning; 7 sitting dazed with stars over its head; 8 asleep curled
up, a small "z" bubble drawn as a simple shape (no letters).
```

### E2 コウモリ — `castle_bat`（4 コマ / 1 段 × 4）

```
<共通段落>

THE CHARACTER: a small round purple bat, cute but mischievous, big yellow
eyes, tiny fangs. It FACES LEFT.

A looping WING FLAP in 4 frames, 1 row of 4: 1 wings raised high, 2 wings
level and spread, 3 wings swept down below the body, 4 wings level again
coming back up. The body bobs slightly with the flap.
```

### E3 石の巨像 — `castle_golem`（8 コマ / 2 段 × 4）

ステージ最後の見せ場です。指で弾き飛ばされる**コマ 6〜8 が、PV でいちばん目立つ**ところです。

```
<共通段落>

THE CHARACTER: a giant stone guardian statue come to life: a blocky knight
built of big grey stone blocks with moss in the cracks, a glowing blue gem
in its chest, round glowing cyan eyes, a huge round stone shield with a red
boss on its left arm. Heavy and slow. It FACES LEFT. About six times the
height of a small child.

8 frames, 2 rows of 4. Row 1, a slow heavy WALK loop: 1 left foot forward,
2 weight shifting, 3 right foot forward, 4 weight shifting back. Row 2:
5 STOMP, one foot raised high and the shield held up; 6 hit hard from
below-left, knocked off its feet, eyes turned to X marks; 7 tumbling
backwards through the air, arms flung out, stone chips flying; 8 tumbling
further, upside down, smaller chips scattering.
```

### E4 大砲 — `castle_cannon`（4 コマ / 1 段 × 4）

```
<共通段落>

A stubby black iron castle cannon on a small wooden carriage with two
wheels, barrel pointing LEFT, a brass band round the muzzle. 4 frames,
1 row of 4: 1 idle; 2 charging, the fuse sparking and the muzzle glowing
orange inside; 3 FIRING, a big round puff of white smoke and a bright
orange flash at the muzzle; 4 recoil, the cannon jolted back to the right
with smoke drifting away.
```

---

## 3. 優先度

1. **R1 走り** —— 全ステージ・PV のどのカットにも映ります。これ 1 枚で印象がいちばん変わります。
2. R2 待機・R3 ジャンプ・R4 やられ
3. E1 番犬・E3 石の巨像
4. R5 リアクション・R6 飛ばされる・E2 コウモリ・E4 大砲
5. `docs/art-prompts-castle.md` の背景・地面（①②③）

届いた順に組み込んでいくので、全部が揃うのを待つ必要はありません。
