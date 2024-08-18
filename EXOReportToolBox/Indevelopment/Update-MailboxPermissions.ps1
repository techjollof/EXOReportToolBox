function Update-MailboxPermissions {

    <#
.SYNOPSIS
    managing mailbox permissions


#>

    [CmdletBinding()]
    param (
        # Parameter help description

        [Parameter(Mandatory, ParameterSetName = "User")]
        [Parameter(Mandatory, ParameterSetName = "Group")]
        [Parameter(Mandatory, ParameterSetName = "RemoveAll")]
        $Delegator,

        [Parameter(Mandatory, ParameterSetName = "User")]
        [Parameter(Mandatory, ParameterSetName = "Group")]
        [string[]]
        $Delegate,

        [Parameter(Mandatory, ParameterSetName = "User")]
        [Parameter(Mandatory, ParameterSetName = "Remove")]
        [ValidateSet("FullAccess", "ReadPermission", "ChangeOwner", "ChangePermission", "DeleteItem", "ExternalAccount")]
        [string[]]
        $AccessRights,

        [Parameter()]
        [Parameter(Mandatory, ParameterSetName = "Group")]
        [switch]
        $Group,

        [Parameter()]
        [switch]
        $SentAs,

        [Parameter()]
        [switch]
        $SendOnBehalf,

        [Parameter()]
        [Parameter(Mandatory, ParameterSetName = "Remove")]
        [switch]
        $RemovePermission,

        [Parameter(Mandatory, ParameterSetName = "Remove")]
        [Parameter(Mandatory, ParameterSetName = "RemoveAll")]
        [ValidateSet("AllUserPermissions","AllDelegatePermissions")]
        $RemoveAllPermission

    
    )

    # Check if the delegator and delegate mailboxes exist and select Primary SMTP address
    # Handle invalid delegate mailboxes and Extract the primary SMTP addresses of valid delegates is down if the Delegate list is less/equal to 10
    $DelegatorMailbox = Get-EXORecipient -Identity $Delegator -ErrorAction SilentlyContinue
    if (-not $DelegatorMailbox) {
        Write-Error "The delegator ($Delegator) does not exist. Please check the email address."
        return
    }
    $Delegator = $DelegatorMailbox
    
    if ($Delegate.Count -le 10) {
        $InvalidDelegates = @()
        $DelegateMailboxes = $Delegate | ForEach-Object {
            $Mailbox = Get-EXORecipient -Identity $_ -ErrorAction SilentlyContinue
            if (-not $Mailbox) {
                $InvalidDelegates += $_
            }
            $Mailbox
        }
        if ($InvalidDelegates.Count -gt 0 -and $InvalidDelegates.Count -ne $Delegate.Count) {
            Write-Error "The following ($($InvalidDelegates.Count)) delegate mailboxes do not exist: $($InvalidDelegates -join ', '). Please check the email addresses."
            $Delegate = $DelegateMailboxes.PrimarySMTPAddress
        }
        else {
            Write-Error "All delegate mailboxes do not exist. Please check the email addresses."
            return            
        }
    }

    # Apply permission bease on recipient type of the delegator object
    $DelegatorRecipientType = $Delegator.RecipientTypeDetails
    $DelegatorAddress = $Delegator.PrimarySMTPAddress

    
    Write-Output "`nProcessing permission update on  $($Delegator.DisplayName + " : " + $DelegatorAddress)" -ForegroundColor Yellow
    foreach ($user in $Delegate) {
        #updating and managing mailbox permission
        
        if(!$Group){
            if ($RemovePermission) {
                Remove-MailboxPermission -Identity $DelegatorAddress -AccessRights $AccessRights -User $user -Confirm:$false
            }
            else {
                Add-MailboxPermission -Identity $DelegatorAddress -AccessRights $AccessRights -User $user -Confirm:$false
            }
        }
        
        if ($SentAs) {
            if ($RemovePermission) {
                Remove-RecipientPermission -Identity $DelegatorAddress -AccessRights SendAS -Trustee $user  -Confirm:$false 
            }
            else {
                Add-RecipientPermission -Identity $DelegatorAddress -AccessRights SendAS -Trustee $user  -Confirm:$false 
            }
        }

        if ($SendOnBehalf) {
            if ($Group) {
                switch ($DelegatorRecipientType) {
                    {"MailUniversalSecurityGroup", "MailUniversalDistributionGroup"} {
                        Set-DistributionGroup -Identity $DelegatorAddress -GrantSendOnBehalfTo @{ add = $user } -Confirm:$false
                    }
                    "DynamicDistributionGroup" {
                        Set-DynamicDistributionGroup $DelegatorAddress -GrantSendOnBehalfTo @{ add = $user } -Confirm:$false
                    }
                    "GroupMailbox" {
                        Set-UnifiedGroup $DelegatorAddress -GrantSendOnBehalfTo @{ add = $user } -Confirm:$false
                    }
                    default {
                        Write-Error "The delegator address $($DelegatorAddress) is not a group resource. Remove the -Group switch, it's a ($DelegatorRecipientType)"
                        return
                    }
                }
            }
            else {
                Set-Mailbox -Identity $DelegatorAddress -GrantSendOnBehalfTo @{ add = $user } -Confirm:$false
            }
        }
        

            #Removing send as permission
            if ($RemovePermission) {
                # Loop through each permission
                Write-Output "`tRemoving SendAs from $($DelegatorAddress)" -ForegroundColor Yellow
                foreach ($user in $SAPermissions) {
                    # Remove the permission
                    Write-Host "`t`nRemoving :  $($user.Trustee)"
                    Remove-RecipientPermission  -Identity $mailbox.Identity -Trustee $user -AccessRights SendAs  -Confirm:$false -WarningAction SilentlyContinue | Out-Null #-WhatIf
                }
                Write-Host "`n"
            }

            #removing Full access permssion
            if ($AccessRights) {
                # Loop through each permission
                Write-Host "`n`tAdding $($AccessRights) on $($mailbox.DisplayName)" -ForegroundColor Yellow
                foreach ($user in $FAPermissions) {
                    # Remove the permission
                    if (($AccessRights -eq "ReadPermission")) {
                        if (($User.AccessRights).Trim().contains("FullAccess")) {
                            Remove-MailboxPermission -Identity $mailbox.Identity -User $user.User -AccessRights "FullAccess"  -BypassMasterAccountSid -Confirm:$false  | Out-Null #-WhatIf
                        }
                        if (($User.AccessRights).Trim().contains("ReadPermission")) {
                            Write-Host "`t`tUser $($user.user) already have permission" -ForegroundColor Magenta
                        }
                        else {
                            Write-Host "`t`tAdding :  $($user.User)"
                            Add-MailboxPermission  -Identity $mailbox.Identity -User $user.User -AccessRights $AccessRights -Confirm:$false -WarningAction SilentlyContinue | Out-Null #-WhatIf
                        }
                
                    }
                    else {
                        if (($User.AccessRights).Trim().contains("ReadPermission")) {
                            Remove-MailboxPermission -Identity $mailbox.Identity -User $user.User -AccessRights "ReadPermission"  -BypassMasterAccountSid -Confirm:$false  | Out-Null #-WhatIf
                        }

                        if (($User.AccessRights).Trim().contains("FullAccess")) {
                            Write-Host "`t`tUser $($user.user) already have permission $($AccessRights)" -ForegroundColor Magenta
                        }
                        else {
                            Write-Host "`t`tAdding :  $($user.User)"
                            Add-MailboxPermission  -Identity $mailbox.Identity -User $user.User -AccessRights $AccessRights -Confirm:$false -WarningAction SilentlyContinue | Out-Null #-WhatIf
                        }   
                    }
                }
                Write-Host "`n"
            }

            #removing Full access permssion
            if ($RemoveSendOnBehalfPermission) {
                Write-Host "Removing SendOnBehalf permission on $($mailbox.DisplayName)" -ForegroundColor Yellow
                Set-Mailbox -Identity $mailbox.Identity -GrantSendOnBehalfTo @{}
                Write-Host "`n"
            }

        }

        #Export the permisison list to csv
        $permissionsList | Export-Csv $HOME\Downloads\$($fileName) -NoTypeInformation

        Write-Host "`t############### Happy Shelling #######################"

    }