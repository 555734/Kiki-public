# 1-10 PV opening rescue — camera work cut back (fixed camera)

Target: "6358.mp4" (= `rescue_pacing_v3.mp4`). Only the camera and the slow
motion's speeds were changed; background, terrain, characters and gimmicks
are as they were.

| Deliverable | Where |
| --- | --- |
| 1. `rescue_camera_fixed.mp4` — 8.42 s, 1280×720, 60 fps, H.264 + AAC | sent with this report (`build/` is not in git) |
| 2. `rescue_camera_comparison.mp4` — 6358 and the new cut side by side; under each frame: camera FIXED / MOVING / ZOOMING / CUT, the zoom, the game speed | sent with this report |
| 3. camera position and zoom of every frame | `rescue-camera-fixed/rescue_camera_timeline.csv` (`t_s, segment, source, source_frame, cam_x, cam_y, cam_zoom, runner_x, runner_y, runner_vy, on_floor, time_scale, events`) |
| camera movement per section, old vs new | `rescue-camera-fixed/camera_motion_summary.csv` |
| timing per section | `rescue-camera-fixed/timing_report.csv` |
| event log, traces | `rescue-camera-fixed/` |

## 1. What moved the camera in 6358, and what was removed

All in `tools/promotion/capture_finale_pv.gd`, `take_opening` (the game's
own camera is driven by this director during the PV shots).

| # | Camera move in 6358 | When | Removed / replaced by |
| --- | --- | --- | --- |
| 1 | follow with 190 px look-ahead, offset, smoothing, **1.95× zoom and a 2° tilt** | run | **fixed** frame (1.3×) with a slow 130 px drift to the right; no tilt |
| 2 | second follow (1.8×, look-ahead 110) re-set before the hop | hop | removed |
| 3 | "frame" camera re-fitting to the runner and the far bank every frame (1.22×) | take-off | **fixed gorge shot** (below) |
| 4 | re-fit on the way up, **zooming to 1.6×** | rise | removed |
| 5 | re-fit from the air jump, **zooming to 2.1×** | air jump → top | removed |
| 6 | re-fit beside the falling runner (**2.3×**), following them down | fall (both takes) | removed |
| 7 | follow (**2.0×**, fast vertical follow) on the failed fall | failure | removed — the runner falls through the fixed frame; the failure is cut while they are still in it |
| 8 | (the rewind replayed moves 3–7 backwards) | rewind | the rewind now replays a **still** camera; nothing was added |
| 9 | follow (**2.6×**) on the call | call | removed |
| 10 | still frame re-fitted at the answer, **2.56×**, a zoom change mid-rescue | finger, platform | removed |
| 11 | **zoom punch** + 5 px shake on landing | contact | punch removed; a 3 px shake for 5 frames is kept |
| 12 | re-fit pulling back (1.8× → 1.3×) for the hop | platform 1 → 2 | removed |
| 13 | re-fit on the jump to the bank | jump | removed |
| 14 | follow (1.9×, look-ahead 120) on the bank | run on | slow sideways follow, **height locked, same zoom** |
| 15 | game screen shake fed into the PV camera (`fx` 0.4) | lip crumbling etc. | `fx` 0 in every shot |

## 2. The new camera

| Time (s) | Shot | Camera |
| --- | --- | --- |
| 0.00–1.00 | run, hop | fixed, 1.3×, drifts 130 px right over ~1.8 s; the runner crosses the frame |
| 1.00 | — | one cut |
| 1.00–5.60 | leap, air jump, failed fall, failure held, rewind, slow motion, call, finger, platform, landing | **one fixed shot**, centre (1960, 1100), **1.1×**: the near lip at the left, the far bank's edge at the right, the top of the leap at the top, the drop below; the call card in the empty top-left; the finger, the platform and the landing in the lower middle |
| 5.60–8.42 | caught → platform 2 → far bank → run on | sideways follow only (height locked at 1100, zoom 1.1, smoothing 1.2/s) |

The rescue's framing is the gorge shot itself, set before the leap; it
does not change during the call, the finger, the build or the landing. The
runner rises to the top of the frame, hangs, sinks through it in slow
motion, and lands in the lower middle.

Measured from the per-frame camera record (`camera_motion_summary.csv`):

| Section | 6358: camera travel / frames zooming | New |
| --- | --- | --- |
| run and hop | 513 px / 37 % (1.80–1.95×) | 95 px (the drift) / 0 % |
| leap and failed fall | 1293 px / 76 % (1.13–2.24×) | 1 px / 0 % |
| rewind | 830 px / 82 % | 0 px / 0 % |
| slow motion, call, finger, platform, landing | 426 px / 29 % (1.88–2.56×) | 11 px (the landing shake) / 0 % |
| escape and run | 1098 px / 38 % | 724 px (sideways only) / 0 % |
| whole clip | 4172 px, zoom 1.13–2.56× | 832 px, zoom 1.1 (1.3 for the run) |

## 3. Slow motion

Speeds are now **0.35× → 0.28× → 0.25×** (no 0.07×). To fit them into
the fall the physics allows, the rewind ends earlier — just after the air
jump, while the runner is still rising — so the slow motion covers the
last of the rise, the top of the arc and the fall:

| Out (s) | Section | Game speed | Runner on screen |
| --- | --- | --- | --- |
| 2.15–2.85 | rises, tops out short, falls into the gorge | 1.0× | 1078 px/s |
| 2.85–3.05 | failure held | 0 | 0 |
| 3.05–3.52 | rewind | −1.46× | — |
| 3.52–3.72 | slow motion begins (top of the arc) | 0.95 → 0.35× | 276 px/s |
| 3.72–4.68 | Discord call (card real time) | 0.35 → 0.28× | 295 px/s |
| 4.68–5.02 | YOU answers, rushes down (cursor real time) | 0.28 → 0.25× | 333 px/s |
| 5.02–5.52 | stroke, platform builds, runner lands on it | 0.25× | 312 px/s |
| 5.52–5.60 | hit stop 5 frames → **1.0×** | | |
| 5.60– | platform 2, far bank, run | 1.0× | 450–740 px/s |

With the camera still, the same fall reads at ~1080 px/s at full speed and
~300 px/s in slow motion. Platform 1 is created 61 px under the falling
runner (contact 0.23 s later, vy 1100 → 0); escape and arrival as before.

## 4. Checks on the delivered MP4

* Lip, gap, far bank and runner stay in the same places on screen from the
  leap to the landing; the runner never leaves the frame.
* The rewind replays a still frame; the frames before and after the join
  are identical (0 pixels differ), so nothing jumps.
* Call card, finger, platform and runner are all on screen together; the
  card covers only background.
* Game proof (`rescue_event_log.txt`): platform 1 by the guardian's build
  ability; contact vy 1100 → 0, floor on; platform 2; far bank; 0 airborne
  frames touching a wall; no move beyond velocity × time scale.
* No game code changed (director and editor only).

## 5. Unresolved

* With one wide fixed shot the runner is ~66 px tall (9 % of the height)
  through the rescue, smaller than in 6358 (up to 2.56×); the finger, the
  platform and the landing are smaller too.
* The clip is 8.4 s (6358: 10.3 s): the slow motion at 0.25–0.35× uses the
  available fall faster than at 0.07–0.12×.
* The slow motion before the call (after the rewind) is short (0.2 s); most
  of the slow part is under the call.
* One cut remains (run → gorge shot, at 1.0 s).
* The burrbug on the far bank reaches the runner ~0.2 s after the clip ends.
