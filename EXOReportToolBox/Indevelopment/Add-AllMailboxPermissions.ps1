function Add-AllMailboxPermissions {
    param (
        [string]$DelegatorAddress,
        [string]$User,
        [string[]]$AccessRights,
        [switch]$SentAs,
        [switch]$SendOnBehalf,
        [switch]$Group,
        [string]$DelegatorRecipientType
    )

    if ($AccessRights) {
        Add-MailboxPermission -Identity $DelegatorAddress -AccessRights $AccessRights -User $User -Confirm:$false
    }

    if ($SentAs) {
        Add-RecipientPermission -Identity $DelegatorAddress -AccessRights SendAs -Trustee $User -Confirm:$false
    }

    if ($SendOnBehalf) {
        if ($Group) {
            switch ($DelegatorRecipientType) {
                {"MailUniversalSecurityGroup", "MailUniversalDistributionGroup"} {
                    Set-DistributionGroup -Identity $DelegatorAddress -GrantSendOnBehalfTo @{add=$User} -Confirm:$false
                }
                "DynamicDistributionGroup" {
                    Set-DynamicDistributionGroup -Identity $DelegatorAddress -GrantSendOnBehalfTo @{add=$User} -Confirm:$false
                }
                "GroupMailbox" {
                    Set-UnifiedGroup -Identity $DelegatorAddress -GrantSendOnBehalfTo @{add=$User} -Confirm:$false
                }
                default {
                    Write-Error "The delegator address $DelegatorAddress is not a group resource. Remove the -Group switch."
                }
            }
        } else {
            Set-Mailbox -Identity $DelegatorAddress -GrantSendOnBehalfTo @{add=$User} -Confirm:$false
        }
    }
}