# 1-10 PV opening rescue — camera A / B / C and the landing

Target: "6363.mp4" (= `rescue_camera_fixed.mp4`). Only camera framing, shot
timing, time scale and the landing were changed. One piece of dressing was
removed (see §5). No new art.

| Deliverable | Where |
| --- | --- |
| 1. `rescue_camera_v2.mp4` — 8.35 s, 1280×720, 60 fps, H.264 + AAC | sent with this report (`build/` is not in git) |
| 2. `rescue_camera_v2_comparison.mp4` — 6363 and the new cut side by side; under each frame: camera FIXED / MOVING / CUT, zoom, game speed | sent with this report |
| 3. the five key scenes, old vs new | `docs/images/stage-1-10/rescue_camera_v2_key_scenes.jpg` |
| 4. camera position, zoom and game speed of every frame | `rescue-camera-v2/rescue_camera_timeline.csv` (`cam_x, cam_y, cam_zoom, time_scale`, runner, events) |
| per-section timing and speed | `rescue-camera-v2/timing_report.csv` |
| camera travel per section, old vs new | `rescue-camera-v2/camera_motion_summary.csv` |
| event log, traces | `rescue-camera-v2/` |

## 1. The three cameras

| Camera | Time (s) | Framing | Movement |
| --- | --- | --- | --- |
| (run) | 0.00–1.00 | 1.3×, the run and the hop | fixed, a slow 130 px drift to the right |
| **A** | 1.00–3.52 | wide, **1.1×**, centre (1960, 1100): both cliffs' edges, the gap, the drop | **fixed** through the leap, the failed fall, the held failure and the rewind (the rewind replays this still frame backwards) |
| **B** | 3.52–5.97 | medium, **1.22×**, centre (1946, 1068) | **fixed**: a cut at the rewind's end, then no movement and no zoom through the slow fall, the call, the finger, the build, the landing and the beat on platform 1 |
| **C** | 5.97–8.35 | same 1.22× | starts at the re-jump: sideways follow only (height locked, smoothing 1.0/s), toward the far bank and on |

**The A → B cut.** Camera B's centre was chosen so the runner is at the
same place on screen on both sides of the cut — (477, 52) in A,
(477, 57) in B — so only the scene around them scales up; nothing jumps.
In the picture the cut lands 2 frames after the join, under the join's
flash. (In the CSV the zoom column switches one frame before the centre
does; the rendered frames are A until the cut, then B.)

**Camera B, from the per-frame record:** every frame from just after the
cut to the re-jump — 144 frames, covering the call, the finger, the build,
the landing and the beat after it — has the same centre (1946, 1068) and zoom 1.22,
unchanged; the runner stays between screen y 56 and 564. The runner, the finger with its
hand, the platform and the landing burst stay inside the frame (checked
on the frames, `rescue_camera_v2_key_scenes.jpg`).

**Size.** Camera B is as close as it can be while holding both the top of
the leap (where the runner is when the rewind ends) and the catch
platform with the YOU hand below it: 1.22×. The runner is **73 px (10.2 %
of the height)**, up from 66 px (9.2 %) in 6363 (+11 %); the finger and the
platform grow the same. At 1.28× and 1.35× (both tried) the hand or the
platform's lower edge left the frame.

## 2. Speed (`timing_report.csv`)

| Out (s) | Section | Game speed |
| --- | --- | --- |
| 1.00–2.85 | take-off, air jump, falls short into the gorge | 1.0× |
| 2.85–3.05 | failure held | 0 |
| 3.05–3.52 | rewind | −1.46× |
| 3.52–3.72 | rewind ends → slow motion (top of the arc) | 0.95 → 0.35× |
| 3.72–4.52 | Discord call (card at real speed) | 0.35 → 0.25× |
| 4.52–4.85 | YOU presses accept and rushes down (cursor at real speed) | 0.26 → 0.30× |
| 4.85–5.28 | stroke, platform builds, runner closes on it | 0.30 → 0.45× |
| 5.28–5.37 | **contact**: hit stop 5 frames → **1.0×** | |
| 5.37–5.97 | **on platform 1**: crouch, recover (0.6 s) | 1.0× |
| 5.97–8.35 | hop to platform 2, jump + air jump to the far bank, run on | 1.0× |

On screen the runner falls ~1080 px/s at full speed and 270–460 px/s in
the slow motion; the cursor rushes at full speed while the runner sinks
slowly.

## 3. The landing

1. The platform is created **70 px** under the falling runner (aimed from
   the runner's own fall: the frames the finger needs at the current time
   scale, plus a 70 px approach) and builds while the runner closes on it.
2. Time eases 0.30 → 0.45× as they close.
3. **Contact** (collision): vy 1100 → 0, floor on; hit stop 5 frames
   (0.08 s); thud + impact sound; burst at the feet; the existing landing
   crouch at its natural proportions; **no camera shake** (removed so
   camera B does not move at all).
4. Full speed; the runner holds the crouch, stands (0.6 s on the
   platform) while the finger adds platform 2.
5. Re-jump at full speed; camera C begins to follow.

## 4. Game proof (`rescue_event_log.txt`)

Platform 1 by the guardian's build ability, created 70 px under the feet;
contact vy 1100 → 0, floor on; platform 2; jump from platform 1 (vy −931);
platform 2; jump + air jump; far bank (2488, 1017); run on. 0 airborne
frames touching a wall; no move beyond velocity × time scale. Without help
(the failed take) the runner falls through nothing and dies at the kill
hazard.

## 5. Changes

* `tools/promotion/capture_finale_pv.gd`: camera B (`RESCUE_SHOT`,
  `RESCUE_ZOOM`) set on the rewind's end; camera C at the re-jump; the
  slow-motion curve (0.35 / 0.25 / 0.30 / 0.45); the platform aimed from
  the finger's frames; the call 0.8 s; no landing shake; 0.6 s on
  platform 1.
* `src/render/finale_foreground.gd`: the dark near rocks drawn along the
  bottom edge over the gorge (added in an earlier round) are **removed** —
  in camera B they covered the landing burst.
* Nothing else in the game changed.

## 6. Unresolved

* The runner in camera B is 73 px (10.2 %): at the low end of the 10–15 %
  target. Larger is not possible with one fixed frame that holds both the
  top of the leap and the catch with the finger's hand.
* The far bank is only partly in camera B (its edge at the right); the full
  bank comes into view with camera C.
* The cut from A to B is 2 frames after the join (under the flash).
* The camera travel figure for the slow-motion section in
  `camera_motion_summary.csv` (35 px) is the record's one-frame lag at the
  cut, not movement; camera B itself has one value for all its frames.
* The burrbug on the far bank reaches the runner ~0.2 s after the clip ends.
