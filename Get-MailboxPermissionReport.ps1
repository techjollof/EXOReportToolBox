function Get-MailboxPermissionReport([Parameter(mandatory)][string]$MailboxAddress) {

    $mailbox = Get-Mailbox $MailboxAddress -ErrorAction SilentlyContinue


    $mailbox | % {
        if ( $mailbox -ne $null ) {
        $FullAccess  = Get-MailboxPermission -Identity $mailbox.Identity | Where-Object {$_.User -ne "NT AUTHORITY\SELF"}
        $SendAs  = Get-RecipientPermission -Identity $mailbox.Identity | Where-Object {$_.Trustee -ne "NT AUTHORITY\SELF"}

        $permreport = [PSCustomObject]@{
            DisplayName     =   $mailbox.DisplayName
            EmailAddress    =   $mailbox.PrimarySMTPAddress
            FullAccess      =   $FullAccess.User -join ","
            SendAs          =   $SendAs.Trustee -join ","
            SendOnBehalf    =   if($null -eq $mailbox.GrantSendOnBehalfTo){""}else{($mailbox.GrantSendOnBehalfTo | % { Get-Mailbox $_}).PrimarySMTPAddress -join ','}
        }
        return $permreport  
    }else {
        Write-Information "invalid mailbox - $($mailbox) -  provided, please and try again"
    }
    }
    
}

