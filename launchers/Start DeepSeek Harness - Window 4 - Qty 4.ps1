# DeepSeek Harness - Window 4 / Qty 4 - port 3083
# Sets the window number and port, then runs the shared launcher body.
# Operating rules and preflight live in launcher-common.ps1.

$Window = 4
$Port   = 3083
. (Join-Path $PSScriptRoot 'launcher-common.ps1')
