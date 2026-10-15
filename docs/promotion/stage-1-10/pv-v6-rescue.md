# 1-10 PV — the cliff rescue, rebuilt (v6)

Only the rescue (storyboard beats 3–10) was redone. The giant, the bone
canyon and the 49 s PV were not touched. "6330.mp4" is taken to be the v5
clip `rescue_v2.mp4`.

Deliverables (shot from real play, Godot 4.7.2, 60 fps, game sound):

| File | What it shows | Length |
| --- | --- | --- |
| `rescue_without_help.mp4` | Test A: the same leap, nobody answers — falls and dies | 3.4 s |
| `rescue_with_help.mp4` | Test B / the scene: the leap, the fall, the call, the YOU finger's platform, the catch, the way out | 7.0 s |
| `docs/images/stage-1-10/rescue_comparison.jpg` | A and B side by side, with the log values | |
| `docs/images/stage-1-10/rescue_6330_vs_new.jpg` | 6330 vs the new clip, same moments | |
| `rescue-v6/rescue_trace_help.csv`, `rescue_trace_nohelp.csv` | every frame: beat, clock tick, time scale, position, velocity, on floor, on wall, state, dead, events | |
| `rescue-v6/rescue_log_summary.txt` | the events with clip times, wall-contact and teleport checks | |

## 1. What was wrong in 6330

* **The runner hung in the air.** Slow motion went to 0.01–0.03× for about
  2 s while the call rang: the runner moved a few pixels and read as frozen
  beside the far wall.
* **The far bank was barely higher (80 px)** and close behind the runner, so
  nothing looked out of reach; the gorge's depth was only visible in one wide
  frame.
* **The platform appeared and the runner was on it** with no readable
  moment between: the build of the blocks was hidden at 0.02×, the landing
  happened as time snapped back.
* The cliffs were the terrain renderer's textured rectangles.

## 2. What changed

### Terrain (`level_finale_data.gd`, new art)

* Far bank **120 px higher than the lip** (top y 1040), 760 px away, an
  overhang whose wall recedes under it (no wall to reach while falling).
  Gorge has no floor; a kill hazard at y 2700. The best possible leap
  (sprint, full jump, air jump, steering right) tops out 463 px short.
* Cliffs, far side and depth are **new painted PNGs** from
  `tools/promotion/make_gorge_art.py` (the lit, outlined SDF painter used for
  the creatures): `gorge_left.png` (grass run-up, bulging rock strata,
  boulders, vines over the lip, flowers), `gorge_right.png` (grass-topped
  overhang, roots hanging under it), `gorge_far.png` (the gorge's inner wall
  just under the lips, going black within ~300 px, a waterfall under the near
  cliff). The terrain renderer skips those rectangles
  (`painted_ground()`); **collision is still the rectangles**, unchanged
  kind. The waterfall sits left of the leap so nothing bright is behind the
  falling runner.

### The scene (`tools/promotion/capture_finale_pv.gd`, take_opening)

Inputs only (`InputHub.drive_runner`), the guardian's own build ability
(`Guardian.use_active` with a traced path), and the engine's time scale for
slow motion. No position or velocity is written anywhere.

| Clip time | Beat | Camera | Game |
| --- | --- | --- | --- |
| 0.0–1.0 | 3 | wide: both cliffs, the gap, the dark drop | sprint, take-off at 0.43 s, air jump at 0.78 s |
| 1.0–2.0 | 4 | eases in to 1.4× on the runner, the drop under them | apex 1.05 s, 463 px short; falling; slow motion from 1.27 s (0.05×) once level with the bank's top |
| 2.0–2.9 | 5 | runner left, card right | still falling (≈55 px per real second); call: Discord mark, decline, accept — no text |
| 2.9–3.7 | 6 | widens to take the finger in | accepted; the YOU finger swoops under the runner |
| 3.7–4.4 | 7 | runner + stroke + platform | the finger strokes from under the runner toward the bank; platform created at 3.92 s, its blocks build from under the runner; time eases to 0.3×; **contact at 4.12 s: vy 1100 → 0, landing animation**, thud |
| 4.4–7.0 | 8–10 | pulls back: platform, bank, gorge | stands, jumps (4.98 s), air jump, lands on the bank (5.80 s), runs on (checkpoint 1 at 6.53 s) |

