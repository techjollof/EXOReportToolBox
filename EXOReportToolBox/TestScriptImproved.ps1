param (
    [object]$InputData   # Can be a CSV file path (string) OR in-memory data (Hashtable/Array)
)

# Load WPF assemblies
Add-Type -AssemblyName PresentationFramework
Add-Type -AssemblyName System.Windows.Forms
Add-Type -AssemblyName System.Drawing

# Function to check if input is a valid file
function Test-ValidFile {
    param ([string]$FilePath)

    if (-not (Test-Path $FilePath)) {
        [System.Windows.MessageBox]::Show("Error: CSV file not found at $FilePath") | Out-Null
        exit
    }

    if ((Import-Csv -Path $FilePath | Measure-Object).Count -eq 0) {
        [System.Windows.MessageBox]::Show("Error: CSV file is empty or invalid.") | Out-Null
        exit
    }
}

# Function to check if input is valid in-memory data
function Test-ValidData {
    param ([object]$Data)

    if (($Data | Measure-Object).Count -eq 0) {
        [System.Windows.MessageBox]::Show("Error: Provided data is empty or invalid.") | Out-Null
        exit
    }
}

# Determine if InputData is a file path or an in-memory object
if ($InputData -is [string] -and (Test-Path $InputData)) {
    Test-ValidFile -FilePath $InputData
}
elseif ($InputData -is [System.Collections.IEnumerable]) {
    Test-ValidData -Data $InputData
}
else {
    [System.Windows.MessageBox]::Show("Error: Invalid input. Provide a valid CSV file path or in-memory data.") | Out-Null
    exit
}

# Create Window
$window = New-Object System.Windows.Window
$window.Title = "Unified Audit Log Viewer"
$window.Width = 1200
$window.Height = 800
$window.WindowStartupLocation = "CenterScreen"

# Create Grid
$grid = New-Object System.Windows.Controls.Grid
$grid.Margin = "10"
$window.Content = $grid

# Define Rows and Columns
$row1 = New-Object System.Windows.Controls.RowDefinition
$row1.Height = "Auto"
$row2 = New-Object System.Windows.Controls.RowDefinition
$row2.Height = "*"
$row3 = New-Object System.Windows.Controls.RowDefinition
$row3.Height = "Auto"
$grid.RowDefinitions.Add($row1)
$grid.RowDefinitions.Add($row2)
$grid.RowDefinitions.Add($row3)

$col1 = New-Object System.Windows.Controls.ColumnDefinition
$col1.Width = "Auto"
$col2 = New-Object System.Windows.Controls.ColumnDefinition
$col2.Width = "*"
$col3 = New-Object System.Windows.Controls.ColumnDefinition
$col3.Width = "Auto"
$grid.ColumnDefinitions.Add($col1)
$grid.ColumnDefinitions.Add($col2)
$grid.ColumnDefinitions.Add($col3)

# Create a StackPanel to hold the label and search box
$searchPanel = New-Object System.Windows.Controls.StackPanel
$searchPanel.Orientation = "Horizontal"
$searchPanel.Margin = "5"
$searchPanel.VerticalAlignment = "Center"
$searchPanel.HorizontalAlignment = "Left"

# Add Label for search
$searchBoxLabel = New-Object System.Windows.Controls.Label
$searchBoxLabel.Content = "Keyword:"
$searchBoxLabel.Margin = "5"
$searchBoxLabel.VerticalAlignment = "Center"

# Add Search Box
$searchBox = New-Object System.Windows.Controls.TextBox
$searchBox.Width = 300
$searchBox.Height = 30
$searchBox.Margin = "5"
$searchBox.VerticalAlignment = "Center"
$searchBox.TextAlignment = "Center"
$searchBox.ToolTip = "Enter a keyword to filter log entries."

# Add Filter Button
$filterButton = New-Object System.Windows.Controls.Button
$filterButton.Content = " Filter by Keyword "
$filterButton.Width = [double]::NaN
$filterButton.Height = 25
$filterButton.Margin = "10"
$filterButton.ToolTip = "Filter log entries based on the search term/keyword."
$filterButton.Add_Click({
        Filter-TreeView
    })


# Event Handlers for Buttons
# $filterButton.Add_Click({
#     $searchText = $searchBox.Text.ToLower()
#     $selectedRecordType = $recordTypeFilter.SelectedValue
#     $selectedOperation = $operationsFilter.SelectedValue
#     $startDateTime = $startDatePicker.SelectedDate
#     $endDateTime = $endDatePicker.SelectedDate

