# 完全版買い切りとフレンドパス

走れメロスは**基本無料**でダウンロードでき、**1-1 と 1-2 は誰でも遊べる**。
1-3 / 1-4 / 1-5 は完全版（非消費型の一回限りのアプリ内課金）に含まれる。

そして、**完全版を持っている人が作った部屋には、買っていない友達1人がそのまま
入って全ステージを一緒に遊べる**。これは抜け道ではなく仕様である。このゲームは
2人で通話しながら遊ぶために作られていて、片方しか買っていないペアが遊べないなら
売り物として成立しない。

---

## 1. 4つの状態

`src/autoload/entitlement.gd` がこの4つを一元管理する。ほかのどこにも
「このステージは遊べるか」の判断は無い。

| 状態 | どこから来るか | 有効範囲 |
|---|---|---|
| `FREE` | 何もない | 1-1 と 1-2 |
| `FULL` | 自分の `kind:"full"` トークン | 全ステージ・永続（30日ごとに自動更新） |
| `DEV` | 自分の `kind:"dev"` トークン | 全ステージ・7日ごとに更新 |
| `GUEST` | 相手から受け取った有効なトークン | 全ステージ・**メモリのみ**・部屋が終われば消える |

`GUEST` はディスクに一切書かない。だからゲストがクリアした記録は残っても、
あとで1人で同じステージを開こうとすれば `FREE` に戻っている。

### 誰が部屋を作れるか

`can_play()` と `can_host()` は別物で、ここが仕組みの要になっている。

- `can_play(paid)` … `FULL` / `DEV` / `GUEST`
- `can_host(paid)` … `FULL` / `DEV` のみ（**ゲストは除く**）

この1行から、サーバでセッション数を数えることなく次が成立する。

- 未購入者2人では有料ステージの部屋が**作れない**ので、始められない
- EOSロビーは2人上限（`max_lobby_members = 2`）なので、
  **1つの購入端末が同時にゲストにできるのは1人だけ**
- ゲストは借りた権限を又貸しできない
- 購入者が抜ければロビーが壊れ、ゲストの権限も一緒に消える

---

## 2. 権限トークン

サーバが発行する自己完結型の署名付き文字列。

```
base64url(payload) "." base64url(signature)
payload = {"v":1,"kind":"full"|"dev","puid":"<EOS ProductUserId>",
           "plat":"android"|"ios","iat":…,"exp":…}
```

**RSA-2048 / PKCS#1 v1.5 / SHA-256。** Ed25519 ではない —— Godot の
`Crypto.verify()` は RSA しか検証できず、検証はクライアントでやる必要がある。

- アプリが持つのは**公開鍵だけ**（`entitlement_key.json`）。公開鍵は秘密ではない
  ので、再現性のためにリポジトリにコミットしてある
- 秘密鍵は Cloudflare Worker の Secret にしか存在しない
- `full` は30日、`dev` は7日。期限内はオフラインでも遊べる

### なぜトークンなのか（毎回サーバに聞かない理由）

答えは**飛行機の中でも**、そして**相手の端末でも**必要だから。Android で買った
purchase token を、iPhone のゲスト端末が Google に問い合わせることはできない。
短命の署名付き証明書は持ち運べる。サーバ問い合わせは持ち運べない。

---

## 3. フレンドパスの検証

ハンドシェイク（`Protocol.VERSION = 15`）の HELLO と WELCOME の末尾に、
それぞれの端末のトークンが乗る。受け取った側は3つ確認する。

1. **署名**が公開鍵で検証でき、`exp` が切れていないこと
2. トークンの `puid` が、**EOSロビーが報告するその相手の PUID** と一致すること
   （パケットの自己申告ではなく `NetTransport.peer_identity()`、実体は
   `EosCoopLobby.remote_puid()`）
3. ロビー属性 `room_kind` が `"friend"` であること

HELLO は再接続時もまったく同じ経路で処理される（`HostSession._resync` の
コメント参照）ので、**通信が切れて戻ってきたときの権限復帰に専用の分岐が無い**。
「壊れたときだけ通る道」を作らないための設計で、課金もそれに乗せた。

