$Result=@()
$allMailboxes = Get-Mailbox -ResultSize 2 | Select-Object -Property Displayname,PrimarySMTPAddress
$totalMailboxes = $allMailboxes.Count
$i = 1 
$allMailboxes | ForEach-Object {
$mailbox = $_
Write-Progress -activity "Processing $($_.Displayname)" -status "$i out of $totalMailboxes completed"
    $folderPerms = Get-MailboxFolderPermission -Identity "$($_.PrimarySMTPAddress):\Calendar"
    $folderPerms | ForEach-Object {
        
        $Result +=[PSCustomObject]@{

            MailboxName = $mailbox.DisplayName
            MailboxEmail = $mailbox.PrimarySMTPAddress
            FolderName = $_.FolderName
            User = $_.User
            Permissions = $_.AccessRights -join ","
        }
   
    $i++
    }
}
$Result
