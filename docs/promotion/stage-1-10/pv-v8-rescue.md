# 1-10 PV opening — the rewind rescue, quality pass (v8)

Target: "6342.mp4" (= v7 `rescue_rewind.mp4`). Only the opening rescue was
reworked; the 49 s PV, the giant and the bone canyon were not touched.

| File | What | Length |
| --- | --- | --- |
| `rescue_rewind.mp4` | **the deliverable**: run, leap, falls short, the failure held, rewind to mid-fall, call, YOU's short platform under the feet, landing, second platform, far bank, run on | 7.30 s, 1280×720, 60 fps, H.264 + AAC |
| `rescue_direct.mp4` | the same help take without the failure and rewind (for reference) | 5.95 s |
| `docs/images/stage-1-10/rescue_v8_vs_6342_a.jpg`, `_b.jpg` | old (6342) vs new, the same nine scenes | |
| `docs/images/stage-1-10/rescue_v8_terrain_map.jpg` | the whole gorge from the game, collision boxes, both recorded paths, the two platforms | |
| `docs/images/stage-1-10/rescue_v8_rewind_contact.jpg` | one frame per second, labelled | |
| `rescue-v8/rescue_event_log.txt` | the events of both takes with clip times, contact, wall and teleport checks | |
| `rescue-v8/rescue_trace_help.csv`, `rescue_trace_nohelp.csv` | every frame: position, velocity, floor/wall contact, time scale, events | |
| `rescue-v8/timeline.json` | the edit's segments and event times | |

## 1. What was wrong in 6342 (analysis)

* **Sky and meadow everywhere.** From the leap to the landing the frame was
  mostly blue sky and the meadow backdrop; the gorge was a grey rim at the
  bottom. Nothing behind the runner said "high over a drop".
* **Boxy cliffs.** Two brown slabs with the same oval boulders, flat tops,
  vertical sides.
* **Weak failure and rewind.** The failure was the runner small in the dark;
  the rewind was a mild tint over the same shots, ending at the top of the
  leap (the runner rising, not in danger).
* **The rescue looked easy.** Platform 1 was a 225 px slab created 187 px
  under the falling runner (seen as a safe bridge before they reached it);
  the runner had no take-off, reach, panic or impact poses.
* **Call card** 300×420 on the right third, over the far bank, with a 28 %
  darkening of the whole frame.

## 2. Game-side changes

### Terrain and art (new production PNGs, `tools/promotion/make_gorge_art.py`)

* `gorge_wall.png` (new, 1900×2300, world 1300,520): the far wall of the
  gorge — a sandstone massif with weathered butte skyline, strata bands,
  worn gullies, moss and shrubs on the ledges, a waterfall pouring from a
  notch into mist, hazed with distance and sinking into the gorge's dark
  below the lips. It rises above the leap's apex and **sinks behind both
  cliffs at its ends** (sky beyond), so the leap and the fall are seen
  against rock, not sky.
* `gorge_left.png` (redrawn): undercut lip, a buttress with a ledge and a
  small tree half way down, wavy strata, angular rock facets, vines.
* `gorge_right.png` (redrawn): a forward-leaning overhang with rock teeth on
  its underside, hanging roots, a ledge and tree, strata. Left and right
  differ in height (the far bank is 120 px higher), outline and mass.
* Same soft, outlined, lit raster style as the rest of 1-10 (the SDF
  painter used for the creatures); no flat rectangles.
* `finale_foreground.gd`: when the camera is over the gorge (no ground at
  the bottom of the screen), dark near outcrops slide along the bottom
  edge at 1.45× parallax — a foreground plane for the fall; they stay in the
  bottom fifth of the frame and never reach the runner.
* Collision is unchanged (the same rectangles as v6/v7): the art is painted
  over it (see the terrain map).

### Runner animation (`src/runner/runner_visual.gd`, all stages, visual only)

* **Take-off spring**: a vertical stretch on the frame a jump starts (decays
  in ~0.15 s).
* **Reach**: after an air jump, near the top of the arc and moving forward,
  the runner uses the `runner_reach` pose (arms forward), leaning forward.
* **Panic**: falling fast (vy > 700) for more than 0.12 s, the reach pose
  with a flailing tilt.
* Landing squash, the `runner_land` crouch and the run cycle are the
  existing ones. The runner is moved only by input and physics.

