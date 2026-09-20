# Kiki 現行対戦の1対1兼任対応・通信改善設計

## 0. この設計の前提

- 調査日: 2026-09-20。対象: `recovery/unified`。
- GitHubからfetchし、`59c47cc` から **`aeefa87a3b81d70c4a4b319c9414ef29dbfec80e`** へfast-forwardして調査した。
- **ユーザー確認済み: 1対1では各自がランナーとガーディアンを兼任する。** ガーディアンを取り除いたランナー対戦にしない。
- 基準は最新の `src/versus/`。以前の `docs/coin-battle-plan.md` の7枚・3分・小型アリーナ・4キャラクター案は採用しない。
- 今回は文書のみ。ゲームコードの変更、Godot・テスト・ビルドの実行、Actions・Codemagicの起動はしていない。以下は次の実装担当への指示であり、実装済み・実測済みという意味ではない。
- 回線の物理的な遅延をゼロにはできない。本設計の対象は、入力の取りこぼし、不要な待ち時間、古い状態の滞留、同期漏れ、回線悪化時の壊れ方。実際の端末・回線の遅延値は未測定で、数値は初期設計値と合格基準である。

**採用方針: 現在の遊びを維持し、2人の兼任モードを追加する。自分のRunnerは自分の端末で即時に動かし、ホストがコイン・対戦ダメージ・設置・試合進行を確定する。まず現行WebSocket経路の不具合を直し、実測してから通信方式の変更を判断する。**

## 1. 維持する現在のゲーム

| 項目 | 実際の実装と維持する仕様 | 根拠 |
|---|---|---|
| ステージ | 1-1全体と終端の接続階段。x=-1600〜17400、1周19000px。左右に周回できる | `versus_main.gd::_finish_world/_build_laps`、`versus_stage_data.gd` |
| キャラクター | 本編の `Runner`。地上移動、可変ジャンプ、三段ジャンプ、壁操作、しゃがみ、スライド、スプリント、グラウンドパウンド等を置換しない | `versus_main.gd::_build_runners`、`src/runner/runner.gd` |
| 勝利 | **現在所持しているコインが先に10枚に達したチーム** | `VersusRules.WIN_AT`、`VersusMatch._check_win` |
| コイン | 台帳は18枚。フィールド上3枚を目安に補充。45tickの補充間隔、600tickで未取得コイン再循環。放出により3枚を超えることはある | `versus_rules.gd`、`versus_match.gd::_top_up/_step_coins` |
| 戦闘 | 前方攻撃は発生8／持続4／硬直14tick。PvP被弾で1枚放出、死亡で全所持を返却する設計。実装の通知漏れは§2で区別する。既存RunnerのHPと被弾動作を使う | `VersusMatch`、`ArenaCombat`、`Runner.take_damage` |
| 復帰 | 72tick後、死亡位置の手前にあるチェックポイントから復帰。ランダム復帰に変更しない | `versus_main.gd::_apply_respawns`、`VersusStageData.respawn_for` |
| カメラ | 自チームのランナー追従。ミニマップに両ランナーと落ちているコイン | `versus_main.gd::_update_camera/map_marks`、`versus_hud.gd` |
| 既存オンライン | 2ランナー＋2ガーディアンの4役割。各Runner所有端末が自身の物理を処理し、ホストが試合を裁定 | `versus_roster.gd`、`versus_host.gd`、`versus_client.gd` |
| ガーディアン | **対戦の通信経路は足場・壁・自分の設置の取消のみ**。設置は両チームに当たり判定を持つ。全体上限12、超過で最古を除去 | `versus_command_router.gd`、`VersusHost.place_build/undo_build` |
| 能力の未対応 | 本編Guardianには狙撃・ワープがあるが、対戦routerはslot 3/4を拒否する。コメントの「全ツール」を実装済みと解釈しない | `Guardian._ready`、`versus_command_router.gd::request_use` |
| 通信基盤 | `/room4/<code>` のWebSocket中継。`/room/` の協力用経路と分離。実際には同じROOMS binding内の `v4:` 接頭辞で部屋を分離している | `server/signaling/worker.js` |

コイン位置の `_free_point()` は現在 `coin_points()` の先頭から探す。コメントの「中央から」と実際の順番は一致しない。今回これを新しいランダム配置や追跡ルールに変えない。同様に9対9で全18枚を保持すれば奪う必要がある状態は現ルールの帰結であり、勝手に追加コインや時間切れを導入しない。

## 2. 調査で判明した修正対象

下表はソース上で確認した構造的な問題。ユーザー端末での発生頻度や遅延への寄与率を測定したものではない。

