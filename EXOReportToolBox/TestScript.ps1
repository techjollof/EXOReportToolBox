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


Function Get-CalendarFolderPermissionReport {
    <#
    .SYNOPSIS
        Retrieves calendar permissions for specified mailboxes or all mailboxes if none are specified.
    
    .DESCRIPTION
        This script queries specified mailboxes or all mailboxes if no specific mailboxes are provided,
        and retrieves the calendar permissions for each mailbox. It outputs the results in a custom object
        format with details of mailbox name, email, folder name, user, and permissions.
    
    .PARAMETER MailboxTypes
        Specifies the types of mailboxes to include. You can specify multiple values separated by commas, such as UserMailbox, SharedMailbox.
    
    .PARAMETER SpecificMailboxes
        Specifies individual mailboxes to include. You can specify multiple mailbox identifiers separated by commas.
    
    .PARAMETER ResultSize
        Specifies the number of results to return. The default value is "Unlimited".
    
    .EXAMPLE
        .\Get-MailboxCalendarPermissions.ps1 -MailboxTypes "UserMailbox"
        Retrieves and displays the calendar permissions for all user mailboxes.
    
    .EXAMPLE
        .\Get-MailboxCalendarPermissions.ps1 -SpecificMailboxes "userA","userB"
        Retrieves and displays the calendar permissions for the specified mailboxes.
    #>
    
    [CmdletBinding()]
    param(
        [Parameter(ParameterSetName = "MailBoxTypes")]
        [ValidateSet("UserMailbox", "SharedBox", "RoomMailbox", "All")]
        [ValidateScript({
                if ($_ -contains "All" -and $_.Count -gt 1) {
                    throw "The 'All' option cannot be selected together with other mailbox types."
                }
                return $true
            })]
        [string[]]
        $MailboxTypes = "All",
    
        [Parameter(ParameterSetName = "SpecificMailboxes")]
        [string[]]
        $SpecificMailboxes,

        # report path
        [Parameter()]
        [string]
        $ReportPath,

        [Parameter()]
        $ResultSize = "Unlimited"
    )
    
    process {

        #Export function
        . "$PSScriptRoot\Export-ReportCsv.ps1"

        # Get recipients based on the provided parameters
        $allRecipients = if ($SpecificMailboxes) {
            $SpecificMailboxes | ForEach-Object { Get-EXOMailbox $_ -ErrorAction SilentlyContinue }
        }
        else {
            Get-EXOMailbox -RecipientTypeDetails $MailboxTypes -ResultSize $ResultSize
        }

        if ($allRecipients.count -eq 0) {
            Write-Output "All the specified recipients are invalid"
            return
        }

        if ($SpecificMailboxes) {
            $allEmail = Get-EXORecipient -RecipientTypeDetails UserMailbox, SharedMailbox, MailUser
        }else{
            $allEmail = $allRecipients
        }

        $reportData = @()
        $totalRecipients = $allRecipients.Count
        $userEmailCache = @{} # Create a hashtable to cache UserEmail lookups

        $count = 0
        # Iterate over each recipient
        $allRecipients | ForEach-Object {

            $recipient = $_

            # Get calendar folder permissions for the recipient
            $folderPerms = Get-EXOMailboxFolderPermission -Identity "$($recipient.PrimarySMTPAddress):\Calendar" -ErrorAction SilentlyContinue | Where-Object { $_.User -notin "Default", "Anonymous" }
            if ($folderPerms) {
                # Iterate over each permission entry
                $folderPerms | ForEach-Object {
                    # Cache the email lookup to avoid repeated Get-EXORecipient calls
                    if (-not $userEmailCache.ContainsKey($_.User)) {
                        $userEmailCache[$_.User] = ($allRecipients | Where-Object {$_.DisplayName -eq $_.User}).PrimarySMTPAddress
                    }

                    # Create a custom object for each permission entry
                    $reportData += [PSCustomObject]@{
                        MailboxName  = $recipient.DisplayName
                        MailboxEmail = $recipient.PrimarySMTPAddress
                        User         = $_.User
                        UserEmail    = $userEmailCache[$_.User]
                        Permissions  = $_.AccessRights -join ","
                    }
                }

                # Increment the count
                $count++
                if ($count % 20 -eq 0) {
                    Write-Output "A total of $($count) out of $($totalRecipients) mailboxes have been processed."
                }
            }

        }
    }
    end {

        Write-Output "Calender Report export has been completed"
        Export-ReportCsv -ReportData $reportData -ReportPath $ReportPath
    }
    
}


