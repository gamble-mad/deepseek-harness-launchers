# Sync the tracked dsh head and desk-loop skill between this repo and the live DSH home (~/.dsh).
#
#   .\tools\sync-dsh-home.ps1            # repo -> ~/.dsh  (install / update the live harness)
#   .\tools\sync-dsh-home.ps1 -Pull      # ~/.dsh -> repo  (capture live edits for commit)
#   .\tools\sync-dsh-home.ps1 -Diff      # show differences only, change nothing
#
# Only AGENTS.md and skills/ are tracked. settings.yaml, profiles, sessions, storages stay in ~/.dsh untouched.
# AGENTS.md is the fixed cache head for every window: a byte change there invalidates every session's cache,
# so this script never rewrites a file whose content is already identical.

param(
    [switch]$Pull,
    [switch]$Diff
)

$ErrorActionPreference = 'Stop'
$repoHome = Join-Path $PSScriptRoot '..\dsh-home' | Resolve-Path
$liveHome = Join-Path $HOME '.dsh'
if (-not (Test-Path $liveHome)) { throw "DSH home not found at $liveHome" }

$tracked = Get-ChildItem -Path $repoHome -Recurse -File | ForEach-Object {
    $_.FullName.Substring($repoHome.Path.Length).TrimStart('\')
}
if ($Pull) {
    $tracked += Get-ChildItem -Path (Join-Path $liveHome 'skills') -Recurse -File | ForEach-Object {
        $_.FullName.Substring($liveHome.Length).TrimStart('\')
    }
    $tracked += 'AGENTS.md'
    $tracked = $tracked | Sort-Object -Unique
}

$changed = 0
foreach ($rel in $tracked) {
    $src = if ($Pull) { Join-Path $liveHome $rel } else { Join-Path $repoHome $rel }
    $dst = if ($Pull) { Join-Path $repoHome $rel } else { Join-Path $liveHome $rel }
    if (-not (Test-Path $src)) { Write-Host "missing source: $rel"; continue }
    $same = (Test-Path $dst) -and ((Get-FileHash $src).Hash -eq (Get-FileHash $dst).Hash)
    if ($same) { continue }
    $changed++
    if ($Diff) { Write-Host "differs: $rel"; continue }
    New-Item -ItemType Directory -Force -Path (Split-Path $dst) | Out-Null
    Copy-Item -Path $src -Destination $dst -Force
    Write-Host "copied: $rel"
}
Write-Host "$changed file(s) $(if ($Diff) { 'differ' } else { 'updated' })."
