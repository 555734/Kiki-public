param(
    [string]$GodotPath = $env:GODOT,
    [string]$AndroidSdk = $(if ($env:ANDROID_HOME) { $env:ANDROID_HOME } else { $env:ANDROID_SDK_ROOT }),
    [string]$JavaHome = $env:JAVA_HOME,
    [string]$Keystore = ""
)

Set-StrictMode -Version Latest
$ErrorActionPreference = "Stop"

$Root = (Resolve-Path (Join-Path $PSScriptRoot "..")).Path
Set-Location $Root
$Utf8NoBom = New-Object System.Text.UTF8Encoding($false)
$GodotVersion = "4.4.1"

function Write-Utf8NoBom([string]$Path, [string]$Text) {
    [System.IO.File]::WriteAllText($Path, $Text, $Utf8NoBom)
}

function Download-File([string]$Url, [string]$OutFile, [string]$Label) {
    $parent = Split-Path $OutFile -Parent
    if ($parent) { New-Item -ItemType Directory -Force -Path $parent | Out-Null }

    $curl = Get-Command curl.exe -ErrorAction SilentlyContinue
    if ($curl) {
        if (Test-Path $OutFile) {
            $have = [math]::Round((Get-Item $OutFile).Length / 1MB, 1)
            Write-Host "${Label}: resuming existing ${have} MB download..."
        } else {
            Write-Host "${Label}: downloading..."
        }
        & $curl.Source --location --fail --retry 3 --retry-delay 2 --continue-at - --progress-bar --output $OutFile $Url
        if ($LASTEXITCODE -ne 0) {
            throw "${Label} download failed with curl exit code ${LASTEXITCODE}. Partial file is kept so the next run can resume."
        }
        return
    }

    Write-Host "${Label}: curl.exe was not found; using PowerShell downloader."
    Invoke-WebRequest -Uri $Url -OutFile $OutFile -UseBasicParsing
}

function Prefer-ConsoleGodot([string]$Path) {
    if (-not $Path) { return $null }
    if (-not (Test-Path $Path)) { return $null }
    $resolved = (Resolve-Path $Path).Path
    if ($resolved -match '_console\.exe$') { return $resolved }
    if ($resolved -match '\.exe$') {
        $console = $resolved -replace '\.exe$', '_console.exe'
        if (Test-Path $console) { return (Resolve-Path $console).Path }
    }
    return $resolved
}

function Ensure-Godot([string]$Requested) {
    if ($Requested) {
        if (Test-Path $Requested) { return (Prefer-ConsoleGodot $Requested) }
        $cmd = Get-Command $Requested -ErrorAction SilentlyContinue
        if ($cmd) { return (Prefer-ConsoleGodot $cmd.Source) }
        throw "Godot not found: $Requested"
    }

    foreach ($name in @("godot", "godot4")) {
        $cmd = Get-Command $name -ErrorAction SilentlyContinue
        if ($cmd) { return (Prefer-ConsoleGodot $cmd.Source) }
    }

    foreach ($candidate in @(
        "$env:USERPROFILE\Downloads\Godot_v4.4.1-stable_win64_console.exe",
        "$env:USERPROFILE\Downloads\Godot_v4.4.1-stable_win64.exe",
        "$env:LOCALAPPDATA\Programs\Godot\Godot_console.exe",
        "$env:LOCALAPPDATA\Programs\Godot\Godot.exe",
        "$env:ProgramFiles\Godot\Godot_console.exe",
        "$env:ProgramFiles\Godot\Godot.exe"
    )) {
        if ($candidate -and (Test-Path $candidate)) { return (Prefer-ConsoleGodot $candidate) }
    }

    $ToolDir = Join-Path $Root "build\tools\godot-$GodotVersion"
    $GuiExe = Join-Path $ToolDir "Godot_v${GodotVersion}-stable_win64.exe"
    $ConsoleExe = Join-Path $ToolDir "Godot_v${GodotVersion}-stable_win64_console.exe"

    if (-not (Test-Path $GuiExe) -and -not (Test-Path $ConsoleExe)) {
        New-Item -ItemType Directory -Force -Path $ToolDir | Out-Null
        $Zip = Join-Path $ToolDir "godot.zip"
        $Url = "https://github.com/godotengine/godot-builds/releases/download/${GodotVersion}-stable/Godot_v${GodotVersion}-stable_win64.exe.zip"
        Download-File $Url $Zip "Godot $GodotVersion"
        Write-Host "Extracting Godot..."
        Expand-Archive -Path $Zip -DestinationPath $ToolDir -Force
        Remove-Item $Zip -Force
    }

    if (Test-Path $ConsoleExe) { return (Resolve-Path $ConsoleExe).Path }
    if (Test-Path $GuiExe) { return (Resolve-Path $GuiExe).Path }
    throw "Godot download completed but executable was not found in $ToolDir"
}

