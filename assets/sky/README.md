# 1-S「THE OPEN SKY」の素材置き場

**9 枚、揃っています。** 生成に使ったプロンプトは
[`docs/art-prompts-sky.md`](../../docs/art-prompts-sky.md)、
取り込みの寸法と理由は [`../SOURCES.md`](../SOURCES.md)。

| キー | ファイル | 寸法 | 画面では |
|---|---|---|---|
| `sky_panorama` | `panorama.jpg` | 1280x720 | 背景 |
| `sky_island_tile` | `island_tile.png` | 132x132 | シームレス・66px で敷く |
| `sky_island_cap` | `island_cap.png` | 1257x92 | 島の上端・46px で敷く |
| `sky_keel` | `keel.png` | 480x298 | 島の底。**鎖は絵に入っています** |
| `sky_updraft` | `updraft.png` | 240x720 | 帯そのものに stretch |
| `sky_streamer` | `streamer.png` | 200x385 | 高さ 190 |
| `sky_arch` | `arch.png` | 440x520 | 220x260 |
| `sky_beacon` | `beacon.png` | 120x488 | ゴール、高さ 246 |
| `sky_flyer` | `flyer.png` | 128x90 | 高さ 44 |

絵を見て直したことが 2 つあります。**`keel.png` は自前の鎖を持っている**ので
`decor.gd` はベクターの鎖を上描きしなくなりました（半個ぶんずれて 2 組見えた）。
**上昇気流は tile から stretch に**変えました——このステージには
240x720 と 170x560 の 2 種類の帯があり、高いほうの倍率で敷くと
低いほうは右端が 9% はみ出して切れます。切れるのは縁＝**一番明るい部分**で、
「どこまで効くか」を言っているのがそこです。

**このステージも素材ゼロで最後まで遊べます**（`Art.tex()` が null ならベクター）。
