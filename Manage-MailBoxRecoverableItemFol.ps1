# function ManageMailBoxRecoverableItemFolder {
[CmdletBinding()]
param (
    # [Parameter(Mandatory = $true)]
    [object]$MailboxIDs,
        
    [Parameter(Mandatory = $true, HelpMessage = "This is defined as folder where you want to save all reports that will be generated")]
    [string]$ReportDirectory,
        
    [Parameter(HelpMessage = "This is to force path creation")]
    [switch]$ForceCreateDirectory
)

# Initialize a global array to hold log messages
if (-not $global:LogMessages) {
    $global:LogMessages = @()
}

# function for logging and splaying message
function Write-Message {
    param (
        [string]$Message,
        [string]$TextColor = "White",  # Default to White if no color specified
        [switch]$Logging,
        [switch]$BatchWrite
    )

    # Log the message if the logging switch is enabled
    if ($Logging) {
        $TimestampedMessage = "$(Get-Date -Format 'yyyy-MM-dd HH:mm:ss') - $Message"
        if ($BatchWrite) {
            # Store messages in a global array for batch writing
            $global:LogMessages += $TimestampedMessage
        } else {
            # Write immediately if batch writing is not enabled
            Add-Content -Path "TrainingIssues.log" -Value $TimestampedMessage
        }
    }else{
        Write-Host "`n$Message`n" -ForegroundColor $TextColor
    } 
}

function Write-Log {
    param (
        [string]$LogPath = "TrainingIssues.log"
    )

    if ($global:LogMessages.Count -gt 0) {
        # Write all batched messages to the log file at once
        $global:LogMessages | Add-Content -Path $LogPath
        # Clear the global array after writing
        $global:LogMessages.Clear()
    }
}

# Extract the directory from ReportPath
$ExtractReportDirectory = Split-Path -Path $ReportDirectory -Parent

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


#Retention Hold preocessed and corresponding user, this will holde information on list of policies that has been modified, export to csv
$InitialHoldConfig = @()
    
# Get current date and time for file naming
$CurrentDateTime = (Get-Date).ToString("yyyyMMdd_HHmm")
    
# File paths with current date and time
$ConsentFormPath = Join-FileDirectoryPath -ReportDirectory $ReportDirectory -ReportFileName "ComplianceTagHold_Removal_Consent_Form.txt"
$MailboxInitialHoldConfigPath = Join-FileDirectoryPath -ReportDirectory $ReportDirectory -ReportFileName ("Mailbox_and_Hold_Restore_Data_" + $CurrentDateTime + ".csv")
$RecoverableFolderStatsPath = Join-FileDirectoryPath -ReportDirectory $ReportDirectory -ReportFileName ("Mailbox_Recoverable_Items_Stats_Report" + $CurrentDateTime + ".csv")

    
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
    
Set-Content $ConsentFormPath -Value $ConsentForm -Force
    
    
    
