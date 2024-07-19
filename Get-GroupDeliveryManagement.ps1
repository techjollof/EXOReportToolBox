$User = Get-Mailbox "it@itpro.work.gd"
Get-DistributionGroup | Where-Object { 
    $_.AcceptMessagesOnlyFrom -ne $null -and $_.AcceptMessagesOnlyFrom -contains $User.Name
} | Select DisplayName, PrimarySMTPAddress | Export-csv $("$Home\Downloads\"+$User.DisplayName+"_assigned_dm.csv" -replace(" ","_")) -NoTypeInformation



$Result = @()
$AllDLs = Get-DistributionGroup | Where-Object { $_.AcceptMessagesOnlyFrom -ne $null} 
$AllDLs | % {
    $dl = $_
    $users = $dl.AcceptMessagesOnlyFrom | Get-Recipient | Select Displ*, Prim*

    $Result +=[PSCustomObject]@{

        DLName = $dl.DisplayName
        DLEmail = $dl.PrimarySMTPAddress
        UserName = $users.DisplayName -join ","
        UserEmail = $Users.PrimarySMTPAddress -join ","
    }
} 

$Result | Export-csv $Home\Downloads\AllDLs_with_directly_assigned_dm.csv -NoTypeInformation


