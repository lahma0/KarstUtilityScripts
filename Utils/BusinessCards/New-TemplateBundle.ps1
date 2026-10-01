<#
.SYNOPSIS
    Deduplicates and compresses the SVG business card templates into a bundle embedded in BusinessCardCustomizer.html.
.DESCRIPTION
    Recursively scans a templates directory for "<company>/.../back|front/*.svg" files. Since these
    templates are typically near-identical copies of one another (same background artwork, only a
    small region differs per variant), each file's bytes are split into content-defined chunks using a
    rolling hash (Gear/FastCDC-style), so chunk boundaries re-synchronize after any insertion or
    deletion instead of drifting out of alignment like fixed-offset chunking would. Chunks are hashed
    (SHA-256) and deduplicated into a single shared asset pool, so identical content across many
    templates is stored only once. The resulting manifest (asset pool + per-file chunk index lists) is
    JSON-serialized, gzip-compressed, base64-encoded, and written into the TEMPLATE_BUNDLE_BASE64
    constant inside BusinessCardCustomizer.html so the page loads templates automatically without a
    folder picker.
.PARAMETER TemplatesRoot
    Path to the templates directory. Defaults to the 'templates' folder next to this script.
.PARAMETER FontsRoot
    Path to a directory containing .ttf font files to embed alongside the templates (matched at runtime
    against @font-face 'font-family' names and their alternate/alias names declared in each SVG's
    stylesheet). Defaults to the 'assets/fonts' folder next to this script. If the directory does not
    exist, font embedding is skipped with a warning.
.PARAMETER HtmlPath
    Path to BusinessCardCustomizer.html. Defaults to the file next to this script.
.PARAMETER MinChunkSize
    Minimum content-defined chunk size in bytes. Defaults to 1024.
.PARAMETER MaxChunkSize
    Maximum content-defined chunk size in bytes (forced cut point). Defaults to 32768.
.PARAMETER AverageChunkBits
    Number of mask bits used to target an average chunk size of 2^AverageChunkBits bytes. Defaults to 12 (4096 bytes).
.EXAMPLE
    .\New-TemplateBundle.ps1
    Rebuilds the embedded template bundle using the default paths.
#>
[CmdletBinding()]
param(
    [string]$TemplatesRoot = (Join-Path $PSScriptRoot "templates"),
    [string]$FontsRoot = (Join-Path $PSScriptRoot "assets/fonts"),
    [string]$HtmlPath = (Join-Path $PSScriptRoot "BusinessCardCustomizer.html"),
    [int]$MinChunkSize = 1024,
    [int]$MaxChunkSize = 32768,
    [int]$AverageChunkBits = 12
)

$ErrorActionPreference = "Stop"

if (-not (Test-Path $TemplatesRoot)) {
    throw "Templates directory not found: $TemplatesRoot"
}
if (-not (Test-Path $HtmlPath)) {
    throw "HTML file not found: $HtmlPath"
}

$templatesRootFull = (Resolve-Path $TemplatesRoot).Path
$svgFiles = Get-ChildItem -Path $templatesRootFull -Recurse -Filter *.svg -File
if (-not $svgFiles) {
    throw "No .svg files found under $templatesRootFull"
}

# --- Content-defined chunking helper (Gear/FastCDC-style rolling hash), compiled for speed ---
Add-Type -Language CSharp -TypeDefinition @"
using System;
using System.Collections.Generic;

public static class ChunkingHelper
{
    private static readonly ulong[] Gear = BuildGearTable();

    private static ulong[] BuildGearTable()
    {
        var table = new ulong[256];
        var rng = new Random(1234567);
        var buffer = new byte[8];
        for (int i = 0; i < 256; i++)
        {
            rng.NextBytes(buffer);
            table[i] = BitConverter.ToUInt64(buffer, 0);
        }
        return table;
    }

