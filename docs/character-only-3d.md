# 操作キャラクターだけ3Dにする構成

2026-09-22時点の現行仕様。全画面3D化は廃止し、背景、地形、敵、小物、エフェクト、
UIは既存の2D素材へ戻した。3D描画の対象は操作可能なRunner（旧4人アリーナでは
各Fighter）だけである。

## 素材

- 制作元: `tools/blender/lira_mobile.blend`（Blender 4.5 LTS）
- 再生成スクリプト: `tools/blender/build_lira_mobile.py`
- ゲーム用: `assets/models/blender/lira_mobile.glb`
- アニメーション: Idle / Run / Jump / Fall / Land / Dash / Hurt / Dead

モデルは既存の2D絵を基準に、茶髪、赤いスカーフ、白シャツ、青いオーバーオール、
茶色い手袋とブーツで作った。外部のフリーモデルや新規テクスチャは使用していない。

## モバイル負荷

`character_view.gd`は透過SubViewportをゲーム画面につき1個だけ作る。解像度は画面の
75%以下かつ横720px以下、3D MSAAなし、影なし、ライト1灯。3D物理や3Dコライダーは
なく、既存の2D物理・入力・通信に触れない。画面外のキャラクターは描画しない。

標準レンダラーは広い端末で動くGLES3 compatibility。Androidビルドスクリプトは
互換版を推奨APKとして残しつつ、新しい端末向けVulkan版も別途生成する。両APKへ
ARMv7（32-bit）とARM64を同梱し、ARM64専用だった以前の配布物より対応範囲を広げた。

## 検証

`test/three_view_probe.tscn`（名前は既存CIとの互換のため維持）が次を検査する。

- 3D対象が操作キャラクターだけであること
- 全7ステージ相当で2D地形が表示されたままであること
- GLBの8アニメーション、実移動・ジャンプとの連動
- カメラズームと画面サイズ変更後の1px未満の位置一致
- 720px上限、MSAA無効、タッチ入力を遮らないこと

Windows / AMD Radeon Graphics / Godot 4.4.1 / OpenGL compatibility / 1280x720の
確認では206 draw calls、5,094 primitives、フレーム間隔の中央値16.75ms、p95 23.92ms。
これはデスクトップでの短時間測定であり、全スマートフォンの60fpsや長時間の発熱を
保証するものではない。最終判断には最低仕様端末を含む実機試験が必要。
