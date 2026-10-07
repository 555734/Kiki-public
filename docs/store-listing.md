# ストア提出物 — メロスゲーム 0.9.16

App Store Connect と Google Play Console に**そのまま貼れる**文面と、
どちらのフォームに何と答えるかをまとめたもの。ビルドの中身ではないので
コードからは検証できない。ここが唯一の正本になる。

対象ビルド: version 0.9.16（Android versionCode 43）。提出前の原稿であり、ストア提出済みを意味しません。
bundle / package: iOS `com.sasakiful.sidesky` / Android `com.sasakiful.melos`

> プライバシーポリシーは公開済み:
> **https://555734.github.io/Kiki-public/privacy-policy.html**

---

## 1. 名前とテキスト

### 日本語（両ストアの主要言語）

| 欄 | 文字数上限 | 内容 |
|---|---|---|
| アプリ名 | iOS 30 / Play 30 | `メロスゲーム` |
| サブタイトル (iOS) | 30 | `ふたりで越える、非対称の協力プレイ` |
| 簡単な説明 (Play) | 80 | `ひとりが走り、ひとりが世界を描き換える。通話しながら遊ぶ協力アクション。` |

**詳しい説明（両ストア共通）**

```
ふたりで、ひとつのステージを越える協力アクションです。

【走る人】画面の中を走り、跳び、壁を蹴り、空中でダッシュします。

【見守る人】足場を描き、射撃で敵や追跡者を止めて、走る人の道を作ります。地形に当たった足場は、当たる直前までの部分が残ります。

第一章の8ステージを収録。草原、村はずれ、空の遺跡、海岸、溶岩峡谷、砂の遺跡、歯車の塔、地下の森を進みます。6文字の合言葉で離れた友達とつながるか、1台で一緒に遊べます。

スターを取り合う対戦モードも無料です。ロイヤル・アリーナでは、ジャンプ台や移動足場を使って空中のスターを奪い合えます。

ステージ1-1・1-2・1-6〜1-8は無料で最後まで遊べます。完全版の買い切り購入でステージ1-3、1-4、1-5が開きます。完全版を持つ人の部屋には、買っていない友達も参加できます。

広告・定期課金はありません。
```

**新機能 / リリースノート（0.9.3）**

<!-- release-notes:ja -->
```
・新ステージ 1-6〜1-8 を追加しました（完全版に含まれます）
・1-5 と 1-6 を、協力して足場を作りながら登るステージに作り直しました
・スターたいせん（対戦モード）を追加しました。誰でも無料で遊べます
・iPhone で購入の復元ができないことがある問題を直しました
```

**リリースノート（0.9.0）**

```
最初の公開版です。5ステージ、オンライン2人プレイ、完全版の買い切りに対応しました。
```

### English (secondary locale)

> 英語名は `Melos Game` とした。日本語名が「メロスゲーム」になった以上、
> 英語だけ `Run, Melos` のままにすると別のアプリに見える。変えたければ
> ここ1か所で、ストアのフォームに入れる前に決めること。

| Field | Content |
|---|---|
| Name | `Melos Game` |
| Subtitle | `Asymmetric co-op, two players` |
| Short description | `One player runs. One rewrites the world. A co-op action game made for two.` |

```
A co-op action game for two players. Work together to cross the stage.

THE RUNNER runs, jumps, wall-kicks, and air-dashes.

THE GUARDIAN draws platforms and shoots enemies and pursuers to make a path for the runner. Platforms that hit terrain keep the valid section before the collision.

Explore eight stages in Chapter One: grassland, village outskirts, sky ruins, seaside, a lava canyon, sand ruins, a clockwork tower, and an underground grove. Connect with a friend using a six-character room code or play together on one device.

Star Battle is free for everyone. In Royal Arena, use jump pads and moving platforms to compete for stars in the air.

Stages 1-1, 1-2, and 1-6 through 1-8 are free to play all the way through. A single non-consumable purchase unlocks stages 1-3, 1-4, and 1-5. Friends who have not purchased the full version can join a full-version owner's room.

No ads or subscriptions.
```

### キーワード（iOS、100文字、カンマ区切り）

```
協力, co-op,2人,ふたり,アクション,プラットフォーマー,通話,オンライン,友達,非対称,広告なし,買い切り
```

---

## 2. カテゴリと年齢レーティング

| | 回答 |
|---|---|
| カテゴリ | ゲーム / アクション（Play: `GAME_ACTION`、`package/app_category=2` と一致） |
| iOS 年齢制限 | **9+** |
| Play / IARC | **全年齢〜12歳未満相当**（下の回答のとおり） |