#     # Start filtering asynchronously
#     $filterJob = Filter-TreeViewAsync -SearchText $searchText -SelectedRecordType $selectedRecordType -SelectedOperation $selectedOperation -StartDateTime $startDateTime -EndDateTime $endDateTime -LogDataArray $logDataArray

#     # Wait for the async operation to complete
#     $filteredData = $filterJob.PowerShell.EndInvoke($filterJob.AsyncResult)

#     # Update the TreeView with filtered data
#     $treeView.Items.Clear()
#     foreach ($logData in $filteredData) {
#         # Add items to the TreeView
#     }
# })



# Add Export to JSON Button
$exportJsonButton = New-Object System.Windows.Controls.Button
$exportJsonButton.Content = "Export to JSON"
$exportJsonButton.Width = 100
$exportJsonButton.Height = 25
$exportJsonButton.Margin = "5"
$exportJsonButton.ToolTip = "Export the displayed data to a JSON file."
$exportJsonButton.Add_Click({
        $saveFileDialog = New-Object Microsoft.Win32.SaveFileDialog
        $saveFileDialog.Filter = "JSON Files (*.json)|*.json"
        if ($saveFileDialog.ShowDialog() -eq $true) {
            $logDataArray | ConvertTo-Json -Depth 10 | Out-File -FilePath $saveFileDialog.FileName
            [System.Windows.MessageBox]::Show("Data exported to JSON successfully!") | Out-Null
        }
    })

# Add Export to CSV Button
$exportCsvButton = New-Object System.Windows.Controls.Button
$exportCsvButton.Content = "Export to CSV"
$exportCsvButton.Width = 100
$exportCsvButton.Height = 25
$exportCsvButton.Margin = "5"
$exportCsvButton.ToolTip = "Export the displayed data to a CSV file."
$exportCsvButton.Add_Click({
        $saveFileDialog = New-Object Microsoft.Win32.SaveFileDialog
        $saveFileDialog.Filter = "CSV Files (*.csv)|*.csv"
        if ($saveFileDialog.ShowDialog() -eq $true) {
            $logDataArray | Export-Csv -Path $saveFileDialog.FileName -NoTypeInformation
            [System.Windows.MessageBox]::Show("Data exported to CSV successfully!") | Out-Null
        }
    })

# Add Refresh Button
$refreshButton = New-Object System.Windows.Controls.Button
$refreshButton.Content = "Refresh"
$refreshButton.Width = 75
$refreshButton.Height = 25
$refreshButton.Margin = "5"
$refreshButton.ToolTip = "Refresh reloads the data sets"
$refreshButton.Add_Click({
        # Clear the TreeView
        $treeView.Items.Clear()

        # Reload the data
        $logDataArray = Load-AuditLogData -DataInput $InputData
        # Start loading data asynchronously
        # $loadJob = Load-AuditLogDataAsync -DataInput $InputData

        # Monitor the job and update the UI when done
        # Wait for the async operation to complete
        # $logDataArray = $loadJob.PowerShell.EndInvoke($loadJob.AsyncResult)

        # Repopulate filters
        Populate-Filters

        # Reset date pickers
        $startDatePicker.SelectedDate = $null
        $endDatePicker.SelectedDate = $null

        # Reapply filters (including date range)
        Filter-TreeView

        # Update status bar
        $statusBar.Text = "Data refreshed successfully!"
    }
)



# Add Theme Toggle Button
$themeButton = New-Object System.Windows.Controls.Button
$themeButton.Content = "Toggle Theme"
$themeButton.Width = 100
$themeButton.Height = 25
$themeButton.ToolTip = "Change UI to dark mode"
$themeButton.Margin = "5"
$themeButton.Add_Click({
        if ($window.Background -eq [System.Windows.Media.Brushes]::White) {
            $window.Background = [System.Windows.Media.Brushes]::Black
            $window.Foreground = [System.Windows.Media.Brushes]::White
        }
        else {
            $window.Background = [System.Windows.Media.Brushes]::White
            $window.Foreground = [System.Windows.Media.Brushes]::Black
        }
    })

