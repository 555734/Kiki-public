# recovery/unified のビルド手順

このブランチを統合版の確認対象にする。

## Android / Windows

必要なものは Godot 4.4.1、Android SDK（build-tools を含む）、JDK。
環境変数を一度設定する。

```powershell
$env:GODOT = "C:\path\to\Godot_v4.4.1-stable_win64.exe"
$env:ANDROID_HOME = "C:\Users\YOUR_NAME\AppData\Local\Android\Sdk"
$env:JAVA_HOME = "C:\path\to\jdk"
```

その後はリポジトリのルートでこれだけ。

```powershell
powershell -ExecutionPolicy Bypass -File .\tools\build-android.ps1
```

出力:

```text
build\android\side-sky-vulkan.apk
build\android\side-sky-gles3.apk
```

両方とも Android 0.2.3 / versionCode 23。固定のテスト用 debug keystore で署名するため、同じ package id の以前のテスト APK の上へ更新インストールできる。スクリプトは APK の署名と Godot ゲームデータの存在まで確認する。

スクリプトはビルド中だけ `project.godot`、`balance.gd`、Godot の Android editor settings を一時変更し、終了時（失敗時を含む）に元のバイト列へ戻す。

## iOS / TestFlight

PC で clone する必要はない。Codemagic が GitHub から直接取得する。

Codemagic の **Start new build** で:

- Branch: `recovery/unified`
- Workflow: `iOS — TestFlight に提出（署名付き）`

を選ぶ。

`codemagic.yaml` には push 自動実行用の `triggering:` を置いていないので、push だけで macOS 分数を消費したり Apple へ提出したりしない。

TestFlight版は:

- Version: 0.2.3
- Bundle ID: `com.sasakiful.sidesky`
- Team ID: `6TGM565HX8`
- Build number: Codemagic の `$BUILD_NUMBER`

を使う。

App Store Connect API キーは Codemagic の Developer Portal integration に `SIDE_SKY_ASC` という名前で登録する。秘密鍵はリポジトリへ入れない。

詳細は `docs/testflight.md`。

## GitHub Actions

Android / iOS とも `workflow_dispatch` のみ。push やタグ作成では自動実行しない。Actions を使いたいときだけ Actions タブから明示的に実行する。
