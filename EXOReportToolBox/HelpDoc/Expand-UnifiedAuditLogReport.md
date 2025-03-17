# Expand-UnifiedAuditLogReport

## Overview

`Expand-UnifiedAuditLogReport` is a PowerShell script designed to process and analyze audit logs from Microsoft 365 Unified Audit Log data. The script can handle audit logs in two ways: This script was developed to streamline audit log analysis and reporting within Microsoft 365 environments.

1. **Using locally provided audit logs**

2. **Retrieving audit data directly from a source**

The script expands JSON-based audit log entries, extracts key parameters, and generates detailed reports.

## Features

- Supports processing of audit logs from local data files or direct retrieval from Microsoft 365.

- Converts JSON-based audit log data into an easily readable format.

- Extracts and structures detailed parameter information.

- Generates CSV reports for audit logs and modified property reports.

- Supports filtering based on audit record types, operations, date ranges, and free text searches.

- Provides an option to prioritize completeness over performance.

- Enables session-based data retrieval for handling large datasets.

## Prerequisites

- PowerShell 5.1 or later

- Exchange Online Management module (`Install-Module ExchangeOnlineManagement`)

- Required permissions to access audit logs

## Syntax

```powershell
Expand-UnifiedAuditLogReport 
    [-AuditLogs <Object[]>] 
    [-AuditStartDate <DateTime>] 
    [-AuditEndDate <DateTime>] 
    [-AuditRecordType <String[]>] 
    [-AuditOperations <String[]>] 
    [-AuditResultSize <Int>] 
    [-FreeText <String>] 
    [-HighCompleteness] 
    [-SessionCommand <String>] 
    [-CreateAuditModifiedPropertyReport <boolean>]
    [-ReportPath <String>]
```

## Examples

### Example 1: Using Local Data

```powershell
$Unifiedlogs = Search-UnifiedAuditLog -EndDate 3/15/2025 -StartDate 3/1/2025 -ResultSize 500 -RecordType ExchangeAdmin
Expand-UnifiedAuditLogReport -AuditLogs $Unifiedlogs -CreateAuditModifiedPropertyReport -ReportPath "C:\Reports\AuditReport.csv"
```

You are directly getting auditlog from server

### Example 2: Using Local Data

```powershell
$Unifiedlogs = Import-csv "ExistingM365UnifiedAuditfile.csv"
Expand-UnifiedAuditLogReport -AuditLogs $logs -CreateAuditModifiedPropertyReport -ReportPath "C:\Reports\AuditReport.csv"
```

Import an already export unified audit logs and processing to readable format

### Example 3: Retrieving Data Directly

```powershell
Expand-UnifiedAuditLogReport -AuditStartDate (Get-Date).AddDays(-7) -AuditEndDate (Get-Date) -FreeText "ImportantEvent" -HighCompleteness -ReportPath "C:\Reports\AuditReport.csv"
```

Automatically getting the logs from the server and processing the reports

## Parameters

### `-AuditLogs`

- **Description**: Specifies the audit logs to process. This is for unified audit data that you have already received, by running unified audit log command or import by csv

- **Type**: Object[]

- **Required**: Yes (when using "LocalData" parameter set)

- **Default Value**: N/A

- **Accepted Values**: N/A

### `-AuditStartDate`

- **Description**: Defines the start date for retrieving audit data.

- **Type**: DateTime

- **Required**: Yes (when using "DirectData" parameter set)

- **Default Value**: N/A

- **Accepted Values**: N/A

### `-AuditEndDate`

- **Description**: Defines the end date for retrieving audit data.

- **Type**: DateTime

- **Required**: Yes (when using "DirectData" parameter set)

- **Default Value**: N/A

- **Accepted Values**: N/A

### `-AuditRecordType`

- **Description**: Filters the logs based on specific record types.

- **Type**: String[]

- **Required**: No

- **Default Value**: N/A

- **Accepted Values**: Refer to Microsoft documentation

### `-AuditOperations`

- **Description**: Filters the logs based on specific operations.

- **Type**: String[]

- **Required**: No

- **Default Value**: N/A

- **Accepted Values**: Refer to Microsoft documentation

### `-AuditResultSize`

- **Description**: Specifies the number of records to retrieve.

- **Type**: Int

- **Required**: No

- **Default Value**: 100

- **Accepted Values**: Any positive integer

### `-FreeText`

- **Description**: Filters log entries by a specified text string.

- **Type**: String

- **Required**: No

- **Default Value**: N/A

- **Accepted Values**: Any string

### `-HighCompleteness`

- **Description**: Prioritizes completeness over performance in the results.

- **Type**: Switch

- **Required**: No

- **Default Value**: False

- **Accepted Values**: True, False

### `-SessionCommand`

- **Description**: Specifies how much information is returned and how it's structured.

- **Type**: String

- **Required**: No

- **Default Value**: N/A

- **Accepted Values**: "ReturnLargeSet", "ReturnNextPreviewPage"

### `-CreateAuditModifiedPropertyReport`

- **Description**: Indicates whether to generate a report for modified properties in the audit logs.

- **Type**: Switch

- **Required**: No

- **Default Value**: False

- **Accepted Values**: True, False

### `-ReportPath`

- **Description**: Defines the file path where the report will be saved.

- **Type**: String

- **Required**: Yes

- **Default Value**: N/A

- **Accepted Values**: Valid file path

## Output

The script generates the following reports in CSV format:

- **Expanded_Audit_Report_YYYYMMDD_HHMMSS.csv**: Contains detailed audit logs.

- **Expanded_Parameter_Report_YYYYMMDD_HHMMSS.csv** (if `-CreateAuditModifiedPropertyReport` is enabled): Contains extracted parameter details.

## Notes

- Ensure you have the necessary permissions to retrieve Microsoft 365 audit logs.

- If using direct retrieval, ensure you are connected to Exchange Online by running `Connect-ExchangeOnline`.

- The script checks for missing prerequisites and provides guidance if Exchange Online Management is not installed.

## Author

Daniel (techjollof@gmail.com)

## License

MIT License
