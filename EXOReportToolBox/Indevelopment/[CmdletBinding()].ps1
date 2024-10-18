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

    # Report path
    [Parameter()]
    [string]
    $ReportPath,

    [Parameter()]
    [string]
    $ResultSize = "Unlimited"
)

process {
    # Import export function
    . "$PSScriptRoot\Export-ReportCsv.ps1"

    # Retrieve recipients based on the provided parameters
    if ($SpecificMailboxes) {
        $allRecipients = $SpecificMailboxes | ForEach-Object { Get-EXOMailbox $_ -ErrorAction Stop }
        $allEmail = Get-EXORecipient -RecipientTypeDetails UserMailbox, SharedMailbox, MailUser
    }
    else {
        $allRecipients = Get-EXOMailbox -RecipientTypeDetails $MailboxTypes -ResultSize $ResultSize
        $allEmail = $allRecipients
    }

    if ($allRecipients.Count -eq 0) {
        Write-Output "All the specified recipients are invalid"
        return
    }

    $reportData = @()
    $totalRecipients = $allRecipients.Count
    $userEmailCache = @{} # Create a hashtable to cache UserEmail lookups

    # Prepopulate the userEmailCache for efficiency
    $allEmail | ForEach-Object {
        $userEmailCache[$_.DisplayName] = $_.PrimarySMTPAddress
    }

    $count = 0

    # Iterate over each recipient to get permissions
    foreach ($recipient in $allRecipients) {
        $folderPerms = Get-MailboxFolderPermission -Identity "$($recipient.PrimarySMTPAddress):\Calendar" -ErrorAction Stop | Where-Object { $_.User -notin "Default", "Anonymous" }

        if ($folderPerms) {
            foreach ($perm in $folderPerms) {
                # Create a custom object for each permission entry
                $reportData += [PSCustomObject]@{
                    MailboxName  = $recipient.DisplayName
                    MailboxEmail = $recipient.PrimarySMTPAddress
                    User         = $perm.User
                    UserEmail    = $userEmailCache[$perm.User]
                    Permissions  = $perm.AccessRights -join ","
                }
            }

            # Increment the count and log progress
            $count++
            if ($count % 20 -eq 0) {
                Write-Output "Processed $count out of $totalRecipients mailboxes."
            }
        }
    }
}

end {
    Write-Output "Calendar Report export has been completed."
    Export-ReportCsv -ReportData $reportData -ReportPath $ReportPath
}