function Write-Message {
    param (
        [string]$Message,
        [string]$TextColor = "White", # Default to White if no color specified
        [switch]$Logging,
        [switch]$BatchWrite
    )

    # Log the message if the logging switch is enabled
    if ($Logging) {
        $TimestampedMessage = "$(Get-Date -Format 'yyyy-MM-dd HH:mm:ss') - $Message"
        if ($BatchWrite) {
            # Store messages in a global array for batch writing
            $global:LogMessages += $TimestampedMessage
        }
        else {
            # Write immediately if batch writing is not enabled
            Add-Content -Path $LoggingPath -Value $TimestampedMessage
        }
    }
    else {
        Write-Host "`n$Message`n" -ForegroundColor $TextColor
    } 
}

function Write-Log {
    param (
        [string]$LogPath
    )

    if ($global:LogMessages.Count -gt 0) {
        # Write all batched messages to the log file at once
        $global:LogMessages | Add-Content -Path $LoggingPath
        # Clear the global array after writing
        $global:LogMessages.Clear()
    }
}



do {
    # Display the menu
    Write-Message -Message $UserPrompt -TextColor "Green"
    $actions | ForEach-Object { Write-Output "`t$_" }

    # Get user choice
    $choice = Read-Host "Please enter the number of your choice" 

    switch ($choice) {
        '1' {
            $MailboxRecoverableItemsFolderStats = @()
            
            $Mailboxes | ForEach-Object {
                $PrimaryMailbox = $_
                $ArchiveMailbox = $ArchiveMailboxes | Where-Object {$_.UserPrincipalName -eq $PrimaryMailbox.UserPrincipalName}
                $MailboxRecoverableItemsFolderStats += if ($ArchiveMailbox) {
                    Get-MailboxRecoverableStatistics -MailboxId $PrimaryMailbox -ArchiveMailboxId $ArchiveMailbox
                } else {
                    Get-MailboxRecoverableStatistics -MailboxId $PrimaryMailbox
                }

                Write-Message -Message $Error[0] -Logging
            }

            if ($MailboxRecoverableItemsFolderStats) {
                Write-Verbose "Recoverable items folder statistics have been exported to $($ReportDirectory)" -Verbose
                $MailboxRecoverableItemsFolderStats | Export-Csv -Path $RecoverableFolderStatsPath -NoTypeInformation
            } else {
                Write-Message "There is no content due to invalid mailbox information provided; ending program and providing mailboxes." -TextColor Red -MessageAndLogging
            }
        }
        '2' {
            Write-Message "Removing retention policies and holds applied to the mailboxes and creating consent from removal of ComplianceTagHoldApplied policy"
            Set-Content $ConsentFormPath -Value $ConsentForm -Force

            $Mailboxes | ForEach-Object { 
                $InitialHoldConfig += Remove-MailboxHoldConfig -MailboxID $_.Identity -CompliancePolicy $ComplianceHolds
                Write-Message -Message $Error[0] -Logging
            }
        }
        '3' { 
            Write-Message "Generating report for retention policies and holds applied to the mailboxes."
            $ReportInitialHoldConfig = @()
            $Mailboxes | ForEach-Object {
                $ReportInitialHoldConfig += Remove-MailboxHoldConfig -MailboxID $_.Identity -CompliancePolicy $ComplianceHolds -HoldReportOnly
                Write-Message -Message $Error[0] -Logging
            }
            $ReportInitialHoldConfig | Export-Csv (Join-FileDirectoryPath -ReportDirectory $ReportDirectory -ReportFileName "Preview_Report_Mailbox_Holds.csv") -NoTypeInformation
            $ReportInitialHoldConfig | Out-GridView -Title "Mailbox Initial Hold configuration"
        }
        '4' { 
            if ($InitialHoldConfig.Count -eq 0) {
                Write-Message "There are no default saved settings from the selected mailboxes to restore" -TextColor Yellow -MessageAndLogging
            } else {
                Restore-MailboxHoldConfig -InitialMailboxHoldConfig $InitialHoldConfig
            }
        }
        '5' { 
            if ($InitialHoldConfig.Count -eq 0) {
                Write-Message "There are no default saved settings from the selected mailboxes to remove delay hold" -TextColor Yellow -MessageAndLogging
            } else {
                Remove-ComplianceDelayHold -MailboxIds $Mailboxes
            }
        }
        '6' { 
            if ($Mailboxes -and -not $InitialHoldConfig) {
                $confirmAction = Read-Host "The hold has been removed for the mailboxes. Are you sure you want to proceed? (Y/N) "
                
                if ($confirmAction.ToLower() -in 'y', "yes") {
                    Start-MRMProcessing -MailboxIds $Mailboxes
                    Write-Message "MRM processing started for the specified mailboxes." -TextColor Yellow
                } else {
                    Write-Message "Action canceled." -TextColor Yellow
                }
            } else {
                Start-MRMProcessing -MailboxIds $Mailboxes
            }
        }
        '7' {
            if ($InitialHoldConfig) {
                $InitialHoldConfig | Export-Csv $MailboxInitialHoldConfigPath -NoTypeInformation
                $InitialHoldConfig | Out-GridView -Title "Mailbox Initial Hold configuration"
            } else {
                Write-Message -Message "The mailboxes have not yet been processed; no initial configuration has been retrieved." -TextColor "Yellow" -MessageAndLogging
            }
        }
        'q' {
            if ($InitialHoldConfig) {
                Write-Message -Message "Exporting initial mailbox settings and configuration" -TextColor "green" -Logging
                $InitialHoldConfig | Export-Csv $MailboxInitialHoldConfigPath -NoTypeInformation
            }
            Write-Message "Happy Using....Exiting..." -TextColor Yellow
            Write-Message -Message $logFooter -Logging
            exit
        }
        default { 
            Write-Message "Invalid choice. Please select a valid option." -TextColor "Red" 
        }
    }
    Write-Log
} while ($choice -ne 'q') 



