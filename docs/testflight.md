# TestFlight まで：あなたがやることだけ

**設定は全部こちらで済ませてあります。** 下の画面で、書いてある文字をそのまま入れてください。
判断が要るところはありません。

| 決まっている値 | |
|---|---|
| Team ID | `6TGM565HX8` |
| Bundle ID | `com.sasakiful.sidesky` |
| アプリ名 | `SIDE SKY` |
| 提出バージョン | `0.2.3` |
| ビルド元ブランチ | `recovery/unified` |
| 中継サーバー | `https://side-sky-signalling.a3506124.workers.dev`（デプロイ済み・動作確認済み） |

---

## 手順1：Bundle ID を登録する

> **この手順は飛ばしても構いません。** ビルド時に App ID が無ければ
> **自動で登録される**ようにしてあります。手作業でやりたい場合だけ以下を。

いま開いている **Register an App ID** の画面です。

| 欄 | 入れるもの |
|---|---|
| Platform | **iOS, iPadOS, macOS, tvOS, watchOS, visionOS**（そのまま） |
| Description | `SIDE SKY` |
| Bundle ID | **Explicit** を選び、`com.sasakiful.sidesky` |
| Capabilities | **何も触らない**（このゲームは特別な権限を使いません） |

→ **Continue** → **Register**

## 手順2：App Store Connect でアプリを作る

**新規アプリ** の画面です。

| 欄 | 入れるもの |
|---|---|
| プラットフォーム | **iOS** にチェック |
| 名前 | `SIDE SKY` |
| プライマリ言語 | **日本語** |
| バンドルID | 手順1で作った **`com.sasakiful.sidesky`** を選ぶ |
| SKU | `sidesky-001` |
| ユーザアクセス | **アクセス制限なし** |

→ **作成**

## 手順3：API キーを作る（これだけは私に渡さないでください）

App Store Connect → **Users and Access** → **Integrations** → **App Store Connect API**
→ **＋** で新規キー

| 欄 | 入れるもの |
|---|---|
| Name | `Codemagic` |
| Access | **App Manager** |

**`.p8` ファイルは一度しかダウンロードできません。** 必ず保存してください。
同じ画面に出ている **Issuer ID** と、キー一覧の **Key ID** も控えます。

> ⚠️ **この3つ（.p8 / Issuer ID / Key ID）はチャットに貼らないでください。**
> `.p8` は秘密鍵です。次の手順で Codemagic に直接入れます。

## 手順4：Codemagic に API キーを登録する

codemagic.io → **Teams** → **Integrations** → **Developer Portal** → **Add key**

| 欄 | 入れるもの |
|---|---|
| Name | **`SIDE_SKY_ASC`**（この名前でないと `codemagic.yaml` が見つけられません） |
| Issuer ID | 手順3で控えたもの |
| Key ID | 手順3で控えたもの |
| Private key | 手順3の `.p8` ファイル |

## 手順5：ビルドする

Codemagic のアプリ画面 → **Start new build** → ワークフローを選ぶところで
**必ずこちらを選んでください**：

| 選ぶ | **iOS — TestFlight に提出（署名付き）** |
|---|---|
| 選ばない | iOS — 自分の端末用（未署名・TestFlightには使えません） |

ブランチは **`recovery/unified`** を選んでください。
この設定はpush時の自動ビルドを無効にしているため、意図せずビルド時間を
消費したりAppleへ送信したりしません。

**未署名の `.ipa` は TestFlight にアップロードできません。**
未署名版は AltStore や Sideloadly で自分の端末に直接入れるためのもので、
Apple のサーバーは受け取りません。

Team ID も Bundle ID も設定済みなので、**入力欄はありません**。
証明書とプロビジョニングプロファイルは初回に自動生成されます。

手順3・4の API キーが登録されていない場合は、**最初のステップで
「App Store Connect にアクセスできません」と出て止まります**（長いログの
奥で分かりにくく失敗しないようにしてあります）。

> **なぜ `--testflight` を付けていないのか**：あのフラグは
> **外部テスター向けのベータ審査に提出する**ためのものです。
> お友達1人に渡す**内部テストには不要**で、付けると審査待ちになります。

## 手順6：お友達に渡す

App Store Connect → **TestFlight**。処理に10〜30分かかります。

**Internal（審査なし・すぐ渡せる）**：
**Users and Access** → **＋** でお友達の Apple ID を招待（役割は Developer で可）
→ TestFlight → Internal Testing にそのお友達を追加。

お友達は TestFlight アプリを入れて、届いた招待から開きます。

---

## うまくいかないとき

### `Cannot save Signing Certificates without certificate private key`

