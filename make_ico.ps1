Add-Type -AssemblyName System.Drawing

# Konversi Assets/FormUpLogo.png -> windows/runner/resources/app_icon.ico
# (multi-ukuran 16..256 px, rasio dipertahankan di kanvas persegi transparan)

$root = $PSScriptRoot
$srcPath = Join-Path $root 'Assets\FormUpLogo.png'
$outPath = Join-Path $root 'mobile\windows\runner\resources\app_icon.ico'

$src = [System.Drawing.Image]::FromFile($srcPath)
Write-Host "Sumber: $($src.Width) x $($src.Height)"

$sizes = 16, 24, 32, 48, 64, 128, 256
$entries = @()
foreach ($s in $sizes) {
    $bmp = New-Object System.Drawing.Bitmap($s, $s)
    $g = [System.Drawing.Graphics]::FromImage($bmp)
    $g.InterpolationMode = [System.Drawing.Drawing2D.InterpolationMode]::HighQualityBicubic
    $g.SmoothingMode = [System.Drawing.Drawing2D.SmoothingMode]::HighQuality
    $g.Clear([System.Drawing.Color]::Transparent)
    # fit-contain: skala agar sisi terpanjang = $s, posisikan di tengah
    $scale = [Math]::Min($s / $src.Width, $s / $src.Height)
    $w = [int]([Math]::Round($src.Width * $scale))
    $h = [int]([Math]::Round($src.Height * $scale))
    $x = [int](($s - $w) / 2)
    $y = [int](($s - $h) / 2)
    $g.DrawImage($src, $x, $y, $w, $h)
    $g.Dispose()
    $ms = New-Object System.IO.MemoryStream
    $bmp.Save($ms, [System.Drawing.Imaging.ImageFormat]::Png)
    $bmp.Dispose()
    $entries += , $ms.ToArray()
    $ms.Dispose()
}
$src.Dispose()

# Header ICO: ICONDIR + ICONDIRENTRY per ukuran + data PNG (format valid sejak Vista)
$fs = [System.IO.File]::Create($outPath)
$bw = New-Object System.IO.BinaryWriter($fs)
$bw.Write([UInt16]0)                 # reserved
$bw.Write([UInt16]1)                 # type = icon
$bw.Write([UInt16]$entries.Count)    # count

$offset = 6 + 16 * $entries.Count
for ($i = 0; $i -lt $entries.Count; $i++) {
    $s = $sizes[$i]
    $byte = if ($s -ge 256) { 0 } else { $s }   # 256 disimpan sebagai 0
    $bw.Write([Byte]$byte)           # width
    $bw.Write([Byte]$byte)           # height
    $bw.Write([Byte]0)               # palette
    $bw.Write([Byte]0)               # reserved
    $bw.Write([UInt16]1)             # planes
    $bw.Write([UInt16]32)            # bpp
    $bw.Write([UInt32]$entries[$i].Length)
    $bw.Write([UInt32]$offset)
    $offset += $entries[$i].Length
}
foreach ($e in $entries) { $bw.Write($e) }
$bw.Flush()
$bw.Dispose()

Write-Host "OK: $outPath ($((Get-Item $outPath).Length) bytes)"
