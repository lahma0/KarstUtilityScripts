<#
.SYNOPSIS
Generates a memorable/pronounceable password (ex: 'W!lyGlass329') using the DinoPass API. Alternatively, the script can check whether a word exists in the DinoPass word list.

.DESCRIPTION
This script is a PowerShell wrapper for the DinoPass API at https://www.dinopass.com/api.

It supports the following modes:

- Strong (default): Uses /password/strong
- Simple: Uses /password/simple
- Custom: Uses /password/custom with configurable length and character options
- HasWord: Uses /hasword to check if a word exists in the DinoPass adjective/noun database

The API requires a browser-like User-Agent header, which this script sets automatically.

.PARAMETER Mode
API operation mode.

Valid values:
- Simple
- Strong
- Custom
- HasWord

Default: Strong

.PARAMETER Count
Number of passwords to generate.

Range: 1-100.

Additional constraints:
- When Mode is Strong, DinoPass supports up to 10 passwords per request.
- When Mode is HasWord, Count must be 1.

Default: 1

.PARAMETER Length
Custom password length for Mode Custom.

Range: 7-20.

Default: 14

.PARAMETER ExcludeNumbers
Switch. When Mode is Custom, excludes digits 0-9 from the generated password.

Note: DinoPass's symbol substitutions (e.g. '3' for 'e') can still introduce digit-like
characters even when this switch is set, since that behavior is tied to the symbols
feature rather than the numbers feature. Combine with -ExcludeSymbols to guarantee no
digits appear.

Default: Off (numbers are included)

