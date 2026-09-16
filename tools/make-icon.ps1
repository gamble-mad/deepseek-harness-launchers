# make-icon.ps1 - build a multi-resolution Windows .ico from a rounded-square
# badge PNG whose corners/border sit on a removable flat background.
#
#   -Source     source PNG (fully opaque, badge fills the frame to the mid-edges)
#   -Out        output .ico path
#   -BgMode     dark  = background is near-black  (brightest channel < Threshold)
#               light = background is near-white  (dimmest  channel > Threshold)
#   -Threshold  0 => mode default (dark:140, light:236)
#
# Method:
#   1. Load Source as 32bpp ARGB.
#   2. Flood-fill from every image-border pixel: edge-connected background pixels
#      become fully transparent. The badge's coloured border/glow walls the flood,
#      so only the external background is removed - no badge pixel, border, or
#      internal art is touched. No synthetic border/outline/fill is added.
#   3. Trim fully-transparent outer rows/columns to the badge's true bounds.
#   4. Scale the trimmed badge to fill each icon canvas edge-to-edge (256..16),
#      high-quality bicubic, alpha preserved.
#   5. Assemble the .ico: 16..128 as 32bpp BMP/DIB, 256 as PNG (Explorer rejects PNG below 256).
#   Source may also be an existing .ico: its largest PNG frame is repacked (steps 1-3 skipped).

param(
    [string]$Source = (Join-Path (Split-Path -Parent $PSScriptRoot) 'assets\icons\src\DS_Harness_2.png'),
    [string]$Out    = (Join-Path (Split-Path -Parent $PSScriptRoot) 'assets\icons\deepseek-harness-window-1.ico'),
    [ValidateSet('dark', 'light')][string]$BgMode = 'dark',
    [int]$Threshold = 0
)

Set-StrictMode -Version Latest
$ErrorActionPreference = 'Stop'
Add-Type -AssemblyName System.Drawing

if ($Threshold -le 0) { $Threshold = if ($BgMode -eq 'light') { 236 } else { 140 } }
$sizes = 256, 128, 64, 48, 32, 16

if (-not (Test-Path -LiteralPath $Source)) { throw "Source not found: $Source" }

# ---- repack mode: Source is an existing .ico ---------------------------------
# Its largest PNG frame is already background-cleared and trimmed, so the flood
# fill and trim are skipped and only the frame set is rebuilt. Used to convert
# icons whose 64/128 frames were PNG (which Explorer's icon loader rejects,
# showing a blank page) into DIB frames without touching the artwork.
$repack = ([IO.Path]::GetExtension($Source) -ieq '.ico')
if ($repack) {
    $raw = [IO.File]::ReadAllBytes($Source)
    if ($raw[0] -ne 0 -or $raw[2] -ne 1) { throw "Not an .ico: $Source" }
    $count = [BitConverter]::ToUInt16($raw, 4)
    $best = $null
    for ($i = 0; $i -lt $count; $i++) {
        $o = 6 + 16 * $i
        $size = [BitConverter]::ToUInt32($raw, $o + 8)
        $off  = [BitConverter]::ToUInt32($raw, $o + 12)
        $isPng = ($raw[$off] -eq 0x89 -and $raw[$off + 1] -eq 0x50)
        if ($isPng -and ($null -eq $best -or $size -gt $best.Size)) { $best = @{ Size = $size; Off = $off } }
    }
    if ($null -eq $best) { throw "No PNG frame in $Source to repack from." }
    $ms0 = New-Object System.IO.MemoryStream($raw, [int]$best.Off, [int]$best.Size)
    $orig = New-Object System.Drawing.Bitmap($ms0)
    $clean = New-Object System.Drawing.Bitmap($orig.Width, $orig.Height, [System.Drawing.Imaging.PixelFormat]::Format32bppArgb)
    $gr = [System.Drawing.Graphics]::FromImage($clean)
    $gr.Clear([System.Drawing.Color]::Transparent)
    $gr.DrawImage($orig, 0, 0, $orig.Width, $orig.Height)
    $gr.Dispose(); $orig.Dispose(); $ms0.Dispose()
    Write-Host ("Repack: {0}  largest PNG frame {1}x{2}" -f $Source, $clean.Width, $clean.Height)
}

