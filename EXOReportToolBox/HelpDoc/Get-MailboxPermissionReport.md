# Get-MailboxPermissionReport

---

## SYNOPSIS
Generates a detailed report of mailbox permissions.

---

## DESCRIPTION
The `Get-MailboxPermissionReport` function is designed for administrators managing Exchange Online environments. It retrieves and displays permissions for specified mailboxes or types of mailboxes, helping to audit and review access rights. The report can include basic or detailed information about user or trustee access rights and can be exported to a specified file path.

This function supports various mailbox types, including User, Shared, and Room mailboxes. It can be particularly useful when auditing permissions across different mailbox categories or for specific mailboxes. The `-ExpandedReport` switch can be used to include more detailed permission information.

---

## NOTES
- This function is specifically designed for Exchange Online environments.
- Use the `-MailboxAddress` parameter to target specific mailboxes.
- The `-MailboxTypes` parameter allows you to select categories of mailboxes.
- The report can be exported to a file using the `-ReportPath` parameter.

---



## EXAMPLES

**Example 1: Retrieve Permissions for Specific Mailboxes**
```powershell
Get-MailboxPermissionReport -MailboxAddress "user1@example.com", "user2@example.com" -ReportPath "C:\Reports\MailboxPermissions.csv"
```
**Description:** This example retrieves and displays permissions for the mailboxes associated with "user1@example.com" and "user2@example.com". The report is saved to "C:\Reports\MailboxPermissions.csv".

**Example 2: Retrieve Permissions for All User Mailboxes**
```powershell
Get-MailboxPermissionReport -MailboxTypes "UserMailbox" -ReportPath "C:\Reports\UserMailboxPermissions.csv"
```
**Description:** This example retrieves and displays permissions for all user mailboxes in the environment. The report is saved to "C:\Reports\UserMailboxPermissions.csv".

**Example 3: Retrieve Permissions for All Mailboxes with Expanded Details**
```powershell
Get-MailboxPermissionReport -MailboxTypes "All" -ReportPath "C:\Reports\AllMailboxPermissions.csv" -ExpandedReport
```
**Description:** This example retrieves and displays permissions for all types of mailboxes (User, Shared, Room) with expanded detail information. The report is saved to "C:\Reports\AllMailboxPermissions.csv".

**Example 4: Retrieve Permissions for Specific Mailboxes with Expanded Details**
```powershell
Get-MailboxPermissionReport -MailboxAddress "user3@example.com", "user4@example.com" -ReportPath "C:\Reports\SpecificMailboxes.csv" -ExpandedReport
```
**Description:** This example retrieves and displays detailed permissions for the mailboxes associated with "user3@example.com" and "user4@example.com". The expanded report is saved to "C:\Reports\SpecificMailboxes.csv".



---

## PARAMETERS

- **`MailboxAddress`**
    - **Description:** Specify one or more mailbox addresses to retrieve permission details. This parameter is ideal for checking permissions on specific mailboxes.
    - **Type:** `string[]`
    - **Parameter Set:** SpecificMailboxes

- **`MailboxTypes`**
    - **Description:** Specify the type of mailboxes to include in the report. Available options are "UserMailbox", "SharedMailbox", "RoomMailbox", and "All". The default is "All".
    - **Type:** `string`
    - **Parameter Set:** Bulk
    - **Default Value:** "All"

- **`ReportPath`**
    - **Description:** Specify the file path where the report will be saved. This parameter is mandatory, ensuring that the report is saved to a specific location.
    - **Type:** `string`
    - **Parameter Set:** All
    - **Required:** Yes

- **`ExpandedReport`**
    - **Description:** Include detailed permission information in the report. This will provide a more comprehensive view of access rights, including the types of access granted to users or trustees.
    - **Type:** `switch`
    - **Parameter Set:** All


---
