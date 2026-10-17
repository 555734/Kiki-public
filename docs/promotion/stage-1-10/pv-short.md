# Vertical short PV with narration (`melos_short_pv.mp4`)

20.3 s, 1080×1920, 30 fps, H.264 + AAC (about −15 LUFS). Compact two-line
title at the top (「落ちる相棒を足場で」 white on a red band / 「助けるゲーム」),
the gameplay large in the middle (1080×1350, 70 % of the height), one short
reaction subtitle under it, the voice credit at the bottom.

Narration: VOICEVOX, 玄野武宏 (speaker 11, speed 1.15), from a local engine
(`docker run -p 50021:50021 voicevox/voicevox_engine:cpu-amd64-latest`);
credit "VOICEVOX:玄野武宏" on every frame.

Each part has one clear event; the rule is shown in the first second.

| Out (s) | Picture | Subtitle | Narration |
| --- | --- | --- | --- |
| 0.0–2.0 | the runner falls into the close shot, the finger strokes a platform, contact at 0.42 (slow motion), the hop on | 落ちる！ → 足場で助ける | 落ちる相棒を、足場で助けるゲーム。 |
| 2.0–5.6 | meadow: YOU draws steps, the runner climbs them | ふたりで協力 | ひとりが走って、もうひとりが、足場を描く。 |
| 5.6–7.7 | nobody helps: the leap falls short, into the gorge | 届かない… | 間に合わないと、落ちてしまう。 |
| 7.7–9.3 | storm: lightning strikes the tower | 雷！ | 雷。 |
| 9.3–11.2 | volcano: the lava boulder rolls after the runner | 岩が来る！ | 溶岩の岩。 |
| 11.2–13.5 | the giant's arm sweeps in | 巨人！？ | 巨人。 |
| 13.5–16.9 | bone canyon: the jaws close behind the runner | 間に合え！ | — |
| 16.9–20.3 | softens; MELOS GAME (18.4) | メロスゲーム | このゲームの名前は、/ メロスゲーム。 |

## Recorded for the window, not cropped

The takes are recorded with a 1100×1375 view (the window's aspect), so
nothing is cropped afterwards: every shot keeps nearly the full width it
was composed for (1100 of 1280; the rescue shots were checked to hold the
runner, the finger, the card and both cliffs) and gains picture above and
below, and the picture is shown larger than at 1280 wide (1080/1100). Godot's movie writer writes
at the project's viewport size, so the take script overrides
`display/window/size/viewport_height` for the recording only
(`VIEW_W=1100 VIEW_H=1375` in `tools/promotion/record_take.sh` writes a
temporary `override.cfg` and removes it afterwards). The director reads the view
size from the viewport (`VIEW`), so the YOU pointer and the camera fit stay
right at any height. The rescue takes play exactly as before (platform 70
px under the feet, contact vy 1100 → 0, far bank (2488, 1017); both takes
identical up to the branch).

`PV_NO_TITLE=1` records the meadow (`title` take) without the in-game
MELOS GAME title; the short shows its own name card at the end.

## Build

```
export VIEW_W=1100 VIEW_H=1375
PV_RESCUE=nohelp FINALE_LOG=1 tools/promotion/record_take.sh opening   # -> nh/
FINALE_LOG=1 tools/promotion/record_take.sh opening                    # -> hp/
PV_SIZE=1100x1375 RESCUE_MUSIC_GAIN=0 python3 tools/promotion/edit_rescue_versions.py nh hp out
tools/promotion/record_take.sh storm,volcano,giant,bone                # -> stages
PV_NO_TITLE=1 tools/promotion/record_take.sh title                     # -> meadow
python3 tools/promotion/make_short_pv.py out/rescue_rewind.mp4 stages.avi meadow.avi OUT_DIR
```

(each recording is `build/promotion/stage-1-10/pv/takes.avi` + `shots_report.json`;
copy it out between runs). Needs the VOICEVOX engine on 127.0.0.1:50021 and
Noto Sans CJK JP Black. Source times per shot: `short-pv/short_timeline.json`.