| 優先度 | 確認事項 | 修正指示・根拠 |
|---|---|---|
| P0 | オンラインでも `VersusInput.poll()` が2つのhubへ物理キーの値を書き続ける。hubはscripted。対戦HUDにタッチ操作の描画がなく、攻撃もキーだけ | ローカル2人のキーボード入力とオンライン1端末の入力を分離。タッチstick値をゼロで上書きしない。`versus_input.gd`、`versus_main.gd::_physics_process` |
| P0 | ホストのhurtイベントが遠隔Runnerへ届かない。EVENTのenumだけあり送受信実装がない。client側はalive=falseしか適用せず、HP/速度は送信時に0を詰める | 命中→HP/ノックバック/放出を同じ確定イベントにする。現在はコインだけ落ちて身体が反応しない組合せが起き得る。`_apply_events/_apply_client_hits`、host/client/protocol |
| P0 | 遠隔Runnerのalive=falseをhostが採用しても `note_death()` を呼ぶ経路がない。環境被弾の1枚放出も対戦台帳へつながっていない | 生命世代とダメージIDを持つ通知、死亡遷移の一度だけの処理を追加。環境被弾と対戦被弾の重複も防ぐ。`VersusHost._on_input`、`VersusMatch.step/note_death` |
| P0 | 設置同期は配列の**個数だけ**比較。上限12で古い1個を消して新しい1個を作ると同数のため地形が更新されない | build_idとworld_revisionで差分適用。host上のRunner用地形も同じ問題。`_sync_builds/_sync_builds_from_snapshot` |
| P0 | 設置後のhost `_rebuild_world()` とclient `collision()` が `Stage.ground()` に戻り、周回階段・隣接周回の衝突矩形を失う | 初期生成・再生成・検証を同一の `VersusStageData` 衝突データ関数へ統一。Runner用地形とコイン用地形を一致させる |
| P0 | waiting表示はあるがhostは相手が来る前から試合を進める | 接続状態と試合状態を分離し、START確定まで得点・移動・能力を止める。`waiting()`、`VersusHost.step` |
| P0 | OVER中はsceneが早期returnしhost/client.stepが止まる。再戦はhost側だけtick/rosterを初期化し、clientは旧tick以下を破棄する | OVERでも通信ポンプを継続。match_epoch付き再戦と全員のreset ACK。`_physics_process/_restart_host`、`VersusClient._absorb` |
| P1 | 状態送信は毎physics tick、worldは30Hz。INPUTのtickはclient自身の観測tickではなく最後に受けたworld_tick。hostは順序・鮮度を確認しない | sample_seq、観測時刻、鮮度検査。姿勢30Hzと即時の操作イベントを分離。順序逆転を拒否する |
| P1 | 相手を毎physics tickで0.35 lerp。時刻バッファなし、速度・接地・HP・Runner stateの反映なし | 描画時刻ベースの補間と限定外挿。表示と裁定位置を別に持つ。単なる係数調整では直さない |
| P1 | WebSocketはUNRELIABLE指定を無視しTCPで送る。sendの結果・送信滞留を監視しない | 送信前に最新状態へ畳み込む。重要イベントは別管理。TCPへ投入済みの古いデータは取り消せない |
| P1 | requested seatが満席だと別席へ自動割当。sceneは要求した_seatで既にRunner/Guardianを作る。clientはhost以外からのsnapshotも検査しない | 明示的な権限割当・拒否理由・送信元確認。WELCOME確定後に操作所有者を設定 |
| P1 | peer-leftを無視し、BYEでも_reportedを残す。startでも_reportedをclearしない | 接続世代・heartbeat・タイムアウト・古い観測の破棄。停止した敵を永久に攻撃できる状態を防ぐ |
| P1 | 敵は各端末で生成・物理更新。versus snapshotに敵・弾・Clock同期がない | 下記の環境同期工程が必要。独立シミュレーションが一致すると仮定しない |
| P1 | コイン表示はcanonical座標のまま、Runnerはnearest_imageで表示 | 周回継ぎ目のコイン・設置・予告もnearest_imageで描画し、座標の世代を補間から区別する |

既存probeは台帳・座席・通信形式・ローカル実Runnerを別々に検証している。`versus_net_probe.gd` の合格だけでは、遠隔の実Runnerが被弾し復帰することやスマホ入力を保証できない。`VersusLoopback` の独立パケットlossも、実際のTCPで後続全体が待たされる状態とは異なる。

## 3. 1対1のゲーム仕様

### 3.1 参加単位と権限

ゲーム内の身体は今と同じ2体。ガーディアン用キャラクターを新しく出さない。

| room_mode | 人数 | A側の所有 | B側の所有 |
|---|---:|---|---|
| `DUEL_COMBINED` | 2 | peer AがRunner A＋Guardian A | peer BがRunner B＋Guardian B |
| `TEAM_SPLIT` | 最大4 | Runner AとGuardian Aを別peerが所有 | Runner BとGuardian Bを別peerが所有 |

論理seat 0/1/2/3は維持し、**1 peerが複数seatを所有できる**ようにする。兼任の権限maskはA=0b0011、B=0b1100。`seat_of(peer)` を唯一の権限根拠として使わず、`owns_seat(peer, seat)` を追加する。`actor_id` はRunner A=0/B=1、`team_id` も0/1、`peer_id` は接続、`seat` は操作権限。相互に代用しない。

DUELはhostがAの2役、参加者がBの2役を原子的に取得する。片方だけを割り当てない。3人目は試合に入れず「2人の部屋です」と返す。TEAM_SPLITでは同一peerの複数役取得を拒否し、既存の分担を維持する。

既存 `can_play()` は両Runnerがいればtrueで、Guardianは任意。TEAM_SPLITはこの互換性を残し、欠席ガーディアンがいる場合は両RunnerのReady画面に席状況を明示する。試合中に欠席席を埋める機能は初版に入れず、人数・役割はロビーで確定する。DUELは必ず2名の兼任で開始する。

### 3.2 スマホでの兼任操作

比較した方式:

| 方式 | 評価 |
|---|---|
| 完全な役割切替。Guardian中はRunner操作不可 | 止まる頻度が増え、走行・ジャンプの連続性を壊す。採用しない |
| 操作を全部常時表示 | 画面と右親指が混雑しやすい。既存sharedレイアウトをそのまま縮小しても解決しない |
| **Runner操作を常設し、建築パレットだけ開閉** | 選択と配置を分ける現在のGuardian操作を使いながら、左親指で移動を続けられる。採用 |

