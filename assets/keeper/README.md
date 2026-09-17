# 1-B「THE KEEPER」の素材置き場

**13 枚、揃っています。** 生成に使ったプロンプトは
[`docs/art-prompts-keeper.md`](../../docs/art-prompts-keeper.md)、
取り込みの寸法と理由は [`../SOURCES.md`](../SOURCES.md)。
渡された 1000〜2500px の板から
`tools/import_assets.py --stage-art` で作り直したもので、
元の板は**リポジトリには入れていません**（22 枚で 36MB あります）。

| キー | ファイル | 寸法 | 画面では |
|---|---|---|---|
| `keeper_panorama` | `panorama.jpg` | 1280x720 | 背景 |
| `keeper_stand` | `keeper_stand.png` | 336x242 | 168x134 に stretch |
| `keeper_brace` | `keeper_brace.png` | 336x242 | 〃 |
| `keeper_charge` | `keeper_charge.png` | 336x242 | 〃 |
| `keeper_reel` | `keeper_reel.png` | 336x242 | 〃 |
| `keeper_core` | `core.png` | 128x128 | 64x64 |
| `keeper_barricade` | `barricade.png` | 140x256 | 70x128（当たり判定そのもの） |
| `keeper_barricade_rubble` | `barricade_rubble.png` | 168x77 | 84x38 |
| `keeper_shockwave` | `shockwave.png` | 220x96 | 110x48（進行方向で反転） |
| `keeper_portcullis` | `portcullis.png` | 112x840 | 56x420 |
| `keeper_flagstone` | `flagstone.png` | 132x132 | シームレス・66px で敷く |
| `keeper_brazier` | `brazier.png` | 130x303 | 高さ 150 |
| `keeper_rubble` | `rubble.png` | 460x149 | 高さ 74 |

**4 つのポーズは 1 枚のキャンバスに足元を揃えて載せてあります。**
別々に切り詰めると、状態が変わるたびに番人の背が伸び縮みします
（渡された 4 枚は床の高さが 45 / 96 / 149 / 62px とばらばらでした）。
差し替えるときは `tools/import_assets.py` の `KEEPER_POSES` を通してください。

**このステージは素材ゼロでも最後まで遊べます。** 寸法と読みやすさは全部
ベクター描画の側で測ってあり、`Art.tex()` が null を返せばそこに落ちます
（`src/render/art.gd`）。絵は差し替えであって前提ではありません。
