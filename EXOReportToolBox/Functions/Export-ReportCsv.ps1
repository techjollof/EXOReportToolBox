Function Export-ReportCsv {
    <#
    .SYNOPSIS
        Exports report data to a CSV file with the current date and time appended to the filename.
    
    .DESCRIPTION
        This script exports the provided report data to a CSV file. The filename is appended with the current date and time to ensure uniqueness and prevent overwriting existing files.
    
    .PARAMETER ReportPath
        The path where the CSV file will be saved. The directory will be created if it does not exist.
    
    .PARAMETER ReportData
        The data to be exported to the CSV file. It should be an array of objects. This parameter accepts pipeline input.
    
    .EXAMPLE
        $reportData = @(
            [PSCustomObject]@{ Name = "John Doe"; Age = 30; Position = "Developer" },
            [PSCustomObject]@{ Name = "Jane Smith"; Age = 25; Position = "Designer" }
        )
        $ReportPath = "/path/to/reports/EmployeeReport.csv"
        Export-ReportCsv -ReportPath $ReportPath -ReportData $reportData
    
        This example exports the report data to a CSV file named "EmployeeReport_20240723_153045.csv" in the specified directory.
    
    .EXAMPLE
        $reportData = @(
            [PSCustomObject]@{ Name = "Alice Johnson"; Age = 35; Position = "Manager" },
            [PSCustomObject]@{ Name = "Bob Brown"; Age = 28; Position = "Analyst" }
        )
        $ReportPath = "C:\Reports\StaffReport.csv"
        Export-ReportCsv -ReportPath $ReportPath -ReportData $reportData
    
        This example exports the report data to a CSV file named "StaffReport_20240723_153045.csv" in the specified directory.
    
    .EXAMPLE
        $reportData = @(
            [PSCustomObject]@{ Name = "Alice Johnson"; Age = 35; Position = "Manager" },
            [PSCustomObject]@{ Name = "Bob Brown"; Age = 28; Position = "Analyst" }
        )
        $reportData | Export-ReportCsv -ReportPath "C:\Reports\StaffReport.csv"
    
        This example demonstrates pipeline input. The report data is piped into the function.
    #>
    [CmdletBinding()]
    param (
        [Parameter(Mandatory = $true)]
        [string] $ReportPath,

        [Parameter(Mandatory = $true, ValueFromPipeline = $true)]
        $ReportData
    )

    begin {
        # Initialize a list to collect pipeline input
        $collectedData = @()
    }

    process {
        # Collect pipeline input
        $collectedData += $ReportData
    }

    end {
        try {
            # Get current date and time
            $currentDateTime = Get-Date -Format "yyyy_MM_dd_HH_mm"

            # Split the file path into directory, filename, and extension
            $directory = [System.IO.Path]::GetDirectoryName($ReportPath)
            $filename = [System.IO.Path]::GetFileNameWithoutExtension($ReportPath)
            $extension = [System.IO.Path]::GetExtension($ReportPath)

            # If no directory is provided, default to the user's Downloads folder
            if ([string]::IsNullOrEmpty($directory)) {
                $directory = [System.IO.Path]::Combine($HOME, "Downloads")
            }

            # If no extension is provided, default to .csv
            if ([string]::IsNullOrEmpty($extension)) {
                $extension = ".csv"
            }

            # Construct the new file path
            $newFilePath = [System.IO.Path]::Combine($directory, "${filename}_${currentDateTime}${extension}")

            # Ensure the directory exists
            if (-not (Test-Path -Path $directory)) {
                New-Item -Path $directory -ItemType Directory -Force | Out-Null
            }

            # Export to CSV
            $collectedData | Export-Csv -Path $newFilePath -NoTypeInformation

            Write-Host "Report saved to: $newFilePath"
        }
        catch {
            Write-Error "Failed to export report: $_"
        }
    }
}