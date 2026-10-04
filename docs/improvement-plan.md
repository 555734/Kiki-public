# 改善計画（2026-10 レビュー対応）

外部レビューで挙がった15項目を、現行コードに当てて検証した結果と、このブランチで
実施したもの・これから実施するものの計画です。方針はレビューと同じく
「機能を増やすより、既にあるものを壊れにくく、出荷しやすくする」。

## 検証結果の一覧

| 優先 | 項目 | 指摘は正しいか | 状態 |
|---|---|---|---|
| S | サーバーをCIに入れる | 正しい | **実施済み** |
| S | ストア版ビルド経路の常時検証 | 正しい | **実施済み**（週1リハーサル） |
| S | 性能を品質ゲートにする | 正しい | **実施済み**（draw calls / object 数） |
| — | （追加で判明）CIが verify.sh もロジックテストも回していない | — | **実施済み** |
| A | 通信versionとコンテンツversionの分離 | 正しい | 計画（§1） |
| A | Stageデータの型付け | 正しい | **一部実施**（未知typeはエラー）、残りは計画（§2） |
| A | ビジュアル回帰テスト | 正しい | 計画（§3） |
| A | 出荷対象と実験対象の分離 | 正しい | 計画（§4、要判断） |
| A | ドキュメントの一本化 | おおむね正しい | 計画（§5） |
| B | Balance の整理 | 正しい | 計画（§6） |
| B | decor.gd の分割 | 正しい（720行） | 計画（§7） |
| B | リポジトリ軽量化 | 正しいが効果は限定的 | 要判断（§8） |
| B | Node依存関係の固定 | 正しい | **実施済み** |
| B | 診断情報のprivacy | 正しい | **実施済み** |
| B | 開発者unlockを製品UIから除く | **誤り** | 対応不要（下記） |
| C | LICENSE | 正しい | 要判断（§9） |

### 誤っていた指摘：開発者コード欄は release に出ていない

開発者コードの入力欄は接続診断画面（`src/ui/net_diagnostics.gd`）にあり、その画面を
開くボタン「接続記録」は `OS.has_feature("editor")` のときだけ作られます
（`src/ui/net_panel.gd`）。他に診断画面を開く経路はないので、出荷ビルドからは
到達できません。加えて、コードの照合はサーバー側の秘密値で行われ、登録は2台まで、
サーバー側の値を消せば即座に無効化できる設計です（docs/monetization.md）。

## このブランチで実施したこと

- **サーバーテストのCI化**：`tools/server-tests.sh` が entitlement のルールテストを
  実行した後、新しい Durable Object ストレージで `wrangler dev --local` を起動し、
  `test.mjs`（部屋・レート制限・部屋の期限切れ）と `test4.mjs`（versus 中継）を回す。
  `.github/workflows/server.yml` が server/ の変更ごとに実行。
- **依存の固定**：`wrangler` を `4.147.0` に固定し、`package-lock.json` を commit。
  CI は `npm ci`。
- **Godot スイート全体のCI化**：`.github/workflows/godot.yml` が push / PR ごとに
  `tools/verify.sh` 全体を実行。ゲート導入時点で既に落ちていたチェック（30件＋1-S の
  3件）は `test/known_failures.txt` に記録し、**新しい失敗だけ**で落とす。リストは
  減る方向にしか変えない（直ったチェックは verify.sh が「消してよい」と知らせる）。
- **性能ゲート**：`tools/perf_probe.gd --budget` が歩行中の draw calls と object 数の
  ピークを記録し、`tools/perf_budgets.cfg` の上限（現状値＋約10%）を超えたら失敗。
  どちらもシーンの性質でGPUに依存しないため、CI の xvfb＋ソフトウェアGLでも端末と
  同じ値になる（2回測定して完全一致を確認）。フレーム時間は表示のみで判定しない。
- **ストア経路の週次リハーサル**：`.github/workflows/store-rehearsal.yml` が毎週月曜、
  本番鍵・本番 EOS 資格情報で Play 用 AAB を作って破棄し、iOS は StoreKit・証明書・
  プロファイル・署名・App Store 用 export まで通して `app-store-connect publish` の
  直前で止める。
- **未知の enemy / gimmick type はエラー**：`LevelBuilder.ENEMY_TYPES` と
  `GIMMICKS` にない type は `push_error` し、全ステージの spec をロジックテストで照合。
- **診断コピーの伏せ字**：コピーされる報告では Product User ID・client id を末尾4文字に、
  ローカルIPを `<IPv4>` / `<IPv6>` に置き換える（画面表示はそのまま）。

### 作業中に見つかったこと

- **1-5 と 1-7 の draw calls が突出**：1-5 は 759、1-7 は 1,203（他のステージは
  およそ150）。予算で現状以上の悪化は止めたが、端末で重い可能性が高い。
  §7 の decor 分割と合わせて最優先で下げるべき。
- **ロジックテストの既知の失敗30件**のうち多くは、廃止されたゲージや、今はない
  レイアウト上のボタン（scope / ping / slot_2）を前提にした古いテスト。仕様として
  残すか消すかを決めて整理する（§6）。

## 1. 通信 version とコンテンツ version の分離

**現状**：`Protocol.VERSION`（20）が完全一致しないと接続を拒否する
（`host_session.gd`）。履歴を見ると 16（1-4 再構築）、19（1-8 追加）のように
コンテンツ変更でも上がっている。さらにステージは `Stage.Which` の整数値のまま
ハンドシェイクで送られる。Android 公開・iOS 審査中のような期間に、プラットフォーム
間で遊べなくなる。

**計画**

1. HELLO を拡張する：`protocol_version`（ワイヤ形式。互換が崩れたときだけ上げる）、
   `content_version`（情報用）、`features`（ビットマスク）、`stage_key`
   （"1-8" のような安定した文字列。EOS ロビーでは既に `STAGE_KEY` として使っている）。
