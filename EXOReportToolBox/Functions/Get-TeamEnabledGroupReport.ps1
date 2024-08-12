<#
.SYNOPSIS
    Generates a report of all Microsoft 365 unified groups with Team functionality.

.DESCRIPTION
    The `Get-TeamEnabledGroupReport` cmdlet retrieves information about Microsoft 365 unified groups that have the Teams functionality enabled. It collects data including group name, email, privacy type, SharePoint site URL, group owners, owners count, member count, and creation date. The gathered information is then exported to a CSV file specified by the user. Optionally, the cmdlet can leverage parallel processing for performance improvement in PowerShell 7.

.PARAMETER filePath
    Specifies the path where the report CSV file will be saved. This parameter is mandatory.

.PARAMETER UseParrallel
    (Optional) Switch parameter to enable parallel processing for faster execution. This is only applicable in PowerShell 7.

.EXAMPLE
    Get-TeamEnabledGroupReport -filePath "C:\Reports\GroupReport.csv"

    Retrieves the unified groups and exports the report to "C:\Reports\GroupReport.csv". The report includes details about each group and its Team functionality.

.EXAMPLE
    Get-TeamEnabledGroupReport -filePath "C:\Reports\GroupReport.csv" -UseParrallel

    Retrieves the unified groups with parallel processing enabled (PowerShell 7 required) and exports the report to "C:\Reports\GroupReport.csv". This can improve performance for large sets of data.
#>
function Get-TeamEnabledGroupReport {
    [CmdletBinding()]
    [OutputType([type])]
    param(
        [Parameter(Mandatory = $true)]
        [string]
        $filePath,

        # use this key if you are using PowerShell 7 and want to leverage parallel processing; this will make it faster
        [Parameter()]
        [switch]
        $UseParrallel
    )
    process {

        $reportData = @()
        . "$PSScriptRoot\Export-ReportCsv.ps1" 

        Write-Verbose "Retrieving all unified groups"
        $allUnifiedGroups = Get-UnifiedGroup -ResultSize Unlimited 

        Write-Host "Processing group information......"
        $allUnifiedGroups | ForEach-Object {
            $groupOwner = $_.ManagedBy | Get-EXORecipient

            $reportData += [PSCustomObject]@{
                GroupName      = $_.DisplayName
                GroupEmail     = $_.PrimarySMTPAddress
                TeamEnabled    = if ($_.ResourceProvisioningOptions -contains "Team") { "Enabled" }
                PrivacyType    = $_.AccessType
                SharePointSite = $_.SharePointSiteUrl
                GroupOwners    = $groupOwner.PrimarySMTPAddress -join ","
                OwnersCount    = $groupOwner.count
                MembershipCount    = $_.GroupMemberCount
                ExternalMemberCount =  $_.GroupExternalMemberCount
                MemberShipType = if($_.IsMembershipDynamic -eq $true){"Dynamic"}else{"Static"}
                CreateDate     = $_.WhenCreatedUTC
            }
        }

    }
    
    end {
        Write-Host "Exported file of the groups completed"
        Export-ReportCsv -ReportPath $filePath -ReportData $reportData
    }
}