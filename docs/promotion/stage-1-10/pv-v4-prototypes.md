# 1-10 PV, fourth pass — three prototype scenes (for review)

Per the brief, the 49 s PV was **not** re-rendered. Three scenes were rebuilt
from the game up (stage geometry, machines, enemy behaviour, art, then the
shooting) and recorded as short clips of real play for review:

| Clip | Storyboard | Length | File (CI / local render) |
| --- | --- | --- | --- |
| A — the rescue | 2–9 s (beats 3–10) | 7.5 s | `A_rescue.mp4` |
| B — the stone giant | 30–33 s (beats 32–33) | 5.4 s | `B_giant.mp4` |
| C — the canyon climax | 36–39 s (beats 37–39) | 6.6 s | `C_canyon.mp4` |

Made with `tools/promotion/capture_finale_pv.tscn -- --take=opening|giant|bone`
and `tools/promotion/render_pv_clip.py OUT.mp4 FIRST LAST`.

Representative frames: `docs/images/stage-1-10/v4-A-frames.jpg`,
`v4-B-frames.jpg`, `v4-C-frames.jpg`. Same moments in 6290.mp4 and in the
prototype side by side: `v4-A-vs-6290.jpg`, `v4-B-vs-6290.jpg`,
`v4-C-vs-6290.jpg`.

`G` = game change, `S` = shooting change, `A` = new art.

## Phase 1 — what was wrong in 6290.mp4

* **A (2–9 s).** The jump simply ended in mid-air far from the far bank, so
  "falling short" read as hovering in a pleasant sky; nothing showed how deep
  the drop was; the rescue was a ramp drawn under the runner and an ordinary
  jump — no moment of release. (`level_finale_data.gd` far bank 2,250px away;
  `capture_finale_pv.gd` take_opening.)
* **B (30–33 s).** The giant stood in front of the plateaus and swung a mace
  that never touched the terrain; the runner just jumped it. The giant itself
  was a mosaic of flat polygons. (`stone_giant.gd`.)
* **C (33–39 s).** The skull was a flat polygon; the jaws chased but never did
  anything to the course; the runner hopped identical pillars; the escape
  onto the high rib path happened only by chance of a sand jet's cycle.
  (`bone_beast.gd`, `bone_pillar.gd`, `sand_geyser.gd`.)

## Phase 2/3 — what each scene now does (all real play)

### A — the rescue (G + S)

1. The runner sprints to the edge; the **overhanging lip breaks away** under
   the take-off (`crumble_lip.gd`, new machine) and its chunks tumble into the
   gorge, fading into the haze — the drop shows its depth.
2. Wide: the far wall is closer now (2,000px) and 200px higher: the leap ends
   **against its face, a body length under the top** (G: far bank moved; a
   gorge back wall and haze behind the drop).
3. Hard cut close: impact (hit-stop, thud), the runner slides down the wall,
   time slows to a near stop. While the call rings, the camera eases back so
   the dark drop under their feet comes into frame.
4. Discord call (mark and two buttons only, no text) → accept → the blue YOU
   hand swoops in, draws a ledge out from the wall block by block under the
   runner. Time snaps back on the landing.
5. YOU taps the **launch ring** every drawn slab carries (the game's own co-op
   launch, `launch_trigger.gd`): the runner is thrown straight up the wall
   and over the top, the camera rising with them, and lands on the grass.

### B — the stone giant (G + A + S)

New behaviour (`stone_giant.gd`, rewritten) on a fixed rhythm:

1. The giant heaves up out of the gorge **across the way** (it stands between
   the plateaus, behind their rock faces).
2. **Wind-up**: its near fist rises high over the plateau's end; its
   **shadow grows on the ground** where it will land; its eyes flare.
3. The runner **breaks forward** out from under it.
4. **Slam**: the fist smashes the plateau where the runner stood — hit-stop,
   shock ring, debris, cracks that stay.
5. The impact **knocks the stone pillar over the gorge: the only bridge**.
6. On the bridge, the far fist is drawn back and **swept flat across it**; the
   runner jumps it (time drags as it passes under) and lands on the far side.

A fist that lands costs a heart and throws the runner back; the guardian can
still shoot the core to freeze both fists. Art: painted giant body and
two-segment arms (`giant_body.png`, `giant_upper_arm.png`,
`giant_fist_arm.png`), posed by two-bone IK each frame.

### C — the canyon climax (G + A + S)

1. The beast bursts up through the vertebra bridge ahead of the runner
   (crash zoom out, hit-stop).
2. The jaws come up out of the canyon and chase. **They bite through each
   bone pillar they reach** (`bone_pillar.gd` state 2: the pillar's head
   shatters and it drops) — the runner's footholds sag under them and are
   bitten off behind them.
3. **The jaws' impact on the canyon blows the sand vent ahead**
   (`sand_geyser.gd`: a jet keyed to the beast's own clock): the runner jumps
   into it and is **thrown up onto the high rib path** — a route change made
   by the danger itself.
4. Along the ribs, down past the fang gate; the jaws slam shut on it behind.

Art: painted skull with opening lower jaw (`beast_skull.png`,
`beast_jaw.png`), neck vertebrae (`beast_vertebra.png`), ribs
(`beast_rib.png`).

## Art method and its limit

No image generator is available to this project's tools. The new raster art
is painted by `tools/promotion/make_creature_art.py`: shapes as signed
distance fields, lit as rounded solids from the upper left (soft toon bands,
warm highlight, cool occlusion), a thick dark outline and surface grain — the
soft, outlined look of the 1-1 art — saved as PNGs and drawn as textures in
Godot. It is procedural painting, not hand-drawn illustration.

## Phase 5 — what changed vs. 6290.mp4, and what did not

Improved (checked by eye on the clips and frames):

* A: the far wall, the impact against it, the slide, the visible drop below,
  the launch up the wall — cause (YOU's ledge + ring) and effect (thrown up
  and over) are on screen.
* B: the giant blocks the way, telegraphs, hits the ground, and the hit
  changes the course (bridge); the runner's dodge and jump are reactions to
  it. The giant is painted, not a polygon mosaic.
* C: the jaws destroy footholds; the danger opens the escape route; the
  skull is painted and opens its jaw.

Not solved:

* The runner has no hand-up "reach" pose; at the wall the existing wall-slide
  pose is used.
* In B and C the runner is small next to the giant/skull (6–12 % of the
  frame) — the size contrast is the point of those shots, but close shots of
  the runner's reaction are few.
* The giant's face is simple (cartoon robot); the fallen pillar is a plain
  textured slab; the beast's ribcage drawn behind the neck is barely in frame.
* The canyon's background ribs and pillar shapes still repeat.
* The other areas (sand ruins, train, hive) were not rebuilt in this pass.
* The full 49 s PV was not re-rendered; these beats now have their own
  lengths and will need the timeline re-balanced when it is.

## Phase 6 — technical checks (separate from the visual review)

* `test/finale_stage_probe.tscn`: 157 / 157 (new checks: the lip breaks; the
  launch ring throws the runner up the wall; the slam topples the pillar;
  fists freeze when staggered; the jaws bite a pillar; the vent blows; the
  jet lands the runner on the rib path).
* Perf gate 1-10: 150 / 160 draw calls.
