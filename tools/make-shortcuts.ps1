# make-shortcuts.ps1 - (re)create the four Desktop shortcuts for the four-window
# DeepSeek Harness mode, with their icons attached, and rebuild Explorer's icon
# cache so the new icons actually show.
#
#   -Desktop       where to write the .lnk files (default: the user's Desktop
#                  folder, which is the OneDrive Desktop when that redirection is on)
#   -IconStore     where icon files are copied for the shortcuts to reference
#                  (default: %LOCALAPPDATA%\DeepSeekHarness - outside OneDrive so
#                  Files On-Demand can never dehydrate them)
#   -NoCacheReset  skip the Explorer icon-cache rebuild (Explorer is restarted
#                  during the rebuild; open Explorer windows close and reopen)
#
# Shortcut names are "DS Harness N.lnk" (the operator's names). The earlier
# "DeepSeek Harness - Window N - Qty N.lnk" names, if present, are removed so
# the Desktop never carries two shortcuts for one window. Nothing else on the
# Desktop is touched.
#
# Channel map, fixed: window N -> launcher "Window N - Qty N" -> 127.0.0.1:(3079+N)
# -> storage ~\.dsh\storages-wN -> icon deepseek-harness-window-N.ico.

param(
    [string]$Desktop   = [Environment]::GetFolderPath('Desktop'),
    [string]$IconStore = (Join-Path $env:LOCALAPPDATA 'DeepSeekHarness'),
    [switch]$NoCacheReset
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

# Four icons must be four different images, or the windows are not distinguishable.
$iconHashes = 1..4 | ForEach-Object { (Get-FileHash (Join-Path $icons "deepseek-harness-window-$_.ico")).Hash }
if (($iconHashes | Sort-Object -Unique).Count -ne 4) { throw 'assets\icons: the four window icons are not all distinct.' }

$sh = New-Object -ComObject WScript.Shell
foreach ($n in 1..4) {
    $port    = 3079 + $n
    $script  = Join-Path $launchers "Start DeepSeek Harness - Window $n - Qty $n.ps1"
    $srcIcon = Join-Path $icons "deepseek-harness-window-$n.ico"
    $dstIcon = Join-Path $IconStore "deepseek-harness-window-$n.ico"
    $lnkPath = Join-Path $Desktop "DS Harness $n.lnk"
    $oldLnk  = Join-Path $Desktop "DeepSeek Harness - Window $n - Qty $n.lnk"

    foreach ($p in @($script, $srcIcon)) {
        if (-not (Test-Path -LiteralPath $p)) { throw "Missing: $p" }
    }
    Copy-Item -LiteralPath $srcIcon -Destination $dstIcon -Force
    if (Test-Path -LiteralPath $oldLnk) { Remove-Item -LiteralPath $oldLnk -Force; Write-Host "Removed old-name duplicate $oldLnk" }

    $lnk = $sh.CreateShortcut($lnkPath)
    $lnk.TargetPath       = $psExe
    $lnk.Arguments        = "-ExecutionPolicy Bypass -NoProfile -File `"$script`""
    $lnk.WorkingDirectory = $workDir
    $lnk.IconLocation     = "$dstIcon,0"
    $lnk.WindowStyle      = 1
    $lnk.Description      = "DeepSeek Harness window $n - http://127.0.0.1:$port - storages-w$n"
    $lnk.Save()

    Write-Host ("Wrote {0}" -f $lnkPath)
    Write-Host ("  script: {0}" -f $script)
    Write-Host ("  port:   127.0.0.1:{0}" -f $port)
    Write-Host ("  icon:   {0}" -f $dstIcon)
}
[Runtime.InteropServices.Marshal]::ReleaseComObject($sh) | Out-Null

if ($NoCacheReset) {
    Write-Host 'Done (icon cache not reset; pass without -NoCacheReset if the Desktop shows blank icons).'
    exit 0
}

# Explorer keeps a per-user icon cache (iconcache_*.db) that survives ie4uinit
# on Windows 11. Rebuild it properly: stop Explorer, delete the cache files,
# start Explorer again. Open Explorer windows close and reopen; nothing else.
Write-Host 'Rebuilding the Explorer icon cache (Explorer restarts once)...'
$cacheDir = Join-Path $env:LOCALAPPDATA 'Microsoft\Windows\Explorer'
Stop-Process -Name explorer -Force -ErrorAction SilentlyContinue
Start-Sleep -Seconds 2
Get-ChildItem -LiteralPath $cacheDir -Filter 'iconcache_*.db' -Force -ErrorAction SilentlyContinue |
    Remove-Item -Force -ErrorAction SilentlyContinue
Get-ChildItem -LiteralPath $cacheDir -Filter 'thumbcache_*.db' -Force -ErrorAction SilentlyContinue |
    Remove-Item -Force -ErrorAction SilentlyContinue
$ie4 = Join-Path $env:WINDIR 'System32\ie4uinit.exe'
if (Test-Path -LiteralPath $ie4) { & $ie4 -show }
Start-Process explorer.exe
Write-Host 'Done. The four shortcuts should now show their own icons.'
