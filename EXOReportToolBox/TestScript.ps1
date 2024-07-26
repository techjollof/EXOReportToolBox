# Main script
# Define the script root manually
$scriptRoot = Split-Path -Parent $MyInvocation.MyCommand.Path

# Define the report data
$reportData = @(
    @{ Name = "John Doe"; Age = 30; Position = "Developer" },
    @{ Name = "Jane Smith"; Age = 25; Position = "Designer" }
)

# Specify the file path
$filePath = "$scriptRoot/Reports/EmployeeReport.csv" # Update this path as needed

# Source the Export-ReportCsv.ps1 script
$exportScriptPath = "$scriptRoot/Export-ReportCsv.ps1"

if (Test-Path -Path $exportScriptPath) {
    . $exportScriptPath
    # Call the function to export the data to CSV with appended date and time
    Export-ReportCsv -FilePath $filePath -ReportData $reportData
} else {
    Write-Error "The script Export-ReportCsv.ps1 could not be found at $exportScriptPath"
}


$User = Get-Mailbox "it@itpro.work.gd"
Get-DistributionGroup | Where-Object { 
    $_.AcceptMessagesOnlyFrom -ne $null -and $_.AcceptMessagesOnlyFrom -contains $User.Name
} | Select-Object DisplayName, PrimarySMTPAddress | Export-csv $("$Home\Downloads\"+$User.DisplayName+"_assigned_dm.csv" -replace(" ","_")) -NoTypeInformation




function Get-MailboxPermissionReport {
    [CmdletBinding()]
    param (
        [Parameter(ParameterSetName="SpecificMailboxes")]
        [string[]]
        $MailboxAddress,

        [Parameter(ParameterSetName="Bulk")]
        [ValidateSet("UserMailbox","SharedMailbox","RoomMailbox","All")]
        $MailboxTypes = "All",

        [Parameter()]
        [switch]
        $ExpandedReport
    )

    # Fetch mailboxes in batch to reduce multiple Get-Mailbox calls
    $mailboxes = Get-Mailbox -Identity $MailboxAddress -ErrorAction SilentlyContinue

    $permReport = foreach ($mailbox in $mailboxes) {
        if ($null -ne $mailbox) {
            # Fetch full access permissions
            $fullAccess = Get-MailboxPermission -Identity $mailbox.Identity | Where-Object { $_.User -ne "NT AUTHORITY\SELF" }
            # Fetch SendAs permissions
            $sendAs = Get-RecipientPermission -Identity $mailbox.Identity | Where-Object { $_.Trustee -ne "NT AUTHORITY\SELF" }
            # Fetch SendOnBehalf permissions
            $sendOnBehalfCheck = $mailbox.GrantSendOnBehalfTo
            $sendOnBehalf = if ($null -ne $sendOnBehalfCheck) {
                $sendOnBehalfCheck | ForEach-Object { 
                    $recipient = Get-Recipient $_ -ErrorAction SilentlyContinue
                    if ($null -ne $recipient) { $recipient.PrimarySMTPAddress }
                }
            }

            # Build the report object
            [PSCustomObject]@{
                DisplayName   = $mailbox.DisplayName
                EmailAddress  = $mailbox.PrimarySMTPAddress
                ReadManage    = ($fullAccess | Select-Object -ExpandProperty User) -join ","
                SendAs        = ($sendAs | Select-Object -ExpandProperty Trustee) -join ","
                SendOnBehalf  = ($sendOnBehalf) -join ","
            }
        }
    }

    return $permReport
}



Get-AllGroupMembershipReport {
    [CmdletBinding()]
    param(
        # Group report type
        [Parameter()]
        [ValidateSet("Condensed", "Expanded")]
        $MembershipReportType,

        # Group Tpye
        [Parameter()]
        [ValidateSet(
            "DistributionGroupOnly", "AllDistributionGroup", "MailSecurityGroupOnly", "DynamicDistributionGroup", "M365GroupOnly",
            "AllSecurityGroupIncludeM365", "AllSecurityGroupExcludeM365", "NonMailSecurityGroup", "AllDynamicSecurityGroup"
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
                            GroupName   = $group.DisplayName
                            GroupEmail  = $group.PrimarySMTPAddress
                            MemberName  = $member.DisplayName
                            MemberEmail = $member.PrimarySmtpAddress
                        }
                    }
                }
                default {
                    $members += [PSCustomObject]@{
                        GroupName   = $group.DisplayName
                        GroupEmail  = $group.PrimarySMTPAddress
                        MemberName  = $groupMembers.DisplayName -join ","
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
                { @("DistributionGroupOnly", "AllDistributionGroup", "MailSecurityGroupOnly") -contains $_ } { Get-DistributionGroupMember -Identity $Identity -ResultSize Unlimited }
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
        if ($PSBoundParameters["ExportGroupList"]) { $allGroups | Export-Csv -Path "$Home\Downloads\$($GroupType+'_Report_'+(Get-Date -Format 'yyyy_MM_dd_HH_mm')).csv" -NoTypeInformation }
    
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

}