**なぜ 9+ か。** 敵を狙撃して倒す、トゲや落下で自機が消える、1-2 は暗い村はずれ
という演出がある。血液・人物への残酷描写・性的表現・薬物・ギャンブル・
ユーザー生成コンテンツは**一切ない**。

**両ストアの質問に対する回答**

| 質問 | 回答 |
|---|---|
| 暴力表現（対人／リアル） | なし |
| 暴力表現（マンガ・ファンタジー） | **あり・頻度は低い／軽度**（小さな敵を撃つ） |
| 流血 | なし |
| 性的表現・ヌード | なし |
| 冒涜的表現 | なし |
| アルコール・たばこ・薬物 | なし |
| ギャンブル（模擬含む） | なし |
| 恐怖・ホラー表現 | **あり・軽度**（1-2 の暗い演出） |
| ユーザー同士の交流 | **あり**（合言葉で入る2人の部屋のみ。**チャット・音声・投稿機能は無い**） |
| 位置情報の共有 | なし |
| 購入 | **あり**（アプリ内購入1件） |
| 広告 | なし |

> 「ユーザー同士の交流」を**あり**と答えること。通信して一緒に遊ぶ以上、
> 交流機能が無いとは言えない。ただしこのゲームにはメッセージ欄も音声も無く、
> 相手に送れるのは自分が動かすキャラクターの動きだけ、という説明を添える。

---

## 3. プライバシー申告

正本は `docs/privacy-policy.md`。両ストアのフォームには次のとおり答える。

### App Store Connect — App のプライバシー

| データ種別 | 収集 | 用途 | 個人に紐づくか |
|---|---|---|---|
| 識別子 → **デバイスID** | **する** | アプリの機能（対戦相手との接続、購入の復元） | **紐づけない** |
| 購入履歴 | **する** | アプリの機能（完全版の権限確認） | **紐づけない** |
| 連絡先情報・位置情報・連絡先・ユーザーコンテンツ・検索履歴・閲覧履歴・使用状況データ・診断 | **しない** | | |
| トラッキング | **しない**（ATT のダイアログは出さない） | | |

### Google Play — データセーフティ

| 項目 | 回答 |
|---|---|
| データを収集または共有するか | **はい** |
| 収集するもの | **デバイスID または他のID**、**購入履歴** |
| 目的 | アプリの機能 |
| 必須か任意か | オンラインで遊ぶとき／購入するときのみ。**必須ではない** |
| 第三者と共有するか | **はい** — Epic Online Services（接続のため） |
| 転送時に暗号化されるか | **はい** |
| 削除を要求できるか | **はい**（ポリシー記載の連絡先） |
| 独立したセキュリティ審査 | 受けていない |

---

## 4. プライバシーポリシーの公開URL

**これを入れる:**

```
https://555734.github.io/Kiki-public/privacy-policy.html
```

両ストアの「プライバシーポリシー」欄に同じものを入れる。サポートURLは
`https://github.com/555734/Kiki-public` で足りる。

中身は `docs/privacy-policy.html`（正本は `docs/privacy-policy.md`。両方を
直すこと ―― HTML のほうが公開される)。`docs/.nojekyll` を置いてあるので
GitHub は Jekyll を通さずそのまま配信する。他の `docs/*.md` は変換されずに
テキストとして置かれるだけで、リポジトリが公開である以上すでに読める内容。

有効化（**一度だけ**。私が `gh api` で済ませたが、消えたらここから）:

```bash
gh api -X POST repos/555734/Kiki-public/pages -f "source[branch]=main" -f "source[path]=/docs"
```

反映まで1〜2分かかる。開けることを**ブラウザで確認してから**ストアの欄に入れること。

## 5. スクリーンショット

撮るものは決まっている。**5枚とも横向き**で、各ステージ1枚ずつ。

| # | 内容 |
|---|---|
| 1 | 1-1。走る人と、いま置かれた足場が同じ画面にある瞬間 |
| 2 | 見守る人の画面。照準と道具ボタンが見えている |
| 3 | 1-3 の縦の遺跡。先の高さが見えている |
| 4 | 1-4 の海岸 |
| 5 | 合言葉の画面（6文字が見えているもの） |

必要サイズ:

| ストア | サイズ |
|---|---|
| iOS 6.9インチ（必須） | 2868×1320 または 1320×2868 |
| iOS 13インチ iPad（iPad対応のため必須） | 2064×2752 など |
| Play スマートフォン（必須・2〜8枚） | 短辺1080px以上、16:9 横 |
| Play フィーチャーグラフィック（必須） | 1024×500 |