switch ($choice) {
    '1' {
        $MailboxRecoverableItemsFolderStats = @()
        Write-Host "Number $($Mailboxes.count)"
        $Mailboxes | ForEach-Object {
            $PrimaryMailbox = $_
            $ArchiveMailbox = $ArchiveMailboxes | Where-Object { $_.UserPrincipalName -eq $PrimaryMailbox.UserPrincipalName }
            $MailboxRecoverableItemsFolderStats += if ($ArchiveMailbox) {
                Get-MailboxRecoverableStatistics -MailboxId $PrimaryMailbox -ArchiveMailboxId $ArchiveMailbox
            }
            else {
                Get-MailboxRecoverableStatistics -MailboxId $PrimaryMailbox
            }

            Write-Message -Message $Error[0] -Logging
        }

        if ($MailboxRecoverableItemsFolderStats) {
            Write-Verbose "Recoverable items folder statistics have been exported to $($ReportDirectory)" -Verbose
            $MailboxRecoverableItemsFolderStats | Export-Csv -Path $RecoverableFolderStatsPath -NoTypeInformation
        }
        else {
            Write-Message "There is no content due to invalid mailbox information provided; ending program and providing mailboxes." -TextColor Red -MessageAndLogging
        }
    }
    '2' {
        Write-Message "Removing retention policies and holds applied to the mailboxes and creating consent from removal of ComplianceTagHoldApplied policy"
        Set-Content $ConsentFormPath -Value $ConsentForm -Force

        $Mailboxes | ForEach-Object { 
            $InitialHoldConfig += Remove-MailboxHoldConfig -MailboxID $_.Identity -CompliancePolicy $ComplianceHolds
            Write-Message -Message $Error[0] -Logging
        }
    }
    '3' { 
        Write-Message "Generating report for retention policies and holds applied to the mailboxes."
        $ReportInitialHoldConfig = @()
        $Mailboxes | ForEach-Object {
            $ReportInitialHoldConfig += Remove-MailboxHoldConfig -MailboxID $_.Identity -CompliancePolicy $ComplianceHolds -HoldReportOnly
            Write-Message -Message $Error[0] -Logging
        }
        $ReportInitialHoldConfig | Export-Csv (Join-FileDirectoryPath -ReportDirectory $ReportDirectory -ReportFileName "Preview_Report_Mailbox_Holds.csv") -NoTypeInformation
        $ReportInitialHoldConfig | Out-GridView -Title "Mailbox Initial Hold configuration"
    }
    '4' { 
        if ($InitialHoldConfig.Count -eq 0) {
            Write-Message "There are no default saved settings from the selected mailboxes to restore" -TextColor Yellow -MessageAndLogging
        }
        else {
            Restore-MailboxHoldConfig -InitialMailboxHoldConfig $InitialHoldConfig
        }
    }
    '5' { 
        if ($InitialHoldConfig.Count -eq 0) {
            Write-Message "There are no default saved settings from the selected mailboxes to remove delay hold" -TextColor Yellow -MessageAndLogging
        }
        else {
            Remove-ComplianceDelayHold -MailboxIds $Mailboxes
        }
    }
    '6' { 
        if ($Mailboxes -and -not $InitialHoldConfig) {
            $confirmAction = Read-Host "The hold has been removed for the mailboxes. Are you sure you want to proceed? (Y/N) "
            
            if ($confirmAction.ToLower() -in 'y', "yes") {
                Write-Message "MRM processing started for the specified mailboxes." -TextColor Yellow -MessageAndLogging
                Start-MRMProcessing -MailboxIds $Mailboxes
                Write-Message "MRM processing started for the specified mailboxes." -TextColor Yellow -MessageAndLogging
            }
            else {
                Write-Message "MRM Action canceled." -TextColor Yellow -MessageAndLogging
            }
        }
        else {
            Start-MRMProcessing -MailboxIds $Mailboxes
        }
    }
    '7' {
        if ($InitialHoldConfig) {
            $InitialHoldConfig | Export-Csv $MailboxInitialHoldConfigPath -NoTypeInformation
            $InitialHoldConfig | Out-GridView -Title "Mailbox Initial Hold configuration"
        }
        else {
            Write-Message -Message "The mailboxes have not yet been processed; no initial configuration has been retrieved." -TextColor "Yellow" -MessageAndLogging
        }
    }
    'q' {
        if ($InitialHoldConfig) {
            Write-Message -Message "Exporting initial mailbox settings and configuration" -TextColor "green" -Logging
            $InitialHoldConfig | Export-Csv $MailboxInitialHoldConfigPath -NoTypeInformation
        }
        Write-Message "Happy Using....Exiting..." -TextColor Yellow
        Write-Message -Message $logFooter -Logging
        exit
    }
    default { 
        Write-Message "Invalid choice. Please select a valid option." -TextColor "Red" 
    }
}
Write-Log
} while ($choice -ne 'q') 





