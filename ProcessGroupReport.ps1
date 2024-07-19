function ProcessGroupMembers {
        param (
            [string]$reportType,
            $group,
            $groupMembers
        )
    
        $members = @()
    
        switch ($reportType) {
            "Expanded" {
                foreach ($member in $groupMembers) {
                    $members += [PSCustomObject]@{
                        GroupName = $group.DisplayName
                        GroupEmail = $group.PrimarySMTPAddress
                        MemberName = $member.DisplayName
                        MemberEmail = $member.PrimarySmtpAddress
                    }
                }
            }
            default {
                $members += [PSCustomObject]@{
                    GroupName = $group.DisplayName
                    GroupEmail = $group.PrimarySMTPAddress
                    MemberName = $groupMembers.DisplayName -join ","
                    MemberEmail = $groupMembers.PrimarySmtpAddress -join ","
                }
            }
        }
    
        return $members
    }
