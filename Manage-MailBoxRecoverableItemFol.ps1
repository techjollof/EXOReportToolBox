
[CmdletBinding()]
param (
    [Parameter(ParameterSetName = "MailBoxID", Mandatory = $true)]
    [object]$MailboxIDs,

    [Parameter(ParameterSetName = "MailboxType")]
    [ValidateSet("UserMailbox", "SharedMailbox", "RoomMailbox", "EquipmentMailbox", "AllMailboxes")]
    [string]$MailboxRecipientTypes,

    [Parameter(ParameterSetName = "MailBoxID")]
    [Parameter(ParameterSetName = "MailboxType")]
    [Parameter(ParameterSetName = "Directory", HelpMessage = "This is defined as the folder where you want to save all reports that will be generated")]
    [string]$ReportDirectory,

    [Parameter(ParameterSetName = "MailBoxID")]
    [Parameter(ParameterSetName = "MailboxType")]
    [Parameter(ParameterSetName = "Directory", HelpMessage = "This is to force path creation")]
    [switch]$ForceCreateDirectory
)

# Validate that ForceCreateDirectory is only set if ReportDirectory is specified
if ($ForceCreateDirectory -and -not $ReportDirectory) {
    throw "The -ForceCreateDirectory switch cannot be specified without a valid -ReportDirectory."
}

# Initialize a global array to hold log messages
if (-not $global:LogMessages) {
    $global:LogMessages = @()
}


#Retention Hold preocessed and corresponding user, this will holde information on list of policies that has been modified, export to csv
$InitialHoldConfig = @()
    
# Get current date and time for file naming
$CurrentDateTime = (Get-Date).ToString("yyyyMMdd_HHmm")
$LoggingCurrentDateTime = (Get-Date).ToString("yyyy_MM_dd")

# Extract the directory from ReportPath
$ExtractReportDirectory = Split-Path -Path $ReportDirectory -Parent

# function for logging and splaying message


# Check if the directory exists
if (-not (Test-Path -Path $ReportDirectory)) {
    if ($ForceCreateDirectory) {
        # Force create the directory
        $ReportDirectory = (New-Item -Path $ExtractReportDirectory -ItemType Directory -Force).FullName
    }
    else {
        throw "The specified ReportPath does not exist: $ReportDirectory"
    }
}

function Join-FileDirectoryPath {
    param (
        [string]$ReportDirectory,
        [string]$ReportFileName
    )
    # Create the consent form path
    return Join-Path -Path $ReportDirectory -ChildPath $ReportFileName
}

# File paths with current date and time
$ConsentFormPath = Join-FileDirectoryPath -ReportDirectory $ReportDirectory -ReportFileName "ComplianceTagHold_Removal_Consent_Form.txt"
$MailboxInitialHoldConfigPath = Join-FileDirectoryPath -ReportDirectory $ReportDirectory -ReportFileName ("Mailbox_and_Hold_Restore_Data_" + $CurrentDateTime + ".csv")
$RecoverableFolderStatsPath = Join-FileDirectoryPath -ReportDirectory $ReportDirectory -ReportFileName ("Mailbox_Recoverable_Items_Stats_Report" + $CurrentDateTime + ".csv")
$LoggingPath = Join-FileDirectoryPath -ReportDirectory $ReportDirectory -ReportFileName ("Mailbox_Activity_Logging_" + $LoggingCurrentDateTime + ".log")


function Write-Message {
    param (
        [string]$Message,
        [ValidateSet("Black", "DarkBlue", "DarkGreen", "DarkCyan", "DarkRed", "DarkMagenta", "DarkYellow", "Gray", "DarkGray", "Blue", "Green", "Cyan", "Red", "Magenta", "Yellow", "White")]
        [string]$TextColor = "White", # Default to White if no color specified
        [switch]$Logging,
        [switch]$MessageAndLogging
    )

    # Prepare the timestamped message
    $TimestampedMessage = "$(Get-Date -Format 'yyyy-MM-dd HH:mm:ss') - $Message"

    # Log the message if the logging switch is enabled
    if ($Logging -or $MessageAndLogging) {
        # Store messages in a global array for batch writing
        $global:LogMessages += $TimestampedMessage

        # Write message to host if MessageAndLogging is used
        if ($MessageAndLogging) {
            Write-Host "`n$Message`n" -ForegroundColor $TextColor
        }
    }
    else {
        Write-Host "`n$Message`n" -ForegroundColor $TextColor
    }
}