# Add Expand/Collapse Buttons
$expandButton = New-Object System.Windows.Controls.Button
$expandButton.Content = "Expand All"
$expandButton.Width = 75
$expandButton.Height = 25
$expandButton.Margin = "5"
$expandButton.ToolTip = "Expand all collapsed logs"
$expandButton.Add_Click({
        foreach ($item in $treeView.Items) {
            $item.IsExpanded = $true
        }
    })

$collapseButton = New-Object System.Windows.Controls.Button
$collapseButton.Content = "Collapse All"
$collapseButton.Width = 75
$collapseButton.Height = 25
$collapseButton.Margin = "5"
$expandButton.ToolTip = "Collapse all expanded logs"
$collapseButton.Add_Click({
        foreach ($item in $treeView.Items) {
            $item.IsExpanded = $false
        }
    })

# Add Label for RecordType Filter
$recordTypeLabel = New-Object System.Windows.Controls.Label
$recordTypeLabel.Content = "Filter by RecordType:"
$recordTypeLabel.Margin = "5"
$recordTypeLabel.VerticalAlignment = "Center"

# Add RecordType Filter Dropdown
$recordTypeFilter = New-Object System.Windows.Controls.ComboBox
$recordTypeFilter.Width = 150
$recordTypeFilter.Height = 25
$recordTypeFilter.Margin = "5"
$recordTypeFilter.ToolTip = "Filter by RecordType"
$recordTypeFilter.Add_SelectionChanged({
        Filter-TreeView
    })

# Add Label for Operations Filter
$operationsLabel = New-Object System.Windows.Controls.Label
$operationsLabel.Content = "Filter by Operations:"
$operationsLabel.Margin = "5"
$operationsLabel.VerticalAlignment = "Center"

# Add Operations Filter Dropdown
$operationsFilter = New-Object System.Windows.Controls.ComboBox
$operationsFilter.Width = 150
$operationsFilter.Height = 25
$operationsFilter.Margin = "5"
$operationsFilter.ToolTip = "Filter by Operations"
$operationsFilter.Add_SelectionChanged({
        Filter-TreeView
    })

# Add Advanced Filter Panel
$filterPanel = New-Object System.Windows.Controls.StackPanel
$filterPanel.Orientation = "horizontal"
$filterPanel.HorizontalAlignment = "Stretch"
$filterPanel.VerticalAlignment = "Stretch"
$filterPanel.Margin = "10"
$grid.Children.Add($filterPanel)
[System.Windows.Controls.Grid]::SetRow($filterPanel, 0)
[System.Windows.Controls.Grid]::SetColumn($filterPanel, 1)

# Add a StackPanel to Row 1, Column 1 for buttons
$buttonPanel = New-Object System.Windows.Controls.StackPanel
$buttonPanel.Orientation = "Horizontal"
$buttonPanel.Margin = "10"
$grid.Children.Add($buttonPanel)
[System.Windows.Controls.Grid]::SetRow($buttonPanel, 0)
[System.Windows.Controls.Grid]::SetColumn($buttonPanel, 2)


# Add the search StackPanel to the grid
$grid.Children.Add($searchPanel)
[System.Windows.Controls.Grid]::SetRow($searchPanel, 0)
[System.Windows.Controls.Grid]::SetColumn($searchPanel, 0)

$searchPanel.Children.Add($searchBoxLabel)
$searchPanel.Children.Add($searchBox)

$filterPanel.Children.Add($filterButton)
$filterPanel.Children.Add($recordTypeLabel)
$filterPanel.Children.Add($recordTypeFilter)
$filterPanel.Children.Add($operationsLabel)
$filterPanel.Children.Add($operationsFilter)

$buttonPanel.Children.Add($exportJsonButton)
$buttonPanel.Children.Add($exportCsvButton)
$buttonPanel.Children.Add($refreshButton)
$buttonPanel.Children.Add($expandButton)
$buttonPanel.Children.Add($collapseButton)
$buttonPanel.Children.Add($themeButton)

# Add TreeView
$treeView = New-Object System.Windows.Controls.TreeView
$treeView.ToolTip = "Browse the audit log data hierarchically."
$grid.Children.Add($treeView)
[System.Windows.Controls.Grid]::SetRow($treeView, 1)
[System.Windows.Controls.Grid]::SetColumn($treeView, 0)

