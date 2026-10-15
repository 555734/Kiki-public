# 1-10 PV, fifth pass — the three prototype scenes rebuilt from the game up

The 49 s PV was **not** re-rendered. The three scenes rejected in review
(6319 = rescue, 6320 = giant, 6321 = bone canyon, i.e. the v4 clips) were
redesigned at the level of terrain, collision, enemy behaviour and gimmicks,
and shot again from real play:

| Clip | Beats | Length | What happens (all in the game's physics) |
| --- | --- | --- | --- |
| `rescue_v2.mp4` | 3–10 | 7.1 s | leap → falls short in an open, bottomless gorge → call → YOU's finger draws a platform under the falling runner → the fall stops on it → jump again → far bank |
| `giant_v2.mp4` | 32–33 | 6.3 s | the giant blocks the stone bridge → sees the runner, raises its fist → runner backs off → slam just in front → the bridge breaks block by block (colliders gone) → runner jumps onto the planted arm, runs up it → leaps off as the other fist smashes the arm |
| `bone_canyon_v2.mp4` | 37–39 | 6.3 s | diagonal run up a huge rib → the maw rises, opens under the span → bites the span the runner just left → the rib's tip drops with them onto a tilted thigh bone → slide → the maw resurfaces, bites the bone's end → last long jump while it bites the curved rib behind |

Made with `tools/promotion/capture_finale_pv.tscn -- --take=opening,giant,bone`
(one recording) and `tools/promotion/render_pv_clip.py OUT.mp4 FIRST LAST`.
Old vs new, same moments: `docs/images/stage-1-10/v5-A-old-vs-new.jpg`,
`v5-B-old-vs-new.jpg`, `v5-C-old-vs-new.jpg` (top row old, bottom row new).

## 1. Root causes in the v4 clips

* **A (6319).** The chasm had a floor (`Rect2(1540, 2100, …)`), a climbable
  chimney and a far wall within reach: the leap ended *against the wall*, the
  runner wall-slid, and the rescue was a ledge on that wall plus a launch.
  Nothing on screen or in the physics said the runner would die.
* **B (6320).** The giant stood in front of the plateaus, filling the frame
  with its torso; its slam only toppled a pillar into a flat rectangular
  bridge over its own body; the runner was 6–12 % of the frame. The attack
  never changed the route under the runner.
* **C (6321).** The route was a row of identical bone pillars hopped one
  after another; the jaws snapped on a rhythm not tied to the runner's
  footing; the escape came from a sand jet.

## 2. What was changed (game level)

### A — `level_finale_data.gd`, `scenery.gd`, `capture_finale_pv.gd`

* Gorge rebuilt: 760 px wide (the best leap — full sprint, top gear, full
  jump, air jump, steering all the way — covers ~470 px). **No floor, no
  chimney, no waterfall.** A kill hazard at y 2,700 under the whole gorge.
* Far bank is an **overhang** (`Rect2(2300, 1080, 620, 300)`) whose wall
  recedes under it (`Rect2(2860, 1380, …)`): a falling runner cannot reach a
  wall to slide on or a ledge to catch.
* Gorge art: the far side of the gorge drawn as ridges sinking into
  blue-black haze from 140 px under the lip (nothing stands behind a runner in
  the air); the meadow backdrop no longer shows at the bottom.
* Take: slow-motion starts from the game state (runner falling, air jump
  spent, 330 px short); the call card is on the right, the runner framed on
  the left; YOU traces a platform under the feet; the landing is the fall
  stopping (thud on the contact frame); then a ground jump + air jump to the
  bank. Camera: wide depth shot on the leap → close on the fall → runner and
  platform together on the catch.

### B — `stone_giant.gd` (rewritten), `level_finale_data.gd`, take

* The giant stands well back in the gorge, behind the far plateau, and the
  way past it is a **long natural stone bridge** (8 blocks of uneven width,
  each its own collider, drawn as one rock span until struck).
* Rhythm (clock-driven): notice (eyes flare, body leans) → wind-up (fist
  raised over the bridge, shadow gathering on the stone just ahead) → slam.
  **The slam breaks the bridge:** the block under the fist goes at once, the
  others crack, sag and fall in a wave from the impact (colliders removed).
* The slammed arm stays planted 3.6 s, straight across the gorge: **its
  forearm is a solid ramp** (a collider along the arm's top). Up the forearm
  to the elbow, then a leap down onto the far plateau — the route the attack
  made. The other fist is raised over the arm and **smashes the arm's top**
  0.35 s after the runner leaves it (hurts anyone still there). Then the arm
  lifts (ramp gone) and it repeats.
* Arms longer and thinner (two-bone IK of the painted segments), the body
  never between the runner and the way on; the old toppling pillar and sweep
  are gone.

### C — `bone_maw.gd` (new machine), `make_creature_art.py`, data, take

* New terrain, all fossil bones with real colliders: a **great rib** rising
  over the canyon in three spans (A, B, C; 14°→27°), a **tilted thigh bone**
  below it (upper and lower part; polished — it carries a crouching runner
  down: a slide), a **curved rib** (P2), and a **jawbone ramp** up to the gate.
  The old vertebra deck, the six identical pillars, the sand jets and the high
  rib path were removed.
* The maw (state 1 on the rib): rise → open (wind-up, grit raining off the
  span) → lunge and **bite span B** (shatters, collider gone) → recover
  (shakes the bone from its teeth) → sink. With B gone, **span C tips and
  falls** — with the runner on it — onto the thigh bone: the lower route.
* State 2 (on the thigh bone): it resurfaces behind, chases under the bone,
  **bites the bone's lower end** as the runner jumps from it, chases under the
  curved rib and **bites it** just after the last jump. A bite closing on the
  runner kills.
* Art: two new painted rasters from `make_creature_art.py` — `bone_shaft.png`
  (one long shaft; every span is drawn from a different stretch of it, so no
  two pieces repeat) and `bone_knob.png` (knuckle ends). The painted canyon
  backdrop's ribs were dimmed (`make_finale_assets.py`), and the far rib
  layer tinted, so the walkable bones read in front.

## 3. Key events: game log vs. picture

Times are seconds into each delivered clip (from `shots_report.json`
events). "On screen" was checked on the frames of the delivered MP4.

### rescue_v2.mp4

| t | Game state (log) | On screen |
| --- | --- | --- |
| 0.40 | take-off at x 1525; far bank at 2300 | yes (close, the lip breaking) |
| 0.97 | air jump spent at x 1804 | yes, but in the wide shot (runner ~4–10 % of height) |
| 1.30 | falling, 332 px short of the bank, feet below the lip; slow-mo starts | yes |
| 2.40 / 2.97 | call rings (card right) while the runner keeps falling (left) | yes |
| 3.37 | accept | yes |
| 4.27 | platform built: top 1218, feet 1186 (falling at 1,100 px/s) | yes |
| 4.83 | lands on the platform: vy 1100 → 0 (collision), thud | yes, runner and platform together |
| 6.10 | on the far bank (2371, 1057), thud | yes |

Death without the finger: `test/finale_stage_probe.gd` area grass — the same
leap with no platform falls to the hazard, touching nothing on the way
(`ok`). Area solo: a lone runner in the gorge dies and restarts at the
start (`ok`).

### giant_v2.mp4

| t | Game state (log) | On screen |
| --- | --- | --- |
| 0.02–0.6 | giant notices (state 1), rumble | yes (short wide shot) |
| 1.53 | wind-up: fist over the bridge, shadow at x 18252, runner at 18142 | yes (fist enters from the top) |
| 2.23 | slam: fist at (18252, 262), 115 px in front of the runner; boom/crumble | yes |
| 2.25–3.35 | bridge blocks lose their colliders and fall (crumble per block) | yes |
| 3.43 | runner on the giant's arm (ramp collider solid) | yes |
| 4.83 | leaves the elbow (cycle 3.73; swat at 3.75) | yes |
| 5.02 | other fist lands on the arm's top; runner already clear | yes (fist and runner in frame) |
| 6.08 | on the far plateau, hp 2 | yes |

### bone_canyon_v2.mp4

| t | Game state (log) | On screen |
| --- | --- | --- |
| 0.0–1.6 | diagonal run up spans A→B→C | yes |
| 0.38 | maw rises (state 1) | **no** until ~1.0 s: it rises from below the frame |
| 0.92 | jaws opening under span B (runner at x 21743) | partly (jaw tip at frame bottom) |
| 1.58 | span B bitten: collider gone; runner at 21958, just past B's end (21800); boom/crumble | yes (skull at the span, shards) |
| 1.83 | span C loses its hold and tips | yes |
| 2.17 | runner lands on the thigh bone (lower route, y 346 from y ~40), thud | yes |
| 2.53 | maw resurfaces behind (state 2) | yes |
| 3.93 | thigh bone's lower end bitten (boom/crumble) as the runner jumps | yes |
| 4.30 | runner on the curved rib | yes |
| 4.90 | last jump from the curved rib's end | yes |
| 5.28 | curved rib bitten behind the runner | yes |
| 5.85 | lands on the jawbone ramp by the gate | yes |

Probe checks (`area bone`): B's collider gone while the runner is on C; C
fell; the runner reached the thigh bone; slid; L1b bitten after the runner
left it; P2 bitten after the last jump; checkpoint 11 reached. `area
mechanics`: a runner who stays on the bitten span dies.

## 4. Implemented / not implemented / unverified

Implemented and checked (probe + frames of the delivered clips):

* A: deadly gorge, fall short in the open, platform collision stops the fall,
  death without the finger (automatic test), second jump to the bank.
* B: slam reaches the runner's position, breaks the bridge's colliders, the
  arm becomes a walkable ramp, the second attack lands where the runner left.
* C: bites destroy spans of the runner's path (B, thigh bone end, curved
  rib), the runner rides the collapse to a lower route, slides, jumps, last
  jump.
* Probe `finale_stage_probe.tscn`: 166 / 166. Perf gate 1-10: 131 / 160 draw
  calls, 3212 / 3500 objects.

Not implemented / known weaknesses (judged on the clips):

* A: the wide shot on the leap shows the runner small (~4–10 % of height) for
  about 0.9 s; the zoom-out passes through ~0.2 s where the gorge's dark mass
  fills the frame. The close shots of the fall still show the meadow backdrop
  above the gorge's ridges.
* A: with the gorge deadly, **a lone player cannot pass 1-10's opening**
  (there is no AI guardian). This follows the brief; it is a game-design
  consequence that needs your decision.
* B: the planted arm is large and grey; the runner on it is ~11 % of height
  but low in contrast against it. The arm's lift at the end of the clip
  passes in front of the landing.
* C: the maw is off screen for its first ~0.6 s; the canyon backdrop still
  contains its painted ribs (dimmed, not removed); the jaw-gate fang
  dressing draws as a plain diagonal band in the last second. No roar sound
  (the rumble is reused).
* C: the director's hit-stop was dropped at the first bite: a moving
  platform under a hit-stop throws the runner (huge transferred velocity).
* The guardian cannot stagger the maw (the giant's core shot still works).
* Storyboard beat names in `finale_shots.gd` (e.g. "SWEEP!", "SAND GOES
  VERTICAL") still carry the old wording.

Unverified:

* The other 46 s of the PV were not re-shot; beats 32/33/37–39 now have new
  lengths and the 49 s timeline is not re-balanced.
* Online (host/guest) play of the new machines: they are clock-deterministic
  like the others, but no two-device session was run.
