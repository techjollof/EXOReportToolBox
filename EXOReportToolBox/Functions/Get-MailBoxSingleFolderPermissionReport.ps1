Function Get-Get-MailBoxFolderPermissionReport {
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
    
    .PARAMETER FolderName
        Specifies the name of the folder for which permissions are being retrieved. The default value is "Calendar".
    
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
        [Parameter(ParameterSetName="MailBoxTypes")]
        [array]
        $MailboxTypes,
    
        [Parameter(ParameterSetName="SpecificMailboxes")]
        [array]
        $SpecificMailboxes,

        [Parameter(Mandatory)]
        [string]
        $FolderName = "Calendar",

        [Parameter()]
        $ResultSize = "Unlimited"
    )
    
    process {
        # Initialize the result array
        $Result = @()
        
        # Get mailboxes based on the provided parameters
        $allMailboxes = if ($SpecificMailboxes) {
            $SpecificMailboxes | ForEach-Object { Get-Mailbox $_ }
            } elseif ($MailboxTypes) {
                Get-Mailbox -RecipientTypeDetails $MailboxTypes -ResultSize $ResultSize
            } else {
                Get-Mailbox -ResultSize $ResultSize
            }
        
        $allMailboxes = $allMailboxes | Select-Object -Property Displayname,PrimarySMTPAddress
        $totalMailboxes = $allMailboxes.Count
    
        $i = 1
        
        # Iterate over each mailbox
        $allMailboxes | ForEach-Object {
            $mailbox = $_
            Write-Progress -Activity "Processing $($_.Displayname)" -Status "$i out of $totalMailboxes completed"
            
            # Get calendar folder permissions for the mailbox
            $folderPerms = Get-MailboxFolderPermission -Identity "$($_.PrimarySMTPAddress):\$FolderName"
            
            # Iterate over each permission entry
            $folderPerms | ForEach-Object {
                # Create a custom object for each permission entry
                $Result += [PSCustomObject]@{
                    MailboxName = $mailbox.DisplayName
                    MailboxEmail = $mailbox.PrimarySMTPAddress
                    FolderName = $FolderName
                    User = $_.User
                    Permissions = $_.AccessRights -join ","
                }
            }
            $i++
        }
        $Result
    }
}
