# ステージ1-9 PV v3（参考動画の構成）

2026-10-10。最新の `068dfdd`（Trickster Parade）を基に、オーナー提供の参考動画（約49秒）の
構成をなぞって作った約41.6秒のPV。1280×720、60fps、H.264/AAC。表記は英語、制作者名は **Inoue & Sasabe**。

成果物: `build/promotion/stage-1-9/pv-v3/melos-trickster-parade-pv-v3.mp4`（`build/` はgit管理外）。

## 構成

| 秒 | 参考動画 | v3 |
| --- | --- | --- |
| 0.0〜3.8 | 暗い導入、主人公が罠で死ぬ | 偽の入口の口がLiraを噛む → 引いて89体の群れを見せる |
| 3.8〜7.2 | 巨大キャラ +「THIS IS YOU」 | PLAYER 1 / PLAYER 2 の役割表示、「THIS IS YOU」の矢印をもうひとりの操作ボタンへ |
| 7.2〜24.6 | 「BUILD YOUR LEVEL」「STOP THE HEROES」を単語ごとに出す | 1-9実プレイに `SHOOT THE TRICKS` / `ONE SHOT. FOURTEEN FLY.` / `SIX ACTS. 18 MACHINES.` / `12 TRICKSTERS` / `DRAW. SHOOT. SOAR.` を単語ごとに表示 |
| 24.6〜30.6 | 別ステージの高速モンタージュ | 1-1〜1-8を各0.75秒、ステージ番号と名前、カットごとの白フラッシュ。見出し `EIGHT STAGES BEFORE IT` |
| 30.6〜33.8 | ブロック文字のタイトル | ゴール場面の上に `MELOS GAME` の文字が1字ずつ落ちる → `STAGE 1-9 / THE TRICKSTER PARADE / BY Inoue & Sasabe` |
| 33.8〜39.0 | 走る群れの帯 + タグライン3枚 | Liraをパレードのグレムリンが追う帯 + `THE TWO-PLAYER RESCUE PLATFORMER` / `NEW STAGE 1-9 THE TRICKSTER PARADE` / `PLAY TOGETHER` |
| 39.0〜41.6 | 黒いエンドカード、左上に小さなロゴ | 同じ配置で `MELOS GAME / BY INOUE & SASABE` |

ストア配信は未提出のため、参考動画の「COMING SOON」「WISHLIST」に当たる配信先の文言は入れていない。

## 素材と制作手順

ゲーム映像はすべてネイティブ実行・等倍速。演出はカメラと実際の入力だけ。

```sh
G=Godot_v4.7.2-stable_linux.x86_64
$G --headless --path . --import
# 1-9 の13テイク（既存の撮影スクリプト）
xvfb-run -a -s "-screen 0 1280x720x24" $G --path . --rendering-method gl_compatibility --resolution 1280x720 \
  --disable-vsync --fixed-fps 60 --write-movie build/promotion/stage-1-9/pv-v2/raw-takes.avi tools/promotion/capture_parade_pv.tscn
# 1-1〜1-8 の短い走行（v3で追加）
xvfb-run -a -s "-screen 0 1280x720x24" $G --path . --rendering-method gl_compatibility --resolution 1280x720 \
  --disable-vsync --fixed-fps 60 --write-movie build/promotion/stage-1-9/pv-v3/raw-montage.avi tools/promotion/capture_stage_montage.tscn
python3 tools/promotion/edit_parade_pv_v3.py
```

- 1-9撮影 `capture_parade_pv.tscn`: 噛みつき、橋、口の反転、14体の打ち上げ、カーテン、磁石、竹馬、大砲、影、猟犬、観覧車、描画で受け止めてゴールまで、すべて成立（`takes.json`）。
- モンタージュ `capture_stage_montage.tscn`: 各ステージの開始地点から右入力と定期ジャンプで2秒走る。
- 編集 `edit_parade_pv_v3.py`: タイトル・帯・エンドカードはPILで生成。帯の絵は `assets/stage_1_9/gremlin_run.png` と `assets/characters/runner_run/dash.png`。音楽はオリジナルの150BPM合成（導入はドローンと刻み、`partner_bridge` から本編ビート）、ゲーム内効果音を重ね、ラウドネスは約−18 LUFS。

参考動画のフレームや素材は使っていない。
