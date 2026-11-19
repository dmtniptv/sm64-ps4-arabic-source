param(
    [Parameter(Mandatory = $true)][string]$FontPath,
    [Parameter(Mandatory = $true)][string]$OutputDirectory,
    [int]$FontSize = 8,
    [float]$OffsetY = 0.0
)

$ErrorActionPreference = 'Stop'
Add-Type -AssemblyName System.Drawing
$scriptDirectory = Split-Path -Parent $MyInvocation.MyCommand.Path
$repository = Resolve-Path (Join-Path $scriptDirectory '..\..')
$data = Get-Content (Join-Path $repository 'text\ar\credits.json') -Raw -Encoding UTF8 | ConvertFrom-Json
if (@($data.entries).Count -ne 20) { throw 'Arabic credits must contain exactly 20 entries' }
$resolvedFont = Resolve-Path -LiteralPath $FontPath
New-Item -ItemType Directory -Force -Path $OutputDirectory | Out-Null
$collection = New-Object System.Drawing.Text.PrivateFontCollection
$collection.AddFontFile($resolvedFont)
$font = New-Object System.Drawing.Font($collection.Families[0], (2 * $FontSize), [System.Drawing.FontStyle]::Regular, [System.Drawing.GraphicsUnit]::Pixel)
$format = [System.Drawing.StringFormat]::GenericTypographic
$format.FormatFlags = $format.FormatFlags -bor [System.Drawing.StringFormatFlags]::DirectionRightToLeft -bor [System.Drawing.StringFormatFlags]::NoClip
$utf8NoBom = New-Object System.Text.UTF8Encoding($false)
$lines = New-Object System.Collections.Generic.List[string]
$roleDls = @(); $roleWidths = @(); $roleCounts = @()
$nameDls = @(); $nameWidths = @(); $nameCounts = @()

function Add-Texture([string]$Name, [string]$Text) {
    $measureBitmap = New-Object System.Drawing.Bitmap(1, 1)
    $measureGraphics = [System.Drawing.Graphics]::FromImage($measureBitmap)
    try {
        $measureGraphics.TextRenderingHint = [System.Drawing.Text.TextRenderingHint]::AntiAliasGridFit
        $measured = [int][Math]::Ceiling($measureGraphics.MeasureString($Text, $font, 4096, $format).Width / 2) + 2
    } finally { $measureGraphics.Dispose(); $measureBitmap.Dispose() }
    if ($measured -gt 144) { throw "$Name is too wide for a credits column: $Text ($measured px)" }
    $width = [int]([Math]::Ceiling($measured / 8.0) * 8)
    $bitmap = New-Object System.Drawing.Bitmap(($width * 2), 32, [System.Drawing.Imaging.PixelFormat]::Format32bppArgb)
    $graphics = [System.Drawing.Graphics]::FromImage($bitmap)
    try {
        $graphics.Clear([System.Drawing.Color]::Transparent)
        $graphics.TextRenderingHint = [System.Drawing.Text.TextRenderingHint]::AntiAliasGridFit
        $graphics.DrawString($Text, $font, [System.Drawing.Brushes]::White, [float](($width - 1) * 2), ($OffsetY * 2), $format)
        $bytes = New-Object System.Collections.Generic.List[byte]
        for ($y = 0; $y -lt 32; $y++) { for ($x = 0; $x -lt $width * 2; $x++) {
            $bytes.Add([byte](0xF0 -bor [Math]::Round($bitmap.GetPixel($x, $y).A * 15 / 255)))
        }}
    } finally { $graphics.Dispose(); $bitmap.Dispose() }
    $texture = "texture_arabic_credit_$Name"; $vertices = "vertex_arabic_credit_$Name"; $dl = "dl_arabic_credit_$Name"
    $values = ($bytes | ForEach-Object { '0x{0:X2}' -f $_ }) -join ', '
    $quadWidth = $width
    $textureWidth = $width * 2
    $textureHeight = 32
    $height = 16
    $resolution = 2
    $tileHeight = if ($textureWidth -le 256) { 8 } else { 4 }
    $textureMaxS = ($textureWidth - 1) -shl 5
    $textureMaxT = ($tileHeight - 1) -shl 5
    $lineWords = $textureWidth / 8

    $lines.Add("ALIGNED8 static const u8 $texture`[] = { $values };")
    $lines.Add("static const Vtx $vertices`[] = {")
    for ($row = 0; $row -lt $textureHeight; $row += $tileHeight) {
        $top = $height - $row / $resolution
        $bottom = $top - $tileHeight / $resolution
        $lines.Add("    {{{ 0, $bottom, 0 }, 0, { 0, $textureMaxT }, { 0xff, 0xff, 0xff, 0xff }}},")
        $lines.Add("    {{{ $quadWidth, $bottom, 0 }, 0, { $textureMaxS, $textureMaxT }, { 0xff, 0xff, 0xff, 0xff }}},")
        $lines.Add("    {{{ $quadWidth, $top, 0 }, 0, { $textureMaxS, 0 }, { 0xff, 0xff, 0xff, 0xff }}},")
        $lines.Add("    {{{ 0, $top, 0 }, 0, { 0, 0 }, { 0xff, 0xff, 0xff, 0xff }}},")
    }
    $lines.Add('};')
    $lines.Add("static const Gfx $dl`[] = {")
    for ($row = 0; $row -lt $textureHeight; $row += $tileHeight) {
        $texturePointer = if ($row -eq 0) { $texture } else { "$texture + $($row * $textureWidth)" }
        $vertexPointer = if ($row -eq 0) { $vertices } else { "$vertices + $([int]($row / $tileHeight) * 4)" }
        $lines.Add("    gsDPPipeSync(),")
        $lines.Add("    gsDPSetTextureImage(G_IM_FMT_IA, G_IM_SIZ_8b, 1, $texturePointer),")
        $lines.Add("    gsDPSetTile(G_IM_FMT_IA, G_IM_SIZ_8b, 0, 0, G_TX_LOADTILE, 0, G_TX_CLAMP, G_TX_NOMASK, G_TX_NOLOD, G_TX_CLAMP, G_TX_NOMASK, G_TX_NOLOD),")
        $lines.Add("    gsDPLoadSync(),")
        $lines.Add("    gsDPLoadBlock(G_TX_LOADTILE, 0, 0, $($textureWidth * $tileHeight - 1), CALC_DXT($textureWidth, G_IM_SIZ_8b_BYTES)),")
        $lines.Add("    gsDPSetTile(G_IM_FMT_IA, G_IM_SIZ_8b, $lineWords, 0, G_TX_RENDERTILE, 0, G_TX_CLAMP, G_TX_NOMASK, G_TX_NOLOD, G_TX_CLAMP, G_TX_NOMASK, G_TX_NOLOD),")
        $lines.Add("    gsDPSetTileSize(G_TX_RENDERTILE, 0, 0, $(($textureWidth - 1) -shl 2), $(($tileHeight - 1) -shl 2)),")
        $lines.Add("    gsSPVertex($vertexPointer, 4, 0),")
        $lines.Add("    gsSP2Triangles(0, 1, 2, 0, 0, 2, 3, 0),")
    }
    $lines.Add("    gsSPEndDisplayList(),")
    $lines.Add('};')
    $lines.Add('')
    return @{ dl = $dl; width = $width }
}

