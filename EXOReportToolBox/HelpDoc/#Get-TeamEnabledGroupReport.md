# Get-TeamEnabledGroupReport

## Synopsis
Generates a report of all Microsoft 365 unified groups with Team functionality.

## Description
The `Get-TeamEnabledGroupReport` cmdlet retrieves detailed information about Microsoft 365 unified groups that have Teams functionality enabled. It collects and organizes data such as group name, email address, privacy type, SharePoint site URL, group owners, and member counts. The data is then exported to a CSV file specified by the user. For users running PowerShell 7 or later, parallel processing can be enabled to improve performance.


## Parameters

### `-filePath`
- **Type**: `string`
- **Description**: Specifies the full path of the CSV file where the report will be saved. This parameter is mandatory and requires a valid file path.
- **Default Value**: None (this parameter is required and must be specified by the user).

### `-UseParrallel`
- **Type**: `switch`
- **Description**: (Optional) Enables parallel processing to improve performance for large datasets. This option is only available in PowerShell 7 or later versions.
- **Default Value**: The cmdlet runs without parallel processing if this switch is not used.

## Examples

### Example 1
```powershell
Get-TeamEnabledGroupReport -filePath "C:\Reports\GroupReport.csv"
```
**Description** Retrieves all unified groups and exports the report to C:\Reports\GroupReport.csv. The report includes details about each group and its Team functionality.

### Example 2
```powershell
Get-TeamEnabledGroupReport -filePath "C:\Reports\GroupReport.csv" -UseParrallel
```
**Description** Retrieves all unified groups with parallel processing enabled (requires PowerShell 7) and exports the report to C:\Reports\GroupReport.csv. This option can enhance performance when working with large datasets.

Related Links
## Related Links

- [Get-UnifiedGroup](https://docs.microsoft.com/powershell/module/exchange/unified-groups/get-unifiedgroup): Provides detailed information about the `Get-UnifiedGroup` cmdlet, which retrieves information about unified groups in Microsoft 365.
- [Get-EXORecipient](https://docs.microsoft.com/powershell/module/exchange/exchange-online/get-exorecipient): Offers information on the `Get-EXORecipient` cmdlet, used to retrieve details about Exchange Online recipients.