### フレンドルームと公開ルーム

いまの部屋はすべて「6桁を口頭で伝えて入る」招待制で、ロビーは
`allow_invites=false` / `enable_join_by_id=false`、`room_code` 完全一致でしか
検索できない。それでも `room_kind` 属性を**いま**書いておく。

- `create_room()` は常に `"friend"` を書く
- 将来の野良マッチングは `"public"` を書く
- **フレンドパスは `"friend"` のときしか渡さない**

属性が読めない部屋は `"friend"` ではないものとして扱う。読めない答えを
気前のいい方に倒してはいけない。

---

## 4. 何を守れて、何を守れないか

**守れること**

- `user://entitlement.json` を書き換えても解放されない（署名検証で落ちる）
- 他人のトークンをコピーしても使えない（`puid` に束縛されている）
- 期限切れトークンの再生は効かない
- 通信で「自分は購入者だ」と名乗るだけでは何も起きない
- アプリの中に隠し解除機能も、秘密鍵も、ストアAPIの資格情報も**存在しない**
- 1つの購入が同時に2人のゲストを連れてくることはできない（ロビーが2人上限）

**守れないこと**

**APKを改造した人間は、自分の端末で全ステージを解放できる。** これは Godot に
限らず、サーバ権威でないゲーム全部に当てはまる。ここでやっているのは
「普通のクライアントが騙されない」ことであって、「改造が不可能」ではない。
そう書けないことを、そう書かない。

---

## 5. サーバ（Cloudflare Worker）

既存の `side-sky-signalling` Worker に3つのルートを足した。新しい Worker も
VPS も増やさない。**追加の月額費用はゼロ**（Workers 無料プラン・
SQLite-backed Durable Objects・1日10万リクエストまで）。

| ルート | 内容 |
|---|---|
| `POST /entitlement/verify` | ストアのレシート → 検証 → 署名トークン |
| `POST /entitlement/renew` | 期限が近いトークン → ストアに聞かずに延長 |
| `POST /entitlement/dev-enrol` | 開発者の合言葉 → `dev` トークン |

実装は `server/signaling/entitlement.js`。テストは
`server/signaling/entitlement.test.mjs`（`npm run test:entitlement`、
ネットワーク不要）。

### ストアAPIの呼び出し回数

検証結果は Durable Object に記録され、**7日以内の再確認はストアに聞かない**。
`/renew` はキャッシュだけを見る。クライアントも「期限まで7日を切るまで叩かない」。
実効的に**購入1件あたり月1回程度**。

### 障害時・返金時

- ストアAPIが落ちている + 過去に検証済み → **そのまま発行する**（遊べ続ける）
- ストアAPIが落ちている + 未知のレシート → `503`。クライアントは手持ちの
  未期限トークンを使い続け、「購入できませんでした」とは言わない
- 返金・購入取消し → `revoked` を返し、クライアントはトークンを破棄する

### 機種変更・再インストール

同じストアアカウントなら同じ purchase token / originalTransactionId が返る。
Worker は `bind:<platform>:<receipt>` の行を**新しい端末に付け替える**。
だから機種変更は動き、レシートの使い回しで2本目のコピーにはならない。

### Android の acknowledge について

**Google は3日以内に acknowledge されなかった購入を自動返金する。**
これは端末ではなく **Worker の `verify` の中で**やっている。購入が本物だと
分かる最初の瞬間がそこで、レシート画面でアプリを閉じたプレイヤーが
支払った game を失わないため。

### Apple の検証について

`verifyReceipt` は使わない（Apple が廃止済み）。App Store Server API の
`GET /inApps/v1/transactions/{transactionId}` を、本番 → Sandbox の順で叩く。
Apple が署名した JWS のペイロードを読んでいるが、x5c 証明書チェーンまでは
検証していない。自分の秘密鍵が無いと話しかけられないエンドポイントから
TLS で届いたものなので現状は十分だが、**この仕組みを商品ID1つより広く使う
なら、チェーン検証を足すこと。**

