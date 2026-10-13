# 37秒PVの縦版

元動画の構成は `1361439` の `tools/trailer_shots.gd` にある12カット。
`ccr-f66afd35-ssomm6` の最新コミットは31.4秒に再編集されているため、
添付された37秒版を変更するときは37秒の構成を基準にする。

`--portrait` を指定すると、Godotが720×1280の論理画面を1080×1920で
描画する。横長MP4を切り抜く処理ではなく、背景・キャラクター・指を
描画し直す。カメラの幅、門と犬を同時に見せる引き、星を奪う二人と
乱戦の画角、通話表示、指のラベル、縦に並ぶストア表示を調整している。
カットの長さとゲームの入力タイミングは元のまま。

```bash
TRAILER_AUDIO_SOURCE=/absolute/path/6027.mp4 \
  tools/make_trailer.sh /path/to/godot build/trailer/melos_shorts.mp4 -- --portrait
```

`TRAILER_AUDIO_SOURCE` は元の完成動画の音声を再圧縮せずコピーする。
未指定なら従来どおり `trailer_mix.py` が録音素材とスコアを混ぜる。

構図を速く確認するには、`--portrait --size 360x640` を指定する。
`--only a2_gate,vs_steal,e1_title` でカットを限定できる。
出力先は `--out /absolute/path/capture` で指定できる。

撮影・描画: `tools/capture_trailer.gd`

カット割りとカメラ: `tools/trailer_shots.gd`

通話・指・最後のタイトル: `tools/trailer_overlay.gd`

## 2026-10-13 修正版

非表示の操作ボタンが縦画面中央の指を拾ってしまうため、撮影時の指は
本番のワールド用ジェスチャーに渡す。門の持ち上げ、岩の停止が実際に
成立し、主人公が生存して通過することを確認する。
岩の上への移動では縦の追従を追加し、敵を弾く前には敵も収める。
画面外の指の「YOU」は表示せず、敵を弾いた後の指は退出させる。

公式配布元から取得した しゃろう「2:23 AM」を使用する。
配布元: https://opentracks.com/bgm/detail/13494
ライセンス: https://opentracks.com/help/articles/license/
作曲者条件: https://opentracks.com/creator/detail/101
原音ファイルをリポジトリへ再配布せず、取得したファイルを指定する。

```bash
TRAILER_BGM=/absolute/path/Sharou_223_AM.mp3 \
  tools/make_trailer.sh /path/to/godot build/trailer/melos_shorts.mp4 -- --portrait
```

`trailer_bgm.py` が効果音を撮影イベントから再構成し、旧生成スコアを
外してから新BGMを合成する。BGMはステレオを保持し、効果音が強い
瞬間には少し下げ、最後にフェードする。標準音量は -21 LUFS。

特定カットの撮り直しには `tools/trailer_retake.py` を使う。
同じカット名・フレーム数の素材を入れ替え、効果音と通話音の時刻も
元の37秒の時間軸へ戻す。
