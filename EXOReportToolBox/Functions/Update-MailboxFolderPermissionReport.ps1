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

    .PARAMETER ExcludeFolders
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
        [Parameter(ParameterSetName = "Remove")]
        [switch]
        $ManageAllSubFolders,

        [Alias("Exclude")]
        [Parameter(ParameterSetName = "AddOrSet")]
        [Parameter(ParameterSetName = "Remove")]
        [string[]]
        $ExcludeFolders,

        [Alias("Update")]
        [Parameter(ParameterSetName = "AddOrSet")]
        [switch]
        $UpdatePermission,

        [Alias("Remove")]
        [Parameter(ParameterSetName = "Remove")]
        [switch]
        $RemovePermission
    )

    process {
        # Handle error messages
        trap {
            Write-Warning "Script Failed: $_"
            throw $_
        }

        function Update-FolderPermission {
            param (
                [string] $FolderID
            )

            foreach ($Delegate in $DelegateMailbox) {
                if ($RemovePermission) {
                    if ($PSCmdlet.ShouldProcess("$FolderID", "Removing permissions for delegate $Delegate")) {
                        Write-Verbose "Removing permissions for $Delegate on $FolderID"
                        Remove-MailboxFolderPermission -Identity $FolderID -User $Delegate -Confirm:$false -ErrorAction SilentlyContinue
                        if ($error[0].Exception.Message -like "*UserNotFoundInPermissionEntryException*") {
                            Write-Verbose "Delegate $Delegate not found in permissions. Skipping..."
                        }
                    }
                }
                else {
                    if ($PSCmdlet.ShouldProcess("$FolderID", "Adding or setting permissions for delegate $Delegate")) {
                        Write-Verbose "Adding or setting permissions for $Delegate on $FolderID"
                        $null = Add-MailboxFolderPermission -Identity $FolderID -User $Delegate -AccessRights $AccessRights  -ErrorAction SilentlyContinue

                        if ($error[0].Exception.Message -like "*UserAlreadyExistsInPermissionEntryException*") {
                            Write-Verbose "Delegate $Delegate already exists in permissions."
                            if ($UpdatePermission) {
                                Write-Verbose "Updating permissions for $Delegate on $FolderID"
                                $null = Set-MailboxFolderPermission -Identity $FolderID -User $Delegate -AccessRights $AccessRights -Confirm:$false -ErrorAction SilentlyContinue
                            }
                        }
                    }
                }
            }
        }

    
        # Check if the delegator and delegate mailboxes exist
        $DelegatorMailboxCheck = (Get-Mailbox $DelegatorMailbox -ErrorAction SilentlyContinue).PrimarySMTPAddress
        $DelegateMailboxCheck = $DelegateMailbox | ForEach-Object { Get-Mailbox $_ -ErrorAction SilentlyContinue }

        if ($null -eq $DelegatorMailboxCheck) {
            Write-Error "The delegator ($DelegatorMailbox) does not exist. Please check the email address."
            return
        }
        else {
            $DelegatorMailbox = $DelegatorMailboxCheck
        }

        if ($null -eq $DelegateMailboxCheck) {
            Write-Error "One or more of the specified delegate mailboxes ($DelegateMailbox) do not exist. Please check the email addresses."
            return
        }
        else {
            $DelegateMailbox = $DelegateMailboxCheck.PrimarySMTPAddress
        }

        # Initialize Arrays
        $ConvertFolderPath = @()
        $ExcludeFoldersPath = @()
        $FolderTypeSelection = "User Created", "Inbox", "SentItems", "DeletedItems", "JunkEmail", "Archive", "Drafts", "Notes", "Outbox"
        $MailboxFolderDetails = Get-MailboxFolderStatistics $DelegatorMailbox

        # Filter Mailbox Folders and convert folder paths
        $filteredFolder = $MailboxFolderDetails |
        Where-Object { $_.FolderType -in $FolderTypeSelection } |
        Select-Object Identity, Name, @{Name = "FolderPath" ; Expression = { $_.FolderPath -replace ("/", "\") } }

        # Create a hashtable
        $FolderPath = @{}
        foreach ($folder in $filteredFolder) {
            $FolderPath[$folder.FolderPath] = $true
        }

        # Convert folder paths and ensure they start with a backslash
        $ConvertFolderPath += $TargetFolder | ForEach-Object { if (($_).StartsWith("\")) { $_ } else { "\" + $_ } }
        if ($ExcludeFolders) {
            $ExcludeFoldersPath += $ExcludeFolders | ForEach-Object { if (($_).StartsWith("\")) { $_ } else { "\" + $_ } }
        }

        if ($ExcludeFoldersPath) {
            foreach ($excludePath in $ExcludeFoldersPath) {
                $ExcludedPaths += $filteredFolder.FolderPath |
                    Where-Object { $_ -like "$excludePath*" }
            }
        }
        # Process each folder in the ConvertFolderPath array
        foreach ($folder in $ConvertFolderPath) {
            if (-not $FolderPath.ContainsKey($folder)) {
                Write-Output "$folder specified does not exist in the mailbox"
            }
            else {
                # Apply ExcludeFolders filter
                if (!$ExcludeFoldersPath -or ($folder -notin $ExcludeFoldersPath)) {
                    $ParentFolder = ($DelegatorMailbox, ":", $folder) -join ""

                    if ($ManageAllSubFolders) {
                        Write-Output "Applying permission to parent folder $folder and subfolders"
                        Update-FolderPermission -FolderID $ParentFolder

                        # Find and filter subfolders, excluding those in $ExcludeFoldersPath
                        $Subfolders = $filteredFolder.FolderPath | Where-Object { $_ -like "$folder\*" -and $_ -notin $ExcludeFoldersPath -and $_ -notlike "$ExcludeFoldersPath\*"} | ForEach-Object { ($DelegatorMailbox + ":" + $_) }

                        foreach ($Subfolder in $Subfolders) {
                            Update-FolderPermission -FolderID $Subfolder
                        }
                    }
                    else {
                        Write-Output "Only applying permission to parent folder $folder"
                        Update-FolderPermission -FolderID $ParentFolder
                    }
                }
                else {
                    Write-Output "The folder $folder Excluded"
                }
            }
        }
    }
    end {
        Write-Verbose "Mailbox folder permissions update process completed."
    }
}
