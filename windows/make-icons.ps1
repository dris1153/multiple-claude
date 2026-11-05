# Builds claudeN.ico (gradient rounded square + white spark) from assets/palette.json and assets/spark.png.
# Usage: make-icons.ps1 -Out <dir> [-Numbers 2,3] [-Assets <dir>]
param([int[]]$Numbers = (2..10), [Parameter(Mandatory)][string]$Out, [string]$Assets)
$ErrorActionPreference = 'Stop'
if (-not $Assets) { $Assets = Join-Path $PSScriptRoot '..\assets' }   # PS 5.1: $PSScriptRoot is empty in param defaults
Add-Type -AssemblyName System.Drawing

$palette = Get-Content (Join-Path $Assets 'palette.json') -Raw | ConvertFrom-Json
$sizes = 16, 24, 32, 48, 64, 128, 256

function New-IconPng($c1, $c2, [Drawing.Image]$spark, $scale, $px) {
    $bmp = New-Object Drawing.Bitmap $px, $px, ([Drawing.Imaging.PixelFormat]::Format32bppArgb)
    $g = [Drawing.Graphics]::FromImage($bmp)
    $g.SmoothingMode = 'AntiAlias'; $g.InterpolationMode = 'HighQualityBicubic'; $g.PixelOffsetMode = 'HighQuality'
    $d = $px * 0.45   # corner diameter
    $path = New-Object Drawing.Drawing2D.GraphicsPath
    $path.AddArc(0, 0, $d, $d, 180, 90); $path.AddArc($px - $d, 0, $d, $d, 270, 90)
    $path.AddArc($px - $d, $px - $d, $d, $d, 0, 90); $path.AddArc(0, $px - $d, $d, $d, 90, 90)
    $path.CloseFigure()
    $brush = [Drawing.Drawing2D.LinearGradientBrush]::new([Drawing.Rectangle]::new(0, 0, $px, $px), $c1, $c2, [single]90)
    $g.FillPath($brush, $path)
    $s = $px * $scale
    $g.DrawImage($spark, ($px - $s) / 2, ($px - $s) / 2, $s, $s)
    $ms = New-Object IO.MemoryStream
    $bmp.Save($ms, [Drawing.Imaging.ImageFormat]::Png)
    $g.Dispose(); $bmp.Dispose(); $brush.Dispose(); $path.Dispose()
    , $ms.ToArray()
}

function Write-Ico([string]$file, [byte[][]]$pngs) {
    $fs = [IO.File]::Create($file); $w = New-Object IO.BinaryWriter $fs
    $w.Write([uint16]0); $w.Write([uint16]1); $w.Write([uint16]$pngs.Count)
    $offset = 6 + 16 * $pngs.Count
    for ($i = 0; $i -lt $pngs.Count; $i++) {
        $sz = if ($sizes[$i] -ge 256) { 0 } else { $sizes[$i] }   # 0 means 256 in the ICO directory
        $w.Write([byte]$sz); $w.Write([byte]$sz); $w.Write([byte]0); $w.Write([byte]0)
        $w.Write([uint16]1); $w.Write([uint16]32); $w.Write([uint32]$pngs[$i].Length); $w.Write([uint32]$offset)
        $offset += $pngs[$i].Length
    }
    foreach ($p in $pngs) { $w.Write($p) }
    $w.Close(); $fs.Close()
}

New-Item -ItemType Directory -Force $Out | Out-Null
$spark = [Drawing.Image]::FromFile((Resolve-Path (Join-Path $Assets 'spark.png')).Path)
try {
    foreach ($n in $Numbers) {
        $hex = $palette.colors."$n"
        if (-not $hex) { Write-Warning "No colour for Claude $n in palette.json, skipped"; continue }
        $c1, $c2 = $hex | ForEach-Object { [Drawing.ColorTranslator]::FromHtml($_) }
        $pngs = foreach ($px in $sizes) { , (New-IconPng $c1 $c2 $spark $palette.sparkScale $px) }
        Write-Ico (Join-Path $Out "claude$n.ico") $pngs
        Write-Output "Done: claude$n.ico"
    }
} finally { $spark.Dispose() }
