function Update-AllMailboxPermissions {
    <#
    .SYNOPSIS
        Manage mailbox permissions in Exchange Online.

    .DESCRIPTION
        This function allows you to remove or add mailbox permissions for users, such as SendAs, FullAccess, ReadPermission, and SendOnBehalf.
        It exports the current permissions to a CSV file before making any changes.

    .PARAMETER Delegator
        The primary mailbox or group for which permissions will be updated.

    .PARAMETER Delegate
        The user(s) to whom permissions will be granted or removed.

    .PARAMETER AccessRights
        The type of permission to assign. Acceptable values: FullAccess, ReadPermission.

    .PARAMETER Group
        Indicates if the Delegator is a group mailbox.

    .PARAMETER SentAs
        Manage "Send As" permissions.

    .PARAMETER SendOnBehalf
        Manage "Send On Behalf" permissions.

    .PARAMETER RemovePermission
        Indicates that permissions should be removed.

    .PARAMETER RemoveAllPermission
        Remove all permissions for the specified user or delegate. Acceptable values: AllUserPermissions, AllDelegatePermissions.

    .EXAMPLE
        Grant FullAccess to a delegate:
        .\Update-MailboxPermission.ps1 -Delegator "shared@example.com" -Delegate "user1@example.com" -AccessRights FullAccess

    .EXAMPLE
        Remove "Send As" permission from a delegate:
        .\Update-MailboxPermission.ps1 -Delegator "shared@example.com" -Delegate "user1@example.com" -SentAs -RemovePermission

    .EXAMPLE
        Grant "Send On Behalf" permission to a group mailbox:
        .\Update-MailboxPermission.ps1 -Delegator "group@example.com" -Delegate "user1@example.com" -SendOnBehalf -Group

    #>

    [CmdletBinding()]
    param (
        [Parameter(Mandatory=$true)]
        [string]$Delegator,

        [Parameter(Mandatory=$true)]
        [string[]]$Delegate,

        [Parameter(Mandatory=$false)]
        [ValidateSet("FullAccess", "ReadPermission")]
        [string[]]$AccessRights,

        [Parameter(Mandatory=$false)]
        [switch]$Group,

        [Parameter(Mandatory=$false)]
        [switch]$SentAs,

        [Parameter(Mandatory=$false)]
        [switch]$SendOnBehalf,

        [Parameter(Mandatory=$false)]
        [switch]$RemovePermission,

        [Parameter(Mandatory=$false)]
        [ValidateSet("AllUserPermissions", "AllDelegatePermissions")]
        [string]$RemoveAllPermission
    )

    # Validate Delegator mailbox
    $DelegatorMailbox = Get-EXORecipient -Identity $Delegator -ErrorAction Stop
    if (-not $DelegatorMailbox) {
        Write-Error "The delegator ($Delegator) does not exist. Please check the email address."
        return
    }

    # Validate Delegate mailboxes
    $ValidDelegates = @()
    $InvalidDelegates = @()
    foreach ($delegate in $Delegate) {
        $Mailbox = Get-EXORecipient -Identity $delegate -ErrorAction SilentlyContinue
        if ($Mailbox) {
            $ValidDelegates += $Mailbox.PrimarySMTPAddress
        } else {
            $InvalidDelegates += $delegate
        }
    }

    if ($InvalidDelegates.Count -gt 0) {
        Write-Warning "The following delegate mailboxes do not exist: $($InvalidDelegates -join ', ')."
    }

    if ($ValidDelegates.Count -eq 0) {
        Write-Error "No valid delegate mailboxes found. Exiting."
        return
    }

    
    Write-Output "Update mailbox permission of $($Delegator.PrimarySMTPAddress)"

    # Apply permissions using child functions
    foreach ($user in $ValidDelegates) {
        if ($RemovePermission) {
            Remove-MailboxPermissions -DelegatorAddress $DelegatorMailbox.PrimarySMTPAddress -User $user -AccessRights $AccessRights -SentAs:$SentAs -SendOnBehalf:$SendOnBehalf -Group:$Group -DelegatorRecipientType $DelegatorMailbox.RecipientTypeDetails
        } else {
            Add-MailboxPermissions -DelegatorAddress $DelegatorMailbox.PrimarySMTPAddress -User $user -AccessRights $AccessRights -SentAs:$SentAs -SendOnBehalf:$SendOnBehalf -Group:$Group -DelegatorRecipientType $DelegatorMailbox.RecipientTypeDetails
        }
    }

    Write-Output "Permission update completed on $($DelegatorMailbox.DisplayName) for $($ValidDelegates -join ', ')."
}
