
    [CmdletBinding()]
    param(

        [Parameter(ValueFromPipeline = $true, ValueFromPipelineByPropertyName = $true, ParameterSetName = "SpecificReport")]
        [Alias("ReportType")]
        [ValidateSet(
            "DistributionGroupOnly", "MailSecurityGroupOnly", "AllDistributionGroup", "DynamicDistributionGroup", "M365GroupOnly", "AllSecurityGroup",
            "NonMailSecurityGroup", "SecurityGroupExcludeM365", "M365SecurityGroup", "DynamicSecurityGroup", "DynamicSecurityExcludeM365", "AllGroups"
        )]
        $GroupType = "DistributionGroupOnly",

        [Parameter(Mandatory, HelpMessage = "Specify the file path to save the report.")]
        [string]
        $ReportPath,

        [Parameter()]
        [switch]$ExpandedReport,

        [Parameter(Mandatory = $false, HelpMessage = "Specify whether the selected GroupType should be exported")]
        [switch]$GroupSummaryReport,

        [Parameter(Mandatory = $false, ParameterSetName = "FullReport", HelpMessage = "Specify whether the report should be created for all group types")]
        [switch]$CreateReportForAllGroupsTypes

    )
