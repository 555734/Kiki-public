# build-23 GLES3 / Motorola g55 障害調査

2026-09-21。調査中。原因特定・修正完了とは扱わない。

## 報告された症状

Motorola g55でbuild-23のGLES3 APKを起動すると、メニューが操作できず、端末が再起動。
2回目の再起動で止まったが、アプリを再度起動すると再発。Androidのバージョン、
OSビルド番号、発生時のシステムログは未取得。再現実行は依頼していない。

## 確認済み

- 公開ビルド: https://github.com/555734/Kiki-public/actions/runs/35589116699
- ビルド元: `5f2e67bf8dd67d098a55ddd80c58801bd96a0f8c`。
- 公開main `a66861f`とprivate `5e7afba`のゲーム本体・project.godotに差分なし。
- 配布APK `side-sky-gles3.apk` のSHA256:
  `a5c00044a9d8a58675f90d9cb24fd0d1f7ff752b6f93c8946a879b7d2d85be1c`。
  ダウンロードしたファイルとReleaseのdigestが一致。
- APK内`assets/project.binary`を直接解析した結果:
  `rendering/renderer/rendering_method.mobile = gl_compatibility`。
  名前だけGLES3で中身がVulkanという推測は支持されない。
- `main.gd`はNetPanelを表示した直後にWorld3Dを作る。
  World3Dはメニュー中もUPDATE_ALWAYS・2x MSAAで描画する。
  画面外モデルを非表示にはするが、モデル生成そのものはステージ全体に対して行う。
- 以前の`three_view_probe`はNetPanelを最初に解放していた。
  「入力を遮らない」判定も設定値の確認のみであり、起動メニューの操作検証として不十分だった。
- Windows / AMD Radeon / Godot 4.4.1 Compatibilityでメニューを残して
  Input.parse_input_eventによるScreenTouchの押下・解放を送ると、ローカルプレイを開始できた。
  最終計測のフレーム間隔中央値42.573ms / p95 47.053ms、報告VRAM約50MB。
  先行実行は中央値16.643ms。PCの短時間値から実機の正常動作や必要メモリを推定しない。
  先行プローブはボタンで解放されたNetPanelを参照してエラーになったため、
  is_instance_validで判定するようプローブを直して再確認した。

## 未確定の原因候補

### 優先候補: BXM-8-256のGLES3 3D描画経路

[Motorola公式仕様](https://en-us.support.motorola.com/app/answers/detail/a_id/183716/~/specifications---moto-g55-5g)
でmoto g55のSoCはDimensity 7025。
[MediaTek公式仕様](https://www.mediatek.com/products/smartphones/mediatek-dimensity-7025)
でそのGPUはIMG BXM-8-256。

[Godot #104640](https://github.com/godotengine/godot/issues/104640)は
同じGPUのMotorola g73で、Compatibility表示に3Dメッシュを入れるとクラッシュする報告。
4.4 / 4.4.1 RC等で再現。メッシュをカメラの後ろへ置くと動き、視界に入るとクラッシュする。
報告者は後に4.0/4.1でも再現したと訂正しているため、単純な旧版への変更を解決策としない。
統合先の[Godot #91916](https://github.com/godotengine/godot/issues/91916)は調査時点でopen。
今回新しく導入した3D表示、GPU型、GLES3が一致するため優先候補。
ただし別機種のアプリクラッシュであり、g55のOS再起動まで説明した証拠ではない。
端末の実際のドライバーバージョン・クラッシュスタックは未取得。

1. 新しく追加した起動時のメッシュ生成・シェーダー準備による長い停止。
2. GLES3のオフスクリーン描画・MSAAと端末ドライバーの組み合わせ。
3. メモリ圧迫、GPU/システムのwatchdog、OS側の障害。
4. 実機に固有の入力経路の障害。PCでタッチを合成できたことだけでは除外できない。

いずれも端末再起動の根本原因と断定する証拠はまだない。
GodotのPowerVR向け粒子シェーダーキャッシュ修正
(https://github.com/godotengine/godot/pull/111329)も確認したが、Kikiのエフェクトは
CPUParticles2Dであり、同じ障害と決めつけない。
3D追加時のCompatibility停止報告
(https://github.com/godotengine/godot/issues/102665)は関連候補だが、
別機種の初回ロード停止であって今回の端末再起動を証明しない。

## 次の切り分け

- USB接続不可との回答あり。端末内の開発者向けオプション「バグレポート」で
  USBなしでも既存記録を取得できる可能性がある。再現起動は不要。
  [Android公式手順](https://developer.android.com/studio/debug/bug-report)。
- 記録を取得できた場合、既存のboot reason、DropBoxの
  SYSTEM_LAST_KMSG / SYSTEM_RESTART / SYSTEM_SERVER_WATCHDOG / crash / ANR等を確認する。
  再起動で失われたログもあり得る。bugreport全体には他アプリの情報も含まれるため公開しない。
- メニュー処理が止まったのか、描画だけが止まったのか、GPU/システムの再起動かを記録から区別する。
- ログが示す箇所に合わせ、MSAA、起動時3D生成、描画更新など一要素ずつ比較する。
  ユーザーの端末に危険な再現実行を要求しない。
- 素材・アニメーションを破棄したり、単に2Dへ戻しただけで修正完了とはしない。

調査用APK、ビルドログ、設定解析とメニュー試験はローカル`build/incident/`に保存。
この時点でゲーム本体の変更、修正版の配布、端末へのインストールは行っていない。