if (-not $repack) {
# ---- load into a 32bpp ARGB bitmap --------------------------------------------
$orig = New-Object System.Drawing.Bitmap($Source)
$src  = New-Object System.Drawing.Bitmap($orig.Width, $orig.Height, [System.Drawing.Imaging.PixelFormat]::Format32bppArgb)
$g0   = [System.Drawing.Graphics]::FromImage($src)
$g0.DrawImage($orig, 0, 0, $orig.Width, $orig.Height)
$g0.Dispose()
$orig.Dispose()

$W = $src.Width; $H = $src.Height
Write-Host ("Source: {0}  {1}x{2}   BgMode={3}  Threshold={4}" -f $Source, $W, $H, $BgMode, $Threshold)

# ---- flood-fill the flat background from the borders -------------------------
$rect = New-Object System.Drawing.Rectangle(0, 0, $W, $H)
$data = $src.LockBits($rect, [System.Drawing.Imaging.ImageLockMode]::ReadWrite, [System.Drawing.Imaging.PixelFormat]::Format32bppArgb)
try {
    $stride = $data.Stride
    $bytes  = New-Object byte[] ($stride * $H)
    [System.Runtime.InteropServices.Marshal]::Copy($data.Scan0, $bytes, 0, $bytes.Length)

    $visited = New-Object 'bool[]' ($W * $H)
    $stack   = New-Object System.Collections.Generic.Stack[int]
    $isLight = ($BgMode -eq 'light')

    function Test-Bg([int]$idx) {
        $o = $idx * 4          # BGRA
        $b = $bytes[$o]; $g = $bytes[$o + 1]; $r = $bytes[$o + 2]
        if ($isLight) {
            $mn = $b; if ($g -lt $mn) { $mn = $g }; if ($r -lt $mn) { $mn = $r }
            return $mn -gt $Threshold
        } else {
            $mx = $b; if ($g -gt $mx) { $mx = $g }; if ($r -gt $mx) { $mx = $r }
            return $mx -lt $Threshold
        }
    }

    for ($x = 0; $x -lt $W; $x++) {
        foreach ($y in 0, ($H - 1)) {
            $i = $y * $W + $x
            if (-not $visited[$i] -and (Test-Bg $i)) { $visited[$i] = $true; $stack.Push($i) }
        }
    }
    for ($y = 0; $y -lt $H; $y++) {
        foreach ($x in 0, ($W - 1)) {
            $i = $y * $W + $x
            if (-not $visited[$i] -and (Test-Bg $i)) { $visited[$i] = $true; $stack.Push($i) }
        }
    }

    $cleared = 0
    while ($stack.Count -gt 0) {
        $i = $stack.Pop()
        $bytes[$i * 4 + 3] = 0
        $cleared++
        $x = $i % $W; $y = [int]($i / $W)
        if ($x -gt 0)      { $n = $i - 1;  if (-not $visited[$n] -and (Test-Bg $n)) { $visited[$n] = $true; $stack.Push($n) } }
        if ($x -lt $W - 1) { $n = $i + 1;  if (-not $visited[$n] -and (Test-Bg $n)) { $visited[$n] = $true; $stack.Push($n) } }
        if ($y -gt 0)      { $n = $i - $W; if (-not $visited[$n] -and (Test-Bg $n)) { $visited[$n] = $true; $stack.Push($n) } }
        if ($y -lt $H - 1) { $n = $i + $W; if (-not $visited[$n] -and (Test-Bg $n)) { $visited[$n] = $true; $stack.Push($n) } }
    }

    # sanity: the flood must clear something, must not eat the badge
    $pctCleared = 100.0 * $cleared / ($W * $H)
    if ($cleared -eq 0) {
        throw "Flood cleared 0 px - Threshold/BgMode wrong for this source, aborting."
    }
    foreach ($f in @(@(0.50, 0.35), @(0.50, 0.50), @(0.40, 0.63), @(0.30, 0.30), @(0.70, 0.70))) {
        $sx = [int]($f[0] * $W); $sy = [int]($f[1] * $H)
        $si = ($sy * $W + $sx) * 4 + 3
        if ($bytes[$si] -eq 0) { throw "Flood leaked into the badge at ($sx,$sy) - aborting." }
    }
    if ($pctCleared -gt 45) {
        throw ("Cleared {0:N1}% of pixels (>45%) - flood leaked, aborting." -f $pctCleared)
    }

    [System.Runtime.InteropServices.Marshal]::Copy($bytes, 0, $data.Scan0, $bytes.Length)
    Write-Host ("Flood-filled {0:N0} background px to transparent ({1:N2}%)" -f $cleared, $pctCleared)
} finally {
    $src.UnlockBits($data)
}

# ---- trim fully-transparent outer rows / columns ---------------------------
$minX = $W; $minY = $H; $maxX = -1; $maxY = -1
for ($y = 0; $y -lt $H; $y++) {
    for ($x = 0; $x -lt $W; $x++) {
        if ($src.GetPixel($x, $y).A -ne 0) {
            if ($x -lt $minX) { $minX = $x }
            if ($x -gt $maxX) { $maxX = $x }
            if ($y -lt $minY) { $minY = $y }
            if ($y -gt $maxY) { $maxY = $y }
        }
    }
}
$cropW = $maxX - $minX + 1
$cropH = $maxY - $minY + 1
Write-Host ("Content bounds: x $minX..$maxX  y $minY..$maxY  ({0}x{1})" -f $cropW, $cropH)

$clean = New-Object System.Drawing.Bitmap($cropW, $cropH, [System.Drawing.Imaging.PixelFormat]::Format32bppArgb)
$gc = [System.Drawing.Graphics]::FromImage($clean)
$gc.Clear([System.Drawing.Color]::Transparent)
$srcRect = New-Object System.Drawing.Rectangle($minX, $minY, $cropW, $cropH)
$dstRect = New-Object System.Drawing.Rectangle(0, 0, $cropW, $cropH)
$gc.DrawImage($src, $dstRect, $srcRect, [System.Drawing.GraphicsUnit]::Pixel)
$gc.Dispose()
$src.Dispose()
} # end of the PNG-source path