function Get-MailboxInfo {
    param (
        [Parameter(ParameterSetName = "ByMailboxID", Mandatory = $true, ValueFromPipeline = $true)]
        [string]$MailboxID,

        [Parameter(ParameterSetName = "ByRecipientType", Mandatory = $true)]
        [ValidateSet("UserMailbox", "SharedMailbox", "RoomMailbox", "EquipmentMailbox", "AllMailboxes")]
        [string[]]$RecipientType
    )

    try {
        if ($MailboxID) {
            # Retrieve mailbox information by MailboxID
            $mailboxInfo = Get-EXOMailbox -Identity $MailboxID -Properties DisplayName, UserPrincipalName, GUID, RetentionHoldEnabled, LitigationHoldEnabled, DelayHoldApplied, InPlaceHolds, ElcProcessingDisabled, ComplianceTagHoldApplied, SingleItemRecoveryEnabled, 
            RetainDeletedItemsFor, ExchangeGuid, ExternalDirectoryObjectId, LegacyExchangeDN, DistinguishedName, ArchiveStatus, ArchiveQuota, AutoExpandingArchiveEnabled, RecoverableItemsQuota -ErrorAction SilentlyContinue
            
            $ArchiveMailbox = Get-EXOMailbox $MailboxID -Archive -PropertySets Quota -ErrorAction SilentlyContinue

            return $mailboxInfo, $ArchiveMailbox
        }
        elseif ($RecipientType) {
            # Validate that 'AllMailboxes' is not included with multiple selections
            if ($RecipientType.Count -gt 1 -and $RecipientType -contains "AllMailboxes") {
                throw "Cannot select 'AllMailboxes' with other recipient types."
            }

            # If 'AllMailboxes' is selected, adjust the recipient type list
            if ($RecipientType -eq "AllMailboxes") {
                $RecipientType = "UserMailbox", "SharedMailbox", "RoomMailbox", "EquipmentMailbox"
            }

            $mailboxes = Get-EXOMailbox -ResultSize Unlimited -RecipientTypeDetails $RecipientType -Properties DisplayName, UserPrincipalName, GUID, RetentionHoldEnabled, LitigationHoldEnabled, DelayHoldApplied, InPlaceHolds, ElcProcessingDisabled,
            ComplianceTagHoldApplied, SingleItemRecoveryEnabled, RetainDeletedItemsFor, ExchangeGuid, ExternalDirectoryObjectId, LegacyExchangeDN, DistinguishedName, ArchiveStatus, ArchiveQuota, AutoExpandingArchiveEnabled, RecoverableItemsQuota -ErrorAction SilentlyContinue
            
            $ArchiveMailbox = Get-EXOMailbox -ResultSize Unlimited -RecipientTypeDetails $RecipientType -Archive -PropertySets Quota -ErrorAction SilentlyContinue

            return $mailboxes, $ArchiveMailbox
        }
    }
    catch {
        Write-Message -Message "Failed to retrieve mailbox information: $_" -Logging
    }
}


    
# Process the mailbox identies provided by the user
function Read-MailboxIdentity {
    param (
        [string[]]$MailboxIds
    )
    
    # Valid mailboxes
    $ValidMailboxes = @()
    
    if ($MailboxIds -is [string]) {
        $fileExtension = [System.IO.Path]::GetExtension($MailboxIds)
        if ($fileExtension -in (".csv", ".txt") -and (Test-Path $MailboxIds)) {
            try {
                # Import CSV data and check for relevant columns
                $csvMailboxes = Import-Csv -Path $MailboxIds -ErrorAction Stop
                Write-Message "CSV imported successfully from $MailboxIds." -MessageAndLogging
                
                $foundColumns = $csvMailboxes[0].PSObject.Properties.Name | Where-Object { $_ -in @("EmailAddress", "Mail", "Email", "PrimarySMTPAddress", "EmailID", "Identity", "ObjectID") }
                
                # Select mailbox IDs based on found columns
                if ($foundColumns) {
                    $MailboxArray = $csvMailboxes | Select-Object -ExpandProperty ($foundColumns | Get-Random)
                    Write-Message "Selected mailbox ID(s) from column(s): $foundColumns." -Logging
                }
                else {
                    $MailboxArray = Get-Content -Path $MailboxIds
                    Write-Message "No relevant columns found. Falling back to Get-Content." -Logging
                }
            }
            catch {
                Write-Message "Error importing CSV: $_.Exception.Message" -Logging
                return
            }
        }
        else {
            # Split the string into an array
            $MailboxArray = $MailboxIds -split '[,; ]+' | Where-Object { -not ($_ -like '*\*' -or $_ -like '*/') }
        }
    }
    else {
        $MailboxArray = $MailboxIds
    }

    if ($MailboxArray.Count -eq 0) {
        Write-Message "Invalid input information or csv/txt file is empty. Please provide a string, an array, or a valid CSV file path." -TextColor Red -MessageAndLogging
        return
    }
    else {
        Write-Message -Message "Processing and retrieving valid mailbox information" -MessageAndLogging -TextColor Yellow
        $MailboxArray | ForEach-Object {
            $ValidMailboxes += Get-MailboxInfo -MailboxID $_

            Write-Message -Message $Error[0] -Logging
        }

        if ($ValidMailboxes) {
            return $ValidMailboxes
        }
        else {
            Write-Message -Message "All mailboxes are invalid and could not retrieve information." -MessageAndLogging -TextColor Red
            return
        }
    }
}