---

## 6. 開発者2人の無料権限

### いまの取得方法（審査前・審査後どちらでも）

1. Worker Secret に合言葉を入れる: `wrangler secret put DEV_ENROL_SECRET`
2. アプリの **接続記録** 画面（スタート画面 → 遊び方 → 接続記録）を開く
3. 「開発者コード」欄に合言葉を入れて「登録」

以後その端末には `dev` トークン（7日）が発行され続ける。

**クライアントに隠し機能は無い。** コード入力欄は誰にでも見える普通の
テキストボックスで、合言葉は Worker の Secret にしかない。隠しジェスチャや
デバッグビルド限定の解除は作らなかった —— 出荷したアプリの中の隠し解除は、
見つけた全員にとっての隠し解除だからである。

**安全装置**

- 登録できるのは **2端末まで**（`DEV_ENROL_MAX`）。3人目は拒否される
- トークンは **7日**しか持たない

### 消し方（アプリ更新なし）

```bash
wrangler secret delete DEV_ENROL_SECRET
# さらに、既に登録済みの端末も止めるなら Durable Object の dev: 行を消す
```

以後 `dev` トークンは更新されず、**最長7日で開発者権限は自動的に消える**。
端末から何かを回収する必要はない。

### ストア規約との関係

これは「開発者が自分のアカウントに権限を付与する」もので、ユーザーに
ストア外の購入経路を提供するものではないため、Apple / Google どちらの規約にも
抵触しない。ただし**合言葉が漏れれば最大2人の第三者が無料で遊べる**ので、
上限2件・7日失効・即時無効化をもって担保している。

### 発売後の正規手段（本命）

ストアが公式に用意している手段に移行する。こちらは規約上の議論が一切ない。

- **Google Play Console** → 「プロモーション コード」でアプリ内アイテムの
  無料コードを発行（アプリ内アイテムごとに四半期500件まで）
- **App Store Connect** → App内課金の「プロモーションコード」を発行
  （アプリごとに年間1000件まで）

移行が済んだら `DEV_ENROL_SECRET` を消す。

---

## 7. 人が管理画面でやること

### Google Play Console

1. **アプリ内アイテム** → 商品ID `full_unlock` / **管理対象アイテム（非消費型）**
   / 価格500円 を作成し、**有効化**する
2. **API アクセス** → サービスアカウントを作成し「財務データの表示」
   「注文と定期購入の管理」を付与 → JSON キーをダウンロード
3. **ライセンステスト** → 開発者2人の Google アカウントを登録（購入が常に無料）
4. **内部テストトラック**にビルドを上げる
   —— **アプリ内課金は内部テスト以上でないとテストできない**

### App Store Connect

1. **App内課金** → 非消費型 → 商品ID `full_unlock` / 価格（500円相当のTier）
   を作成。審査用スクリーンショットとレビューメモが必須
2. **Users and Access → Integrations → App Store Server API** で `.p8` キーを発行
   （Key ID と Issuer ID も控える）
3. **Sandbox テスター**を開発者2人分作成
4. **Paid Applications 契約**（Agreements, Tax, and Banking）を完了させる
   —— **未完了だとアプリ内課金は一切動かない。ここが一番よく忘れられる**

### Cloudflare

**鍵は 2026-09-26 に生成済み。** `entitlement_key.json` に入っている公開鍵の
指紋は次のとおりで、Worker に入れた秘密鍵と対になっていることをこれで照合できる。

```
openssl rsa -pubin -in <秘密鍵から作った公開鍵> -outform DER | sha256sum
abf1b1790bbf6af2b8ea8e38e4699e87aed265598484f6025ed18ea36a382e8c
```

`tools/release-check.sh` が、公開鍵が PLACEHOLDER のまま出荷されることを
**拒否する**（`entitlement.gd` が昔からそう書いていた検査が、いま実在する）。

作り直すとき:

```bash
# 署名鍵を作る（秘密鍵はこの1回しか表示されない）
tools/make-entitlement-key.sh
# → entitlement_key.json が更新される。これはコミットする（公開鍵なので）

cd server/signaling
wrangler secret put ENTITLEMENT_SIGNING_KEY   # 上で表示された秘密鍵
wrangler secret put GOOGLE_SERVICE_ACCOUNT    # Play Developer API の JSON 全文
wrangler secret put APPLE_ASC_KEY             # .p8 の中身
wrangler secret put APPLE_ASC_KEY_ID
wrangler secret put APPLE_ASC_ISSUER_ID
wrangler secret put DEV_ENROL_SECRET          # 開発者の合言葉
wrangler deploy
```

### 課金プラグインのピン留め（2026-09-26 完了）

**Android は release アーカイブのピン留め。** チェックサムは実測して
`tools/install-iap-plugins.sh` に入っている。

```
3.3.0 / godot-google-play-billing.zip
sha256 20d75623d6f337f08d8283c83098b73678d5f575e39247af5a8eb80588b18568
```

> **URLが2か所間違っていた。** タグは `v3.3.0` ではなく `3.3.0`、アセット名は
> `GodotGooglePlayBilling-3.3.0.zip` ではなく `godot-google-play-billing.zip`。
> さらにアーカイブの最上位は `addons/` ではなく `GodotGooglePlayBilling/` なので、
> 展開先は `addons/` を指定しないと入らない。3つとも直してある。
>
> なお同じリポジトリの **1.4.0（3.3.0より新しい日付）は Godot 3 系の保守版**で、
> このプロジェクトには**間違ったほう**である。使うのは 3.x 系。

**iOS はピン留めできるアーカイブが存在しない。** `godot-ios-plugins` の
バイナリリリースは **3.5-stable（2022年）で止まっていて、Godot 4 用は一度も
配布されていない。** `docs/` に書いてあった「落としてチェックサムを貼る」手順は、
そもそも落とすものが無いので実行できない。

代わりに**ソースをピン留めしてビルドする**。`tools/build-ios-iap-plugin.sh` が
macOS ランナー上で:

1. プラグインを **commit `caafb2c7`** で取得（shallow）
2. エンジンのヘッダを **`4.7.2-stable`** で取得
3. `inappstore` を arm64 端末 / 両シミュレータ向けに release と debug でビルド
4. `ios/plugins/` に `.gdip` と2つの `.xcframework` を置く

固定するものが zip から (commit, engine tag) の2つに変わっただけで、約束は同じ:
**同じ入力からは同じプラグインが出る。**

iOS プラグインは**エクスポートされたアプリに静的リンクされる**ので、
**そのアプリをビルドするエンジンと同じバージョンのヘッダで**コンパイルしなければ
ならない。4.0 のヘッダでビルドして 4.7 で出すと、リンクエラーか、
CIでは起きず実機でだけ起きるクラッシュになる。

**CIの状態（いま）**

- `android.yml` … `env.IAP_PLUGINS: "1"`（常に入る）
- `android-play.yml` … **無条件**。ストアに出す .aab が課金を持たないことは
  ありえないので、入らなければビルドを落とす
- `ios.yml` … App Store 提出モードのときだけビルドする。未署名フォールバックは
  パッケージングの確認なので StoreKit を要らない（macOSランナーで数分かかる）

### 取引を閉じる（iOS）

`Iap._redeem()` は、**サーバがトークンを返したあとで** バックエンドの
`finish()` を呼ぶ。順序は意図的で、先に identifier がサーバに渡っているので、
その間にクラッシュしても復元できないものは無い。

これは 2026-09-26 に入れた。それまで `iap_ios.gd` は `_finish` を receipt に
入れて返していたが、**誰もそれを読んでいなかった** —— StoreKit は閉じられて
いない取引を毎回配信し直すので、課金は1回なのに購入画面が起動のたびに出続ける。
Apple のリジェクト事由でもある。プラグインが入っていないビルドでは
`Iap.available()` が false なので、**配線するまで発現しないバグ**だった。

### GitHub Secrets