- 左: 今のスティック。上下入力によるしゃがみ・パウンド等を維持。
- 右: 今のジャンプ・スプリントに、独立した対戦攻撃ボタンと「建築」を追加する。ジャンプ長押しを建築や攻撃の長押しに転用しない。
- 建築をタップすると右上寄りに「足場／壁／取消／閉じる」の小パレット。**既存の移動・ジャンプ・スプリント・攻撃は押せるまま**。選択中の能力名を表示する。
- 足場か壁を選び、UI以外のワールドをタップしてその位置に設置要求。ドラッグ中はプレビュー、離して確定。選択は維持する。建築を閉じるとワールドタップは何もしない。
- 自動走行、自動ジャンプ、切替中の無敵・時間停止は導入しない。指を離した移動は通常の減速。ジャンプ指を保持していれば建築パレット開閉でreleaseを合成しない。
- 左の移動指を離さず右手で配置できる。空中でジャンプを押し続けながら配置するには別の指が必要になるが、通常操作を3本指必須にはしない。
- UIの指は開始時の所有先を固定し、ドラッグして別ボタンへ入っても操作を移譲しない。ボタン上で離した設置ドラッグは取消。パレットを開いたタップで同時に設置しない。
- フォーカス喪失・死亡・画面変更は保留配置と未消費edgeを破棄する。`release_everything()` がslot releaseで選択を残す経路も調べ、取消をcommitと扱わない。
- 専用 `versus_combined` レイアウトを `ControlLayout` に追加。協力プレイの `shared/runner/guardian` と保存設定は維持。基準タッチ領域48dp相当以上、重複なし、端末safe area内。描画・hit test・編集に同じ矩形データを使う。
- TEAM_SPLITはRunner用とGuardian用の対戦レイアウト。未対応slot 3/4を使えるボタンとして出さない。狙撃・ワープは将来の別工程であり、兼任の完成条件に紛れ込ませない。
- desktop兼任は既存p1移動・ジャンプ・スプリント＋F攻撃、1/2選択、マウス配置、建築UIと同じ取消操作。現在の1台2Runnerテスト用キーは別モードとして残す。

操作例: 左で走る→右で建築を開く→足場を選ぶ→穴の先をタップ→ジャンプ、が連続する。建築中にRunnerを止めるコードはない。「少し安全な場所で先に足場を置く」操作も成立する。

### 3.3 建築ルールを勝手に別物にしない

現行オンラインは足場・壁のサイズをBalanceから読み、全体12個のFIFO、設置者別の取消を使う。初版はこれを維持し、兼任でも専任と同じコマンドを使う。host本人だけ `Guardian.use_active()` の協力用実行経路に入れてはならない。

現行の対戦hostには協力用のゲージ消費・寿命・同時個数ルールが実装されていない。したがって今回、協力用ゲージをこっそり必須化しない。対戦HUDに減らないゲージを能力制限として表示することもしない。建築ゲージ導入やチーム別上限への変更はバランス変更として別に比較する。

必要な整合性検証は加える: slotは1/2のみ、有限座標、canonical x、kill_yより上、負サイズ不可、他のRunner身体内への埋め込み不可。誤タップの配置先はプレビューと同じワールド座標。配置可能範囲を新たに短くする改変は行わず、現在の自チーム追従カメラで見て指定できる操作を維持する。取消は同じGuardian seatの最後の現存build_idだけ。

初版は設置物の推測当たり判定を置かず、タップ直後の半透明プレビューと「配置待ち」で応答する。host受理時に実体化し拒否なら理由表示。未確定の床でジャンプを成立させる方式は、否認時に落下を取り消す大きな変更が必要なので避ける。

## 4. 接続・開始・再戦

メニューに「1対1（ひとりで両役）」「チーム対戦（役割を分担）」を追加。ホストが選択したmodeを部屋の唯一の正とする。参加者はコード入力後にmodeと担当を確認し、DUELで4席の選択UIは出さない。

状態機械は `LOBBY → COUNTDOWN → PLAYING → OVER`、通信途絶は `SUSPENDED`、回復不能は `ABORTED`。`VersusMatch.Phase` とは別のsession状態で開始前の試合処理をgateしてよい。

1. WELCOMEでmode、roster_revision、権限mask、match_epoch、ルール版、ステージ版を受け取る。承諾前に入力所有者を確定しない。
2. 初期世界を全chunk受信→stage生成完了→READY。両Runner所有者がReadyで、着席済みGuardianもReadyならhostが3秒COUNTDOWNを送る。
3. STARTはhost_tick付き。カウントダウン中は両Runnerを開始位置で保持し、HP/コイン/能力/環境時間を初期状態にする。接続待ち時間で有利にならない。
4. OVERでも受信・heartbeat・結果再送は継続。両Runnerが「もう一度」を選択し、着席済みGuardianが確認したら新epochで初期化する。
5. rosterを維持して新epochに移り、台帳・位置・HP・builds・combat・入力edge・重複除去表・補間履歴・観測をreset。新しい初期snapshotをACKしてから次のCOUNTDOWN。旧epochはtickが大きくても破棄する。
6. 「やめる」は通常メニューへ戻る。スマホでR/Escやアプリ終了を要求しない。

部屋番号はpanelとsceneで二重生成しない。既存 `_open_link(true)` はLaunchから渡された番号を再生成するため、生成元を一つにする。relay peer index 0をhostとする既存の前提は維持し、host消失後に0番に入り直した別人をhostと認めない。初版にホスト移譲を入れず、host切断は明示的に試合終了・無効とする。

## 5. 同期の責任と被弾の修復

### 5.1 採用する同期モデル

全面的なhost物理＋rollbackへの置換は、Runnerの内部状態・衝突・敵・移動床まで再現が必要になり、現在の操作感を壊すリスクが大きい。まず現在の**所有端末で移動、hostで裁定**を保つ。ただし位置とHPの両方を毎回clientの自己申告で上書きしてはいけない。

