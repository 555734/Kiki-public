# 1-10 PV rebuild — audit, fixes and verification

> Second pass. The third pass (shaped terrain, closer camera, beats of their
> own length, reworked set pieces) is in [pv-v3.md](pv-v3.md); its numbers
> supersede the status below.

The first 1-10 PV render (`finale_pv_49cuts.mp4`, 49 s) was reviewed second by
second against the storyboard (`Melos_PV_Final_49_Storyboard.pdf`, the 49
reference images and `Melos_PV_49_Shot_List.csv`). It was not usable: the
runner was usually a speck, the key machines were off screen or not doing
anything when the cut ran, the opening rescue and the title/end cards were
missing, and there was no sound. This file records what was wrong, why, what
was changed in the game and in the shooting, and how the new PV is checked.

The per-cut result of the new PV is in [pv_match.md](pv_match.md) (generated),
with the raw data in `shots_report.json`, `shots.csv` and `audio_check.json`.

## 1. Audit of the first render (all 49 cuts)

`G` = fixed in the game (terrain, machines, art), `S` = fixed in the shooting
code (camera, timing, inputs), `E` = edit-only (overlays, sound mix).

| Cut | Storyboard | What the first render showed | Cause | Fix |
| --- | --- | --- | --- | --- |
| 1 | Downhill run, one enemy approaches | Runner ~3% of frame height on a wide slope; the enemy 900px away, never on screen | Camera table zoom effectively wide for the action; enemy placed for gameplay, not for this beat; cut window picked around a "key frame" of a slower take | G (enemy moved to 1,180) + S (60-frame cut windows, camera per cut) |
| 2 | Jump the enemy, reveal the gap | Jump happened, enemy a few pixels tall, gap not framed | same | S |
| 3 | Leap toward the high bank | Two tall flat **blue rectangles** (the 1-3 waterfall painting stretched to 1,100px); far bank only 120px higher across a 700px gap, so the jump was hopeless, not a near miss; clouds with straight cut edges | Waterfall sprite stretched far past its design; cloud PNGs are crops of the mockup with cut edges; chasm geometry | G (procedural animated waterfall, soft painted clouds from `make_soft_clouds.py`, far bank re-cut 200px higher and 710px away) |
| 4 | Airborne close-up, near stop | Runner falling far from the ledge; slow motion not readable | Camera did not frame runner + ledge; slow motion started late | S (frame mode on runner+ledge, 8-frame ramp to 3%) |
| 5 | Discord icon + accept/decline only | Nothing (the call was left "for the edit") | Overlay not implemented | E (in-game call card: official Discord mark, two buttons, no text) |
| 6 | Blue YOU pointer appears | Small grey arrow labelled YOU | Placeholder pointer | E (blue hand pointer, scales with the camera) |
| 7 | YOU draws a staircase of glowing blocks | Two yellow slabs placed by taps | Guardian slabs keep the painted yellow style; no traced path | G (1-10 platforms drawn as blue glowing blocks) + S (one traced staircase stroke, a real `place_path` platform) |
| 8–10 | Land, cross, reach the grass | Runner tiny near the chasm floor; far bank read as a pillar | Rescue happened far below the lip | G + S (rescue at the lip height, steps up to the bank) |
| 11 | Wide storm bridge | Flat bridge, runner ~3%, no lightning | Wide fixed camera; no ambient storm | G (Clock-driven distant lightning) + S |
| 12 | Strike blasts the bridge | Thin bolt far from the runner; no cause → effect | Strike trigger too early for a sprinting runner; camera wide | G (strike trigger moved so the bolt lands just ahead of the runner; thicker bolt, impact flash, more debris) + S (push-in) |
| 13 | Diagonal vault up the broken spans | Runner tiny mid-air | Camera | S |
| 14–16 | Ruins reveal, duck the block, floor collapse | Block at frame edge at the wrong moment; fall not shown | No phase alignment with the pendulum; camera | G (desert enemies moved off the hall floor; collapse crash sound) + S (run starts on a fixed pendulum phase; follow-down camera) |
| 17 | Land among lava platforms | Wide shot, runner missing | Camera | S (continuous from the fall) |
| 18 | Magma sphere chases | Sphere on screen, runner far ahead, no threat | Runner sprinting away; camera not framing both | S (runner at run speed, camera fits runner + sphere) |
| 19 | Leap onto a swinging platform | Runner tiny | Camera | S |
| 20 | Up between geysers | Blue meadow/aqueduct sky in the volcano | Backdrop chosen by x only | G (backdrop follows height under the station) |
| 21–24 | Fast train run, leap, crate drop, full speed | Static wide framing of parked-looking trains; runner ~3%; crane far | No speed cues; crane 2 dropped before the runner could reach the second train | G (wind streaks, smoke, line-side posts, faster parallax; crane 1 retargeted off the route, crane 2 moved to 14,600, footbridge/low bridge moved 280px east) + S |
| 25–30 | Hive: honey, swarm, bubble launch, shaft | Mostly readable; swarm and bubble squash not clear | Camera | S (close-up on the honey, follow on the tiers, upward tracking) |
| 31 | Off-centre landing | Runner tiny in the sky | Camera | S (tilt + landing shake) |
| 32 | The giant wakes | Sandstone blocks the same colour as the terrain: no figure | Giant painted with the terrain's stone | G (grey-blue stone, dark rims, brow band and two glowing eyes, moss) |
| 33 | Jump the mace | Mace and runner not together | Timing | S (step on behind the mace, jump at the bottom of its arc) |
| 34–39 | Canyon reveal … closing jaws | Runner tiny; no sand jets in frame; jaws far from the runner | Camera; jaw speed vs. runner | G (jaw chase 300 → 350px/s so the jaws slam just behind the runner) + S |
| 40–46 | MELOS GAME behind continuous play; chase, death, respawn, awkward blocks | **No title at all**; death/respawn barely visible; yellow slabs | Title left "for the edit" | E (title layer between backdrop and world) + S (real drone strike → death → checkpoint respawn; traced awkward blocks) |
| 47–49 | Upper half play; lower half badges / date / credit, one at a time | **No cards at all** | Cards left "for the edit" | E (lower panel, official store badges, one card per cut) |
| all | Sound on the key events | **No audio track** in the 49-cut MP4 | Concat dropped audio | E (game sound cut with each window; project music bed) + G (new synthesized SFX for the machines) |