function Resolve-AndroidSdk([string]$Requested) {
    if ($Requested -and (Test-Path $Requested)) { return (Resolve-Path $Requested).Path }
    foreach ($candidate in @(
        "$env:LOCALAPPDATA\Android\Sdk",
        "$env:USERPROFILE\AppData\Local\Android\Sdk",
        "C:\Android\Sdk"
    )) {
        if ($candidate -and (Test-Path $candidate)) { return (Resolve-Path $candidate).Path }
    }
    throw "Android SDK not found. Install Android Studio/SDK or set ANDROID_HOME (or ANDROID_SDK_ROOT)."
}

function Resolve-JavaHome([string]$Requested) {
    if ($Requested -and (Test-Path $Requested)) { return (Resolve-Path $Requested).Path }
    foreach ($candidate in @(
        "$env:ProgramFiles\Android\Android Studio\jbr",
        "$env:ProgramFiles\Android\Android Studio\jre",
        "$env:ProgramFiles\Eclipse Adoptium\jdk-17*",
        "$env:ProgramFiles\Java\jdk-17*"
    )) {
        if (-not $candidate) { continue }
        $matches = Get-Item $candidate -ErrorAction SilentlyContinue
        if ($matches) {
            $first = @($matches)[0]
            if (Test-Path (Join-Path $first.FullName "bin\java.exe")) { return $first.FullName }
        }
    }
    throw "JDK not found. Android Studio includes one at C:\Program Files\Android\Android Studio\jbr, or set JAVA_HOME."
}

$Godot = Ensure-Godot $GodotPath
$AndroidSdk = Resolve-AndroidSdk $AndroidSdk
$JavaHome = Resolve-JavaHome $JavaHome

if (-not $env:APPDATA) { throw "APPDATA is not set; Godot editor settings path cannot be resolved." }
if (-not $Keystore) {
    if (-not $env:USERPROFILE) { throw "USERPROFILE is not set; local test keystore path cannot be resolved." }
    $Keystore = Join-Path $env:USERPROFILE ".android\side-sky-debug.keystore"
}
if (-not (Test-Path $Keystore)) {
    $Keytool = Join-Path $JavaHome "bin\keytool.exe"
    if (-not (Test-Path $Keytool)) { throw "keytool.exe not found under JDK: $JavaHome" }
    $KeyDir = Split-Path $Keystore -Parent
    if ($KeyDir) { New-Item -ItemType Directory -Force -Path $KeyDir | Out-Null }
    & $Keytool -genkeypair -noprompt `
        -keystore $Keystore `
        -storepass android `
        -keypass android `
        -alias androiddebugkey `
        -keyalg RSA -keysize 2048 -validity 10000 `
        -dname "CN=SIDE SKY Local Debug,O=Local Development,C=JP" | Out-Null
    if ($LASTEXITCODE -ne 0) { throw "Failed to create local test keystore: $Keystore" }
    Write-Host "Created local test signing key: $Keystore"
}
$Keystore = (Resolve-Path $Keystore).Path

$BuildTools = Get-ChildItem (Join-Path $AndroidSdk "build-tools") -Directory -ErrorAction Stop |
    Sort-Object { [version]($_.Name -replace '-.*$','') } -Descending |
    Select-Object -First 1
if (-not $BuildTools) { throw "Android SDK build-tools not found under $AndroidSdk" }
$ApkSigner = Join-Path $BuildTools.FullName "apksigner.bat"
if (-not (Test-Path $ApkSigner)) { throw "apksigner.bat not found: $ApkSigner" }

