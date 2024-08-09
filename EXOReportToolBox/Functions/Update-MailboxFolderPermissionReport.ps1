function Update-MailboxFolderPermissionReport {

    <#
    .SYNOPSIS
        Edits mailbox folder permissions by adding, updating, or removing delegate permissions.

    .DESCRIPTION
        This function allows you to manage mailbox folder permissions by adding, updating, or removing permissions for delegates. You can specify permissions for individual folders and apply settings to all subfolders if needed.

    .PARAMETER DelegatorMailbox
        The mailbox where permissions are being applied.

    .PARAMETER DelegateMailbox
        The mailbox or mailboxes that are being granted or removed permissions.

    .PARAMETER TargetFolder
        The folders for which permissions are being managed. This can be a single folder or multiple folders.

    .PARAMETER AccessRights
        The permissions to assign to the delegate(s). Valid values include "ReadItems", "EditAllItems", "FolderOwner", etc.

    .PARAMETER ManageAllSubFolders
        If specified, the permissions will be applied to all subfolders of the target folder.

    .PARAMETER FolderToExclude
        A list of folders to exclude from the permission changes. This parameter can be used in conjunction with the `ManageAllSubFolders` parameter.

    .PARAMETER UpdatePermission
        Use this parameter to update existing permissions. It is used in the "AddOrSet" parameter set.

    .PARAMETER RemovePermission
        Use this parameter to remove existing permissions. It is used in the "Remove" parameter set.

    .EXAMPLE
        Update-MailboxFolderPermissionReport -DelegatorMailbox "user@example.com" -DelegateMailbox "delegate@example.com" -TargetFolder "Inbox" -AccessRights "Editor" -UpdatePermission
        This example updates the permission for "delegate@example.com" on the "Inbox" folder of "user@example.com" to "Editor".

    .EXAMPLE
        Update-MailboxFolderPermissionReport -DelegatorMailbox "user@example.com" -DelegateMailbox "delegate@example.com" -TargetFolder "Calendar" -AccessRights "ReadItems" -ManageAllSubFolders
        This example adds "ReadItems" permission to the "delegate@example.com" for the "Calendar" folder and all its subfolders of "user@example.com".

    .EXAMPLE
        Update-MailboxFolderPermissionReport -DelegatorMailbox "user@example.com" -DelegateMailbox "delegate@example.com" -TargetFolder "Sent Items" -RemovePermission
        This example removes all permissions from "delegate@example.com" for the "Sent Items" folder of "user@example.com".
    #>

    [CmdletBinding(SupportsShouldProcess = $true, ConfirmImpact = 'High')]
    param (
        [Alias("Delegator")]
        [Parameter(Mandatory, ParameterSetName = "AddOrSet")]
        [Parameter(Mandatory, ParameterSetName = "Remove")]
        [string]
        $DelegatorMailbox,

        [Alias("Delegate")]
        [Parameter(Mandatory, ParameterSetName = "AddOrSet")]
        [Parameter(Mandatory, ParameterSetName = "Remove")]
        [string[]]
        $DelegateMailbox,

        [Alias("Folder")]
        [Parameter(Mandatory, ParameterSetName = "AddOrSet")]
        [Parameter(Mandatory, ParameterSetName = "Remove")]
        [string[]]
        $TargetFolder,

        [Alias("Rights")]
        [Parameter(Mandatory = $true, ParameterSetName = "AddOrSet")]
        [ValidateSet("None", "CreateItems", "CreateSubfolders", "DeleteAllItems", "DeleteOwnedItems",
            "EditAllItems", "EditOwnedItems", "FolderContact", "FolderOwner", "FolderVisible",
            "ReadItems", "Author", "Contributor", "Editor", "NonEditingAuthor", "Owner",
            "PublishingAuthor", "PublishingEditor", "Reviewer", IgnoreCase = $true)]
        [string[]]
        $AccessRights,

        [Alias("SubFolders")]
        [Parameter(ParameterSetName = "AddOrSet")]
        [switch]
        $ManageAllSubFolders,

        [Alias("ExcludeFolders")]
        [Parameter(ParameterSetName = "AddOrSet")]
        [Parameter(ParameterSetName = "Remove")]
        [string[]]
        $FolderToExclude,

        [Alias("Update")]
        [Parameter(ParameterSetName = "AddOrSet")]
        [switch]
        $UpdatePermission,

        [Alias("Remove")]
        [Parameter(ParameterSetName = "Remove")]
        [switch]
        $RemovePermission

        # # Prompt for confirmation before executing potentially destructive actions
        # [Parameter()]
        # [Switch]$Confirm
    )

    # Handle error messages
    trap {
        Write-Warning "Script Failed: $_"
        throw $_
    }

    $ConfirmPreference

    function Update-FolderPermission {
        param (
            [string] $FolderID
        )

        
        foreach ($Delegate in $DelegateMailbox) {
            Write-Verbose "Applying folder permission configuration to delegate: $Delegate"

            if ($RemovePermission) {
                Write-Verbose "Removing permissions for $Delegate on $FolderID"
                Remove-MailboxFolderPermission -Identity $FolderID -User $Delegate -Confirm:$Confirm -ErrorAction SilentlyContinue
                if ($error[0].Exception.Message -like "*UserNotFoundInPermissionEntryException*") {
                    Write-Verbose "Delegate $Delegate not found in permissions. Skipping..."
                }
            }
            else {
                Write-Verbose "Adding or setting permissions for $Delegate on $FolderID"
                $null = Add-MailboxFolderPermission -Identity $FolderID -User $Delegate -AccessRights $AccessRights -Confirm:$Confirm -ErrorAction SilentlyContinue

                if ($error[0].Exception.Message -like "*UserAlreadyExistsInPermissionEntryException*") {
                    Write-Verbose "Delegate $Delegate already exists in permissions."
                    if ($UpdatePermission) {
                        Write-Verbose "Updating permissions for $Delegate on $FolderID"
                        $null = Set-MailboxFolderPermission -Identity $FolderID -User $Delegate -AccessRights $AccessRights -Confirm:$Confirm
                    }
                }
            }
        }
        
    }

    # Check the delegate and delegator's mailbox if they exist
    $DelegatorMailboxCheck = (Get-Mailbox $DelegatorMailbox -ErrorAction SilentlyContinue).PrimarySMTPAddress  
    $DelegateMailboxCheck = $DelegateMailbox | ForEach-Object { Get-Mailbox $_ -ErrorAction SilentlyContinue } 
    
    if ($null -eq $DelegatorMailboxCheck) {
        Write-Error "The delegator ($DelegatorMailbox) specified the account does not exist or check the email id"
        break;
    }
    else {
        $DelegatorMailbox = $DelegatorMailboxCheck
    }

    if ($null -eq $DelegateMailboxCheck) {
        Write-Error "The delegate ($DelegateMailbox) specified the account does not exist or check the email id"
        break;
    }
    else {
        $DelegateMailbox = $DelegateMailboxCheck.PrimarySMTPAddress
    }


    $ConvertFolderPath = @()
    $FolderTypeSelection = "User Created", "Inbox", "SentItems", "DeletedItems", "JunkEmail", "Archive", "Drafts", "Notes", "Outbox"
    $MailboxFolderDetails = Get-MailboxFolderStatistics $DelegatorMailbox
    $filteredFolder = $MailboxFolderDetails | 
        Where-Object { $_.FolderType -in $FolderTypeSelection } | 
            Select-Object Identity, Name, @{Name = "FolderPath" ; Expression = { $_.FolderPath -replace ("/", "\") } }
    
    $ConvertFolderPath += $TargetFolder | ForEach-Object { if (($_).StartsWith("\")) { $_ }else { "\" + $_ } }

    foreach ($folder  in $ConvertFolderPath) {
        
        if ($folder -notin $filteredFolder.FolderPath) {
            Write-Verbose "$folder specified does not exist on the mailox"
        }
        else {

            $ParentFolder = ($DelegatorMailbox,":",$folder) -join ""

            if ($ManageAllSubFolders) {
                Write-Verbose "Applyiing permission to parent folder $folder and subfolders"
                Update-FolderPermission -FolderID $ParentFolder
                $Subfolders = $filteredFolder.FolderPath | 
                    Where-Object { $_ -like "$folder\*" } | 
                        ForEach-Object { ($DelegatorMailbox+":"+$_)}

                # $Subfolder
                foreach ($Subfolder in $Subfolders) {
                    $Subfolder
                    Update-FolderPermission -FolderID
                }
            }
            else {
                Write-Verbose "Only Applyiing permission to parent folder $folder"
                Update-FolderPermission -FolderID $ParentFolder
            }
        }

    }

}