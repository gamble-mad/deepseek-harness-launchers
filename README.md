# deepseek-harness-launchers
This repo holds the operational scaffolding for the four-window DeepSeek Harness setup on Windows — not @deepseek-ai/dsh itself. It contains the four PowerShell launchers (one per window, ports 3080/3081/3082/3083), the storage-root-per-window cordis patch overlay that gives each window its own storage-json.root to prevent the shared-workspace.json last-write-wins clobber, the icon/shortcut build utilities, and the steady-state operating note. DSH_HOME, credentials, settings, and session logs stay shared; only the workspace-registry storage is split per window.

## Layout

| Path | Role |
|---|---|
| `launchers/Start DeepSeek Harness - Window N - Qty N.ps1` | The four Desktop entry points (names are referenced by the shortcuts; do not rename). Each sets `$Window`/`$Port` and dot-sources the shared body. |
| `launchers/launcher-common.ps1` | Shared body: preflight (dsh, patch, per-window storage root, node, port free), window title, launch, honest exit handling. Derives every path from the repo location and `%USERPROFILE%`. |
| `patches/storage-root-per-window.patch.yml` | Load-bearing overlay: per-window `storage-json.root` from `DSH_STORAGE_ROOT`, falling back to the shared root when the variable is unset **or empty**. |
| `assets/icons/deepseek-harness-window-N.ico` | The single source for the four icons. `assets/icons/src/` holds the PNG originals. |
| `tools/make-icon.ps1` | Builds a multi-resolution `.ico` from a PNG source. |
| `tools/make-shortcuts.ps1` | Recreates the four Desktop shortcuts, copies the icons into `%LOCALAPPDATA%\DeepSeekHarness`, and points the shortcuts there. Run it to "reattach" icons or after moving the repo. |
| `docs/STEADY-STATE-OPERATING-NOTE.txt` | Operating rules for four-window mode. |
| `.github/workflows/validate.yml` | Parses every script with the real PowerShell parser and fails on errors; checks the launchers stay thin and path-free. |

Runtime state (`%USERPROFILE%\.dsh\storages-w1..4`, sessions, credentials) never lives in this repo.
