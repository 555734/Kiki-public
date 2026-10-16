# 1-10 PV opening rescue — final pass (rescue_rewind_final_v2)

Base: "6346.mp4" (= v8 `rescue_rewind.mp4`); tempo reference "6347.mp4"
(= v8 `rescue_direct.mp4`). Only the cliff rescue was made; no 49 s PV, no
giant, no bone canyon.

| Deliverable | Where |
| --- | --- |
| 1. `rescue_rewind_final_v2.mp4` (7.40 s, 1280×720, 60 fps, H.264 + AAC) | sent with this report (not in git; `build/` is ignored) |
| 2. `rescue_before_after.jpg` — the five moments, old vs new | `docs/images/stage-1-10/rescue_before_after.jpg` |
| 3. `rescue_camera_timeline.csv` — every frame: segment, source frame, camera centre and zoom, runner | `rescue-final-v2/rescue_camera_timeline.csv` |
| 4. rescue event log, per-frame traces, edit timeline | `rescue-final-v2/rescue_event_log.txt`, `rescue_trace_*.csv`, `timeline.json` |
| frame strip of the catch (20 fps) | `docs/images/stage-1-10/rescue_catch_frames.jpg` |

## Phase 1 — what was wrong in 6346, and where

| Moment | Problem | Cause (code) |
| --- | --- | --- |
| Fall | the runner ~110 px tall in a frame mostly flat grey/beige rock | `gorge_wall.png` (one big wall, top above the leap) + `gorge_far.png` (grey ridges) behind the whole fall; camera 1.95× |
| Rewind end | ended mid-fall, call already ringing — no moment of "time runs again" | branch at "feet past the bank top" in `take_opening` |
| Call | runner ~16 % of the height, centre-left | follow camera 1.95× |
| Platform | stroke and build seen at 1.9×; platform pale on grey ridges; created 65 px under the feet | camera fit kept bank + platform; `gorge_far` behind; `PV_P1_DROP` 130 |
| Landing | 2.1× (fit could drop it to 1.7×), squash flattened the crouch pose, no hit stop | camera fit, `runner_visual.gd` squash × 0.22 on the crouch pose |
| Limbs | flail = one pose tilting; no reaction to the platform | `runner_visual.gd` |
| Escape | runner at the top edge of frame on the jump to the bank | escape camera fit kept platform 1 in frame |

## Phase 2 — the rescue, redesigned (game)

`tools/promotion/capture_finale_pv.gd` (`take_opening`), inputs only, the
guardian's own build ability, the engine's time scale:

1. **Branch = top of the leap** (471 px short). Both takes are identical up
   to it; the rewind ends there.
2. Help take: **normal time** — the runner visibly falls again (0.31 s,
   accelerating to 1100 px/s).
3. When the feet drop **level with the far bank's top** ("danger") the
   **call rings**; the stick is let go; time eases to 0.06×.
4. YOU presses accept on the card; the cursor **rushes** (12 frames) to just
   under the runner; platform 1 (**90 px**) is aimed from the runner's own
   velocity (terminal fall, air brake on the drift).
5. Stroke (9 frames at 0.16×) — the platform is **created 34 px under the
   feet**; time 0.22×; its blocks build out from the stroke; the runner's
   legs come down (brace pose) and **lands 9 frames later** (contact:
   vy 1100 → 0, on floor), as the blocks finish.
6. Contact: hit stop 5 frames (engine time scale 0.02, the collision is
   real), thud, impact sound, short shake, burst at the feet, zoom punch.
7. Crouch, back up; the finger adds platform 2 (92 px, 112 px higher); a
   hard jump (dust, stretch), on it, at once jump + air jump onto the bank,
   running on.

