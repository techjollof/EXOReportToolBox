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




$Test1 = {
    Get-DistributionGroup -ResultSize Unlimited  | Where-Object { $_.AcceptMessagesOnlyFrom.count -ne 0}
}

$test2 = {
    $gp = Get-DistributionGroup -ResultSize Unlimited  
    $gp | Where-Object { $_.AcceptMessagesOnlyFrom.count -ne 0}
}

Measure-PSMDCommand -Iterations 10 -TestSet @{
    Test1 = $Test1
    Test2 = $test2
}

Measure-Command {
    $ug.AcceptMessagesOnlyFrom | Get-Recipient
}

Measure-Command {
    foreach ($User in $ug.AcceptMessagesOnlyFrom) {
        Get-Recipient $User
    }
}


$NewTest1 =  {
    $ug.AcceptMessagesOnlyFrom | Get-Recipient
}

$NewTest2 =  {
    foreach ($User in $ug.AcceptMessagesOnlyFrom) {
        Get-Recipient $User
    }
}


Measure-PSMDCommand -Iterations 10 -TestSet @{
    NewTest1 =  $NewTest1
    NewTest2 = $NewTest2
}




<#
.SYNOPSIS
    Short description
.DESCRIPTION
    Long description
.EXAMPLE
    Example of how to use this cmdlet
.EXAMPLE
    Another example of how to use this cmdlet
#>
function Get-GroupDeliveryManagementReport {
    [CmdletBinding()]
    [OutputType([type])]
    param(
        # group options
        [Parameter()]
        [ValidateSet("MailDistributionGroup", "MailSecurityGroup","M365Groups","DynamicGroups","AllDLs")]
        $GroupType = "AllDLs",

        # Export file path
        [Parameter(Mandatory =$true, HelpMessage = "Specify the file path to save the report.")]
        [string]
        $ReportPath,

        # Size
        [Parameter()]
        [string]
        $ResultSize ="Unlimited"
    )

    
    process {

        #Export function
        . "$PSScriptRoot\Export-ReportCsv.ps1" 
            
        $Result = @()
        $getGroup = switch ($GroupType) {
            "MailDistributionGroup" { Get-DistributionGroup -RecipientTypeDetails MailUniversalDistributionGroup -ResultSize $ResultSize | Where-Object { $_.AcceptMessagesOnlyFrom.count -ne 0} }
            "MailSecurityGroup" {Get-DistributionGroup -RecipientTypeDetails MailUniversalSecurityGroup -ResultSize $ResultSize  | Where-Object { $_.AcceptMessagesOnlyFrom.count -ne 0}}
            "M365Groups" {Get-UnifiedGroup -ResultSize $ResultSize  | Where-Object { $_.AcceptMessagesOnlyFrom.count -ne 0}}
            "DynamicGroups" {Get-DynamicDistributionGroup -ResultSize $ResultSize   | Where-Object { $_.AcceptMessagesOnlyFrom.count -ne 0}}
            Default {Get-DistributionGroup -ResultSize $ResultSize  | Where-Object { $_.AcceptMessagesOnlyFrom.count -ne 0}}
        }
        

        $getGroup | ForEach-Object {
            $dl = $_
            $users = $dl.AcceptMessagesOnlyFrom | ForEach-Object {
                Get-Recipient -ResultSize Unlimited | Select-Object Displ*, Prim*
            }

            $Result +=[PSCustomObject]@{

                GroupName = $dl.DisplayName
                GroupEmail = $dl.PrimarySMTPAddress
                UserName = $users.DisplayName -join ","
                UserEmail = $Users.PrimarySMTPAddress -join ","
            }
        } 

        Export-ReportCsv -ReportData $Result -ReportPath $ReportPath        
    }
}




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
        # Specifies the type of group to retrieve (default: AllDLs).
        [Parameter(HelpMessage = "Specifies the type of group to retrieve. Valid options are 'MailDistributionGroup', 'MailSecurityGroup', 'M365Groups', 'DynamicGroups', 'AllDLs'.")]
        [ValidateSet("MailDistributionGroup", "MailSecurityGroup", "M365Groups", "DynamicGroups", "AllDLs")]
        [string]
        $GroupType = "AllDLs",

        # Specifies the file path to save the report (mandatory).
        [Parameter(Mandatory = $true, HelpMessage = "Specify the file path to save the report.")]
        [string]
        $ReportPath,

        # Specifies the maximum number of results to return (default: Unlimited).
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

    process {
        # Import the Export-ReportCsv function .
        . "$PSScriptRoot\Export-ReportCsv.ps1" 

        # Ensure ResultSize is valid
        # Convert ResultSize to an integer if it is not 'Unlimited'
        if ($ResultSize -ne 'Unlimited') {
            $ResultSize = [int]$ResultSize
        }
        
        $reportData = @()

        function ProcessReport {
            param (
                [Parameter(Mandatory = $true)]
                [object]$UsersInfo,
        
                [Parameter(Mandatory = $true)]
                [object]$Group

            )

            $report = @()
            
            if ($ExpandedReport) {
                foreach ($user in $UsersInfo) {
                    $report += [PSCustomObject]@{
                        GroupName  = $group.DisplayName
                        GroupEmail = $group.PrimarySMTPAddress
                        UserName   = ($User.DisplayName) 
                        UserEmail  = ($User.PrimarySMTPAddress) 
                    }
                }
                $report
            }
            else {
                [PSCustomObject]@{
                    GroupName  = $group.DisplayName
                    GroupEmail = $group.PrimarySMTPAddress
                    UserName   = ($UsersInfo.DisplayName) -join ","
                    UserEmail  = ($UsersInfo.PrimarySMTPAddress) -join ","
                }
            }
        }
        

        $groups = switch ($GroupType) {
            "MailDistributionGroup" { Get-DistributionGroup -RecipientTypeDetails MailUniversalDistributionGroup -ResultSize $ResultSize }
            "MailSecurityGroup" { Get-DistributionGroup -RecipientTypeDetails MailUniversalSecurityGroup -ResultSize $ResultSize }
            "M365Groups" { Get-UnifiedGroup -ResultSize $ResultSize }
            "DynamicGroups" { Get-DynamicDistributionGroup -ResultSize $ResultSize }
            Default { Get-DistributionGroup -ResultSize $ResultSize }
        }

        # Check if $groups is null or empty
        if (-not $groups) {
            Write-Error "No groups found for the specified GroupType: $GroupType"
            return
        }

        $filteredGroups = $groups | Where-Object { $_.AcceptMessagesOnlyFrom.count -ne 0 }

        foreach ($group in $filteredGroups) {
            $userInfo = $group.AcceptMessagesOnlyFrom | Get-Recipient -ErrorAction SilentlyContinue
            $reportData += ProcessReport -UsersInfo $userInfo -Group $group
        }

        Export-ReportCsv -ReportData $reportData -ReportPath $ReportPath
    }

}