function Write-Log {
    if ($global:LogMessages.Count -gt 0) {
        # Write all batched messages to the log file at once
        $global:LogMessages | Add-Content -Path $LoggingPath
        # Clear the global array after writing
        $global:LogMessages.Clear()
    }
}

$ConsentForm = "
    Hello <Support Engineer Name if you know>,
    
    Hope you are doing well.
    
    Issue: Need to set ComplianceTagHoldApplied to false to clear up RecoverableItems.
    
    Consent Form
    =================
    I, <FULL NAME>, with global admin account <GA EMAIL ADDRESS>, hereby authorize the Microsoft 365 team to remove the ComplianceTagHoldApplied from the mailboxes to enable clearing
    up the content from the Recoverable Items folder. I fully understand the complete impact of removing the ComplianceTagHoldApplied from the mailbox. Any content or information
    kept under this policy will be completely deleted and irreversible, and Microsoft Corporation will not be held accountable or responsible for any data loss.
    
    Mailbox Information
    =======================
    ".split("`r") | ForEach-Object { $_.TrimStart() }

# get use information

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
            RetainDeletedItemsFor, ExchangeGuid, ExternalDirectoryObjectId, LegacyExchangeDN, DistinguishedName, ArchiveStatus, ArchiveQuota, AutoExpandingArchiveEnabled,RecoverableItemsQuota -ErrorAction SilentlyContinue
            
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
            ComplianceTagHoldApplied, SingleItemRecoveryEnabled, RetainDeletedItemsFor, ExchangeGuid, ExternalDirectoryObjectId, LegacyExchangeDN, DistinguishedName, ArchiveStatus, ArchiveQuota, AutoExpandingArchiveEnabled,RecoverableItemsQuota -ErrorAction SilentlyContinue
            
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


    
# Get Current recovalable Items size
# Retrieve mailbox properties and recoverable information
function Get-MailboxRecoverableStatistics {
    param (
        [Object]$MailboxId,
        [Object]$ArchiveMailboxId
    )
    
    # Retrieve primary mailbox properties
    $primaryRecoverableUsed = Get-EXOMailboxFolderStatistics -Identity $MailboxId.UserPrincipalName -FolderScope RecoverableItems -ErrorAction SilentlyContinue | Where-Object { $_.Name -eq "Recoverable Items" }
    
    # Archive status
    $archiveStatus = $MailboxId.ArchiveStatus        
    $archiveRecoverableUsed = $null
    if ($archiveStatus -eq "Active") {
        $archiveMailbox = Get-EXOMailbox -Identity $MailboxId.UserPrincipalName -Archive -PropertySets Quota -ErrorAction SilentlyContinue
        $archiveRecoverableUsed = Get-EXOMailboxFolderStatistics -Identity $MailboxId.UserPrincipalName -FolderScope RecoverableItems -Archive -ErrorAction SilentlyContinue | Where-Object { $_.Name -eq "Recoverable Items" }
    }
    
    # Create output object
    $MailboxInfo = [PSCustomObject]@{
        DisplayName             = $MailboxId.DisplayName
        EmailAddress            = $MailboxId.UserPrincipalName
        ArchiveStatus           = $MailboxId.ArchiveStatus
        ArchiveQuota            = $MailboxId.ArchiveQuota
        AutoExpandArchive       = $MailboxId.AutoExpandingArchiveEnabled
        PrimaryRecoverableQuota = $MailboxId.RecoverableItemsQuota
        PrimaryRecoverableUsed  = $primaryRecoverableUsed.FolderAndSubfolderSize
        ArchiveRecoverableQuota = if ($archiveStatus) { $archiveMailbox.RecoverableItemsQuota } else { $null }
        ArchiveRecoverableUsed  = if ($archiveStatus) { $archiveRecoverableUsed.FolderAndSubfolderSize } else { $null }
    }
    
    return $MailboxInfo
}    
    
# Check if there are nay holded on mailbox and perform clean up
    
# for managing holds on the mailbox and other information that prevent deletion fo recoverable items folder content
function Remove-MailboxHoldConfig {
    param (
        [Parameter(Mandatory = $true)]
        [Object]$MailboxID,
    
        [Parameter(Mandatory = $true)]
        [Object[]]$CompliancePolicy,
    
        [switch]$HoldReportOnly
    )
    
    $changedHolds = @() # Monitor hold changes
    
    if ($CompliancePolicy.Count -ne 0) {
        foreach ($hold in $CompliancePolicy) {
            # Write-Verbose "Processing $($hold.Name)"
    
            try {
                if ($hold.ExchangeLocation.ImmutableIdentity -eq "All" -and $MailboxID.ExternalDirectoryObjectId -notin $hold.ExchangeLocationException.ImmutableIdentity) {
                    if (-not $HoldReportOnly) {
                        # Uncomment to execute the command
                        Set-RetentionCompliancePolicy -Identity $hold.guid -AddExchangeLocationException $MailboxID.ExternalDirectoryObjectId -Force
                    }
                    $changedHolds += [PSCustomObject]@{
                        Guid       = $hold.Guid
                        PolicyType = "All"
                    }
                    # Write-Verbose 'All policy, account excluded'
                }
                elseif ($MailboxID.Identity -in $hold.ExchangeLocation.ImmutableIdentity) {
                    if (-not $HoldReportOnly) {
                        # Uncomment to execute the command
                        Set-RetentionCompliancePolicy -Identity $hold.guid -RemoveExchangeLocation $MailboxID.ExternalDirectoryObjectId -Force
                    }
                    $changedHolds += [PSCustomObject]@{
                        Guid       = $hold.Guid
                        PolicyType = "Segment"
                    }
                    # Write-Verbose 'Removing user from segment'
                }
            }
            catch {
                Write-Error "Error processing hold: $_"
            }
        }
    }
    
    if (-not($HoldReportOnly)) {
        try {
            Set-Mailbox $MailboxID.ExchangeGuid -RetentionHoldEnabled:$false -SingleItemRecoveryEnabled:$false -RetainDeletedItemsFor 0 -LitigationHoldEnabled:$false -ElcProcessingDisabled:$false -Verbose:$false -WarningAction SilentlyContinue
            Set-OrganizationConfig -ElcProcessingDisabled:$false -Verbose:$false -WarningAction SilentlyContinue
        }
        catch {
            Write-Error "Failed to modify mailbox properties: $_"
        }
    }

    $UserInitialHoldConfig = [PSCustomObject]@{
        EmailAddress              = $MailboxID.UserPrincipalName
        MailboxGUID               = $MailboxID.ExternalDirectoryObjectId
        LitigationHoldEnabled     = [bool]$MailboxID.LitigationHoldEnabled
        SingleItemRecoveryEnabled = [bool]$MailboxID.SingleItemRecoveryEnabled
        RetentionHoldEnabled      = [bool]$MailboxID.RetentionHoldEnabled
        RetainDeletedItemsFor     = $MailboxID.RetainDeletedItemsFor
        ComplianceTagHoldApplied  = [bool]$MailboxID.ComplianceTagHoldApplied
        ElcProcessingDisabled     = [bool]$MailboxID.ElcProcessingDisabled
        ComplianecHoldInfo        = if ($changedHolds) { $changedHolds }else { $null }
    }
    
    if ($MailboxID.ComplianceTagHoldApplied -eq $true) {
        Write-Output "`nThe mailbox $($MailboxID.UserPrincipalName) has ComplianceTagHoldApplied set to True. All other properties have been changed.`n
            Please proceed to raise a support request from the Microsoft 365 Admin Center for the product team to remove the tag for you.`n
            Copy the information below and add it to your case. Check your current path to locate the file ComplianceTagHold_Removal_Consent_Form.txt"
    
        $RemoveCTMbx = "
                PrimarySmtpAddress: $($MailboxID.PrimarySmtpAddress)
                ExchangeGuid: $($MailboxID.ExchangeGuid)
                ExternalDirectoryObjectId: $($MailboxID.ExternalDirectoryObjectId)
                LegacyExchangeDN: $($MailboxID.LegacyExchangeDN)
                DistinguishedName: $($MailboxID.DistinguishedName)
                ".split("`r") | ForEach-Object { $_.TrimStart() }
    
        #update form
        Add-Content $ConsentFormPath -Value $RemoveCTMbx
    }

    return $UserInitialHoldConfig 

}

# Restore the Restoore the mailbox hold configuration to what it was before the hold was applied
function Restore-MailboxHoldConfig {
    
    param (
        [Parameter(Mandatory = $true)]
        [object[]]$InitialMailboxHoldConfig
    )

    foreach ($config in $InitialMailboxHoldConfig) {
        try {
            # Restore the mailbox hold configuration
            Set-Mailbox $config.EmailAddress `
                -RetentionHoldEnabled:$config.RetentionHoldEnabled `
                -SingleItemRecoveryEnabled:$config.SingleItemRecoveryEnabled `
                -RetainDeletedItemsFor $config.RetainDeletedItemsFor `
                -LitigationHoldEnabled:$config.LitigationHoldEnabled `
                -ElcProcessingDisabled:$config.ElcProcessingDisabled `
                -Verbose:$false `
                -WarningAction SilentlyContinue
        }
        catch {
            Write-Message "Failed to restore hold configuration for $($config.EmailAddress): $_" -Logging
        }
    }
}


