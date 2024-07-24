<#
.SYNOPSIS
    Short description
.DESCRIPTION
    Long description
.EXAMPLE
    Example of how to use this cmdlet
.EXAMPLE
    Another example of how to use this cmdlet
#>
function Get-GroupDeliveryManagementReport {
    [CmdletBinding()]
    [OutputType([type])]
    param(
        # group options
        [Parameter()]
        [ValidateSet("MailDistributionGroup", "MailSecurityGroup","M365Groups","DynamicGroups","AllDLs")]
        $GroupType = "AllDLs",

        # Size
        [Parameter()]
        [string]
        $ResultSize ="Unlimited"
    )
    
    process {
            
        $Result = @()
        $getGroup = switch ($GroupType) {
            "MailDistributionGroup" { Get-DistributionGroup -RecipientTypeDetails MailUniversalDistributionGroup -ResultSize Unlimited | Where-Object { $null -ne $_.AcceptMessagesOnlyFrom} }
            "MailSecurityGroup" {Get-DistributionGroup -RecipientTypeDetails MailUniversalSecurityGroup -ResultSize Unlimited | Where-Object { $null -ne $_.AcceptMessagesOnlyFrom}}
            "M365Groups" {Get-UnifiedGroup -ResultSize Unlimited | Where-Object { $null -ne $_.AcceptMessagesOnlyFrom}}
            "DynamicGroups" {Get-DynamicDistributionGroup -ResultSize  | Where-Object { $null -ne $_.AcceptMessagesOnlyFrom}}
            Default {Get-DistributionGroup -ResultSize Unlimited | Where-Object { $null -ne $_.AcceptMessagesOnlyFrom}}
        }
        

        $getGroup | ForEach-Object {
            $dl = $_
            $users = $dl.AcceptMessagesOnlyFrom | ForEach-Object {
                Get-Recipient -ResultSize Unlimited | Select-Object Displ*, Prim*
            }

            $Result +=[PSCustomObject]@{

                DLName = $dl.DisplayName
                DLEmail = $dl.PrimarySMTPAddress
                UserName = $users.DisplayName -join ","
                UserEmail = $Users.PrimarySMTPAddress -join ","
            }
        } 

        $Result #| Export-csv $Home\Downloads\AllDLs_with_directly_assigned_dm.csv -NoTypeInformation        
    }
}