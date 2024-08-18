function Get-AllGroupMembershipReport {
    <#
    .SYNOPSIS
    Generates a membership report for specified group types.

    .DESCRIPTION
    This function retrieves members from various group types (distribution, security, M365, etc.) and exports the data to a CSV file.
    The report can be in a condensed or expanded format and optionally include a list of the groups.

    .PARAMETER MembershipReportType
    Specifies the format of the report: "Condensed" for summary information or "Expanded" for detailed information about each member.

    .PARAMETER GroupType
    Defines the type of groups to include in the report, such as "DistributionGroupOnly", "AllDistributionGroup", "MailSecurityGroupOnly", etc.

    .PARAMETER ExpandedReport
    Include detailed information in the report. This includes specifics about the types of access granted to users or trustees.


    .EXAMPLE
    Get-AllGroupMembershipReport -MembershipReportType Expanded -GroupType M365GroupOnly -ExportGroupList

    .NOTES
    This function requires appropriate permissions to retrieve group and member information.
    #>
    [CmdletBinding()]
    param(

        [Parameter()]
        [ValidateSet(
            "DistributionGroupOnly", "AllDistributionGroup", "MailSecurityGroupOnly", "DynamicDistributionGroup", "M365GroupOnly",
            "AllSecurityGroupIncludeM365", "AllSecurityGroupExcludeM365", "NonMailSecurityGroup", "AllDynamicSecurityGroup"
        )]
        $GroupType = "DistributionGroupOnly",

        [Parameter()]
        [ValidateSet("Condensed", "Expanded")]
        $MembershipReportType,

        [Parameter(Mandatory = $false, HelpMessage = "Specify whether the selected GroupType should be exported")]
        [switch]
        $ExpandedReport
    )

    begin {
        function Get-GroupDetails {
            param (
                [string]$GroupType
            )

            switch ($GroupType) {
                "DistributionGroupOnly" { Get-DistributionGroup -RecipientTypeDetails MailUniversalDistributionGroup -ResultSize Unlimited }
                "AllDistributionGroup" { Get-DistributionGroup -ResultSize Unlimited }
                "MailSecurityGroupOnly" { Get-DistributionGroup -RecipientTypeDetails MailUniversalSecurityGroup -ResultSize Unlimited }
                "DynamicDistributionGroup" { Get-DynamicDistributionGroup -ResultSize Unlimited }
                "M365GroupOnly" { Get-UnifiedGroup -ResultSize Unlimited }
                "AllSecurityGroupIncludeM365" { Get-AzureADMSGroup -Filter "SecurityEnabled eq true and MailEnabled eq true" }
                "NonMailSecurityGroup" { Get-AzureADMSGroup -Filter "SecurityEnabled eq true and MailEnabled eq false" }
                "AllSecurityGroupExcludeM365" { Get-AzureADMSGroup -Filter "SecurityEnabled eq true and MailEnabled eq true" | Where-Object { $_.GroupTypes -notcontains 'Unified' } }
                "AllDynamicSecurityGroup" { Get-AzureADMSGroup -Filter "SecurityEnabled eq true" | Where-Object { $_.GroupTypes -contains 'DynamicMembership' } }
                default { throw "Unknown group type: $GroupType" }
            }
        }

        function ProcessGroupMembers {
            param (
                [string]$reportType,
                [Object]$group,
                [Object[]]$groupMembers
            )

            $members = @()
            switch ($reportType) {
                "Expanded" {
                    $members = $groupMembers | ForEach-Object {
                        [PSCustomObject]@{
                            GroupName   = $group.DisplayName
                            GroupEmail  = $group.PrimarySMTPAddress
                            MemberName  = $_.DisplayName
                            MemberEmail = $_.PrimarySmtpAddress
                        }
                    }
                }
                default {
                    $members = [PSCustomObject]@{
                        GroupName   = $group.DisplayName
                        GroupEmail  = $group.PrimarySMTPAddress
                        MemberName  = ($groupMembers | ForEach-Object { $_.DisplayName }) -join ","
                        MemberEmail = ($groupMembers | ForEach-Object { $_.PrimarySmtpAddress }) -join ","
                    }
                }
            }
            return $members
        }

        function Get-GroupMembers {
            param (
                [string]$Identity,
                [string]$GroupType
            )

            switch ($GroupType) {
                "DistributionGroupOnly" { Get-DistributionGroupMember -Identity $Identity -ResultSize Unlimited }
                "AllDistributionGroup" { Get-DistributionGroupMember -Identity $Identity -ResultSize Unlimited }
                "MailSecurityGroupOnly" { Get-DistributionGroupMember -Identity $Identity -ResultSize Unlimited }
                "DynamicDistributionGroup" { Get-DynamicDistributionGroupMember -Identity $Identity -ResultSize Unlimited }
                "M365GroupOnly" { Get-UnifiedGroupLinks -Identity $Identity -LinkType Member -ResultSize Unlimited }
                "AllSecurityGroupIncludeM365" { }  # Add appropriate handling here if needed
                default { throw "Unknown group type: $GroupType" }
            }
        }
    }

    process {
        $allGroups = Get-GroupDetails -GroupType $GroupType

        if ($ExpandedReport) {
            $allGroups | Export-Csv -Path "$Home\Downloads\$GroupType`_Report_$(Get-Date -Format 'yyyy_MM_dd_HH_mm').csv" -NoTypeInformation
        }

        $allMembers = @()

        foreach ($group in $allGroups) {
            $groupMembers = Get-GroupMembers -Identity $group.PrimarySMTPAddress -GroupType $GroupType
            $allMembers += ProcessGroupMembers -reportType $MembershipReportType -group $group -groupMembers $groupMembers
        }

        $allMembers | Export-Csv -Path "$Home\Downloads\$GroupType`_Membership_$MembershipReportType`_Report_$(Get-Date -Format 'yyyy_MM_dd_HH_mm').csv" -NoTypeInformation
    }
}
