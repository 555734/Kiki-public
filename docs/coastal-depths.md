# 1-4: 上段海岸と下段の港

20区間を上段10区間、深い潮だまり1区間、下段9区間へ折り返した。通常のCoastalSections・SectionBuilder・LevelBuilder・描画を使い、全体PNGにも同じ地形とオブジェクトを出す。上下コースは水平に重なるが、通行中の頭上・着地点に他の層の床が干渉しないよう実Runnerで検査する。

潮だまりは240/260/250/340px幅の恒久棚を4段、820px下る。底のチェックポイントから印2の門で下段入口（x3300、床y1110）へ戻る。水面1450px、落下センサー1550px。12個の恒久チェックポイントは進行順で保存し、上段に戻っても下段の復帰位置を上書きしない。最後の協力壁を越えた乾いた岸に鍵を置く。

## 20区間の組み合わせ

| 区間 | 遊び方 |
|---|---|
| sky_mouth | 噴潮を発射台で越え、空中ワープへ乗る |
| under_the_island | 落下する錨の予告を見て屋根の下へ降りる |
| trapdoor_pier | 崩れる桟橋から救済棚へ落ち、下の噴潮を避ける |
| rifle_tide | 二つの射撃点で橋を延長し、島の横の噴潮を渡る |
| cliff_rescue | 高い岸壁をGuardianの足場で登る |
| wind_ship | 上昇気流、斜めの船の移動床、出口の落下錨 |
| falling_reef | 高さも落下位相も異なる二つの錨の礁を下る |
| ship_wheel | 回転する船の歯車と出口の噴潮 |
| upper_lower_portals | 上へ出る門から下へ落とす門へ乗り継ぐ |
| undertow_tunnel | 逆向きベルトと低い屋根、出口付近の落下錨 |
| tidal_sink | 4段の深い潮だまり、途中の錨と底の噴潮、下段への折り返し |
| harbour_sigil | 記号の異なる二つの射撃標的で港の門を開ける |
| turning_launcher | 回る発射台、逆側の報酬棚、噴潮越しの着地 |
| backwash_loop | 後方への門、点滅床と斜めの船への乗り換え、錨 |
| wreck_pendulum | 二つの崩れる床、振り子、下からの噴潮 |
| low_tide_choice | 協力で高い棚へ、低い脇道は入口へ戻る |
| lighthouse_hand | 灯台の回転針から錨の棚、バネで出口へ |
| rolling_breakwater | 転がる岩、上段の下へ降りる棚、噴潮の脇を抜ける |
| sky_bridge_exit | 射撃橋、錨、空中へ放り出す出口の門 |
| last_lighthouse_rescue | 最後の協力壁を登り、鍵と灯台の旗へ |

噴潮9個、落下錨9個。CoastalHazardは既存VolcanicHazardの共有Clockによる予告・動き・Colliderを再利用し、素材と噴出口の見た目を差し替える。予告は1.2秒、錨は加速落下して消え、危険な上向き巻き戻しはしない。噴潮は連続した中央の水柱だけが危険で、端の飛沫を即死Colliderに含めない。後方ワープでは既存の追跡敵保護（出口の後ろへ移動、1秒の猶予、射撃停止時間の維持）が適用される。

## 検証と境界

- radical_route_probe: 20区間の名前・相対経路に重複なし、43手を実Runner・実ギミック・実Guardian足場で検査。
- coastal_hazard_probe: 上下の重なりと4段の下降、無効schema、host/guest/再生成でClock境界と周期が一致、実Collider、予告時の安全・発動時の実接触死・クールダウンの安全、下段のチェックポイントと実復帰、最後の鍵の実取得。
- guardian_required_probe: 3地点で合法な2速・二段ジャンプ・壁キックの有限探索と実Guardian足場を検査。無限の操作列に対する数学的保証ではない。
- sea_stage_probe / stage_chaser_probe / key_crow_probe: 水面の接触死、実足場、折り返し門での追跡位置と猶予、実際の鍵とゴール。
- Visual Regression: 開始・潮だまりの底・終盤、発動中の噴潮・錨。共通描画の変更で既存1-5の5場面が変わらないことも比較する。
- 性能: 1-4の既存測定場面でpeak 95 draws / 2866 objects。予算151 / 2945を維持する。全場面・全端末のfps保証ではない。

経路検査は敵と即死Areaを除いて通行可能性を検査する。敵込みの連続プレイ、全危険位相、Android/iPhoneの操作と難易度は実機での確認が必要。全体PNGは `tools/export_stage_maps.tscn -- --stage=1-4` で通常の生成・描画から出力する。

アプリ0.9.17 / Android code44。旧海岸をローカル生成するクライアントを拒否するためCo-op wire27。Stage enumは変更しない。ストア原稿の更新は提出済みという意味ではない。

## 生成素材と最終プロンプト

組み込みimagegenを透明背景で使用。既存の画像を上書きせず、stage manifestに登録した。

- `assets/stage_1_4/generated/surge_v1.png`
- `assets/stage_1_4/generated/anchor_v1.png`

噴潮:

> Single isolated dangerous coastal blowhole water eruption sprite for a warm hand-painted 2D fantasy platform game. Transparent background. Side view: a continuous tall narrow turquoise water column blasting straight UP from a flat base, foamy white core, rolling cobalt edges, broad crown of breaking surf at the top and a few small droplets near the column. Entire column and splash visible, centered, minimal padding, approximately 1:3 width to height. Clean readable silhouette at small game scale, richly shaded rounded painterly fantasy art, bright sunny coastal palette. No crater, no rocks, no ground, no ocean background, no smoke, no characters, no text, no UI, no border. Match playful painted volcanic sprites but use distinctly blue and white water.

錨:

> Single isolated falling ship anchor sprite for a warm hand-painted 2D fantasy coastal platform game. Transparent background. Front/side orthographic game view, compact heavy weathered blue iron anchor at the BOTTOM with two broad curved flukes, a thick shank, a rounded horizontal crossbar and ring; short broken rusty chain extending straight upward from its ring. Entire anchor and chain visible, centered, minimal empty padding. The anchor head occupies the bottom 55 percent of the sprite, whole sprite width:height about 1:2. Readable at 64 pixels wide. Rounded richly shaded painterly mobile game art, sunlit cream highlights, deep navy shadows, small orange rust patches. No water, no splash, no rope across the ground, no ship, no scenery, no shadow outside sprite, no characters, no text, no UI, no border.
