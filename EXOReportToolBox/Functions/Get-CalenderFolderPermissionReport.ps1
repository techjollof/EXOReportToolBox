Function Get-CalendarFolderPermissionReport {
    <#
    .SYNOPSIS
    Retrieves and processes mailbox information based on specified types or individual mailboxes.

    .DESCRIPTION
    The Get-CalendarFolderPermissionReport function allows you to retrieve mailbox data based on the type of mailbox (e.g., UserMailbox, SharedBox, RoomMailbox) or specific mailboxes. It supports generating a report of the mailbox data and handles an "All" option which selects all mailbox types if no specific type is given.

    .PARAMETER MailboxTypes
    Specifies the type(s) of mailboxes to retrieve. Valid values are "UserMailbox", "SharedBox", "RoomMailbox", and "All". Note that "All" cannot be combined with other types.

    .PARAMETER SpecificMailboxes
    Specifies a list of individual mailboxes to retrieve data for. This parameter is used when you want to query specific mailboxes instead of by type.

    .PARAMETER ReportPath
    Specifies the path where the report should be saved. If not specified, the report will not be saved.

    .PARAMETER ResultSize
    Specifies the number of results to return. Default is "Unlimited". 

    .EXAMPLE
    Get-CalendarFolderPermissionReport -MailboxTypes UserMailbox -ReportPath "C:\Reports\UserMailboxes.csv"
    Retrieves user mailboxes and saves the report to "C:\Reports\UserMailboxes.csv".

    .EXAMPLE
    Get-CalendarFolderPermissionReport -SpecificMailboxes "mailbox1@example.com", "mailbox2@example.com"
    Retrieves data for the specified mailboxes.

    .NOTES
    File path for report generation must be valid, and the script must have the necessary permissions to write to the specified location.
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

        $reportData = @()
        $totalRecipients = $allRecipients.Count

        $count = 0
        # Iterate over each recipient
        $allRecipients | ForEach-Object {

            $recipient = $_

            # Get calendar folder permissions for the recipient and Iterate over each permission entry
            $folderPerms = Get-EXOMailboxFolderPermission -Identity "$($recipient.PrimarySMTPAddress):\Calendar" -ErrorAction SilentlyContinue | Where-Object { $_.User -notin "Default", "Anonymous" }
            if ($folderPerms) {
                $folderPerms | ForEach-Object {
                    $reportData += [PSCustomObject]@{
                        MailboxName  = $recipient.DisplayName
                        MailboxEmail = $recipient.PrimarySMTPAddress
                        User         = $_.User
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
