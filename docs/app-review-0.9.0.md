# App Review 対応 — 0.9.0 (387632) の却下

提出 2026-09-27 18:20 / 却下 2026-10-02（Submission ID 2e1f75e2-5b51-47a6-84db-d05f69f50a23）
審査端末: iPad Air (5th generation)

却下されたビルド 387632 はビルド番号（2026-01-01 UTC からの分数）から
2026-09-27 13:32 JST のビルド、つまりコミット `2febb90`
（Enlarge purchase and friend play text）。修正はこのコミットの上に積んだ。

## 原因と修正

| ガイドライン | 指摘 | 原因 | 修正 |
|---|---|---|---|
| 2.1(b) | アプリ内課金 Full Game Unlock が見つからない | iOS の書き出しプリセットに `plugins/InAppStore=true` がなく、Godot は iOS プラグインを既定で**リンクしない**。StoreKit プラグインはビルド・配置されていたのに、アプリに入っていなかった（`Iap.available()` が false → 「このビルドではストアに接続できません」）。さらに購入画面は鍵付きステージのカードを押したときしか出なかった | プリセットで有効化。`tools/submit-ios-appstore.sh` はプラグインが書き出されたプロジェクトに入っていなければ提出を止める。ホーム画面右上に常時「★ 完全版を購入（全ステージ）」。購入前に EOS ログインを待つ（未ログインのまま課金して権限を受け取れない事故を防ぐ）。価格の再取得 |
| 4 | 画面が混み合っている／ホームに戻る機能がない | 操作ボタンは画面の高さ基準の大きさで、4:3 の iPad は縦に長いキャンバスになるためボタンが拡大されプレイ領域を覆っていた。プレイ中にホームへ戻る手段がなかった（クリア画面のみ） | iPad 形状（縦横比 1.6 未満）では操作系を約 70% に縮小（スマホは従来どおり）。プレイ画面左上に「≡」メニュー：「ゲームに戻る」「ホームに戻る（ステージ選択）」。1台プレイ中は一時停止。HUD の目的表示・道具名を端末言語で表示 |
| 1.5 | サポート URL がリポジトリ | — | `docs/support.html` を追加。App Store Connect のサポートURLを `https://555734.github.io/Kiki-public/support.html` に変更する |

## 再提出前にやること（コードでは済まないもの）

1. **このブランチを `main` にマージする。** GitHub Pages は `main` の `/docs` を配信しているので、
   マージするまで support.html は公開されない。公開後、ブラウザで開けることを確認する。
2. App Store Connect → アプリ情報（またはバージョン情報）→ **サポートURL** を
   `https://555734.github.io/Kiki-public/support.html` に変更。
3. App Store Connect → ビジネス → **有料アプリ契約（Paid Apps Agreement）** が「有効」か確認。
   未締結だとサンドボックスでも価格が返らず、課金できない。
4. Full Game Unlock（`full_unlock`）が「審査準備完了」のまま、新しいビルドと**一緒に**提出されているか確認。
5. エンタイトルメントサーバー（Cloudflare Worker）に `APPLE_ASC_KEY` / `APPLE_ASC_KEY_ID` /
   `APPLE_ASC_ISSUER_ID` が設定されているか確認。サンドボックス購入の検証に必要。
6. iOS ワークフローを手動実行して新ビルドを上げ、0.9.0 のビルドを差し替えて再提出。
   ログに `StoreKit plugin linked` が出ていること。
7. 可能なら TestFlight（サンドボックスアカウント）で iPad 実機の購入・復元を一度通す。

## App Review への返信文（そのまま貼れる）

```
Hello,

Thank you for the review. We have submitted a new build that addresses all three issues.

Guideline 2.1(b) - Locating the In-App Purchase
The previous build did not link the StoreKit module, so the purchase could not be
completed. This is fixed. Steps to find "Full Game Unlock":
1. Launch the app and tap "START GAME" on the title screen.
2. On the home screen (stage select), tap "Buy the full game (all stages)"
   in the top-right corner. (Tapping a locked stage card, 1-3 / 1-4 / 1-5,
   opens the same screen.)
3. Tap "Buy full game (<price>)" to start the purchase.
   "Restore purchase" is on the same screen.
The purchase is not restricted by storefront or device. An internet connection
is required, because the unlock is verified with the App Store Server API.

Guideline 4 - Design
- A menu button (≡) is now always shown in the top-left corner during play.
  It opens "Resume" and "Back to home (stage select)". Single-device play is
  paused while the menu is open.
- On iPad the on-screen controls are now about 30% smaller, so they no longer
  cover the play area.

Guideline 1.5 - Support URL
The Support URL now points to https://555734.github.io/Kiki-public/support.html,
which has our contact address and an FAQ.

Best regards
```