| 状態 | 所有・確定者 |
|---|---|
| 自分の移動・ジャンプ・接地・入力 | Runner所有端末。通常snapshotで巻き戻さない |
| 相手の見た目 | 観測履歴から描画専用に補間。判定用位置にlerp値を使わない |
| コイン状態・勝敗 | hostだけ。clientの予告演出に取得確定や得点を含めない |
| PvP命中、HPの確定、無敵期限、死亡世代、復帰 | host。自端末の身体には確定結果を一度だけ適用 |
| 環境接触による被弾の即時反応 | 所有端末で予測し、後述の通知でhostが台帳とHPを確定 |
| 設置、取消、world_revision | host。hostの兼任操作も同じ検証関数を通る |

友人同士の対戦を対象とする現行の信頼モデルを維持する。位置自己申告を残す以上、改造clientへの完全な不正対策は完成しない。これは移動入力を遅くする理由にはせず、ランキング等を足す際の別判断とする。

### 5.2 ダメージ・死亡・復帰の契約

新設 `VersusRunnerAdapter` がactor_id、life_id、直近damage_revision、環境被弾連番、最後に適用したhost_event_idを持つ。既存Runnerの移動計算には触らない。Runnerからの通知が必要ならactorを識別できるinstance signal/限定hookを追加し、協力時の挙動は既定のままにする。グローバル `Events.runner_damaged(hp,max)` だけでは2体の識別ができない。

**PvP:** hostは既存の8/4/14tick攻撃と同時命中収集を維持。命中時に一つのtransactionとしてHP、無敵期限、1枚放出、死亡なら残りの返却を更新し、`HIT_CONFIRMED(event_id, actor_id, life_id, damage_revision, hp_after, dir, host_tick, invuln_until)` を送る。host Runnerにも同じイベント経路を使う。被弾予定をclientが反映する前に、古いcan_act/invulnerableを読み戻して再び命中させない。

- clientは確認イベントを同じlifeに一度だけ適用し、Runnerの既存被弾動作・ジャンプ解除・連鎖解除を使う。hp_afterは差分減算ではなく確定値。receipt ACKを返す。
- `take_damage()` はローカル無敵だとreturnする。確定イベントをただ呼ぶだけでは修復できない。adapterから「既存の被弾遷移を確定値で適用する」小さな入口を設ける。移動モデルの書換えや内部timerの無秩序な直接代入はしない。
- snapshotにもlife_id、damage_revision、hp、dead、無敵期限、last_event_idを載せる。イベント未適用ならsnapshotだけでHP差分を引かず、欠落を要求し、必要ならcheckpoint状態で復元する。
- life_idが進んだ後に来た古いHIT/DEATHは身体へ適用しない。ACKだけ返す。重複でノックバックやコイン放出を再生しない。

**環境:** 敵・弾・トゲによる被弾は所有端末で即時に既存反応を予測し、`ENV_DAMAGE_REQUEST(request_id, actor_id, life_id, base_damage_revision, observed_tick, source_id/kind, position)` を重要経路で送る。host自身の環境被弾も同じ関数へ投入する。

- hostは権限、世代、重複、同じ無敵期間の被弾を確認し、受理時に1枚放出とHPを確定。落下・即死はDEATH_REQUESTへ分ける。拒否はHP/生命状態の確定値を返信する。
- 各actorのダメージはhost受信順で直列化し、そのtickの同時PvPは従来どおり両者へ適用。環境予測とPvPが競合したらhostのdamage_revisionで収束させ、同じ無敵期間に二重徴収しない。初版は過去の物理全体を巻き戻さない。
- 予測済みrequestが承認された際はHP/台帳を確定するだけで、ノックバックをもう一度掛けない。別のPvPイベントを同じものと見なさない。
- 予測被弾が拒否された場合は確定HP・無敵期限へ戻す。既に進んだ通常移動は巻き戻さない。予測で死亡まで進んでいた場合だけRESYNCで同じlifeの安全な位置・状態を復元する。応答がないまま勝手に次lifeを開始しない。
- 復帰時刻と場所はhostが `death_tick + 72` と `respawn_for` で決め、RESPAWNイベントを送る。ローカルで秒読み表示はできるが、hostが決めたlife_idに一度だけrespawnする。
- 入力観測のalive=falseも、重要DEATHの欠落検出に使う。alive true→falseを検出したら問い合わせ／照合し、コインを保持したままの死亡を残さない。古いalive=trueで復活しない。

この工程の完成条件は、実際の2つのsceneでAがBを殴る場合とBがAを殴る場合が同じHP・放出・硬直・復帰になること。台帳だけの一致で完了にしない。

## 6. 通信遅延を増やさないデータ処理

### 6.1 フレームの順序

現行sceneはphysics priority=100でRunner後に `input.poll()` を行う。次の責任分割を行い、1frame余分に待たせない。

1. `_input/_unhandled_input` で指の状態とedgeを記録。
2. Runnerより前のphysics処理でローカル入力をhubへ確定し、受信済み重要イベントを反映。
3. 既存Runnerを60Hzで更新。
4. 更新後の姿勢をsample化。hostは受信観測と自身の観測で試合を1tick進め、結果を生成。
5. 送信scheduler。描画は `_process(delta)` で補間・HUD・camera更新。

socketはrender frameでもpollし、結果をsessionの受信箱へ入れる。physicsから二重に同じイベントを消費しない。physicsが追いつこうと複数tick回ってもネット送信をその回数だけburstしない。

### 6.2 姿勢・操作・確定結果を分ける

