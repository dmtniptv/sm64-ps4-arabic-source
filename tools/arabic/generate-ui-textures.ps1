param(
    [Parameter(Mandatory = $true)][string]$FontPath,
    [Parameter(Mandatory = $true)][string]$OutputDirectory,
    [int]$FontSize = 9,
    [float]$OffsetY = 0.0
)

$ErrorActionPreference = 'Stop'
Add-Type -AssemblyName System.Drawing

$scriptDirectory = Split-Path -Parent $MyInvocation.MyCommand.Path
$repository = Resolve-Path (Join-Path $scriptDirectory '..\..')
$entries = Get-Content (Join-Path $repository 'text\ar\ui.json') -Raw -Encoding UTF8 | ConvertFrom-Json
$overlays = Get-Content (Join-Path $repository 'text\ar\generated\overlay-labels.json') -Raw -Encoding UTF8 | ConvertFrom-Json
$allEntries = @($entries.PSObject.Properties) + @($overlays.PSObject.Properties)
$resolvedFont = Resolve-Path -LiteralPath $FontPath
New-Item -ItemType Directory -Force -Path $OutputDirectory | Out-Null

$collection = New-Object System.Drawing.Text.PrivateFontCollection
$collection.AddFontFile($resolvedFont)
$format = [System.Drawing.StringFormat]::GenericTypographic
$format.FormatFlags = $format.FormatFlags -bor [System.Drawing.StringFormatFlags]::DirectionRightToLeft -bor [System.Drawing.StringFormatFlags]::NoClip
$utf8NoBom = New-Object System.Text.UTF8Encoding($false)
$lines = New-Object System.Collections.Generic.List[string]
$displayLists = @()
$widths = @()
$heights = @()
$fonts = @{}

