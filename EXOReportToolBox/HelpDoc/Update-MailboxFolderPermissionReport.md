# Update-MailboxFolderPermissionReport

## SYNOPSIS
Edits mailbox folder permissions by adding, updating, or removing delegate permissions.

## DESCRIPTION
The `Update-MailboxFolderPermissionReport` function manages mailbox folder permissions by allowing the addition, updating, or removal of permissions for delegates. This function supports specifying permissions for individual folders and optionally applying settings to all subfolders. It also includes advanced features for error handling, logging, and performance optimization.

This is one to many mailbox, that is giving permission to many user on one mailbox folder.

## PARAMETERS

### `-DelegatorMailbox`
The mailbox where permissions are being applied. This parameter is mandatory in both `AddOrSet` and `Remove` parameter sets.

- **Type**: `string`
- **Aliases**: `Delegator`
- **ParameterSetName**: `AddOrSet`, `Remove`
- **Position**: 0
- **Default Value**: None
- **Validation**: Ensures the mailbox exists and is a valid email address.

### `-DelegateMailbox`
The mailbox or mailboxes that are being granted or removed permissions. This parameter is mandatory in both `AddOrSet` and `Remove` parameter sets.

- **Type**: `string[]`
- **Aliases**: `Delegate`
- **ParameterSetName**: `AddOrSet`, `Remove`
- **Position**: 1
- **Default Value**: None
- **Validation**: Ensures each mailbox exists and is a valid email address.

### `-TargetFolder`
The folders for which permissions are being managed. This can be a single folder or multiple folders. This parameter is mandatory in both `AddOrSet` and `Remove` parameter sets.

- **Type**: `string[]`
- **Aliases**: `Folder`
- **ParameterSetName**: `AddOrSet`, `Remove`
- **Position**: 2
- **Default Value**: None
- **Validation**: Validates that the folder exists in the specified mailbox.

### `-AccessRights`
The permissions to assign to the delegate(s). Valid values include permissions such as "ReadItems", "EditAllItems", "FolderOwner", etc. This parameter is mandatory in the `AddOrSet` parameter set.

- **Type**: `string[]`
- **Aliases**: `Rights`
- **ParameterSetName**: `AddOrSet`
- **Position**: 3
- **Default Value**: None
- **Validation**: Must be a valid access right according to the set options.

### `-ManageAllSubFolders`
If specified, the permissions will be applied to all subfolders of the target folder.

- **Type**: `switch`
- **Aliases**: `SubFolders`
- **ParameterSetName**: `AddOrSet`
- **Position**: 4
- **Default Value**: `$false`
- **Usage**: Use this switch to apply permissions recursively.

### `-FolderToExclude`
A list of folders to exclude from the permission changes. This parameter can be used in conjunction with the `ManageAllSubFolders` parameter.

- **Type**: `string[]`
- **Aliases**: `ExcludeFolders`
- **ParameterSetName**: `AddOrSet`, `Remove`
- **Position**: 5
- **Default Value**: `@()`
- **Usage**: Specify folders that should not be affected by permission changes.

### `-UpdatePermission`
Use this parameter to update existing permissions. It is used in the `AddOrSet` parameter set.

- **Type**: `switch`
- **Aliases**: `Update`
- **ParameterSetName**: `AddOrSet`
- **Position**: 6
- **Default Value**: `$false`
- **Usage**: Apply this switch to modify existing permissions rather than adding new ones.

### `-RemovePermission`
Use this parameter to remove existing permissions. It is used in the `Remove` parameter set.

- **Type**: `switch`
- **Aliases**: `Remove`
- **ParameterSetName**: `Remove`
- **Position**: 7
- **Default Value**: `$false`
- **Usage**: Apply this switch to remove permissions for the specified delegate(s).

### `-Confirm`

**Description:**
Prompts for confirmation before executing potentially destructive actions. This parameter is used to ensure that users explicitly approve the execution of actions that can cause significant changes, deletions, or other potentially impactful operations.