### The rescue (`tools/promotion/capture_finale_pv.gd`, take_opening)

* The two takes (help / nohelp) share inputs and camera up to the
  **branch**, which is now **mid-fall**: the runner falling past the top
  of the far bank, 307 px short, at terminal speed. That is where the
  rewind returns to (the dangerous position) and where the call comes.
* After the branch (help) the stick is let go (the air brake slows the
  runner's drift — real input); time eases to 0.045× for the call, 0.1×
  for the finger, 0.16× for the stroke, then back to 1× over 9 frames. The
  runner keeps falling the whole time (log: vy 1100 throughout).
* The YOU cursor appears on the card, presses accept, and **rushes** (14
  frames) to a point under the runner. Platform 1 is aimed from the
  runner's own state (feet + 130 px, the x where they will land given their
  velocity and the air brake) and is **90 px wide** (the build ability's
  minimum is 70). It is created **65 px under the feet**; the runner lands
  on it **0.11 s later** (contact: vy 1100 → 0).
* The finger adds platform 2 (92 px, 112 px higher, toward the bank) while
  the runner takes the landing; a hard jump to it, an immediate jump off it
  with the air jump onto the far bank, then a run.
* Call card: `pv_overlay.gd` gained `call_centre`, `call_scale`,
  `call_dim`; for this shot the card is 56 % size in the empty top-left of
  the frame, with a 10 % dim. Icon, decline and accept only, no text.
  Defaults are unchanged for the other PV takes.

## 3. Edit (`tools/promotion/edit_rescue_versions.py`)

Version A is built frame by frame in Python:

1. the nohelp take up to `fail_end` (deep in the gorge);
2. **the failure held** 14 frames (0.23 s), draining of colour with a dark
   edge; the failure sting;
3. **the rewind**, 36 frames: the fall's own frames backwards (the runner
   and the camera — hence the background — go back together), eased (it
   lurches off, races, settles), ghosts of the later frames, cool tint,
   colour fringe, tape lines and a ◀◀ mark — at most 35 % desaturation, so
   the runner stays plain; all of it fades out before the join;
   reversed game sound and music, a rewind whirr, a reversed swell into the
   join;
4. **the join** on the frame before the branch: the two takes are
   pixel-identical there (mean difference 0.0, 0 pixels differ — checked by
   the script); a 7-frame flash and a click as time starts again, and the
   call rings on that same moment.

The rewind is an edit only; the game has no time reversal. Everything else
in the clip is the recorded game.

## 4. Time structure (rescue_rewind.mp4)

