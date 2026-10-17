# Vertical short PV with narration (`melos_short_pv.mp4`)

24 s, 1080×1920, 30 fps, H.264 + AAC. Built on the "このゲームの名前は"
short format: a one-line premise as the title (「走って跳ぶだけの相棒を」
white on a red band / 「死なせないゲーム」), the gameplay large in the middle
(1080×1350, 70 % of the height), a dry, matter-of-fact narration whose
subtitle changes phrase by phrase (≤ 10 characters on screen at a time),
the voice credit at the bottom.

The script follows the reference's shape: the goal → 「しかし」 the problem →
「そこで…である」 the answer → it escalates → 「とにかく全力で」 →
「ちなみにこのゲームの名前は」. Each phrase is synthesised on its own
(VOICEVOX 玄野武宏, speaker 11, speed 1.15) and placed on the picture it
describes.

| Out (s) | Picture | Narration |
| --- | --- | --- |
| 0.0–4.7 | meadow: the run | このゲームの目的は / 走って跳ぶことしかできない相棒を / ゴールまで送り届けること |
| 4.7–12.9 | 1-10 rescue | しかし相棒は / 無茶なジャンプをするので / 普通に谷へ落ちていく (the fall) / そこで通話である (the call) / 急いで足場を描く (stroke, contact) / 相棒はなんとか向こう岸へ |
| 12.9–16.2 | lightning, lava boulder, giant (a cut on each phrase) | その後も雷が落ち / 岩が転がり / 巨人が暴れるが |
| 16.2–19.7 | meadow: YOU draws steps | とにかく全力で足場を描き / 相棒をゴールまで運ぶのだ |
| 19.7–24.1 | far bank, softens; MELOS GAME | ちなみに / このゲームの名前は / メロスゲーム |

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
