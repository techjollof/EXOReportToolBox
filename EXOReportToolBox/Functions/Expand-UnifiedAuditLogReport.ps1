<#
.SYNOPSIS  
This script processes audit logs either from local data or by retrieving data directly from a source.

.DESCRIPTION  
This function allows you to process audit logs in two ways:  
1. Using locally provided audit logs.  
2. Retrieving audit data directly from a source using specified parameters.  

.PARAMETER AuditLogs  
Specifies the audit logs to process. This parameter is required when using the "LocalData" parameter set.

.PARAMETER AuditStartDate  
Defines the start date for retrieving audit data. This parameter is required when using the "DirectData" parameter set.

.PARAMETER AuditEndDate  
Defines the end date for retrieving audit data. This parameter is required when using the "DirectData" parameter set.

.PARAMETER AuditRecordType  
Filters the logs based on specific record types. This is an optional parameter for the "DirectData" parameter set.

.PARAMETER AuditOperations  
Filters the logs based on specific operations. This is an optional parameter for the "DirectData" parameter set.

.PARAMETER AuditResultSize  
Specifies the number of records to retrieve. The default is 100. This is an optional parameter for the "DirectData" parameter set.

.PARAMETER FreeText  
Filters log entries by a specified text string. If the value contains spaces, enclose it in quotation marks. This is an optional parameter for the "DirectData" parameter set.

.PARAMETER HighCompleteness  
A switch parameter that prioritizes completeness over performance in the results. When enabled, queries return more complete results but may take longer to execute.

.PARAMETER SessionCommand  
Specifies how much information is returned and how it's structured. Required when retrieving more than the default 100 results.  
Valid values:  
- **ReturnLargeSet**: Returns unsorted data with a maximum of 50,000 results via paging.  
- **ReturnNextPreviewPage**: Returns sorted data with a maximum of 5,000 results.  

**Note**: Always use the same `SessionCommand` value for a given `SessionId`. Switching values within the same session may limit results to 10,000.

.PARAMETER CreateAuditModifiedPropertyReport  
A switch parameter indicating whether to generate a report for modified properties in the audit logs.

.PARAMETER ReportPath  
Defines the file path where the report will be saved. This parameter is required for all parameter sets.

.EXAMPLE  
# Example 1: Using the "LocalData" parameter set  
```powershell
Expand-UnifiedAuditLogReport -AuditLogs $logs -CreateAuditModifiedPropertyReport -ReportPath "C:\Reports\AuditReport.csv"
```

.EXAMPLE  
# Example 2: Using the "DirectData" parameter set  
```powershell
Expand-UnifiedAuditLogReport -AuditStartDate (Get-Date).AddDays(-7) -AuditEndDate (Get-Date) -FreeText "ImportantEvent" -HighCompleteness -ReportPath "C:\Reports\AuditReport.csv"
```
#>


[CmdletBinding()]
param(
    [Parameter(Mandatory = $true, ParameterSetName = "LocalData", ValueFromPipeline)]
    [Object[]]$AuditLogs,

    [Parameter(Mandatory = $true, ParameterSetName = "DirectData")]
    [datetime]$AuditStartDate,

    [Parameter(Mandatory = $true, ParameterSetName = "DirectData")]
    [datetime]$AuditEndDate,

    [Parameter(Mandatory = $false, ParameterSetName = "DirectData", HelpMessage = "https://learn.microsoft.com/en-us/office/office-365-management-api/office-365-management-activity-api-schema#auditlogrecordtype")]
    [string[]]$AuditRecordType,

    [Parameter(Mandatory = $false, ParameterSetName = "DirectData", HelpMessage = "https://learn.microsoft.com/en-us/purview/audit-log-activities")]
    [string[]]$AuditOperations,

    [Parameter(Mandatory = $false, ParameterSetName = "DirectData")]
    [int]$AuditResultSize = 100,

    [Parameter(Mandatory = $false, ParameterSetName = "DirectData")]
    [string]$FreeText,

    [Parameter(Mandatory = $false, ParameterSetName = "DirectData")]
    [switch]$HighCompleteness,

    [Parameter(Mandatory = $false, ParameterSetName = "DirectData")]
    [switch]$SessionCommand,

    [Parameter()]
    [switch]$CreateAuditModifiedPropertyReport,

    [Parameter(Mandatory = $true)]
    [ValidateScript({Test-Path -Path (Split-Path $_ -Parent) -PathType Container})]
    [string]$ReportPath
)

