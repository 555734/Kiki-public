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

固定した開始場面のみを対象にしています。全ステージ全位置、全端末の安全領域、実機の入力・fps・発熱を保証しません。詳細位置の素材チェック・seating probe・実機acceptanceを併用してください。
