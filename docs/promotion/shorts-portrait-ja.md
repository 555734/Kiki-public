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
