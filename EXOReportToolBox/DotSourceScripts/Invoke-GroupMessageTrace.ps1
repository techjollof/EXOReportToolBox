<#
.DESCRIPTION
This PowerShell script initiates a message trace for different types of groups in Microsoft 365. It allows users to specify parameters such as the batch size, the number of days to look back for message traces, the type of groups to include, and whether to include outbound messages. The script processes groups in batches, generating reports for received and optionally sent messages for the specified group types. 

The script can be particularly useful for administrators looking to monitor email traffic associated with distribution lists, dynamic distribution lists, or M365 groups over a specified timeframe.

.SYNOPSIS
Initiates a message trace for specified group types in batches.

.PARAMETER BatchSize
Specifies the number of groups to process in each batch. Must be between 1 and 100. Default is 100.

.PARAMETER DaysBack
The number of days to look back for message traces. Default is 90 days.

.PARAMETER GroupType
Specifies the type of groups to include in the trace. Options are:
    - DistributionList
    - DynamicDistributionList
    - M365Group
    - AllGroups
Default is AllGroups.

.PARAMETER IncludeOutbound
If specified, includes outbound message traces for the selected groups. This refers to emails sent from the groups 
where the group is the sender address, utilizing "Send As" or "Send on Behalf" permissions.

.EXAMPLE
Invoke-GroupMessageTrace -BatchSize 50 -DaysBack 30 -GroupType "M365Group" -IncludeOutbound
Initiates a message trace for M365 Groups over the last 30 days, processing 50 groups at a time,
and includes outbound message traces.

.EXAMPLE
Invoke-GroupMessageTrace -BatchSize 100 -DaysBack 60 -GroupType "AllGroups"
Initiates a message trace for all group types over the last 60 days, processing 100 groups at a time,
without including outbound messages.

.EXAMPLE
Invoke-GroupMessageTrace -BatchSize 20 -DaysBack 14 -GroupType "DistributionList" -IncludeOutbound
Initiates a message trace for Distribution Lists over the last 14 days, processing 20 groups at a time,
and includes outbound message traces.

.INPUTS
None. This function does not accept pipeline input.

.OUTPUTS
None. The function initiates a message trace report for the specified groups, which includes both received 
and optionally sent messages, depending on the `IncludeOutbound` parameter.
#>
[CmdletBinding()]
param (
    [ValidateRange(1, 100)]
    [int]$BatchSize = 100,

    [int]$DaysBack = 90,

    [ValidateSet("DistributionList", "DynamicDistributionList", "M365Group", "AllGroups")]
    [string]$GroupType = "AllGroups",

    [switch]$IncludeOutbound
)

# Retrieve groups based on the specified GroupType
Write-Output "Retrieving and processing selected group type: $GroupType"
$AllGroups = @()
switch ($GroupType) {
    "DistributionList" { $AllGroups = Get-DistributionGroup -ResultSize Unlimited -WarningAction SilentlyContinue }
    "DynamicDistributionList" { $AllGroups = Get-DynamicDistributionGroup -ResultSize Unlimited -WarningAction SilentlyContinue }
    "M365Group" { $AllGroups = Get-UnifiedGroup -ResultSize Unlimited -WarningAction SilentlyContinue }
    "AllGroups" {
        $AllGroups += Get-DistributionGroup -ResultSize Unlimited -WarningAction SilentlyContinue | Select-Object DisplayName, PrimarySMTPAddress
        $AllGroups += Get-DynamicDistributionGroup -ResultSize Unlimited -WarningAction SilentlyContinue | Select-Object DisplayName, PrimarySMTPAddress
        $AllGroups += Get-UnifiedGroup -ResultSize Unlimited -WarningAction SilentlyContinue | Select-Object DisplayName, PrimarySMTPAddress
    }
}

# Check if any groups were found
if (-not $AllGroups) {
    Write-Host "No groups found for the specified type: $GroupType" -ForegroundColor Yellow
    return
}

$startdate = (Get-Date).AddDays(-$DaysBack)
$enddate = Get-Date

# Calculate the total number of batches needed
$batchCount = [math]::Ceiling($AllGroups.Count / $BatchSize)

Write-Output "Initiating message trace for the selected groups`n"
for ($i = 0; $i -lt $batchCount; $i++) {
    # Calculate the start and end index for the current batch
    $startIndex = $i * $BatchSize
    $endIndex = [math]::Min(($i + 1) * $BatchSize - 1, $AllGroups.Count - 1)
    $currentBatch = $AllGroups[$startIndex..$endIndex]

    # Run the historical search for the combined recipient addresses
    Start-HistoricalSearch -ReportTitle "$GroupType Received Trace Report Batch $($i + 1)" `
        -StartDate $startdate `
        -EndDate $enddate `
        -ReportType MessageTrace `
        -RecipientAddress $currentBatch.PrimarySMTPAddress

    # Include outbound message traces if specified
    if ($IncludeOutbound) {
        Start-HistoricalSearch -ReportTitle "$GroupType Sent Trace Report Batch $($i + 1)" `
            -StartDate $startdate `
            -EndDate $enddate `
            -ReportType MessageTrace `
            -SenderAddress $currentBatch.PrimarySMTPAddress
    }
}
