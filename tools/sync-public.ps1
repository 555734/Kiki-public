param(
    [string]$PublicRepo = "C:\product\Kiki-public-export",
    [string]$SourceBranch = "recovery/unified",
    [string]$PublicBranch = "main",
    [string]$CommitMessage = "Sync latest game"
)

$ErrorActionPreference = "Stop"
Set-StrictMode -Version Latest

$SourceRepo = (Resolve-Path (Join-Path $PSScriptRoot "..")).Path
$GitBash = "C:\Program Files\Git\bin\bash.exe"

function Invoke-Git {
    param(
        [Parameter(Mandatory = $true)][string]$Repo,
        [Parameter(Mandatory = $true)][string[]]$Args
    )
    & git -C $Repo @Args
    if ($LASTEXITCODE -ne 0) {
        throw "git failed in ${Repo}: git $($Args -join ' ')"
    }
}

function Convert-ToGitBashPath {
    param([Parameter(Mandatory = $true)][string]$WindowsPath)
    $full = [System.IO.Path]::GetFullPath($WindowsPath)
    $root = [System.IO.Path]::GetPathRoot($full)
    if ($root -notmatch '^[A-Za-z]:\\$') {
        throw "Expected a drive-letter Windows path, got: $full"
    }
    $drive = $root.Substring(0, 1).ToLowerInvariant()
    $rest = $full.Substring($root.Length).Replace('\', '/')
    return "/$drive/$rest"
}

if (-not (Test-Path (Join-Path $PublicRepo ".git"))) {
    throw "Public repo clone not found: $PublicRepo"
}

$currentBranch = (& git -C $SourceRepo branch --show-current).Trim()
if ($LASTEXITCODE -ne 0 -or $currentBranch -ne $SourceBranch) {
    throw "Source repo must be on $SourceBranch (currently '$currentBranch')."
}

# Never publish a stale local HEAD. Fetch only; do not rewrite a working tree
# that may contain local Godot import files or intentional edits.
Invoke-Git -Repo $SourceRepo -Args @("fetch", "origin", $SourceBranch)
$localHead = (& git -C $SourceRepo rev-parse HEAD).Trim()
$remoteHead = (& git -C $SourceRepo rev-parse "origin/$SourceBranch").Trim()
if ($localHead -ne $remoteHead) {
    throw "Local $SourceBranch is not at origin/$SourceBranch. Run: git pull --ff-only"
}

# Bring the public clone up to date before replacing its snapshot.
Invoke-Git -Repo $PublicRepo -Args @("fetch", "origin", $PublicBranch)
Invoke-Git -Repo $PublicRepo -Args @("switch", $PublicBranch)
Invoke-Git -Repo $PublicRepo -Args @("pull", "--ff-only", "origin", $PublicBranch)

$tempRoot = Join-Path $env:TEMP ("kiki-public-sync-" + [guid]::NewGuid().ToString("N"))
$zipPath = Join-Path $tempRoot "snapshot.zip"
New-Item -ItemType Directory -Path $tempRoot | Out-Null

try {
    & git -C $SourceRepo archive --format=zip --output=$zipPath HEAD
    if ($LASTEXITCODE -ne 0) {
        throw "git archive failed"
    }

    # Kiki-public-export is deliberately a disposable mirror checkout. Keep only
    # its .git directory, then replace every published file with the audited
    # snapshot from recovery/unified.
    Get-ChildItem -LiteralPath $PublicRepo -Force |
        Where-Object { $_.Name -ne ".git" } |
        Remove-Item -Recurse -Force

    Expand-Archive -LiteralPath $zipPath -DestinationPath $PublicRepo -Force

    if (-not (Test-Path $GitBash)) {
        throw "Git Bash not found at '$GitBash'. Install Git for Windows or update the path in this script."
    }

    $bashPublicRepo = Convert-ToGitBashPath $PublicRepo
    & $GitBash -lc "cd '$bashPublicRepo' && tools/audit-public.sh"
    if ($LASTEXITCODE -ne 0) {
        throw "Public audit failed. Nothing was committed or pushed."
    }

    Invoke-Git -Repo $PublicRepo -Args @("add", "-A")
    & git -C $PublicRepo diff --cached --quiet
    $diffExit = $LASTEXITCODE
    if ($diffExit -eq 0) {
        Write-Host "Kiki-public is already in sync with $localHead"
        exit 0
    }
    if ($diffExit -ne 1) {
        throw "git diff --cached failed"
    }

    Invoke-Git -Repo $PublicRepo -Args @("commit", "-m", $CommitMessage)
    Invoke-Git -Repo $PublicRepo -Args @("push", "origin", $PublicBranch)

    $publicHead = (& git -C $PublicRepo rev-parse HEAD).Trim()
    Write-Host "Synced $SourceBranch $localHead -> Kiki-public/$PublicBranch $publicHead"
    Write-Host "The public push will trigger Android and iOS GitHub Actions when build inputs changed."
}
finally {
    if (Test-Path $tempRoot) {
        Remove-Item -LiteralPath $tempRoot -Recurse -Force -ErrorAction SilentlyContinue
    }
}
