<#
.SYNOPSIS
    Retrieves delivery management details for specified group types and exports a report.
.DESCRIPTION
    This cmdlet retrieves details about groups (based on specified types) that accept messages only from certain users,
    compiles this information into a report, and exports it to a CSV file.
.PARAMETER GroupType
    Specifies the type of group to retrieve. Valid options are:
    - MailDistributionGroup: Retrieves mail distribution groups.
    - MailSecurityGroup: Retrieves mail security groups.
    - M365Groups: Retrieves Microsoft 365 groups.
    - DynamicGroups: Retrieves dynamic distribution groups.
    - AllDLs: Retrieves all distribution lists (default).
.PARAMETER ReportPath
Specifies the file path to save the report. This parameter is mandatory. If the file path is not fully, for example ( "\Reports\GroupReport") instead ( "C:\Reports\GroupReport.csv"), the file will b exported to Downlads by default with file as GroupReport_Date_time.csv.
.PARAMETER ResultSize
    Specifies the maximum number of results to return. Use a positive integer to limit the results or 'Unlimited' for no limit. Default is 'Unlimited'.

.PARAMETER ExpandedReport
        Include detailed permission information in the report. This includes specifics about the types of access granted to users or trustees.

.EXAMPLE
    Get-GroupDeliveryManagementReport -GroupType MailDistributionGroup -ReportPath "C:\Reports\GroupReport.csv"
    Retrieves delivery management details for all mail distribution groups and exports the report to "C:\Reports\GroupReport.csv".
.EXAMPLE
    Get-GroupDeliveryManagementReport -GroupType M365Groups -ResultSize 100 -ReportPath "C:\Reports\M365GroupReport.csv"
    Retrieves delivery management details for Microsoft 365 groups, limiting the result size to 100, and exports the report to "C:\Reports\M365GroupReport.csv".
#>

function Get-GroupDeliveryManagementReport {
    [CmdletBinding()]
    [OutputType([System.Management.Automation.PSCustomObject])]
    param(
        [Parameter(HelpMessage = "Specifies the type of group to retrieve. Valid options are 'MailDistributionGroup', 'MailSecurityGroup', 'M365Groups', 'DynamicGroups', 'AllDLs'.")]
        [ValidateSet("MailDistributionGroup", "MailSecurityGroup", "M365Groups", "DynamicGroups", "AllDLs")]
        [string]
        $GroupType = "AllDLs",

        [Parameter(Mandatory = $true, HelpMessage = "Specify the file path to save the report.")]
        [string]
        $ReportPath,

        [Parameter(HelpMessage = "Specifies the maximum number of results to return. Use a positive integer to limit the results or 'Unlimited' for no limit.")]
        [ValidateScript({
                if ($_ -eq 'Unlimited' -or ($_ -match '^\d+$' -and [int]$_ -gt 0)) {
                    $true
                }
                else {
                    throw "ResultSize must be a positive integer or 'Unlimited'"
                }
            })]
        [object]
        $ResultSize = 'Unlimited',

        [Parameter(HelpMessage = "Include detailed permission information in the report.")]
        [switch]
        $ExpandedReport
    )

    begin {
        . "$PSScriptRoot\Export-ReportCsv.ps1"
        
        if ($ResultSize -ne 'Unlimited') {
            $ResultSize = [int]$ResultSize
        }

        $reportData = @()
    }

    process {
        $groups = switch ($GroupType) {
            "MailDistributionGroup" { Get-DistributionGroup -RecipientTypeDetails MailUniversalDistributionGroup -ResultSize $ResultSize }
            "MailSecurityGroup" { Get-DistributionGroup -RecipientTypeDetails MailUniversalSecurityGroup -ResultSize $ResultSize }
            "M365Groups" { Get-UnifiedGroup -ResultSize $ResultSize }
            "DynamicGroups" { Get-DynamicDistributionGroup -ResultSize $ResultSize }
            Default { Get-DistributionGroup -ResultSize $ResultSize }
        }

        if (-not $groups) {
            Write-Error "No groups found for the specified GroupType: $GroupType"
            return
        }

        $filteredGroups = $groups | Where-Object { $_.AcceptMessagesOnlyFrom.count -ne 0 }

        function ProcessReport {
            param (
                [Parameter(Mandatory = $true)]
                [object]$UsersInfo,
                
                [Parameter(Mandatory = $true)]
                [object]$Group
            )

            if ($ExpandedReport) {
                $report = $UsersInfo | ForEach-Object {
                    [PSCustomObject]@{
                        GroupName  = $Group.DisplayName
                        GroupEmail = $Group.PrimarySMTPAddress
                        UserName   = $_.DisplayName
                        UserEmail  = $_.PrimarySMTPAddress
                    }
                }
            } else {
                $report = [PSCustomObject]@{
                    GroupName  = $Group.DisplayName
                    GroupEmail = $Group.PrimarySMTPAddress
                    UserName   = ($UsersInfo.DisplayName) -join ","
                    UserEmail  = ($UsersInfo.PrimarySMTPAddress) -join ","
                }
            }
            return $report
        }

        foreach ($group in $filteredGroups) {
            try {
                $userInfo = $group.AcceptMessagesOnlyFrom | Get-Recipient -ErrorAction Stop
                $reportData += ProcessReport -UsersInfo $userInfo -Group $group
            } catch {
                Write-Warning "Failed to retrieve recipient information for group $($group.DisplayName): $_"
                continue
            }
        }
    }

    end {
        Export-ReportCsv -ReportData $reportData -ReportPath $ReportPath
    }
}