# Delay holds on mailbox only happens when the mailbox has been removed from compliance hold
# This function removes the delay hold on the mailbox
function Remove-ComplianceDelayHold {
    param (
        # Mailbox
        [Parameter(Mandatory = $true)]
        [object[]]$MailboxIds
    )
    
    foreach ($MailboxID in $MailboxIds) {
        try {
            # Remove delay holds
            Set-Mailbox $MailboxID.ExchangeGuid -RemoveDelayHoldApplied -Verbose:$false -WarningAction SilentlyContinue
            Set-Mailbox $MailboxID.ExchangeGuid -RemoveDelayReleaseHoldApplied -Verbose:$false -WarningAction SilentlyContinue
        }
        catch {
            Write-Message -Message "Failed to remove compliance delay holds for mailbox $($MailboxID.UserPrincipalName): $_" -Logging
        }
    }
}


function Start-MRMProcessing {
    param (
        [object[]]$MailboxIds
    )

    foreach ($mailbox in $MailboxIds) {
        try {
            # Start the Managed Folder Assistant for the specified mailbox
            Start-ManagedFolderAssistant -Identity $mailbox
            Start-ManagedFolderAssistant -Identity $mailbox -AggMailboxCleanup -FullCrawl -HoldCleanup
        }
        catch {
            Write-Message -Message $_ -Logging
        }
    }
}