    public static List<int> GetChunkLengths(byte[] data, int minSize, int maxSize, int maskBits)
    {
        var lengths = new List<int>();
        ulong mask = (1UL << maskBits) - 1;
        int n = data.Length;
        int start = 0;
        ulong hash = 0;
        for (int i = 0; i < n; i++)
        {
            hash = (hash << 1) + Gear[data[i]];
            int size = i - start + 1;
            if ((size >= minSize && (hash & mask) == 0) || size >= maxSize)
            {
                lengths.Add(size);
                start = i + 1;
                hash = 0;
            }
        }
        if (start < n)
        {
            lengths.Add(n - start);
        }
        return lengths;
    }
}
"@

# --- Deduplication state ---
$sha256 = [System.Security.Cryptography.SHA256]::Create()
$chunkIndexByHash = @{}
$uniqueChunks = [System.Collections.Generic.List[byte[]]]::new()
$totalRawBytes = 0

function Get-ChunkIndices {
    param([byte[]]$Bytes)

    $indices = [System.Collections.Generic.List[int]]::new()
    $chunkLens = [ChunkingHelper]::GetChunkLengths($Bytes, $MinChunkSize, $MaxChunkSize, $AverageChunkBits)

    $offset = 0
    foreach ($len in $chunkLens) {
        $chunk = [byte[]]::new($len)
        [System.Array]::Copy($Bytes, $offset, $chunk, 0, $len)

        $hashBytes = $sha256.ComputeHash($chunk)
        $hashHex = [System.BitConverter]::ToString($hashBytes)

        if ($chunkIndexByHash.ContainsKey($hashHex)) {
            $indices.Add($chunkIndexByHash[$hashHex])
        } else {
            $newIndex = $uniqueChunks.Count
            $uniqueChunks.Add($chunk)
            $chunkIndexByHash[$hashHex] = $newIndex
            $indices.Add($newIndex)
        }

        $offset += $len
    }

    return , $indices.ToArray()
}

$companies = [ordered]@{}

