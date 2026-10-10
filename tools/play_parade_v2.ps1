param([ValidateRange(1,6)][int]$Zone = 1)
$paradeRoot = Split-Path -Parent $PSScriptRoot
$paradeGodot = Join-Path $paradeRoot '../tools/godot-4.7.2/Godot_v4.7.2-stable_win64_console.exe'
if (-not (Test-Path -LiteralPath $paradeGodot)) { throw 'Godot 4.7.2 is missing from build/tools.' }
Start-Process -FilePath $paradeGodot -WorkingDirectory $paradeRoot -WindowStyle Hidden -ArgumentList @('--path','.', '--rendering-method','gl_compatibility','--resolution','1280x720','--position','200,80','tools/play_parade_v2.tscn','--','--review-zone',"$Zone")
