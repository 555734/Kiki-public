# プライバシーポリシー / Privacy Policy — メロスゲーム

最終更新 / Last updated: 2026-09-26
対象 / Applies to: メロスゲーム (iOS `com.sasakiful.sidesky`, Android `com.sasakiful.sidesky`)

> **公開前に1か所だけ埋めてください。** 下の「お問い合わせ / Contact」の
> `<連絡先メールアドレス>` は、ストアの審査でも実際の問い合わせ窓口としても
> 必要です。ここに書いたアドレスは公開されます。
>
> このファイルは `docs/privacy-policy.html` として GitHub Pages で公開でき、
> その URL を App Store Connect と Google Play Console の両方に入れます。
> 手順は `docs/store-listing.md`。

---

## 日本語

### 1. 集めていないもの

このゲームは、**氏名・メールアドレス・電話番号・住所・生年月日・位置情報・
連絡先・写真・広告ID を一切取得しません。** アカウント登録はありません。
広告SDK、解析SDK、クラッシュレポートSDKは**1つも組み込んでいません**。

### 2. オフラインで遊ぶ場合

**何も送信しません。** 1人で、またはローカルで遊んでいるあいだ、端末の外に
出ていく情報はありません。

次のものは**端末の中だけ**に保存され、アプリを削除すると消えます。

| 保存されるもの | 用途 |
|---|---|
| 進行状況・設定・ボタン配置 | 続きから遊ぶため |
| ランダムな端末内ID（`client_id`） | 通信時に相手と自分を区別するため |
| 購入の権限トークン | 購入済みかどうかの判定（下記4）|
| 動作ログ（`user://logs/`、最大5ファイル） | 不具合の調査。端末の外へ自動送信されることはありません |

### 3. オンラインで2人で遊ぶ場合

2人プレイを始めたときにだけ、次の3者と通信します。

**(a) Epic Online Services（Epic Games, Inc.）**

対戦相手とつなぐために使います。**匿名のデバイスログイン**で、Epic アカウントは
作りません。表示名は端末内のランダムIDから作った `SideSky-xxxxxxxx` で、
あなたの本名とは無関係です。Epic は接続に必要な範囲で、端末識別子・IPアドレス・
接続情報を処理します。

- Epic のプライバシーポリシー: https://www.epicgames.com/site/privacypolicy

**(b) 中継サーバー（Cloudflare Workers 上の自社サーバー）**

6桁の合言葉で部屋を結びつけるためだけに使います。保持するのは**接続中の
部屋の情報だけ**で、部屋が終われば消えます。ゲームの内容や会話は記録しません
（このゲームに音声チャット機能はありません）。

**(c) 権限サーバー（同じ Cloudflare Workers 上）**

完全版を購入した場合にだけ通信します。詳しくは次項。

### 4. 購入について

完全版（1回限りの買い切り）を購入すると、購入したことの証明を確認するため、
**ストアのレシート識別子**（Android: purchase token、iOS: transaction ID）と、
**匿名のプレイヤーID（Epic ProductUserId）**を当社の権限サーバーに送ります。

- サーバーは、その2つの対応関係と確認日時だけを保存します
- **クレジットカード番号などの決済情報は、アプリにも当社サーバーにも一切
  渡りません。** 決済は Apple と Google が行います
- 保存された対応関係は、返金・購入取消し時、またはお問い合わせによる削除依頼時に
  削除します

Apple / Google のプライバシーポリシー:
- https://www.apple.com/legal/privacy/
- https://policies.google.com/privacy

### 5. 子どもについて

このゲームは特定の年齢層に向けたものではなく、**子どもから個人情報を
意図的に収集することはありません。** そもそも個人情報を収集しません。

### 6. データの削除

- 端末内のデータ: アプリを削除すれば消えます
- 権限サーバー上の対応関係: 下記の連絡先までご連絡ください。購入の証明が
  確認できしだい削除します（削除すると、その購入での再ダウンロード時の復元が
  できなくなります）

### 7. 変更

内容を変更した場合は、このページの「最終更新」を改めます。重要な変更は
アプリの更新情報でもお知らせします。

### 8. お問い合わせ / Contact

`<連絡先メールアドレス>`

---

## English

### 1. What is never collected

This game collects **no name, email address, phone number, postal address,
date of birth, location, contacts, photos or advertising identifier.** There
are no accounts to create. It contains **no advertising SDK, no analytics SDK
and no crash-reporting SDK.**

### 2. Playing offline

**Nothing is transmitted.** While you play alone or locally, no information
leaves your device.

The following is stored **on the device only** and is deleted when the app is
uninstalled: progress and settings, a random on-device id (`client_id`) used
to tell the two players apart while connected, the entitlement token for a
purchase (section 4), and a diagnostic log (`user://logs/`, at most five
files) which is never uploaded automatically.

### 3. Playing online with another person

Only when you start a two-player session, the game talks to three parties.

**(a) Epic Online Services (Epic Games, Inc.)** connects the two players. The
game uses **anonymous device login**; no Epic account is created. The display
name is `SideSky-xxxxxxxx`, derived from the random on-device id, and is
unrelated to your real name. Epic processes device identifiers, IP address and
connection data as needed to connect you.
See https://www.epicgames.com/site/privacypolicy

**(b) Our relay server** (Cloudflare Workers) matches the two players by a
six-character room code. It holds only the state of rooms that are currently
open, and discards it when the room ends. No gameplay content is recorded, and
the game has no voice chat.

**(c) Our entitlement server** (same Cloudflare Workers deployment) is
contacted only if you purchase the full version — see below.

### 4. Purchases

If you buy the full version (a single non-consumable purchase), the game sends
your **store receipt identifier** (Android purchase token, iOS transaction ID)
and your **anonymous player id (Epic ProductUserId)** to our entitlement
server so the purchase can be verified with Apple or Google.

The server stores only that pairing and the time it was last checked.
**No payment details ever reach the app or our servers** — Apple and Google
handle payment. The pairing is deleted on refund or cancellation, or on
request (section 6).

### 5. Children

This game is not directed at a specific age group and does **not knowingly
collect personal information from children.** It does not collect personal
information from anyone.

### 6. Deleting your data

Uninstalling removes everything held on the device. To have the purchase
pairing removed from our server, contact us at the address below; we will
delete it once the purchase can be identified. (After deletion, restoring that
purchase on a new device will no longer work.)

### 7. Changes

If this policy changes, the "Last updated" date above is revised. Significant
changes are also noted in the app's release notes.

### 8. Contact

`<contact email address>`
