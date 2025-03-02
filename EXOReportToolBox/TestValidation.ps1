if ($PSVersionTable.PSVersion.Major -ge 7) {
    Write-Host "Running on PowerShell 7 or later, using parallel processing."
    
    # Retrieve group details based on the provided group type
    $groups = Get-GroupDetails -GroupType $GroupType
    $allGroupMembers = New-Object System.Collections.Generic.List[Object]

    # Import the function to the parallel task (Make sure Invoke-Groups is defined)
    $InvokeGroupFunction = ${Function:Invoke-Groups}.ToString()
    $InvokeGroupMembers = ${Function:Get-GroupMembers}.ToString()
    $InvokeProcessGroupMembers = ${Function:ProcessGroupMembers}.ToString()

    #External function to retrieve members of a distribution group
    $InvokeGetDistributionGroupMember = ${Function:Get-DistributionGroupMember}.ToString()
    $InvokeGetRecipient = ${Function:Get-Recipient}.ToString()

    Write-Host "Processing all groups and retrieving members for group type: $($GroupType)"
    
    # Process each group in parallel
    $groups[0..3] | ForEach-Object -Parallel {

        $group = $_
        
        write-host "Processing group: $($group.DisplayName) :  $using:GroupType"
        
        # Use the $using: to reference external variables and functions
        ${Function:Invoke-Groups} = $using:InvokeGroupFunction
        ${Function:Get-GroupMembers} = $using:InvokeGroupMembers
        ${Function:ProcessGroupMembers} = $using:InvokeProcessGroupMembers

        # External functions
        ${Function:Get-DistributionGroupMember} = $using:InvokeGetDistributionGroupMember
        ${Function:Get-Recipient} = $using:InvokeGetRecipient
        
        # Retrieve members for this group using the helper function
        $groupMembers = Invoke-Groups -Groups $group -GroupType $using:GroupType

        $groupMembers
    
        # Return the group members for this specific group
        return $groupMembers
    }  | ForEach-Object {
        # Collect the results from parallel tasks and add them to the allGroupMembers list
        $allGroupMembers.Add($_)
    }
    
    # Return the collection of all group members
    Write-Host "Total members retrieved: $($allGroupMembers.Count)"
    return $allGroupMembers
}

else {