# Vertical short PV with narration (`melos_short_pv.mp4`)

25 s, 1080×1920, 30 fps, H.264 + AAC (−14 LUFS). Format of the usual
Japanese game-introduction short: white page, two-line hook title
(「落ちる相棒を指で救う」 white on a red band / 「ふたり協力ゲーム」), the gameplay
in a 1080×976 window, one subtitle phrase under it per narration line
(key words in red), the voice credit at the bottom.

Narration: VOICEVOX, 玄野武宏 (speaker 11), from a local engine
(`docker run -p 50021:50021 voicevox/voicevox_engine:cpu-amd64-latest`);
credit "VOICEVOX:玄野武宏" on every frame.

| Out (s) | Picture | Narration |
| --- | --- | --- |
| 0.0–2.6 | YOU draws steps under the runner (meadow) | 落ちていく相棒を、指一本で救う。 |
| 2.6–4.9 | the leap, the call | これは、ふたりで遊ぶ協力アクション。 |
| 4.9–12.3 | the 1-10 rescue cut: run, leap, fall short, rewind, call, finger, catch, far bank | ひとりは走って、跳ぶ。/ でも、届かないと谷底へ。/ そこで相棒を呼ぶと、/ 指で足場を描いて、/ 受け止めてくれる！ |
| 12.3–15.2 | storm, volcano, train, giant (a cut on each word) | 嵐、火山、列車、巨人。 |
| 15.2–17.6 | bone canyon | ステージごとに、助け方が変わる。 |
| 17.6–20.4 | meadow | 離れた友達とも、合言葉ひとつで遊べる。 |
| 20.4–25.0 | the far bank, softens; MELOS GAME comes in (21.9) | このゲームの名前は、/ メロスゲーム！ |

Pictures are the recorded takes (16:9), cropped to the window: the rescue
cut (`edit_rescue_versions.py` with `RESCUE_MUSIC_GAIN=0`, so its sound is
the game's own) with a crop per shot following the action, and the 49 s PV
(`finale_pv_49cuts.mp4`, sound `pv_game_sound.wav`). Music: the game's
`music_drive.wav`, ducked under the voice. Exact timings:
`short-pv/short_timeline.json`.

Build: `python3 tools/promotion/make_short_pv.py RESCUE.mp4 PV49.mp4
PV49_SOUND.wav OUT_DIR` (needs the VOICEVOX engine on 127.0.0.1:50021 and
Noto Sans CJK JP Black; voice clips are cached in `OUT_DIR/voice`).
