# p9.ps1 - one-shot P9 for a DeepSeek build left uncommitted in a worktree.
#
#   .\tools\p9.ps1 -Worktree w4 -Branch deepseek/alpaca-diagnostic -MessageFile C:\path\msg.txt
#   .\tools\p9.ps1 -Worktree w4 -Branch deepseek/alpaca-diagnostic -Message "feat(x): one line"
#   .\tools\p9.ps1 -Worktree w4 -Merge          # after a green P9: merge the worktree's branch into the main checkout
#
# Steps (each prints one line; the whole run prints under ten):
#   1. worktree HEAD + git status before
#   2. git checkout -b <Branch>; git add -A; git commit (message from -Message or -MessageFile)
#   3. npm run typecheck   -> node / web / tooling / mla-offline pass|FAIL
#   4. npm test            -> the two summary lines from vitest
#   5. git status after (must be empty)
# Nothing here pushes, deletes, rebuilds native modules, or runs the Desk.
# -Merge does: git merge --no-ff <branch of that worktree> into the main checkout, then typecheck + npm test there.

param(
    [Parameter(Mandatory = $true)][ValidateSet('w1', 'w2', 'w3', 'w4')][string]$Worktree,
    [string]$Branch,
    [string]$Message,
    [string]$MessageFile,
    [switch]$Merge,
    [string]$WorktreeRoot = 'G:\DeepSeek Desk Work\worktrees',
    [string]$MainCheckout = 'C:\Users\mgamb\Trading UI for me',
    [string]$NodeDir      = 'C:\Users\mgamb\AppData\Local\nvm\v24.18.1'
)

$ErrorActionPreference = 'Continue'
$env:PATH = "$NodeDir;" + $env:PATH
$wt = Join-Path $WorktreeRoot $Worktree

function Run-Checks([string]$dir) {
    Set-Location $dir
    $tc = & npm run typecheck 2>&1 | Out-String
    $tcErrors = ([regex]::Matches($tc, 'error TS\d+')).Count
    $tcLine = if ($LASTEXITCODE -eq 0 -and $tcErrors -eq 0) { 'typecheck: node pass . web pass . tooling pass . mla-offline pass' } else { "typecheck: FAIL ($tcErrors errors, exit $LASTEXITCODE)" }
    Write-Host $tcLine
    if ($tcErrors -gt 0) { ($tc -split "`n" | Select-String 'error TS' | Select-Object -First 5) | ForEach-Object { Write-Host "  $_" } }
    $t = & npm test 2>&1 | Out-String -Width 4096
    $lines = @($t -split "`n" | ForEach-Object { ($_ -replace '\x1b\[[\d;]*[A-Za-z]', '') -replace '^\s*(?:npm|node)(?:\.(?:exe|cmd|bat))?\s*:\s', '' })
    $summary = ($lines | Select-String '^\s*(Test Files|Tests)\s' | ForEach-Object { $_.Line.Trim() }) -join ' | '
    Write-Host "suite:     $summary"
    $hitIdx = @(0..($lines.Count - 1) | Where-Object { $lines[$_] -match '^\s*(FAIL|\u00D7|\u276F)\s' } | Select-Object -First 8)
    for ($h = 0; $h -lt $hitIdx.Count; $h++) {
        Write-Host "  $($lines[$hitIdx[$h]].Trim())"
        $stop = if ($h + 1 -lt $hitIdx.Count) { $hitIdx[$h + 1] } else { $lines.Count }
        for ($j = $hitIdx[$h] + 1; $j -lt $stop; $j++) {
            if ($lines[$j] -match 'AssertionError|Error:') { Write-Host "    $($lines[$j].Trim())"; break }
        }
    }
}

if ($Merge) {
    Set-Location $wt
    $branch = (& git branch --show-current).Trim()
    if (-not $branch) { Write-Host "merge: $Worktree is detached; nothing to merge"; exit 1 }
    Set-Location $MainCheckout
    $dirty = (& git status --short)
    if ($dirty) { Write-Host "merge: main checkout not clean:`n$dirty"; exit 1 }
    & git merge -q --no-ff $branch -m "merge: $branch ($(Set-Location $wt; (& git log -1 --format=%h); Set-Location $MainCheckout))" 2>&1 | Out-String | Write-Host
    Write-Host ("merged:    {0} -> funnel {1}" -f $branch, (& git log -1 --format=%h))
    Run-Checks $MainCheckout
    Write-Host ("status:    '{0}'" -f ((& git status --short) -join ' '))
    exit 0
}

if (-not $Branch) { Write-Host 'need -Branch (or -Merge)'; exit 1 }
$msg = if ($MessageFile) { Get-Content -Raw -LiteralPath $MessageFile } else { $Message }
if (-not $msg) { Write-Host 'need -Message or -MessageFile'; exit 1 }
if ($msg -notmatch 'Co-Authored-By') { $msg = $msg.TrimEnd() + "`n`nCo-Authored-By: Claude Opus 5 <noreply@anthropic.com>`n" }

Set-Location $wt
Write-Host ("before:    HEAD {0}  changed {1} file(s)" -f (& git log -1 --format=%h), ((& git status --short | Measure-Object).Count))
& git checkout -q -b $Branch 2>&1 | Out-Null
& git add -A -- . ':!reports' 2>&1 | Out-Null
$tmp = [IO.Path]::GetTempFileName(); Set-Content -LiteralPath $tmp -Value $msg -Encoding UTF8
& git commit -q -F $tmp 2>&1 | Out-String | Write-Host
Remove-Item $tmp -Force
Write-Host ("commit:    {0}  on {1}" -f (& git log -1 --format=%h), (& git branch --show-current))
Run-Checks $wt
Write-Host ("status:    '{0}'" -f ((& git status --short) -join ' '))
