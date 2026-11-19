param(
    [Parameter(Mandatory = $true)][string]$FontPath,
    [Parameter(Mandatory = $true)][string]$OutputDirectory,
    [ValidateRange(7, 11)][int]$FontSize = 11
)

$ErrorActionPreference = 'Stop'
Add-Type -AssemblyName System.Drawing
Add-Type -AssemblyName System.Security

$scriptDirectory = Split-Path -Parent $MyInvocation.MyCommand.Path
$repository = Resolve-Path (Join-Path $scriptDirectory '..\..')
$translations = Get-Content (Join-Path $repository 'text\ar\translations.json') -Raw -Encoding UTF8 | ConvertFrom-Json
$usDialogs = Get-Content (Join-Path $repository 'text\us\dialogs.h') -Raw -Encoding UTF8
$resolvedFont = Resolve-Path -LiteralPath $FontPath

New-Item -ItemType Directory -Force -Path $OutputDirectory | Out-Null
$collection = New-Object System.Drawing.Text.PrivateFontCollection
$collection.AddFontFile($resolvedFont)
$dialogFonts = @($FontSize..7 | ForEach-Object {
    New-Object System.Drawing.Font($collection.Families[0], (2 * $_), [System.Drawing.FontStyle]::Regular, [System.Drawing.GraphicsUnit]::Pixel)
})
$format = [System.Drawing.StringFormat]::GenericTypographic
$format.FormatFlags = $format.FormatFlags -bor [System.Drawing.StringFormatFlags]::DirectionRightToLeft -bor [System.Drawing.StringFormatFlags]::NoClip
$utf8NoBom = New-Object System.Text.UTF8Encoding($false)
$cLines = New-Object System.Collections.Generic.List[string]
$manifestDialogs = [ordered]@{}
$tableEntries = [ordered]@{}

function Get-Sha256([byte[]]$Bytes) {
    $sha = [System.Security.Cryptography.SHA256]::Create()
    try { return (($sha.ComputeHash($Bytes) | ForEach-Object { $_.ToString('x2') }) -join '') }
    finally { $sha.Dispose() }
}

function Draw-PlayStationButtonIcons(
    [System.Drawing.Graphics]$Graphics,
    [string]$Text,
    [System.Drawing.Font]$TextFont,
    [float]$RightEdge,
    [float]$TextY,
    [System.Drawing.StringFormat]$TextFormat
) {
    # The Arabic font's Unicode multiplication and empty-square glyphs are
    # tiny and ambiguous at PS4 resolution. Locate each glyph in the RTL run,
    # clear it, then draw a consistent 8px PlayStation-style vector icon.
    for ($index = 0; $index -lt $Text.Length; $index++) {
        $symbol = $Text[$index]
        if ($symbol -ne [char]0x00D7 -and $symbol -ne [char]0x25A1) { continue }

        $before = if ($index -gt 0) { $Text.Substring(0, $index) } else { '' }
        $through = $Text.Substring(0, $index + 1)
        $beforeWidth = if ($before.Length -gt 0) {
            $Graphics.MeasureString($before, $TextFont, 4096, $TextFormat).Width
        } else { 0.0 }
        $throughWidth = $Graphics.MeasureString($through, $TextFont, 4096, $TextFormat).Width
        $glyphWidth = [Math]::Max(7.0, $throughWidth - $beforeWidth)
        $centerX = $RightEdge - $beforeWidth - ($glyphWidth / 2.0)
        $factor = if ($TextFont.Size -gt 16) { 2.0 } else { 1.0 }
        $iconLeft = [float]($centerX - 4.0 * $factor)
        $iconTop = [float]($TextY + 4.0 * $factor)

        $oldMode = $Graphics.CompositingMode
        $Graphics.CompositingMode = [System.Drawing.Drawing2D.CompositingMode]::SourceCopy
        if ($factor -eq 1) {
            $Graphics.FillRectangle([System.Drawing.Brushes]::Transparent, $iconLeft - 1, $iconTop - 2, 10, 12)
        } else {
            $Graphics.FillRectangle([System.Drawing.Brushes]::Transparent, [float]$centerX - [float]($glyphWidth / 2), $iconTop - 2 * $factor, [float]$glyphWidth, 12 * $factor)
        }
        $Graphics.CompositingMode = [System.Drawing.Drawing2D.CompositingMode]::SourceOver
        $pen = New-Object System.Drawing.Pen([System.Drawing.Color]::White, (1.5 * $factor))
        try {
            if ($symbol -eq [char]0x00D7) {
                $Graphics.DrawLine($pen, $iconLeft, $iconTop, $iconLeft + 8 * $factor, $iconTop + 8 * $factor)
                $Graphics.DrawLine($pen, $iconLeft + 8 * $factor, $iconTop, $iconLeft, $iconTop + 8 * $factor)
            } else {
                $Graphics.DrawRectangle($pen, $iconLeft + 0.5 * $factor, $iconTop + 0.5 * $factor, 7 * $factor, 7 * $factor)
            }
        }
        finally {
            $pen.Dispose()
            $Graphics.CompositingMode = $oldMode
        }
    }
}

