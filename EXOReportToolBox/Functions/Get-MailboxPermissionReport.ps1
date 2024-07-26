#function Get-MailboxPermissionReport {
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

    $permReport =@()

    $permReport += foreach ($mbx in $MailboxAddress) {
        $mailbox  = Get-Mailbox $mbx -ErrorAction SilentlyContinue
        if ($null -ne $mailbox) {
            $fullAccess = Get-MailboxPermission -Identity $mailbox.Identity | Where-Object { $_.User -ne "NT AUTHORITY\SELF" }
            $sendAs = Get-RecipientPermission -Identity $mailbox.Identity | Where-Object { $_.Trustee -ne "NT AUTHORITY\SELF" }

            #$sendOnBehalfCheck = 
            $sendOnBehalf = if ($null -ne $mailbox.GrantSendOnBehalfTo ) { 
                $sendOnBehalfCheck | ForEach-Object { 
                    $sonbh = (Get-Recipient $_ -ErrorAction SilentlyContinue)
                    if($null -ne $sonbh){$sonbh.PrimarySMTPAddress }
                } 
            }
            [PSCustomObject]@{
                DisplayName   = $mailbox.DisplayName
                EmailAddress  = $mailbox.PrimarySMTPAddress
                ReadManage    = $fullAccess.User -join ","
                SendAs        = $sendAs.Trustee -join ","
                SendOnBehalf  = $sendOnBehalf -join ","
            }
        }

    }
    
    return $permReport
#}


$sendOnBehalf = if ($null -ne $sonbh ) { 
    $sendOnBehalfCheck | ForEach-Object { 
        $sonbh = (Get-Recipient $_ -ErrorAction SilentlyContinue)
        if($null -ne $sonbh){$sonbh.PrimarySMTPAddress -join ","}
    } 
}