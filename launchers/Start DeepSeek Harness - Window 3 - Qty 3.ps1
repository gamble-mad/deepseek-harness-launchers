# DeepSeek Harness - Window 3 / Qty 3 - port 3082
# Sets the window number and port, then runs the shared launcher body.
# Operating rules and preflight live in launcher-common.ps1.

$Window = 3
$Port   = 3082
. (Join-Path $PSScriptRoot 'launcher-common.ps1')
