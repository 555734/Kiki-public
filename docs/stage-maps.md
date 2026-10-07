# ステージ全体マップ

リポジトリのルートで、Godot 4.7.2のimport後に実行します。

```sh
godot --headless --editor --path . --import
godot --path . --rendering-method gl_compatibility tools/export_stage_maps.tscn -- --ci-skip-eos
```

`build/stage-maps/stage-1-1.png`〜`stage-1-8.png`と`maps.json`を生成します。横長・縦長とも、ステージ全体を切らずに1枚へ描きます。PNG生成はGPU/ソフトウェア描画の使えるdisplayが必要です。Linux CIでは2番目のコマンドを`xvfb-run -a`で実行してください。PNG生成に`--headless`を付けると失敗します。

```sh
godot --path . --rendering-method gl_compatibility tools/export_stage_maps.tscn -- --stage=1-7 --scale=1 --output=res://build/tower-map --no-background --ci-skip-eos
```

- `--stage=all`（既定）または`1-1`〜`1-8`。
- `--scale=0.5`（既定）はworld 1pxを画像0.5pxへ変換。最大辺12288px/約3200万pixelを超える場合は倍率を自動的に下げます。実際の倍率はログとJSONへ記録します。
- `--output=PATH`で出力先を変更。絶対パスと`res://`に対応します。
- `--no-background`は背景を省略し、地形・オブジェクトの配置を見やすくします。

通常の`LevelBuilder.build()`が地形、装飾、敵、ギミック、コイン、checkpoint、goalを生成し、通常の各rendererが描画します。地形をツール用に描き直したり、ステージ配置を複写したりしません。撮影範囲のみ`Stage`の配置・移動範囲から計算し、シルエット用の余白256pxを加えます。Clock=0/seed=42で生成直後に固定し、HUD・操作ボタン・プレイヤーは表示しません。

背景は通常のSky rendererが俯瞰viewportに描いたものです。ゲーム中のparallaxをつなぎ合わせた画像ではありません。動く床の全軌道、開閉状態、隠し橋の全状態、攻略ルート線は描きません。画像は初期配置のレビュー用であり、踏破可能性はclimb/guardian probesで確認します。

`maps.json`のworld_origin/scaleを使って画像座標とゲーム座標を対応付けられます。生成PNGはbuild配下の開発成果物で、Gitには追加しません。

GitHub Actionsの **Stage maps → Run workflow** でも8枚を生成できます。完了後に`coop-stage-maps` artifactをダウンロードしてください。ツール変更PRでは同じ処理を自動実行し、8枚のPNG・寸法・Clock固定も検査します。
