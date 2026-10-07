# メロスゲーム / Kiki

横画面で遊ぶ協力アクションです。ランナーが走って跳び、ガーディアンが足場と射撃で支えます。一台共有と二台オンライン、スターを取り合う対戦モードがあります。

開発元は [Kiki-public](https://github.com/555734/Kiki-public)。ローカルでは `C:/product/Kiki/Kiki/build/stage-1-8-public` を使用します。legacy Kiki checkout では開発しません。

現在の仕様・検証状況は [docs/status.md](docs/status.md)、提出用文章は [docs/store-listing.md](docs/store-listing.md) を参照してください。数値の正本は `src/autoload/balance.gd`、ステージの正本は `src/levels/stage.gd` と各 data ファイルです。過去の設計資料と現行仕様が違う場合はコードを確認してください。

## 遊べる内容

| 協力ステージ | 名前 |
|---|---|
| 1-1 | GREENFIELD PLAINS |
| 1-2 | THE HOLLOW OUTSKIRTS |
| 1-3 | THE SKYWARD RUINS |
| 1-4 | THE SUNLIT COAST |
| 1-5 | THE MOLTEN CROSSING |
| 1-6 | THE SANDGLASS RUINS |
| 1-7 | THE CLOCKWORK TOWER |
| 1-8 | THE UNDERGROVE |

対戦の初期ステージは ROYAL ARENA。追加の実験ステージもありますが、通常の第一章は上記8ステージです。1-3〜1-5 は完全版購入で解放、1-1・1-2・1-6〜1-8 は無料です。

## 操作と能力

- スマホの移動は左下の領域に触れた位置を中心にする可変スティック。カスタム配置時は固定位置になります。ジャンプと同時入力できます。
- 一台共有のジャンプは右下に大きく配置し、足場・射撃の選択ボタンをその上に置きます。選択中のボタンを色と表示で区別します。
- 足場はドラッグして作成します。地形に当たった場合は衝突直前までの有効部分を残します。点線の配置枠は表示しません。
- 射撃のドラッグは照準操作です。カメラの横スクロールには使いません。
- 通常ガーディアンUIは足場と射撃。足場コスト0、射撃コスト0、射撃クールダウン0秒、足場寿命6秒、同時足場数2です。壁・スコープなどの内部能力を通常UIの選択肢と混同しないでください。
- 1-2〜1-8にはテーマに合う追跡敵がいます。射撃で一時停止させ、逃走を支援できます。

## 開発と検証

Godot **4.7.2** を使用します。まず公開リポジトリを fetch し、変更を保護しながら `origin/main` と同期してください。

```sh
godot --headless --path . --editor --import
godot --headless --path . --fixed-fps 60 test/run_tests.tscn
bash tools/verify.sh /path/to/godot --shots
bash tools/perf-gate.sh /path/to/godot
bash tools/server-tests.sh
```

`test/manifest.txt` がテスト場面を分類します。known failures は現在0件です。Godot checks は全PRでロジック・UI・描画・性能を検証します。ステージの敵・ギミックの型とプロパティ名は StageSpecSchema の契約テストで検証します。

画像比較の使い方は [docs/visual-regression.md](docs/visual-regression.md)。通信互換性と今後の分離方針は [docs/network-compatibility.md](docs/network-compatibility.md) を参照してください。

## モバイル配布

ステージ全体をPNGでレビューする開発ツールは [docs/stage-maps.md](docs/stage-maps.md) を参照してください。

- `mobile.yml`: AndroidテストAPKとiOSビルド。pushの成功だけではストア提出を意味しません。
- `android-play.yml`: 永続署名の `com.sasakiful.melos` AAB。明示した versionCode と提出オプションを使用します。
- `ios.yml`: `com.sasakiful.sidesky`。署名・アップロードと App Store 審査提出は別オプションです。
- `testflight-status.yml`: 選択したソースのマーケティングversionと、必須入力した正確なbuild番号を照合します。過去ビルドの確認では対応するrefを選択してください。
- `store-status.yml`: 通常は両ストアのバージョン・状態の確認のみです。明示した更新オプションで、選択ソースの既存審査待ち版の日本語説明だけを正本から更新できます。公開済み版や本審査中の版には書き込みません。Playの一時editはcommitせず削除します。productionの `completed` は審査完了や公開を保証しません。

実機でしか確かめられない項目は [docs/release-acceptance.md](docs/release-acceptance.md)、実施状況は `docs/release-results/` に記録します。自動テストの成功を実機の合格に置き換えないでください。

`dist/` のAPKは歴史的なコピーです。最新テストAPKは Actions の成果物を使用してください。