if ($PSVersionTable.PSVersion.Major -ge 7) {
    Write-Host "Running on PowerShell 7 or later, using parallel processing."
    
    # Retrieve group details based on the provided group type
    $groups = Get-GroupDetails -GroupType $GroupType
    $allGroupMembers = New-Object System.Collections.Generic.List[Object]

    # Import the function to the parallel task (Make sure Invoke-Groups is defined)
    $InvokeGroupFunction = ${Function:Invoke-Groups}.ToString()
    $InvokeGroupMembers = ${Function:Get-GroupMembers}.ToString()
    $InvokeProcessGroupMembers = ${Function:ProcessGroupMembers}.ToString()

    #External function to retrieve members of a distribution group
    $InvokeGetDistributionGroupMember = ${Function:Get-DistributionGroupMember}.ToString()
    $InvokeGetRecipient = ${Function:Get-Recipient}.ToString()

    Write-Host "Processing all groups and retrieving members for group type: $($GroupType)"
    
    # Process each group in parallel
    $groups[0..3] | ForEach-Object -Parallel {

        $group = $_
        
        write-host "Processing group: $($group.DisplayName) :  $using:GroupType"
        
        # Use the $using: to reference external variables and functions
        ${Function:Invoke-Groups} = $using:InvokeGroupFunction
        ${Function:Get-GroupMembers} = $using:InvokeGroupMembers
        ${Function:ProcessGroupMembers} = $using:InvokeProcessGroupMembers

        # External functions
        ${Function:Get-DistributionGroupMember} = $using:InvokeGetDistributionGroupMember
        ${Function:Get-Recipient} = $using:InvokeGetRecipient
        
        # Retrieve members for this group using the helper function
        $groupMembers = Invoke-Groups -Groups $group -GroupType $using:GroupType

        $groupMembers
    
        # Return the group members for this specific group
        return $groupMembers
    }  | ForEach-Object {
        # Collect the results from parallel tasks and add them to the allGroupMembers list
        $allGroupMembers.Add($_)
    }
    
    # Return the collection of all group members
    Write-Host "Total members retrieved: $($allGroupMembers.Count)"
    return $allGroupMembers
}





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
            "DistributionGroupOnly" {
                Get-DistributionGroup -RecipientTypeDetails MailUniversalDistributionGroup -ResultSize Unlimited
            }
            "AllDistributionGroup" {
                Get-DistributionGroup -ResultSize Unlimited
            }
            "MailSecurityGroupOnly" {
                Get-DistributionGroup -RecipientTypeDetails MailUniversalSecurityGroup -ResultSize Unlimited
            }
            "DynamicDistributionGroup" {
                Get-DynamicDistributionGroup -ResultSize Unlimited
            }
            "M365GroupOnly" {
                Get-MgGroup -Filter "groupTypes/any(c:c eq 'Unified')"
            }
            "AllSecurityGroup" {
                Get-MgGroup -Filter "SecurityEnabled eq true"
            }
            "NonMailSecurityGroup" {
                Get-MgGroup -Filter "SecurityEnabled eq true and MailEnabled eq false"
            }
            "SecurityGroupExcludeM365" {
                Get-MgGroup -Filter "SecurityEnabled eq true" | Where-Object { "Unified" -notin $_.GroupTypes }
            }
            "M365SecurityGroup" {
                Get-MgGroup -Filter "SecurityEnabled eq true and groupTypes/any(c:c eq 'Unified')"
            }
            "DynamicSecurityGroup" {
                Get-MgGroup -Filter "groupTypes/any(c:c eq 'DynamicMembership')"
            }
            "DynamicSecurityExcludeM365" {
                Get-MgGroup -Filter "SecurityEnabled eq true and groupTypes/any(c:c eq 'DynamicMembership')"
            }
            "AllGroups" {
                # Fetch both standard and dynamic groups in a single call and combine the results
                $allGroups = Get-MgGroup -All
                $dynamicGroups = Get-DynamicDistributionGroup -ResultSize Unlimited
                $allGroups + $dynamicGroups
            }
            default {
                throw "Unknown group type: $GroupType"
            }
        }
    }
    catch {
        Write-Host "Error occurred while fetching groups for type '$GroupType': $_"
        throw $_
    }            
}