foreach ($file in $svgFiles) {
    $relativePath = $file.FullName.Substring($templatesRootFull.Length).TrimStart('\', '/')
    $segments = $relativePath -split '[\\/]' | Where-Object { $_ -ne '' }
    if ($segments.Count -lt 2) {
        continue
    }

    $companyName = $segments[0]
    $subPath = @()
    if ($segments.Count -gt 2) {
        $subPath = $segments[1..($segments.Count - 2)] | ForEach-Object { $_.ToLowerInvariant() }
    }

    $content = Get-Content -Path $file.FullName -Raw -Encoding UTF8
    $bytes = [System.Text.Encoding]::UTF8.GetBytes($content)
    $totalRawBytes += $bytes.Length

    $chunkIndices = Get-ChunkIndices -Bytes $bytes

    if (-not $companies.Contains($companyName)) {
        $companies[$companyName] = [ordered]@{ back = @(); front = @() }
    }

    $entry = [ordered]@{ name = $file.Name; chunks = $chunkIndices }

    if ($subPath -contains 'back') {
        $companies[$companyName].back += $entry
    } elseif ($subPath -contains 'front') {
        $companies[$companyName].front += $entry
    }
}

$sha256.Dispose()

if ($companies.Count -eq 0) {
    throw "No company/back|front folder structure was found under $templatesRootFull"
}

# --- Collect local TTF fonts (base64-encoded) so the PDF exporter can embed them without ---
# --- relying on same-origin fetch() of files next to the HTML page (which fails when the ---
# --- page is opened via the file:// scheme in some browsers/contexts). ---
$fonts = [ordered]@{}
$fontCount = 0
if (Test-Path $FontsRoot) {
    $fontsRootFull = (Resolve-Path $FontsRoot).Path
    $ttfFiles = Get-ChildItem -Path $fontsRootFull -Filter *.ttf -File
    foreach ($fontFile in $ttfFiles) {
        $fontBytes = [System.IO.File]::ReadAllBytes($fontFile.FullName)
        $fontName = [System.IO.Path]::GetFileNameWithoutExtension($fontFile.Name)
        $fonts[$fontName] = [Convert]::ToBase64String($fontBytes)
        $fontCount++
    }
} else {
    Write-Warning "Fonts directory not found: $FontsRoot (skipping font embedding)"
}

# --- Build the shared asset pool ---
$chunkLengths = [System.Collections.Generic.List[int]]::new()
$assetPoolLength = 0
foreach ($chunk in $uniqueChunks) {
    $chunkLengths.Add($chunk.Length)
    $assetPoolLength += $chunk.Length
}

$assetPool = [byte[]]::new($assetPoolLength)
$writeOffset = 0
foreach ($chunk in $uniqueChunks) {
    [System.Array]::Copy($chunk, 0, $assetPool, $writeOffset, $chunk.Length)
    $writeOffset += $chunk.Length
}

$assetPoolBase64 = [Convert]::ToBase64String($assetPool)

$manifest = [ordered]@{
    chunkLengths = $chunkLengths.ToArray()
    assetPool    = $assetPoolBase64
    companies    = $companies
    fonts        = $fonts
}
$json = $manifest | ConvertTo-Json -Depth 20 -Compress
$jsonBytes = [System.Text.Encoding]::UTF8.GetBytes($json)

$memoryStream = [System.IO.MemoryStream]::new()
$gzipStream = [System.IO.Compression.GZipStream]::new($memoryStream, [System.IO.Compression.CompressionLevel]::Optimal, $true)
$gzipStream.Write($jsonBytes, 0, $jsonBytes.Length)
$gzipStream.Dispose()
$compressedBytes = $memoryStream.ToArray()
$memoryStream.Dispose()

$base64 = [Convert]::ToBase64String($compressedBytes)

$html = Get-Content -Path $HtmlPath -Raw -Encoding UTF8
$pattern = '(?s)/\* TEMPLATE_BUNDLE_START.*?/\* TEMPLATE_BUNDLE_END \*/'
if ($html -notmatch $pattern) {
    throw "Could not find TEMPLATE_BUNDLE_START/TEMPLATE_BUNDLE_END markers in $HtmlPath"
}

$replacement = "/* TEMPLATE_BUNDLE_START - generated by New-TemplateBundle.ps1, do not edit by hand */`n        const TEMPLATE_BUNDLE_BASE64 = `"$base64`";`n        /* TEMPLATE_BUNDLE_END */"
$newHtml = [System.Text.RegularExpressions.Regex]::Replace($html, $pattern, { param($m) $replacement })

[System.IO.File]::WriteAllText($HtmlPath, $newHtml, [System.Text.UTF8Encoding]::new($false))

$companyCount = $companies.Count
$backCount = ($companies.Values | ForEach-Object { $_.back.Count } | Measure-Object -Sum).Sum
$frontCount = ($companies.Values | ForEach-Object { $_.front.Count } | Measure-Object -Sum).Sum

Write-Host "Companies:            $companyCount"
Write-Host "Back templates:       $backCount"
Write-Host "Front templates:      $frontCount"
Write-Host "Embedded fonts:       $fontCount"
Write-Host "Raw SVG size:         $([Math]::Round($totalRawBytes / 1KB, 1)) KB"
Write-Host "Unique chunks:        $($uniqueChunks.Count) (avg ~$([Math]::Pow(2, $AverageChunkBits)) bytes, min $MinChunkSize, max $MaxChunkSize)"
Write-Host "Deduplicated size:    $([Math]::Round($assetPoolLength / 1KB, 1)) KB"
Write-Host "Gzip size:            $([Math]::Round($compressedBytes.Length / 1KB, 1)) KB"
Write-Host "Base64 size:          $([Math]::Round($base64.Length / 1KB, 1)) KB (embedded in HTML)"
Write-Host "Updated: $HtmlPath"

