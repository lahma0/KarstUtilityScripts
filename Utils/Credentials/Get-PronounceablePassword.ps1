<#
.SYNOPSIS
Generates one or more pronounceable passwords.

.DESCRIPTION
Creates pronounceable passwords by generating a letter-based segment and appending
numeric and special-character segments as separate groups. The letter segment can be
forced to specific case patterns, and the final arrangement of Letters, Digits, and
SpecialChars can be selected or randomized.

No password element groups are interleaved. For example, a password may look like:
garamEZWAT348!@
but never like:
gar3amEZ4WAT!8@

.PARAMETER Length
Total password length. Minimum is 12. Default is 14.

.PARAMETER MinNumOfDigits
Minimum number of digits to include. Default is 1. Maximum is 3.

.PARAMETER MinNumOfSpecialChars
Minimum number of special characters to include. Default is 1. Maximum is 3.

.PARAMETER Case
Case pattern for the pronounceable letter segment.

Valid options:
- lowerUPPER  : first half lowercase, second half uppercase (example: garamEZWAT)
- UPPERlower  : first half uppercase, second half lowercase (example: GARAMezwat)
- CamelCase   : first character of each half uppercase (example: GaramEzwat)
- lowerOnly   : all lowercase (example: garamezwat)
- UPPEROnly   : all uppercase (example: GARAMEZWAT)
- Random      : randomly picks lowerUPPER, UPPERlower, or CamelCase

Default is Random.

.PARAMETER Order
Order of the three password element groups: Letters, Digits, and SpecialChars.

Valid options:
- LettersDigitsSpecialChars
- LettersSpecialCharsDigits
- DigitsLettersSpecialChars
- DigitsSpecialCharsLetters
- SpecialCharsLettersDigits
- SpecialCharsDigitsLetters
- Random

Default is Random.

.PARAMETER Count
Number of passwords to generate. Default is 1.

.EXAMPLE
.\Get-PronounceablePassword.ps1

Generates one password with default settings.

.EXAMPLE
.\Get-PronounceablePassword.ps1 -Length 16 -MinNumOfDigits 2 -MinNumOfSpecialChars 2 -Case CamelCase -Order DigitsLettersSpecialChars

Generates one 16-character password using CamelCase letters and places digits first.

.EXAMPLE
.\Get-PronounceablePassword.ps1 -Count 5 -Length 14 -Case Random -Order Random

Generates five passwords using randomized case pattern and randomized element order.
#>
[CmdletBinding()]
param(
    [Parameter()]
    [ValidateRange(12, [int]::MaxValue)]
    [int]$Length = 14,

    [Parameter()]
    [ValidateRange(1, 3)]
    [int]$MinNumOfDigits = 1,

    [Parameter()]
    [ValidateRange(1, 3)]
    [int]$MinNumOfSpecialChars = 1,

    [Parameter()]
    [ValidateSet('lowerUPPER', 'UPPERlower', 'CamelCase', 'lowerOnly', 'UPPEROnly', 'Random')]
    [string]$Case = 'Random',

    [Parameter()]
    [ValidateSet('LettersDigitsSpecialChars', 'LettersSpecialCharsDigits', 'DigitsLettersSpecialChars', 'DigitsSpecialCharsLetters', 'SpecialCharsLettersDigits', 'SpecialCharsDigitsLetters', 'Random')]
    [string]$Order = 'Random',

    [Parameter()]
    [ValidateRange(1, [int]::MaxValue)]
    [int]$Count = 1
)

Set-StrictMode -Version Latest

function New-PronounceableText {
    param(
        [Parameter(Mandatory)]
        [int]$TargetLength
    )

    $consonants = @(
        'b', 'br', 'c', 'ch', 'd', 'dr', 'f', 'g', 'gr', 'h', 'j', 'k', 'kr', 'l',
        'm', 'n', 'p', 'ph', 'pr', 'q', 'r', 's', 'sh', 'st', 't', 'tr', 'v', 'w', 'z'
    )
    $vowels = @('a', 'e', 'i', 'o', 'u', 'ae', 'ai', 'ea', 'ie', 'oa', 'oo')

    $builder = New-Object System.Text.StringBuilder
    $useConsonant = [bool](Get-Random -Minimum 0 -Maximum 2)

    while ($builder.Length -lt $TargetLength) {
        $chunk = if ($useConsonant) {
            $consonants | Get-Random
        } else {
            $vowels | Get-Random
        }

        [void]$builder.Append($chunk)
        $useConsonant = -not $useConsonant
    }

    return $builder.ToString().Substring(0, $TargetLength)
}

