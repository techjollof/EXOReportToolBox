# Get-CalendarFolderPermissionReport

## SYNOPSIS
Retrieves calendar permissions for specified mailboxes or all mailboxes if none are specified.

## DESCRIPTION
This script queries specified mailboxes or all mailboxes if no specific mailboxes are provided, and retrieves the calendar permissions for each mailbox. It outputs the results in a custom object format with details of mailbox name, email, folder name, user, and permissions.

## PARAMETERS

### MailboxTypes
Specifies the types of mailboxes to include. You can specify multiple values separated by commas, such as `UserMailbox`, `SharedMailbox`, or `RoomMailbox`. The default value is `All`.

- **Valid Values**: `UserMailbox`, `SharedMailbox`, `RoomMailbox`, `All`
- **Parameter Set**: `MailBoxTypes`
- **Description**: Specifies the types of mailboxes to include in the report. If "All" is selected, it includes all types of mailboxes. Note that "All" cannot be used in conjunction with other specific mailbox types.

### SpecificMailboxes
Specifies individual mailboxes to include. You can specify multiple mailbox identifiers separated by commas.

- **Parameter Set**: `SpecificMailboxes`
- **Type**: `string[]`
- **Description**: Lists the mailboxes to include in the report. This takes precedence over the `MailboxTypes` parameter if both are provided.

### ReportPath
Specifies the file path where the report will be saved.

- **Type**: `string`
- **Description**: The path where the output report will be written. If not provided, the report will be output to the console.

### ResultSize
Specifies the number of results to return.

- **Type**: `string`
- **Default Value**: `"Unlimited"`
- **Description**: Defines the maximum number of results to return. Use `"Unlimited"` to return all results. If a specific number is set, only that number of results will be returned.

## EXAMPLES

### Example 1
This gets the report all mailboxes except group mailbox
```powershell
Get-CalendarFolderPermissionReport 
```
### Example 2
Retrieves and displays the calendar permissions for all user mailboxes.

```powershell
Get-CalendarFolderPermissionReport -MailboxTypes "UserMailbox"
```

### Example 3
Retrieves and displays the calendar permissions for the specified mailboxes.

```powershell
Get-CalendarFolderPermissionReport -SpecificMailboxes "userA","userB"
```

### Example 4
Retrieves and displays the calendar permissions for shared and room mailboxes, limiting the results to 100.

```powershell
.\Get-CalendarFolderPermissionReport -MailboxTypes "SharedMailbox","RoomMailbox" -ResultSize 100
```

## Example 5
Retrieves and displays the calendar permissions for mailbox "userC" and saves the report to the specified file path `C:\Reports\CalendarPermissions.csv`.

```powershell
Get-CalendarFolderPermissionReport -SpecificMailboxes "userC" -ReportPath "C:\Reports\CalendarPermissions.csv"
```

## Notes
- Ensure you have the necessary permissions to access the mailbox calendars and generate the report.
- The `ReportPath` parameter is optional; if not specified, the report will be output to the console.
```

