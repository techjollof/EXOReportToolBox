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
                "AllDistributionGroup"       = { Get-DistributionGroup -ResultSize Unlimited   -ErrorAction SilentlyContinue}
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

            $members = @()
            # Determine the group ID, prioritize 'ExternalDirectoryObjectId' if available
            $groupId = if ($group.PSObject.Properties.Name -contains "ExternalDirectoryObjectId") { $group.ExternalDirectoryObjectId } else { $group.Id }

            # Get the owner information and group email addresses depending to the group type or command source, EXO or Graph
            if ($group.PSObject.Properties.Name -contains "ManagedBy") {
                $OwnerInfo = if ($Group.ManagedBy.count -ne 0) { $Group.ManagedBy | ForEach-Object { Get-Recipient $_ } } else { $null }
                $OwnerEmail = if ($OwnerInfo.count -ne 0) { $OwnerInfo.PrimarySmtpAddress -join "," } else { "No Owners" }
                $OwnerName = if ($OwnerInfo.count -ne 0) { $OwnerInfo.DisplayName -join "," } else { "No Owners" }
            }
            else {
                try {
                    # Attempt to get the group owners via Microsoft Graph and If owners are found, retrieve their details
                    $OwnerInfo = (Get-MgGroupOwner -GroupId $groupId).AdditionalProperties
                
                    $OwnerEmail = if ($OwnerInfo.count -ne 0) { $OwnerInfo.mail -join "," } else { "No Owners" }
                    $OwnerName = if ($OwnerInfo.count -ne 0) { $OwnerInfo.displayName -join "," } else { "No Owners" }
                }
                catch {
                    # Handle errors (e.g., group not found or inaccessible)
                    Write-Warning "Failed to retrieve owner information for group: $($group.DisplayName). Error: $_"
                    $OwnerEmail = "Error retrieving owners"
                    $OwnerName = "Error retrieving owners"
                }
            }

            # Get group email address
            $GroupEmail = if ($group.PSObject.Properties.Name -contains "PrimarySMTPAddress") {
                $Group.PrimarySMTPAddress
            }
            else {
                $Group.Mail
            }

            #get the group type
            
            $GroupTypeInfo = if ($group.PSObject.Properties.Name -contains "RecipientTypeDetails") {
                $Group.RecipientTypeDetails
            }
            else {
                # Check if GroupTypes exists and has relevant entries
                $groupTypes = $group.GroupTypes
                $containsUnified = $groupTypes -contains "Unified"
                $containsDynamic = $groupTypes -contains "DynamicMembership"
            
                # Determine if the group is mail-enabled and security-enabled
                $isMailEnabled = $Group.MailEnabled
                $isSecurityEnabled = $Group.SecurityEnabled
            
                if (-not $groupTypes) {
                    # Simplified logic for MailEnabled and SecurityEnabled combinations
                    if ($isMailEnabled) {
                        if ($isSecurityEnabled) {
                            "Mail Security Group"
                        }
                        else {
                            "Distribution Group"
                        }
                    }
                    else {
                        "Security Group"
                    }
                }
                else {
                    # Determine the type of group based on Unified and Dynamic membership
                    if ($isSecurityEnabled) {
                        if ($containsUnified -and $containsDynamic) {
                            "Dynamic M365 Security Group"
                        }
                        elseif ($containsUnified) {
                            "M365 Security Group"
                        }
                        elseif ($containsDynamic) {
                            "Dynamic Security Group"
                        }
                        else {
                            "Security Group"
                        }
                    }
                    else {
                        if ($containsUnified -and $containsDynamic) {
                            "Dynamic M365 Group"
                        }
                        elseif ($containsUnified) {
                            "M365 Group"
                        }
                        elseif ($containsDynamic) {
                            "Dynamic Group"
                        }
                        else {
                            "Standard Group"
                        }
                    }
                }
            }


            # Process the group members
            if ($ExpandedReport -and $GroupMembers.Count -gt 1) {
                $members = $groupMembers | ForEach-Object {

                    if ($_.AdditionalProperties) {
                        $memberName = ($_.AdditionalProperties).displayName 
                        $memberEmail = ($_.AdditionalProperties).mail
                    }
                    else {
                        $memberName = $_.displayName 
                        $memberEmail = $_.PrimarySMTPAddress
                    }

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
                # Default report: handle cases with no members
                if ($null -eq $GroupMembers -or $GroupMembers.Count -eq 0) { 
                    # write-host "1 GroupMembers: $($GroupMembers.count)"
                    $memberName = "No Members"
                    $memberEmail = "No Members"
                } 
                elseif ($GroupMembers.RecicpientType) {
                    # write-host "2 GroupMembers: $($GroupMembers.count)"
                    $memberName = $GroupMembers.displayName -join "," 
                    $memberEmail = $GroupMembers.PrimarySMTPAddress -join ","
                }
                else {
                    # write-host "3 GroupMembers: $($GroupMembers.count)"                
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
                "DistributionGroupOnly"      = { Get-DistributionGroupMember -Identity $groupId -ResultSize Unlimited -ErrorAction SilentlyContinue}
                "MailSecurityGroupOnly"      = { Get-DistributionGroupMember -Identity $groupId -ResultSize Unlimited -ErrorAction SilentlyContinue}
                "AllDistributionGroup"       = { Get-DistributionGroupMember -Identity $groupId -ResultSize Unlimited -ErrorAction SilentlyContinue}
                "DynamicDistributionGroup"   = { Get-DynamicDistributionGroupMember -Identity $groupId -ResultSize Unlimited -ErrorAction SilentlyContinue}
                "M365GroupOnly"              = { Get-MgGroupMember -GroupId $groupId -All }
                "AllSecurityGroup"           = { Get-MgGroupMember -GroupId $groupId -All }
                "NonMailSecurityGroup"       = { Get-MgGroupMember -GroupId $groupId -All }
                "SecurityGroupExcludeM365"   = { Get-MgGroupMember -GroupId $groupId -All }
                "M365SecurityGroup"          = { Get-MgGroupMember -GroupId $groupId -All }
                "DynamicSecurityGroup"       = { Get-MgGroupMember -GroupId $groupId -All }
                "DynamicSecurityExcludeM365" = { Get-MgGroupMember -GroupId $groupId -All }
                "AllGroups"                  = {
                    if ($Group.ExternalDirectoryObjectId) {
                        Get-DynamicDistributionGroupMember -Identity $groupId -ResultSize Unlimited
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

                [ref]$AllGroupMembers,  # Pass by reference to modify the original list
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
        $allGroupMembers = if ($ExpandedReport){
            Invoke-Groups -Groups $groups -GroupType $GroupType -AllGroupMembers ([ref]$allGroupMembers) -ExpandedReport
        }
        else {
            Invoke-Groups -Groups $groups -GroupType $GroupType -AllGroupMembers ([ref]$allGroupMembers)
        }

        # Return the collection of all group members
        # return $allGroupMembers
    
    }
    end {
        Write-Host "Exported file of the groups completed, save to: $ReportPath"
        if ($GroupSummaryReport) {
            Export-ReportCsv -ReportPath "SummaryReportGroupType $ReportPath" -ReportData $groups
        }
        Export-ReportCsv -ReportPath $ReportPath -ReportData $allGroupMembers
    }

    
}