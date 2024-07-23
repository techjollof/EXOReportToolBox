# Main script
# Define the script root manually
$scriptRoot = Split-Path -Parent $MyInvocation.MyCommand.Path

# Define the report data
$reportData = @(
    @{ Name = "John Doe"; Age = 30; Position = "Developer" },
    @{ Name = "Jane Smith"; Age = 25; Position = "Designer" }
)

# Specify the file path
$filePath = "$scriptRoot/Reports/EmployeeReport.csv" # Update this path as needed

# Source the Export-ReportCsv.ps1 script
$exportScriptPath = "$scriptRoot/Export-ReportCsv.ps1"

if (Test-Path -Path $exportScriptPath) {
    . $exportScriptPath
    # Call the function to export the data to CSV with appended date and time
    Export-ReportCsv -FilePath $filePath -ReportData $reportData
} else {
    Write-Error "The script Export-ReportCsv.ps1 could not be found at $exportScriptPath"
}