function Get-GroupMembers {
    param (
        [string]$GroupId,
        [ValidateSet(
            "DistributionGroupOnly", "MailSecurityGroupOnly", "AllDistributionGroup", "DynamicDistributionGroup", "M365GroupOnly", "AllSecurityGroup",
            "NonMailSecurityGroup", "SecurityGroupExcludeM365", "M365SecurityGroup", "DynamicSecurityGroup", "DynamicSecurityExcludeM365", "AllGroups"
        )]
        $GroupType
    )

    # Define a lookup table for GroupType and their corresponding commands
    $groupTypeMap = @{
        "DistributionGroupOnly"       = { Get-DistributionGroupMember -Identity $GroupId -ResultSize Unlimited }
        "MailSecurityGroupOnly"       = { Get-DistributionGroupMember -Identity $GroupId -ResultSize Unlimited }
        "AllDistributionGroup"        = { Get-DistributionGroupMember -Identity $GroupId -ResultSize Unlimited }
        "DynamicDistributionGroup"    = { Get-DynamicDistributionGroupMember -Identity $GroupId -ResultSize Unlimited }
        "M365GroupOnly"               = { Get-MgGroupMember -GroupId $GroupId -All }
        "AllSecurityGroup"            = { Get-MgGroupMember -GroupId $GroupId -All }
        "NonMailSecurityGroup"        = { Get-MgGroupMember -GroupId $GroupId -All }
        "SecurityGroupExcludeM365"    = { Get-MgGroupMember -GroupId $GroupId -All }
        "M365SecurityGroup"           = { Get-MgGroupMember -GroupId $GroupId -All }
        "DynamicSecurityGroup"        = { Get-MgGroupMember -GroupId $GroupId -All }
        "DynamicSecurityExcludeM365"  = { Get-MgGroupMember -GroupId $GroupId -All }
        "AllGroups"                   = { Get-MgGroupMember -GroupId $GroupId -All }
    }

    try {
        if ($groupTypeMap.ContainsKey($GroupType)) {
            # Execute the corresponding script block from the lookup table
            return & $groupTypeMap[$GroupType]
        } else {
            throw "Unknown group type: $GroupType"
        }
    }
    catch {
        Write-Host "Error occurred while fetching members for group '$GroupId' and type '$GroupType': $_"
        throw $_
    }
}


