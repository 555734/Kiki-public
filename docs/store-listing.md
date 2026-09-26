# ストア提出物 — メロスゲーム 0.9.0

App Store Connect と Google Play Console に**そのまま貼れる**文面と、
どちらのフォームに何と答えるかをまとめたもの。ビルドの中身ではないので
コードからは検証できない。ここが唯一の正本になる。

対象ビルド: version 0.9.0 / Android versionCode 25
bundle / package: `com.sasakiful.sidesky`（両プラットフォーム共通）

> **先に埋めるもの（2つだけ）**
> 1. `docs/privacy-policy.md` の `<連絡先メールアドレス>`
> 2. そのポリシーの**公開URL**（下の「プライバシーポリシーの公開手順」）
>
> この2つが埋まるまで、どちらのストアも提出フォームを閉じられない。

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
見えるのは自分のまわりだけ。目の前の穴が、ひとりでは跳べません。

【見守る人】空の上から先の地形が見えています。
足場を描き、壁を立て、狙撃し、ワープ門を置く。
そして足場をタップして、乗っている相手を空へ打ち上げます。

ひとりでは越えられない場所が、必ず用意してあります。
だからこのゲームは、ふたりの会話そのものになります。
「そこ、もう1枚ちょうだい」「跳んで、今」

■ 5つのステージ
1-1 GREENFIELD PLAINS ― 道具をひとつずつ覚える草原
1-2 THE HOLLOW OUTSKIRTS ― 灯りの少ない村はずれ
1-3 THE SKYWARD RUINS ― 空へ伸びる縦の遺跡
1-4 THE SUNLIT COAST ― 陽の当たる海岸
1-5 THE POISON MARSH ― 沈む沼

■ オンラインでもその場でも
6文字の合言葉を口で伝えるだけで、離れた相手とつながります。
同じ部屋にいるなら、そのまま1台でも遊べます。

■ 無料で始められます
1-1 と 1-2 は誰でも最後まで遊べます。
完全版（買い切り・1回限り）で 1-3 / 1-4 / 1-5 が開きます。
そして完全版を持っている人の部屋には、買っていない友達がそのまま入って、
全ステージを一緒に遊べます。片方が持っていれば、ふたりで遊べます。

■ 広告はありません
広告も、定期課金も、スタミナもありません。
```

**新機能 / リリースノート（0.9.0）**

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
A co-op action game for exactly two people.

THE RUNNER moves, jumps, wall-kicks and air-dashes. They can only see what is
around them, and some gaps are simply too wide to cross alone.

THE GUARDIAN sees the road ahead from above. They draw platforms, raise walls,
snipe, and place warp gates -- and they can tap a platform to launch whoever is
standing on it into the air.

Every stage contains something one player cannot solve. That is the point: the
game is the conversation between you.

FIVE STAGES
1-1 GREENFIELD PLAINS / 1-2 THE HOLLOW OUTSKIRTS / 1-3 THE SKYWARD RUINS
1-4 THE SUNLIT COAST / 1-5 THE POISON MARSH

ONLINE OR SIDE BY SIDE
Read a six-character room code out loud and you are connected. In the same
room, one device works too.

FREE TO START
1-1 and 1-2 are free all the way through. One non-consumable purchase opens
1-3, 1-4 and 1-5 -- and a friend who has not bought it can join YOUR room and
play every stage with you. One copy is enough for two people.

No ads. No subscription. No stamina.
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

## 4. プライバシーポリシーの公開手順

両ストアとも**到達可能なURL**が必須。リポジトリの Markdown は URL にならない。

```bash
# 公開リポジトリ側で一度だけ
# Settings > Pages > Source = "Deploy from a branch", Branch = main, Folder = /docs
```

これで `https://555734.github.io/Kiki-public/privacy-policy` が生えるので、
その URL を両ストアの「プライバシーポリシー」欄に入れる。
サポートURLは公開リポジトリのトップで足りる。

---

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
   スタート画面でステージ 1-3、1-4、1-5 のいずれかをタップすると購入画面が
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

- [ ] `docs/privacy-policy.md` の連絡先を埋めた
- [ ] GitHub Pages を有効にし、ポリシーURLが**ブラウザで開けた**
- [ ] ✅ 署名鍵が本番のもので、Worker に対になる秘密鍵が入っている
- [ ] ✅ バージョンが 0.9.0 / versionCode 25 で全箇所一致している
- [ ] ✅ 課金プラグインがピン留めされ、CIで有効
- [ ] Play Console: `full_unlock` を**管理対象アイテム（非消費型）**として作成し、**有効化**した
- [ ] Play Console: サービスアカウントを作り、Worker に `GOOGLE_SERVICE_ACCOUNT` を入れた
- [ ] App Store Connect: `full_unlock` を作り、審査用スクショとレビューメモを付けた
- [ ] App Store Connect: **Paid Applications 契約**を完了した（これが未完だと課金は動かない）
- [ ] App Store Connect: App Store Server API の `.p8` を Worker に入れた
- [x] スクリーンショットとフィーチャーグラフィックを用意した（`store-assets/`）
- [ ] 内部テスト / TestFlight で**実際に1回購入した**
- [ ] 機種変更を想定し、**別端末で「購入を復元する」が通った**

### 残っている判断（人が決めること）

**接続記録画面の「開発者コード」欄**を審査ビルドに残すかどうか。
`docs/monetization.md` 6章のとおり、これは開発者2人が自分の端末に権限を
付けるためのもので、ユーザーにストア外の購入経路を提供するものではない。
ただし**有料コンテンツが合言葉で開く入力欄**であることは事実で、
App Review が 3.1.1 として扱う可能性は残る。

隠す場合の変更は1行:
`src/ui/net_diagnostics.gd` の開発者コード欄を作っている箇所を
`if OS.is_debug_build():` で囲む。発売後は Play / App Store の
プロモーションコードへ移行する計画がすでに書かれている。