**撮影済み（2026-09-26）。** 実物は `../store-assets/` にある
（リポジトリ外。PNGが20枚以上あり、コミットすると数十MB増えるため）。
必要サイズごとにフォルダが分かれていて、どのフォームに入れるかは
`store-assets/README.md` に書いてある。

撮り直すとき:

```bash
godot --path . --rendering-method gl_compatibility --rendering-driver opengl3     --resolution 1280x720 --fixed-fps 60 tools/capture_store_shots.tscn     -- --ci-skip-eos --shot-size 2868x1320
```

`--shot-size` がそのまま出力サイズになる。**`--resolution` ではない** ——
ウィンドウはディスプレイより大きくできず、2868 を頼むと黙って 1924 が出てきて、
どちらのストアもそのサイズを受け取らない。だから SubViewport に描いている。

フィーチャーグラフィックは `--no-hud` で撮った素材から合成してある。

---

## 6. App Review へのメモ（iOS の「レビューに関する情報」欄にそのまま貼る）

```
このゲームは2人で遊ぶ協力ゲームです。レビュアーが1人で確認できるよう、
以下の手順をご利用ください。

1. 1人での確認
   スタート画面 →「この端末でふたり（ローカル）」を選ぶと、1台で両方の役を
   操作できます。課金なしで 1-1 と 1-2 を最後まで確認できます。

2. アプリ内購入の確認（full_unlock / 非消費型 / 1回限り）
   スタート画面で 1-3〜1-5 のいずれかのステージをタップすると購入画面が
   開きます。Sandbox アカウントでご確認ください。
   「購入を復元する」も同じ画面にあります。

3. オンライン対戦の確認（任意・端末2台が必要）
   一方で「部屋を作る」→ 表示された6文字を、もう一方の「合言葉で入る」に
   入力します。中継サーバーのURLは入力済みです。

補足:
- ユーザー同士のメッセージ機能・音声チャット・投稿機能はありません。
  相手に伝わるのは操作しているキャラクターの動きだけです。
- アカウント登録はありません。氏名・メールアドレスは一切取得しません。
- 広告および解析用のSDKは含まれていません。
```

---

## 7. 提出前チェックリスト

`tools/release-check.sh` が自動で見る部分は ✅ 印。人が見る部分だけ残した。

- [x] `docs/privacy-policy.md` の連絡先を埋めた（a3506124@gmail.com）
- [x] GitHub Pages を有効にし、ポリシーURLが**ブラウザで開けた**
- [x] ✅ 署名鍵が本番のもので、Worker に対になる秘密鍵が入っている
      （deploy-worker が `/entitlement/health` の指紋と `entitlement_key.json` を照合）
- [x] ✅ バージョンと versionCode が全箇所一致している（release-check）
- [x] ✅ 課金プラグインがピン留めされ、提出ビルドに実際に入っている
      （iOS: Xcode プロジェクトの inappstore、Android: AAB の BILLING 権限と billingclient）
- [x] Play Console: `full_unlock` を作成・有効化した（2026-10-04 に Android で購入成功）
- [x] ✅ Worker の `GOOGLE_SERVICE_ACCOUNT` が Play API に通る（health の google）
- [x] App Store Connect: `full_unlock` を作り、審査用スクショとレビューメモを付けた
- [x] App Store Connect: **Paid Applications 契約**を完了した（2026-10-04 に iOS で購入・復元成功）
- [x] ✅ Worker の Apple 鍵が App Store Server API に通る（health の apple）
- [x] スクリーンショットとフィーチャーグラフィックを用意した（`store-assets/`）
- [x] 実機で**実際に1回購入した**（iOS / Android、2026-10-04）
- [x] **再インストール後に「購入を復元する」が通った**（iOS、2026-10-04 21:02、`/entitlement/recent` で確認）

### 残っている判断（人が決めること）

（解決済み）開発者コード欄のある `net_diagnostics.gd` は全プリセットの
exclude_filter で出荷ビルドから除かれている。以下は経緯として残す。

**接続記録画面の「開発者コード」欄**を審査ビルドに残すかどうか。
`docs/monetization.md` 6章のとおり、これは開発者2人が自分の端末に権限を
付けるためのもので、ユーザーにストア外の購入経路を提供するものではない。
ただし**有料コンテンツが合言葉で開く入力欄**であることは事実で、
App Review が 3.1.1 として扱う可能性は残る。

隠す場合の変更は1行:
`src/ui/net_diagnostics.gd` の開発者コード欄を作っている箇所を
`if OS.is_debug_build():` で囲む。発売後は Play / App Store の
プロモーションコードへ移行する計画がすでに書かれている。