function Get-GroupMembers {
    param (
        [string]$GroupId,
        [ValidateSet(
            "DistributionGroupOnly", "MailSecurityGroupOnly", "AllDistributionGroup", "DynamicDistributionGroup", "M365GroupOnly", "AllSecurityGroup",
            "NonMailSecurityGroup", "SecurityGroupExcludeM365", "M365SecurityGroup", "DynamicSecurityGroup", "DynamicSecurityExcludeM365", "AllGroups"
        )]
        $GroupType
    )

    # Define a lookup table for GroupType and their corresponding commands
    $groupTypeMap = @{
        # Combined entries for DistributionGroupOnly, MailSecurityGroupOnly, and AllDistributionGroup
        { $_ -in @("DistributionGroupOnly", "MailSecurityGroupOnly", "AllDistributionGroup") } = { 
            Get-DistributionGroupMember -Identity $GroupId -ResultSize Unlimited 
        }
        "DynamicDistributionGroup" = { 
            Get-DynamicDistributionGroupMember -Identity $GroupId -ResultSize Unlimited 
        }
        # Combined entries for M365GroupOnly, AllSecurityGroup, NonMailSecurityGroup, SecurityGroupExcludeM365, M365SecurityGroup, DynamicSecurityGroup, DynamicSecurityExcludeM365, AllGroups
        { $_ -in @("M365GroupOnly", "AllSecurityGroup", "NonMailSecurityGroup", "SecurityGroupExcludeM365", "M365SecurityGroup", "DynamicSecurityGroup", "DynamicSecurityExcludeM365", "AllGroups") } = { 
            Get-MgGroupMember -GroupId $GroupId -All 
        }
    }

    try {
        # Find the matching script block in the lookup table
        $scriptBlock = $groupTypeMap.Keys | Where-Object { $_ -is [ScriptBlock] -and (& $_) -or $_ -eq $GroupType }
        if ($scriptBlock) {
            # Execute the corresponding script block
            return & $groupTypeMap[$scriptBlock]
        } else {
            throw "Unknown group type: $GroupType"
        }
    }
    catch {
        Write-Host "Error occurred while fetching members for group '$GroupId' and type '$GroupType': $_"
        throw $_
    }
}


