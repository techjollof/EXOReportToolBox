# Get-GroupOwnershipReport

## SYNOPSIS

Retrieves a detailed ownership report for the specified group type, including group owners, group names, and email addresses. The report can be expanded to include each owner in a separate row and exported to a CSV file.

## DESCRIPTION

The `Get-GroupOwnershipReport` cmdlet allows administrators to generate a report of group ownership for various group types. The report includes details such as the group name, email, owner names, owner emails, and the type of group. This cmdlet supports different group types, including distribution groups, security groups, dynamic groups, and Microsoft 365 groups.

You can specify the `GroupType` to filter the types of groups included in the report. Additionally, you can use the `-ExpandedReport` switch to format the report so that each owner appears on a separate row.

The report must be exported to a CSV file using the `-ReportPath` parameter.

## SYNTAX

```powershell
Get-GroupOwnershipReport
    [-GroupType <String>]
    -ReportPath <String>
    [-ExpandedReport]
    [<CommonParameters>]
```

## EXAMPLES

### Example 1: Generate a report for all distribution groups

```powershell
Get-GroupOwnershipReport -GroupType "AllDistributionGroup" -ReportPath "C:\Reports\GroupOwnership.csv"
```

Generates a report for all distribution groups and saves it to `C:\Reports\GroupOwnership.csv`.

### Example 2: Generate an expanded report for all Microsoft 365 groups

```powershell
Get-GroupOwnershipReport -GroupType "M365GroupOnly" -ExpandedReport -ReportPath "C:\Reports\M365GroupOwnership.csv"
```

Generates an expanded report for all Microsoft 365 groups, ensuring that each owner appears in a separate row, and saves it to `C:\Reports\M365GroupOwnership.csv`.

### Example 3: Generate a report for all security groups

```powershell
Get-GroupOwnershipReport -GroupType "AllSecurityGroup" -ReportPath "C:\Reports\SecurityGroupOwnership.csv"
```

Generates a report for all security groups and saves it to `C:\Reports\SecurityGroupOwnership.csv`.

### Example 4: Generate ownership reports for all group types

```powershell
$AllGroupTypes = @("DistributionGroupOnly", "MailSecurityGroupOnly", "AllDistributionGroup", "DynamicDistributionGroup", "M365GroupOnly", "AllSecurityGroup", "NonMailSecurityGroup", "SecurityGroupExcludeM365", "M365SecurityGroup", "DynamicSecurityGroup", "DynamicSecurityExcludeM365", "AllGroups")

$AllGroupTypes | ForEach-Object { 
    Get-GroupOwnershipReport -GroupType $_ -ReportPath "C:\Reports\$($_)Ownership.csv" 
}
```

This command generates ownership reports for all available group types and saves each to a separate CSV file.

## PARAMETERS

### `-GroupType`

- **Type**: `String`
- **Position**: 1
- **Required**: No
- **Accepted Values**:
  - `DistributionGroupOnly`            : Only mail-enabled distribution groups.
  - `MailSecurityGroupOnly`            : Only mail-enabled security groups.
  - `AllDistributionGroup`             : Includes all types of distribution groups.
  - `DynamicDistributionGroup`         : Only dynamic distribution groups.
  - `M365GroupOnly`                    : Only Microsoft 365 (M365) groups.
  - `AllSecurityGroup`                 : Includes all security groups.
  - `NonMailSecurityGroup`             : Only security groups that are NOT mail-enabled.
  - `SecurityGroupExcludeM365`         : Security groups, excluding M365 Security Groups.
  - `M365SecurityGroup`                : Only Microsoft 365 security groups.
  - `DynamicSecurityGroup`             : Only dynamic security groups.
  - `DynamicSecurityExcludeM365`       : Dynamic security groups, excluding M365 Security Groups.
  - `AllGroups`                        : Retrieves ownership details for all group types.

Specifies the type of groups to be included in the report. Only one value can be selected at a time.

### `-ReportPath`

- **Type**: `String`
- **Position**: 2
- **Required**: Yes
- **Description**:
  Specifies the file path where the generated group ownership report should be saved as a CSV file.

### `-ExpandedReport`

- **Type**: `SwitchParameter`
- **Position**: 3
- **Required**: No
- **Description**:
  If specified, the report will format each owner on a separate row.

## OUTPUTS

The function generates a report file at the specified `ReportPath`. The content of the report depends on the parameters provided:

- If `-ExpandedReport` is used, the report formats each owner on a separate row.

## NOTES

- Ensure that you have the appropriate permissions to retrieve group ownership details.
- This function may require PowerShell modules such as `ExchangeOnlineManagement` or `Microsoft.Graph` for retrieving group data.
- The generated report is saved as a CSV file and can be further processed in Excel or Power BI.

## RELATED LINKS

- [`Get-DistributionGroup`](https://docs.microsoft.com/powershell/module/exchange/get-distributiongroup)
- [`Get-MgGroup`](https://docs.microsoft.com/powershell/module/microsoft.graph.groups/get-mggroup)
- [`Get-DynamicDistributionGroup`](https://docs.microsoft.com/powershell/module/exchange/get-dynamicdistributiongroup)
- [`Get-MgGroupOwner`](https://docs.microsoft.com/powershell/module/microsoft.graph.groups/get-mggroupowner)
