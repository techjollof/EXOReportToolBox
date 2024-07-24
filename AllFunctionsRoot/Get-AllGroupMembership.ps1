[CmdletBinding()]
param(
    # Group report type
    [Parameter()]
    [ValidateSet("Condensed","Expanded")]
    $MembershipReportType,

    # Group Tpye
    [Parameter()]
    [ValidateSet(
        "DistributionGroupOnly","AllDistributionGroup","MailSecurityGroupOnly","DynamicDistributionGroup", "M365GroupOnly",
        "AllSecurityGroupIncludeM365","AllSecurityGroupExcludeM365","NonMailSecurityGroup","AllDynamicSecurityGroup"
    )]
    $GroupType = "DistributionGroupOnly",

    # group report
    [Parameter(Mandatory = $false, HelpMessage = "Speficy whether the select GroupType should be exported")]
    [switch]
    $ExportGroupList

)
begin {

    # Budding the collection of group type to be retrieved
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
            "AllMailSecurityGroupIncludeM365" { Get-AzureADMSGroup -Filter "SecurityEnabled eq true and MailEnabled eq true" }
            "NonMailSecurityGroup" { Get-AzureADMSGroup -Filter "SecurityEnabled eq true and MailEnabled eq false" }
            "AllMailSecurityGroupExcludeM365" { Get-AzureADMSGroup -Filter "SecurityEnabled eq true and MailEnabled eq true" | Where-Object { $_.GroupTypes -notcontains 'Unified' } }
            "AllDynamicSecurityGroup" { Get-AzureADMSGroup -Filter "SecurityEnabled eq true" | Where-Object { $_.GroupTypes -contains 'DynamicMembership' } }
            default { throw "Unknown group type: $GroupType" }
        }
    }


    # process and gather all group members
    function ProcessGroupMembers {
        param (
            [string]$reportType,
            $group,
            $groupMembers
        )
    
        $members = @()
    
        switch ($reportType) {
            "Expanded" {
                foreach ($member in $groupMembers) {
                    $members += [PSCustomObject]@{
                        GroupName = $group.DisplayName
                        GroupEmail = $group.PrimarySMTPAddress
                        MemberName = $member.DisplayName
                        MemberEmail = $member.PrimarySmtpAddress
                    }
                }
            }
            default {
                $members += [PSCustomObject]@{
                    GroupName = $group.DisplayName
                    GroupEmail = $group.PrimarySMTPAddress
                    MemberName = $groupMembers.DisplayName -join ","
                    MemberEmail = $groupMembers.PrimarySmtpAddress -join ","
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
            { @("DistributionGroupOnly", "AllDistributionGroup","MailSecurityGroupOnly") -contains $_ } { Get-DistributionGroupMember -Identity $Identity -ResultSize Unlimited }
            "DynamicDistributionGroup" { Get-DynamicDistributionGroupMember -Identity $Identity -ResultSize Unlimited }
            "M365GroupOnly" { Get-UnifiedGroupLinks -Identity $Identity -LinkType Member -ResultSize Unlimited }
            "AllMailSecurityGroupIncludeM365" { }
            default { throw "Unknown group type: $GroupType" }
        }
    }
    
}

process {

    $allGroups = Get-GroupDetails -GroupType $GroupType
    
    # Exprt selected group information
    if($PSBoundParameters["ExportGroupList"]) { $allGroups | Export-Csv -Path "$Home\Downloads\$($GroupType+'_Report_'+(Get-Date -Format 'yyyy_MM_dd_HH_mm')).csv" -NoTypeInformation }
    
    # Initialize an array to store group members
    $allMembers = @()

    # Iterate through each group
    foreach ($group in $allGroups) {
        $groupMembers = Get-GroupMembers -Identity $group.PrimarySMTPAddress -GroupType $groupType
        $allMembers += ProcessGroupMembers $MembershipReportType $group $groupMembers
    }
    
    #$filtered = $allMembers | Out-GridView -PassThru -Title "Filter by User Email Address"

    $allMembers | Export-Csv -Path "$Home\Downloads\$($GroupType+'_Memebership_'+$MembershipReportType+'_Report_'+(Get-Date -Format 'yyyy_MM_dd_HH_mm')).csv" -NoTypeInformation
    #Write-Host "Group members exported to AllGroupMembers.csv"
    
}
