# Stage 1-9 generated paintings

Generated with the built-in image_gen tool before stage implementation, 2026-10-09.
Full generation prompts are saved in `prompts.json`. Source PNGs remain intact.

| File | Use | Canvas |
| --- | --- | --- |
| background.png | Opaque theatre backdrop | 1672 x 941 |
| gremlin_run.png | Four-frame enemy run atlas, true alpha | 2172 x 724 |
| mouth_gate.png | Three-pose false-goal trap atlas, true alpha | 2172 x 724 |
| hammer.png | Rotating shootable crusher, true alpha | 1024 x 1536 |
| theatre_floor.png | Terrain, lifts and collapsing floor, true alpha | 2172 x 724 |

`ParadeArt` reads native texture regions to remove transparent padding. The
floor's golden top rim matches the collision top. Hammer rotation uses the
painted pivot at (512, 103); collision is active only during the visible slam.
Enemy contacts, death, shooting, switch activation and platform launches use
the game's normal mechanics. No reference-video frames are used as game art.
