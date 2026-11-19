param(
    [Parameter(Mandatory = $true)][string]$FontPath,
    [Parameter(Mandatory = $true)][string]$OutputDirectory,
    [int]$FontSize = 14,
    [float]$OffsetX = -1.0,
    [float]$OffsetY = -2.0,
    [ValidateRange(0, 255)][int]$AlphaThreshold = 128,
    [ValidateRange(0, 15)][int]$JoinRow = 14,
    [ValidateRange(1, 3)][int]$JoinThickness = 2
)

$ErrorActionPreference = 'Stop'
Add-Type -AssemblyName System.Drawing

$scriptDirectory = Split-Path -Parent $MyInvocation.MyCommand.Path
$json = node (Join-Path $scriptDirectory 'write-glyph-manifest.mjs')
$glyphs = $json | ConvertFrom-Json

New-Item -ItemType Directory -Force -Path $OutputDirectory | Out-Null
$collection = New-Object System.Drawing.Text.PrivateFontCollection
$collection.AddFontFile((Resolve-Path -LiteralPath $FontPath))
$font = New-Object System.Drawing.Font($collection.Families[0], $FontSize, [System.Drawing.FontStyle]::Regular, [System.Drawing.GraphicsUnit]::Pixel)
$format = [System.Drawing.StringFormat]::GenericTypographic
$format.FormatFlags = $format.FormatFlags -bor [System.Drawing.StringFormatFlags]::NoClip

$glyphLines = New-Object System.Collections.Generic.List[string]
$lut = @('0x0') * 256
for ($i = 0; $i -lt 10; $i++) { $lut[$i] = "texture_font_char_us_$i" }
for ($i = 0; $i -lt 26; $i++) {
    $lut[0x0A + $i] = 'texture_font_char_us_' + [char]([int][char]'A' + $i)
    $lut[0x24 + $i] = 'texture_font_char_us_' + [char]([int][char]'a' + $i)
}
$lut[0x3E] = 'texture_font_char_us_apostrophe'
$lut[0x3F] = 'texture_font_char_us_period'
$lut[0x50] = 'texture_font_char_us_button_C_up'
$lut[0x51] = 'texture_font_char_us_button_C_down'
$lut[0x52] = 'texture_font_char_us_button_C_left'
$lut[0x53] = 'texture_font_char_us_button_C_right'
$lut[0x54] = 'texture_font_char_us_button_A'
$lut[0x55] = 'texture_font_char_us_button_B'
$lut[0x56] = 'texture_font_char_us_button_C'
$lut[0x57] = 'texture_font_char_us_button_Z'
$lut[0x58] = 'texture_font_char_us_button_R'
$lut[0x6E] = 'texture_font_char_us_period'
$lut[0x6F] = 'texture_font_char_us_comma'
$lut[0xD0] = 'texture_font_char_us_slash'
$lut[0xE1] = 'texture_font_char_us_open_parentheses'
$lut[0xE2] = 'texture_font_char_us_close_open_parentheses'
$lut[0xE3] = 'texture_font_char_us_close_parentheses'
$lut[0xE4] = 'texture_font_char_us_left_right_arrow'
$lut[0xE5] = 'texture_font_char_us_ampersand'
$lut[0xE6] = 'texture_font_char_us_ellipsis'
$lut[0xF2] = 'texture_font_char_us_exclamation'
$lut[0xF3] = 'texture_font_char_us_percent'
$lut[0xF4] = 'texture_font_char_us_question'
$lut[0xF5] = 'texture_font_char_us_double_quote_open'
$lut[0xF6] = 'texture_font_char_us_double_quote_close'
$lut[0xF7] = 'texture_font_char_us_tilde'
$lut[0xF9] = 'texture_font_char_us_coin'
$lut[0xFA] = 'texture_font_char_us_star_filled'
$lut[0xFB] = 'texture_font_char_us_multiply'
$lut[0xFC] = 'texture_font_char_us_interpunct'
$lut[0xFD] = 'texture_font_char_us_star_hollow'

