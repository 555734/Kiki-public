# 1-10 PV, third pass — from "every beat ticked" to an action PV

The second render (`6280.mp4`) met the storyboard item by item but did not
read as a commercial action PV: the runner was often a few percent of the
frame, the foreground was rectangles of tile, the big set pieces moved
without ever really threatening the runner, the camera was the same
side-on follow at one zoom, and one storyboard second was always one cut.
This pass rebuilt the picture, the staging and the edit. Everything is still
real play in the game (scripted inputs, real physics and machines); the
storyboard stays the reference, not a template.

`G` = game change (stage, art, machine), `S` = shooting change (director:
camera, timing, inputs), `E` = edit/overlay/mix only.

## What changed and why

| Problem in 6280.mp4 | Cause | Change | Type |
| --- | --- | --- | --- |
| Runner small (2-3 s, 12 s, 20-24 s, 30-38 s) | One mid zoom (~1.0-1.5) for nearly every beat | Every beat re-framed: action at zoom 1.7-2.2 (runner 14-22 % of the frame), close-ups to 3.0, wides kept only where the scale is the point (the chasm, the giant, the canyon reveal) | S |
| One storyboard second = one cut | Director recorded exactly 60 frames per beat | Beats now have their own lengths (40-120 frames, still 2,940 in total, still in storyboard order). Beats recorded back to back play as one continuous shot: the rescue (falling short, the call, the pointer, the ramp, the landing, the jump) is one move | S + render |
| Foreground made of square tiles | Slabs drawn as rectangles with a tiled texture and a grass strip | `FinaleGround`: each slab drawn as a shaped mass per material — earth cliffs with an overhanging lip and receding face, eroded sandstone steps, jagged basalt with glowing fissures, slate, mesa, scalloped comb walls with honey drips; floating ledges hang a rocky keel; thin bone ledges are bones. Faceted painted rock textures, depth shading, dark rims, lit edges, strata, vines and props. Sides touching another slab stay straight, so two rectangles read as one cliff | G (picture only; collision unchanged) |
| No depth | Only the backdrop behind the play layer | Far gorge wall and haze in the opening chasm (the drop reads as a drop), haze under the canyon, and a foreground plane of dark silhouettes sliding along the bottom edge at 1.45x parallax (only over ground) | G |
| Magma sphere "big but no tension" (17 s) | Runner sprinted away; wide frame | Runner flees at a run so the accelerating sphere closes the gap; the frame holds both, sphere filling the left; leap for the escape ledge, time drags as the sphere rolls through under the runner's feet, then smashes the crust | S |
| Train lacked speed and danger (20-23 s) | Slow backdrop parallax; frame mostly sky | Backdrop parallax 0.22 → 0.36 (aqueduct 0.55 → 0.85), a trackside hedge in front of the wheels streaming past, tighter frames that keep the cars in shot during the leaps, a hit-stop and shake when the crate lands | G + S |
| Giant read as a stack of squares, no size contrast (31-32 s) | Body drawn from square stone sprites | Repainted as sculpted rock masses (legs, chest, shoulder boulders, head with brow and burning eyes, moss, cracks; tapered stone arms and fists). Wide reveal with the runner small beside it, then a close frame on the bridge; time drags while the mace passes under the jump | G + S |
| Canyon "straight platforms", weak jaws (33-39 s) | Tile pillars, flat tile deck, flat skull | Pillars are colossal leg bones, the deck is a spine of vertebrae, the skull is shaded bone with horns, teeth and a burning eye, the exit is two crossing fangs. Crane-down reveal, low close follow up the arched rib, crash zoom out as the skull erupts with a hit-stop, frames that hold runner and jaws, slow motion at the gate and a hit-stop on the snap | G + S |
| Rescue lacked despair and relief (0-10 s) | Mid zoom, staircase of steps | Wide pull-back on the leap (abyss and the higher far bank), hard cut to a close-up as the runner falls short, slow motion to a near stop, the call, the YOU hand swooping in big, a pull-out while it draws a rising ramp whose blocks build along the stroke, full speed and a hit-stop on the landing, then a big jump to the bank | G (block build-up) + S |
| Title section play small (39-46 s) | Zoom 1.15-1.35 | Zoom 1.55-1.8 under a larger title (scale 0.68); end-card upper half at zoom 1.45 | S + E |
| Sounds present but weak at key events | Quiet platform sound, no impact sound | `build_glow` (1-10 platform appears, played by the game) and `thud` (heavy landings / crate impact at hit-stops); the music bed (the project's own stage music) ducks up to −8 dB under game sounds | G + E |

## Method

1. Three short test clips first, compared frame by frame with 6280.mp4:
   A the rescue, B the magma chase (and the giant's mace), C the canyon.
   Each was reshot until it worked as a scene, then the same standard was
   applied to the whole PV.
2. Full PV shot, rendered, compared second by second with 6280.mp4
   (`docs/images/stage-1-10/v3-before-after-*.jpg`), weak beats re-framed
   and reshot.
3. Every beat keeps the three checks (intent, happened from game state,
   visible: runner size and subject on screen); see `pv_match.md`.

## Not solved

- Art is programmatic or reused: no image generator was available, so the
  new textures are generated by script (`make_terrain_textures.py`), the
  shapes and the giant are drawn in code. Not hand-painted.
- The runner is game-scale: close-ups reach about 22 % of the frame, not the
  storyboard's half-screen portraits (the sprite is 136 px tall).
- The magma sphere and the trains keep their gameplay speeds; tension comes
  from staging, not from faster machines.
- In the canyon the route past the pillars depends on whether a sand jet
  throws the runner onto the rib path; the shot uses what happens.
- The cut 2 enemy is still the 1-3 sprout; the launch-trigger ring on traced
  platforms (a real mechanic) stays visible.