## 2. How the new PV is made

* **Play is code, not image recognition.** `tools/promotion/capture_finale_pv.gd`
  is a play script per area. The runner moves only through
  `InputHub.drive_runner`, the guardian acts only through
  `Guardian.use_active` (traced platforms use the real `place_path`), and
  every decision (when to jump, when to duck, when to go on air) reads game
  state: machine phases on the shared `Clock`, enemy positions, the
  runner's floor contact. Each take resets the clock to tick 0, so a take
  plays the same alone or in the full run.
* **Exactly 60 on-air frames per cut.** A cut starts the frame after the
  previous one ends (seamless) or after an off-air pause (a hard cut); the
  render takes those exact frames, located through a one-frame slate.
* **Camera per cut**: follow with look-ahead, fixed with pan, or a frame that
  fits several moving things (runner + magma sphere, runner + mace); zoom
  eases, rotation, shake from the machines, hit-stop and zoom punch.
* **Screen layers** (in game, recorded with it): the call card, the YOU
  pointer, the MELOS GAME title behind the world, and the end cards.
* **Three checks per cut**, all from game state: *intent* (what the cut must
  show, written in the script), *happened* (a condition checked every
  on-air frame, e.g. "span 3 is gone and the runner is airborne past it"),
  *visible* (runner drawn height ≥ 8% of the frame on average — 6% for
  establishing shots, 4.5% for the giant reveal — runner on screen ≥ 85% of
  frames, the cut's subject on screen ≥ 50%). Being hurt on air fails a cut
  (except the death cut). End cards also require the runner to stay in the
  upper half on every frame.
* **Sound**: every `Audio.play` is logged with its frame; the render checks
  each one against the final audio (onset within 60 ms).

## 3. Status

**Implemented and verified in the rendered PV**: all 49 cuts pass the three
checks (see pv_match.md); MP4 1280×720, 60 fps, 49.0 s with an AAC 48 kHz
track; 123 game sounds fired on air, 116 with a measured onset at their
event time, 7 playing under a louder sound already ringing, 0 missing
(`audio_check.json`); every cut checked by eye on the sheets below.

* One frame per second, 0–48 s: [pv-contact-sheet.jpg](../../images/stage-1-10/pv-contact-sheet.jpg)
* Storyboard (top) vs. PV (bottom), 8 cuts per sheet:
  [00](../../images/stage-1-10/pv-vs-storyboard-00.jpg) ·
  [01](../../images/stage-1-10/pv-vs-storyboard-01.jpg) ·
  [02](../../images/stage-1-10/pv-vs-storyboard-02.jpg) ·
  [03](../../images/stage-1-10/pv-vs-storyboard-03.jpg) ·
  [04](../../images/stage-1-10/pv-vs-storyboard-04.jpg) ·
  [05](../../images/stage-1-10/pv-vs-storyboard-05.jpg) ·
  [06](../../images/stage-1-10/pv-vs-storyboard-06.jpg)

Rejected and re-shot after review of the rendered frames (not caught by the
metrics): cut 20 showed the rail area's sky and a viaduct painting behind the
volcano lifts (backdrop now follows height; viaducts moved clear); cut 32's
giant blended into the terrain (repainted); cut 3 kept the runner at the
frame edge (reframed); cut 17 put the landing in a corner (reframed).

**Implemented, verified by tests only**: the changed course still plays
start to goal (`test/finale_stage_probe.tscn`, 152 checks), solo chimney
climb with the raised far bank, low-bridge position.

**Not implemented**: hand-painted art (all 1-10 art is programmatic or
reused); a distinct mech enemy model for cut 2 (the 1-3 sprout is used);
real Discord integration (not required — the call is an in-game effect).

**Known gaps against the storyboard**: the runner is drawn at the game's
scale (10–18% of the frame in action cuts, 6–9% in reveals) rather than the
storyboard's illustrated close-ups; the cut 2 enemy is the 1-3 sprout, not a
mech; in cut 7 the runner already lands on the first block in the last
frames (the storyboard has the landing in cut 8); in cut 43 the drone's second
hit takes the last heart beside the saw rather than knocking the runner
into it.

**Not verified**: online two-device play of the changed areas; how the PV
reads to a first-time viewer (judged here against the storyboard by the
same scripted metrics and by eye on the contact sheets).
