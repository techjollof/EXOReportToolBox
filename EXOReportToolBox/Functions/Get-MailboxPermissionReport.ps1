function Get-MailboxPermissionReport {
    <#
    .SYNOPSIS
        Generates a report of mailbox permissions.

    .DESCRIPTION
        The Get-MailboxPermissionReport function retrieves and displays permissions for specified mailboxes or types of mailboxes. It can generate detailed reports including user or trustee information and access rights. 
        This function is especially useful for administrators who need to audit or review access permissions within an Exchange Online environment.

    .NOTES
        This function is designed for use in environments with Exchange Online.
        Use the -MailboxAddress parameter to specify individual mailboxes or -MailboxTypes to specify categories of mailboxes like User, Shared, or Room mailboxes.
        The report can be exported to a specified path using the -ReportPath parameter.

    .PARAMETER MailboxAddress
        Specify one or more mailbox addresses for which to retrieve permission details. This is useful for checking permissions on specific mailboxes.

    .PARAMETER MailboxTypes
        Specify the type of mailboxes to include in the report. Options include "UserMailbox", "SharedMailbox", "RoomMailbox", and "All". The default value is "All".

    .PARAMETER ReportPath
        Specify the file path where the report will be saved. If not provided, the report will only be displayed on the console.

    .PARAMETER ExpandedReport
        Include detailed permission information in the report. This includes specifics about the types of access granted to users or trustees.
    .EXAMPLE
        Get-MailboxPermissionReport -MailboxAddress "user1@example.com", "user2@example.com"
        Retrieves and displays permissions for the specified mailboxes.

    .EXAMPLE
        Get-MailboxPermissionReport -MailboxTypes "UserMailbox"
        Retrieves and displays permissions for all user mailboxes.

    #>

    [CmdletBinding()]
    param (
        [Parameter(ParameterSetName = "SpecificMailboxes", HelpMessage = "Specify one or more mailbox addresses.")]
        [string[]]
        $MailboxAddress,

        [Parameter(ParameterSetName = "Bulk", HelpMessage = "Specify the type of mailboxes to include in the report.")]
        [ValidateSet("UserMailbox", "SharedMailbox", "RoomMailbox", "All")]
        $MailboxTypes = "All",

        [Parameter(Mandatory = $true, HelpMessage = "Specify the file path to save the report.")]
        [string]
        $ReportPath,

        [Parameter(HelpMessage = "Include detailed permission information in the report.")]
        [switch]
        $ExpandedReport
    )

    process {
        
        $permReport = @()
        . "$PSScriptRoot\Export-ReportCsv.ps1" 

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
            # Fetch mailboxes in batch to reduce multiple Get-ExoMailbox calls
            $mailboxes = @()
            foreach ($user in $MailboxAddress) {
                $mailboxes += Get-ExoMailbox -Identity $user -ErrorAction SilentlyContinue
            }
        }
        else {
            # Fetch mailboxes based on MailboxTypes
            switch ($MailboxTypes) {
                "UserMailbox" { $mailboxes = Get-ExoMailbox -RecipientTypeDetails UserMailbox -ResultSize Unlimited }
                "SharedMailbox" { $mailboxes = Get-ExoMailbox -RecipientTypeDetails SharedMailbox -ResultSize Unlimited }
                "RoomMailbox" { $mailboxes = Get-ExoMailbox -RecipientTypeDetails RoomMailbox -ResultSize Unlimited }
                "All" { $mailboxes = Get-ExoMailbox -ResultSize Unlimited }
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
                        if ($null -ne $recipient) { $recipient | Select-Object PrimarySMTPAddress }
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


    }
    end {
        Export-ReportCsv -ReportPath $ReportPath -ReportData $permReport
    }
}
