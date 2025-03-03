
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

# Cache expensive property lookups (avoid repeated access to properties)
$recipientTypeDetails = $Group.RecipientTypeDetails
$groupTypes = $Group.GroupTypes
$isMailEnabled = $Group.MailEnabled
$isSecurityEnabled = $Group.SecurityEnabled
$containsUnified = $groupTypes -contains "Unified"
$containsDynamic = $groupTypes -contains "DynamicMembership"

# Use hash table lookup with for better performance
if ($recipientTypeDetails -and $recipientTypeMap.ContainsKey($recipientTypeDetails)) {
    return $recipientTypeMap[$recipientTypeDetails]  # Return the value if the key exists
}
else {
    # Process other group types if not found in RecipientTypeDetails
    if (-not $groupTypes) {
        if ($isMailEnabled) { if ($isSecurityEnabled) { "Mail Security Group" } else { "Distribution Group" } } else { "Security Group" }
    }

    if ($isSecurityEnabled) {
        if ($containsUnified -and $containsDynamic) { "Dynamic M365 Security Group" }
        elseif ($containsUnified) { "M365 Security Group" }
        elseif ($containsDynamic) { "Dynamic Security Group" }
        else { "Security Group" }
    }

    if ($containsUnified -and $containsDynamic) { "Dynamic M365 Group" }
    elseif ($containsUnified) { "M365 Group" }
    elseif ($containsDynamic) { "Dynamic Group" }
    else { "Security Group" }
}
# }
