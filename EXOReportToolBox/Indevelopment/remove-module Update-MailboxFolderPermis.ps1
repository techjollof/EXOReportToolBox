remove-module Update-MailboxFolderPermissionReport -Force
import-module .\Functions\Update-MailboxFolderPermissionReport.ps1 -Force
Update-MailboxFolderPermissionReport -DelagatorMailbox AddresBook@ithero.work.gd  -DelagateMailbox sqlcplt@techjollof.net -AccessRights Editor -TargetFolder \Top3\TEAMS\AzureAD 