**新しく必要なものは無い。** クライアントは公開鍵しか持たないので、
ビルドに追加の秘密は要らない。これは意図的な設計である。

---

## 8. 課金プラグインの選定

`tools/install-eosg.sh` と同じ流儀（バイナリはコミットせず、CIが
チェックサム検証して取得）に揃えた。

- **Android**: 公式（Godot Foundation）の **GodotGooglePlayBilling 3.3.0**。
  1st-party でメンテナンス性が最も高い。新しい `BillingClient` API を使う
  （廃止された 1.x のシングルトンAPIではない）
- **iOS**: `godot-sdk-integrations/godot-ios-plugins` の **inappstore**。
  **StoreKit 1 ベース**で、Godot 4.4 以降での過去購入の復元が不安定だという
  報告がある。**プリビルドは無い**（上記）ので commit 固定でソースビルドする

iOS の弱さは設計で吸収してある: **復元の正はサーバ側のキャッシュ**であり、
プラグインは transaction id を取り出す役でしかない。同じストアアカウントなら
同じ id が返り、Worker はそれをすでに知っている。

`src/store/iap_android.gd` と `iap_ios.gd` はどちらも **addon の型名を一切
書かない**（`load()` で動的に読む）。書いてしまうと、プラグインを入れていない
チェックアウト —— 自動テストが走るチェックアウト全部 —— で parse に失敗する。

**未確定**: `query_product_details_response` が返す商品辞書の価格キーの正確な
綴りは、実機でしか確認できていない。`iap_android.gd` は
`one_time_purchase_offer_details` / `oneTimePurchaseOfferDetails` と
`formatted_price` / `formattedPrice` の両方を試し、どれでもなければ空を返す
（価格欄が「読み込み中」のままになる）。実機で確認したら1つに絞ること。

---

## 9. テスト

### 自動（ネットワーク・ストア不要）

```bash
GODOT=<godot> tools/verify.sh              # entitlement_probe を含む
cd server/signaling && npm run test:entitlement
```

`test/entitlement_probe.gd` は**起動時に使い捨てのRSA鍵を生成**して検証する。
本番鍵も裏口も使わない。トークンは「いま入っている鍵で署名されたもの」しか
通らないので、テストは自分の鍵を入れて、署名なし・他人のPUID・期限切れが
ちゃんと落ちることを示せる。

### 実機でしか確かめられないこと

- 実際の購入・復元フロー（ストア商品の登録が必要）
- Android ↔ iOS のクロスプレイ
- 返金・機種変更の実挙動
- Worker と本番ストアAPIの疎通
- 上記「未確定」の価格キー

**これらを「確認済み」と書かないこと。**

---

## 10. コードの置き場所

| ファイル | 役割 |
|---|---|
| `src/autoload/entitlement.gd` | 4状態・トークン検証・友達パスの受け渡し |
| `src/store/iap.gd` | 課金のファサード（プラグインが無ければ静かに無効） |
| `src/store/iap_android.gd` / `iap_ios.gd` | 各ストアの薄いラッパ |
| `src/store/entitlement_client.gd` | Worker への3ルート |
| `src/ui/purchase_panel.gd` | 3つの扉（買う / 友達と遊ぶ / 復元する） |
| `src/ui/net_panel.gd` | 鍵バッジ・join専用モード・部屋作成のガード |
| `src/net/protocol.gd` | v15。HELLO と WELCOME にトークン |
| `src/net/eos/eos_coop_lobby.gd` | `room_kind` 属性と部屋作成のガード |
| `server/signaling/entitlement.js` | 検証・署名・重複防止・開発者登録 |
| `entitlement_key.json` | 署名の**公開**鍵（コミットする） |

`Stage.is_free()` は `src/levels/stage.gd` にあるが、**`Stage.use()` には
ゲートを入れていない**。テストの全 probe が `Stage.use()` を直接呼んで
ジオメトリを調べているので、そこを塞ぐとスイートごと倒れる。ロックは
「プレイヤーがゲームを始める場所」——メニューと部屋作成——にだけ置いてある。
