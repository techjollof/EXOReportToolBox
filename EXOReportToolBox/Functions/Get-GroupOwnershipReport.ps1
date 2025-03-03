<#
.SYNOPSIS
    Generates a report on group ownership based on specified group types.

.DESCRIPTION
    The Get-GroupOwnershipReport function retrieves group ownership details for different types of groups 
    (e.g., Distribution Groups, Security Groups, M365 Groups). The report is saved to a specified file path. 
    Optionally, the output can be expanded to display each owner in a separate row.

.PARAMETER GroupType
    Specifies the type of groups to include in the report. Valid options:
        - "DistributionGroupOnly"            : Only mail-enabled distribution groups.
        - "MailSecurityGroupOnly"            : Only mail-enabled security groups.
        - "AllDistributionGroup"             : Includes all types of distribution groups.
        - "DynamicDistributionGroup"         : Only dynamic distribution groups.
        - "M365GroupOnly"                    : Only Microsoft 365 (M365) groups.
        - "AllSecurityGroup"                 : Includes all security groups.
        - "NonMailSecurityGroup"             : Only security groups that are NOT mail-enabled.
        - "SecurityGroupExcludeM365"         : Security groups, excluding M365 Security Groups.
        - "M365SecurityGroup"                : Only Microsoft 365 security groups.
        - "DynamicSecurityGroup"             : Only dynamic security groups.
        - "DynamicSecurityExcludeM365"       : Dynamic security groups, excluding M365 Security Groups.
        - "AllGroups"                        : Retrieves ownership details for all group types.

.PARAMETER ReportPath
    Specifies the file path where the group ownership report will be saved. This parameter is mandatory.

.PARAMETER ExpandedReport
    If specified, the report will be expanded so that each group owner appears in a separate row 
    instead of being grouped under a single group entry.

.EXAMPLE
    Get-GroupOwnershipReport -GroupType "DistributionGroupOnly" -ReportPath "C:\Reports\GroupOwnership.csv"

    This command generates an ownership report for all **mail-enabled distribution groups** and 
    saves it as a CSV file in the specified location.

.EXAMPLE
    Get-GroupOwnershipReport -GroupType "M365GroupOnly" -ReportPath "C:\Reports\M365GroupOwners.csv" -ExpandedReport

    This command generates a report for **Microsoft 365 Groups**, expanding the report so that each owner 
    is displayed on a separate row. The report is saved as an csv file.

.NOTES
    - Requires the appropriate permissions to retrieve group ownership information.
    - The function uses the `Get-DistributionGroup`, `Get-DynamicDistributionGroup`, `Get-MgGroup`, and `Get-MgGroupOwner` cmdlets.
    - The function uses the `Get-Recipient` cmdlet to retrieve owner information for Exchange groups.
    - The function uses the `Get-MgGroupOwner` cmdlet to retrieve owner information for Microsoft 365 groups.
    - The report format (CSV) is determined by the file extension in the specified path.
    - Ensure the provided path has write permissions.
    - If `-ExpandedReport` is not used, multiple owners will be listed under a single group entry.
    - The function uses the `Export-ReportCsv` function to export the report. 
      If the custom export function fails, it falls back to the default `Export-Csv` cmdlet.
#>




