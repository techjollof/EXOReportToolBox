function Get-MailboxPermissionReport {
    [CmdletBinding()]
    param (
        [Parameter(Mandatory = $true)]
        [string]$MailboxAddress,
        [Parameter()]
        [switch]$ExpandedReport
    )

    $mailbox = Get-Mailbox -Identity $MailboxAddress -ErrorAction SilentlyContinue
    if (-not $mailbox) {
        Write-Error "Invalid mailbox address provided: $MailboxAddress. Please try again."
        return
    }

    $fullAccess = Get-MailboxPermission -Identity $mailbox.Identity | Where-Object { $_.User -ne "NT AUTHORITY\SELF" }
    $sendAs = Get-RecipientPermission -Identity $mailbox.Identity | Where-Object { $_.Trustee -ne "NT AUTHORITY\SELF" }
    
    $sendOnBehalf = if ($null -eq $mailbox.GrantSendOnBehalfTo) { "" } else { 
        $mailbox.GrantSendOnBehalfTo | ForEach-Object { (Get-Mailbox $_).PrimarySMTPAddress } -join ","
    }

    $permReport = [PSCustomObject]@{
        DisplayName   = $mailbox.DisplayName
        EmailAddress  = $mailbox.PrimarySMTPAddress
        FullAccess    = $fullAccess.User -join ","
        SendAs        = $sendAs.Trustee -join ","
        SendOnBehalf  = $sendOnBehalf
    }

    return $permReport
}
