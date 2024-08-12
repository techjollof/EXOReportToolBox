# Get-GroupDeliveryManagementReport

## SYNOPSIS
Retrieves delivery management details for specified group types and exports a report.

## DESCRIPTION
The `Get-GroupDeliveryManagementReport` cmdlet retrieves information about groups (based on specified types) that have specific delivery management settings, meaning they accept messages only from certain users. It compiles this information into a report and exports it to a CSV file. Includes detailed permission information in the report, such as specifics about the types of access granted to users or trustees.



## EXAMPLES

### Example 1
```powershell
Get-GroupDeliveryManagementReport -GroupType MailDistributionGroup -ReportPath "C:\Reports\GroupReport.csv"
```

### EXAMPLE 2
```powershell
Get-GroupDeliveryManagementReport -GroupType MailDistributionGroup -ReportPath "C:\Reports\GroupReport.csv"  -ExpandedReport
```
**Description** Retrieves delivery management details for all mail distribution groups and exports the report to "C:\Reports\GroupReport.csv" The `ExpandedReport` give more expanded detail on the report, it will create role of each user.

### EXAMPLE 3
```powershell
Get-GroupDeliveryManagementReport -GroupType M365Groups -ResultSize 100 -ReportPath "C:\Reports\M365GroupReport.csv"    
```
**Description** Retrieves delivery management details for Microsoft 365 groups, limiting the result size to 100, and exports the report to "C:\Reports\M365GroupReport.csv".

## PARAMETERS

### `GroupType`
- **Type**: `string`
- **Required**: No
- **Default Value**: `AllDLs`
- **Accepted Values**:
  - `MailDistributionGroup`: Retrieves mail distribution groups.
  - `MailSecurityGroup`: Retrieves mail security groups.
  - `M365Groups`: Retrieves Microsoft 365 groups.
  - `DynamicGroups`: Retrieves dynamic distribution groups.
  - `AllDLs`: Retrieves all distribution lists (default).

Specifies the type of group to retrieve.

### `ReportPath`
- **Type**: `string`
- **Required**: Yes

Specifies the file path where the report will be saved. If a full file path is not provided (e.g., `\Reports\GroupReport` instead of `C:\Reports\GroupReport.csv`), the file will be exported to the `Downloads` folder by default if the provided path does not exit, with the name format `GroupReport_Date_time.csv`.

### `ResultSize`
- **Type**: `object`
- **Required**: No
- **Default Value**: `Unlimited`
- **Accepted Values**:
  - A positive integer to limit the number of results.
  - `Unlimited` for no limit.

Specifies the maximum number of results to return.

### `ExpandedReport`
- **Type**: `switch`
- **Required**: No