# Add TextBox
$textBox = New-Object System.Windows.Controls.TextBox
$textBox.IsReadOnly = $true
$textBox.VerticalScrollBarVisibility = "Auto"
$textBox.ToolTip = "View detailed information about the selected item."
$grid.Children.Add($textBox)
[System.Windows.Controls.Grid]::SetRow($textBox, 1)
[System.Windows.Controls.Grid]::SetColumn($textBox, 1)
[System.Windows.Controls.Grid]::SetColumnSpan($textBox, 2)

# Add Progress Bar
$progressBar = New-Object System.Windows.Controls.ProgressBar
$progressBar.Width = 300
$progressBar.Height = 20
$progressBar.HorizontalAlignment = "Center"
$progressBar.VerticalAlignment = "Bottom"
$progressBar.Margin = "10"
$grid.Children.Add($progressBar)
[System.Windows.Controls.Grid]::SetRow($progressBar, 2)
[System.Windows.Controls.Grid]::SetColumn($progressBar, 0)

# Add Status Bar
$statusBar = New-Object System.Windows.Controls.TextBlock
$statusBar.Width = 300
$statusBar.Height = 20
$statusBar.Margin = "10"
$statusBar.VerticalAlignment = "Bottom"
$statusBar.HorizontalAlignment = "Left"
$grid.Children.Add($statusBar)
[System.Windows.Controls.Grid]::SetRow($statusBar, 2)
[System.Windows.Controls.Grid]::SetColumn($statusBar, 1)


# Add Date Range Filter
$dateRangeLabel = New-Object System.Windows.Controls.Label
$dateRangeLabel.Content = "Filter by Date Range:"
$dateRangeLabel.Margin = "5"
$dateRangeLabel.VerticalAlignment = "Center"

$startDatePicker = New-Object System.Windows.Controls.DatePicker
$startDatePicker.Width = 120
$startDatePicker.Margin = "5"
$startDatePicker.ToolTip = "Select start date"
$startDatePicker.Add_SelectedDateChanged({
        Filter-TreeView
    })

$endDatePicker = New-Object System.Windows.Controls.DatePicker
$endDatePicker.Width = 120
$endDatePicker.Margin = "5"
$endDatePicker.ToolTip = "Select end date"
$endDatePicker.Add_SelectedDateChanged({
        Filter-TreeView
    })


# Add Time Pickers
$startTimeComboBox = New-Object System.Windows.Controls.ComboBox
$startTimeComboBox.Width = 100
$startTimeComboBox.Margin = "5"
$startTimeComboBox.ToolTip = "Select start time"
$startTimeComboBox.IsEditable = $true  # Allow manual input
$startTimeComboBox.Text = "00:00:00"   # Default start time
$startTimeComboBox.Add_SelectionChanged({
        Filter-TreeView
    })

$endTimeComboBox = New-Object System.Windows.Controls.ComboBox
$endTimeComboBox.Width = 100
$endTimeComboBox.Margin = "5"
$endTimeComboBox.ToolTip = "Select end time"
$endTimeComboBox.IsEditable = $true    # Allow manual input
$endTimeComboBox.Text = "23:59:59"     # Default end time
# Add event handlers to Time TextBox controls
$endTimeComboBox.Add_SelectionChanged({
        Filter-TreeView
    })

# Populate ComboBoxes with time values
$timeValues = @()
for ($hour = 0; $hour -lt 24; $hour++) {
    for ($minute = 0; $minute -lt 60; $minute++) {
        $timeValues += "{0:D2}:{1:D2}:00" -f $hour, $minute
    }
}

# Add time values to ComboBoxes
$timeValues | ForEach-Object {
    $startTimeComboBox.Items.Add($_) | Out-Null
    $endTimeComboBox.Items.Add($_) | Out-Null
}

# Add Date Range Filter to the Filter Panel
$filterPanel.Children.Add($dateRangeLabel)
$filterPanel.Children.Add($startDatePicker)
$filterPanel.Children.Add($endDatePicker)
# Add Time Pickers to the Filter Panel
$filterPanel.Children.Add($startTimeComboBox)
$filterPanel.Children.Add($endTimeComboBox)



