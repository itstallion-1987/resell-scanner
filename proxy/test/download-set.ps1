# Скачивание сгенерированных тест-фото по кейсам + конвертация в JPEG (как делает приложение)
$ErrorActionPreference = "Stop"
Add-Type -AssemblyName System.Drawing
$prefix = "https://d8j0ntlcm91z4.cloudfront.net/user_3DnToxpWifLEz7nJ63EQqP93ma1/"
$sets = Join-Path $PSScriptRoot "sets"

$map = @{
  "02-tshirt/1-overall"         = "hf_20260610_165809_9fb2f024-e56d-4555-bd1e-97d06010e8cd.png"
  "02-tshirt/2-tag"             = "hf_20260610_165813_f74e5ddf-03ce-475f-a4ef-9acf5aa06099.png"
  "03-dress/1-overall"          = "hf_20260610_165817_ae50eead-b479-4d1e-b79d-416ede364bcb.png"
  "03-dress/2-tag"              = "hf_20260610_165826_77b7df60-62be-4248-9c6f-815ba407f54f.png"
  "04-sneakers/1-overall"       = "hf_20260610_165830_6e2e5fa9-d1b3-41ca-a3cd-3730bdbbb5ec.png"
  "04-sneakers/2-tag"           = "hf_20260610_165833_aad03ff8-aac6-467e-9513-f2fe19e889d2.png"
  "05-kids-jacket/1-overall"    = "hf_20260610_165838_32bf1cd9-ceda-45f7-a784-83be6df65937.png"
  "05-kids-jacket/2-tag"        = "hf_20260610_165841_52dd3ce8-62ed-4f0c-a4ea-9ffd7dbf0ace.png"
  "06-sweater-no-tag/1-overall" = "hf_20260610_165907_85ab4c78-4357-4675-b664-f586227c5972.png"
  "07-jeans-no-tag/1-overall"   = "hf_20260610_165910_43acdbd2-9e91-4f4d-abb5-f57108f5f8ae.png"
  "08-boots-scuffed/1-overall"  = "hf_20260610_165913_592cf1fd-39ab-4946-9d44-e3d7aa80e058.png"
  "09-headphones/1-overall"     = "hf_20260610_165917_679070bc-4580-4e54-b0a2-4c6f2639a4d0.png"
  "10-gamepad/1-overall"        = "hf_20260610_165920_e6da31e5-35be-4a75-9834-ae19546301b8.png"
  "11-keyboard/1-overall"       = "hf_20260610_165923_ab46b1c9-3527-4fda-a3c4-60a285e60783.png"
  "12-lamp/1-overall"           = "hf_20260610_165938_5ba89f67-614a-46f4-a8fa-32f547cbf7d8.png"
  "13-chipped-mug/1-overall"    = "hf_20260610_165942_ea577eb9-fd78-4917-b5f5-b9bea83464e0.png"
  "14-stained-hoodie/1-overall" = "hf_20260610_165859_db788da2-daaa-462c-bfd9-e35c49e81ee5.png"
  "14-stained-hoodie/2-stain"   = "hf_20260610_165903_cc5698cd-c509-47f8-9f86-7538ed15d04d.png"
  "15-leather-bag/1-overall"    = "hf_20260610_165949_40cc50f1-4a80-4f77-bf64-4ee07b41be4e.png"
  "16-jewelry-ring/1-overall"   = "hf_20260610_165953_ad269e1d-df22-4ae3-9f75-530a05a577d5.png"
  "17-blurry/1-overall"         = "hf_20260610_165956_4715aed7-5eed-4c69-8879-212fed0ad97b.png"
  "18-not-item/1-overall"       = "hf_20260610_165959_f169a2dd-a826-4117-8221-7f0a1d8330a2.png"
}

$codec = [System.Drawing.Imaging.ImageCodecInfo]::GetImageEncoders() | Where-Object { $_.MimeType -eq "image/jpeg" }
$qparams = New-Object System.Drawing.Imaging.EncoderParameters(1)
$qparams.Param[0] = New-Object System.Drawing.Imaging.EncoderParameter([System.Drawing.Imaging.Encoder]::Quality, [long]72)

$done = 0
foreach ($key in $map.Keys | Sort-Object) {
  $parts = $key.Split("/")
  $dir = Join-Path $sets $parts[0]
  New-Item -ItemType Directory -Force $dir | Out-Null
  $tmp = Join-Path $env:TEMP "ts-dl.png"
  Invoke-WebRequest ($prefix + $map[$key]) -OutFile $tmp
  $img = [System.Drawing.Image]::FromFile($tmp)
  $img.Save((Join-Path $dir ($parts[1] + ".jpg")), $codec, $qparams)
  $img.Dispose()
  Remove-Item $tmp -Force
  $done++
}
Write-Output "Downloaded and converted: $done images"
Get-ChildItem $sets -Directory | ForEach-Object { "{0}: {1} photo(s)" -f $_.Name, (Get-ChildItem $_.FullName -Filter *.jpg).Count }
