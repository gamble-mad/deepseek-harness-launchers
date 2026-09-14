# DeepSeek Harness - Window 1 / Qty 1 - port 3080
# Sets the window number and port, then runs the shared launcher body.
# Operating rules and preflight live in launcher-common.ps1.

$Window = 1
$Port   = 3080
. (Join-Path $PSScriptRoot 'launcher-common.ps1')