foreach ($property in $translations.dialogs.PSObject.Properties) {
    $id = $property.Name
    $resolution = 2
    $rasterY = -3.0
    $metadata = [regex]::Match($usDialogs, "DEFINE_DIALOG\($id,\s*\d+,\s*(\d+),\s*\d+,\s*(\d+),")
    if (-not $metadata.Success) { throw "Could not find metadata for $id" }
    $linesPerBox = [int]$metadata.Groups[1].Value
    # The final DEFINE_DIALOG field is the vertical screen position despite
    # being named `width` in the original structure. US dialog text is drawn
    # inside the fixed 132px box; keep a small right margin for RTL lines.
    $dialogWidth = 128
    $textureWidth = $dialogWidth * $resolution
    $textureHeight = 16 * $resolution
    $logicalLines = [string]$property.Value -split "`r?`n"
    if ($logicalLines.Count -gt 32) { throw "$id has $($logicalLines.Count) lines; the generated table supports at most 32" }

    $dialogManifest = [ordered]@{
        width = $dialogWidth
        textureWidth = $textureWidth
        linesPerBox = $linesPerBox
        lines = @()
    }
    $dialogManifest.textureHeight = $textureHeight
    $displayLists = @()

    for ($lineIndex = 0; $lineIndex -lt $logicalLines.Count; $lineIndex++) {
        $logicalText = $logicalLines[$lineIndex]
        # Slash runs are SM64 choice-layout controls. Keep them in the hidden
        # byte stream, but render only the visible PS4-facing labels.
        $renderText = $logicalText -replace '////', '       ' -replace '//', ''
        $measurementBitmap = New-Object System.Drawing.Bitmap(1, 1)
        $measurementGraphics = [System.Drawing.Graphics]::FromImage($measurementBitmap)
        try {
            $measurementGraphics.TextRenderingHint = [System.Drawing.Text.TextRenderingHint]::AntiAliasGridFit
            foreach ($lineFont in $dialogFonts) {
                $measuredWidth = $measurementGraphics.MeasureString($renderText, $lineFont, 4096, $format).Width / $resolution
                if ($measuredWidth -le $dialogWidth) { break }
            }
        }
        finally {
            $measurementGraphics.Dispose()
            $measurementBitmap.Dispose()
        }
        if ($measuredWidth -gt $dialogWidth) {
            throw "$id line $($lineIndex + 1) is $([Math]::Round($measuredWidth, 1))px wide, exceeding its ${dialogWidth}px box: $logicalText"
        }

        $verticalPadding = 8
        $canvasHeight = $textureHeight + 2 * $verticalPadding
        $bitmap = New-Object System.Drawing.Bitmap($textureWidth, $canvasHeight, [System.Drawing.Imaging.PixelFormat]::Format32bppArgb)
        $graphics = [System.Drawing.Graphics]::FromImage($bitmap)
        try {
            $graphics.Clear([System.Drawing.Color]::Transparent)
            $graphics.TextRenderingHint = [System.Drawing.Text.TextRenderingHint]::AntiAliasGridFit
            $drawY = $rasterY + $verticalPadding
            $graphics.DrawString($renderText, $lineFont, [System.Drawing.Brushes]::White, [float]$textureWidth, $drawY, $format)
            Draw-PlayStationButtonIcons $graphics $renderText $lineFont ([float]$textureWidth) $drawY $format
            $pixels = [byte[]]::new($textureWidth * $canvasHeight)
            $firstInk = $canvasHeight
            $lastInk = -1
            for ($y = 0; $y -lt $canvasHeight; $y++) {
                for ($x = 0; $x -lt $textureWidth; $x++) {
                    $alpha = $bitmap.GetPixel($x, $y).A
                    # Reinforce fine strokes and dots while retaining soft edges.
                    $alpha = [Math]::Min(255, $alpha * 1.18)
                    $alpha4 = [Math]::Round($alpha * 15 / 255)
                    $pixels[$y * $textureWidth + $x] = [byte](0xF0 -bor $alpha4)
                    if ($alpha4 -ne 0) {
                        $firstInk = [Math]::Min($firstInk, $y)
                        $lastInk = $y
                    }
                }
            }
            $startY = $verticalPadding
            if ($lastInk -ge 0) {
                if ($lastInk - $firstInk + 1 -gt $textureHeight - 2) {
                    throw "$id line $($lineIndex + 1) is too tall: $logicalText"
                }
                $startY = [Math]::Max($lastInk - $textureHeight + 2, [Math]::Min($firstInk - 1, $startY))
            }
            $bytes = [byte[]]::new($textureWidth * $textureHeight)
            [Array]::Copy($pixels, $startY * $textureWidth, $bytes, 0, $bytes.Length)
        }
        finally {
            $graphics.Dispose()
            $bitmap.Dispose()
        }

        $baseName = "arabic_dialog_$($id.Substring(7))_line_$lineIndex"
        $textureName = "texture_$baseName"
        $vertexName = "vertex_$baseName"
        $displayListName = "dl_$baseName"
        $values = ($bytes | ForEach-Object { '0x{0:X2}' -f $_ }) -join ', '
        $textureMaxS = ($textureWidth - 1) -shl 5
        $tileHeight = [int](2048 / $textureWidth)
        $textureMaxT = ($tileHeight - 1) -shl 5
        $lineWords = $textureWidth / 8

        $cLines.Add("ALIGNED8 static const u8 $textureName`[] = { $values };")
        $cLines.Add("static const Vtx $vertexName`[] = {")
        for ($row = 0; $row -lt $textureHeight; $row += $tileHeight) {
            $top = 16 - $row / $resolution
            $bottom = $top - $tileHeight / $resolution
            $cLines.Add("    {{{ 0, $bottom, 0 }, 0, { 0, $textureMaxT }, { 0xff, 0xff, 0xff, 0xff }}},")
            $cLines.Add("    {{{ $dialogWidth, $bottom, 0 }, 0, { $textureMaxS, $textureMaxT }, { 0xff, 0xff, 0xff, 0xff }}},")
            $cLines.Add("    {{{ $dialogWidth, $top, 0 }, 0, { $textureMaxS, 0 }, { 0xff, 0xff, 0xff, 0xff }}},")
            $cLines.Add("    {{{ 0, $top, 0 }, 0, { 0, 0 }, { 0xff, 0xff, 0xff, 0xff }}},")
        }
        $cLines.Add('};')
        $cLines.Add("static const Gfx $displayListName`[] = {")
        for ($row = 0; $row -lt $textureHeight; $row += $tileHeight) {
            $texturePointer = if ($row -eq 0) { $textureName } else { "$textureName + $($row * $textureWidth)" }
            $vertexPointer = if ($row -eq 0) { $vertexName } else { "$vertexName + $([int]($row / $tileHeight) * 4)" }
            $cLines.Add("    gsDPPipeSync(),")
            $cLines.Add("    gsDPSetTextureImage(G_IM_FMT_IA, G_IM_SIZ_8b, 1, $texturePointer),")
            $cLines.Add("    gsDPSetTile(G_IM_FMT_IA, G_IM_SIZ_8b, 0, 0, G_TX_LOADTILE, 0, G_TX_CLAMP, G_TX_NOMASK, G_TX_NOLOD, G_TX_CLAMP, G_TX_NOMASK, G_TX_NOLOD),")
            $cLines.Add("    gsDPLoadSync(),")
            $cLines.Add("    gsDPLoadBlock(G_TX_LOADTILE, 0, 0, $($textureWidth * $tileHeight - 1), CALC_DXT($textureWidth, G_IM_SIZ_8b_BYTES)),")
            $cLines.Add("    gsDPSetTile(G_IM_FMT_IA, G_IM_SIZ_8b, $lineWords, 0, G_TX_RENDERTILE, 0, G_TX_CLAMP, G_TX_NOMASK, G_TX_NOLOD, G_TX_CLAMP, G_TX_NOMASK, G_TX_NOLOD),")
            $cLines.Add("    gsDPSetTileSize(G_TX_RENDERTILE, 0, 0, $(($textureWidth - 1) -shl 2), $(($tileHeight - 1) -shl 2)),")
            $cLines.Add("    gsSPVertex($vertexPointer, 4, 0),")
            $cLines.Add("    gsSP2Triangles(0, 1, 2, 0, 0, 2, 3, 0),")
        }
        $cLines.Add("    gsSPEndDisplayList(),")
        $cLines.Add('};')
        $cLines.Add('')

        $displayLists += $displayListName
        $dialogManifest.lines += [ordered]@{
            text = $logicalText
            measuredWidth = [Math]::Round($measuredWidth, 2)
            texture = $textureName
            textureBytes = $bytes.Count
            textureSha256 = Get-Sha256 $bytes
        }
    }

    $numericId = [int]$id.Substring(7)
    $tableEntries[[string]$numericId] = $displayLists
    $manifestDialogs[$id] = $dialogManifest
}

