function Edit-MailboxFolderPermission {
    [CmdletBinding()]
    param (
        # Delagator
        [Parameter(Mandatory)]
        [string]
        $DelagatorMailbox,

        # Delagate
        [Parameter(Mandatory)]
        [string[]]
        $DelagateMailbox,

        # FolderPermission
        [Parameter(Mandatory = $true)]
        [string[]]
        $FolderAccessRights,

        # Specifiy the folder to delegate
        [Parameter()]
        [string[]]
        $FolderToDelagete,

        # Specify the folder exlude
        [Parameter()]
        [string[]]
        $FolderToExclude,

        # Assigned  permission to all subfolders
        [Parameter()]
        [switch]
        $GrantAccessToAllSubFolders,

        # Parameter help description
        [Parameter()]
        [ValidateSet("AddPermission","RemovePermission")]
        $PermssionAction = "AddPermission",
    )

    # handle error message
    trap {
        Write-Warning "Script Failed: $_"
        throw $_
    }


    function Validate-Email {
        param (
            [string]$Email
        )
        $validEmails = @()
        foreach ($email in $Emails) {
            if ($email -match '^[\w-\.]+@([\w-]+\.)+[\w-]{2,4}$') {
                $validEmails += $email
            }
        }
        return $validEmails
    }

    function Edit-FolderPermission {
        param (
            # Parameter help description
            [Parameter(Mandatory)]
            [string]
            $FolderID,

            # Parameter help description
            [Parameter(Mandatory)]
            [string]
            $DelagateMailbox,

            # Parameter help description
            [Parameter(Mandatory)]
            [string]
            $FolderAccessRights,
            
            # Parameter help description
            [Parameter()]
            [ValidateSet("AddPermission","RemovePermission")]
            $PermssionAction = "AddPermission"
        )

        if($PermssionAction -eq "RemovePermission"){
            Remove-MailboxFolderPermission -Identity $FolderID -User $DelagateMailbox 
        }else{
            Add-MailboxFolderPermission -Identity $FolderID -User $DelagateMailbox -AccessRights $FolderAccessRights
        }
        
    }

    
    $FolderToDelagete = "Inbox, CreateSubfolders,Top3\EXO,Top3\SPO\AzureAD\AzureAD, Delete\AllItems, Delete/OwnedItems, EditAllItems".Split(",").Trim()
    $ConvertFolderPath =@()
    $FolderTypeSelection = "User Created", "Inbox", "SentItems", "DeletedItems", "JunkEmail", "Archive", "Drafts", "Notes", "Outbox"
    $MailboxFolderDetails = Get-MailboxFolderStatistics AddresBook@ithero.work.gd
    $filteredFolder = $MailboxFolderDetails | Where-Object { $_.FolderType -in $FolderTypeSelection } | Select-Object Identity, Name, @{Name = "FolderPath" ; Expression ={ $_.FolderPath -replace("/","\")}}
    
    $ConvertFolderPath += $FolderToDelagete | ForEach-Object { if (($_).StartsWith("\")) { $_ }else { "\" + $_ } }

    foreach ($folder  in $ConvertFolderPath) {
        
        if ($folder -notin $filteredFolder.FolderPath) {
            Write-Output "$folder specified does not exist on the mailox"
        }else {
            if($GrantAccessToASubFolders){
                $Subfolders = ($filteredFolder.FolderPath).Where({ $_.StartsWith($fodler)  })
                foreach ($Subfolder in $Subfolders) {
                    Edit-FolderPermission -FolderID -DelagateMailbox $DelagatorMailbox -AccessRights $FolderAccessRights
                }
            }else{
                Edit-FolderPermission -FolderID -DelagateMailbox $DelagatorMailbox -AccessRights $FolderAccessRights
            }
        }

    }

}


TODO:

<#

# SpcificFolder or not
+ If Get mabox folder statistis.
+ if sepcific folder
    Recursive permission, permission for specified folder and all sub folders 
    par: PermissionScope: AllSubFolder, OnlySpecifiedFolder
+ All folder folders

("None","CreateItems","CreateSubfolders","DeleteAllItems","DeleteOwnedItems","EditAllItems","EditOwnedItems","FolderContact","FolderOwner",
                    "FolderVisible","ReadItems","Author","Contributor","Editor","NonEditingAuthor","Owner","PublishingAuthor","PublishingEditor","Reviewer")


#>


$mbfld = Get-MailboxFolderStatistics AddresBook@ithero.work.gd



