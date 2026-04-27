<#
.SYNOPSIS
    Gets an extension attribute for one or more users from Microsoft Graph.

.DESCRIPTION
    This script retrieves a specified extension attribute (1-15) for one or more users
    from Azure AD/Microsoft 365 using Microsoft Graph PowerShell.

.PARAMETER UserId
    One or more user IDs (UPN or Object ID) to query.

.PARAMETER AttributeNum
    The extension attribute number (1-15) to retrieve.

.EXAMPLE
    .\Get-ExtensionAttribute.ps1 -UserId "user@domain.com" -AttributeNum 1

.EXAMPLE
    .\Get-ExtensionAttribute.ps1 -UserId "user1@domain.com","user2@domain.com" -AttributeNum 1

.EXAMPLE
    $users = @("user1@domain.com", "user2@domain.com", "user3@domain.com")
    .\Get-ExtensionAttribute.ps1 -UserId $users -AttributeNum 2

.EXAMPLE
    Get-Content users.txt | .\Get-ExtensionAttribute.ps1 -AttributeNum 1
#>

[CmdletBinding()]
param(
    [Parameter(Mandatory = $true, ValueFromPipeline = $true)]
    [string[]]$UserId,

    [Parameter(Mandatory = $true)]
    [ValidateRange(1, 15)]
    [int]$AttributeNum
)

begin {
    # Connect to Microsoft Graph
    Write-Host "Connecting to Microsoft Graph..." -ForegroundColor Cyan
    try {
        Connect-MgGraph -NoWelcome -Scopes "User.ReadWrite.All" -ErrorAction Stop
        Write-Host "Successfully connected to Microsoft Graph." -ForegroundColor Green
    } catch {
        Write-Error "Failed to connect to Microsoft Graph: $_"
        exit 1
    }

    # Build the attribute name
    $attributeName = "ExtensionAttribute$AttributeNum"

    # Initialize results array
    $results = @()
}

process {
    foreach ($user in $UserId) {
        Write-Host "`nQuerying user: ${user}" -ForegroundColor Yellow

        try {
            # Get the user with extension attributes
            $mgUser = Get-MgUser -UserId $user -Property Id, UserPrincipalName, DisplayName, OnPremisesExtensionAttributes -ErrorAction Stop

            # Extract the specific extension attribute value
            $attributeValue = $mgUser.OnPremisesExtensionAttributes.$attributeName

            if ($null -eq $attributeValue -or $attributeValue -eq "") {
                Write-Host "  ${attributeName}: <not set>" -ForegroundColor Gray
            } else {
                Write-Host "  ${attributeName}: ${attributeValue}" -ForegroundColor Green
            }

            # Add to results
            $results += [PSCustomObject]@{
                UserId            = $user
                UserPrincipalName = $mgUser.UserPrincipalName
                DisplayName       = $mgUser.DisplayName
                Attribute         = $attributeName
                Value             = $attributeValue
                Status            = "Success"
                Error             = $null
            }
        } catch {
            Write-Host "✗ Failed to retrieve $attributeName for ${user}" -ForegroundColor Red
            Write-Host "  Error: $($_.Exception.Message)" -ForegroundColor Red

            # Add to results
            $results += [PSCustomObject]@{
                UserId            = $user
                UserPrincipalName = $null
                DisplayName       = $null
                Attribute         = $attributeName
                Value             = $null
                Status            = "Failed"
                Error             = $_.Exception.Message
            }
        }
    }
}

end {
    # Display summary
    Write-Host "`n==================== SUMMARY ====================" -ForegroundColor Cyan
    Write-Host "Total users processed: $($results.Count)" -ForegroundColor White
    Write-Host "Successful: $($results.Where({$_.Status -eq 'Success'}).Count)" -ForegroundColor Green
    Write-Host "Failed: $($results.Where({$_.Status -eq 'Failed'}).Count)" -ForegroundColor Red
    Write-Host "=================================================" -ForegroundColor Cyan

    # Output results object
    Write-Output $results

    # Disconnect from Microsoft Graph
    # Write-Host "`nDisconnecting from Microsoft Graph..." -ForegroundColor Cyan
    # Disconnect-MgGraph | Out-Null
    # Write-Host "Disconnected." -ForegroundColor Green
}