| t (s) | picture | camera |
| --- | --- | --- |
| 0.00–1.00 | sprint, hop the enemy | low follow |
| 1.00–1.58 | both cliffs, the gap, the drop ahead | wide on the cliffs, 1.22× |
| 1.58–2.18 | take-off (spring), air jump, reach at the top, 471 px short | moves in, bank kept in frame, 1.5× |
| 2.18–3.02 | falls past the far bank's top and into the dark (panic pose, wind) | close beside the runner, 1.95×/1.8×, depth under them |
| 3.02–3.27 | the failure held | |
| 3.27–3.87 | **rewind** to mid-fall | (the fall's camera, backwards) |
| 3.87–4.53 | the call rings (top-left), YOU presses accept | 1.95× on the runner |
| 4.53–5.07 | YOU rushes under the runner, strokes the short platform | runner + finger + platform, 1.9× |
| 5.07–5.18 | built; time back to normal; **landing** 5.18 (burst, thud, shake, zoom punch) | 2.1× on the landing |
| 5.18–6.55 | step 2 appears 5.38; hop (5.40), lands (5.75), jump + air jump, far bank 6.55 | pulls back to platforms + bank, 1.55× |
| 6.55–7.30 | runs on (checkpoint 6.97) | follow, 1.7× |

## 5. Proof in the game (from `rescue_event_log.txt`)

No help — falls with nothing under it:

| t | event | position | velocity |
| --- | --- | --- | --- |
| 1.58 | take-off | (1533, 1137) | (492, −1020) |
| 2.18 | top of the arc, 471 px short | (1829, 818) | (492, 0) |
| 2.52 | branch: falling past the bank's top | (1993, 1041) | (492, 1100) |
| 3.02 | deep in the gorge (end of the shown fall) | (2239, 1591) | (492, 1100) |
| 3.98 | **dead** at the kill hazard | (2715, 2654) | — |

With help (times in rescue_direct.mp4; add 1.35 s for rescue_rewind.mp4):

| t | event | position | velocity | time scale | floor |
| --- | --- | --- | --- | --- | --- |
| 2.52 | branch (same as above) | (1993, 1041) | (492, 1100) | 1.0 → 0.045 | off |
| 3.18 | call answered | (2032, 1135) | (412, 1100) | 0.045 | off |
| 3.72 | **platform 1 created** (guardian build ability): top 1291, 90 px; feet 1226 | (2055, 1203) | (342, 1100) | 0.19 | off |
| 3.83 | **contact**: the fall stops on it | (2073, 1268) | (272, **0**) | 1.0 | **on** |
| 4.03 | **platform 2 created**: top 1179, 92 px | | | 1.0 | on |
| 4.05 | **jump from platform 1** | (2088, 1252) | (30, −931) | 1.0 | off |
| 4.40 | lands on platform 2 | (2177, 1156) | (410, 0) | 1.0 | on |
| 4.45 / 4.73 | jump from platform 2 / air jump | (2197, 1139) | (410, −1020) | 1.0 | off |
| 5.20 | **on the far bank** | (2505, 1017) | (410, 0) | 1.0 | on |
| 5.88 | running on (clip end) | (2785, 1017) | (410, 0) | 1.0 | on |

Both takes: 0 airborne frames touching a wall; no per-frame move beyond
velocity × time scale (no teleport); positions and velocities are never
written by the director. The rewind section of the video is the nohelp
recording reversed; the rescue section is the help recording forward.

## 6. Old vs new, item by item (evidence: the comparison sheets)

| Item | 6342 | v8 |
| --- | --- | --- |
| Hero visibility | wide 0.85× (≈ 50 px), fall 1.6×, call 1.8× against sky | wide 1.22× (≈ 73 px), fall 1.95×, landing 2.1×; against warm rock, high contrast |
| Cliff terrain and depth | two slabs with repeated oval boulders; sky behind | undercut lip with buttress, ledge and tree; overhang with rock teeth and roots; far wall with strata, gullies, waterfall; dark depth below; foreground outcrops |
| Fall danger | falls in front of the sky; small in the dark at the end | falls close to camera past the bank's edge, the drop under them, panic pose |
| Rewind clarity | mild tint, ends at the top of the leap (rising) | held failure, eased backwards run with ghosts and ◀◀, ends mid-fall (danger), flash + call on the same beat |
| Finger and platform | 225 px slab, 187 px under the feet, seen early | YOU presses accept, rushes in; 90 px platform 65 px under the feet |
| Landing moment | contact during a time ramp, 1.3× | 0.11 s after creation, 2.1×, burst + thud + shake + punch, crouch pose |
| Arrival | small at 1.2×, ends quickly | second step, jump + air jump onto the bank, runs on at 1.7× |

## 7. Effect on the rest of the game

* `test/finale_stage_probe.tscn`: 166 / 166 checks (unchanged count).
* Other stages' probes (`runner_visual.gd` is shared): cave, desert,
  horror, parade (67 checks), sea, swamp, tower — all pass.
* Perf gate (`tools/perf-gate.sh`): every stage within budget; 1-10 at
  130 / 160 draw calls and 3196 / 3500 objects (v7: 130 / 3191).
* `pv_overlay.gd`: new fields default to the old card; other takes
  unchanged. `finale_foreground.gd`: draws only over the 1-10 gorge
  (x 1350–2500, grass zone, no ground under the screen).

## 8. Unresolved

* The wide shot of the leap still shows the runner at ≈ 10 % of the frame
  height for ~0.6 s (needed for both cliff tops and the gap).
* The far wall's waterfall reads as a pale column behind the far bank in
  the last second (its plunge is hidden behind the bank).
* The rewind is 0.6 s (the shown fall is 0.5 s); the brief allowed it as an
  edit.
* The launch rings drawn by the build ability beside each platform (yellow
  circles) are the game's own and stay visible.
* With the gorge deadly, a lone player cannot pass the opening (no AI
  guardian) — as in v6/v7, a design decision for you.
* The burrbug on the far bank still hits the runner ~0.6 s after the clip
  ends (outside the clip).