$TemplateDir = Join-Path $env:APPDATA "Godot\export_templates\${GodotVersion}.stable"
$AndroidDebugTemplate = Join-Path $TemplateDir "android_debug.apk"
$AndroidReleaseTemplate = Join-Path $TemplateDir "android_release.apk"
if (-not (Test-Path $AndroidDebugTemplate) -or -not (Test-Path $AndroidReleaseTemplate)) {
    New-Item -ItemType Directory -Force -Path $TemplateDir | Out-Null
    $TemplateArchive = Join-Path $Root "build\tools\Godot_v${GodotVersion}-stable_export_templates.zip"
    $TemplateUrl = "https://github.com/godotengine/godot-builds/releases/download/${GodotVersion}-stable/Godot_v${GodotVersion}-stable_export_templates.tpz"
    Download-File $TemplateUrl $TemplateArchive "Godot Android export templates (large download)"
    Write-Host "Extracting Android export templates..."
    $TempExtract = Join-Path $Root "build\tools\templates-$GodotVersion"
    Remove-Item $TempExtract -Recurse -Force -ErrorAction SilentlyContinue
    New-Item -ItemType Directory -Force -Path $TempExtract | Out-Null
    Expand-Archive -Path $TemplateArchive -DestinationPath $TempExtract -Force
    $SourceTemplateDir = Join-Path $TempExtract "templates"
    foreach ($name in @("android_debug.apk", "android_release.apk", "android_source.zip")) {
        $src = Join-Path $SourceTemplateDir $name
        if (Test-Path $src) { Copy-Item $src (Join-Path $TemplateDir $name) -Force }
    }
    Remove-Item $TempExtract -Recurse -Force -ErrorAction SilentlyContinue
    Remove-Item $TemplateArchive -Force -ErrorAction SilentlyContinue
}
if (-not (Test-Path $AndroidDebugTemplate)) { throw "Godot Android debug template is missing: $AndroidDebugTemplate" }
if (-not (Test-Path $AndroidReleaseTemplate)) { throw "Godot Android release template is missing: $AndroidReleaseTemplate" }

$Out = Join-Path $Root "build\android"
New-Item -ItemType Directory -Force -Path $Out | Out-Null
$VulkanApk = Join-Path $Out "side-sky-vulkan.apk"
$GlesApk = Join-Path $Out "side-sky-gles3.apk"
Remove-Item $VulkanApk,$GlesApk -Force -ErrorAction SilentlyContinue

$GodotConfig = Join-Path $env:APPDATA "Godot"
$EditorSettingsPath = Join-Path $GodotConfig "editor_settings-4.4.tres"
New-Item -ItemType Directory -Force -Path $GodotConfig | Out-Null
$HadEditorSettings = Test-Path $EditorSettingsPath
$EditorSettingsBytes = if ($HadEditorSettings) { [System.IO.File]::ReadAllBytes($EditorSettingsPath) } else { $null }

function Slash([string]$p) { return ($p -replace '\\','/') }
$EditorSettings = @"
[gd_resource type="EditorSettings" format=3]

[resource]
export/android/android_sdk_path = "$(Slash $AndroidSdk)"
export/android/java_sdk_path = "$(Slash $JavaHome)"
export/android/debug_keystore = "$(Slash $Keystore)"
export/android/debug_keystore_user = "androiddebugkey"
export/android/debug_keystore_pass = "android"
"@
Write-Utf8NoBom $EditorSettingsPath $EditorSettings

# Configure both signing modes. Local test builds may use either release or
# debug export; both use the same machine-local test key so upgrades install
# cleanly without putting a reusable private key in Git.
$env:GODOT_ANDROID_KEYSTORE_RELEASE_PATH = $Keystore
$env:GODOT_ANDROID_KEYSTORE_RELEASE_USER = "androiddebugkey"
$env:GODOT_ANDROID_KEYSTORE_RELEASE_PASSWORD = "android"
$env:GODOT_ANDROID_KEYSTORE_DEBUG_PATH = $Keystore
$env:GODOT_ANDROID_KEYSTORE_DEBUG_USER = "androiddebugkey"
$env:GODOT_ANDROID_KEYSTORE_DEBUG_PASSWORD = "android"

$ProjectPath = Join-Path $Root "project.godot"
$BalancePath = Join-Path $Root "src\autoload\balance.gd"
$ProjectBytes = [System.IO.File]::ReadAllBytes($ProjectPath)
$BalanceBytes = [System.IO.File]::ReadAllBytes($BalancePath)
$ProjectOriginal = Get-Content $ProjectPath -Raw
$BalanceOriginal = Get-Content $BalancePath -Raw

