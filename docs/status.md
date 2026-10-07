# 現在の開発状況

現行のアプリversionは [project.godot](../project.godot)、通信互換性は [network-compatibility.md](network-compatibility.md)、公開mainのcommitとCIは [GitHub](https://github.com/555734/Kiki-public) を参照してください。提出時点のversion・build・審査結果は [release-results](release-results/) の日付付き記録に保存します。この文書の履歴番号を現在の開発versionとして扱わないでください。

## 実装済み

Godot 4.7.2、横画面1280×720。第一章1-1〜1-8、対戦の既定ステージROYAL ARENA。一台共有とEOSを用いた二台オンラインに対応します。

- 1-2〜1-8の素材差し替え、追跡敵、1-7/1-8の背景調整。
- 可変移動スティック、大きな右下ジャンプ、足場/射撃の選択表示。
- 衝突直前まで残す足場配置、射撃ドラッグによるカメラスクロールの撤去。
- 対戦スターの空中配置、時間制限・再接続猶予・結果表示・CPUパートナー。
- クラス・アートmanifestの分割、known failures 0件、全Godot/UI/server/performance CI、署名アップロードと正確なTestFlight build確認。
- 1-5 の記録されたdraw callsは114、予算300。これは測定場面の値で、全端末・全場面のfps保証ではありません。

## 2026-10-06のレビュー判断（履歴）

| 指摘 | 判断と対応 |
|---|---|
| README/status/入力コメントの古さ | 妥当。現行コードに合わせて更新し、旧statusを歴史資料として退避。 |
| wire/content互換性分離 | 将来課題として妥当。ただしアプリversionは通信versionとして比較していない。厳密比較を外すと危険なため、今回の提出直前には握手形式を変更しない。`network-compatibility.md` に現状と段階的計画を記録。 |
| TestFlightの古い既定値 | 妥当。versionを選択refのproject.godotから読み、build番号を既定値なしの必須入力に変更。 |
| 実機acceptanceの記録不足 | 妥当。`release-results/0.9.9.md` に確定済み配布証拠と未実施項目を記録。端末が未接続のため実機合格は主張しない。 |
| 画像比較なし | 妥当。固定した場面のbaseline比較を追加。実機UXの代わりにはしない。 |
| Stageの未知property | 妥当。敵/ギミック別の許可キー、必須位置、typoの否定テスト、全ステージ検証を追加。 |
| 分割後のprivate結合 | 指摘は正しいが直近の不具合ではない。API境界の整理は次の変更時に行う。 |
| decor/Balance/mainの行数 | 数値だけでは欠陥ではない。decorのテーマ分離を将来候補とし、審査前の無目的な全面改修は避ける。 |
| dist/ライセンス/旧branch | distを歴史資料と明示。アクティブな他者branchは削除しない。公開ライセンスと素材権利の選択は所有者の決定を要し、勝手に付与しない。 |

## 配布・実機確認の境界

0.9.9 の署名済みiOS build399882はApple処理VALID / 内部TestFlight IN_BETA_TESTINGまで確認済みです。これはApp Store審査提出・公開の確認ではありません。

今回開始時のストアAPI確認: Google Play production 0.9.7 (34)、App Store公開版0.9.3。テストAPKのversionCode36をPlayの提出済み番号と混同しないでください。実機UX・購入復元・Android↔iPhone・回線変更・長時間性能は未確認です。

最新の提出結果は `release-results/` にソースcommit、ストアbuild番号、Actions run、APIの実状態を記録します。

2026-10-06 04:51 JST: 0.9.10のGoogle Play (37)とApp Store (399994)を両方審査へ提出済み。App Store画面の『審査待ち』を確認。承認・公開と実機acceptanceは未確認。
