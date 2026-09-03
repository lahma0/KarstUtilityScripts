<#
.SYNOPSIS
Generates a business card SVG file by populating a template with contact information.

.DESCRIPTION
This script automates business card creation by locating SVG templates, collecting contact
information (via parameters or interactive prompts), and producing a fully populated SVG
file ready for use or printing.

The workflow is:
  1. Select an SVG template from the templates folder (or use the -Template path directly).
  2. Parse the template to determine which field placeholders are present.
  3. Collect values for each placeholder found in the template — either from supplied
     parameters or via interactive prompts.
  4. Format and validate phone numbers; extract QR code content from a QR SVG file if needed.
  5. Determine the output file path, using an auto-suggested name or the supplied -OutputSvgPath.
  6. Replace all placeholders in the template with the collected values and save the file.
  7. Offer to open the completed SVG file when done.

All field values are automatically converted to uppercase in the output, with the exception
of the QR code content which is preserved as-is.

Phone values are assembled from separate Type, Number, and Extension inputs and formatted as:
  C: 737.376.6888
  O: 254.489.0469 EXT 5027

The QR code content is extracted from a separate QR SVG file by capturing all content between
the first <g> element and the last </g> element in that file. This avoids the rect element, which colors the background white, resulting in a transparent background.

Supported template variables:
    FirstName, LastName, Email, Phone1, Phone2,
    Addr1, City1, State1, Zip1, Addr2, City2, State2, Zip2,
    JobTitle, Region, QR

Example data-var format:
    <tspan data-var="FirstName">JOHN</tspan>

The script replaces the inner content of each element with a matching data-var attribute. This
lets the template display sample text when viewed directly while still allowing the script to
swap in real values.

