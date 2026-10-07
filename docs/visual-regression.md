# 描画の回帰テスト

`test/visual_regression_probe.tscn` は通常のmain/対戦sceneを1280×720、GLESで描き、第一章8ステージとROYAL ARENAの開始場面を比較します。英語locale・同梱フォント・seedとClockを固定し、物理・アニメーション・タイマーを停止してから撮影します。OSの日本語fallbackフォントは比較対象にしません。

RGB各channelの差48を超えるpixelが64×64のtileの4%を超えた場合に失敗します。全画面の平均だけで小さなズレを見逃さないよう、局所tileで判定します。40×40の意図的な画像欠損も毎回検出して比較器自体を検証します。微小な色差・サブピクセル差を許容するため、全ての5pxズレの検出を保証するものではありません。

```sh
godot --path . --rendering-method gl_compatibility --resolution 1280x720 test/visual_regression_probe.tscn
```

意図したアート変更でbaselineを更新する場合:

```sh
godot --path . --rendering-method gl_compatibility --resolution 1280x720 test/visual_regression_probe.tscn -- --write-baseline
```

`test/visual_baselines/` の画像差分を目視確認してcommitしてください。CIはbaselineを自動更新しません。失敗時の実画像は `build/visual-regression/` とActions artifactに残します。

第一章8ステージとROYAL ARENAの開始場面に加え、1-4/1-5/1-6の中盤・終盤、1-7/1-8の中盤・最上部、1-4の発動中の噴潮・錨、1-5の発動中の噴火・隕石も比較します（全23場面）。中盤・終盤はrooms()の中央/最終roomのexitへ、追加の危険物は共有Clock0で発動する実データの位置へカメラを移動し、goal/checkpoint Areaによる一時演出は止めます。全ステージ全位置、全端末の安全領域、実機の入力・fps・発熱を保証しません。詳細位置の素材チェック・seating probe・実機acceptanceを併用してください。
