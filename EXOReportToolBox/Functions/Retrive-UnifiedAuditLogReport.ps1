function Parse-AndWriteToCSV {
    param (
        [PSObject[]]$Records,
        [string]$OutputFilename = "output.csv"
    )

    # Helper function to recursively expand JSON objects
    function Expand-JsonObject {
        param (
            [Parameter(Mandatory = $true)]
            [psobject]$JsonObject,
            [string]$Prefix = ""
        )

        $expanded = @{}

        foreach ($property in $JsonObject.PSObject.Properties) {
            $key = if ($Prefix) { "$Prefix`_$($property.Name)" } else { $property.Name }
            if ($property.Value -is [System.Management.Automation.PSObject] -and $property.Value.PSObject.Properties.Count -gt 0) {
                # If the property value is a nested object
                $expanded += Expand-JsonObject -JsonObject $property.Value -Prefix $key
            } elseif ($property.Value -is [System.Collections.IList]) {
                # Handle arrays
                $i = 0
                foreach ($item in $property.Value) {
                    if ($item -is [System.Management.Automation.PSObject]) {
                        $expanded += Expand-JsonObject -JsonObject $item -Prefix "$key`_$i"
                    } else {
                        $expanded["$key`_$i"] = $item
                    }
                    $i++
                }
            } else {
                # Simple property
                $expanded[$key] = $property.Value
            }
        }

        return $expanded
    }

    # Array to store the parsed records
    $parsedRecords = @()

    foreach ($record in $Records) {
        $parsedData = @{}

        # Directly access each property of the PSObject
        $parsedData['RecordType'] = $record.RecordType
        $parsedData['CreationDate'] = $record.CreationDate
        $parsedData['UserIds'] = $record.UserIds
        $parsedData['Operations'] = $record.Operations
        $parsedData['ResultIndex'] = $record.ResultIndex
        $parsedData['ResultCount'] = $record.ResultCount
        $parsedData['Identity'] = $record.Identity
        $parsedData['IsValid'] = $record.IsValid
        $parsedData['ObjectState'] = $record.ObjectState

        # Handle the AuditData JSON separately if it exists
        if ($record.AuditData) {
            try {
                $auditData = $record.AuditData | ConvertFrom-Json
                $expandedAuditData = Expand-JsonObject -JsonObject $auditData
                foreach ($auditKey in $expandedAuditData.Keys) {
                    $parsedData[$auditKey] = $expandedAuditData[$auditKey]
                }
            } catch {
                Write-Warning "Failed to parse AuditData for record with Identity $($record.Identity)"
            }
        }

        $parsedRecords += New-Object PSObject -Property $parsedData
    }

    # Export the parsed records to a CSV file
    $parsedRecords | Export-Csv -Path $OutputFilename -NoTypeInformation
    Write-Output "Data has been written to $OutputFilename"
}

# Example usage


# Call the function
Parse-AndWriteToCSV -Records $data -OutputFilename "output.csv"
