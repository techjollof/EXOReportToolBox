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
