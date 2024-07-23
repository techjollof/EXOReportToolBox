<#
.SYNOPSIS
    Exports report data to a CSV file with the current date and time appended to the filename.

.DESCRIPTION
    This script exports the provided report data to a CSV file. The filename is appended with the current date and time to ensure uniqueness and prevent overwriting existing files.

.PARAMETER FilePath
    The path where the CSV file will be saved. The directory will be created if it does not exist.

.PARAMETER ReportData
    The data to be exported to the CSV file. It should be an array of objects.

.EXAMPLE
    $reportData = @(
        @{ Name = "John Doe"; Age = 30; Position = "Developer" },
        @{ Name = "Jane Smith"; Age = 25; Position = "Designer" }
    )
    $filePath = "/path/to/reports/EmployeeReport.csv"
    Export-ReportCsv -FilePath $filePath -ReportData $reportData

    This example exports the report data to a CSV file named "EmployeeReport_20240723_153045.csv" in the specified directory.

.EXAMPLE
    $reportData = @(
        @{ Name = "Alice Johnson"; Age = 35; Position = "Manager" },
        @{ Name = "Bob Brown"; Age = 28; Position = "Analyst" }
    )
    $filePath = "C:\Reports\StaffReport.csv"
    Export-ReportCsv -FilePath $filePath -ReportData $reportData

    This example exports the report data to a CSV file named "StaffReport_20240723_153045.csv" in the specified directory.
#>

function Export-ReportCsv {
        
    param (
        [Parameter(Mandatory=$true)]
        [string] $FilePath,

        [Parameter(Mandatory=$true)]
        [array] $ReportData
    )

    # Get current date and time
    $currentDateTime = Get-Date -Format "yyyy_MM_dd_HH_mm"

    # Split the file path to insert the date and time
    $directory = [System.IO.Path]::GetDirectoryName($FilePath)
    $filename = [System.IO.Path]::GetFileNameWithoutExtension($FilePath)
    $extension = If($null -eq [System.IO.Path]::GetExtension($FilePath)) { ".csv" } Else { [System.IO.Path]::GetExtension($FilePath) }  

    # Construct the new file path
    $newFilePath = [System.IO.Path]::Combine($directory, "${filename}_${currentDateTime}${extension}")

    # Ensure the directory exists (cross-platform way)
    if (-not (Test-Path -Path $directory)) {
        New-Item -Path $directory -ItemType Directory -Force
    }

    # Export to CSV
    Export-Csv -Path $newFilePath -InputObject $ReportData -NoTypeInformation
        
}