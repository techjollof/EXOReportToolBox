# Get-GroupMembershipReport

## SYNOPSIS

Retrieves a detailed membership report for the specified group type, including group members, owner information, and group type. Optionally, the report can be expanded to include more detailed information and exported to a CSV file.

## DESCRIPTION

The `Get-GroupMembershipReport` cmdlet allows administrators to generate a report of group membership for specified group types. The report includes details such as the group name, email, owner names, owner emails, and the type of group. This cmdlet supports various group types, such as distribution groups, security groups, dynamic groups, and Microsoft 365 groups.

You can specify the `GroupType` to filter the types of groups to include in the report, which can be narrowed further based on different group types. Additionally, you can use the `-ExpandedReport` switch to include more detailed information about the group members.

The report can optionally be exported to a CSV file using the `-ReportPath` parameter. Additionally, a group summary report can be exported with the `-GroupSummaryReport` switch.

## SYNTAX

```powershell
Get-GroupMembershipReport
    [-GroupType <String>]
    -ReportPath <String>
    [-ExpandedReport]
    [-GroupSummaryReport]
    [<CommonParameters>]
```


## EXAMPLES

### Example 1: Generate a report for distribution groups

```powershell
Get-GroupMembershipReport -GroupType "DistributionGroupOnly" -ReportPath "C:\Reports\GroupMembership.csv"
```

Generates a report for all distribution groups and saves it to `C:\Reports\GroupMembership.csv`.

### Example 2: Generate an expanded report for all Microsoft 365 groups

```powershell
Get-GroupMembershipReport -GroupType "M365GroupOnly" -ExpandedReport -ReportPath "C:\Reports\M365GroupMembership.csv"
```

Generates an expanded report for all Microsoft 365 groups, including detailed member information, and saves it to `C:\Reports\M365GroupMembership.csv`.

### Example 3: Export a summary report for all security groups and members

```powershell
Get-GroupMembershipReport -GroupType "AllSecurityGroup" -GroupSummaryReport -ReportPath "C:\Reports\SecurityGroupSummary.csv"
```

Generates a summary report for all security groups and exports it to `C:\Reports\SecurityGroupSummary.csv`.

### Example 4: Export Summary Reports for All Group Types
```powershell
$AllGroupReport = @("DistributionGroupOnly", "MailSecurityGroupOnly", "AllDistributionGroup", "DynamicDistributionGroup", "M365GroupOnly", "AllSecurityGroup", "NonMailSecurityGroup", "SecurityGroupExcludeM365", "M365SecurityGroup", "DynamicSecurityGroup", "DynamicSecurityExcludeM365", "AllGroups")

$AllGroupReport | % { Get-GroupMembershipReport -GroupType $_ -ReportPath "C:\Reports\$($_)Summary.csv" }
```
This command generates a summary report for all available group types and saves each to a separate CSV file.

## PARAMETERS

### `-GroupType`

- **Type**: `String`
- **Position**: 1
- **Default Value**: `"DistributionGroupOnly"`
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

Specifies the type of groups to be included in the report. This defines which groups are queried and included based on their membership type. Only one value can be selected

### `-ReportPath`

- **Type**: `String`
- **Position**: 2
- **Required**: Yes
- **Description**:
  Specify the file path where the generated group membership report should be saved as a CSV file.

### `-ExpandedReport`

- **Type**: `SwitchParameter`
- **Position**: 3
- **Required**: No
- **Description**:
  If specified, the report will include expanded details for each group member.

### `-GroupSummaryReport`

- **Type**: `SwitchParameter`
- **Position**: 4
- **Required**: No
- **Description**:
  If specified, a summary report of the groups (without member details) will also be exported to a CSV file.


## Outputs
The function generates a report file at the specified `ReportPath`. The content of the report depends on the parameters provided:
- If `-ExpandedReport` is used, the report includes detailed membership information.
- If `-GroupSummaryReport` is used, the report provides a summary of the selected group type.


## NOTES

- Ensure that you have the appropriate permissions to retrieve group membership details and that the necessary modules (`Get-DistributionGroup`, `Get-MgGroup`, etc.) are installed.
- The `Export-ReportCsv.ps1` script must be available in the same directory as the script to export the report to CSV format.
- The `-ExpandedReport` switch provides a more detailed membership listing, which may result in a larger report size.

- Ensure you have the necessary permissions to access group membership information in your environment.
- The function relies on PowerShell modules such as `ExchangeOnlineManagement` or `Microsoft.graph` for group data retrieval. Ensure these modules are installed and imported before running the function.

## RELATED LINKS

- `Export-ReportCsv`
- [`Get-DistributionGroup`](https://docs.microsoft.com/powershell/module/exchange/get-distributiongroup)
- [`Get-MgGroup`](https://docs.microsoft.com/powershell/module/microsoft.graph.groups/get-mggroup)
- [`Get-DynamicDistributionGroup`](https://docs.microsoft.com/powershell/module/exchange/get-dynamicdistributiongroup)
- [`Get-MgGroupMember`](https://docs.microsoft.com/powershell/module/microsoft.graph.groups/get-mggroupmember)