begin {
    # Function to recursively expand JSON objects
    function Expand-UnifiedAuditData {
        param(
            [Parameter(Mandatory = $true)]
            [PSCustomObject]$Data,

            [string]$Prefix = ""
        )

        $Expanded = @()
        foreach ($Property in $Data.PSObject.Properties) {
            $Name = if ($Prefix) { "$Prefix.$($Property.Name)" } else { $Property.Name }
        
            if ($Property.Value -is [PSCustomObject]) {
                $Expanded += Expand-UnifiedAuditData -Data $Property.Value -Prefix $Name
            }
            elseif ($Property.Value -is [System.Array]) {
                for ($i = 0; $i -lt $Property.Value.Count; $i++) {
                    $Expanded += Expand-UnifiedAuditData -Data $Property.Value[$i] -Prefix "$Name[$i]"
                }
            }
            else {
                $Expanded += [PSCustomObject]@{
                    Name  = $Name
                    Value = $Property.Value
                }
            }
        }
        return $Expanded
    }

    # Function to expand and limit parameters to 7 keys, merging extras into "OtherParameters"
    function Expand-Parameters {
        param(
            [Parameter(Mandatory = $true)]
            [Object[]]$Parameters
        )

        $Expanded = @{}
        $OtherParams = @()
        $Counter = 1  # Start index at 1

        foreach ($param in $Parameters) {
            # Convert JSON-like values if applicable
            $Value = $param.Value
            if ($Value -is [string] -and ($Value.StartsWith("{") -or $Value.StartsWith("["))) {
                try {
                    $Value = $Value | ConvertFrom-Json -ErrorAction Stop
                }
                catch {
                    # Keep original value if parsing fails
                }
            }

            if ($Counter -le 7) {
                $Expanded["Parameter[$Counter].Name"] = $param.Name
                $Expanded["Parameter[$Counter].Value"] = $Value
            }
            else {
                $OtherParams += [PSCustomObject]@{
                    Name  = $param.Name
                    Value = $Value
                }
            }
            $Counter++
        }

        # Merge extra parameters under "OtherParameters"
        if ($OtherParams.Count -gt 0) {
            $Expanded["OtherParameters"] = $OtherParams
        }

        return [PSCustomObject]$Expanded
    }

    # Create a hashtable to store the parameters
    $searchParams = @{}
    $ProcessedLogs = @()
    $ProcessedParameterInfo = @()

    
    # Example: Use the hashtable to call Search-UnifiedAuditLog
    try {
        # Add parameters to the hashtable based on the parameter set and provided values
        if ($PSCmdlet.ParameterSetName -eq "DirectData") {

            if(-not(Get-Command Search-UnifiedAuditLog -ErrorAction SilentlyContinue)){
                Write-Host "`nYou have not yet connected to ExchangeOnlineManagement. Please connect by running Connect-ExchangeOnline. If it fails, then must must be installed `nusing Install-Module ExchangeOnlineManagement. Retry after installing and connecting`n" -ForegroundColor Yellow
                break
            }

            # Add mandatory parameters for the DirectData set
            $searchParams['StartDate'] = $AuditStartDate
            $searchParams['EndDate'] = $AuditEndDate

            # Add optional parameters if they are provided
            if ($PSBoundParameters.ContainsKey('AuditRecordType')) {
                $searchParams['RecordType'] = $AuditRecordType
            }

            if ($PSBoundParameters.ContainsKey('AuditOperations')) {
                $searchParams['Operations'] = $AuditOperations
            }

            if ($PSBoundParameters.ContainsKey('AuditResultSize')) {
                $searchParams['ResultSize'] = $AuditResultSize
            }

            if ($PSBoundParameters.ContainsKey('FreeText')) {
                $searchParams['FreeText'] = $FreeText
            }

            if ($PSBoundParameters.ContainsKey('HighCompleteness')) {
                $searchParams['HighCompleteness'] = $HighCompleteness
            }

            if ($PSBoundParameters.ContainsKey('SessionCommand')) {
                $searchParams['SessionCommand'] = $SessionCommand
            }


            Write-Host "Retrieving audit data from Microsoft 365..." -ForegroundColor Cyan
            $UnifiedAuditData = Search-UnifiedAuditLog @searchParams
            
            if ($null -eq $UnifiedAuditData -or $UnifiedAuditData.Count -eq 0) {
                Write-Warning "No audit data found with the specified criteria."
                return
            }
            
            Write-Host "Retrieved $($UnifiedAuditData.Count) audit records." -ForegroundColor Green
        }
        else {
            $UnifiedAuditData = $AuditLogs
            
            if ($null -eq $UnifiedAuditData -or $UnifiedAuditData.Count -eq 0) {
                Write-Warning "The provided audit logs are empty. Please check and try again."
                return
            }
            
            Write-Host "Processing $($UnifiedAuditData.Count) provided audit records." -ForegroundColor Green
        }
        }
        catch {
            Write-Error "Error retrieving or processing audit data: $_"
            return
        }
}

