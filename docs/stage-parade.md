# Stage 1-9 — THE TRICKSTER PARADE

2026-10-09. Development starts from public `origin/main` at
`ff1607e1274640c09fb88399d9c79a36b798b67d`, after fetching and confirming
HEAD and origin/main are synchronized. The outer legacy checkout is preserved.

1−9はプロモーションのための短い「からくり劇場」。明るい珊瑚色、青緑、真鍮の
配色に、巨大な仕掛けと72体の機械の小鬼を組み合わせる。ステージ選択の9枚目に
追加し、無料で選べる。既存のステージIDを変えず、末尾にPARADE=14を追加した。

## 驚きを重ねる構成

| 場面 | プレイヤーの予想と、その後の出来事 | 対応するゲーム内操作 |
| --- | --- | --- |
| 偽ゴール | 旗の付いた笑顔の門へ進むと、門が巨大な口になって噛む | 門の琥珀色の照準を射撃すると口が開いたままになる |
| 第一陣 | 門の先へ進むと、左から36体が追ってくる | 上の足場へ逃げ、ハンマーの支点を射撃する |
| 大群の処理 | 停止していた巨大ハンマーが振り下ろされ、敵がまとめて倒れる | 一度の射撃で繰り返し動く。主人公も打撃域を避ける |
| 床の裏切り | 普通の劇場の床が、乗って0.45秒後に崩れる | 相棒が下に足場を描き、受け止めて射出する |
| 第二の門と第二陣 | さらに大きな口が開き、今度は右から36体が来る | 門を射撃し、上の避難場所と二つ目のハンマーを使う |
| 本物のゴール | ゴールは最後の空中の島にある | 昇降床と描いた足場から射出し、島へ着地して旗に触れる |

ゲームの既存能力（描画、射撃、射出）、敵の被害・死亡イベント、チェックポイント、
ゴール処理を使う。敵の描画を消すだけの大量撃破は使わない。死んだ小鬼の絵が回転して
飛ぶ演出は、実際の敵死亡イベントから発生する。敵数が多い場面でも破片は40体分を上限にする。

口とハンマーの動き・危険な時間はClock.tickから決まる。スイッチの起動には既存の
SWITCHイベントと再接続時の再送を使い、移行用状態に敵の方向を含める。プロトコルは28。
噛みつき中は継続した接触も調べ、口の中で立ち止まっても危険になる。

## アセットを作ってから実装

組み込みのimage_genで、背景、4コマの小鬼、3状態の口の門、床、巨大ハンマーの
5種類を生成し、`assets/stage_1_9/`へ保存してから実装した。
全プロンプトは同フォルダの`prompts.json`、利用方法は`ASSETS.md`。
PNG原本を保持し、Godotのテクスチャ領域で余白やアトラスのコマを読む。
敵・門・床・ハンマーは本物のアルファを持つ。背景は不透明。
大型画像5枚は1−9を組み立てるときに読み込み、先行ステージの起動では読み込まない。
選択カードの`assets/menu/card_1_9.png`は実ゲーム録画から取得した画面。

## 再現と検証

Godot 4.7.2でインポートし、次を実行する。

```powershell
& $godot --headless --path . --fixed-fps 60 test/parade_stage_probe.tscn
& $godot --headless --path . --fixed-fps 60 test/stage_menu_probe.tscn
& $godot --headless --path . test/check_scripts.tscn
& $godot --headless --path . --fixed-fps 60 test/run_tests.tscn
```

専用プローブは静止した主人公への噛みつき、ネイティブ射撃の軌跡、第一陣だけの起動、
大群の撃破、安全な退避場所、ホスト移行、スイッチ再送、床の崩落、実際の足場救出、
リトライでの再構築、射出から本物のゴールまでを確認する。`tools/verify.sh`のCI検証に登録済み。

既存のインポート設定583ファイルは今回の作業開始時の状態を保存する。
Godotが再生成した既存設定だけを復元して、元からあった変更を維持する。
新規アセットのインポート設定は保持する。

## 撮影

`tools/promotion/capture_parade.tscn`は登録済みの1−9をそのまま組み立てて撮影する。
カメラと両プレイヤーの入力を撮影用に指定する。死亡、配置、射撃、撃破、射出、
ゴールは実ゲーム処理。収録用の別地形は使わない。

```powershell
& $godot --path . --rendering-method gl_compatibility --audio-driver Dummy `
  --resolution 1280x720 --position 2400,0 --disable-vsync --fixed-fps 60 `
  --write-movie build/promotion/stage-1-9/raw-takes.avi tools/promotion/capture_parade.tscn
& $python tools/promotion/edit_parade.py
```

成果物は`build/promotion/stage-1-9/melos-stage-1-9.mp4`。英語表記、
制作者名Inoue & Sasabe。撮影の成立条件とイベントをJSONへ残し、成功したテイクだけを
等速で編集する。音楽は既存試作のオリジナル曲を再構成する。
オンラインの2人操作とモバイル実機での検証は未実施。

## 今回の結果

専用23項目、既存ロジック1,361項目、スクリプト321ファイル、9枚のステージ選択を
確認し、失敗は0。専用プローブではハンマーが19体以上を倒し、足場による救出と
最後の旗への到達が成立した。新しいプローブは検証スクリプトに組み込んでいる。

完成プレビューは19.283秒、1280×720、60fps、1,157フレーム、H.264/AAC、BT.709。
実ゲーム処理の撮影条件11項目が成立。撮影では第一のハンマーで25体、第二で23体の撃破。
収録区間の主人公位置1,157フレームを確認し、画面内に収まった。
全デコードでエラーなし、音声は−17.38 LUFS、真のピーク−5.75 dBTP。
聴感による評価は未実施。既存インポート設定583ファイルは作業前とバイト一致。

証跡は`build/promotion/stage-1-9/`の`probe.json`、`capture-checks.json`、
`verification.json`、`logic-writable.log`、`scripts.log`、`menu-final.log`に保存した。
