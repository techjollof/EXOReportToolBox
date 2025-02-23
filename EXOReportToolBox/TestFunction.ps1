
[CmdletBinding()]
param (
    [ValidateSet(
        "DistributionGroupOnly", "AllDistributionGroup", "MailSecurityGroupOnly", "DynamicDistributionGroup", "M365GroupOnly", "AllSecurityGroup",
        "NonMailSecurityGroup", "SecurityGroupExcludeM365", "SecurityGroupM365", "DynamicSecurityGroup", "DynamicSecurityExcludeM365","AllGroups"
    )]
    $GroupType
)

Write-Host "Retrieving group details for $GroupType..."
try {
    switch ($GroupType) {
            
        "DistributionGroupOnly" { Get-DistributionGroup -RecipientTypeDetails MailUniversalDistributionGroup -ResultSize Unlimited }
        "AllDistributionGroup" { Get-DistributionGroup -ResultSize Unlimited }
        "MailSecurityGroupOnly" { Get-DistributionGroup -RecipientTypeDetails MailUniversalSecurityGroup -ResultSize Unlimited }
        "DynamicDistributionGroup" { Get-DynamicDistributionGroup -ResultSize Unlimited }
        "M365GroupOnly" { Get-MgGroup -Filter "groupTypes/any(c:c eq 'Unified')" }
        "AllSecurityGroup" { Get-MgGroup -Filter "SecurityEnabled eq true" }
        "NonMailSecurityGroup" { Get-MgGroup -Filter "SecurityEnabled eq true and MailEnabled eq false" }
        "SecurityGroupExcludeM365" { Get-MgGroup -Filter "SecurityEnabled eq true" | Where-Object { "Unified" -notin $_.GroupTypes } }
        "SecurityGroupM365" { Get-MgGraph -Filter "SecurityEnabled eq true and groupTypes/any(c:c eq 'Unified')" }
        "DynamicSecurityGroup" { Get-MgGroup -Filter "groupTypes/any(c:c eq 'DynamicMembership')" }
        "DynamicSecurityExcludeM365" { Get-MgGroup -Filter "SecurityEnabled eq true and groupTypes/any(c:c eq 'DynamicMembership')" }
        default { throw "Unknown group type: $GroupType" }
    }
}
catch {
    Write-Host "Error occurred while fetching groups for type '$GroupType': $_"
    throw $_
}