foreach ($property in $allEntries) {
    $name = $property.Name
    $text = [string]$property.Value.text
    $width = [int]$property.Value.width
    $height = if ($null -ne $property.Value.height) { [int]$property.Value.height } else { 16 }
    $entryFontSize = if ($null -ne $property.Value.fontSize) { [int]$property.Value.fontSize } else { $FontSize }
    $entryOffsetY = if ($null -ne $property.Value.offsetY) { [float]$property.Value.offsetY } elseif ($entryFontSize -lt $FontSize) { 1.0 } else { $OffsetY }
    $resolution = 2
    $quadWidth = [int]([Math]::Ceiling($width / 8.0) * 8)
    $textureWidth = $quadWidth * $resolution
    $textureHeight = $height * $resolution
    $tileHeight = if ($textureWidth -le 256) { 8 } else { 4 }
    if ($textureWidth * $tileHeight -gt 2048 -or $textureHeight % $tileHeight -ne 0) {
        throw "$name exceeds the high-resolution tile layout"
    }
    $entryFontSize *= $resolution
    $entryOffsetY *= $resolution
    if ($height -eq 12) { $entryOffsetY = -1.0 }
    if ($name -match '^(opening|startup)_') { $entryOffsetY = -2.0 }
    if ($name.StartsWith('overlay_')) { $entryOffsetY = 1.0 }
    if (-not $fonts.ContainsKey($entryFontSize)) {
        $fonts[$entryFontSize] = New-Object System.Drawing.Font($collection.Families[0], $entryFontSize, [System.Drawing.FontStyle]::Regular, [System.Drawing.GraphicsUnit]::Pixel)
    }
    $entryFont = $fonts[$entryFontSize]

    $measureBitmap = New-Object System.Drawing.Bitmap(1, 1)
    $measureGraphics = [System.Drawing.Graphics]::FromImage($measureBitmap)
    try {
        $measureGraphics.TextRenderingHint = [System.Drawing.Text.TextRenderingHint]::AntiAliasGridFit
        $measuredWidth = $measureGraphics.MeasureString($text, $entryFont, 4096, $format).Width
        while ($name.StartsWith('overlay_') -and $measuredWidth -gt $textureWidth - 4 -and $entryFontSize -gt 14) {
            $entryFontSize -= 2
            if (-not $fonts.ContainsKey($entryFontSize)) {
                $fonts[$entryFontSize] = New-Object System.Drawing.Font($collection.Families[0], $entryFontSize, [System.Drawing.FontStyle]::Regular, [System.Drawing.GraphicsUnit]::Pixel)
            }
            $entryFont = $fonts[$entryFontSize]
            $measuredWidth = $measureGraphics.MeasureString($text, $entryFont, 4096, $format).Width
        }
    }
    finally {
        $measureGraphics.Dispose()
        $measureBitmap.Dispose()
    }
    if ($measuredWidth -gt $width * $resolution) { throw "$name is too wide for ${width}px: $text" }

    $bitmap = New-Object System.Drawing.Bitmap($textureWidth, $textureHeight, [System.Drawing.Imaging.PixelFormat]::Format32bppArgb)
    $graphics = [System.Drawing.Graphics]::FromImage($bitmap)
    try {
        $graphics.Clear([System.Drawing.Color]::Transparent)
        $graphics.TextRenderingHint = [System.Drawing.Text.TextRenderingHint]::AntiAliasGridFit
        $drawX = if ($property.Value.centerInk -or $name -match '^(opening|startup|overlay)_') { ($textureWidth + $measuredWidth) / 2 } else { $width * $resolution }
        $graphics.DrawString($text, $entryFont, [System.Drawing.Brushes]::White, [float]$drawX, $entryOffsetY, $format)
        $bytes = New-Object System.Collections.Generic.List[byte]
        for ($y = 0; $y -lt $textureHeight; $y++) {
            for ($x = 0; $x -lt $textureWidth; $x++) {
                $alpha4 = [Math]::Round($bitmap.GetPixel($x, $y).A * 15 / 255)
                $bytes.Add([byte](0xF0 -bor $alpha4))
            }
        }
    }
    finally {
        $graphics.Dispose()
        $bitmap.Dispose()
    }

    $textureName = "texture_arabic_ui_$name"
    $vertexName = "vertex_arabic_ui_$name"
    $displayListName = "dl_arabic_ui_$name"
    $values = ($bytes | ForEach-Object { '0x{0:X2}' -f $_ }) -join ', '
    $textureMaxS = ($textureWidth - 1) -shl 5
    $textureMaxT = ($tileHeight - 1) -shl 5
    $lineWords = $textureWidth / 8

    $lines.Add("ALIGNED8 static const u8 $textureName`[] = { $values };")
    $lines.Add("static const Vtx $vertexName`[] = {")
    for ($row = 0; $row -lt $textureHeight; $row += $tileHeight) {
        $top = $height - $row / $resolution
        $bottom = $top - $tileHeight / $resolution
        $lines.Add("    {{{ 0, $bottom, 0 }, 0, { 0, $textureMaxT }, { 0xff, 0xff, 0xff, 0xff }}},")
        $lines.Add("    {{{ $quadWidth, $bottom, 0 }, 0, { $textureMaxS, $textureMaxT }, { 0xff, 0xff, 0xff, 0xff }}},")
        $lines.Add("    {{{ $quadWidth, $top, 0 }, 0, { $textureMaxS, 0 }, { 0xff, 0xff, 0xff, 0xff }}},")
        $lines.Add("    {{{ 0, $top, 0 }, 0, { 0, 0 }, { 0xff, 0xff, 0xff, 0xff }}},")
    }
    $lines.Add('};')
    $lines.Add("static const Gfx $displayListName`[] = {")
    for ($row = 0; $row -lt $textureHeight; $row += $tileHeight) {
        $texturePointer = if ($row -eq 0) { $textureName } else { "$textureName + $($row * $textureWidth)" }
        $vertexPointer = if ($row -eq 0) { $vertexName } else { "$vertexName + $([int]($row / $tileHeight) * 4)" }
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
    $displayLists += $displayListName
    $widths += $quadWidth
    $heights += $height
}

$lines.Add('const Gfx *const arabic_ui_text_table[ARABIC_UI_TEXT_COUNT] = {')
foreach ($displayList in $displayLists) { $lines.Add("    $displayList,") }
$lines.Add('};')
$lines.Add('const u16 arabic_ui_text_width[ARABIC_UI_TEXT_COUNT] = {')
foreach ($width in $widths) { $lines.Add("    $width,") }
$lines.Add('};')
$lines.Add('const u8 arabic_ui_text_height[ARABIC_UI_TEXT_COUNT] = {')
foreach ($height in $heights) { $lines.Add("    $height,") }
$lines.Add('};')

[System.IO.File]::WriteAllLines((Join-Path $OutputDirectory 'ui_textures.inc.c'), $lines, $utf8NoBom)
$header = New-Object System.Collections.Generic.List[string]
$header.Add('// Generated from text/ar/ui.json. Do not edit by hand.')
$header.Add('enum ArabicUiTextId {')
foreach ($property in $allEntries) { $header.Add("    ARABIC_UI_$($property.Name.ToUpperInvariant()),") }
$header.Add('    ARABIC_UI_TEXT_COUNT,')
$header.Add('};')
[System.IO.File]::WriteAllLines((Join-Path $OutputDirectory 'ui_text_ids.h'), $header, $utf8NoBom)
$format.Dispose()
foreach ($cachedFont in $fonts.Values) { $cachedFont.Dispose() }
$collection.Dispose()
Write-Output "Generated $($displayLists.Count) Arabic UI textures"