- **Type:** `Switch`
- **Aliases:** None
- **Position:** Named
- **Default Value:** None
- **Required:** False
- **Accept Pipeline Input:** False
- **Accept Wildcard Characters:** False

- **Purpose:** The `-Confirm` parameter adds an additional layer of safety by asking for user approval before proceeding with operations that could affect data or system configurations.
- **Behavior:** When `-Confirm` is specified, the function will display a confirmation prompt, allowing the user to review and approve the action before it is executed. If the user declines, the function will abort the operation, thus preventing unintended changes.
- **Default Behavior:** If `-Confirm` is not specified, the function may execute the specified actions without prompting for confirmation, depending on how the function is designed.
- **Prompt Handling:** When `-Confirm` is used, a confirmation dialog will appear, requesting the user to confirm their intention to proceed. This helps avoid accidental execution of critical operations.
- **Interaction with Other Parameters:** Using `-Confirm` in combination with parameters like `-WhatIf` can provide a comprehensive safety check, where `-WhatIf` simulates the actions and `-Confirm` ensures user consent before actual execution.



## EXAMPLES

### Example 1: Update Permissions
```powershell
Update-MailboxFolderPermissionReport -DelegatorMailbox "user@example.com" -DelegateMailbox "delegate@example.com" -TargetFolder "Inbox" -AccessRights "Editor" -UpdatePermission
```
**Description**: Updates the permission for `delegate@example.com` on the "Inbox" folder of `user@example.com` to "Editor".

### Example 2: Apply Permissions to All Subfolders
```powershell
Update-MailboxFolderPermissionReport -DelegatorMailbox "user@example.com" -DelegateMailbox "delegate@example.com" -TargetFolder "Calendar" -AccessRights "ReadItems" -ManageAllSubFolders
```
**Description**: Adds "ReadItems" permission to `delegate@example.com` for the "Calendar" folder and all its subfolders of `user@example.com`.

### Example 3: Remove Permissions
```powershell
Update-MailboxFolderPermissionReport -DelegatorMailbox "user@example.com" -DelegateMailbox "delegate@example.com" -TargetFolder "Sent Items" -RemovePermission
```
**Description**: Removes all permissions from `delegate@example.com` for the "Sent Items" folder of `user@example.com`.

```powershell
Update-MailboxFolderPermissionReport -DelegatorMailbox "user@example.com" -DelegateMailbox "delegate@example.com" -TargetFolder "Inbox" -AccessRights "Editor" -UpdatePermission -Confirm
```
**Description**: This example updates the permission for delegate@example.com on the Inbox folder of user@example.com to Editor. The -Confirm parameter is used to prompt for confirmation before applying the changes, ensuring that the user reviews and approves the modification before it is executed.

```powershell
Update-MailboxFolderPermissionReport -DelegatorMailbox "user@example.com" -DelegateMailbox "delegate@example.com" -TargetFolder "Sent Items" -RemovePermission -Confirm:$false
````
**Description**This example removes all permissions from "delegate@example.com" for the "Sent Items" folder of "user@example.com" and prompts for confirmation before proceeding with the removal.




## NOTES

- **Verbose Logging**: Use `-Verbose` to get detailed logging about the actions performed by the script. This helps in tracking and debugging.
- **Error Handling**: The script includes error handling that provides informative messages and handles exceptions gracefully.
- **Performance Considerations**: For large operations, consider running the script during off-peak hours or using batch processing to minimize impact on system performance.

## SEE ALSO
- [Add-MailboxFolderPermission](https://learn.microsoft.com/en-us/powershell/module/exchange/add-mailboxfolderpermission)
- [Set-MailboxFolderPermission](https://learn.microsoft.com/en-us/powershell/module/exchange/set-mailboxfolderpermission)
- [Remove-MailboxFolderPermission](https://learn.microsoft.com/en-us/powershell/module/exchange/remove-mailboxfolderpermission)
- [Get-MailboxFolderStatistics](https://learn.microsoft.com/en-us/powershell/module/exchange/get-mailboxfolderstatistics)