| 種類 | 初期頻度／扱い | 必須情報 |
|---|---|---|
| Runner sample | 活動時30Hz、完全静止時10Hz。最新未送信1件だけ保持 | sample_seq u32、自身のlocal_tick、推定host観測tick、actor/life、pos、実velocity、facing、Runner state、接地、可動状態、反映済event_id |
| STRIKE_REQUEST | 押下edgeですぐ送る。姿勢送信周期を待たない | request_id u32、actor/life、観測tick、姿勢参照、方向。再送でも1回のみ発火 |
| BUILD/UNDO/ENV/DEATH | 即時、ACK対象、順序を保持 | request_id、権限seat、epoch、参照world/damage revision、能力/座標/対象 |
| WORLD_SNAPSHOT | hostから30Hz。状態は最新を優先 | host_tick、snapshot_seq、roster/world revision、全18コイン、2Runnerの確定状態 |
| WORLD_UPDATE | 設置変更時即時。定期snapshotにも全設置を含め復元可能にする | world_revision、build_id、seat、rect、追加/除去、依存コマンドID |
| HIT/DEATH/RESPAWN/RESULT | 発生時即時。event_idで順序適用・ACK | epoch、host_tick、各対象の世代と確定状態 |
| PING/PONG | 1秒ごと。試合停止中も送る | nonce、送受信monotonic時刻、host_tick |

STRIKEをsample coalescingで消さない。旧u16 strike_seqのwrap判定問題も新u32 request_idで解消する。長押しによる自動連打は追加しない。移動packetの名称INPUTを残しても「ボタン再演用ではなく位置観測」であることを明記する。

### 6.3 時計・補間・古い観測

- RTTはrelayまでではなく相手sessionから返るPING/PONGで測る。offsetは4時刻交換の低RTTサンプルで推定する。非対称経路では片道遅延は正確に測れないため、UI/記録でRTTと推定を区別する。
- 補間履歴はactorごとにhost時間へ写像したsampleを16件以上保持。初期表示遅延50ms、到着jitterを見て33〜100ms内で緩やかに調整する。増やしたバッファをpingが下がっても永久に残さない。
- hostが中継する各actorにも**元のsample_seqと観測時刻**を残す。snapshot送信tickで古い観測を新しく見せない。client→host→Guardianの2区間の遅延を時計推定とageに含める。
- 描画時刻を挟む2観測で位置を補間。状態・向きは対応時刻のものを使う。速度は必ず実測値を送る。相手表示に既存0.35 lerpを重ねて二重に遅らせない。
- 次sampleがなければ最大50msだけvelocityで外挿し、その後は停止表示。壁を跨いだ外挿は地形でclampする。250ms以上観測が古ければ「通信待ち」とし、無限に走らせない。
- canonical xは一度 `nearest_image` で連続座標へ展開してから補間し、最後にcameraに近い周回へ表示する。life変更・respawn・明示teleportは履歴を切る。継ぎ目の移動を距離240pxという条件だけでrespawn扱いしない。
- hostの裁定は表示位置と別。相手位置の観測が新しい間は同じく最大50msの外挿で現在時刻へ近づけるが、外挿だけで壁の向こうの攻撃/取得を成立させない。250ms staleのRunnerによる攻撃・取得は保留し、500msでsessionをSUSPENDEDにする。
- 攻撃判定の全面rewindは初版に入れない。遠隔STRIKEの到着とhostの即時入力の差は残る。自分の攻撃予告は即時表示しても、命中とコイン取得はhost確定を待つ。ホスト有利の度合いをA/B入替試験で測り、必要なら次工程で両者を同一時刻の履歴で裁定する方式を比較する。過去位置の相手だけを戻してコイン・壁は現在のまま判定する半端なrewindはしない。

### 6.4 WebSocketでできる対策と限界