The PV-only parts (slow motion, call card, finger cursor, camera) live in the
director; the game's own rules are untouched except the terrain above.

## 3. Proof in the game (logs)

From `rescue_log_summary.txt` (clip seconds):

**A — no help**

| t | event | position | velocity |
| --- | --- | --- | --- |
| 0.43 | jump start (on floor → off) | (1533, 1137) | (492, −1020) |
| 0.78 | air jump | (1706, 935) | (492, −858) |
| 1.05 | fall start (apex passed, 463 px short) | (1837, 819) | (492, 66) |
| 2.83 | **dead** (kill hazard) | (2715, 2654) | — |

Airborne frames touching a wall: **0**. No floor contact after take-off.

**B — with help** (same start, same inputs up to the fall)

| t | event | position | velocity | time scale |
| --- | --- | --- | --- | --- |
| 0.43 / 0.78 / 1.05 | take-off / air jump / fall start | identical to A | | 1.0 |
| 1.27 | slow motion starts | (1944, 934) | (492, 922) | 0.96 → 0.05 |
| 2.92 | call answered | (2011, 1082) | (492, 1100) | 0.05 |
| 3.38 | platform planned under the feet | (2023, 1108) | (492, 1100) | 0.05 |
| 3.92 | platform created: top 1198, x 1983–2233 (feet at 1160) | (2036, 1137) | (492, 1100) | 0.055 |
| 4.12 | **contact: landed on the platform, floor on**, vy 1100 → 0 | (2054, 1175) | (492, 0) | 0.33 |
| 4.98 | jump from the platform (floor off) | (2104, 1175) | (30, −931) | 1.0 |
| 5.32 | air jump | (2179, 1001) | (410, −858) | 1.0 |
| 5.80 | lands on the far bank (floor on) | (2378, 1017) | (410, 0) | 1.0 |
| 6.53 | checkpoint 1, running | (2679, 1017) | (410, 0) | 1.0 |

Airborne frames touching a wall: **0**. Per-frame displacement never exceeds
velocity × time scale (no teleport). Dead: never.

Automatic test (`test/finale_stage_probe.tscn`, area grass/solo): the best
unaided leap dies touching nothing; with a platform placed under the falling
runner the fall stops on it and the runner reaches the bank; a lone runner in
the gorge dies. 166 / 166 checks. Perf gate 1-10: 130 / 160 draw calls,
3191 / 3500 objects.

## 4. Log vs. picture

Checked on frames of the delivered MP4s (`rescue_comparison.jpg`):

* falling clearly — yes (1.0–4.1 s, the runner moves down the frame the whole
  time, faster before 1.27 s and after 3.92 s);
* the finger reaches the falling runner — yes (3.0–3.7 s, under and left of
  them);
* the platform's making is visible — the stroke (3.6–3.9 s) and the blocks
  building (3.92–4.3 s) are visible; the block under the runner is still
  half-built at the contact frame;
* the fall stops on the platform — yes (4.12 s landing pose on the blue
  blocks, the drop beneath);
* without the finger the runner dies — yes (A, 2.83 s);
* the runner reaches the bank and runs on — yes (5.8–7.0 s);
* the call card has no text — yes; it never covers the runner (runner on the
  left third).

## 5. Unsolved / honest limits

* The opening wide shot shows the runner at ~6–7 % of the frame height for
  about a second (needed to show the width and the depth together).
* Slow motion lasts ~2.7 s (1.27–3.95 s); the runner keeps falling, but
  slowly (about 55 px per real second at 0.05×).
* The contact is close: the platform exists 0.2 s (real) before the runner
  lands, and its build animation has not finished under the runner's feet
  at that moment (the platform is solid from the start; only the picture
  builds).
* The escape jump starts from standing (the runner had stopped on landing);
  it needs the air jump to clear the higher bank.
* With the gorge deadly, a lone player cannot pass the opening of 1-10 (no
  AI guardian) — this follows the brief and is a design decision for you.
* The YOU cursor and "YOU" label are small at this zoom.
* The left painted cliff joins the run-up slope with a 40 px soft edge.
