<#
.SYNOPSIS
    Generates a report of group memberships based on the specified group type.

.DESCRIPTION
    This script retrieves and exports group membership details for various types of groups, including Distribution Groups, Security Groups, M365 Groups, and Dynamic Groups.

.PARAMETER GroupType
    Specifies the type of groups to be included in the report. Options include:
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
    The file path where the report will be saved.

.PARAMETER ExpandedReport
    If specified, the report will include detailed membership information.

.PARAMETER GroupSummaryReport
    If specified, a summary report of the selected group type will be exported.

.EXAMPLE
    Get-GroupMembershipReport -GroupType "AllGroups" -ReportPath "C:\Reports\GroupReport.csv" -ExpandedReport

.EXAMPLE
    Get-GroupMembershipReport -GroupType "M365GroupOnly" -ReportPath "C:\Reports\M365Report.csv" -GroupSummaryReport

.EXAMPLE
    Get-GroupMembershipReport -GroupType "SecurityGroupExcludeM365" -ReportPath "C:\Reports\SecurityGroups.csv"

.NOTES
    Author: Your Name
    Date: March 2025
#>

function Get-GroupMembershipReport {
    
    [CmdletBinding()]
    param(

        [Parameter(ValueFromPipeline = $true, ValueFromPipelineByPropertyName = $true)]
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
        [switch]$GroupSummaryReport
    )

    begin {
        # Import the Export-ReportCsv function
        . "$PSScriptRoot\Export-ReportCsv.ps1"
        
        function Get-GroupDetails {
            param (
                [ValidateSet(
                    "DistributionGroupOnly", "MailSecurityGroupOnly", "AllDistributionGroup", "DynamicDistributionGroup", "M365GroupOnly", "AllSecurityGroup",
                    "NonMailSecurityGroup", "SecurityGroupExcludeM365", "M365SecurityGroup", "DynamicSecurityGroup", "DynamicSecurityExcludeM365", "AllGroups"
                )]
                $GroupType
            )
    
            Write-Host "Retrieving group details for $GroupType..."
    
            # Define a lookup table for GroupType and their corresponding filters/commands
            $groupTypeMap = @{
                "DistributionGroupOnly"      = { Get-DistributionGroup -RecipientTypeDetails MailUniversalDistributionGroup -ResultSize Unlimited -ErrorAction SilentlyContinue }
                "AllDistributionGroup"       = { Get-DistributionGroup -ResultSize Unlimited   -ErrorAction SilentlyContinue }
                "MailSecurityGroupOnly"      = { Get-DistributionGroup -RecipientTypeDetails MailUniversalSecurityGroup -ResultSize Unlimited  -ErrorAction SilentlyContinue }
                "DynamicDistributionGroup"   = { Get-DynamicDistributionGroup -ResultSize Unlimited  -ErrorAction SilentlyContinue }
                "M365GroupOnly"              = { Get-MgGroup -Filter "groupTypes/any(c:c eq 'Unified')" }
                "AllSecurityGroup"           = { Get-MgGroup -Filter "SecurityEnabled eq true" }
                "NonMailSecurityGroup"       = { Get-MgGroup -Filter "SecurityEnabled eq true and MailEnabled eq false" }
                "SecurityGroupExcludeM365"   = { Get-MgGroup -Filter "SecurityEnabled eq true" | Where-Object { "Unified" -notin $_.GroupTypes } }
                "M365SecurityGroup"          = { Get-MgGroup -Filter "SecurityEnabled eq true and groupTypes/any(c:c eq 'Unified')" }
                "DynamicSecurityGroup"       = { Get-MgGroup -Filter "groupTypes/any(c:c eq 'DynamicMembership')" }
                "DynamicSecurityExcludeM365" = { Get-MgGroup -Filter "SecurityEnabled eq true and groupTypes/any(c:c eq 'DynamicMembership')" }
                "AllGroups"                  = {
                    # Fetch both standard and dynamic groups in a single call and combine the results
                    $allGroups = Get-MgGroup -All
                    $dynamicGroups = Get-DynamicDistributionGroup -ResultSize Unlimited
                    $allGroups + $dynamicGroups
                }
            }
    
            try {
                if ($groupTypeMap.ContainsKey($GroupType)) {
                    # Execute the corresponding script block from the lookup table
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


        function Group-MembershipReport {
            param (
                [Object]$Group,
                [Object[]]$GroupMembers,
                [switch]$ExpandedReport
            )
        
            # Helper function to simplify owner information retrieval
            function Get-OwnerInfo {
                param (
                    [Object]$Group
                )
        
                # Determine the group ID, prioritize 'ExternalDirectoryObjectId' if available
                $groupId = if ($group.PSObject.Properties.Name -contains "ExternalDirectoryObjectId") { $group.ExternalDirectoryObjectId } else { $group.Id }
        
        
                if ($group.PSObject.Properties.Name -contains "ManagedBy") {
                    if ($Group.ManagedBy.Count -ne 0) {
                        $ownerInfo = $Group.ManagedBy | Where-Object { $_ -ne "Organization Management" } | ForEach-Object { Get-Recipient $_ }
                        return @{
                            OwnerEmail = $ownerInfo.PrimarySmtpAddress -join ","
                            OwnerName  = $ownerInfo.DisplayName -join ","
                        }
                    }
                    else {
                        return @{
                            OwnerEmail = "No Owners"
                            OwnerName  = "No Owners"
                        }
                    }
                }
                else {
                    try {
                        $ownerInfo = (Get-MgGroupOwner -GroupId $groupId).AdditionalProperties
                        return @{
                            OwnerEmail = if ($ownerInfo.Count -ne 0) { $ownerInfo.mail -join "," } else { "No Owners" }
                            OwnerName  = if ($ownerInfo.Count -ne 0) { $ownerInfo.displayName -join "," } else { "No Owners" }
                        }
                    }
                    catch {
                        Write-Warning "Failed to retrieve owner information for group: $($group.DisplayName). Error: $_"
                        return @{
                            OwnerEmail = "Error retrieving owners"
                            OwnerName  = "Error retrieving owners"
                        }
                    }
                }
            }
        
            # Helper function to determine group type
            function Get-GroupTypeInfo {
                param (
                    [Object]$Group
                )
        
                if ($group.PSObject.Properties.Name -contains "RecipientTypeDetails") {
                    return $Group.RecipientTypeDetails
                }
                else {
                    $groupTypes = $group.GroupTypes
                    $containsUnified = $groupTypes -contains "Unified"
                    $containsDynamic = $groupTypes -contains "DynamicMembership"
                    $isMailEnabled = $Group.MailEnabled
                    $isSecurityEnabled = $Group.SecurityEnabled
        
                    if (-not $groupTypes) {
                        if ($isMailEnabled) {
                            return if ($isSecurityEnabled) { "Mail Security Group" } else { "Distribution Group" }
                        }
                        else {
                            return "Security Group"
                        }
                    }
                    else {
                        if ($isSecurityEnabled) {
                            if ($containsUnified -and $containsDynamic) {
                                return "Dynamic M365 Security Group"
                            }
                            elseif ($containsUnified) {
                                return "M365 Security Group"
                            }
                            elseif ($containsDynamic) {
                                return "Dynamic Security Group"
                            }
                            else {
                                return "Security Group"
                            }
                        }
                        else {
                            if ($containsUnified -and $containsDynamic) {
                                return "Dynamic M365 Group"
                            }
                            elseif ($containsUnified) {
                                return "M365 Group"
                            }
                            elseif ($containsDynamic) {
                                return "Dynamic Group"
                            }
                            else {
                                return "Security Group"
                            }
                        }
                    }
                }
            }
        
            # Get owner information
            $ownerInfo = Get-OwnerInfo -Group $Group
            $OwnerEmail = $ownerInfo.OwnerEmail
            $OwnerName = $ownerInfo.OwnerName
        
            # Get group email address
            $GroupEmail = if ($group.PSObject.Properties.Name -contains "PrimarySMTPAddress") {
                $Group.PrimarySMTPAddress
            }
            else {
                $Group.Mail
            }
        
            # Get group type
            $GroupTypeInfo = Get-GroupTypeInfo -Group $Group
        
            # Process the group members
            if ($ExpandedReport -and $GroupMembers.Count -gt 1) {
                $members = $groupMembers | ForEach-Object {
                    $memberName = if ($_.AdditionalProperties) { ($_.AdditionalProperties).displayName } else { $_.displayName }
                    $memberEmail = if ($_.AdditionalProperties) { ($_.AdditionalProperties).mail } else { $_.PrimarySMTPAddress }
        
                    [PSCustomObject]@{
                        GroupName   = $group.DisplayName
                        GroupEmail  = $GroupEmail
                        OwnerName   = $OwnerName
                        OwnerEmail  = $OwnerEmail
                        MemberName  = $memberName
                        MemberEmail = $memberEmail
                        GroupType   = $GroupTypeInfo
                    }
                }
            }
            else {
                if ($null -eq $GroupMembers -or $GroupMembers.Count -eq 0) {
                    $memberName = "No Members"
                    $memberEmail = "No Members"
                }
                elseif ($GroupMembers.RecipientType) {
                    $memberName = $GroupMembers.displayName -join ","
                    $memberEmail = $GroupMembers.PrimarySMTPAddress -join ","
                }
                else {
                    $memberName = ($GroupMembers.AdditionalProperties).displayName -join ","
                    $memberEmail = ($GroupMembers.AdditionalProperties).mail -join ","
                }
        
                $members = [PSCustomObject]@{
                    GroupName   = $group.DisplayName
                    GroupEmail  = $GroupEmail
                    OwnerName   = $OwnerName
                    OwnerEmail  = $OwnerEmail
                    MemberName  = $memberName
                    MemberEmail = $memberEmail
                    GroupType   = $GroupTypeInfo
                }
            }
        
            return $members
        }

        # Helper function to retrieve group members based on the group type
        function Get-GroupMembers {
            param (
                [object]$Group,
                [ValidateSet(
                    "DistributionGroupOnly", "MailSecurityGroupOnly", "AllDistributionGroup", "DynamicDistributionGroup", "M365GroupOnly", "AllSecurityGroup",
                    "NonMailSecurityGroup", "SecurityGroupExcludeM365", "M365SecurityGroup", "DynamicSecurityGroup", "DynamicSecurityExcludeM365", "AllGroups"
                )]
                $GroupType
            )

        
            # Determine the group ID, prioritize 'ExternalDirectoryObjectId' if available
            $groupId = if ($Group.ExternalDirectoryObjectId) { $Group.ExternalDirectoryObjectId } else { $Group.Id }
    
            # Define a lookup table for GroupType and their corresponding commands
            $groupTypeMap = @{
                "DistributionGroupOnly"      = { Get-DistributionGroupMember -Identity $groupId -ResultSize Unlimited -ErrorAction SilentlyContinue }
                "MailSecurityGroupOnly"      = { Get-DistributionGroupMember -Identity $groupId -ResultSize Unlimited -ErrorAction SilentlyContinue }
                "AllDistributionGroup"       = { Get-DistributionGroupMember -Identity $groupId -ResultSize Unlimited -ErrorAction SilentlyContinue }
                "DynamicDistributionGroup"   = { Get-DynamicDistributionGroupMember -Identity $groupId -ResultSize Unlimited -ErrorAction SilentlyContinue }
                "M365GroupOnly"              = { Get-MgGroupMember -GroupId $groupId -All }
                "AllSecurityGroup"           = { Get-MgGroupMember -GroupId $groupId -All }
                "NonMailSecurityGroup"       = { Get-MgGroupMember -GroupId $groupId -All }
                "SecurityGroupExcludeM365"   = { Get-MgGroupMember -GroupId $groupId -All }
                "M365SecurityGroup"          = { Get-MgGroupMember -GroupId $groupId -All }
                "DynamicSecurityGroup"       = { Get-MgGroupMember -GroupId $groupId -All }
                "DynamicSecurityExcludeM365" = { Get-MgGroupMember -GroupId $groupId -All }
                "AllGroups"                  = {
                    if ($Group.ExternalDirectoryObjectId) {
                        Get-DynamicDistributionGroupMember -Identity $groupId -ResultSize Unlimited  -ErrorAction SilentlyContinue
                    }
                    else {
                        Get-MgGroupMember -GroupId $groupId -All
                    }
                }
            }
    
            try {
                if ($groupTypeMap.ContainsKey($GroupType)) {
                    # Execute the corresponding script block from the lookup table
                    return & $groupTypeMap[$GroupType]
                }
                else {
                    throw "Unknown group type: $GroupType"
                }
            }
            catch {
                Write-Host "Error occurred while fetching members for group '$groupId' and type '$GroupType': $_"
                throw $_
            }
        }


        # Helper function to process groups and retrieve members
        function Invoke-Groups {
            param (
                [Parameter(Mandatory = $true)]
                [array]$Groups,

                [Parameter(Mandatory = $true)]
                [string]$GroupType,

                [ref]$AllGroupMembers, # Pass by reference to modify the original list
                [switch]$ExpandedReport
            )


            $groupCount = $Groups.Count
            $groupProcessed = 0

            foreach ($group in $Groups) {
                $groupProcessed += 1

                # Processing progress
                Write-Verbose "Retrieving members for group: $($group.DisplayName)"
                if ($groupProcessed % 50 -eq 0 -or $groupProcessed -eq $groupCount) {
                    Write-Host $("Processed $groupProcessed of $groupCount groups")
                }

            
                # Retrieve members of the current group
                $groupMembers = Get-GroupMembers -Group $group -GroupType $GroupType
        
                # Process each group member and add to the list
                $groupMembersProcessed = if ($ExpandedReport) {
                    Group-MembershipReport -Group $group -GroupMembers $groupMembers -ExpandedReport
                }
                else {
                    Group-MembershipReport -Group $group -GroupMembers $groupMembers
                }
                if ($groupMembersProcessed -is [System.Collections.IEnumerable] -and $groupMembersProcessed -isnot [string]) {
                    $AllGroupMembers.Value.AddRange($groupMembersProcessed)
                }
                else {
                    $AllGroupMembers.Value.Add($groupMembersProcessed)
                }
            }
            return $AllGroupMembers.Value
        }
    }


    process {

        # Standard processing for earlier versions of PowerShell

        $groups = Get-GroupDetails -GroupType $GroupType
        $allGroupMembers = New-Object System.Collections.Generic.List[Object]
        

        Write-Host "Processing all groups and Retrieving members for group type: $($GroupType)"
        
        # Use the helper function for sequential processing
        $allGroupMembers = if ($ExpandedReport) {
            Invoke-Groups -Groups $groups -GroupType $GroupType -AllGroupMembers ([ref]$allGroupMembers) -ExpandedReport
        }
        else {
            Invoke-Groups -Groups $groups -GroupType $GroupType -AllGroupMembers ([ref]$allGroupMembers)
        }
    
    }
    end {
        $directory = [System.IO.Path]::GetDirectoryName($ReportPath)
        $fileName = [System.IO.Path]::GetFileNameWithoutExtension($ReportPath)
        $ReportPath = [System.IO.Path]::Combine($directory, "$($fileName)_$($GroupType).csv")

        try {
            if ($GroupSummaryReport) {
                $GSRPath = [System.IO.Path]::Combine($directory, "$($GroupType)_GroupSummaryReport.csv")
                Export-ReportCsv -ReportPath $GSRPath -ReportData $groups
            }
            # Try exporting using the custom Export-ReportCsv function
            $allGroupMembers | Export-ReportCsv -ReportPath $ReportPath
        }
        catch {
            # If Export-ReportCsv fails, use the default export function
            Write-Warning "Custom export failed. Falling back to default export function."
            try {
                # Export using the default Export-Csv function
                $allGroupMembers | Export-Csv -Path $ReportPath -NoTypeInformation
                Write-Host "Report saved to: $ReportPath using default export function."
            }
            catch {
                # Handle failure of the default export function
                Write-Error "Failed to save the report using both custom and default export functions: $_"
            }
        }
        
    }
}