$cLines.Add('const Gfx *const arabic_dialog_line_table[256][32] = {')
foreach ($entry in $tableEntries.GetEnumerator()) {
    $cLines.Add("    [$($entry.Key)] = { $($entry.Value -join ', ') },")
}
$cLines.Add('};')
$cLines.Add('const u8 arabic_dialog_line_count[256] = {')
foreach ($entry in $tableEntries.GetEnumerator()) {
    $cLines.Add("    [$($entry.Key)] = $($entry.Value.Count),")
}
$cLines.Add('};')

$fontBytes = [System.IO.File]::ReadAllBytes($resolvedFont)
$manifest = [ordered]@{
    format = 'IA8'
    height = 16
    fontFamily = $collection.Families[0].Name
    fontSize = $FontSize
    fontSha256 = Get-Sha256 $fontBytes
    dialogs = $manifestDialogs
}

[System.IO.File]::WriteAllLines((Join-Path $OutputDirectory 'dialog_line_textures.inc.c'), $cLines, $utf8NoBom)
[System.IO.File]::WriteAllText((Join-Path $OutputDirectory 'dialog_line_manifest.json'), ($manifest | ConvertTo-Json -Depth 8), $utf8NoBom)

$format.Dispose()
foreach ($dialogFont in $dialogFonts) { $dialogFont.Dispose() }
$collection.Dispose()
Write-Output "Generated full-line Arabic textures for $($manifestDialogs.Count) dialogs"
