function Update-MailboxFolderPermission {

        <#
    .SYNOPSIS
        Edits mailbox folder permissions by adding, updating, or removing delegate permissions.

    .DESCRIPTION
        This function allows you to manage mailbox folder permissions by adding, updating, or removing permissions for delegates. You can specify permissions for individual folders and apply settings to all subfolders if needed.

    .PARAMETER DelagatorMailbox
        The mailbox where permissions are being applied.

    .PARAMETER DelagateMailbox
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
        Edit-MailboxFolderPermission -DelagatorMailbox "user@example.com" -DelagateMailbox "delegate@example.com" -TargetFolder "Inbox" -AccessRights "Editor" -UpdatePermission
        This example updates the permission for "delegate@example.com" on the "Inbox" folder of "user@example.com" to "Editor".

    .EXAMPLE
        Edit-MailboxFolderPermission -DelagatorMailbox "user@example.com" -DelagateMailbox "delegate@example.com" -TargetFolder "Calendar" -AccessRights "ReadItems" -ManageAllSubFolders
        This example adds "ReadItems" permission to the "delegate@example.com" for the "Calendar" folder and all its subfolders of "user@example.com".

    .EXAMPLE
        Edit-MailboxFolderPermission -DelagatorMailbox "user@example.com" -DelagateMailbox "delegate@example.com" -TargetFolder "Sent Items" -RemovePermission
        This example removes all permissions from "delegate@example.com" for the "Sent Items" folder of "user@example.com".
    #>

    [CmdletBinding()]
    param (
        # Delegate mailbox to apply permissions
        [Parameter(Mandatory, ParameterSetName = "AddOrSet")]
        [Parameter(Mandatory, ParameterSetName = "Remove")]
        [string]
        $DelagatorMailbox,

        # Delegate(s) to receive permissions
        [Parameter(Mandatory, ParameterSetName = "AddOrSet")]
        [Parameter(Mandatory, ParameterSetName = "Remove")]
        [string[]]
        $DelagateMailbox,

        # Specify the folder to delegate or remove permissions
        [Parameter(Mandatory, ParameterSetName = "AddOrSet")]
        [Parameter(Mandatory, ParameterSetName = "Remove")]
        [string[]]
        $TargetFolder,

        # Folder permissions to apply
        [Parameter(Mandatory = $true, ParameterSetName = "AddOrSet")]
        [ValidateSet("None", "CreateItems", "CreateSubfolders", "DeleteAllItems", "DeleteOwnedItems",
            "EditAllItems", "EditOwnedItems", "FolderContact", "FolderOwner", "FolderVisible",
            "ReadItems", "Author", "Contributor", "Editor", "NonEditingAuthor", "Owner",
            "PublishingAuthor", "PublishingEditor", "Reviewer", IgnoreCase = $true)]
        [string[]]
        $AccessRights,

        # Assign permissions to all subfolders
        [Parameter(ParameterSetName = "AddOrSet")]
        [switch]
        $ManageAllSubFolders,

        # Specify folders to exclude from permission changes
        [Parameter(ParameterSetName = "AddOrSet")]
        [Parameter(ParameterSetName = "Remove")]
        [string[]]
        $FolderToExclude,

        # Update existing permissions
        [Parameter(ParameterSetName = "AddOrSet")]
        [switch]
        $UpdatePermission,

        # Remove existing permissions
        [Parameter(ParameterSetName = "Remove")]
        [switch]
        $RemovePermission
    )

    # Handle error messages
    trap {
        Write-Warning "Script Failed: $_"
        throw $_
    }

    function Edit-FolderPermission {
        param (
            [string]
            $FolderID           
        )

        if ($RemovePermission) {
            Remove-MailboxFolderPermission -Identity $FolderID -User $DelagateMailbox -Confirm:$false -ErrorAction SilentlyContinue
            if ($error[0].Exception.Message -like "*UserNotFoundInPermissionEntryException*") {
                Write-Output "There is no existing permission entry found for user on $FolderID"
            }
        }
        else {
            $null = Add-MailboxFolderPermission -Identity $FolderID -User $DelagateMailbox -AccessRights $AccessRights -Confirm:$false -ErrorAction SilentlyContinue

            if ($error[0].Exception.Message -like "*UserAlreadyExistsInPermissionEntryException*") {
                Write-Output "An existing permission entry was found for user on $FolderID"
                if (U$UpdatePermission) {
                    $null = Set-MailboxFolderPermission -Identity $FolderID -User $DelagateMailbox -AccessRights $AccessRights -Confirm:$false
                }
            }
        }
        
    }

    # Check the delegate and delegator's mailbox if they exist
    $DelagatorMailboxCheck = (Get-Mailbox $DelagatorMailbox -ErrorAction SilentlyContinue).PrimarySMTPAddress  
    $DelagateMailboxCheck = $DelagateMailbox | ForEach-Object { Get-Mailbox $_ -ErrorAction SilentlyContinue } 
    
    if ($null -eq $DelagatorMailboxCheck) {
        Write-Output "The delegator ($DelagatorMailbox) specified the account does not exist or check the email id"
        break;
    }
    else {
        $DelagatorMailbox = $DelagatorMailboxCheck
    }

    if ($null -eq $DelagateMailboxCheck) {
        Write-Output "The delegate ($DelagateMailbox) specified the account does not exist or check the email id"
        break;
    }
    else {
        $DelagateMailbox = $DelagateMailboxCheck.PrimarySMTPAddress
    }


    $ConvertFolderPath = @()
    $FolderTypeSelection = "User Created", "Inbox", "SentItems", "DeletedItems", "JunkEmail", "Archive", "Drafts", "Notes", "Outbox"
    $MailboxFolderDetails = Get-MailboxFolderStatistics $DelagatorMailbox
    $filteredFolder = $MailboxFolderDetails | Where-Object { $_.FolderType -in $FolderTypeSelection } | Select-Object Identity, Name, @{Name = "FolderPath" ; Expression = { $_.FolderPath -replace ("/", "\") } }
    
    $ConvertFolderPath += $TargetFolder | ForEach-Object { if (($_).StartsWith("\")) { $_ }else { "\" + $_ } }

    foreach ($folder  in $ConvertFolderPath) {
        
        if ($folder -notin $filteredFolder.FolderPath) {
            Write-Output "$folder specified does not exist on the mailox"
        }
        else {
            if ($ManageAllSubFolders) {
                Write-Output "Applyiing permission to parent folder $folder and subfolders"
                #$ParentFolder = ($DelagatorMailbox,":",$folder) -join ""
                #Edit-FolderPermission -FolderID $ParentFolder
                $Subfolders = $filteredFolder.FolderPath | Where-Object { $_ -like "$folder\*" } | ForEach-Object { ($DelagatorMailbox+":"+$_) }

                foreach ($Subfolder in $Subfolders) {
                    #$Subfolders
                    #Edit-FolderPermission -FolderID
                }
            }
            else {
                Write-Output "Only Applyiing permission to parent folder $folder"
                #Edit-FolderPermission -FolderID 
            }
        }

    }

}


# <#

# # SpcificFolder or not
# + If Get mabox folder statistis.
# + if sepcific folder
#     Recursive permission, permission for specified folder and all sub folders 
#     par: PermissionScope: AllSubFolder, OnlySpecifiedFolder
# + All folder folders

# ("None","CreateItems","CreateSubfolders","DeleteAllItems","DeleteOwnedItems","EditAllItems","EditOwnedItems","FolderContact","FolderOwner",
#                     "FolderVisible","ReadItems","Author","Contributor","Editor","NonEditingAuthor","Owner","PublishingAuthor","PublishingEditor","Reviewer")


# #>


# $mbfld = Get-MailboxFolderStatistics AddresBook@ithero.work.gd