2. ホストの判定を「完全一致」から「`protocol_version` が互換範囲内、かつ相手が
   `stage_key` のステージを持っている」に変える。持っていなければ、ステージ名を出して
   「相手のビルドにこのステージがありません」と表示する。
3. 新機能は `features` で交渉する（例：jump press count。片方が持たなければ旧挙動）。
4. 互換性テスト：v(N-1) の HELLO / snapshot のバイト列を fixture として保存し、
   現行のデコーダで読めることをロジックテストで確認する。

これは移行の1回だけ、旧ビルドとの互換を壊す（HELLO の形式が変わる）。次のストア提出に
合わせて入れるのがよい。実機2台での確認が必須。

## 2. Stage データの型付け

**このブランチ**：未知 type のエラー化と全ステージの照合まで実施。

**次の段階**：spec の**キー**の綴り違い（`"pahse"` など）も検出したい。
`from_spec` に既知キーの一覧を持たせ、未知キーを `push_error` する。そのうえで、
よく使う型（MovingPlatform, Laser, CaveEnemy など）から typed Resource
（`MovingPlatformSpec` 等）に移す。データファイルは Dictionary のまま書けるよう、
読み込み時に Resource へ変換する層を挟めば、既存13ステージを一度に書き換える
必要はない。

## 3. ビジュアル回帰テスト

**計画**：`tools/capture_stage_cards.gd` と各 `*_capture.gd` を基に、ステージごとに
固定の位置・カメラで数枚を撮る。基準画像を `test/visual/baseline/` に置き、CI
（xvfb＋ソフトウェアGLで描画は決定的）で比較する。判定は SSIM か、ブロック単位の
平均色差の閾値で行い、「どこが変わったか」の差分画像を artifact に残す。基準画像の
更新は意図した変更のときだけ、PR に差分画像を添えて行う。最終的な見た目の良し悪しは
人が判断し、この仕組みは意図しない破壊を拾う役に限る。

## 4. 出荷対象と実験対象の分離（要判断）

**現状**：`src/arena/`（コインバトル）はメニューから到達しない。1-B / 1-S /
Keeper / Workshop なども現在のメニュー（`StageCards`）にない。一方で verify.sh は
これらを検証し続けており、Runner・InputHub・ControlLayout など共有コードを変える
たびに影響を受ける。

**提案**：「今売る Kiki」を明文化する（co-op 1-1〜1-8、1台共有、EOS オンライン、
Versus 2v2 / 1v1 / FFA、IAP / フレンドパス）。それ以外は
- 残す価値があるもの → `experimental/` に移し、verify.sh では別ステップ（失敗しても
  出荷を止めない）にする、
- 戻す予定がないもの → 削除する（履歴には残る）。

どれを残すかは製品判断なので、オーナーの決定待ち。

## 5. ドキュメントの一本化

README・`docs/status.md`・コメント中の数値（ステージ数、draw calls、プロトコル番号
など）がコードとずれている箇所がある（例：`dist/README.md` は2ステージ時代の説明）。
変わる数値は `tools/` のスクリプトでコードから生成するか、テストで照合する。古い説明は
削除する。まず `docs/status.md` を「現在の真実」として整理し、他の文書はそこへの
リンクに寄せる。

## 6. Balance の整理

`src/autoload/balance.gd`（約33KB）を `RunnerTuning` / `GuardianTuning` /
`CameraTuning` / `NetTuning` / `VersusTuning` に分ける。同時に、廃止済みのゲージ
（`COST_PLATFORM = 0` なのにゲージ値を「互換のため満タンに保つ」コード）を削除し、
それを前提にした古いテスト（`gauge never goes negative`、
`host charged the gauge…` など）も一緒に消す。分割は機械的な置換で済むが、参照箇所が
多いので専用のブランチで1回で行う。

## 7. decor.gd の分割と重いステージの軽量化

`src/render/decor.gd`（720行）を `GreenfieldDecor` / `HorrorDecor` / `SeaDecor` …の
テーマ別 renderer に分け、`Stage` のデータファイルが自分の renderer を指す形にする
（§2 の Stage 表と同じ考え方）。その作業の中で、1-5（759 draw calls）と 1-7（1,203）
を他のステージ並みに下げる。下げた分だけ `tools/perf_budgets.cfg` の上限も下げる。

## 8. リポジトリ軽量化（要判断）

`dist/*.apk`（約60MB）は `.gitignore` 自身が「役目を終えた」と書いている。ただし
**ファイルを消してもリポジトリのサイズは減らない**（過去のコミットに残るため）。
減らすには履歴の書き換え（`git filter-repo`）と force push が必要で、既存の clone や
フォークに影響する。手順の提案：

1. 2つの APK を GitHub Release（例：`legacy-handoff`）に添付する。
2. `dist/README.md` と `docs/playtest.md` のリンクを Release に向け、`dist/*.apk` を
   削除する（作業ツリーが60MB軽くなる）。
3. 履歴からも消すかは別途判断する。

1 はリポジトリ管理者の操作が必要なので、このブランチでは実施していない。

## 9. LICENSE（要判断）

公開リポジトリだが LICENSE がない。この状態は法的には「All Rights Reserved」と
同じ扱いだが、明示した方が誤解がない。オープンソースにするのか、閲覧のみ可とするのかは
オーナーの判断なので、このブランチでは追加していない。

## 進め方

S 項目はこのブランチで済んだので、次は効果の大きい順に
**§1（通信互換）→ §7（重いステージ）→ §6（Balance と古いテストの整理）→ §2 → §3**。
§4・§8・§9 はオーナーの判断が先。
