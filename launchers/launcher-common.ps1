# launcher-common.ps1 - shared body for the four window launchers.
#
# Each "Start DeepSeek Harness - Window N - Qty N.ps1" sets $Window and $Port,
# then dot-sources this file. Everything machine-specific is derived here from
# the repo location and the user profile, so the launchers carry no absolute
# paths of their own.
#
# Four-window isolation mode - operating rules (unchanged since Phase 4):
#  1. Fresh session per window. Never open the same active session in two windows.
#  2. One window per workspace for any mutating work. Neither distinct ports nor
#     storage-root isolation prevent shared-file edit races between windows.
#  3. Workspace-registry state is PER-WINDOW (storages-wN\workspace.json). A
#     workspace registered, reordered, or archived in one window does not appear in
#     the others. Session logs stay shared under .dsh\sessions.
# For ordinary parallel work prefer one server + multiple browser tabs; four
# windows are the deliberate isolation mode, not the default.

Set-StrictMode -Version Latest
$ErrorActionPreference = 'Stop'

if (-not (Test-Path variable:Window) -or -not (Test-Path variable:Port)) {
    throw 'launcher-common.ps1 must be dot-sourced by a window launcher that sets $Window and $Port.'
}

$repoRoot    = Split-Path -Parent $PSScriptRoot
$patchFile   = Join-Path $repoRoot 'patches\storage-root-per-window.patch.yml'
$storageRoot = Join-Path $env:USERPROFILE ".dsh\storages-w$Window"

# One dsh install is the rule. The pinned global prefix is preferred; if it is
# absent fall back to whatever `dsh` resolves to on PATH, and say which was used.
$pinnedDsh = 'B:\npm-global\dsh.cmd'
$dshCmd = if (Test-Path -LiteralPath $pinnedDsh) { $pinnedDsh } else {
    $found = Get-Command dsh.cmd -ErrorAction SilentlyContinue
    if ($null -eq $found) { $found = Get-Command dsh -ErrorAction SilentlyContinue }
    if ($null -eq $found) { $null } else { $found.Source }
}

function Stop-WithMessage([string]$message) {
    Write-Host ''
    Write-Host "Harness (Window $Window, port $Port) cannot start:" -ForegroundColor Red
    Write-Host "  $message" -ForegroundColor Red
    Read-Host 'Press Enter to close'
    exit 1
}

# ---- preflight: every load-bearing piece named, before anything launches ------
if ($null -eq $dshCmd)                        { Stop-WithMessage "dsh is not installed (looked for $pinnedDsh and `dsh` on PATH)." }
if (-not (Test-Path -LiteralPath $patchFile)) { Stop-WithMessage "patch overlay missing: $patchFile (load-bearing; all four windows need it)." }
if (-not (Test-Path -LiteralPath $storageRoot)) { Stop-WithMessage "per-window storage root missing: $storageRoot (restore it from backup; do not point this window at the shared root)." }
if ($null -eq (Get-Command node -ErrorAction SilentlyContinue)) { Stop-WithMessage 'node is not on PATH; dsh.cmd needs it.' }

# Each window owns one loopback port: window N -> 127.0.0.1:(3079+N). A port
# still held after a window was closed is almost always a dsh/node process the
# console closed around but did not end. Name the holder and offer to end it;
# never end anything without the operator's key press.
$BindHost = '127.0.0.1'
$listening = Get-NetTCPConnection -LocalPort $Port -State Listen -ErrorAction SilentlyContinue
if ($listening) {
    $holderId = ($listening | Select-Object -First 1).OwningProcess
    $holder   = Get-CimInstance Win32_Process -Filter "ProcessId = $holderId" -ErrorAction SilentlyContinue
    Write-Host ''
    Write-Host "Port $Port is already in use." -ForegroundColor Yellow
    if ($null -ne $holder) {
        Write-Host "  held by PID $holderId  $($holder.Name)"
        Write-Host "  $($holder.CommandLine)"
    }
    Write-Host "  If a Harness window $Window is open, use that one instead of starting a second."
    $answer = Read-Host "End PID $holderId and start this window here? [y/N]"
    if ($answer -notmatch '^[Yy]$') { exit 0 }
    Stop-Process -Id $holderId -Force -ErrorAction SilentlyContinue
    Start-Sleep -Seconds 2
    if (Get-NetTCPConnection -LocalPort $Port -State Listen -ErrorAction SilentlyContinue) {
        Stop-WithMessage "port $Port is still held after ending PID $holderId."
    }
}

$Host.UI.RawUI.WindowTitle = "DeepSeek Harness - Window $Window - ${BindHost}:$Port"
Write-Host "DeepSeek Harness window $Window" -ForegroundColor Cyan
Write-Host "  web:     http://${BindHost}:$Port"
Write-Host "  dsh:     $dshCmd"
Write-Host "  patch:   $patchFile"
Write-Host "  storage: $storageRoot"
Write-Host "  (first bind can take 15-20 s while node warms its compile cache)"
Write-Host "  open the web address above in your browser yourself; this launcher no longer opens one."
Write-Host "  This console IS window $Window - closing it stops the harness on port $Port."
Write-Host ''

$env:DSH_STORAGE_ROOT = $storageRoot

# Everything dsh prints is also appended to a per-window log, so a window that
# dies while nobody is watching still leaves its last lines behind.
$logFile = Join-Path $env:USERPROFILE ".dsh\launcher-w$Window.log"
Add-Content -LiteralPath $logFile -Encoding UTF8 -Value ("--- {0}  window {1}  port {2}  start" -f (Get-Date -Format s), $Window, $Port)
Write-Host "  log:     $logFile"
Write-Host ''

# Option order matters to dsh: --patch is a global option and must come before
# the web-profile options (--host, --port), or dsh reports "unknown option".
# PowerShell 5.1 wraps a native command's stderr lines as error records when
# they are redirected; under ErrorActionPreference=Stop a single warning line
# from dsh would end this script. Relax it for the duration of the run only.
$ErrorActionPreference = 'Continue'
# --no-open: dsh would otherwise tell the default browser to open the URL on
# every launch, and a browser that restores its session (Comet, Brave, Edge)
# then piles up windows. The operator opens 127.0.0.1:<port> once and keeps
# the tab; the URL is printed above and in the log.
& $dshCmd --profile web --patch $patchFile --host $BindHost --port $Port --no-open 2>&1 |
    ForEach-Object { $line = "$_"; Write-Host $line; Add-Content -LiteralPath $logFile -Value $line -Encoding UTF8 }
$code = $LASTEXITCODE
$ErrorActionPreference = 'Stop'
Add-Content -LiteralPath $logFile -Encoding UTF8 -Value ("--- {0}  window {1}  exit code {2}" -f (Get-Date -Format s), $Window, $code)

# The console never closes on its own. Whatever ended dsh - Ctrl+C, a crash, a
# clean exit nobody asked for - the exit code and the last output stay on
# screen until the operator presses Enter. (A window that silently vanishes
# is exactly the fault this guards against.)
Write-Host ''
if ($code -eq 0 -or $code -eq 130) {
    Write-Host "Harness (Window $Window, port $Port) stopped, exit code $code." -ForegroundColor Yellow
} else {
    Write-Host "Harness (Window $Window, port $Port) exited with code $code." -ForegroundColor Red
}
Write-Host "Last lines are in $logFile"
Read-Host 'Press Enter to close'
