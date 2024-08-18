function Retrive-UnifiedAuditLogReport.ps1 {
    param (
        [string[]]$Records,
        [string]$OutputFilename = "output.csv"
    )

    $parsedRecords = @()

    foreach ($data in $Records) {
        $parsedData = @{}

        $lines = $data.Trim() -split "`n"

        foreach ($line in $lines) {
            if ($line -match "^\s*(\w+)\s*:\s*(.*)\s*$") {
                $key = $matches[1]
                $value = $matches[2].Trim()

                if ($key -eq "AuditData") {
                    $auditData = $value | ConvertFrom-Json
                    foreach ($auditKey in $auditData.PSObject.Properties.Name) {
                        $parsedData["AuditData_$auditKey"] = $auditData.$auditKey
                    }
                } else {
                    $parsedData[$key] = $value
                }
            }
        }

        $parsedRecords += New-Object PSObject -Property $parsedData
    }

    $parsedRecords | Export-Csv -Path $OutputFilename -NoTypeInformation
    Write-Output "Data has been written to $OutputFilename"
}

# Call the function with the $data array
Parse-AndWriteToCSV -Records $ll
