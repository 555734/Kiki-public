# THE TRICKSTER PARADE — playable prototype

Stage 1-9 implements the six acts from `docs/promotion/parade-artbook-v2/`.
The original Lira and Orion paintings and controls are used. Creators: Inoue and Sasabe.
Built on public `origin/main` at `ff1607e1274640c09fb88399d9c79a36b798b67d`.

## Play locally

Run `tools/play_parade_v2.ps1`. For a later checkpoint use `-Zone 2` through `-Zone 6`.
The helper opens the normal game stage, with both players' controls on one PC.
Movement: A/D or arrow keys; jump: Space/W; dash: Shift.
Point the mouse at the world and press 1 for a platform, 2 for a wall, 3 to shoot, 4 for warp.
Touch controls retain the normal game behavior. Shoot the brass/cyan latch rings on machines.
This is a local review shortcut; the normal stage-selection card also starts stage 1-9.

## Implemented acts

| Act | Machines | Cast and interactions |
| --- | --- | --- |
| False Entrance | Mask gate, scenery rails, travelling trapdoors | A dormant crowd wakes; a harmless prop crate opens into a pursuing mimic. A shot unfolds the gate's safe collision bridge. |
| Backstage | Curtain/counterweight lift, pendulum bell, magnetic hoist | Shoot an usher's knee for a temporary ramp. A pulley spider changes rigging. The magnet lifts metal enemies and releases them to the opposite pan. |
| Parade Crossing | Two-route turntable, two-angle stunt cannon, reversible conveyor | The drummer cues synchronized jumps. The cannon imp sends a low prop ball which pushes the crowd and is stopped by a guardian wall. |
| Accordion Gap | Crowd-loaded spring bridge, redirectable confetti vent, tilting balcony | Cut the balloon cord to drop its weight. Shoot the ribbon acrobat to reverse its swing. A drawn wall redirects the vent. |
| Spotlight Gallery | Follow spot, projected mirror decoy, breakaway scenery | A dark marionette folds into a safe prop; lighting restores its hostile form. A charging hound opens stairs. A shot breaks the twins' synchronized motion. |
| Sky Wheel Finale | Weighted six-cabin wheel/brake, lowered crescent bridge, three-step fireworks | The manager telegraphs changes to the wheel, moon and fireworks. The guardian can brake the wheel, bridge a missed landing and launch Lira toward the real flag. |

There are 18 machine kinds, 12 cast types and 89 authored enemies. Five checkpoints divide the acts.
Enemies use actual physics bodies and native guardian shots. Forces stay authoritative on the host.
Machine/cast state events include the clock tick; both active and reversed states replay on reconnect.
Migration preserves transformations, impulse momentum and spent effects using stable enemy IDs.
Protocol version 29 rejects older stage layouts; historical stage enum values are unchanged.

## Art and verification

Original transparent production atlases: `assets/stage_1_9/cast_v2.png` and `machines_v2.png`.
Generated with the built-in image generation tool; full prompts: `assets/stage_1_9/prompts_v2.json`.
Godot consumes source texture regions directly. Original PNGs and earlier trailer/artbook files remain available.
Native preview and verification reports: `build/promotion/stage-1-9/playable-v2/`.
The preview is a directed camera tour of the real stage; it is not a continuous full-course playthrough.

The registered `test/parade_stage_probe.tscn` runs the expanded test: native shots, forces, collision bridges,
travelling trapdoors, curtain and wheel rides, a cannon crossing, migration/replay, retry and final flag.
Existing logic and menu regression checks are also run. See `validation.json` for exact final counts.
Two-human online play, mobile performance, and human difficulty/pacing acceptance remain unverified.

Release preparation targets 0.9.19 (Android 46). The full six-act performance
probe measured 77 peak draws and 2910 peak objects on the local compatibility
renderer; CI now includes 1-9 with ceilings of 90 draws and 3205 objects.

## Iteration limits

This is a playable first pass. Most new cast animations use transforms of one illustrated pose; the original
gremlin retains its run frames. Extra cast mechanics and collisions work, but full run/attack frame sets,
animation polish, route difficulty and long-session balance need a playtest before a release.