function Get-GroupOwnershipReport {
    param (
        [ValidateSet(
            "DistributionGroupOnly", "MailSecurityGroupOnly", "AllDistributionGroup", "DynamicDistributionGroup", "M365GroupOnly", "AllSecurityGroup",
            "NonMailSecurityGroup", "SecurityGroupExcludeM365", "M365SecurityGroup", "DynamicSecurityGroup", "DynamicSecurityExcludeM365", "AllGroups"
        )]
        $GroupType,
    
        [Parameter(Mandatory, HelpMessage = "Specify the file path to save the report.")]
        [string]
        $ReportPath,
    
        [Parameter()]
        [switch]$ExpandedReport # Switch to expand the report with each owner on a separate row
    )

    # Import the Export-ReportCsv function
    begin {
        # Dot-source the Export-ReportCsv.ps1 script using a cross-platform method
        . ([System.IO.Path]::Combine($PSScriptRoot, "Export-ReportCsv.ps1"))
        
        function Get-GroupDetails {
            param (
                [ValidateSet(
                    "DistributionGroupOnly", "MailSecurityGroupOnly", "AllDistributionGroup", "DynamicDistributionGroup", "M365GroupOnly", "AllSecurityGroup",
                    "NonMailSecurityGroup", "SecurityGroupExcludeM365", "M365SecurityGroup", "DynamicSecurityGroup", "DynamicSecurityExcludeM365", "AllGroups"
                )]
                $GroupType
            )
        
            Write-Host "Retrieving group details for $GroupType..."
        
            $groupTypeMap = @{
                "DistributionGroupOnly"      = { Get-DistributionGroup -RecipientTypeDetails MailUniversalDistributionGroup -ResultSize Unlimited -ErrorAction SilentlyContinue }
                "AllDistributionGroup"       = { Get-DistributionGroup -ResultSize Unlimited -ErrorAction SilentlyContinue }
                "MailSecurityGroupOnly"      = { Get-DistributionGroup -RecipientTypeDetails MailUniversalSecurityGroup -ResultSize Unlimited -ErrorAction SilentlyContinue }
                "DynamicDistributionGroup"   = { Get-DynamicDistributionGroup -ResultSize Unlimited -ErrorAction SilentlyContinue }
                "M365GroupOnly"              = { Get-MgGroup -Filter "groupTypes/any(c:c eq 'Unified')" }
                "AllSecurityGroup"           = { Get-MgGroup -Filter "SecurityEnabled eq true" }
                "NonMailSecurityGroup"       = { Get-MgGroup -Filter "SecurityEnabled eq true and MailEnabled eq false" }
                "SecurityGroupExcludeM365"   = { Get-MgGroup -Filter "SecurityEnabled eq true" | Where-Object { "Unified" -notin $_.GroupTypes } }
                "M365SecurityGroup"          = { Get-MgGroup -Filter "SecurityEnabled eq true and groupTypes/any(c:c eq 'Unified')" }
                "DynamicSecurityGroup"       = { Get-MgGroup -Filter "groupTypes/any(c:c eq 'DynamicMembership')" }
                "DynamicSecurityExcludeM365" = { Get-MgGroup -Filter "SecurityEnabled eq true and groupTypes/any(c:c eq 'DynamicMembership')" }
                "AllGroups"                  = {
                    $allGroups = Get-MgGroup -All
                    $dynamicGroups = Get-DynamicDistributionGroup -ResultSize Unlimited
                    $allGroups + $dynamicGroups
                }
            }
        
            try {
                if ($groupTypeMap.ContainsKey($GroupType)) {
                    return & $groupTypeMap[$GroupType]
                }
                else {
                    throw "Unknown group type: $GroupType"
                }
            }
            catch {
                Write-Host "Error occurred while fetching groups for type '$GroupType': $_"
                throw $_
            }
        }
        
        function Get-OwnerInfo {
            param (
                [Object]$Group
            )
        
            $groupId = if ($group.PSObject.Properties.Name -contains "ExternalDirectoryObjectId") { $group.ExternalDirectoryObjectId } else { $group.Id }
        
            if ($group.PSObject.Properties.Name -contains "ManagedBy") {
                if ($Group.ManagedBy.Count -ne 0) {
                    $ownerInfo = $Group.ManagedBy | Where-Object { $_ -ne "Organization Management" } | ForEach-Object { Get-Recipient $_ }
                    return @(
                        foreach ($owner in $ownerInfo) {
                            [PSCustomObject]@{
                                OwnerEmail = $owner.PrimarySmtpAddress
                                OwnerName  = $owner.DisplayName
                            }
                        }
                    )
                }
            }
            else {
                try {
                    $ownerInfo = Get-MgGroupOwner -GroupId $groupId | Select-Object -ExpandProperty AdditionalProperties
                    return @(
                        foreach ($owner in $ownerInfo) {
                            [PSCustomObject]@{
                                OwnerEmail = $owner.mail
                                OwnerName  = $owner.displayName
                            }
                        }
                    )
                }
                catch {
                    Write-Warning "Failed to retrieve owner information for group: $($group.DisplayName). Error: $_"
                }
            }
        
            return @([PSCustomObject]@{ OwnerEmail = "No Owners"; OwnerName = "No Owners" })
        }
        
        function Get-GroupTypeInfo {
            param (
                [Object]$Group
            )
        
            # Define a hash table for fast lookup of RecipientTypeDetails
            $recipientTypeMap = @{
                "MailUniversalDistributionGroup" = "Distribution Group"
                "MailUniversalSecurityGroup"     = "Mail Security Group"
                "RoomList"                       = "Resource Room List"
                "DynamicDistributionGroup"       = "Dynamic Distribution Group"
            }
        
            # Cache expensive property lookups
            $recipientTypeDetails = $Group.RecipientTypeDetails
            $groupTypes = $Group.GroupTypes
            $isMailEnabled = $Group.MailEnabled
            $isSecurityEnabled = $Group.SecurityEnabled
        
            # Check if the recipient type exists in the predefined map
            if ($recipientTypeDetails -and $recipientTypeMap.ContainsKey($recipientTypeDetails)) {
                return $recipientTypeMap[$recipientTypeDetails]
            }
        
            # Handle case where groupTypes is null or empty
            if (-not $groupTypes) {
                if ($isMailEnabled) {
                    return $(if ($isSecurityEnabled) { "Mail Security Group" } else { "Distribution Group" })
                }
                return "Security Group"
            }
        
            # Determine group type based on attributes
            $containsUnified = $groupTypes -contains "Unified"
            $containsDynamic = $groupTypes -contains "DynamicMembership"
        
            if ($isSecurityEnabled) {
                if ($containsUnified -and $containsDynamic) { return "Dynamic M365 Security Group" }
                if ($containsUnified) { return "M365 Security Group" }
                if ($containsDynamic) { return "Dynamic Security Group" }
            }
        
            if ($containsUnified -and $containsDynamic) { return "Dynamic M365 Group" }
            if ($containsUnified) { return "M365 Group" }
            if ($containsDynamic) { return "Dynamic Group" }
        }
    }
    
    
    process {
            
        
        $Owners = @()

        $groups = Get-GroupDetails -GroupType $GroupType

        Write-Host "Processing group ownership report for $($groups.count) ..."
        $groupCount = $Groups.Count
        $groupProcessed = 0
    
        foreach ($group in $groups) {
            $groupProcessed += 1

            # Processing progress
            Write-Verbose "Process owner information for group: $($group.DisplayName)"
            if ($groupProcessed % 50 -eq 0 -or $groupProcessed -eq $groupCount) {
                Write-Host $("Processed $groupProcessed of $groupCount groups")
            }

            $GroupEmail = if ($group.PSObject.Properties.Name -contains "PrimarySMTPAddress") { $Group.PrimarySMTPAddress } else { $Group.Mail }
            $GroupTypeInfo = Get-GroupTypeInfo -Group $Group

            # Write-Host "Processing group: $($group.DisplayName)... $GroupTypeInfo"

            $ownerInfo = Get-OwnerInfo -Group $Group
    
            if ($ExpandedReport) {
                # List each owner on a separate row
                foreach ($owner in $ownerInfo) {
                    $Owners += [PSCustomObject]@{
                        GroupName  = $group.DisplayName
                        GroupEmail = $GroupEmail
                        OwnerName  = $owner.OwnerName
                        OwnerEmail = $owner.OwnerEmail
                        GroupType  = $GroupTypeInfo
                    }
                }
            }
            else {
                # List all owners in a single row (comma-separated)
                $Owners += [PSCustomObject]@{
                    GroupName  = $group.DisplayName
                    GroupEmail = $GroupEmail
                    OwnerName  = ($ownerInfo.OwnerName -join ", ")
                    OwnerEmail = ($ownerInfo.OwnerEmail -join ", ")
                    GroupType  = $GroupTypeInfo
                }
            }
        }

        Write-Host "`nTotal number of groups being processed: $($Owners.Count)"
        # $Owners | FT GroupName, GroupEmail, GroupType -AutoSize
    }
    
    end {

        $directory = [System.IO.Path]::GetDirectoryName($ReportPath)
        $fileName = [System.IO.Path]::GetFileNameWithoutExtension($ReportPath)
        $ReportPath = [System.IO.Path]::Combine($directory, "$($fileName)_$($GroupType).csv")

        try {
            # Try exporting using the custom Export-ReportCsv function
            $Owners | Export-ReportCsv -ReportPath $ReportPath
        }
        catch {
            # If Export-ReportCsv fails, use the default export function
            Write-Warning "Custom export failed. Falling back to default export function."
            try {
                # Export using the default Export-Csv function
                $Owners | Export-Csv -Path $ReportPath -NoTypeInformation
                Write-Host "Report saved to: $ReportPath using default export function."
            }
            catch {
                # Handle failure of the default export function
                Write-Error "Failed to save the report using both custom and default export functions: $_"
            }
        }
    }
}