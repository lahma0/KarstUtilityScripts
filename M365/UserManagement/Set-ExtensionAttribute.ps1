<#
.SYNOPSIS
    Sets an extension attribute for one or more users in Microsoft Graph.

.DESCRIPTION
    This script sets a specified extension attribute (1-15) for one or more users
    in Azure AD/Microsoft 365 using Microsoft Graph PowerShell.

.PARAMETER UserId
    One or more user IDs (UPN or Object ID) to update.

.PARAMETER AttributeNum
    The extension attribute number (1-15) to set.

.PARAMETER Value
    The value to set for the extension attribute.

.EXAMPLE
    .\Set-ExtensionAttribute.ps1 -UserId "user@domain.com" -AttributeNum 1 -Value "Department123"

.EXAMPLE
    .\Set-ExtensionAttribute.ps1 -UserId "user1@domain.com","user2@domain.com" -AttributeNum 1 -Value "IT"

.EXAMPLE
    $users = @("user1@domain.com", "user2@domain.com", "user3@domain.com")
    .\Set-ExtensionAttribute.ps1 -UserId $users -AttributeNum 2 -Value "Project-Alpha"
#>

[CmdletBinding()]
param(
    [Parameter(Mandatory = $true, ValueFromPipeline = $true)]
    [string[]]$UserId,

    [Parameter(Mandatory = $true)]
    [ValidateRange(1, 15)]
    [int]$AttributeNum,

    [Parameter(Mandatory = $true)]
    [string]$Value
)

begin {
    # Connect to Microsoft Graph
    Write-Host "Connecting to Microsoft Graph..." -ForegroundColor Cyan
    try {
        Connect-MgGraph -Scopes "User.ReadWrite.All" -ErrorAction Stop
        Write-Host "Successfully connected to Microsoft Graph." -ForegroundColor Green
    }
    catch {
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
        Write-Host "`nProcessing user: $user" -ForegroundColor Yellow

        try {
            # Create hashtable with the specific extension attribute
            $extensionAttributes = @{
                $attributeName = $Value
            }

            # Update the user
            Update-MgUser -UserId $user -OnPremisesExtensionAttributes $extensionAttributes -ErrorAction Stop

            Write-Host "✓ Successfully set $attributeName to '$Value' for $user" -ForegroundColor Green

            # Add to results
            $results += [PSCustomObject]@{
                UserId    = $user
                Attribute = $attributeName
                Value     = $Value
                Status    = "Success"
                Error     = $null
            }
        }
        catch {
            Write-Host "✗ Failed to set $attributeName for $user" -ForegroundColor Red
            Write-Host "  Error: $($_.Exception.Message)" -ForegroundColor Red

            # Add to results
            $results += [PSCustomObject]@{
                UserId    = $user
                Attribute = $attributeName
                Value     = $Value
                Status    = "Failed"
                Error     = $_.Exception.Message
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
