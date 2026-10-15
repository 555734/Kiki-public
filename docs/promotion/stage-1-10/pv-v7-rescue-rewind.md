# 1-10 PV opening — the rescue in two versions (rewind / direct)

Only the opening rescue was made. Nothing else (other areas, the 49 s PV)
was touched.

| File | Version | Length | Format |
| --- | --- | --- | --- |
| `rescue_rewind.mp4` | A — fails, rewinds, the call, the rescue | 7.65 s | 1280×720, 60 fps, H.264 + AAC |
| `rescue_direct.mp4` | B — the call comes at the top of the leap, the rescue | 6.05 s | 1280×720, 60 fps, H.264 + AAC |
| `rescue_rewind_contact.jpg`, `rescue_direct_contact.jpg` | one frame per second, labelled | | |
| `rescue-v7/rescue_event_log.txt` | the events with clip times, contact and teleport checks | | |
| `rescue-v7/rescue_trace_help.csv`, `rescue_trace_nohelp.csv` | every frame: position, velocity, floor/wall contact, time scale, events | | |
| `rescue-v7/timeline.json` | the edit's segments and event times | | |

## How it is made

Two recordings of the same take from the same start, with the same inputs
and the same camera up to the top of the leap (the "branch" event):

* **nohelp** (`PV_RESCUE=nohelp`): nobody answers; the runner falls into the
  gorge (and dies at the kill hazard after the clip's part ends).
* **help**: at the top of the leap the call comes in, YOU answers and builds
  two platforms with the guardian's ordinary build ability; the runner lands
  on the first by collision, hops to the second and onto the far bank.

`tools/promotion/edit_rescue_versions.py` cuts both versions from them:

* **B** is the help recording as it is.
* **A** is the nohelp recording up to the fall, then **the same frames
  played backwards** (ffmpeg `reverse`, 1.3× faster: the runner rises back up
  the fall, the camera retraces its move), ending on the last frame the two
  recordings share (the frame before the branch), then the help recording
  from the very next frame. The two recordings are pixel-identical up to
  there: mean difference 0.0, 0 pixels differing on the join frame (checked
  by the script) -- position, pose, velocity and camera match exactly
  because it is the same game state.

The rewind is an edit only; the game has no time reversal.

## Time structure

**A — rescue_rewind.mp4**

| Time | Picture | Brief's target |
| --- | --- | --- |
| 0.00–1.00 | run, hop the burrbug (0.40) | 0.0–1.0 |
| 1.00–1.58 | wide: both cliffs, the gap, the drop | 1.0–2.0 |
| 1.58–2.18 | take-off, air jump (1.92), the camera moves in; top of the arc 471 px short | 1.0–2.0 |
| 2.18–3.08 | falls past the far bank's edge into the dark gorge (+ wind, failure note) | 2.0–3.2 |
| 3.08–3.78 | **rewind**: the fall and the camera run backwards to the top of the arc (tinted, ◀◀ mark, reversed sound, rewind whirr) | 3.2–4.1 |
| 3.78–4.58 | time slows to 0.12×, the call (Discord mark, decline, accept); the runner centre-left, card at the right edge | 4.1–5.0 |
| 4.58–5.08 | answered: the YOU finger comes in under the falling runner | 5.0–5.6 |
| 5.08–5.62 | the finger strokes the platform in the runner's path | 5.6–6.9 |
| 5.62–6.13 | platform 1 created 187 px under the feet, blocks building; time comes up to 0.4×; **contact 6.13: vy 1100 → 0**, squash, ring at the feet, thud | 6.9–7.8 |
| 6.13–7.27 | the finger adds a step (6.33); hop (6.33), step (6.72), jump (6.75), far bank (7.27) | 7.8–9.4 |
| 7.27–7.65 | runs on, arrival chime | 9.4–10.0 |

**B — rescue_direct.mp4**: identical to A from 0.00 to 2.18, then A's
3.78–7.65 (shifted by −1.60 s): call at 2.18, answered 2.98, stroke 3.48,
platform 4.02, contact 4.53, step 4.73/5.12, bank 5.67, end 6.05.

**Why shorter than 10 s.** Every action takes the time the game's physics
gives it: the runner's speed, jump and gravity are unchanged, and slow
motion is used only around the call. Stretching to 10 s would mean holding
the runner in the air longer (the brief forbids) or adding run-up. The
fall (0.9 s) and the rewind (0.7 s) are a little shorter than the brief's
1.2 s and 0.9 s because the runner reaches the dark of the gorge in 0.9 s.

## Proof of the rescue (log, help take; clip times as in B)

| t | event | position | velocity | time scale | floor |
| --- | --- | --- | --- | --- | --- |
| 1.58 | take-off | (1533, 1137) | (492, 0) | 1.0 | on → off |
| 2.18 | top of the arc, 471 px short (branch) | (1829, 818) | (492, 0) | 1.0 → 0.12 | off |
| 2.98 | call answered | (1908, 872) | (492, 640) | 0.12 | off |
| 4.02 | platform 1 created, top 1192, runner feet 1005 | (1969, 982) | (492, 1100) | 0.12 | off |
| 4.53 | **landed on platform 1** | (2054, 1169) | (492, **0**) | 1.0 | **on** |
| 4.73 | platform 2 created, top 1109 | | | | |
| 5.12 | landed on platform 2 | (2210, 1086) | (410, 0) | 1.0 | on |
| 5.67 | landed on the far bank | (2436, 1017) | (410, 0) | 1.0 | on |

No help (same until 2.18): falls with nothing under it, 3.08 deep in the
gorge at (2272, 1664) with vy 1100; dies at the kill hazard later. In both:
0 airborne frames touching a wall, no per-frame move beyond velocity × time
scale (no teleport). The platforms are the guardian's build ability
(`Guardian.use_active` with a traced path); nothing invisible, nothing
drawn as a fake platform; the runner is moved only by input.

## Sound

From the game (recorded with the picture): jump, landing, thud on the
platform, `ring` ×2, `accept`, `build_glow` (the finger's build), whoosh at
the fall, `checkpoint` on the far bank, crumble of the lip. The stage music
(`music_stage.wav`, the game's own) as a low bed — **in A it runs backwards
through the rewind and resumes from the branch point**, with the game sounds
reversed too. Made by `edit_rescue_versions.py` (numpy, no outside material):
wind on the fall, the two-note failure, the rewind whirr, a sparkle under each
platform's build, the arrival chime. No third-party audio.

## Changed code

* `tools/promotion/capture_finale_pv.gd`: the rescue take rebuilt around the
  branch (both variants share everything before it); per-frame trace from
  the run-up; landing burst at the feet on each platform landing.
* `tools/promotion/edit_rescue_versions.py` (new): both versions, the
  join check, the rewind picture and sound, contact sheets.
* No game code changed in this round (terrain and art are v6's).

## Unsolved

* Lengths are 7.65 s / 6.05 s, under the 10 s target (see above).
* The wide shot shows the runner small (~6 %) for about half a second.
* During the call the runner is high over the gorge with the meadow
  backdrop behind (the call comes at the top of the leap).
* The step platform appears 0.2 s after the landing: the hop to it starts
  as its blocks are still building.
* The rewind treatment (tint, colour fringing, ◀◀ mark) is an edit filter;
  rain or particles are not reversed separately (they are in the reversed
  frames).
* The burrbug on the far bank hits the runner ~1 s after the clip ends
  (outside both clips).
* With the gorge deadly, a lone player cannot pass the opening (no AI
  guardian) — your design decision.
