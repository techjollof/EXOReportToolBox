function Get-MailboxPermissionReport {
    [CmdletBinding()]
    param (
        [Parameter(ParameterSetName = "SpecificMailboxes")]
        [string[]]
        $MailboxAddress,

        [Parameter(ParameterSetName = "Bulk")]
        [ValidateSet("UserMailbox", "SharedMailbox", "RoomMailbox", "All")]
        $MailboxTypes = "All",

        [Parameter()]
        [switch]
        $ExpandedReport
    )

    $permReport = @()

    function ProcessReport {
        param (
            [Parameter(Mandatory = $true)]
            [object]$MailboxData,
    
            [Parameter(Mandatory = $true)]
            [object]$PermissionData
        )
    
        $userOrTrustee = $PermissionData.User
        if ($null -eq $userOrTrustee) {
            $userOrTrustee = $PermissionData.Trustee
            if ($null -eq $userOrTrustee) {
                $userOrTrustee = $MailboxData.PrimarySMTPAddress
            }
        }
    
        $permissions = $PermissionData.AccessRights
        if ($null -eq $permissions -or $permissions.Count -eq 0) {
            $permissions = "SendOnBehalf"
        }
    
        [PSCustomObject]@{
            DisplayName   = $MailboxData.DisplayName
            EmailAddress  = $MailboxData.PrimarySMTPAddress
            UserOrTrustee = $userOrTrustee
            Permissions   = $permissions
        }
    }
    

    if ($MailboxAddress) {
        # Fetch mailboxes in batch to reduce multiple Get-Mailbox calls
        $mailboxes = @()
        foreach ($user in $MailboxAddress) {
            $mailboxes += Get-Mailbox -Identity $user -ErrorAction SilentlyContinue
        }
    }
    else {
        # Fetch mailboxes based on MailboxTypes
        switch ($MailboxTypes) {
            "UserMailbox" { $mailboxes = Get-Mailbox -RecipientTypeDetails UserMailbox -ResultSize Unlimited }
            "SharedMailbox" { $mailboxes = Get-Mailbox -RecipientTypeDetails SharedMailbox -ResultSize Unlimited }
            "RoomMailbox" { $mailboxes = Get-Mailbox -RecipientTypeDetails RoomMailbox -ResultSize Unlimited }
            "All" { $mailboxes = Get-Mailbox -ResultSize Unlimited }
        }
    }

    foreach ($mailbox in $mailboxes) {
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
                    if ($null -ne $recipient) { $recipient| Select-Object PrimarySMTPAddress }
                }
            }

            if ($ExpandedReport) {
                if ($null -ne $fullAccess) {
                    $fullAccess | ForEach-Object {
                        $permReport += ProcessReport -MailboxData $mailbox -PermissionData $_
                    }
                }
                
                if ($null -ne $sendAs) {
                    $sendAs | ForEach-Object {
                        $permReport += ProcessReport -MailboxData $mailbox -PermissionData $_
                    }  
                }

                if ($null -ne $sendOnBehalfCheck) {
                    $sendOnBehalf | ForEach-Object {
                        $permReport += ProcessReport -MailboxData $mailbox -PermissionData $_
                    } 
                } 
            }
            else {
                # Build the report object
                $permReport += [PSCustomObject]@{
                    DisplayName           = $mailbox.DisplayName
                    EmailAddress          = $mailbox.PrimarySMTPAddress
                    ReadManage            = ($fullAccess | Select-Object -ExpandProperty User) -join ";"
                    ReadManagePermissions = ($fullAccess | Select-Object -ExpandProperty AccessRights) -join ";"
                    SendAs                = ($sendAs | Select-Object -ExpandProperty Trustee) -join ";"
                    SendOnBehalf          = ($sendOnBehalf.PrimarySMTPAddress) -join ";"
                }
            }
        }
    }

    $permReport #| Export-Csv "./Reports/$(Get-Date -Format 'yyyyMMdd_HH_MM_ss').csv" -NoTypeInformation
}
