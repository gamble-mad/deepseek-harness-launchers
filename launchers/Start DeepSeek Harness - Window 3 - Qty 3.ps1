# DeepSeek Harness - Window 3 / Qty 3 - port 3082
#
# OPERATING RULES - four-window isolation mode:
#  1. Fresh session per window. Never open the same active session in two windows.
#     Pick the workspace in the Harness UI after it loads; the OS working directory
#     does not select it.
#  2. One window per workspace for any mutating work. Permanent rule - neither
#     distinct ports nor storage-root isolation prevent shared-file edit races
#     between windows.
#  3. Workspace-registry state is now PER-WINDOW, not shared. Each window reads and
#     writes its own storages-wN\workspace.json. This includes the registry write
#     that happens every time you START A SESSION: the new session is attached to
#     the selected workspace's record in THIS window's root only. A workspace you
#     register, reorder, or archive in one window will not appear in the others -
#     each window keeps its own sidebar. This removes the last-write-wins clobber
#     of the formerly shared workspace index; the cost is that cross-window
#     workspace grouping / ordering / archive state no longer converge. Session
#     logs themselves stay shared under .dsh\sessions and are readable from any
#     window (a session made elsewhere shows Ungrouped here, not missing).
#
# For ordinary parallel work prefer one server + multiple browser tabs; four windows
# are the deliberate isolation mode, not the default.
$env:DSH_STORAGE_ROOT = 'C:\Users\mgamb\.dsh\storages-w3'
& 'B:\npm-global\dsh.cmd' --profile web --patch 'B:\AI\DeepSeekHarness\patches\storage-root-per-window.patch.yml' --port 3082
if ($LASTEXITCODE -ne 0) {
    Write-Host ""
    Write-Host "Harness (Window 3, port 3082) exited with code $LASTEXITCODE." -ForegroundColor Red
    Read-Host "Press Enter to close"
}