$ShortSha = "unknown"
try { $ShortSha = (git rev-parse --short HEAD 2>$null).Trim() } catch {}
$Stamp = if ($env:BUILD_STAMP) { $env:BUILD_STAMP } else { "$ShortSha-$([DateTime]::UtcNow.ToString('yyyyMMdd'))" }
$BalanceStamped = $BalanceOriginal -replace 'const BUILD_ID: String = "dev"', ('const BUILD_ID: String = "' + $Stamp + '"')
Write-Utf8NoBom $BalancePath $BalanceStamped

function Run-Godot([string[]]$GodotArgs) {
    & $Godot @GodotArgs
    $exit = $LASTEXITCODE
    if ($exit -ne 0) { throw "Godot failed with exit code ${exit}: $($GodotArgs -join ' ')" }
}

function Export-Android([string]$Preset, [string]$OutputPath) {
    Remove-Item $OutputPath -Force -ErrorAction SilentlyContinue
    $godotOut = ($OutputPath -replace '\\','/')

    Run-Godot @("--headless", "--verbose", "--path", ".", "--export-release", $Preset, $godotOut)
    if (Test-Path $OutputPath) { return }

    Write-Host "Release export returned without an APK; retrying as debug export..."
    Run-Godot @("--headless", "--verbose", "--path", ".", "--export-debug", $Preset, $godotOut)
    if (-not (Test-Path $OutputPath)) {
        throw "Godot finished but did not create APK: $OutputPath"
    }
}

try {
    Write-Host "== SIDE / SKY Android 0.2.3 (versionCode 23) =="
    Write-Host "Godot: $Godot"
    Write-Host "SDK:   $AndroidSdk"
    Write-Host "JDK:   $JavaHome"
    Write-Host "Build: $Stamp"

    if ($Godot -notmatch '_console\.exe$') {
        Write-Warning "Godot console binary was not found; using $Godot. The console build is preferred for synchronous CLI exports."
    }

    Write-Host "`n== import =="
    Run-Godot @("--headless", "--editor", "--import", "--path", ".")

    Write-Host "`n== Vulkan/mobile APK =="
    Export-Android "Android" $VulkanApk

    Write-Host "`n== GLES3/compatibility APK =="
    $GlesProject = $ProjectOriginal -replace 'renderer/rendering_method.mobile="mobile"', 'renderer/rendering_method.mobile="gl_compatibility"'
    Write-Utf8NoBom $ProjectPath $GlesProject
    Run-Godot @("--headless", "--editor", "--import", "--path", ".")
    Export-Android "Android GLES3" $GlesApk

    Write-Host "`n== verify =="
    Add-Type -AssemblyName System.IO.Compression.FileSystem
    foreach ($apk in @($VulkanApk, $GlesApk)) {
        if (-not (Test-Path $apk)) { throw "APK missing: $apk" }
        & $ApkSigner verify $apk
        if ($LASTEXITCODE -ne 0) { throw "APK signature verification failed: $apk" }
        $zip = [System.IO.Compression.ZipFile]::OpenRead($apk)
        try {
            $gameEntries = @($zip.Entries | Where-Object { $_.FullName -like 'assets/.godot*' }).Count
        } finally {
            $zip.Dispose()
        }
        if ($gameEntries -lt 1) { throw "APK contains no Godot game data: $apk" }
        $mb = [math]::Round((Get-Item $apk).Length / 1MB, 1)
        Write-Host "OK  $(Split-Path $apk -Leaf)  ${mb}MB  signed  game-data=$gameEntries"
    }

    Write-Host "`nDone:"
    Write-Host "  $VulkanApk"
    Write-Host "  $GlesApk"
}
finally {
    [System.IO.File]::WriteAllBytes($ProjectPath, $ProjectBytes)
    [System.IO.File]::WriteAllBytes($BalancePath, $BalanceBytes)
    if ($HadEditorSettings) {
        [System.IO.File]::WriteAllBytes($EditorSettingsPath, $EditorSettingsBytes)
    } else {
        Remove-Item $EditorSettingsPath -Force -ErrorAction SilentlyContinue
    }
}