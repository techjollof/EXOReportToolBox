function Get-GroupMembershipReport {
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

    .PARAMETER GroupSummaryReport
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
        "DistributionGroupOnly", "MailSecurityGroupOnly", "AllDistributionGroup", "DynamicDistributionGroup", "M365GroupOnly", "AllSecurityGroup",
        "NonMailSecurityGroup", "SecurityGroupExcludeM365", "M365SecurityGroup", "DynamicSecurityGroup", "DynamicSecurityExcludeM365", "AllGroups"
    )]
    $GroupType = "DistributionGroupOnly",

    [Parameter()]
    [switch]$ExpandedReport,

    [Parameter(Mandatory = $false, HelpMessage = "Specify whether the selected GroupType should be exported")]
    [switch]$GroupSummaryReport
)

begin {
    function Get-GroupDetails {
        param (
            [ValidateSet(
                "DistributionGroupOnly", "MailSecurityGroupOnly", "AllDistributionGroup", "DynamicDistributionGroup", "M365GroupOnly", "AllSecurityGroup",
                "NonMailSecurityGroup", "SecurityGroupExcludeM365", "M365SecurityGroup", "DynamicSecurityGroup", "DynamicSecurityExcludeM365", "AllGroups"
            )]
            $GroupType
        )

        Write-Host "Retrieving group details for $GroupType..."
        try {
            switch ($GroupType) {
            
                "DistributionGroupOnly" { Get-DistributionGroup -RecipientTypeDetails MailUniversalDistributionGroup -ResultSize Unlimited }
                "AllDistributionGroup" { Get-DistributionGroup -ResultSize Unlimited }
                "MailSecurityGroupOnly" { Get-DistributionGroup -RecipientTypeDetails MailUniversalSecurityGroup -ResultSize Unlimited }
                "DynamicDistributionGroup" { Get-DynamicDistributionGroup -ResultSize Unlimited }
                "M365GroupOnly" { Get-MgGroup -Filter "groupTypes/any(c:c eq 'Unified')" }
                "AllSecurityGroup" { Get-MgGroup -Filter "SecurityEnabled eq true" }
                "NonMailSecurityGroup" { Get-MgGroup -Filter "SecurityEnabled eq true and MailEnabled eq false" }
                "SecurityGroupExcludeM365" { Get-MgGroup -Filter "SecurityEnabled eq true" | Where-Object { "Unified" -notin $_.GroupTypes } }
                "M365SecurityGroup" { Get-MgGraph -Filter "SecurityEnabled eq true and groupTypes/any(c:c eq 'Unified')" }
                "DynamicSecurityGroup" { Get-MgGroup -Filter "groupTypes/any(c:c eq 'DynamicMembership')" }
                "DynamicSecurityExcludeM365" { Get-MgGroup -Filter "SecurityEnabled eq true and groupTypes/any(c:c eq 'DynamicMembership')" }
                default { throw "Unknown group type: $GroupType" }
            }
        }
        catch {
            Write-Host "Error occurred while fetching groups for type '$GroupType': $_"
            throw $_
        }
    }

    function ProcessGroupMembers {
        param (
            [Object]$Group,
            [Object[]]$GroupMembers,
            [switch]$ExpandedReport
        )

        $members = @()

        # Get the owner information and group email addresses depending to the group type or command source, EXO or Graph
        if ($group.PSObject.Properties.Name -contains "ManagedBy") {
            $OwnerInfo = if ($Group.ManagedBy.count -ne 0) { $Group.ManagedBy | ForEach-Object { Get-Recipient $_ } } else { "" }
            $OwnerEmail = if ($OwnerInfo.count -ne 0) { $OwnerInfo.PrimarySmtpAddress -join "," } else { "No Owners" }
            $OwnerName = if ($OwnerInfo.count -ne 0) { $OwnerInfo.DisplayName -join "," } else { "No Owners" }
        }
        else {
            try {
                # Attempt to get the group owners via Microsoft Graph
                $OwnerInfo = (Get-MgGroupOwner -GroupId $group.ExternalDirectoryObjectId).AdditionalProperties
                # If owners are found, retrieve their details
                $OwnerEmail = if ($OwnerInfo.count -ne 0) { $OwnerInfo.mail -join "," } else { "No Owners" }
                $OwnerName = if ($OwnerInfo.count -ne 0) { $OwnerInfo.displayName -join "," } else { "No Owners" }
            }
            catch {
                # Handle errors (e.g., group not found or inaccessible)
                Write-Warning "Failed to retrieve owner information for group: $($group.DisplayName). Error: $_"
                $OwnerEmail = "Error retrieving owners"
                $OwnerName = "Error retrieving owners"
            }
        }

        # Get group email address
        $GroupEmail = if ($group.PSObject.Properties.Name -contains "PrimarySMTPAddress") {
            $Group.PrimarySMTPAddress
        }
        else {
            $Group.Mail
        }

        # Process the group members
        if ($ExpandedReport -and $GroupMembers.Count -ne 0) {
            $members = $groupMembers | ForEach-Object {
                [PSCustomObject]@{
                    GroupName   = $group.DisplayName
                    GroupEmail  = $GroupEmail
                    OwnerName   = $OwnerName
                    OwnerEmail  = $OwnerEmail
                    MemberName  = $_.DisplayName
                    MemberEmail = $_.PrimarySmtpAddress
                }
            }
        }

        else {
            # Default report: handle cases with no members
            $memberNames = if ($GroupMembers.Count -eq 0) { "No Members" } else { ($GroupMembers | ForEach-Object { $_.DisplayName }) -join "," }
            $memberEmails = if ($GroupMembers.Count -eq 0) { "No Members" } else { ($GroupMembers | ForEach-Object { $_.PrimarySmtpAddress }) -join "," }

            $members = [PSCustomObject]@{
                GroupName   = $group.DisplayName
                GroupEmail  = $GroupEmail
                OwnerName   = $OwnerName
                OwnerEmail  = $OwnerEmail
                MemberName  = $memberNames
                MemberEmail = $memberEmails
            }
        }
    
        return $members
    }

    # Get members of a group
    function Get-GroupMembers {
        param (
            [string]$GroupId,
            [string]$GroupType
        )

        Write-Host "Retrieving members for group: $GroupId"
    
        switch ($GroupType) {
            { @("DistributionGroupOnly", "MailSecurityGroupOnly", "AllDistributionGroup") } {
                return Get-DistributionGroupMember -Identity $GroupId -ResultSize Unlimited
            }
            "DynamicDistributionGroup" {
                return Get-DynamicDistributionGroupMember -Identity $GroupId -ResultSize Unlimited
            }
            { @("M365GroupOnly", "AllSecurityGroup", "NonMailSecurityGroup", "SecurityGroupExcludeM365", "M365SecurityGroup", "DynamicSecurityGroup", "DynamicSecurityExcludeM365", "AllGroups") } {
                # Handle these group types (you can adjust the logic to suit the appropriate command)
                return Get-MgGroupMember -GroupId $GroupId -All
            }
            default {
                throw "Unknown group type: $GroupType"
            }      
        }
    }
    
    
}

process {
    $allGroups = Get-GroupDetails -GroupType $GroupType

    # Export the list of groups if $GroupSummaryReport is specified
    if ($GroupSummaryReport) {
        $allGroups | Export-Csv -Path "$Home\Downloads\$GroupType`_Report_$(Get-Date -Format 'yyyy_MM_dd_HH_mm').csv" -NoTypeInformation
    }

    $allMembers = @()

    foreach ($group in $allGroups) {
        $groupMembers = Get-GroupMembers -GroupId $group.PrimarySMTPAddress -GroupType $GroupType
        $allMembers += ProcessGroupMembers -ReportType $ReportType -Group $group -groupMembers $groupMembers
    }

    $allMembers # | Export-Csv -Path "$Home\Downloads\$GroupType`_Membership_$MembershipReportType`_Report_$(Get-Date -Format 'yyyy_MM_dd_HH_mm').csv" -NoTypeInformation
}
}