# get use information
function Get-MailboxInfo ($MailboxID) {
    Get-EXOMailbox $MailboxID -Properties DisplayName, UserPrincipalName, GUID, RetentionHoldEnabled, LitigationHoldEnabled, DelayHoldApplied, InPlaceHolds, ElcProcessingDisabled,
    ComplianceTagHoldApplied, SingleItemRecoveryEnabled, RetainDeletedItemsFor, ExchangeGuid, ExternalDirectoryObjectId, LegacyExchangeDN, DistinguishedName
}

    
# Process the mailbox identies provided by the user
function Read-MailboxIdentity {
    param (
        [string]$MailboxIDs
    )
    
    if ($MailboxIDs -is [string]) {
        $fileExtension = [System.IO.Path]::GetExtension($MailboxIDs)
        if ($fileExtension -in (".csv", ".txt") -and (Test-Path $MailboxIDs)) {
            try {
                # Import CSV data and check for relevant columns
                $csvMailboxes = Import-Csv -Path $MailboxIDs -ErrorAction Stop
                Write-Message "CSV imported successfully from $MailboxIDs."
    
                $foundColumns = $csvMailboxes[0].PSObject.Properties.Name | Where-Object { $_ -in @("EmailAddress", "Mail", "Email", "PrimarySMTPAddress", "EmailID", "Identity", "ObjectID") }
    
                # Select mailbox IDs based on found columns
                if ($foundColumns) {
                    $MailboxArray = $csvMailboxes | Select-Object -ExpandProperty ($foundColumns | Get-Random)
                    Write-Message "Selected mailbox ID(s) from column(s): $foundColumns."
                }
                else {
                    $MailboxArray = Get-Content -Path $MailboxIDs
                    Write-Message "No relevant columns found. Falling back to Get-Content."
                }

            }
            catch {
                Write-Message "Error importing CSV: $_"
                return
            }
        }
        else {
            # Split the string into an array
            $MailboxIdentity = $MailboxIDs -split '[,; ]+'
            $MailboxArray = $MailboxIdentity | ForEach-Object {
                if (-not ($_ -like '*\*' -or $_ -like '*/')) {
                    $_
                }
            }
        }
    }
    else {
        $MailboxArray = $MailboxIDs
        Write-Message "Input is an array."
    }

    if ($MailboxArray.Count -eq 0) {
        Write-Message "Invalid input information or csv/txt file is empty. lease provide a string, an array, or a valid CSV file path."
        return
    }
    
    return $MailboxArray
}
    
    
# Get Current recovalable Items size
# Retrieve mailbox properties and recoverable information
function Get-MailboxRecoverableStatistics {
    param (
        [string]$MailboxID
    )
    
    # Retrieve primary mailbox properties
    $primaryMailbox = Get-EXOMailbox -Identity $MailboxID -PropertySets Minimum, Archive, Quota -ErrorAction SilentlyContinue
        
    if (-not $primaryMailbox) {
        Write-Error "Mailbox with ID '$MailboxID' not found."
        return
    }
    
    $primaryRecoverableUsed = Get-EXOMailboxFolderStatistics -Identity $primaryMailbox.UserPrincipalName -FolderScope RecoverableItems -ErrorAction SilentlyContinue | Where-Object { $_.Name -eq "Recoverable Items" }
    
    # Archive status
    $archiveStatus = $primaryMailbox.ArchiveStatus
        
    $archiveRecoverableUsed = $null
    if ($archiveStatus -eq "Active") {
        $archiveMailbox = Get-EXOMailbox -Identity $primaryMailbox.UserPrincipalName -PropertySets Quota -ErrorAction SilentlyContinue
        $archiveRecoverableUsed = Get-EXOMailboxFolderStatistics -Identity $primaryMailbox.UserPrincipalName -FolderScope RecoverableItems -Archive -ErrorAction SilentlyContinue | Where-Object { $_.Name -eq "Recoverable Items" }
    }
    
    # Create output object
    $MailboxInfo = [PSCustomObject]@{
        DisplayName             = $primaryMailbox.DisplayName
        EmailAddress            = $primaryMailbox.UserPrincipalName
        ArchiveStatus           = $primaryMailbox.ArchiveStatus
        ArchiveQuota            = $primaryMailbox.ArchiveQuota
        AutoExpandArchive       = $primaryMailbox.AutoExpandingArchiveEnabled
        PrimaryRecoverableQuota = $primaryMailbox.RecoverableItemsQuota
        PrimaryRecoverableUsed  = $primaryRecoverableUsed.FolderAndSubfolderSize
        ArchiveRecoverableQuota = if ($archiveStatus -eq "Active") { $archiveMailbox.RecoverableItemsQuota } else { $null }
        ArchiveRecoverableUsed  = if ($archiveStatus -eq "Active") { $archiveRecoverableUsed.FolderAndSubfolderSize } else { $null }
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
            Set-Mailbox $MailboxID.ExchangeGuid -RetentionHoldEnabled:$false -SingleItemRecoveryEnabled:$false -RetainDeletedItemsFor 0 -LitigationHoldEnabled:$false -ElcProcessingDisabled:$false
            Set-Mailbox $MailboxID.ExchangeGuid -RemoveDelayHoldApplied
            Set-Mailbox $MailboxID.ExchangeGuid -RemoveDelayReleaseHoldApplied
            Set-OrganizationConfig -ElcProcessingDisabled:$false
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
    
function Restore-MailboxHoldConfig {
    
    param (
        [object[]]$InitialMailboxHoldConfig
    )

    foreach ($config in $InitialMailboxHoldConfig) {
        # Restore the mailbox hold configuration
        Set-Mailbox $config.MailboxID -RetentionHoldEnabled:$config.RetentionHoldEnabled `
            -SingleItemRecoveryEnabled:$config.SingleItemRecoveryEnabled `
            -RetainDeletedItemsFor $config.RetainDeletedItemsFor `
            -LitigationHoldEnabled:$config.LitigationHoldEnabled `
            -ElcProcessingDisabled:$config.ElcProcessingDisabled
    }
}

function Start-MRMProcessing {
    param (
        [object[]]$MailboxID
    )

    foreach ($mailbox in $Mailboxes) {
        try {
            # Start the Managed Folder Assistant for the specified mailbox
            Start-ManagedFolderAssistant $MailboxID -AggMailboxCleanup -FullCrawl -HoldCleanup
            
            Write-Host "Started Managed Folder Assistant for mailbox: $($mailbox.PrimarySmtpAddress)"
        } catch {
            Write-Host "Failed to start Managed Folder Assistant for mailbox: $($mailbox.PrimarySmtpAddress). Error: $_"
        }
    }
}



# Control Menu

$UserPrompt = "What action do you want to perform? : "
$Mailboxes = Read-MailboxIdentity -MailboxIDs $MailboxIDs # Processing the identities provided and return array.
$ComplianceHolds = Get-RetentionCompliancePolicy -DistributionDetail -ErrorAction SilentlyContinue | Select-Object Name, guid, ExchangeLocation*

$actions = @(

    "###################################################################`n",
    "1. Get-MailboxRecoverableStatistics - Retrieve information about recoverable items in a mailbox.",
    "2. Remove mailbox holds - Remove holds and retention policies from a mailbox.",
    "3. View mailbox hold report - Generate a report of retention policies and holds applied to the mailbox.",
    "4. Restore-MailboxHoldConfig - Restore holds and retention policies to a mailbox.",
    "5. Start-MRMProcessing - Start Mailbox Replication and Management processing.",
    "6. Export and View Initial Hold Config - View and export initial mailbox configuration before the holds were removed",
    "7. Exit - Exit the menu.`n",
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
                $MailboxRecoverableItemsFolderStats += Get-MailboxRecoverableStatistics -MailboxID $_
            }

            if ($MailboxRecoverableItemsFolderStats) {
                Write-Verbose "Recoverable items folder statistics have been exported to $($ReportDirectory)" -Verbose
                $MailboxRecoverableItemsFolderStats | Export-Csv -Path $RecoverableFolderStatsPath -NoTypeInformation
            }
            else {
                Write-Message "There is no content due to invalid mailbox information provided; ending program and providing mailboxes."
            }
        }
        '2' { 
            Write-Message "Removing retention policies and holds applied to the mailboxes."
            $Mailboxes | ForEach-Object {
                $MailboxIdentity = Get-MailboxInfo -MailboxID $_
                $InitialHoldConfig += Remove-MailboxHoldConfig -MailboxID $MailboxIdentity -CompliancePolicy $ComplianceHolds
            }
        }
        '3' { 
            Write-Message "Generating report for retention policies and holds applied to the mailboxes."
            $ReportInitialHoldConfig = @()
            $Mailboxes | ForEach-Object {
                $MailboxIdentity = Get-MailboxInfo -MailboxID $_
                $ReportInitialHoldConfig += Remove-MailboxHoldConfig -MailboxID $MailboxIdentity -CompliancePolicy $ComplianceHolds -HoldReportOnly
            }
            $ReportInitialHoldConfig | Export-Csv (Join-FileDirectoryPath -ReportDirectory $ReportDirectory -ReportFileName "Preview_Report_Mailbox_Holds.csv") -NoTypeInformation
            $ReportInitialHoldConfig | Out-GridView -Title "Mailbox Initial Hold configuration"
        }
        '4' { 
            if ($InitialHoldConfig.Count -eq 0) {
                Write-Message "There are no default saved settings from the selected mailboxes to restore" -TextColor Yellow
            }else{
                Restore-MailboxHoldConfig -InitialMailboxHoldConfig $InitialHoldConfig
            }
        }
        '5' { 
            Start-MRMProcessing 
        }
        '6' {
            if ($InitialHoldConfig) {
                $InitialHoldConfig | Export-Csv $MailboxInitialHoldConfigPath -NoTypeInformation
                $InitialHoldConfig | Out-GridView -Title "Mailbox Initial Hold configuration"
            }
            else {
                Write-Message -Message "The mailboxes have not yet been processed; no initial configuration has been retrieved." -TextColor "Yellow"
            }
        }
        '7' {
            if ($InitialHoldConfig) {
                Write-Message -Message "Exporting initial mailbox settings and configuration" -TextColor "green"
                $InitialHoldConfig | Export-Csv $MailboxInitialHoldConfigPath -NoTypeInformation
            }
            Write-Message "Happy Using....Exiting..." -TextColor Yellow; exit
        }
        default { 
            Write-Message "Invalid choice. Please select a valid option." -TextColor "Red" 
        }
    }
} while ($choice -ne '7') 
    
    
    
# }
    