function Get-GroupMembers {
    param (
        [string]$GroupId,
        [ValidateSet(
            "DistributionGroupOnly", "MailSecurityGroupOnly", "AllDistributionGroup", "DynamicDistributionGroup", "M365GroupOnly", "AllSecurityGroup",
            "NonMailSecurityGroup", "SecurityGroupExcludeM365", "M365SecurityGroup", "DynamicSecurityGroup", "DynamicSecurityExcludeM365", "AllGroups"
        )]
        $GroupType
    )

    # Define a lookup table (hash table) for GroupType and their corresponding commands
    $groupTypeMap = @{
        @("DistributionGroupOnly", "MailSecurityGroupOnly", "AllDistributionGroup") = { Get-DistributionGroupMember -Identity $GroupId -ResultSize Unlimited }
        "DynamicDistributionGroup" = { Get-DynamicDistributionGroupMember -Identity $GroupId -ResultSize Unlimited }
        @("M365GroupOnly", "AllSecurityGroup", "NonMailSecurityGroup", "SecurityGroupExcludeM365", "M365SecurityGroup", "DynamicSecurityGroup", "DynamicSecurityExcludeM365", "AllGroups") = { Get-MgGroupMember -GroupId $GroupId -All }
    }

    try {
        # Find the group type in the map
        $matchingGroupType = $groupTypeMap.Keys | Where-Object { $_ -contains $GroupType }

        if ($matchingGroupType) {
            # Execute the corresponding script block from the lookup table
            return & $groupTypeMap[$matchingGroupType]
        } else {
            throw "Unknown group type: $GroupType"
        }
    }
    catch {
        Write-Host "Error occurred while fetching members for group type '$GroupType': $_"
        throw $_
    }
}



function Get-GroupMembers {
    param (
        [string]$GroupId,
        [ValidateSet(
            "DistributionGroupOnly", "MailSecurityGroupOnly", "AllDistributionGroup", "DynamicDistributionGroup", "M365GroupOnly", "AllSecurityGroup",
            "NonMailSecurityGroup", "SecurityGroupExcludeM365", "M365SecurityGroup", "DynamicSecurityGroup", "DynamicSecurityExcludeM365", "AllGroups"
        )]
        $GroupType
    )

    # Define a lookup table (hash table) for GroupType and their corresponding commands
    $groupTypeMap = @{
        # Use script blocks as keys to group multiple GroupType values
        { $_ -in @("DistributionGroupOnly", "MailSecurityGroupOnly", "AllDistributionGroup") } = { 
            Get-DistributionGroupMember -Identity $GroupId -ResultSize Unlimited 
        }
        { $_ -eq "DynamicDistributionGroup" } = { 
            Get-DynamicDistributionGroupMember -Identity $GroupId -ResultSize Unlimited 
        }
        { $_ -in @("M365GroupOnly", "AllSecurityGroup", "NonMailSecurityGroup", "SecurityGroupExcludeM365", "M365SecurityGroup", "DynamicSecurityGroup", "DynamicSecurityExcludeM365", "AllGroups") } = { 
            Get-MgGroupMember -GroupId $GroupId -All 
        }
    }

    try {
        # Find the matching script block in the lookup table
        $scriptBlock = $groupTypeMap.Keys | Where-Object { $_ -is [ScriptBlock] -and (& $_) }

        if ($scriptBlock) {
            # Execute the corresponding script block from the lookup table
            return & $groupTypeMap[$scriptBlock]
        } else {
            throw "Unknown group type: $GroupType"
        }
    }
    catch {
        Write-Host "Error occurred while fetching members for group type '$GroupType': $_"
        throw $_
    }
}



    # Get members of a group
    function Get-GroupMembers {
        param (
            [string]$GroupId,
            [ValidateSet(
                "DistributionGroupOnly", "MailSecurityGroupOnly", "AllDistributionGroup", "DynamicDistributionGroup", "M365GroupOnly", "AllSecurityGroup",
                "NonMailSecurityGroup", "SecurityGroupExcludeM365", "M365SecurityGroup", "DynamicSecurityGroup", "DynamicSecurityExcludeM365", "AllGroups"
            )]
            $GroupType
        )
        switch ($GroupType) {
            { $_ -in @("DistributionGroupOnly", "MailSecurityGroupOnly", "AllDistributionGroup") } {
                return Get-DistributionGroupMember -Identity $GroupId -ResultSize Unlimited # -ErrorAction SilentlyContinue
            }
            "DynamicDistributionGroup" {
                return Get-DynamicDistributionGroupMember -Identity $GroupId -ResultSize Unlimited #-ErrorAction SilentlyContinue
            }
            { $_ -in @("M365GroupOnly", "AllSecurityGroup", "NonMailSecurityGroup", "SecurityGroupExcludeM365", "M365SecurityGroup", "DynamicSecurityGroup", "DynamicSecurityExcludeM365", "AllGroups") } {
                # Handle these group types (you can adjust the logic to suit the appropriate command)
                return Get-MgGroupMember -GroupId $GroupId -All
            }
            default {
                throw "Unknown group type: $GroupType"
            } 
        }
    }
    