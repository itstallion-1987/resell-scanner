# Скачивание визуалов стиля «Бирка»: иконка + 6 скриншотов App Store
$ErrorActionPreference = "Stop"
Add-Type -AssemblyName System.Drawing
$prefix = "https://d8j0ntlcm91z4.cloudfront.net/user_3DnToxpWifLEz7nJ63EQqP93ma1/"
$root = Split-Path (Split-Path $PSScriptRoot)

# --- Иконки (2 варианта) ---
$icons = @{
  "icon-tag-1.png" = "hf_20260611_020123_caebe738-4423-49e9-9381-16ab738b284c.png"
  "icon-tag-2.png" = "hf_20260611_020123_8d85b76d-3303-417d-ab53-196d059a73d4.png"
}
$iconsDir = Join-Path $root "docs\icons"
foreach ($name in $icons.Keys) {
  Invoke-WebRequest ($prefix + $icons[$name]) -OutFile (Join-Path $iconsDir $name)
}

# Вариант 1 -> AppIcon (RGB 24bpp без альфа-канала — Apple отклоняет иконки с прозрачностью)
$src = [System.Drawing.Image]::FromFile((Join-Path $iconsDir "icon-tag-1.png"))
$bmp = New-Object System.Drawing.Bitmap(1024, 1024, [System.Drawing.Imaging.PixelFormat]::Format24bppRgb)
$g = [System.Drawing.Graphics]::FromImage($bmp)
$g.InterpolationMode = [System.Drawing.Drawing2D.InterpolationMode]::HighQualityBicubic
$g.DrawImage($src, 0, 0, 1024, 1024)
$g.Dispose(); $src.Dispose()
$appIconPath = Join-Path $root "ios\ResellScanner\Resources\Assets.xcassets\AppIcon.appiconset\AppIcon-1024.png"
$bmp.Save($appIconPath, [System.Drawing.Imaging.ImageFormat]::Png)
$bmp.Dispose()
Write-Output "AppIcon updated"

# --- Скриншоты: масштаб по высоте до 2796, центральный кроп до 1290 ---
$shots = [ordered]@{
  "01-hero"        = "hf_20260611_020144_0e85d226-a8b5-474a-8218-5efdc73c0a7d.png"
  "02-camera"      = "hf_20260611_020238_452e765b-473a-44e9-9db5-8d5172ef80e0.png"
  "03-copy"        = "hf_20260611_020257_87fbb7da-8650-47bb-89b2-dd301e11e49e.png"
  "04-electronics" = "hf_20260611_020241_23675f79-9cc8-47d9-b05e-d66cfbf262d6.png"
  "05-platforms"   = "hf_20260611_020216_801a5184-6333-4a4b-b4bf-96451ac41a85.png"
  "06-price"       = "hf_20260611_020219_ebc9fa5c-521d-4c84-b7d2-61fa33df403f.png"
}
$raw = Join-Path $root "docs\screenshots\raw"
$out = Join-Path $root "docs\screenshots\appstore-6.7"
$TW = 1290; $TH = 2796
foreach ($name in $shots.Keys) {
  $rawPath = Join-Path $raw "$name.png"
  Invoke-WebRequest ($prefix + $shots[$name]) -OutFile $rawPath
  $img = [System.Drawing.Image]::FromFile($rawPath)
  $scale = $TH / $img.Height
  $sw = [int]([math]::Round($img.Width * $scale))
  $canvas = New-Object System.Drawing.Bitmap($TW, $TH)
  $gg = [System.Drawing.Graphics]::FromImage($canvas)
  $gg.InterpolationMode = [System.Drawing.Drawing2D.InterpolationMode]::HighQualityBicubic
  $gg.DrawImage($img, [int](($TW - $sw) / 2), 0, $sw, $TH)
  $gg.Dispose(); $img.Dispose()
  $canvas.Save((Join-Path $out "$name.png"), [System.Drawing.Imaging.ImageFormat]::Png)
  $canvas.Dispose()
}
Write-Output "Screenshots updated:"
Get-ChildItem $out -Filter *.png | ForEach-Object { $i=[System.Drawing.Image]::FromFile($_.FullName); "{0}: {1}x{2}" -f $_.Name, $i.Width, $i.Height; $i.Dispose() }