# Function to recursively add JSON data to the TreeView
function Add-TreeNode {
    param (
        [System.Windows.Controls.TreeViewItem]$parentNode,
        [string]$key,
        $value
    )

    # Create a new TreeViewItem for the key-value pair
    $node = New-Object System.Windows.Controls.TreeViewItem

    # Display the key and value in the header
    if ($null -eq $value) {
        $node.Header = "$($key)"
    }
    else {
        $node.Header = "$($key)"
    }

    $node.Tag = $value

    # Add a tooltip to display the full value
    $node.ToolTip = if ($null -eq $value) { "Null or empty data" } else { $value.ToString() }

    if ($value -is [System.Collections.IDictionary]) {
        # If the value is a dictionary, recursively add its key-value pairs
        foreach ($subKey in $value.Keys) {
            Add-TreeNode -parentNode $node -key $subKey -value $value[$subKey]
        }
    }
    elseif ($value -is [System.Collections.IEnumerable] -and $value -isnot [string]) {
        # If the value is a collection (but not a string), add each item
        $index = 0
        foreach ($item in $value) {
            Add-TreeNode -parentNode $node -key "Item $index" -value $item
            $index++
        }
    }
    else {
        # For simple values, add a click event handler to display detailed information
        $node.AddHandler(
            [System.Windows.Controls.TreeViewItem]::MouseLeftButtonUpEvent,
            [System.Windows.RoutedEventHandler] {
                param ($sender, $e)
                if ($null -eq $sender.Tag) {
                    $textBox.Text = "Null or empty data"
                }
                else {
                    $textBox.Text = $sender.Tag | ConvertTo-Json -Depth 10
                }
            }
        )

        # Highlight search results if a search term is provided
        if (-not [string]::IsNullOrEmpty($searchBox.Text)) {
            $searchText = $searchBox.Text
            $text = if ($null -eq $value) { "" } else { $value.ToString() }

            if ($regexCheckBox.IsChecked) {
                try {
                    $matches = [regex]::Matches($text, $searchText)
                    $lastIndex = 0
                    $textBlock = New-Object System.Windows.Controls.TextBlock

                    foreach ($match in $matches) {
                        # Add text before the match
                        if ($match.Index -gt $lastIndex) {
                            $textBlock.Inlines.Add($text.Substring($lastIndex, $match.Index - $lastIndex))
                        }

                        # Add the match with highlighting
                        $run = New-Object System.Windows.Documents.Run $match.Value
                        $run.Background = [System.Windows.Media.Brushes]::Yellow
                        $run.FontWeight = "Bold"
                        $textBlock.Inlines.Add($run)

                        # Update the last index
                        $lastIndex = $match.Index + $match.Length
                    }

                    # Add the remaining text after the last match
                    if ($lastIndex -lt $text.Length) {
                        $textBlock.Inlines.Add($text.Substring($lastIndex))
                    }

                    # Set the TextBlock as the header of the TreeViewItem
                    $node.Header = $textBlock
                }
                catch {
                    # If regex is invalid, display the text without highlighting
                    $node.Header = "$($key)"
                }
            }
            else {
                # Simple text search (case-insensitive)
                $index = $text.IndexOf($searchText, [System.StringComparison]::OrdinalIgnoreCase)
                if ($index -ge 0) {
                    $textBlock = New-Object System.Windows.Controls.TextBlock

                    # Add text before the match
                    $textBlock.Inlines.Add($text.Substring(0, $index))

                    # Add the match with highlighting
                    $run = New-Object System.Windows.Documents.Run $searchText
                    $run.Background = [System.Windows.Media.Brushes]::Yellow
                    $run.FontWeight = "Bold"
                    $textBlock.Inlines.Add($run)

                    # Add the remaining text after the match
                    $textBlock.Inlines.Add($text.Substring($index + $searchText.Length))

                    # Set the TextBlock as the header of the TreeViewItem
                    $node.Header = $textBlock
                }
            }
        }
    }

    # Add the node to the parent node
    $parentNode.Items.Add($node)
}



# Function to Load Audit Log Data with Progress
function Load-AuditLogData {
    param ([object]$DataInput)

    $progressBar.Value = 0
    $statusBar.Text = "Loading data..."

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
        $currentCount++
        $progressBar.Value = ($currentCount / $totalCount) * 100
        $statusBar.Text = "Loading item $currentCount of $totalCount..."

        $_.PSObject.Properties | ForEach-Object {
            if ($_.Name -eq "AuditData") {
                try {
                    $_.Value = ConvertFrom-Json $_.Value -ErrorAction Stop
                }
                catch {
                    Write-Warning "Failed to parse AuditData JSON for entry"
                    $_.Value = $null
                }
            }
        }
        $logDataArray += $_
    }

    $progressBar.Value = 100
    $statusBar.Text = "Data loaded successfully!"

    return $logDataArray
}