#Create log file
# Create the log header
$logHeader = ('#' * 20) + "`t" + (Get-Date -Format 'yyyy-MM-dd HH:mm:ss') + "`tProgram activity logs Starts`t" + ('#' * 20) + "`n"
$logFooter = ('#' * 20) + "`t" + (Get-Date -Format 'yyyy-MM-dd HH:mm:ss') + "`tProgram activity logs Ends`t" + ('#' * 20) + "`n"

Write-Message -Message $logHeader -Logging

# Control Menu
$UserPrompt = "What action do you want to perform? : "

# Processing the identities provided and return array.
$PrimaryAndArchiveMailboxes = if ($MailboxRecipientTypes) {
    Get-MailboxInfo -RecipientType $MailboxRecipientTypes
}
else {
    Read-MailboxIdentity -MailboxIDs $MailboxIDs
} 

if ($PrimaryAndArchiveMailboxes) {
    $Mailboxes = $PrimaryAndArchiveMailboxes[0]
    $ArchiveMailboxes = $PrimaryAndArchiveMailboxes[1]
}else{
    Write-Message -Message "There are no valid mailboxes found in the provided information, ending the program" -TextColor Red -MessageAndLogging
    Write-Log
    Return
}


Write-Log
$ComplianceHolds = Get-RetentionCompliancePolicy -DistributionDetail -ErrorAction SilentlyContinue | Select-Object Name, guid, ExchangeLocation*

$actions = @(

    "###################################################################`n",
    "1. Get recoverable items statistics - Retrieve information about recoverable items in a mailbox.",
    "2. Remove mailbox holds - Remove holds and retention policies from a mailbox.",
    "3. View mailbox hold report - Generate a report of retention policies and holds applied to the mailbox.",
    "4. Restore mailbox hold configuration - Restore holds and retention policies to a mailbox.",
    "5. Remove delay hold - Remove all delay holds to all MRM purge all expired items",
    "6. Start MRM Processing - Start Mailbox Replication and Management processing.",
    "7. Export and View Initial Hold Config - View and export initial mailbox configuration before the holds were removed",
    "q. Exit - Exit the menu.`n",
    "###################################################################`n"
)

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

# }
    