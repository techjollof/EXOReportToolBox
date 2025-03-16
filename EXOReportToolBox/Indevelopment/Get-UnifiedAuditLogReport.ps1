<#
.SYNOPSIS
    This script processes audit logs either from local data or by retrieving data directly from a source.

.DESCRIPTION
    This function allows you to process audit logs in two ways:
    1. Using locally provided audit logs.
    2. Retrieving audit data directly from a source using specified parameters.

.PARAMETER AuditLogs
    The audit logs to process. This parameter is mandatory when using the "LocalData" parameter set.

.PARAMETER CreateAuditModifiedPropertyReport
    A switch parameter to indicate whether to create a report for modified properties in the audit logs.

.PARAMETER StartDate
    The start date for retrieving audit data. This parameter is mandatory when using the "DirectData" parameter set.

.PARAMETER EndDate
    The end date for retrieving audit data. This parameter is mandatory when using the "DirectData" parameter set.

.PARAMETER FreeText
    Filters the log entries by the specified text string. If the value contains spaces, enclose it in quotation marks.

.PARAMETER HighCompleteness
    A switch parameter to specify completeness over performance in the results. When used, the query returns more complete results but may take longer to run.

.PARAMETER SessionCommand
    The SessionCommand parameter specifies how much information is returned and how it's organized. This parameter is required if you want to retrieve more than the default limit of 100 results. Valid values are:

    ReturnLargeSet: This value causes the cmdlet to return unsorted data. By using paging, you can access a maximum of 50,000 results. This is the recommended value if an ordered result is not required and has been optimized for search latency.
    ReturnNextPreviewPage: This value causes the cmdlet to return data sorted on date. The maximum number of records returned through use of either paging or the ResultSize parameter is 5,000 records.
    
    Note: Always use the same SessionCommand value for a given SessionId value. Don't switch between ReturnLargeSet and ReturnNextPreviewPage for the same session ID. Otherwise, the output is limited to 10,000 results.
    

.PARAMETER ReportPath
    The path where the report will be saved. This parameter is mandatory for all parameter sets.

.EXAMPLE
    # Example 1: Using LocalData parameter set
    Get-UnifiedAuditLogReport -AuditLogs $logs -CreateAuditModifiedPropertyReport -ReportPath "C:\Reports\AuditReport.csv"

.EXAMPLE
    # Example 2: Using DirectData parameter set
    Get-UnifiedAuditLogReport -RetrieveAuditDataDirectly "SearchQuery" -StartDate (Get-Date).AddDays(-7) -EndDate (Get-Date) -FreeText "ImportantEvent" -HighCompleteness -ReportPath "C:\Reports\AuditReport.csv"


#>

[CmdletBinding()]
param(
    [Parameter(Mandatory = $true, ParameterSetName = "LocalData", ValueFromPipeline)]
    [Object[]]$AuditLogs,

    [Parameter(Mandatory = $true, ParameterSetName = "DirectData")]
    [datetime]$StartDate,

    [Parameter(Mandatory = $true, ParameterSetName = "DirectData")]
    [datetime]$EndDate,

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
    [ValidateNotNullOrEmpty()]
    [ValidateScript({
        if (-not (Test-Path $_)) {
            throw "The path '$_' does not exist or its invalid."
        }
        $true
    })]
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
    $paramHash = @{}
    $ProcessedLogs = @()
    $ProcessedParameterInfo = @()


    # Add parameters to the hashtable based on the parameter set and provided values
    if ($PSCmdlet.ParameterSetName -eq "DirectData") {
        # Add mandatory parameters for the DirectData set
        $paramHash['StartDate'] = $AuditStartDate
        $paramHash['EndDate'] = $AuditEndDate

        # Add optional parameters if they are provided
        if ($PSBoundParameters.ContainsKey('AuditRecordType')) {
            $paramHash['RecordType'] = $AuditRecordType
        }

        if ($PSBoundParameters.ContainsKey('AuditOperations')) {
            $paramHash['Operations'] = $AuditOperations
        }

        if ($PSBoundParameters.ContainsKey('AuditResultSize')) {
            $paramHash['ResultSize'] = $AuditResultSize
        }

        if ($PSBoundParameters.ContainsKey('FreeText')) {
            $paramHash['FreeText'] = $FreeText
        }

        if ($PSBoundParameters.ContainsKey('HighCompleteness')) {
            $paramHash['HighCompleteness'] = $HighCompleteness
        }

        if ($PSBoundParameters.ContainsKey('SessionCommand')) {
            $paramHash['SessionCommand'] = $SessionCommand
        }
    }

    # Example: Use the hashtable to call Search-UnifiedAuditLog
    if ($PSCmdlet.ParameterSetName -eq "DirectData") {
        $UnifiedAuditData = Search-UnifiedAuditLog @paramHash
    }
    elseif ($PSCmdlet.ParameterSetName -eq "LocalData") {
        $UnifiedAuditData = $AuditLogs
    }

    
    # get data source
    if ($PSCmdlet.ParameterSetName -eq "DirectData") {
        $UnifiedAuditData = Search-UnifiedAuditLog @paramHash
    }
    elseif ($PSCmdlet.ParameterSetName -eq "LocalData") {
        $UnifiedAuditData = $AuditLogs
    }
}

process {
    # Convert AuditData from JSON to PSCustomObject
    if ($UnifiedAuditData) {

        Write-Host "`nProcess and converting provided/retrieved M365 unified audit data...`n"

        foreach ($Log in $UnifiedAuditData) {

            $AuditData = $Log.AuditData | ConvertFrom-Json

            # $AuditData

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
    
        # Process and export parameters only if the switch is enabled
        if ($CreateAuditModifiedPropertyReport) {

            # Process and export parameters
            Write-Host "`nProcess the retrieved audit data parameters or properties that has been acted upon or change.`n"
        
            foreach ($Log in $UnifiedAuditData) {
            
                $AuditData = $Log.AuditData | ConvertFrom-Json

                # # $AuditData.Parameters
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
        }
    }
    else {
        Write-Host "The provided data is $AuditLogs is empty......... check and try again"
    }

}end {

    $directory = [System.IO.Path]::GetDirectoryName($ReportPath)
    $fileName = [System.IO.Path]::GetFileNameWithoutExtension($ReportPath)
    

    try {
        # Try exporting using the custom Export-ReportCsv function
        $ProcessedLogs | Export-ReportCsv -ReportPath $([System.IO.Path]::Combine($directory, "ExpandedAuditLogs_$($fileName).csv"))

        # Export processed logs to a readable format
        if($CreateAuditModifiedPropertyReport){
            $ProcessedParameterInfo | Export-ReportCsv -ReportPath $([System.IO.Path]::Combine($directory, "ExpandedParameterAuditLogs_$($fileName).csv"))
        }
    }
    catch {
        # If Export-ReportCsv fails, use the default export function
        Write-Warning "Custom export failed. Falling back to default export function."
        try {
            # Export using the default Export-Csv function
            $Owners | Export-Csv -Path  $([System.IO.Path]::Combine($directory, "Expanded Audit Report_$ReportPath_$($fileName).csv")) -NoTypeInformation
            Write-Host "Report saved to: $ReportPath using downloads export function."

            if($CreateAuditModifiedPropertyReport){
                $ProcessedParameterInfo | Export-Csv -ReportPath $([System.IO.Path]::Combine($directory, "ExpandedParameterAuditLogs_$($fileName).csv")) -NoTypeInformation
            }
        }
        catch {
            # Handle failure of the default export function
            Write-Error "Failed to save the report using both custom and default export functions: $_"
        }
    }
}