## 0.9.4 更新内容

ステージ1-2〜1-5の背景・地形・敵・足場を刷新しました。
天空の遺跡の浮島を見やすくし、海岸にフグ、火山にゴーレムを追加しました。
ステージ1-5を溶岩の峡谷に変更しました。
ゲームは従来どおり横画面で遊べます。

## 0.9.5 更新内容

ステージ1-6〜1-8の背景・敵・足場・罠を添付素材へ更新。横画面の実プレイと協力ギミックの動作を検証。

## 0.9.6 更新内容

1-7・1-8の背景を引きの表示に調整しました。
各ステージに素材を使った追跡敵を配置しました。
初期設定の移動スティックが左下の押した位置に表示されるようになりました。
1台モードのジャンプを大きくし、右下に配置。足場・狙撃はその上に配置しました。

**新機能 / リリースノート（0.9.7）**

<!-- release-notes:ja -->
```
対戦モードにロイヤル・アリーナを追加しました。空に浮かぶ王国で、ジャンプ台や移動足場を使ってスターを奪い合えます。新しいステージが対戦の初期ステージになりました。対戦中のタッチ操作も改善しました。
```


**新機能 / リリースノート（0.9.9）**

<!-- release-notes:ja -->
```
協力プレイで移動ボタンの入力が失われる不具合を修正しました。射撃中の横スワイプで画面がスクロールしなくなりました。対戦モードのスターをジャンプで取れる空中の位置に変更しました。
```


**新機能 / リリースノート（0.9.10）**
<!-- release-notes:ja -->
```
移動操作の反応を改善しました。足場と射撃の選択中のボタンが分かりやすくなり、足場は地形に当たる直前まで残るようになりました。射撃の照準操作で画面が横に動く機能を廃止しました。ロイヤル・アリーナのスターを空中に配置し、ジャンプして取り合う遊びに調整しました。描画とステージ設定の自動検証、配布時の確認も強化しています。
```

**English release notes (0.9.10, submitted to App Store Connect)**

```
Improved movement controls and made the selected platform or shooting button easier to recognize. Platforms now keep the valid section before hitting terrain. Aiming shots no longer scrolls the camera sideways. Stars in Royal Arena are now placed in the air for jump-based competition. Added automated checks for visuals, stage settings, and release verification.
```
**新機能 / リリースノート（0.9.11）**
<!-- release-notes:ja -->
```
長く走り続けると、もう一段階速く走れるようになりました。空中でもう一度ジャンプできるようになりました。ステージ1-7と1-8を、毎回違うしかけの部屋を登るステージに作り直しました。対戦モードに3分の時間制限とサドンデス、試合結果の表、スターを落とした理由の表示、ルールのヒント、通信が切れたときの再接続、「1台でためす」の練習相手を追加しました。タッチ操作の不具合も修正しています。
```

**English release notes (0.9.11)**

```
Keep running and you now shift into an even faster gear. You can now jump once more in mid-air. Stages 1-7 and 1-8 are rebuilt as climbs through rooms that each use a different gimmick. Versus mode adds a 3-minute time limit with sudden death, a results table, a log of why stars were dropped, rule tips, reconnecting after a dropped connection, and a practice partner for single-device play. Touch control fixes are included too.
```

**新機能 / リリースノート（0.9.13）**
<!-- release-notes:ja -->
```
砂漠ステージ1-6を、異なる遊び方を持つ20区間へ拡張しました。風の井戸、振り子、歯車、ピストンの地下道、点滅床との乗り換え、転送、射撃で維持する橋、ガーディアンの救援壁を追加しています。旧ステージを持つバージョンとの通信不一致も防ぎました。
```

**新機能 / リリースノート（0.9.14）**
<!-- release-notes:ja -->
```
海岸1-4と溶岩1-5を、それぞれ異なる遊び方の20区間へ作り直しました。空中へ射出する転送門、踏み抜く床、予告付きの落石、上下を入れ替えるルート、歯車と動く床の乗り継ぎなどを追加しています。旧地形を持つバージョンとの通信不一致も防ぎました。
```

**新機能 / リリースノート（0.9.16）**
<!-- release-notes:ja -->
```
溶岩ステージ1-5を上下二段の火山峡谷へ改修しました。深い火口を下り、下段の溶岩洞へ進みます。予兆付きのマグマ噴出と隕石を移動床や崩れる床に組み合わせ、最後の協力地点を越えて鍵を取る構成にしました。旧配置との通信不一致も防ぎました。
```