process {
    # Convert AuditData from JSON to PSCustomObject
    if ($UnifiedAuditData) {
        Write-Host "`nProcess and converting provided/retrieved M365 unified audit data...`n"

        foreach ($Log in $UnifiedAuditData) {
            try {
                $AuditData = $Log.AuditData | ConvertFrom-Json -ErrorAction Stop
                $ExpandedData = Expand-UnifiedAuditData -Data $AuditData

                $FlattenedLog = [PSCustomObject]@{
                    RecordType   = $Log.RecordType
                    CreationDate = $Log.CreationDate
                    UserIds      = $Log.UserIds
                    Operations   = $Log.Operations
                }

                foreach ($Item in $ExpandedData) {
                    Add-Member -InputObject $FlattenedLog -MemberType NoteProperty -Name $Item.Name -Value $Item.Value -Force
                }

                $ProcessedLogs += $FlattenedLog
            }
            catch {
                Write-Warning "Failed to process log entry: $_"
            }
        }

        # Process and export parameters only if the switch is enabled
        if ($CreateAuditModifiedPropertyReport) {
            Write-Host "`nProcess the retrieved audit data parameters or properties that has been acted upon or change.`n"
        
            foreach ($Log in $UnifiedAuditData) {
                try {
                    $AuditData = $Log.AuditData | ConvertFrom-Json -ErrorAction Stop
                    $ExpandedParams = Expand-Parameters -Parameters $AuditData.Parameters

                    # Create the FlattenedParameterLog object
                    $FlattenedParameterLog = [PSCustomObject]@{
                        RecordType   = $Log.RecordType
                        CreationDate = $Log.CreationDate
                        UserIds      = $Log.UserIds
                        Operations   = $Log.Operations
                        AppID        = $AuditData.AppID
                        AppPoolName  = $AuditData.AppPoolName
                        ClientAppId  = $AuditData.ClientAppId
                    }

                    # Merge expanded parameters into the FlattenedParameterLog object
                    foreach ($Param in $ExpandedParams.PSObject.Properties) {
                        Add-Member -InputObject $FlattenedParameterLog -MemberType NoteProperty -Name $Param.Name -Value $Param.Value -Force
                    }

                    # Output the final object
                    $ProcessedParameterInfo += $FlattenedParameterLog
                }
                catch {
                    Write-Warning "Failed to process log entry for modified properties: $_"
                }
            }
        }
    }
    else {
        Write-Host "The provided data is empty......... check and try again"
    }
}

end {
    $directory = [System.IO.Path]::GetDirectoryName($ReportPath)
    $fileName = [System.IO.Path]::GetFileNameWithoutExtension($ReportPath)
    $timestamp = Get-Date -Format "yyyyMMdd_HHmmss"

    try {
        # Export using the default Export-Csv function
        $ProcessedLogs | Export-Csv -Path "$directory\Expanded_Audit_Report_$($fileName)_$timestamp.csv" -NoTypeInformation
        Write-Host "Report saved to: $directory\Expanded_Audit_Report_$($fileName)_$timestamp.csv"

        if ($CreateAuditModifiedPropertyReport) {
            $ProcessedParameterInfo | Export-Csv -Path "$directory\Expanded_Parameter_Report_$($fileName)_$timestamp.csv" -NoTypeInformation
            Write-Host "Parameter report saved to: $directory\Expanded_Parameter_Report_$($fileName)_$timestamp.csv"
        }
    }
    catch {
        Write-Error "Failed to save the report: $_"
    }
}