# # Create a runspace pool for asynchronous operations
# $runspacePool = [runspacefactory]::CreateRunspacePool(1, 5)  # Min 1, Max 5 threads
# $runspacePool.Open()

# # Function to Load Audit Log Data Asynchronously
# function Load-AuditLogDataAsync {
#     param ([object]$DataInput)

#     # Create a new PowerShell instance for the runspace
#     $powershell = [powershell]::Create()
#     $powershell.RunspacePool = $runspacePool

#     # Add the script to the runspace
#     [void]$powershell.AddScript({
#             param ($DataInput)

#             if ($DataInput -is [string] -and (Test-Path $DataInput)) {
#                 $ParsedDataInput = Import-Csv -Path $DataInput
#             }
#             elseif ($DataInput -is [System.Collections.IEnumerable]) {
#                 $ParsedDataInput = $DataInput
#             }
#             else {
#                 throw "Invalid input! Provide a valid CSV file path or in-memory data."
#             }

#             $logDataArray = $ParsedDataInput | ForEach-Object {
#                 $_.PSObject.Properties | ForEach-Object {
#                     if ($_.Name -eq "AuditData") {
#                         try {
#                             $_.Value = ConvertFrom-Json $_.Value -ErrorAction Stop
#                         }
#                         catch {
#                             Write-Warning "Failed to parse AuditData JSON for entry"
#                             $_.Value = $null
#                         }
#                     }
#                 }
#                 $_
#             }

#             return $logDataArray
#         }).AddArgument($DataInput)

#     # Start the asynchronous operation
#     $asyncResult = $powershell.BeginInvoke()

#     # Return the PowerShell instance and async result for tracking
#     return @{
#         PowerShell  = $powershell
#         AsyncResult = $asyncResult
#     }
# }

# Function to Filter TreeView Asynchronously
# function Filter-TreeViewAsync {
#     param (
#         [string]$SearchText,
#         [string]$SelectedRecordType,
#         [string]$SelectedOperation,
#         [datetime]$StartDateTime,
#         [datetime]$EndDateTime,
#         [array]$LogDataArray
#     )

#     # Create a new PowerShell instance for the runspace
#     $powershell = [powershell]::Create()
#     $powershell.RunspacePool = $runspacePool

#     # Add the script to the runspace
#     [void]$powershell.AddScript({
#             param (
#                 $SearchText,
#                 $SelectedRecordType,
#                 $SelectedOperation,
#                 $StartDateTime,
#                 $EndDateTime,
#                 $LogDataArray
#             )

#             Write-Host "Start Date $($StartDateTime)"
#             Write-Host "Start Date $($EndDateTime)"

#             $filteredData = $LogDataArray | Where-Object {
#             ($SelectedRecordType -eq "All" -or $_.RecordType -eq $SelectedRecordType) -and
#             ($SelectedOperation -eq "All" -or $_.Operations -eq $SelectedOperation) -and
#             ($_.AuditData -match $SearchText -or $_.ResultIndex -match $SearchText) -and
#             ($null -eq $StartDateTime -or [datetime]::ParseExact($_.CreationTime, "MM/dd/yyyy HH:mm:ss", $null) -ge $StartDateTime) -and
#             ($null -eq $EndDateTime -or [datetime]::ParseExact($_.CreationTime, "MM/dd/yyyy HH:mm:ss", $null) -le $EndDateTime)
#             }

#             return $filteredData
#         }).AddArgument($SearchText).
#     AddArgument($SelectedRecordType).
#     AddArgument($SelectedOperation).
#     AddArgument($StartDateTime).
#     AddArgument($EndDateTime).
#     AddArgument($LogDataArray)

#     # Start the asynchronous operation
#     $asyncResult = $powershell.BeginInvoke()

#     # Return the PowerShell instance and async result for tracking
#     return @{
#         PowerShell  = $powershell
#         AsyncResult = $asyncResult
#     }
# }

# Event Handlers for Buttons


