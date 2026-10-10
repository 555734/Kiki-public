# メロスゲーム — プロモーション動画試作 v1

2026-10-08（JST）。Kiki-public `origin/main` の `ff1607e1274640c09fb88399d9c79a36b798b67d` を基に制作。

成果物: `build/promotion/melos-promo-draft-v1.mp4`。30秒、横16:9、1280×720、30fps、H.264/AAC。

実ゲームの描画と物理を、Godot 4.7.2 の Movie Maker で60fps収録し、30fpsに編集した。開始位置、入力、敵の待機、カメラを撮影用に固定し、HUDを外している。足場作成、射出、射撃による追跡者の停止、足場の寿命、ゴール判定は製品側の処理を使う。

## 実撮影版の構成

| 時間 | カット |
| --- | --- |
| 0〜7秒 | 崩落、線を描いて受け止め、足場の印を撃って射出 |
| 7〜11.5秒 | 追跡者が迫る、射撃で停止、ランナーが逃げる |
| 11.5〜15秒 | 消えかけた足場から跳び、次に描いた足場へ着地 |
| 15〜24秒 | 錨、噴潮、噴火、歯車、トロッコ、上昇気流、射出など9カット |
| 24〜28秒 | 大きな跳躍、足場の追加、灯台のゴール |
| 28〜30秒 | タイトル「メロスゲーム」とコピー |

コピーは「相棒の道は、あなたが描く。」「撃って、飛ばせ。」「撃って、止めろ。」「描け。撃て。ふたりで越えろ。」。

効果音はゲーム本来の音。仮BGMはこの試作用に作った150 BPMのシンセ曲。参考動画の音源は使用していない。ナレーションは入れていない。

## 撮影と編集の再実行

リポジトリのルートからPowerShellで実行する。動画・中間ファイルはGit管理外の `build/promotion/` に保存する。

```powershell
& 'C:/product/Kiki/Kiki/build/tools/godot-4.7.2/Godot_v4.7.2-stable_win64_console.exe' --path . --rendering-method gl_compatibility --resolution 1280x720 --position=-2500,-1500 --disable-vsync --fixed-fps 60 --write-movie build/promotion/raw-takes.avi --log-file 'C:/product/Kiki/Kiki/build/stage-1-8-public/build/promotion/movie-capture.log' tools/promotion/capture_promo.tscn
& 'C:/Users/parak/.cache/codex-runtimes/codex-primary-runtime/dependencies/python/python.exe' tools/promotion/edit_promo.py
```

編集にはFFmpeg、NumPy、Pillowを使用する。Windowsのメイリオ太字をテロップに使用する。

## 検証資料

- `build/promotion/takes.json`: 収録フレーム範囲、配置・射撃・着地・ゴールのイベント。
- `build/promotion/capture-checks.json`: 冒頭の足場着地、射出、追跡者停止、消失前の救援、ゴール、各カットの生存を確認。編集は全項目が成功した場合のみ実行。
- `build/promotion/edit-timeline.json`: 実際の編集区間と速度。
- `build/promotion/storyboard-contact.jpg`: 動画から2秒ごとに抽出したカット一覧。

テンポ、驚き、文字の読みやすさを確認するための初稿。カメラの構図は書き出し後の画面で確認し、冒頭で着地点が切れていた箇所を引きの構図へ修正した。