.PARAMETER Template
Path to the SVG template file to use. May be an absolute path or a path relative to the current
working directory. If not provided, the script searches the templates folder (the parent of the
script's directory) for available SVG files and presents an interactive numbered selection menu.

[Optional]

.PARAMETER Email
The email address to insert into the business card. Converted to uppercase.

[Optional — prompted if Email is found in the template]

.PARAMETER Phone1Type
The type of the first phone number. Valid values: Cell, Office, Fax.
Combined with Phone1Number (and optionally Phone1Extension) to produce a formatted phone string.

If both Phone1Type and Phone1Number are provided as parameters, Phone1Extension is assumed to be
absent (the number has no extension) and the user will not be prompted for it.

[Optional — prompted if Phone1 is found in the template and this was not supplied]

.PARAMETER Phone1Number
The first phone number. Must be exactly 10 digits (no formatting characters).

[Optional — prompted if Phone1 is found in the template and this was not supplied]

.PARAMETER Phone1Extension
The extension for the first phone number. Must be 1-6 digits. Leave blank for no extension.
Only prompted when Phone1 is in the template and at least one of Phone1Type or
Phone1Number was not pre-supplied as a parameter (i.e., both were not already provided).

[Optional]

.PARAMETER Phone2Type
The type of the second phone number. Valid values: Cell, Office, Fax.
Only relevant if the template contains Phone2.

[Optional — prompted if Phone2 is found in the template and this was not supplied]

.PARAMETER Phone2Number
The second phone number. Must be exactly 10 digits (no formatting characters).
Only relevant if the template contains Phone2.

[Optional — prompted if Phone2 is found in the template and this was not supplied]

.PARAMETER Phone2Extension
The extension for the second phone number. Must be 1-6 digits. Leave blank for no extension.
Only prompted when Phone2 is in the template and at least one of Phone2Type or
Phone2Number was not pre-supplied as a parameter.

[Optional]

.PARAMETER Addr1
The street address for address #1. Converted to uppercase.

[Optional — prompted if Addr1 is found in the template]

.PARAMETER City1
The city for address #1. Converted to uppercase.

[Optional — prompted if City1 is found in the template]

.PARAMETER State1
The state for address #1. Converted to uppercase.

[Optional — prompted if State1 is found in the template]

.PARAMETER Zip1
The ZIP code for address #1. Converted to uppercase.

[Optional — prompted if Zip1 is found in the template]

.PARAMETER Addr2
The street address for address #2. Converted to uppercase.

[Optional — prompted if Addr2 is found in the template]

.PARAMETER City2
The city for address #2. Converted to uppercase.

[Optional — prompted if City2 is found in the template]

.PARAMETER State2
The state for address #2. Converted to uppercase.

[Optional — prompted if State2 is found in the template]

.PARAMETER Zip2
The ZIP code for address #2. Converted to uppercase.

[Optional — prompted if Zip2 is found in the template]

.PARAMETER JobTitle
The job title to display on the business card. Converted to uppercase.

[Optional — prompted if JobTitle is found in the template]

.PARAMETER Region
The region or territory to display on the business card. Leave blank if not applicable. Converted to uppercase.

[Optional — prompted if Region is found in the template]

.PARAMETER QR
The raw SVG content for the QR code — the inner <g>...</g> elements from a QR SVG file.
Preserved as-is (not uppercased). If this parameter is not provided and the template contains
QR, the script uses -QrSvgPath to obtain the content instead.

If a full SVG document is provided here instead of only the inner <g>...</g> content, the script
automatically trims any text before the first <g> element and after the final </g> element.

[Optional — QrSvgPath is used/prompted if this parameter is omitted and QR is in the template]

.PARAMETER QrSvgPath
Path to an SVG file containing QR code data. The script extracts all content between the first
<g> element and the last </g> element in that file and uses it as the QR placeholder value.
Ignored if -QR is supplied directly.

[Optional — prompted if QR is in the template and neither QR nor QrSvgPath is supplied]

.PARAMETER FirstName
The first name of the card recipient. Used when auto-generating the suggested output file name.
Also used to populate a FirstName template variable if present. Only prompted when required by
the template or when -OutputSvgPath is not supplied.

[Optional]

.PARAMETER LastName
The last name of the card recipient. Used when auto-generating the suggested output file name.
Also used to populate a LastName template variable if present. Only prompted when required by
the template or when -OutputSvgPath is not supplied.

[Optional]

.PARAMETER OutputSvgPath
The file path where the populated SVG should be saved. Any missing parent directories are
created automatically. If a file already exists at this path, the script prompts for confirmation
before overwriting (unless -OverwriteWithoutPrompting is specified).

For safety, output files are never allowed inside the ./templates/ directory (or any of its
subdirectories). If a path under ./templates/ is provided, you will be prompted to choose
another location.

If this parameter is not provided, the script prompts with an auto-suggested path in the format:
  .\output\[TemplateName].[FirstName].[LastName].svg

The template name portion is taken from the template filename up to the first '.' character,
with any occurrence of '-Template' or 'Template' removed. For example, a template named
'Karst-BusinessCard-Template.QR.1Addr.1Phone.svg' for John Doe would suggest:
  .\output\Karst-BusinessCard.John.Doe.svg

[Optional]

.PARAMETER OverwriteWithoutPrompting
Switch parameter. When specified, any existing file at -OutputSvgPath is overwritten without
prompting for confirmation.

[Optional]

.EXAMPLE
.\New-BusinessCard.ps1

Runs fully interactively — select a template from the menu, then provide all field values when prompted.

.EXAMPLE
.\New-BusinessCard.ps1 -Template ".\karst\Karst-BusinessCard-Template.svg" -Email "jdoe@karst.com" -JobTitle "Project Manager" -Phone1Type Office -Phone1Number "2544890469"

Uses the specified template and pre-supplied values. Prompts only for the remaining placeholders
found in the template.

.EXAMPLE
.\New-BusinessCard.ps1 -Template ".\karst\Karst-BusinessCard-Template.svg" -Email "jdoe@karst.com" -QrSvgPath ".\qr\jdoe-qr.svg" -OutputSvgPath ".\output\Karst-BusinessCard.John.Doe.svg" -OverwriteWithoutPrompting

Fully scripted execution using an existing QR SVG file, writing to a specific path without
an overwrite prompt.

.EXAMPLE
.\New-BusinessCard.ps1 -Phone1Type Cell -Phone1Number "7373766888" -Phone2Type Office -Phone2Number "2544890469" -Phone2Extension "5027"

Provides both phone entries as parameters. Because Phone1Type and Phone1Number are both supplied
as parameters, Phone1Extension is assumed absent (no prompt). Phone2Extension is used as-is from
the supplied parameter value.

.EXAMPLE
.\New-BusinessCard.ps1 -Template ".\karst\Karst-BusinessCard-Template.svg" -Phone1Type Office -Phone1Number "2544890469" -PurgeType None

Provides Phone1Type and Phone1Number; Phone1Extension will not be prompted because both were
supplied as parameters.

.NOTES
No external module dependencies.
#>
param (
    [Parameter(Mandatory = $false)]
    [string]$Template,

    [Parameter(Mandatory = $false)]
    [string]$Email,

    [Parameter(Mandatory = $false)]
    [ValidateSet("Cell", "Office", "Fax")]
    [string]$Phone1Type,

    [Parameter(Mandatory = $false)]
    [string]$Phone1Number,

    [Parameter(Mandatory = $false)]
    [string]$Phone1Extension,

    [Parameter(Mandatory = $false)]
    [ValidateSet("Cell", "Office", "Fax")]
    [string]$Phone2Type,

    [Parameter(Mandatory = $false)]
    [string]$Phone2Number,

    [Parameter(Mandatory = $false)]
    [string]$Phone2Extension,

    [Parameter(Mandatory = $false)]
    [string]$Addr1,

    [Parameter(Mandatory = $false)]
    [string]$City1,

    [Parameter(Mandatory = $false)]
    [string]$State1,

    [Parameter(Mandatory = $false)]
    [string]$Zip1,

    [Parameter(Mandatory = $false)]
    [string]$Addr2,

    [Parameter(Mandatory = $false)]
    [string]$City2,

    [Parameter(Mandatory = $false)]
    [string]$State2,

    [Parameter(Mandatory = $false)]
    [string]$Zip2,

    [Parameter(Mandatory = $false)]
    [string]$JobTitle,

    [Parameter(Mandatory = $false)]
    [string]$Region,

    [Parameter(Mandatory = $false)]
    [string]$QR,

    [Parameter(Mandatory = $false)]
    [string]$QrSvgPath,

    [Parameter(Mandatory = $false)]
    [string]$FirstName,

    [Parameter(Mandatory = $false)]
    [string]$LastName,

    [Parameter(Mandatory = $false)]
    [string]$OutputSvgPath,

    [Parameter(Mandatory = $false)]
    [switch]$OverwriteWithoutPrompting
)

# ─── Helper Functions ─────────────────────────────────────────────────────────

function Read-YesNoResponse {
    param(
        [Parameter(Mandatory = $true)]
        [string]$Prompt,

        [Parameter(Mandatory = $false)]
        [bool]$DefaultValue = $false
    )

    while ($true) {
        $defaultHint = if ($DefaultValue) { "Y" } else { "N" }
        $response = Read-Host "$Prompt (Y/N, default: $defaultHint)"

        if ([string]::IsNullOrWhiteSpace($response)) {
            return $DefaultValue
        }

        switch -Regex ($response.Trim().ToLowerInvariant()) {
            '^(y|yes)$' { return $true }
            '^(n|no)$' { return $false }
            default { Write-Host "Please enter Y or N." -ForegroundColor Yellow }
        }
    }
}

function Read-HostWithDefault {
    param(
        [Parameter(Mandatory = $true)]
        [string]$Prompt,

        [Parameter(Mandatory = $false)]
        [string]$Default = ""
    )

    if ([string]::IsNullOrEmpty($Default)) {
        return Read-Host $Prompt
    }

    $result = Read-Host "$Prompt [$Default]"
    if ([string]::IsNullOrWhiteSpace($result)) {
        return $Default
    }
    return $result
}

function Select-SvgTemplate {
    param(
        [Parameter(Mandatory = $true)]
        [string]$TemplatesRoot
    )

    $svgFiles = Get-ChildItem -Path $TemplatesRoot -Recurse -Filter "*.svg" -File -ErrorAction SilentlyContinue |
        Sort-Object FullName

    if (-not $svgFiles -or $svgFiles.Count -eq 0) {
        Write-Host "✗ No SVG template files found in: $TemplatesRoot" -ForegroundColor Red
        Write-Host "  Ensure SVG templates are present in the templates folder and try again." -ForegroundColor Red
        exit 1
    }

    Write-Host "`nAvailable SVG templates:`n" -ForegroundColor Cyan
    $i = 1
    foreach ($file in $svgFiles) {
        $relativePath = $file.FullName.Substring($TemplatesRoot.TrimEnd('\', '/').Length).TrimStart('\', '/')
        Write-Host "  $i - $relativePath" -ForegroundColor White
        $i++
    }
    Write-Host ""

    $choice = $null
    while ($null -eq $choice) {
        $raw = (Read-Host "Select a template (1-$($svgFiles.Count))").Trim()
        if ($raw -match '^\d+$') {
            $n = [int]$raw
            if ($n -ge 1 -and $n -le $svgFiles.Count) {
                $choice = $n
            } else {
                Write-Host "Please enter a number between 1 and $($svgFiles.Count)." -ForegroundColor Yellow
            }
        } else {
            Write-Host "Please enter a number between 1 and $($svgFiles.Count)." -ForegroundColor Yellow
        }
    }

    return $svgFiles[$choice - 1].FullName
}

function Get-TemplatePlaceholders {
    param(
        [Parameter(Mandatory = $true)]
        [xml]$TemplateXml
    )

    $nodes = $TemplateXml.SelectNodes('//*[@data-var]')
    if ($null -eq $nodes) { return @() }

    return @(
        $nodes |
        ForEach-Object { $_.GetAttribute('data-var') } |
        Where-Object { -not [string]::IsNullOrWhiteSpace($_) } |
        Sort-Object -Unique
    )
}

function Convert-TemplateContentToXmlDocument {
    param(
        [Parameter(Mandatory = $true)]
        [string]$Content,

        [Parameter(Mandatory = $true)]
        [string]$SourceDescription
    )

    $doc = New-Object System.Xml.XmlDocument
    $doc.PreserveWhitespace = $true

    try {
        $doc.LoadXml($Content)
        return $doc
    } catch {
        Write-Host "✗ Failed to parse template as XML: $SourceDescription" -ForegroundColor Red
        Write-Host "  $($_.Exception.Message)" -ForegroundColor Yellow
        exit 1
    }
}

function Set-TemplateVariableValue {
    param(
        [Parameter(Mandatory = $true)]
        [xml]$TemplateXml,

        [Parameter(Mandatory = $true)]
        [string]$VariableName,

        [Parameter(Mandatory = $true)]
        [AllowEmptyString()]
        [string]$Value,

        [Parameter(Mandatory = $false)]
        [bool]$TreatValueAsXml = $false
    )

    $nodes = $TemplateXml.SelectNodes("//*[@data-var='$VariableName']")
    if ($null -eq $nodes) { return }

    foreach ($node in $nodes) {
        if ($TreatValueAsXml) {
            while ($node.HasChildNodes) {
                $null = $node.RemoveChild($node.FirstChild)
            }

            $fragment = $TemplateXml.CreateDocumentFragment()
            try {
                $fragment.InnerXml = $Value
            } catch {
                Write-Host "✗ Invalid XML content supplied for variable '$VariableName'." -ForegroundColor Red
                Write-Host "  $($_.Exception.Message)" -ForegroundColor Yellow
                exit 1
            }

            $null = $node.AppendChild($fragment)
        } else {
            $node.InnerText = $Value
        }
    }
}

function Get-QrSvgGroupContent {
    param(
        [Parameter(Mandatory = $true)]
        [string]$SvgContent,

        [Parameter(Mandatory = $true)]
        [string]$SourceDescription,

        [Parameter(Mandatory = $false)]
        [bool]$RequireGroup = $true
    )

    $firstG = $SvgContent.IndexOf('<g')
    $lastGEnd = $SvgContent.LastIndexOf('</g>')

    if ($firstG -lt 0 -or $lastGEnd -lt 0 -or $lastGEnd -lt $firstG) {
        if ($RequireGroup) {
            Write-Host "✗ Could not locate <g>...</g> elements in $SourceDescription" -ForegroundColor Red
            return $null
        }

        return $SvgContent
    }

    # Include the closing </g> tag (4 characters)
    return $SvgContent.Substring($firstG, $lastGEnd - $firstG + 4)
}

function Get-QrSvgContent {
    param(
        [Parameter(Mandatory = $true)]
        [string]$SvgPath
    )

    if (-not (Test-Path -LiteralPath $SvgPath -PathType Leaf)) {
        Write-Host "✗ QR SVG file not found: $SvgPath" -ForegroundColor Red
        return $null
    }

    $content = Get-Content -LiteralPath $SvgPath -Raw -ErrorAction Stop
    return Get-QrSvgGroupContent -SvgContent $content -SourceDescription "QR SVG file: $SvgPath" -RequireGroup $true
}

function Test-IsPathInsideDirectory {
    param(
        [Parameter(Mandatory = $true)]
        [string]$Path,

        [Parameter(Mandatory = $true)]
        [string]$DirectoryPath
    )

    try {
        $targetFull = [System.IO.Path]::GetFullPath($Path)
        $dirFull = [System.IO.Path]::GetFullPath($DirectoryPath)
    } catch {
        return $false
    }

    $dirWithSeparator = $dirFull
    if (-not $dirWithSeparator.EndsWith([System.IO.Path]::DirectorySeparatorChar) -and
        -not $dirWithSeparator.EndsWith([System.IO.Path]::AltDirectorySeparatorChar)) {
        $dirWithSeparator += [System.IO.Path]::DirectorySeparatorChar
    }

    if ($targetFull.Equals($dirFull, [System.StringComparison]::OrdinalIgnoreCase)) {
        return $true
    }

    return $targetFull.StartsWith($dirWithSeparator, [System.StringComparison]::OrdinalIgnoreCase)
}

function Format-PhoneValue {
    param(
        [Parameter(Mandatory = $true)]
        [string]$Type,

        [Parameter(Mandatory = $true)]
        [string]$Number,

        [Parameter(Mandatory = $false)]
        [string]$Extension = ""
    )

    $typeChar = $Type[0].ToString().ToUpper()
    $formatted = "${typeChar}: $($Number.Substring(0,3)).$($Number.Substring(3,3)).$($Number.Substring(6,4))"

    if (-not [string]::IsNullOrWhiteSpace($Extension)) {
        $formatted += " EXT $Extension"
    }

    return $formatted
}

function Read-PhoneType {
    param(
        [Parameter(Mandatory = $true)]
        [string]$Label
    )

    while ($true) {
        $val = (Read-Host "$Label type (Cell, Office, or Fax)").Trim()
        if ($val -in @('Cell', 'Office', 'Fax')) { return $val }
        Write-Host "Please enter 'Cell', 'Office', or 'Fax'." -ForegroundColor Yellow
    }
}

function Read-PhoneNumber {
    param(
        [Parameter(Mandatory = $true)]
        [string]$Label
    )

    while ($true) {
        $val = (Read-Host "$Label number (10 digits, no formatting)").Trim()
        if ($val -match '^\d{ 10 }$') { return $val }
        Write-Host "Please enter exactly 10 digits (no spaces, dashes, or parentheses)." -ForegroundColor Yellow
    }
}

function Read-PhoneExtension {
    param(
        [Parameter(Mandatory = $true)]
        [string]$Label
    )

    Write-Host "  Leave blank if this number does not have an extension." -ForegroundColor DarkGray

    while ($true) {
        $val = (Read-Host "$Label extension").Trim()
        if ([string]::IsNullOrEmpty($val)) { return "" }
        if ($val -match '^\d{ 1, 6 }$') { return $val }
        Write-Host "Extension must be 1-6 digits, or leave blank for none." -ForegroundColor Yellow
    }
}

# ─── Validate Supplied Phone Parameters ───────────────────────────────────────

if ($PSBoundParameters.ContainsKey('Phone1Number') -and $Phone1Number -notmatch '^\d{ 10 }$') {
    Write-Host "✗ Phone1Number must be exactly 10 digits (no formatting). Exiting." -ForegroundColor Red
    exit 1
}

if ($PSBoundParameters.ContainsKey('Phone1Extension') -and
    -not [string]::IsNullOrWhiteSpace($Phone1Extension) -and
    $Phone1Extension -notmatch '^\d{ 1, 6 }$') {
    Write-Host "✗ Phone1Extension must be 1-6 digits. Exiting." -ForegroundColor Red
    exit 1
}

if ($PSBoundParameters.ContainsKey('Phone2Number') -and $Phone2Number -notmatch '^\d{ 10 }$') {
    Write-Host "✗ Phone2Number must be exactly 10 digits (no formatting). Exiting." -ForegroundColor Red
    exit 1
}

if ($PSBoundParameters.ContainsKey('Phone2Extension') -and
    -not [string]::IsNullOrWhiteSpace($Phone2Extension) -and
    $Phone2Extension -notmatch '^\d{ 1, 6 }$') {
    Write-Host "✗ Phone2Extension must be 1-6 digits. Exiting." -ForegroundColor Red
    exit 1
}

# ─── Select Template ─────────────────────────────────────────────────────────

$templatePath = $null
$protectedTemplatesRoot = $null

$scriptTemplatesCandidate = if ($PSScriptRoot) { Join-Path $PSScriptRoot "templates" } else { $null }
if ($scriptTemplatesCandidate -and (Test-Path -LiteralPath $scriptTemplatesCandidate -PathType Container)) {
    $protectedTemplatesRoot = (Resolve-Path -LiteralPath $scriptTemplatesCandidate).Path
} else {
    $cwdTemplatesCandidate = Join-Path (Get-Location) "templates"
    if (Test-Path -LiteralPath $cwdTemplatesCandidate -PathType Container) {
        $protectedTemplatesRoot = (Resolve-Path -LiteralPath $cwdTemplatesCandidate).Path
    }
}

if (-not [string]::IsNullOrWhiteSpace($Template)) {
    if (Test-Path -LiteralPath $Template -PathType Leaf) {
        $templatePath = (Resolve-Path -LiteralPath $Template).Path
    } else {
        Write-Host "✗ Template file not found: $Template" -ForegroundColor Red
        exit 1
    }
} else {
    $templatesRoot = if ($protectedTemplatesRoot) {
        $protectedTemplatesRoot
    } elseif ($PSScriptRoot) {
        (Resolve-Path (Join-Path $PSScriptRoot "..")).Path
    } else {
        $candidate = Join-Path (Get-Location) "templates"
        if (Test-Path $candidate) {
            (Resolve-Path $candidate).Path
        } else {
            (Get-Location).Path
        }
    }

    Write-Host "`n🛈 No template specified. Searching for SVG templates in: $templatesRoot" -ForegroundColor Cyan
    $templatePath = Select-SvgTemplate -TemplatesRoot $templatesRoot
    Write-Host "`n🛈 Selected template: $templatePath" -ForegroundColor Cyan
}

# ─── Read Template Content ────────────────────────────────────────────────────

Write-Host "`nReading template..." -ForegroundColor Cyan

$templateContent = Get-Content -LiteralPath $templatePath -Raw -ErrorAction Stop
$templateXml = Convert-TemplateContentToXmlDocument -Content $templateContent -SourceDescription $templatePath

# ─── Detect Placeholders ──────────────────────────────────────────────────────

$placeholders = Get-TemplatePlaceholders -TemplateXml $templateXml

if ($placeholders.Count -eq 0) {
    Write-Host "⚠ No recognized placeholders found in the template. The output file will be an unchanged copy." -ForegroundColor Yellow
} else {
    Write-Host "🛈 Placeholders found: $($placeholders -join ', ')" -ForegroundColor Cyan
}

# ─── Collect Simple Text Values ──────────────────────────────────────────────

# Ordered map of placeholder name → human-readable prompt label.
# Iteration order determines prompt order.
$simpleFields = [ordered]@{
    'FirstName' = 'First name'
    'LastName'  = 'Last name'
    'Email'     = 'Email address'
    'JobTitle'  = 'Job title'
    'Addr1'     = 'Address line 1'
    'City1'     = 'City (address 1)'
    'State1'    = 'State (address 1)'
    'Zip1'      = 'ZIP code (address 1)'
    'Addr2'     = 'Address line 2'
    'City2'     = 'City (address 2)'
    'State2'    = 'State (address 2)'
    'Zip2'      = 'ZIP code (address 2)'
}

$values = @{}
$jobTitleProvidedAsParameter = $PSBoundParameters.ContainsKey('JobTitle')
$jobTitleWasPrompted = $false

foreach ($key in $simpleFields.Keys) {
    if ($placeholders -notcontains $key) { continue }

    $paramValue = (Get-Variable -Name $key -ValueOnly -ErrorAction SilentlyContinue)

    if (-not [string]::IsNullOrWhiteSpace($paramValue)) {
        $values[$key] = $paramValue.ToUpper()
    } else {
        Write-Host ""
        $entered = Read-Host "Enter $($simpleFields[$key])"
        $values[$key] = if ([string]::IsNullOrWhiteSpace($entered)) { "" } else { $entered.ToUpper() }

        if ($key -eq 'JobTitle') {
            $jobTitleWasPrompted = $true
        }
    }
}

if ($placeholders -contains 'Region') {
    $regionProvidedAsParameter = $PSBoundParameters.ContainsKey('Region')

    if ($regionProvidedAsParameter) {
        $values['Region'] = if ([string]::IsNullOrWhiteSpace($Region)) { "" } else { $Region.ToUpper() }
    } elseif ($jobTitleProvidedAsParameter) {
        # If JobTitle came from a parameter and Region was not provided, assume Region is intentionally blank.
        $values['Region'] = ""
    } elseif ($jobTitleWasPrompted -or $placeholders -notcontains 'JobTitle') {
        Write-Host ""
        $enteredRegion = Read-Host "Enter region (leave blank if no region should be displayed)"
        $values['Region'] = if ([string]::IsNullOrWhiteSpace($enteredRegion)) { "" } else { $enteredRegion.ToUpper() }
    }
}

# ─── Handle Phone 1 ───────────────────────────────────────────────────────────

if ($placeholders -contains 'Phone1') {
    $p1TypeViaParam = $PSBoundParameters.ContainsKey('Phone1Type')
    $p1NumberViaParam = $PSBoundParameters.ContainsKey('Phone1Number')
    $p1BothViaParam = $p1TypeViaParam -and $p1NumberViaParam
    $p1ExtViaParam = $PSBoundParameters.ContainsKey('Phone1Extension')

    Write-Host "`n─── Phone 1 ────────────────────────────────────────────────────────────────────" -ForegroundColor Cyan

    if (-not $p1TypeViaParam) {
        $Phone1Type = Read-PhoneType -Label "Phone 1"
    }

    if (-not $p1NumberViaParam) {
        $Phone1Number = Read-PhoneNumber -Label "Phone 1"
    }

    # Only prompt for extension when both Type and Number were NOT both pre-supplied as params
    if (-not $p1BothViaParam -and -not $p1ExtViaParam) {
        $Phone1Extension = Read-PhoneExtension -Label "Phone 1"
    }

    $values['Phone1'] = Format-PhoneValue -Type $Phone1Type -Number $Phone1Number -Extension $Phone1Extension
    Write-Host "🛈 Phone 1 formatted: $($values['Phone1'])" -ForegroundColor Cyan
}

# ─── Handle Phone 2 ───────────────────────────────────────────────────────────

if ($placeholders -contains 'Phone2') {
    $p2TypeViaParam = $PSBoundParameters.ContainsKey('Phone2Type')
    $p2NumberViaParam = $PSBoundParameters.ContainsKey('Phone2Number')
    $p2BothViaParam = $p2TypeViaParam -and $p2NumberViaParam
    $p2ExtViaParam = $PSBoundParameters.ContainsKey('Phone2Extension')

    Write-Host "`n─── Phone 2 ────────────────────────────────────────────────────────────────────" -ForegroundColor Cyan

    if (-not $p2TypeViaParam) {
        $Phone2Type = Read-PhoneType -Label "Phone 2"
    }

    if (-not $p2NumberViaParam) {
        $Phone2Number = Read-PhoneNumber -Label "Phone 2"
    }

    if (-not $p2BothViaParam -and -not $p2ExtViaParam) {
        $Phone2Extension = Read-PhoneExtension -Label "Phone 2"
    }

    $values['Phone2'] = Format-PhoneValue -Type $Phone2Type -Number $Phone2Number -Extension $Phone2Extension
    Write-Host "🛈 Phone 2 formatted: $($values['Phone2'])" -ForegroundColor Cyan
}

# ─── Handle QR Code ───────────────────────────────────────────────────────────

if ($placeholders -contains 'QR') {
    if (-not [string]::IsNullOrWhiteSpace($QR)) {
        # QR content supplied directly — if a full SVG was provided, trim to the inner <g>...</g> content.
        $values['QR'] = Get-QrSvgGroupContent -SvgContent $QR -SourceDescription 'direct -QR parameter value' -RequireGroup $false
        Write-Host "`n🛈 QR content supplied directly via -QR parameter." -ForegroundColor Cyan
    } else {
        # Need to extract QR content from an SVG file
        if ([string]::IsNullOrWhiteSpace($QrSvgPath)) {
            Write-Host ""
            $QrSvgPath = Read-Host "Enter path to QR code SVG file"
        }

        $qrContent = $null
        while ($null -eq $qrContent) {
            $qrContent = Get-QrSvgContent -SvgPath $QrSvgPath
            if ($null -eq $qrContent) {
                Write-Host ""
                $QrSvgPath = Read-Host "Enter a valid path to the QR code SVG file"
            }
        }

        $values['QR'] = $qrContent
        Write-Host "🛈 QR content extracted from: $QrSvgPath" -ForegroundColor Cyan
    }
}

# ─── Determine Output Path ────────────────────────────────────────────────────

if ([string]::IsNullOrWhiteSpace($OutputSvgPath)) {
    # Need FirstName and LastName to build the suggested path
    if ([string]::IsNullOrWhiteSpace($FirstName)) {
        Write-Host ""
        $FirstName = Read-Host "Enter first name (used for output file name)"
    }

    if ([string]::IsNullOrWhiteSpace($LastName)) {
        $LastName = Read-Host "Enter last name (used for output file name)"
    }

    # Derive base name: take template filename up to the first '.', then strip Template markers
    $templateFilename = Split-Path $templatePath -Leaf
    $baseName = ($templateFilename -split '\.')[0]
    $baseName = $baseName -replace '-Template', '' -replace 'Template', ''

    $suggestedPath = ".\output\$baseName.$FirstName.$LastName.svg"

    Write-Host ""
    $OutputSvgPath = Read-HostWithDefault -Prompt "Output SVG file path" -Default $suggestedPath
}

# Resolve to absolute path (works even for paths that don't exist yet)
$outputAbsPath = $ExecutionContext.SessionState.Path.GetUnresolvedProviderPathFromPSPath($OutputSvgPath)

while ($protectedTemplatesRoot -and (Test-IsPathInsideDirectory -Path $outputAbsPath -DirectoryPath $protectedTemplatesRoot)) {
    Write-Host "`n✗ Output path cannot be inside the templates directory or its subdirectories." -ForegroundColor Red
    Write-Host "  Protected path: $protectedTemplatesRoot" -ForegroundColor Yellow
    Write-Host "  Provided path : $outputAbsPath" -ForegroundColor Yellow

    $OutputSvgPath = Read-Host "Please enter a different output path (outside templates)"
    $outputAbsPath = $ExecutionContext.SessionState.Path.GetUnresolvedProviderPathFromPSPath($OutputSvgPath)
}

# ─── Check Overwrite ──────────────────────────────────────────────────────────

if (Test-Path -LiteralPath $outputAbsPath -PathType Leaf) {
    if (-not $OverwriteWithoutPrompting) {
        Write-Host ""
        $overwrite = Read-YesNoResponse -Prompt "⚠ File already exists at '$outputAbsPath'. Overwrite?" -DefaultValue $false
        if (-not $overwrite) {
            Write-Host "✗ Operation cancelled by user." -ForegroundColor Red
            exit
        }
    }
}

# ─── Create Output Directories ────────────────────────────────────────────────

$outputDir = Split-Path $outputAbsPath -Parent
if (-not [string]::IsNullOrWhiteSpace($outputDir) -and -not (Test-Path -LiteralPath $outputDir)) {
    New-Item -ItemType Directory -Path $outputDir -Force | Out-Null
    Write-Host "`n🛈 Created directory: $outputDir" -ForegroundColor Cyan
}

# ─── Replace Placeholders ─────────────────────────────────────────────────────

Write-Host "`nPopulating template..." -ForegroundColor Cyan

$outputContent = $templateContent

foreach ($placeholder in $placeholders) {
    if (-not $values.ContainsKey($placeholder)) { continue }

    if ($placeholder -eq 'QR') {
        Set-TemplateVariableValue -TemplateXml $templateXml -VariableName $placeholder -Value $values[$placeholder] -TreatValueAsXml $true
    } else {
        Set-TemplateVariableValue -TemplateXml $templateXml -VariableName $placeholder -Value $values[$placeholder]
    }
}

$outputContent = $templateXml.OuterXml

# ─── Save Output SVG ──────────────────────────────────────────────────────────

$utf8NoBom = [System.Text.UTF8Encoding]::new($false)
[System.IO.File]::WriteAllText($outputAbsPath, $outputContent, $utf8NoBom)

Write-Host "`n✓ Business card SVG saved successfully!" -ForegroundColor Green
Write-Host "`nOutput Details:" -ForegroundColor Cyan
Write-Host "  Template    : $templatePath" -ForegroundColor White
Write-Host "  Output File : $outputAbsPath" -ForegroundColor White
Write-Host "  Fields Set  : $($values.Keys -join ', ')" -ForegroundColor White

# ─── Open File? ───────────────────────────────────────────────────────────────

Write-Host ""
if (Read-YesNoResponse -Prompt "Would you like to open the SVG file now?" -DefaultValue $true) {
    Invoke-Item -LiteralPath $outputAbsPath
}
