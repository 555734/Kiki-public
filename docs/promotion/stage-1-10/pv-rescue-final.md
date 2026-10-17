# 1-10 PV opening — the rescue, final cut (`melos_pv_rescue.mp4`)

10.55 s, 1280×720, 60 fps, H.264 + AAC. Recorded from the game; the
rewind and the end title are the edit.

## Shots

Every shot is a still camera; the shots are joined by cuts on the action,
as in an ordinary film edit.

| Time (s) | Shot | Zoom | What happens |
| --- | --- | --- | --- |
| 0.00–1.00 | run | 1.3 (slow drift right) | the runner sprints and hops the enemy |
| 1.00–3.52 | **A** wide | 1.1 | both cliffs and the drop; the leap, the air jump, short; the fall into the gorge; the failure held; the rewind (the same still frame backwards) |
| 3.52–4.85 | **B1** close | 2.2 | the runner at the top of the arc in slow motion; the call rings (top left); YOU accepts and dives down out of the frame |
| 4.85–6.37 | **B2** close | 1.9 | the runner falls in from the top; the finger strokes a short platform under them; it builds; the landing (hit stop, thud, burst, crouch); a beat; the finger adds a step; the hop to it |
| 6.37–8.35 | **C** | 1.3 (then a slow sideways follow on the bank) | the jump and air jump onto the far bank; the run on |
| 8.35–10.55 | title | — | the picture softens, MELOS GAME comes in, fades out |

The runner is ~130 px tall in B1, ~115 px in B2 (66 px in the wide shot).
The falling motion carries across the B1 → B2 cut (down out of one frame,
down into the next). The cut from A to B1 keeps the runner's horizontal
place on screen.

## Speed

Full speed for the leap and the fall; the rewind at −1.5×; then slow
motion from the top of the arc: 0.35× → 0.25× (call, the card at real
speed) → 0.30× (the finger at real speed) → 0.45× just before the landing;
full speed from the contact on.

## In the game

Platforms by the guardian's build ability; platform 1 created 70 px under
the falling runner, contact by collision (vy 1100 → 0, floor on); jump,
platform 2, far bank. Same recordings and checks as
`pv-rescue-camera-v2.md` (camera A / pacing unchanged); per-frame camera,
zoom and speed in `rescue-pv-final/rescue_camera_timeline.csv`.

Code: `tools/promotion/capture_finale_pv.gd` (shots B1, B2, C:
`CALL_SHOT`, `CATCH_SHOT`, `ESCAPE_SHOT`), `tools/promotion/
edit_rescue_versions.py` (end title, `TITLE`).