.PARAMETER ExcludeSymbols
Switch. When Mode is Custom, excludes symbols (!@#$%^&+) from the generated password.

Default: Off (symbols are included)

.PARAMETER ExcludeCapitals
Switch. When Mode is Custom, excludes uppercase letters A-Z from the generated password.

Default: Off (capitals are included)

.PARAMETER Word
Word to check when Mode is HasWord.

Required when Mode is HasWord.

.PARAMETER Format
Response format returned by the API.

Valid values:
- Text (default)
- Json

When Format is Text for password modes, output is a string (single password) or string array (multiple passwords).
When Format is Json, output is the parsed JSON object returned by DinoPass.

.PARAMETER Raw
When set, outputs request/response metadata (RequestUri, StatusCode, Headers, raw Content) plus parsed data.

.EXAMPLE
.\Get-DinoPass.ps1

Generates one strong DinoPass password using default settings.

Sample output:

```powershell
Br@v3D0g-42
```

.EXAMPLE
.\Get-DinoPass.ps1 -Mode Simple -Count 5

Generates five simple DinoPass passwords.

Sample output:

```powershell
happycat42
bravedog78
cleverbird91
sunnywolf64
quickfox27
```

.EXAMPLE
.\Get-DinoPass.ps1 -Mode Custom -Count 3 -Length 16

Generates three custom DinoPass passwords with 16-character length and full character options (numbers, symbols, and capitals all included by default).

Sample output:

```powershell
happycat42@xyz
bravedog78!abc
cleverbird91#qz
```

.EXAMPLE
.\Get-DinoPass.ps1 -Mode HasWord -Word happy

Returns True if "happy" exists in the DinoPass word database; otherwise False.

Sample output:

```powershell
True
```

.EXAMPLE
.\Get-DinoPass.ps1 -Mode Strong -Count 2 -Format Json

Returns a parsed JSON object containing passwords, count, and type.

Sample output:

```powershell
{
    "passwords": [
        "Cl3v3rB1rd-99",
        "42@ngryL10n"
    ],
    "count": 2,
    "type": "strong"
}
```
#>
[CmdletBinding()]
param(
    [Parameter()]
    [ValidateSet('Simple', 'Strong', 'Custom', 'HasWord')]
    [string]$Mode = 'Strong',

    [Parameter()]
    [ValidateRange(1, 100)]
    [int]$Count = 1,

    [Parameter()]
    [ValidateRange(7, 20)]
    [int]$Length = 14,

    [Parameter()]
    [switch]$ExcludeNumbers,

    [Parameter()]
    [switch]$ExcludeSymbols,

    [Parameter()]
    [switch]$ExcludeCapitals,

    [Parameter()]
    [string]$Word,

    [Parameter()]
    [ValidateSet('Text', 'Json')]
    [string]$Format = 'Text',

    [Parameter()]
    [switch]$Raw
)

Set-StrictMode -Version Latest

$baseUri = 'https://www.dinopass.com'
$headers = @{ 'User-Agent' = 'Mozilla/5.0' }

if ($Mode -eq 'Strong' -and $Count -gt 10) {
    throw 'Count cannot be greater than 10 when Mode is Strong.'
}

if ($Mode -eq 'HasWord' -and [string]::IsNullOrWhiteSpace($Word)) {
    throw 'Word is required when Mode is HasWord.'
}

if ($Mode -eq 'HasWord' -and $Count -ne 1) {
    throw 'Count must be 1 when Mode is HasWord.'
}

$endpoint = switch ($Mode) {
    'Simple' { '/password/simple' }
    'Strong' { '/password/strong' }
    'Custom' { '/password/custom' }
    'HasWord' { '/hasword' }
}

$query = [System.Web.HttpUtility]::ParseQueryString([string]::Empty)
$query['format'] = $Format.ToLowerInvariant()

switch ($Mode) {
    'Simple' {
        $query['n'] = [string]$Count
    }
    'Strong' {
        $query['n'] = [string]$Count
    }
    'Custom' {
        $query['n'] = [string]$Count
        $query['length'] = [string]$Length
        $query['useNumbers'] = (-not $ExcludeNumbers).ToString().ToLowerInvariant()
        $query['useSymbols'] = (-not $ExcludeSymbols).ToString().ToLowerInvariant()
        $query['useCapitals'] = (-not $ExcludeCapitals).ToString().ToLowerInvariant()
    }
    'HasWord' {
        $query['word'] = $Word.Trim()
    }
}

$uriBuilder = [System.UriBuilder]::new($baseUri)
$uriBuilder.Path = $endpoint
$uriBuilder.Query = $query.ToString()
$requestUri = $uriBuilder.Uri.AbsoluteUri

try {
    $response = Invoke-WebRequest -Uri $requestUri -Headers $headers -Method Get -ErrorAction Stop
} catch {
    $exceptionMessage = $_.Exception.Message
    $retryAfter = $null

    if ($_.Exception.PSObject.Properties.Name -contains 'Response' -and $null -ne $_.Exception.Response) {
        try {
            $retryAfter = $_.Exception.Response.Headers['Retry-After']
        } catch {
            $retryAfter = $null
        }
    }

    if (-not [string]::IsNullOrWhiteSpace($retryAfter)) {
        throw "DinoPass API request failed. $exceptionMessage Retry-After: $retryAfter seconds."
    }

    throw "DinoPass API request failed. $exceptionMessage"
}

$content = if ($null -eq $response.Content) { '' } else { [string]$response.Content }

if ($Format -eq 'Json') {
    $parsedJson = $content | ConvertFrom-Json -ErrorAction Stop

    if ($Raw) {
        [PSCustomObject]@{
            RequestUri = $requestUri
            StatusCode = [int]$response.StatusCode
            Headers    = $response.Headers
            Content    = $content
            Data       = $parsedJson
        }
        return
    }

    Write-Output $parsedJson
    return
}

$trimmed = $content.Trim()

if ($Mode -eq 'HasWord') {
    $exists = $false
    if ($trimmed -match '^(?i:true)$') {
        $exists = $true
    }

    if ($Raw) {
        [PSCustomObject]@{
            RequestUri = $requestUri
            StatusCode = [int]$response.StatusCode
            Headers    = $response.Headers
            Content    = $trimmed
            Exists     = $exists
        }
        return
    }

    Write-Output $exists
    return
}

$passwords = @($trimmed -split "`r?`n" | Where-Object { -not [string]::IsNullOrWhiteSpace($_) })

if ($Raw) {
    [PSCustomObject]@{
        RequestUri = $requestUri
        StatusCode = [int]$response.StatusCode
        Headers    = $response.Headers
        Content    = $trimmed
        Passwords  = $passwords
    }
    return
}

if ($passwords.Count -eq 1) {
    Write-Output $passwords[0]
} else {
    Write-Output $passwords
}