foreach ($glyph in $glyphs) {
    $bitmap = New-Object System.Drawing.Bitmap(8, 16, [System.Drawing.Imaging.PixelFormat]::Format32bppArgb)
    $graphics = [System.Drawing.Graphics]::FromImage($bitmap)
    try {
        $graphics.Clear([System.Drawing.Color]::Transparent)
        $graphics.TextRenderingHint = [System.Drawing.Text.TextRenderingHint]::AntiAliasGridFit
        $graphics.DrawString([string]$glyph.char, $font, [System.Drawing.Brushes]::White, $OffsetX, $OffsetY, $format)
        $mask = [Array]::CreateInstance([bool], 8, 16)
        for ($logicalY = 0; $logicalY -lt 16; $logicalY++) {
            for ($logicalX = 0; $logicalX -lt 8; $logicalX++) {
                $mask[$logicalX, $logicalY] = $bitmap.GetPixel($logicalX, $logicalY).A -ge $AlphaThreshold
            }
        }

        # Contextual Arabic forms need their joining stroke to reach the cell
        # boundary. Font rasterizers preserve side bearings when drawing an
        # isolated glyph, which otherwise leaves a visible gap between two
        # correctly shaped forms in SM64's fixed 8-pixel character cells.
        for ($row = $JoinRow; $row -lt [Math]::Min(16, $JoinRow + $JoinThickness); $row++) {
            if ($glyph.connectLeft) {
                $firstPixel = -1
                for ($x = 0; $x -lt 8; $x++) {
                    if ($mask[$x, $row]) { $firstPixel = $x; break }
                }
                if ($firstPixel -ge 0) {
                    for ($x = 0; $x -le $firstPixel; $x++) { $mask[$x, $row] = $true }
                }
            }
            if ($glyph.connectRight) {
                $lastPixel = -1
                for ($x = 7; $x -ge 0; $x--) {
                    if ($mask[$x, $row]) { $lastPixel = $x; break }
                }
                if ($lastPixel -ge 0) {
                    for ($x = $lastPixel; $x -lt 8; $x++) { $mask[$x, $row] = $true }
                }
            }
        }

        $bytes = New-Object System.Collections.Generic.List[byte]
        # The US renderer displays an 8x16 glyph, but the N64 texture tile is
        # physically 16x8. Its vertices map texture S across screen Y and
        # reversed texture T across screen X. Encode the logical bitmap into
        # that native rotated layout: raw(s, t) = logical(7 - t, s).
        for ($textureY = 0; $textureY -lt 8; $textureY++) {
            for ($textureX = 0; $textureX -lt 16; $textureX += 2) {
                # IA4 is IIIA (three intensity bits and one alpha bit), not a
                # four-bit alpha channel. The original US dialog glyphs use
                # only 0x0 (transparent) and 0xF (opaque white). Threshold the
                # antialiased source before packing; otherwise even a faint
                # edge gets alpha=1 and becomes a solid block in game.
                $logicalX = 7 - $textureY
                $a = if ($mask[$logicalX, $textureX]) { 0xF } else { 0x0 }
                $b = if ($mask[$logicalX, ($textureX + 1)]) { 0xF } else { 0x0 }
                $bytes.Add([byte](($a -shl 4) -bor $b))
            }
        }
        $values = ($bytes | ForEach-Object { '0x{0:X2}' -f $_ }) -join ', '
        $name = "texture_font_char_$($glyph.name)"
        $glyphLines.Add("ALIGNED8 static const u8 $name`[] = { $values };")
        $lut[[int]$glyph.code] = $name
    }
    finally {
        $graphics.Dispose()
        $bitmap.Dispose()
    }
}

$utf8NoBom = New-Object System.Text.UTF8Encoding($false)
[System.IO.File]::WriteAllLines((Join-Path $OutputDirectory 'font_glyphs.inc.c'), $glyphLines, $utf8NoBom)

$lutLines = New-Object System.Collections.Generic.List[string]
for ($i = 0; $i -lt 256; $i += 4) {
    $lutLines.Add('    ' + (($lut[$i..($i + 3)]) -join ', ') + ',')
}
[System.IO.File]::WriteAllLines((Join-Path $OutputDirectory 'font_lut.inc.c'), $lutLines, $utf8NoBom)

$font.Dispose()
$collection.Dispose()