現行経路はTCPなので、1つの再送待ちで後続の状態も遅れる。`UNRELIABLE` のラベル変更だけでは解決しない。[GodotのWebSocket説明](https://docs.godotengine.org/en/4.4/tutorials/networking/websocket.html)もこの特性を説明している。

- 送信前の状態キューは宛先・種類・actorごとに1件。重要イベントを先に送り、snapshotは最新だけ送る。重要イベントには上限128件、2秒のACK監視を置き、溢れる前にSUSPENDEDへ移る。捨てて試合を続けない。
- `send()` のErrorを処理し、成功前に重要イベントを送信済みにしない。Godotの `get_current_outbound_buffered_amount()` と最古未ACK時刻を記録する。まず滞留4KiB以上または200ms以上で通常状態送信を15Hzへ落とし、未送信sampleを畳み込む。回復後2秒安定したら30Hzへ戻す。
- TCP投入済みのbyte列、OS・中継側の滞留はそのAPIだけで全て把握・削除できない。受信snapshotの推定ageも監視し、古い全snapshotを順番に描かず最新へ進める。イベントは順に一度だけ処理する。
- `set_no_delay(true)` は確認項目だが、Godot 4.4の説明ではNagle無効が既定。これを「未設定だったから遅い」と決めつけたり、改善完了としない。[WebSocketPeer API](https://docs.godotengine.org/en/4.4/classes/class_websocketpeer.html)
- 通常状態の受信処理は1render frameあたり目標1ms、上限2msで分割。重要イベントは落とさず別queue。200msを超える受信遅れは計測して停止判定へ回す。細切れdecodeで古い状態を何秒も再生しない。
- 共通の1本のTCP接続では重要イベントも既送信データの後ろで待つ。優先queueは投入前にだけ効く。これ以上のloss耐性が必要なら後述のtransport工程へ進む。

帯域目安: 現形式のworldはheader10 + Runner12×2 + coin6×18 + build9×12 = **250byte payload**、中継envelope2byte。30Hzでhost上り約7.6KB/s（TLS等を除く）。新形式は通常snapshot768byte以下、1frame1170byte以下を目標とし、上限をencode/decode双方で検査する。小さいpacketでも秒間通数と遅延は別問題なので、Hzを上げるだけの解決をしない。

## 7. 地形・環境と同期の境界

### 7.1 設置と周回

- `build_id` はepoch内で単調増加。world_revisionは追加・取消・FIFO除去ごとに増える。置換は「旧id除去＋新id追加」の原子的batch。
- clientはsnapshotの個数が同じでもrevisionが変われば適用する。順序逆転・欠番は全設置snapshotを要求。
- 衝突形状の削除追加はphysics安全点で行う。`queue_free()`待ちの旧shapeと新shapeが一時的に重なってRunnerを押し上げないよう、旧shapeを先に無効化して入替える。
- 周回継ぎ目付近の設置はcanonical形状と±LOOP_SPANの必要なimageを物理・描画双方に生成する。collision queryも同じデータを使用。途中で `Stage.ground()` だけに戻らない。
- hostとclientで適用時刻差は残るため、world_revision ACK前の新しい床上を根拠に遠隔Runnerを不正移動と判定しない。配置要求はそのrevisionを参照する。
- 自分の身体へ新規壁を食い込ませる設置はhostで拒否。遅延中に移動して重なった場合は対戦adapter内で最小の安全押出しを行い、押出し距離を記録する。通常移動へ定常的な補正を入れない。

### 7.2 既存の敵・弾・移動床

`LevelBuilder` は敵へ安定したnet_idを割り当てるが、現在のversusはそれを同期していない。`Walker._physics_process` は各端末で物理を積算し、接続時刻差や設置物によって経路が分かれる。これを回線の遅さと混同しない。

環境同期は今回の通信改善の独立工程にする。1-1の敵やトゲを削除して解決しない。

- hostが敵のHP・死亡・弾生成の正を持つ。clientの敵はnet_idによるproxyとし、独自に弾を生成しない。安定IDは配列indexや現在位置にしない。
- snapshot対象は**両Runnerの周囲の和集合**。協力用の1Runner基準をそのまま流用しない。最初は各Runnerから1400pxを候補範囲とし、弾速度と最大受信遅延を含めて画面外生成余裕を検証する。範囲退出・死亡は明示し、古いproxyを残さない。
- 環境snapshotは10〜15Hz、敵/弾のID・pos・vel・state・phase、重要な生成/死亡はイベントで送る。768byteに収まらなければtick/revision/chunk番号を付けた別ENV_SNAPSHOTに分割し、世界snapshotを巨大化しない。
- 時計駆動の移動床・レーザーはepoch起点のhost clockへ同期。接地判定用の床と描画用の床を別の時刻に動かさない。既存Clock設定を対戦入場時に保存し、退場時に戻す。協力sessionのClockを恒久変更しない。
- clientが見えている敵proxyへ接触した反応は§5のENV通知を使う。hostは観測tick周辺の短い敵履歴（初期250ms）とsource_idで妥当性を確認する。これより古い接触を延々と後払いしない。固定トゲ・kill planeはStageデータで検査できる。
- host側proxy Runnerの環境hurtboxは無効化し、所有者だけが接触通知を作る。敵死亡によるglobal signalを他方RunnerのHPとして扱わない。

初期1v1操作試験は現在の環境実装で行えるが、オンライン品質改善を完了扱いするにはこの工程と実機回帰が必要。未同期の環境を「同じseedだから一致」として出荷条件から外さない。

## 8. メッセージ・権限・切断の実装契約

### 8.1 Protocol v2

versusだけVERSIONを2へ。協力用 `src/net/protocol.gd` と `/room/` は変えない。

共通header: `kind:u8, version:u16, match_epoch:u64, message_seq:u32`。epoch未取得のHELLOだけepoch=0。全てlittle endian。接続ごとのgenerationはsessionで保持し、異なるgenerationのinboxを流用しない。

新規種類: `HELLO/WELCOME/REJECT/ROSTER/READY/START/REMATCH/PAUSE/ABORT`、`RUNNER_SAMPLE/STRIKE_REQUEST/GUARDIAN_COMMAND/ENV_DAMAGE_REQUEST/DEATH_REQUEST`、`SNAPSHOT/WORLD_UPDATE/ENV_SNAPSHOT/CONFIRMED_EVENT/ACK/RESYNC/PING/PONG`。

- WELCOME: mode、seed、stage/rules version、seat mask、roster、epoch、現在session phase。REJECTはFULL／VERSION／SEAT_TAKEN／MODE等の理由を区別する。
- commandにseatを書くが、権限はhostのmappingで検証。DUELのRunner seatからGuardianを偽装するのではなく、自分が所有するGuardian seatで送る。
- clientはWELCOME・snapshot・確定イベントの送信元がhost peerであることを確認。hostのepoch確立後は、他epochのSTART以外を採用しない。新epoch STARTもrematch合意とhostからの遷移に限る。
- byte長不足、未知enum、actor数>2、coin数>18、build数>12、非有限値、範囲外seat、余剰byteをdecode前後で拒否。可変長配列の前に残りbyteを検査する。
- seqはu32の半周比較を使い、到着順の古い観測を破棄。request重複はactor/seat＋epoch＋request_idで判定。再送は同じIDを使う。
- 重要イベントACKは累積event_idと欠番要求。hostは各peerの未ACKログを保持し、500ms超で同じIDを再送。ただしTCPが滞留しているときに再送stormを作らない。state修復は全snapshot＋event watermarkで原子的に行う。
- 全状態修復はepoch、host_tick、event watermark、roster、全Runner生命状態、台帳、設置、環境revisionを同じcheckpoint_idで束ねる。複数chunkは全件揃ってから切り替え、2秒以内に揃わなければABORT。旧イベントを半分適用した世界へ新台帳だけを継ぎ足さない。
- 1v1の同一接続から移動と能力を送る。2役のためにWebSocketを2本張らない。hostの自分へのcommandもloopback同等の処理関数へ入れ、ネット往復は不要。

### 8.2 切断・バックグラウンド

- monotonic時計で「最後の有効通信から何ms」を計測。scene tickが止まっている端末を正常接続と見なさない。
- 250ms staleで表示を停止／通信表示、500msでhostはSUSPENDEDを通知して裁定を止める。clientはhostから500ms無通信ならローカル入力を解放し、世界を止めて同期を待つ。止まる前の短い予測位置差は復帰時に修復する。
- この停止は演出ではなくsession gateで、Runner・環境・coin・combat timer全てに適用する。socket/PINGと復帰UIは動くようにする。SceneTree全体をpauseして通信まで止めない。
- 初版は切れたsocketの途中復帰を自動実装しない。同一socketの一時停滞は2秒以内に全状態照合→ACK→1秒カウントで再開。2秒超の継続停止かsocket閉鎖で試合を無効終了し、部屋へ戻す。競技ペナルティは導入しない。
- host退場はhost migrationをせず無効終了。残ったpeerがindex 0を引き継いでも旧試合の正にはならない。将来resumeを足すならランダムresume tokenと席予約を実装し、現在の短いcidや「最小空きindex」を本人確認として使わない。
- BYE/peer-left/終了時はそのpeerの観測、保留commands、入力、権限をclearする。再戦でも `_reported/_since_snapshot` をresetする。

## 9. 通信方式の比較・費用

| 案 | 判断 |
|---|---|
| 現行WebSocketを修復 | 依存と接続方法を維持して上記の確定バグを直せる。**今回の最初の実装対象** |
| WebRTC等の順序待ちを避けられる状態チャネル | TCP再送の影響を減らす候補。ただしnative Android/iOS対応、NAT通過、relay fallback、保守と費用の検証が必要。今回の文書を理由に即移植しない |
| 専用常駐ゲームサーバー＋全物理権威 | 不正耐性・共通時刻の裁定には有力だが、運用費とRunner再現範囲が増える。今回の条件には過大 |

現在のhost方式とCloudflare中継を維持すれば、新しい常駐サーバー契約は不要。ただし全packet中継のため、無料枠を超えても費用ゼロとは保証しない。実際の契約プラン・usageを未確認なので料金額を断定しない。[Durable Objectsの公式料金・無料枠](https://developers.cloudflare.com/durable-objects/platform/pricing/) を運用前に確認する。

計測で「同期漏れを直してもTCPの200〜500ms以上の停滞が頻発」が残る場合はtransport比較試作へ進む。合格条件は同じ端末・回線でsnapshot ageのp95/p99と停止回数が改善し、接続成功率と継続費用を悪化させないこと。将来のUDP系経路でも重要イベントのACKと状態修復、WebSocket fallbackを残す。利用者にポート開放を必須にしない。

## 10. 変更箇所と実装順

| 工程 | 対象 | 完成条件 |
|---|---|---|
| 0. 計測・再現 | `versus_host/client/ws_transport`、対戦debug overlay、既存probeの拡張 | RTT、sample age、ACK待ち、send buffer、physics/render時間が区別できる。P0の再現ケースが失敗を捕捉する |
| 1. 同期の正しさ | protocol v2、Runner adapter、host/client、match、world revision | 遠隔被弾・死亡・全返却・再戦・同数build置換・周回地形の同期が成立。まだ移動Balanceを変更しない |
| 2. 兼任とスマホ | roster権限、Launch/Panel/Main、対戦input/UI/router | 2台で両者が動きながら足場・壁を使える。TEAM_SPLITと協力操作も継続する |
| 3. 表示と滞留 | 姿勢履歴、scheduler、重要queue、clock、suspend | 正常回線で不要な表示遅れを抑え、TCP停滞後に古い世界を長時間再生しない |
| 4. 環境同期 | versus専用環境adapter、enemy ID/弾イベント/Clock接続 | 1-1全周で両画面の敵・床・被弾が一致し、2人が離れても破綻しない |
| 5. 実機受入 | 2台・4台、Android/iOS、Wi-Fi/モバイル | 下記基準の計測結果を文書化。必要時だけtransport試作へ進む |

具体的なファイル責務:

- `src/versus/net/versus_roster.gd`: modeと複数seat所有、空席fallback廃止、ready。
- `src/versus/versus_launch.gd`、`src/ui/versus_panel.gd`: mode・ロビー・拒否理由・兼任表示。
- `src/versus/versus_main.gd`: input provider選択、session gate、adapter接続、カメラ・周回描画。ここへ全netcodeを集めない。
- `src/versus/versus_input.gd`: ローカルキーボード用を明確化。オンラインは単一hubを使う専用input adapterへ。使わないhubのtouch処理を止める。
- `src/versus/versus_hud.gd` と対戦用controls: スコア/ミニマップを維持し、タッチ・待機・再戦を追加。共通HUDを丸ごと重ねて協力用イベントを二重購読しない。
- `versus_command_router.gd`: client専用参照をsession interfaceへ替え、hostローカルも同じコマンド契約へ。未対応slotの拒否signalは `Events.ability_refused(slot, reason)` の実宣言と合わせる。
- `src/versus/net/versus_protocol.gd`: v2、長さ検証、epoch、ACK、確定イベント、姿勢と生命状態。
- `versus_host/client.gd`: 権限、phase、鮮度、ダメージとworld裁定。旧HPゼロplaceholderを廃止。
- 新設候補 `versus_runner_adapter.gd`、`versus_environment_sync.gd`、`net/versus_pose_buffer.gd`、`net/versus_send_scheduler.gd`: 別責務として小さく保つ。汎用ネットフレームワークへ拡大しない。
- `versus_stage_data.gd`: 周回衝突矩形の唯一の生成元。
- `server/signaling/worker.js`: まず経路を維持。必要なpeer識別付き通知と旧host接続の検出を対戦経路に限定して検討。relayでゲームルールを処理しない。
- `src/runner/runner.gd`、`src/input/*` の共有変更は限定hookと追加レイアウトのみ。旧協力経路が同じ結果になることを確認する。`src/arena` の移動実装へ置換しない。

各工程は独立してレビューし、P0修正とゲームバランス調整を同じ変更に混ぜない。初期プロトタイプの最小単位は「同じ1-1で2台が両役を持ち、走る・設置・相互被弾・死亡・復帰・勝利まで1試合」であり、新しい専用ステージではない。

## 11. 検証計画と完了判定

以下は**次回の実装時に行う試験**。今回実行したという記録ではない。

### 11.1 必須の機能試験

1. DUELでA/Bにmask 3/12、3人目拒否、敵seat偽装拒否、slot 3/4拒否、host以外の確定snapshot拒否。TEAM_SPLITの既存4役・任意Guardianの明示的開始も確認。
2. 待機2分で0対0・初期位置。開始時刻を揃え、ホストの先行取得なし。参加時刻差で敵巡回や床phaseがずれない。
3. 実scene2つで相互に3回以上攻撃し、両方向ともHP・無敵・硬直・1枚放出が一致。同時攻撃は相打ち。環境被弾とPvPの同時発生でも重複徴収なし。
4. 遠隔Runnerのトゲ・落下・HP0で全所持返却。復帰life更新後に遅着hurt/deathを注入して再死亡・再放出しない。
5. build上限12→13個目、同一snapshot間に取消＋追加、同数で位置変更を行い、host/clientの描画と物理とコイン衝突が一致。
6. 周回継ぎ目を両方向からスプリント・ジャンプで通過。コイン取得・攻撃・設置・取消・cameraが継ぎ目で途切れない。connector設置後にも床がある。
7. 10枚勝利が全端末へ届き、OVER後も通信継続。連続3試合の再戦でtick拒否・残存build・旧input暴発なし。
8. マルチタッチ: 移動＋ジャンプ長押し＋パレット開閉、移動＋設置、配置ドラッグ取消、画面回転/バックグラウンド、UI越しタップ。2役hubの二重入力や隠れたボタンの反応なし。
9. 協力プレイの地上／空中／壁／三段／パウンド／移動床／Guardianの既存能力、保存済タッチ設定、協力ネットのsnapshotと部屋2名制限を回帰。

### 11.2 通信試験を実装と合わせる

- 既存 `test/versus_probe.gd`、`versus_net_probe.gd`、`versus_play_probe.gd`、`versus_ws_probe.gd`、`server/signaling/test4.mjs` を拡張する。既存probeの文章上の期待値が旧仕様なら更新理由を記録する。
- `VersusLoopback` に**TCP相当のFIFO停止→まとめて再開**と帯域制限モードを追加する。独立loss/reorderは将来transportと受信ガードの試験用に残す。WebSocket自体が普通にpacketを飛ばすという試験にしない。
- RTT 0/40/100/200ms、jitter 0/10/30ms、TCPの200/500/1500ms停滞、10〜30KB/s帯域制限、同時join、重複event、短いpacket、seq wrap、epoch変更、host落ち、バックグラウンドを検証する。
- 回線試験は値の意味を明記し、片道50msをRTT50msと記録しない。実Cloudflare経由と同一LAN対照を同じ端末で比較する。

### 11.3 初期の品質合格基準

| 指標 | 目標・測定方法 |
|---|---|
| 自分の入力 | 入力記録→Runner消費は1physics tick以内。RTTを加えない。タッチから画面の測定は端末frame時間も別記 |
| 通常回線の相手表示 | RTT≦100ms、jitter≦10ms条件でsample age p95≦150msを目標。0.35 lerpの追加遅れなし。host→clientとclient→hostを別記 |
| 建築要求→確定 | 同条件でp95≦RTT+2physics tick+1render frame。ghostの即時表示を確定時間に混ぜない |
| 命中通知 | hostの命中確定→所有者適用を測り、攻撃発生8tickと通信時間を分離。重複適用0件、host/client交換時の差も記録 |
| 滞留回復 | 200ms停止が解消後、250ms以内を目標に最新状態へ追いつく。何秒も過去を再生しない。500ms以上は停止UIへ |
| 一致 | コイン総数18保存、所有者・勝敗・HP・life・build revisionが最終ACK後に一致。幽霊壁・死亡者の所持残留0件 |
| 処理負荷 | 60Hz端末でphysics frame p95≦16.7ms、ネットdecode/scheduler追加p95≦1msを目標。30Hz端末でも速度やtimerが倍化しない |
| 長時間 | 2台で20分・再戦3回、4台で20分。queue/履歴メモリが上限内で安定し、シーン退出後の購読・socketが残らない |

基準未達を「スマホだから」で打ち切らず、CPU frame時間、回線RTT、sample age、イベントACK時間、TCP滞留に分解して対策する。どの変更でどの指標が改善したかを測り、**実機計測なしに『ラグは直った』と完了報告しない**。

## 12. 次の実装担当への禁止事項

- 1対1をRunnerだけに変更しない。ユーザーは両役兼任を明示した。
- 1-1を小さな対戦アリーナに置換しない。コイン10枚先取・周回・チェックポイント復帰を変えない。
- Runnerの加速度・重力・ジャンプ値を通信修正の名目で調整しない。
- 未同期の敵・能力を「対応済み」と記載しない。slot 3/4の対戦対応を無断で完成範囲へ増やさない。
- 移動をサーバー返答待ちにしない。逆に被弾・得点・設置確定を全clientの独立判断にもしない。
- 文書の初期数値を実測結果と扱わない。既存probe合格だけでスマホの通信品質を保証しない。

この文書の納品は設計の完了であり、通信不具合の修正完了ではない。実装はユーザーが次工程を依頼した際に、上記の順序で行う。
