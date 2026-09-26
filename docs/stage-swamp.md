# Stage 1-5 — THE POISON MARSH

ステージ5は、明るい空の下に広がる毒沼を左から右へ渡る協力ステージ。
緑の水面は接触で即死し、苔の岸・石・木橋・筏が安全な足場になる。
画面の色と素材感は `assets/stage_1_5/concept_board_v3.png` を基準にした。

## 経路

1. 最初の岸で操作を整え、小石を連続ジャンプする。
2. 壊れた橋の先はガーディアンが足場を置いて渡す。
3. 石柱を越えて、2本目の広い水路を足場で渡す。
4. 動く丸太筏に乗り、中央の長い毒沼を渡る。
5. 最後の水路を足場で渡り、奥の門に到着する。

自由ジャンプの隙間は最大 200px、ガーディアンが必要な隙間は
630〜680px。筏は 760px を往復する。チェックポイントは6箇所。
毒の判定は水面に沿った透明な `Hazard` で、落下判定より先に死亡する。

## 実装と検証

- レベル配置: `src/levels/level_swamp_data.gd`
- 背景・小物: `assets/stage_1_5/distant_swamp.png` と `props_atlas.png`
- 地形と水面: `src/render/terrain.gd` と `src/render/sea_water.gd`
- 選択画面: `src/ui/net_panel.gd`
- 自動検証: `test/swamp_stage_probe.tscn`
- 画面確認: `test/swamp_capture.tscn`（画像を `build/` に保存）

ステージ番号は既存の通信 enum の末尾に追加した。オンラインでは両端末が
同じ更新版であることが必要。