`src/runner/runner_visual.gd` (all stages, picture only; driven by the
runner's real velocity and floor contact):

* falling fast: arms and legs **thrash** (the two open poses alternate with
  a tilt);
* a solid drawn platform within 150 px under falling feet: **brace** (legs
  down, upright);
* a landing at full fall speed: **knees bent** (crouch pose held ~0.2 s,
  drawn at its own proportions), then a **spring back** past standing;
* take-off from the ground: a vertical stretch and **dust kicked back**.

## Phase 3 — camera and art

Camera per scene (from `rescue_camera_timeline.csv`; hero height = 60 px ×
zoom):

| t (s) | Scene | Zoom | Hero |
| --- | --- | --- | --- |
| 1.58 | take-off: both cliffs and the gap | 1.21 | 72 px |
| 2.18 / 3.82 | top of the leap = rewind end | 1.88 | 113 px |
| 3.05 | failure, deep in the dark | 2.01 | 121 px |
| 4.13 | danger, call | 2.25 → 2.59 | 135–155 px |
| 4.90–5.15 | finger, stroke, platform | 2.70 → 2.86 | 162–171 px |
| 5.30 | landing | 2.95 (+ punch) | 177 px |
| 6.00–6.83 | jump to the bank (arc + bank) | 1.87 → 1.77 | 106–112 px |
| 7.33 | running on | 1.89 | 114 px |

6346 for comparison (configured): wide 1.22, fall 1.95, call 1.95,
platform 1.9, landing 2.1 (could fall to 1.7), escape 1.55.

Art (`tools/promotion/make_gorge_art.py`, new `gorge_wall.png`): the single
wall is replaced by **three ranges of mesas stepping into haze** — the
farthest low and pale, the middle with **two waterfalls into mist**, the
nearest warm with shrubs on its ledges — each with its own strata (band
heights, tilt), **open sky above**, and **the gorge's darkness** below the
rims. `gorge_far` (the grey ridges) is no longer placed. The near rock
silhouettes along the bottom edge are smaller and lighter. The far bank,
near cliff and collision are unchanged.

## Phase 4 — edit and sound

`tools/promotion/edit_rescue_versions.py`: fall (nohelp take) → failure
held 12 frames (colour drains, dark edge) → rewind 28 frames (the fall's
own frames backwards, eased, ghosts, ◀◀, fades out before the join) →
flash at the join, the help take from the next frame (join frames identical:
0 pixels differ).

Sounds and where they sit (s, in the final MP4): wind on the fall
(2.2–3.05), failure sting (2.9), rewind whirr + reversed swell (3.27–3.82),
resume click (3.82), **call ring** (4.13 and 4.43, game), **accept** (4.65,
game), finger swish (4.70), **build** (4.90 game, 5.15 sparkle), **landing
thud + impact** (5.30), **jump** sounds (5.60, 6.00, 6.30 — the game's own,
on the jump frames), arrival chime (6.83). Peak −0.6 dBFS, no clipping.

## Phase 5 — old vs new (`rescue_before_after.jpg`)

| Moment | Changed | Not improved |
| --- | --- | --- |
| 1 Fall failure | close (2.0×), the runner sinking into the gorge's dark under the far bank's roots, held a beat | — |
| 2 Rewind end | ends on the top of the leap, the runner 113 px, with rock and some sky behind; normal time runs 0.31 s before the call | the far bank is out of frame at this zoom (the relation to it returns 0.3 s later) |
| 3 Discord call | 2.59×, runner in the centre, small card in the empty top-left | — |
| 4 Rescue | runner, finger and platform fill the frame (2.7–2.95×); platform made 34 px under the feet, landing 0.15 s later; brace, hit stop, crouch | the platform is pale while it builds (the game's own build look) |
| 5 Far bank | jump arc and bank framed (1.8×), runner never at the frame edge, running on | — |

## Proof in the game (`rescue_event_log.txt`)

No help: falls past the bank's top, no contact with anything, dies at the
kill hazard (2715, 2654). Help (times in the help take): danger 2.50 →
answered 3.02 → stroke 3.27 → **platform 1 created 3.52, feet 34 px above
it** → **contact 3.67: vy 1100 → 0, floor on** → platform 2 3.97 →
**jump from platform 1 3.98** (vy −931) → on platform 2 4.33 → jump + air
jump → **far bank 5.20** → running 5.70. Both takes: 0 airborne frames
touching a wall; no per-frame move beyond velocity × time scale. Nothing
writes the runner's position or velocity.

## Effect on the game

* `test/finale_stage_probe.tscn`: 166 / 166.
* Other stage probes (cave, desert, horror, parade 67 checks, sea, swamp,
  tower): all pass.
* Perf gate: all stages within budget; 1-10 133 / 160 draw calls, 3202 /
  3500 objects.
* `runner_visual.gd` is shared by every stage (pictures only): hard
  landings show the crouch a little longer; a falling runner over a drawn
  platform braces.

## Unresolved

* At the rewind end (top of the leap) the far bank is outside the frame
  (both together would need ≤ 1.4×).
* The platform's build look (pale, then solid) and the green "rescue" ring
  with its arrow and the yellow launch rings are the game's own effects.
* The far canyon's shrubs are simple rounded clumps.
* The fall-to-landing slow motion is about 1.2 s real time (the fall goes
  on all through it).
* A lone player still cannot pass the opening (design decision from v6).
* The burrbug on the far bank hits the runner ~0.8 s after the clip ends.
