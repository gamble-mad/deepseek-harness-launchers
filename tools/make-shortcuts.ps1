# make-shortcuts.ps1 - (re)create the four Desktop shortcuts for the four-window
# DeepSeek Harness mode, with their icons attached.
#
#   -Desktop     where to write the .lnk files (default: the user's Desktop folder,
#                which is the OneDrive Desktop when that redirection is on)
#   -IconStore   where icon files are copied for the shortcuts to reference
#                (default: %LOCALAPPDATA%\DeepSeekHarness - outside OneDrive so
#                Files On-Demand can never dehydrate them)
#
# Icons are the repo's assets\icons\deepseek-harness-window-N.ico; the script
# copies them into the icon store and points each shortcut there, so this one
# command "reattaches" everything. Existing shortcuts with the same names are
# overwritten; nothing else on the Desktop is touched.

param(
    [string]$Desktop   = [Environment]::GetFolderPath('Desktop'),
    [string]$IconStore = (Join-Path $env:LOCALAPPDATA 'DeepSeekHarness')
)

Set-StrictMode -Version Latest
$ErrorActionPreference = 'Stop'

$repoRoot  = Split-Path -Parent $PSScriptRoot
$launchers = Join-Path $repoRoot 'launchers'
$icons     = Join-Path $repoRoot 'assets\icons'
$psExe     = Join-Path $env:WINDIR 'System32\WindowsPowerShell\v1.0\powershell.exe'
$workDir   = Join-Path $env:USERPROFILE 'dsh-workdir'

foreach ($p in @($launchers, $icons, $psExe, $Desktop)) {
    if (-not (Test-Path -LiteralPath $p)) { throw "Missing: $p" }
}
if (-not (Test-Path -LiteralPath $workDir))   { New-Item -ItemType Directory -Path $workDir   | Out-Null }
if (-not (Test-Path -LiteralPath $IconStore)) { New-Item -ItemType Directory -Path $IconStore | Out-Null }

$sh = New-Object -ComObject WScript.Shell
foreach ($n in 1..4) {
    $port    = 3079 + $n
    $script  = Join-Path $launchers "Start DeepSeek Harness - Window $n - Qty $n.ps1"
    $srcIcon = Join-Path $icons "deepseek-harness-window-$n.ico"
    $dstIcon = Join-Path $IconStore "deepseek-harness-window-$n.ico"
    $lnkPath = Join-Path $Desktop "DeepSeek Harness - Window $n - Qty $n.lnk"

    foreach ($p in @($script, $srcIcon)) {
        if (-not (Test-Path -LiteralPath $p)) { throw "Missing: $p" }
    }
    Copy-Item -LiteralPath $srcIcon -Destination $dstIcon -Force

    $lnk = $sh.CreateShortcut($lnkPath)
    $lnk.TargetPath       = $psExe
    $lnk.Arguments        = "-ExecutionPolicy Bypass -NoProfile -File `"$script`""
    $lnk.WorkingDirectory = $workDir
    $lnk.IconLocation     = "$dstIcon,0"
    $lnk.WindowStyle      = 1
    $lnk.Description      = "DeepSeek Harness window $n on port $port"
    $lnk.Save()

    Write-Host ("Wrote {0}" -f $lnkPath)
    Write-Host ("  script: {0}" -f $script)
    Write-Host ("  icon:   {0}" -f $dstIcon)
}
[Runtime.InteropServices.Marshal]::ReleaseComObject($sh) | Out-Null

# Explorer caches icons aggressively; ask it to rebuild so the new icons show.
$ie4 = Join-Path $env:WINDIR 'System32\ie4uinit.exe'
if (Test-Path -LiteralPath $ie4) { & $ie4 -show }
Write-Host 'Done. If the Desktop still shows old icons, sign out and back in once.'
