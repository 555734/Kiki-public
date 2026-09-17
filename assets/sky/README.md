# 1-S「THE OPEN SKY」の素材置き場

まだ空です。ここに入るファイルの一覧と、それを作るための画像生成プロンプトは
[`docs/art-prompts-sky.md`](../../docs/art-prompts-sky.md) にあります。

**空のままでも 1-S は最後まで遊べます。** `Art.tex()` がファイルを見つけられない
ときはベクター描画に落ちる仕組みで（`src/render/art.gd`）、このステージの寸法と
読みやすさはそのベクター版で測ってあります。

1-B と違って、このステージは**素材ゼロでもそこそこ見られます**——
既定のベクター空がそのまま「空」になるので。急ぎではありません。

| キー | ファイル |
|---|---|
| `sky_panorama` | `panorama.jpg` |
| `sky_island_tile` | `island_tile.png` |
| `sky_island_cap` | `island_cap.png` |
| `sky_keel` | `keel.png` |
| `sky_updraft` | `updraft.png` |
| `sky_streamer` | `streamer.png` |
| `sky_arch` | `arch.png` |
| `sky_beacon` | `beacon.png` |
| `sky_flyer` | `flyer.png` |

届いたら `Art.PENDING` から該当行を削除してください。**消し忘れるとテストが落ちます**
（例外リストそのものを監査しているため）。
