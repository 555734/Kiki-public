# 1-5: 上段峡谷と下段の溶岩洞

20区間の一列構成を、上段10区間、火口下降1区間、下段9区間に折り返した。前半の峡谷の下へ後半のコースが重なり、全体PNGでも上下の進行と密度を比較できる。独立した地形コピーを作らず、`MoltenSections`、`SectionBuilder`、通常の`LevelBuilder`と描画を使う。

火口は220/250/250/340px幅の恒久棚を4段下降し、850px下の底へ着く。底のチェックポイントから印2の門を通り、左側の下段入口へ折り返す。溶岩面は1450px、落下センサーは1550px。下段の安全な足場を古い溶岩面で殺さない。チェックポイント12個は実際の進行順で、上段へ落ち戻っても下段の保存位置を上書きしない。

後方へ300px以上ワープする折り返しでは、追跡敵を出口の後ろへ移し、出口に1秒の猶予を付ける。転送前の距離（300〜900px）とGuardianの射撃停止時間を保ち、hostだけが適用する。旧1-6の折り返しにも同じ保護が適用される。通常の前方ワープは従来通り。

## 噴火と隕石の組み合わせ

`volcanic_hazard`は共有Clockだけで位置・当たり判定・予告を計算する。1.2秒の予告、発動、無害なクールダウンの順で、隕石は上へ巻き戻って攻撃しない。マグマは噴出口から徐々に伸び、隕石は斜めに加速落下する。黄色の帯と山形の印が次の危険位置を示す。各区間には恒久の待避足場があり、チェックポイントと敵の初期位置を避ける。

| 区間 | 新しい組み合わせ |
|---|---|
| eruption_entry | 発射台で上向きの噴火を越える |
| air_drop | 空中ワープから隕石の着地帯を避ける |
| false_floor | 崩れる床の下に噴出口と救済棚 |
| rock_rain | 位相をずらした左右斜めの隕石と退避棚 |
| crossing_lifts | 横・縦の移動床の間を噴火が貫く |
| piston_escape | 屋根付き通路からバネで隕石帯へ脱出 |
| double_deck | 点滅床と下の崩れる棚の間で噴火 |
| caldera_descent | 深い4段の火口下降、途中の斜め隕石、底の噴出口 |
| gear_foundry | 歯車と斜めの移動床の間に噴火 |
| crossed_portals | 上下ワープの出口に予告付き隕石 |
| pendulum_belt | 逆転ベルト・振り子・出口付近の噴火 |
| cooling_windows | 二つの射撃窓から橋を維持し噴出口を渡る |
| chimney_fall | 上昇気流から隕石が落ちる棚へ横に抜ける |
| roof_spring | バネで屋根を越え、隕石の予告を見て着地 |
| core_relay | 射撃橋・点滅床・移動床に噴火と隕石の異なる周期 |
| emergency_exit | 崩れる床の間の噴出口から待避門へ |

残る救援壁、二つの炉門、転がる岩、高所＋850pxの最後の横断はそれぞれ別の役割を保つ。鍵は最後の協力地点の先の乾いた岩に置いたため、上段から下へ落ちるだけではゴールを開けない。

## 検証

- `radical_route_probe`: 20区間の名前と相対経路の重複なし、恒久チェックポイント、実Runner・実Guardian足場・実ギミックによる44手の経路。
- `volcanic_hazard_probe`: 上下の重なりと850pxの実下降、schemaの無効値、Clockの境界・繰り返し・長時間tickでhost/guest/再生成の一致、描画と実Collider、予告中の安全と発動中の実Runner死亡、下降後のチェックポイントと実復帰、最後の鍵の実取得。
- `guardian_required_probe`: 3地点で2速・二段ジャンプ・壁キックの有限探索による単独迂回確認と、実Guardian足場による通行。無限の操作列に対する数学的保証ではない。
- `swamp_stage_probe`: 溶岩の接触死と実足場、テーマ素材。
- `stage_chaser_probe`: 1-5/1-6の実折り返し門での追跡位置・出口猶予・射撃停止時間の維持とguestでの無効化。
- Visual Regression: 開始・下段入口・終盤に加え、Clock0で発動する噴火と隕石の専用2場面。既存の全場面の比較基準は緩めない。
- 性能プローブ: 1-5の既存測定場面でpeak 78 draws / 2872 objects、上限300 / 3115を維持。全場面・全端末のfps保証ではない。

ルート検査は敵と即死Areaを除いて通行可能性を検査する。敵込みの連続プレイ、全危険位相、Android/iPhone実機の難易度は別途確認が必要。全体PNGは`tools/export_stage_maps.tscn -- --stage=1-5`で実際の生成・描画から出力する。

アプリ0.9.16 / Android code43。内容をローカル生成する旧クライアントとの不一致を拒否するためCo-op wire26。Stage enumは変更しない。ストア原稿の更新とストアへの提出は別の作業である。

## 生成素材とプロンプト

組み込みimagegenを使用し、透明背景を指定。既存素材を上書きせず、次のPNGをゲームのstage manifestに登録した。

- `assets/stage_1_5/generated/meteor_v1.png`
- `assets/stage_1_5/generated/eruption_v1.png`

隕石の最終プロンプト:

> Create a single isolated game sprite for a falling volcanic meteor in a warm hand-painted 2D fantasy platform game. Transparent background. Side view, meteor falling straight down: compact round jagged charcoal basalt rock at bottom, glowing orange and yellow lava cracks, bright curling flame tail rising upward above the rock. Silhouette readable at 64 pixels wide, full sprite vertical aspect ratio approximately 1:2, centered with minimal empty padding, full rock and entire flame tail visible, no ground, no cast shadow outside the sprite, no scenery, no text, no border, no UI, no extra objects. Rounded illustrative forms, richly textured painterly shading, orange amber highlights and dark plum shadows, polished friendly adventurous mobile game art. Avoid realistic photography, gore, metallic spaceship, or black background.

噴火の最終プロンプト:

> Single isolated volcanic lava geyser plume sprite for a warm hand-painted 2D fantasy platform game. Transparent background, side view. Tall narrow continuous molten orange column blasting UP from its flat base, spectacular bulbous splash at the top and a few small nearby droplets, incandescent yellow inner streaks and red orange edges. Height about three times width. The entire central column from base to top must read as dangerous molten liquid with no black smoke and no huge empty gaps. Full sprite visible, centered, minimal transparent margin. No rocks, no ground, no crater, no backdrop, no text, no UI. Rounded painterly forms, orange amber highlights, soft painted texture, clean readable silhouette at small size, friendly adventurous mobile game visual style.