function Set-PronounceableCase {
    param(
        [Parameter(Mandatory)]
        [string]$Text,

        [Parameter(Mandatory)]
        [ValidateSet('lowerUPPER', 'UPPERlower', 'CamelCase', 'lowerOnly', 'UPPEROnly')]
        [string]$Mode
    )

    if ([string]::IsNullOrWhiteSpace($Text)) {
        return $Text
    }

    $pivot = [Math]::Floor($Text.Length / 2)
    $first = $Text.Substring(0, $pivot)
    $second = $Text.Substring($pivot)

    switch ($Mode) {
        'lowerUPPER' {
            return $first.ToLowerInvariant() + $second.ToUpperInvariant()
        }
        'UPPERlower' {
            return $first.ToUpperInvariant() + $second.ToLowerInvariant()
        }
        'CamelCase' {
            $lower = $Text.ToLowerInvariant()
            $pivot2 = [Math]::Floor($lower.Length / 2)
            if ($pivot2 -eq 0) {
                return $lower.Substring(0, 1).ToUpperInvariant() + $lower.Substring(1)
            }

            $a = $lower.Substring(0, $pivot2)
            $b = $lower.Substring($pivot2)

            $a = $a.Substring(0, 1).ToUpperInvariant() + $a.Substring(1)
            $b = $b.Substring(0, 1).ToUpperInvariant() + $b.Substring(1)
            return $a + $b
        }
        'lowerOnly' {
            return $Text.ToLowerInvariant()
        }
        'UPPEROnly' {
            return $Text.ToUpperInvariant()
        }
    }
}

function New-RandomChars {
    param(
        [Parameter(Mandatory)]
        [string[]]$CharacterSet,

        [Parameter(Mandatory)]
        [int]$Count
    )

    if ($Count -le 0) {
        return ''
    }

    $chars = for ($i = 0; $i -lt $Count; $i++) {
        $CharacterSet | Get-Random
    }

    return -join $chars
}

$requiredNonLetters = $MinNumOfDigits + $MinNumOfSpecialChars
if ($requiredNonLetters -gt $Length) {
    throw "The combined minimum for digits and special characters ($requiredNonLetters) cannot be greater than Length ($Length)."
}

$lettersLength = $Length - $requiredNonLetters
if ($lettersLength -lt 1) {
    throw 'Length is too short to include any pronounceable letters after required digits/special characters are applied.'
}

$results = for ($n = 0; $n -lt $Count; $n++) {
    $effectiveCase = if ($Case -eq 'Random') {
        @('lowerUPPER', 'UPPERlower', 'CamelCase') | Get-Random
    } else {
        $Case
    }

    $letters = New-PronounceableText -TargetLength $lettersLength
    $letters = Set-PronounceableCase -Text $letters -Mode $effectiveCase

    $digits = New-RandomChars -CharacterSet @('0', '1', '2', '3', '4', '5', '6', '7', '8', '9') -Count $MinNumOfDigits
    $specialChars = New-RandomChars -CharacterSet @('!', '@', '#', '$', '%', '&', '*', '?') -Count $MinNumOfSpecialChars

    $effectiveOrder = if ($Order -eq 'Random') {
        @(
            'LettersDigitsSpecialChars',
            'LettersSpecialCharsDigits',
            'DigitsLettersSpecialChars',
            'DigitsSpecialCharsLetters',
            'SpecialCharsLettersDigits',
            'SpecialCharsDigitsLetters'
        ) | Get-Random
    } else {
        $Order
    }

    switch ($effectiveOrder) {
        'LettersDigitsSpecialChars' { $letters + $digits + $specialChars }
        'LettersSpecialCharsDigits' { $letters + $specialChars + $digits }
        'DigitsLettersSpecialChars' { $digits + $letters + $specialChars }
        'DigitsSpecialCharsLetters' { $digits + $specialChars + $letters }
        'SpecialCharsLettersDigits' { $specialChars + $letters + $digits }
        'SpecialCharsDigitsLetters' { $specialChars + $digits + $letters }
    }
}

Write-Output $results
