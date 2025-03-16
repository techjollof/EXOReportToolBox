function Load-AuditLogData {
    param ([object]$DataInput)



    if ($DataInput -is [string] -and (Test-Path $DataInput)) {
        $ParsedDataInput = Import-Csv -Path $DataInput
    }
    elseif ($DataInput -is [System.Collections.IEnumerable]) {
        $ParsedDataInput = $DataInput
    }
    else {
        Write-Host "Invalid input! Provide a valid CSV file path or in-memory data."
        exit
    }

    $logDataArray = @()
    $totalCount = $ParsedDataInput.Count
    $currentCount = 0

    $ParsedDataInput | ForEach-Object {
        
        if ($_.PSObject.Properties.Name -contains "AuditData") {
            try {
                if ($_.AuditData -is [string] -and $_.AuditData.Trim() -ne "") {
                    $_ | Add-Member -MemberType NoteProperty -Name "AuditData" -Value (ConvertFrom-Json $_.AuditData) -Force
                }
            }
            catch {
                Write-Warning "Failed to parse AuditData JSON for entry at index $currentCount"
                $_ | Add-Member -MemberType NoteProperty -Name "AuditData" -Value $null -Force
            }
        }
        
        $logDataArray += $_
    }

    return $logDataArray
}