# Function to populate dropdowns with unique values
function Populate-Filters {
    # Clear existing items
    $recordTypeFilter.Items.Clear()
    $operationsFilter.Items.Clear()

    # Add "All" option to both dropdowns
    $recordTypeFilter.Items.Add("All")
    $operationsFilter.Items.Add("All")

    # Get unique RecordType and Operations values
    $uniqueRecordTypes = $logDataArray | ForEach-Object { $_.RecordType } | Sort-Object -Unique
    $uniqueOperations = $logDataArray | ForEach-Object { $_.Operations } | Sort-Object -Unique

    # Add unique values to dropdowns
    foreach ($recordType in $uniqueRecordTypes) {
        $recordTypeFilter.Items.Add($recordType)
    }
    foreach ($operation in $uniqueOperations) {
        $operationsFilter.Items.Add($operation)
    }

    # Set default selection to "All"
    $recordTypeFilter.SelectedIndex = 0
    $operationsFilter.SelectedIndex = 0
}



# Add a CheckBox for enabling regular expressions
$regexCheckBox = New-Object System.Windows.Controls.CheckBox
$regexCheckBox.Content = "Use Regex"
$regexCheckBox.Margin = "5"
$regexCheckBox.ToolTip = "Enable regular expressions for advanced filtering."

# Add the CheckBox to the search panel
$searchPanel.Children.Add($regexCheckBox)

# Update Filter-TreeView function to handle invalid or empty CreationTime

function Filter-TreeView {
    $searchText = $searchBox.Text.ToLower()
    $selectedRecordType = $recordTypeFilter.SelectedValue
    $selectedOperation = $operationsFilter.SelectedValue

    # Combine date and time for start and end filters
    $startDate = $startDatePicker.SelectedDate
    $startTime = $startTimeTextBox.Text
    $endDate = $endDatePicker.SelectedDate
    $endTime = $endTimeTextBox.Text

    # Parse start and end DateTime
    $startDateTime = $null
    $endDateTime = $null

    if ($null -ne $startDate -and -not [string]::IsNullOrEmpty($startTime)) {
        try {
            $startDateTime = [datetime]::ParseExact("$($startDate.ToString('MM/dd/yyyy')) $startTime", "MM/dd/yyyy HH:mm:ss", $null)
            # Write-Host "Start DateTime: $startDateTime"
        }
        catch {
            Write-Warning "Invalid start date or time format."
        }
    }

    if ($null -ne $endDate -and -not [string]::IsNullOrEmpty($endTime)) {
        try {
            $endDateTime = [datetime]::ParseExact("$($endDate.ToString('MM/dd/yyyy')) $endTime", "MM/dd/yyyy HH:mm:ss", $null)
            # Write-Host "End DateTime: $endDateTime"
        }
        catch {
            Write-Warning "Invalid end date or time format."
        }
    }

    $treeView.Items.Clear()

    foreach ($logData in $logDataArray) {

        $logDate = $null
        if ([string]::IsNullOrEmpty($logData.CreationDate) -or ([Datetime]$logData.CreationDate -is [datetime])) {
            try {
                $logDate = [datetime]$logData.CreationDate -f "MM/dd/yyyy HH:mm:ss"
                Write-Host "Log Date: $logDate"
            }
            catch {
                Write-Warning "Failed to parse CreationTime for entry: $($logData.CreationDate)"
                continue  # Skip this entry if the date is invalid
            }
        }
        else {
            Write-Host "Log data not showing"
        }

        # Apply filters
        $matchesRecordType = ($selectedRecordType -eq "All" -or $logData.RecordType -eq $selectedRecordType)
        $matchesOperation = ($selectedOperation -eq "All" -or $logData.Operations -eq $selectedOperation)

        # Handle search text with or without regex
        $matchesSearch = $false
        if ($regexCheckBox.IsChecked) {
            try {
                $matchesSearch = [regex]::IsMatch($logData.AuditData, $searchText) -or [regex]::IsMatch($logData.ResultIndex, $searchText)
            }
            catch {
                Write-Warning "Invalid regular expression: $searchText"
                continue
            }
        }
        else {
            $matchesSearch = $logData.AuditData -match $searchText -or $logData.ResultIndex -match $searchText
        }

        $matchesDateRange = ($null -eq $startDateTime -or $logDate -ge $startDateTime) -and ($null -eq $endDateTime -or $logDate -le $endDateTime)

        # $matchesSearch = ($logData.AuditData -match $searchText -or $logData.ResultIndex -match $searchText)
        # $matchesDateRange = ($null -eq $startDateTime -or $logDate -ge $startDateTime) -and ($null -eq $endDateTime -or $logDate -le $endDateTime)

        if ($matchesRecordType -and $matchesOperation -and $matchesSearch -and $matchesDateRange) {
            $entryNode = New-Object System.Windows.Controls.TreeViewItem
            $entryNode.Header = "$($logData.RecordType) - $($logData.Operations)"
            $treeView.Items.Add($entryNode)

            foreach ($key in $logData.PSObject.Properties.Name) {
                if ($key -eq "AuditData") {
                    $auditNode = New-Object System.Windows.Controls.TreeViewItem
                    $auditNode.Header = "AuditData"
                    $entryNode.Items.Add($auditNode)

                    foreach ($auditKey in $logData.AuditData.PSObject.Properties.Name) {
                        $auditValue = $logData.AuditData.$auditKey

                        if ($auditKey -eq "Parameters" -and $auditValue -is [System.Collections.IEnumerable]) {
                            $paramNode = New-Object System.Windows.Controls.TreeViewItem
                            $paramNode.Header = "Parameters"
                            $auditNode.Items.Add($paramNode)

                            foreach ($param in $auditValue) {
                                try {
                                    $paramValue = ConvertFrom-Json $param.Value -ErrorAction Stop
                                }
                                catch {
                                    $paramValue = $param.Value
                                }
                                Add-TreeNode -parentNode $paramNode -key $param.Name -value $paramValue
                            }
                        }
                        else {
                            Add-TreeNode -parentNode $auditNode -key $auditKey -value $auditValue
                        }
                    }
                }
                else {
                    Add-TreeNode -parentNode $entryNode -key $key -value $logData.$key
                }
            }
        }
    }
}


