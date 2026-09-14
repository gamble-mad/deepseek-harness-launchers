# DeepSeek Harness - Window 2 / Qty 2 - port 3081
# Sets the window number and port, then runs the shared launcher body.
# Operating rules and preflight live in launcher-common.ps1.

$Window = 2
$Port   = 3081
. (Join-Path $PSScriptRoot 'launcher-common.ps1')