for ($entryIndex = 0; $entryIndex -lt 20; $entryIndex++) {
    $entry = $data.entries[$entryIndex]
    if (@($entry.roles).Count -gt 2 -or @($entry.names).Count -gt 3) { throw "Credits entry $($entryIndex + 1) exceeds table bounds" }
    $rD=@();$rW=@(); foreach($text in $entry.roles){$v=Add-Texture ("e{0:D2}_role_{1}" -f ($entryIndex+1),$rD.Count) ([string]$text);$rD+=$v.dl;$rW+=$v.width}
    $nD=@();$nW=@(); foreach($text in $entry.names){$v=Add-Texture ("e{0:D2}_name_{1}" -f ($entryIndex+1),$nD.Count) ([string]$text);$nD+=$v.dl;$nW+=$v.width}
    $roleDls+=,@($rD);$roleWidths+=,@($rW);$roleCounts+=@($entry.roles).Count
    $nameDls+=,@($nD);$nameWidths+=,@($nW);$nameCounts+=@($entry.names).Count
}

$lines.Add('const Gfx *const arabic_credit_role_table[20][2] = {')
foreach($row in $roleDls){$vals=@($row)+@(0,0);$lines.Add("    { $($vals[0]), $($vals[1]) },")};$lines.Add('};')
$lines.Add('const u16 arabic_credit_role_width[20][2] = {')
foreach($row in $roleWidths){$vals=@($row)+@(0,0);$lines.Add("    { $($vals[0]), $($vals[1]) },")};$lines.Add('};')
$lines.Add('const u8 arabic_credit_role_count[20] = { ' + ($roleCounts -join ', ') + ' };')
$lines.Add('const Gfx *const arabic_credit_name_table[20][3] = {')
foreach($row in $nameDls){$vals=@($row)+@(0,0,0);$lines.Add("    { $($vals[0]), $($vals[1]), $($vals[2]) },")};$lines.Add('};')
$lines.Add('const u16 arabic_credit_name_width[20][3] = {')
foreach($row in $nameWidths){$vals=@($row)+@(0,0,0);$lines.Add("    { $($vals[0]), $($vals[1]), $($vals[2]) },")};$lines.Add('};')
$lines.Add('const u8 arabic_credit_name_count[20] = { ' + ($nameCounts -join ', ') + ' };')
[System.IO.File]::WriteAllLines((Join-Path $OutputDirectory 'credit_textures.inc.c'), $lines, $utf8NoBom)
$format.Dispose();$font.Dispose();$collection.Dispose()
Write-Output "Generated 20 Arabic credit entries"