# Function to filter TreeView based on dropdown selections
# function Filter-TreeView {
#     $searchText = $searchBox.Text.ToLower()
#     $selectedRecordType = $recordTypeFilter.SelectedValue
#     $selectedOperation = $operationsFilter.SelectedValue

#     $treeView.Items.Clear()

#     foreach ($logData in $logDataArray) {
#         # Apply filters
#         $matchesRecordType = ($selectedRecordType -eq "All" -or $logData.RecordType -eq $selectedRecordType)
#         $matchesOperation = ($selectedOperation -eq "All" -or $logData.Operations -eq $selectedOperation)
#         $matchesSearch = ($logData.AuditData -match $searchText -or $logData.ResultIndex -match $searchText)

#         if ($matchesRecordType -and $matchesOperation -and $matchesSearch) {
#             $entryNode = New-Object System.Windows.Controls.TreeViewItem
#             $entryNode.Header = "$($logData.RecordType) - $($logData.Operations)"
#             $treeView.Items.Add($entryNode)

#             foreach ($key in $logData.PSObject.Properties.Name) {
#                 if ($key -eq "AuditData") {
#                     $auditNode = New-Object System.Windows.Controls.TreeViewItem
#                     $auditNode.Header = "AuditData"
#                     $entryNode.Items.Add($auditNode)

#                     foreach ($auditKey in $logData.AuditData.PSObject.Properties.Name) {
#                         $auditValue = $logData.AuditData.$auditKey

#                         if ($auditKey -eq "Parameters" -and $auditValue -is [System.Collections.IEnumerable]) {
#                             $paramNode = New-Object System.Windows.Controls.TreeViewItem
#                             $paramNode.Header = "Parameters"
#                             $auditNode.Items.Add($paramNode)

#                             foreach ($param in $auditValue) {
#                                 try {
#                                     $paramValue = ConvertFrom-Json $param.Value -ErrorAction Stop
#                                 }
#                                 catch {
#                                     $paramValue = $param.Value
#                                 }
#                                 Add-TreeNode -parentNode $paramNode -key $param.Name -value $paramValue
#                             }
#                         }
#                         else {
#                             Add-TreeNode -parentNode $auditNode -key $auditKey -value $auditValue
#                         }
#                     }
#                 }
#                 else {
#                     Add-TreeNode -parentNode $entryNode -key $key -value $logData.$key
#                 }
#             }
#         }
#     }
# }

# Load data from either CSV file or in-memory object
$logDataArray = Load-AuditLogData -DataInput $InputData

# Populate dropdowns with unique values
Populate-Filters

# Populate TreeView
Filter-TreeView

# Show Window
$window.ShowDialog()
# Clean up runspace pool
# $runspacePool.Close()
# $runspacePool.Dispose()
