# 1-10 PV opening rescue — pacing and slow motion (rescue_pacing_v3)

Target: `rescue_rewind_final_v2.mp4` (7.4 s). Only the timing and the
speed of the rescue were reworked; no new backgrounds, characters or
gimmicks; nothing outside the cliff rescue.

| Deliverable | Where |
| --- | --- |
| `rescue_pacing_v3.mp4` — 10.27 s, 1280×720, 60 fps, H.264 + AAC | sent with this report (`build/` is not in git) |
| `rescue_pacing_comparison.mp4` — old and new side by side, the game speed of every frame printed under the new one | sent with this report |
| `timing_report.csv` — every section: output times, source frames / recording times, game speed, curve, distance moved, return to full speed | `rescue-pacing-v3/timing_report.csv` |
| speed-change stills, old vs new | `docs/images/stage-1-10/rescue_pacing_speed_points.jpg` |
| per-frame camera and time scale, event log, traces, edit timeline | `rescue-pacing-v3/` |

## 1. Why the old clip read as fast (with numbers from its own trace)

* After the rewind the runner fell at full speed for only 0.31 s, then the
  time scale dropped **1.0 → 0.06 in 6 frames** — a stop, not a slow-down.
* At 0.06× the runner moves 1 px of the world per frame, and the camera
  followed and zoomed onto them, so on screen they **stood still** while the
  card and the cursor moved.
* The whole slowed part was ~1.1 s; call 0.5 s, finger 0.25 s, stroke
  0.25 s; the landing 0.15 s after the platform appeared.

## 2. Provisional edit first (step 4 of the brief)

The current recording was time-stretched in the editor (frame
interpolation): the 0.31 s fall after the rewind at 0.35×, the slowed part
at 0.6×. Result (8.6 s): longer but still unclear — stretching in the
editor also slowed the **card and the YOU cursor** (the contrast the brief
asks for is lost), and the runner stayed fixed in the frame because the
camera followed them. Conclusion: the slow motion has to happen **in the
game** (everything game-side slows, the UI and the finger do not), and the
camera must hold so the slow fall is seen. Only that part was re-shot
(the help take after the top of the leap; the no-help take and everything
before the branch are unchanged and frame-identical).

## 3. How the slow motion is made

The engine's time scale (`Engine.time_scale`) is the game's own slow
motion: every physics step shrinks with it (at 0.07× a 60 fps frame is a
1/857 s step), so the runner, the scarf, the limbs, the platform's build
and the dust are all simulated at that rate — no frames are duplicated or
interpolated (no judder, no ghosting). The call card, the YOU cursor and
its stroke are driven per real frame, so they keep real speed. The physics
(gravity, jump, terminal speed) is unchanged.

The fall the physics allows from the top of the leap to a catch the runner
can still escape from is ~440 px (≈ 0.5 s of game time). Spread over
≈ 3.5 s of film, that gives the curve below; the runner never stops (still
190–530 screen px/s).

## 4. The new timing (from `timing_report.csv`)

| Out (s) | Section | Game speed | Runner on screen |
| --- | --- | --- | --- |
| 0.00–1.00 | run, hop the enemy | 1.0× | 1300 px/s |
| 1.00–2.18 | wide, take-off, air jump | 1.0× | 811 px/s |
| 2.18–3.07 | falls short into the gorge | 1.0× | 2182 px/s |
| 3.07–3.27 | failure held | 0 (frozen) | 0 |
| 3.27–3.85 | rewind (the fall reversed, eased) | −1.5× | 3304 px/s |
| 3.85–4.55 | **slow motion starts**: falling again | 1.0 → 0.28× (8 frames) | 526 px/s |
| 4.55–5.75 | Discord call (card real time, 2 rings) | 0.28 → 0.12× | 363 px/s |
| 5.75–6.25 | YOU presses accept, rushes down (cursor real time) | 0.12 → 0.07× | 222 px/s |
| 6.25–7.38 | stroke, platform builds, runner comes down onto it | 0.07× | 193 px/s |
| 7.38–7.47 | **contact**: hit stop 5 frames (0.08 s) → **1.0×** | 0.02 → 1.0× | — |
| 7.47–8.00 | caught: a beat on platform 1, platform 2 added | 1.0× | 84 px/s |
| 8.00–9.20 | hop to platform 2, jump + air jump to the bank | 1.0× | 1243 px/s |
| 9.20–10.27 | on the far bank, running on | 1.0× | 771 px/s |

Full speed returns at **7.47 s**. Same moment, old vs new: the call is on
screen 1.2 s (was 0.5 s); the finger 0.5 s rushing + 1.13 s stroking and
building (was 0.5 s in all); 0.53 s on platform 1 before the next jump (was
0.3 s).

## 5. Camera, by section

* Fall and failure (1.0×): close and following — fast.
* Slow motion start and call: the frame keeps the runner and the far bank's
  corner; it drifts as the runner sinks slowly; card in the empty top-left.
* Finger and platform: **a still frame** (2.56×) set when the call is
  answered — the runner at the top, the platform's line at the bottom; the
  runner drops through it in slow motion; no zoom change before the
  contact.
* Escape (1.0×): pulls back to the arc and the bank; follows the run.

## 6. Sound, by section

Fall: wind (raised), failure sting. Rewind: reversed game sound and music,
whirr, reversed swell, click on the join. **Slow motion**: a falling
"time-thickens" whoomp at its start; the music bed low-passed and ducked
for the whole slow part, so the **ring** (×2), the **accept**, the finger's
swish and the **build** sounds stand alone. **Contact**: thud + impact, then
a rising rush as full speed returns, the music back bright; game jump
sounds on the jumps; arrival chime. Peak 0.88 (−1.1 dBFS), no clipping.

## 7. Checks (on the delivered MP4)

| Check | Result |
| --- | --- |
| The danger of the fall reads | yes — 2182 px/s into the dark, held |
| The rewind reads | yes — ◀◀, reversed motion and camera, eased |
| Slow motion is entered and reads as slow | yes — 2182 → 526 → 363 → 193 px/s on screen; limbs, scarf and build slowed |
| The runner never looks stopped | yes — moves every frame (min 193 px/s on screen) |
| The call can be read | yes — 1.2 s on screen, two rings |
| The finger and the platform's build can be read | yes — 0.5 s rush, 1.13 s stroke and build, both in one still frame |
| The landing is clear | yes — hit stop, burst, thud, crouch |
| Full speed returns with a kick | yes — 0.02× → 1.0× at 7.47 s, rush sound, jumps at full speed |

Game proof (help take, `rescue_event_log.txt`): platform 1 created by the
guardian's build ability 53 px under the feet; contact vy 1100 → 0, floor
on; jump from platform 1; platform 2; far bank; 0 airborne frames
touching a wall; no move beyond velocity × time scale. No game code
changed this round (director and editor only).

## 8. Unresolved

* The requested 0.25–0.35× for the call and 0.4× for the build cannot be
  held for that long: the physics allows ~0.5 s of game time between the
  top of the leap and a catch the runner can escape from. The call runs
  at 0.28 → 0.12×, the finger and the build at 0.07×; the runner still
  moves 190–360 px/s on screen.
* The escape plays at 1.0× (not 1.2×).
* The old clip's per-frame game speed is not printed in the comparison
  video (its recording did not log the time scale per frame).
* The burrbug on the far bank reaches the runner ~0.4 s after the clip ends.