**配布証明書の秘密鍵は、その証明書を作ったマシンにしか存在しません。**
Apple は証明書だけを保管し、鍵は返してくれません。

このアカウントには既に Expo が作った配布証明書がありますが、その鍵は
Expo 側のマシンにあるので、Codemagic からは使えません。

対処済みです：**Codemagic 上で新しい秘密鍵を生成し、それに対応する証明書を
新規作成**するようにしました。鍵はキャッシュされるので、証明書が毎回
増えることはありません。

### `No matching profiles found for bundle identifier ...`

App ID・配布証明書・配布プロファイルのどれかが無い状態です。

**このメッセージが「ログの一番最初」に出て、こちらの日本語メッセージが
何も出ていない場合**、それは Codemagic の自動署名がスクリプトより先に
走って落ちていたためです。**その自動署名は外しました**。
最新のコミットでビルドし直してください。

### `UIRequiredDeviceCapabilities ... incompatible with the MinimumOSVersion value of ...`

Godot は Metal レンダラのために `iphone-performance-gaming-tier` を
Info.plist に書きます。**最低 iOS をいくつに上げても Apple は受け取りません**
（14.0 も 16.0 も同じ理由で拒否されました）。

そして、この指定はこのゲームにとって**そもそも間違い**です。
2D の横スクロールアクションが「ゲーミング性能ティアの iPhone を要求する」と
宣言していることになります。

対処済みです：**この指定を Info.plist から削除**します
（`tools/ios-plist-clean.py`）。最低 iOS は 16.0 のままです。

### アップロードする前に検証する

**これがいちばん重要です。** `altool` には**アップロードせずに検証だけ**する
モードがあり、**問題を1回で全部**返します。有効にしてあります：

```bash
app-store-connect publish --path "$IPA" --enable-package-validation
```

これが無いと、Apple のサーバーは**1回のアップロードにつきエラーを1つ**しか
返さないため、修正 → ビルド → 拒否 を繰り返すことになります。
実際そうなっていました。

さらに、**Apple に送る前に手元で確認**できる分は
`tools/ios-plist-clean.py` が検査します（過去に拒否された条件を全部覚えています）。

### `You already have a current Distribution certificate` (409)

安全のため、ビルドは証明書を推測で自動失効しません。ログの証明書一覧から
不要だと確認できたIDだけを、Codemagicの `signing` グループにある
`REVOKE_CERT_ID` へ設定して再実行してください。指定された1枚だけを失効します。

### 配布証明書の枚数上限

**Apple は1アカウントあたり2〜3枚まで**しか配布証明書を持てません。
上限に達していると新規作成が失敗します。ログの「既存の配布証明書」一覧を見て、
developer.apple.com → Certificates で不要なものを **Revoke** してください。

> ⚠️ Expo が作った証明書を取り消すと、そのアプリは次回ビルド時に証明書を
> 作り直すことになります。**すでに App Store に出ているアプリは影響を受けません**が、
> Expo 側で再ビルドが必要になります。

### App Store Connect に何も上がってこない

**未署名のワークフローを選んでいませんか。** 未署名の `.ipa` は Apple が受け取りません。
**「iOS — TestFlight に提出（署名付き）」**を選んでください。

---

## 遊ぶとき

起動画面で **「インターネット（離れていても）」** の
**「部屋を作る（あなたがランナー）」** を押すと **6文字の合言葉**が出ます。
それをお友達に伝え、相手は同じ画面で合言葉を入れて **「合言葉で入る」**。

中継サーバーのURLは**入力済み**です。触る必要はありません。

---

## App Store への「公開提出」は、まだやらないでください

TestFlight（お友達に渡す）と App Store 提出（一般公開の審査）は別物です。
公開提出には追加でスクリーンショット・説明文・**プライバシーポリシーURL**・
年齢レーティング・App Review（数日）が要ります。

そしてそれ以前に、**権利上の問題があります。**

このゲームのアートは、いただいたモックアップから切り出したものです。その中に
**緑の土管・`?` ブロック・レンガブロック・キノコ型の敵・キノコ屋根の城**が含まれています。
これらは任天堂のマリオシリーズの、非常に識別性の高い意匠です。

- **TestFlight の Internal テスト**は非公開で、対象もあなたが招待した人だけなので、実務上の問題は小さいです
- **App Store への公開提出は、審査でのリジェクトと、権利者からの申し立ての対象になり得ます**

権利をお持ちでないのであれば、**公開の前にアートを差し替える**ことを強くおすすめします。
画像は `Art.MANIFEST` を通しているので、**差し替えてもコードは一行も変わりません**。