# ---- render each icon size ------------------------------------------------
function Get-Bgra([System.Drawing.Bitmap]$bmp) {
    $r = New-Object System.Drawing.Rectangle(0, 0, $bmp.Width, $bmp.Height)
    $d = $bmp.LockBits($r, [System.Drawing.Imaging.ImageLockMode]::ReadOnly, [System.Drawing.Imaging.PixelFormat]::Format32bppArgb)
    try {
        $buf = New-Object byte[] ($d.Stride * $bmp.Height)
        [System.Runtime.InteropServices.Marshal]::Copy($d.Scan0, $buf, 0, $buf.Length)
        return ,@{ Bytes = $buf; Stride = $d.Stride }
    } finally { $bmp.UnlockBits($d) }
}

$entries = @()
try {
    foreach ($s in $sizes) {
        $bmp = New-Object System.Drawing.Bitmap($s, $s, [System.Drawing.Imaging.PixelFormat]::Format32bppArgb)
        $g = [System.Drawing.Graphics]::FromImage($bmp)
        try {
            $g.InterpolationMode  = [System.Drawing.Drawing2D.InterpolationMode]::HighQualityBicubic
            $g.PixelOffsetMode    = [System.Drawing.Drawing2D.PixelOffsetMode]::HighQuality
            $g.SmoothingMode      = [System.Drawing.Drawing2D.SmoothingMode]::HighQuality
            $g.CompositingQuality = [System.Drawing.Drawing2D.CompositingQuality]::HighQuality
            $g.Clear([System.Drawing.Color]::Transparent)
            $g.DrawImage($clean, 0, 0, $s, $s)
        } finally { $g.Dispose() }

        # PNG only at 256. Explorer's shell icon loader (PrivateExtractIcons)
        # accepts PNG-compressed frames at 256x256 only; a PNG frame at 64 or
        # 128 makes the whole icon render as a blank page on the Desktop even
        # though GDI+ loads it fine. Every smaller frame is a plain 32bpp DIB.
        if ($s -ge 256) {
            $ms = New-Object System.IO.MemoryStream
            $bmp.Save($ms, [System.Drawing.Imaging.ImageFormat]::Png)
            $entries += ,@{ Size = $s; Png = $true; Data = $ms.ToArray() }
            $ms.Dispose()
        } else {
            $src32 = Get-Bgra $bmp
            $stride = $src32.Stride; $sb = $src32.Bytes
            $ms = New-Object System.IO.MemoryStream
            $w  = New-Object System.IO.BinaryWriter($ms)
            $w.Write([UInt32]40); $w.Write([Int32]$s); $w.Write([Int32]($s * 2))
            $w.Write([UInt16]1);  $w.Write([UInt16]32); $w.Write([UInt32]0)
            $w.Write([UInt32]0);  $w.Write([Int32]0);   $w.Write([Int32]0)
            $w.Write([UInt32]0);  $w.Write([UInt32]0)
            for ($row = $s - 1; $row -ge 0; $row--) { $w.Write($sb, $row * $stride, $s * 4) }
            $maskRow = [int][Math]::Floor((($s + 31) / 32)) * 4
            $zero = New-Object byte[] $maskRow
            for ($row = 0; $row -lt $s; $row++) { $w.Write($zero, 0, $maskRow) }
            $w.Flush()
            $entries += ,@{ Size = $s; Png = $false; Data = $ms.ToArray() }
            $w.Dispose(); $ms.Dispose()
        }
        $bmp.Dispose()
    }
} finally {
    $clean.Dispose()
}

# ---- assemble the .ico container ----------------------------------------
$fs = [System.IO.File]::Open($Out, [System.IO.FileMode]::Create, [System.IO.FileAccess]::Write)
$bw = New-Object System.IO.BinaryWriter($fs)
try {
    $count = $entries.Count
    $bw.Write([UInt16]0); $bw.Write([UInt16]1); $bw.Write([UInt16]$count)
    $offset = 6 + (16 * $count)
    foreach ($e in $entries) {
        $s = $e.Size; $len = $e.Data.Length
        $dim = if ($s -ge 256) { [byte]0 } else { [byte]$s }
        $bw.Write([byte]$dim); $bw.Write([byte]$dim); $bw.Write([byte]0); $bw.Write([byte]0)
        $bw.Write([UInt16]1); $bw.Write([UInt16]32)
        $bw.Write([UInt32]$len); $bw.Write([UInt32]$offset)
        $offset += $len
    }
    foreach ($e in $entries) { $bw.Write($e.Data, 0, $e.Data.Length) }
} finally {
    $bw.Dispose(); $fs.Dispose()
}

$fi = Get-Item -LiteralPath $Out
$fmt = ($entries | ForEach-Object { "{0}{1}" -f $_.Size, $(if ($_.Png) { 'p' } else { 'd' }) }) -join ' '
Write-Host ("Wrote: {0}  {1:N0} bytes  frames: {2}  (p=PNG d=DIB)" -f $Out, $fi.Length, $fmt)
