param (
    [object]$InputData   # Can be a CSV file path (string) OR in-memory data (Hashtable/Array)
)

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

# Load WPF assemblies
[System.Reflection.Assembly]::LoadWithPartialName('PresentationFramework') | Out-Null

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
$grid.ColumnDefinitions.Add($col1)
$grid.ColumnDefinitions.Add($col2)

# Add Search Box
$searchBox = New-Object System.Windows.Controls.TextBox
$searchBox.Width = 200
$searchBox.Height = 25
$searchBox.Margin = "10"
$searchBox.HorizontalAlignment = "Left"
$searchBox.VerticalAlignment = "Top"
$searchBox.ToolTip = "Enter a keyword to filter log entries."
$grid.Children.Add($searchBox)
[System.Windows.Controls.Grid]::SetRow($searchBox, 0)
[System.Windows.Controls.Grid]::SetColumn($searchBox, 0)

# Add Export Button
$exportButton = New-Object System.Windows.Controls.Button
$exportButton.Content = "Export to JSON"
$exportButton.Width = 100
$exportButton.Height = 30
$exportButton.Margin = "10"
$exportButton.HorizontalAlignment = "Right"
$exportButton.VerticalAlignment = "Top"
$exportButton.ToolTip = "Export the displayed data to a JSON file."
$exportButton.Add_Click({
    $saveFileDialog = New-Object Microsoft.Win32.SaveFileDialog
    $saveFileDialog.Filter = "JSON Files (*.json)|*.json"
    if ($saveFileDialog.ShowDialog() -eq $true) {
        $logDataArray | ConvertTo-Json -Depth 10 | Out-File -FilePath $saveFileDialog.FileName
        [System.Windows.MessageBox]::Show("Data exported successfully!") | Out-Null
    }
})
$grid.Children.Add($exportButton)
[System.Windows.Controls.Grid]::SetRow($exportButton, 0)
[System.Windows.Controls.Grid]::SetColumn($exportButton, 1)

# Add Refresh Button
$refreshButton = New-Object System.Windows.Controls.Button
$refreshButton.Content = "Refresh"
$refreshButton.Width = 100
$refreshButton.Height = 30
$refreshButton.Margin = "10"
$refreshButton.HorizontalAlignment = "Right"
$refreshButton.VerticalAlignment = "Top"
$refreshButton.Add_Click({
    $treeView.Items.Clear()
    $logDataArray = Load-AuditLogData -DataInput $InputData
    foreach ($logData in $logDataArray) {
        $entryNode = New-Object System.Windows.Controls.TreeViewItem
        $entryNode.Header = "Log Entry - $($logData.ResultIndex)"
        $treeView.Items.Add($entryNode)

        foreach ($key in $logData.PSObject.Properties.Name) {
            if ($key -eq "AuditData") {
                $auditNode = New-Object System.Windows.Controls.TreeViewItem
                $auditNode.Header = "AuditData"
                $entryNode.Items.Add($auditNode)

                # Add ALL properties of AuditData (not just Parameters)
                foreach ($auditKey in $logData.AuditData.PSObject.Properties.Name) {
                    $auditValue = $logData.AuditData.$auditKey

                    # Special handling for the "Parameters" field (nested JSON parsing)
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
    $statusBar.Text = "Data refreshed successfully!"
})
$grid.Children.Add($refreshButton)
[System.Windows.Controls.Grid]::SetRow($refreshButton, 0)
[System.Windows.Controls.Grid]::SetColumn($refreshButton, 2)

# Add Theme Toggle Button
$themeButton = New-Object System.Windows.Controls.Button
$themeButton.Content = "Toggle Theme"
$themeButton.Width = 100
$themeButton.Height = 30
$themeButton.Margin = "10"
$themeButton.HorizontalAlignment = "Right"
$themeButton.VerticalAlignment = "Top"
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
$grid.Children.Add($themeButton)
[System.Windows.Controls.Grid]::SetRow($themeButton, 0)
[System.Windows.Controls.Grid]::SetColumn($themeButton, 3)

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

# Function to recursively add JSON data to the TreeView
function Add-TreeNode {
    param (
        [System.Windows.Controls.TreeViewItem]$parentNode,
        [string]$key,
        $value
    )

    $node = New-Object System.Windows.Controls.TreeViewItem
    $node.Header = $key
    $node.Tag = $value

    if ($value -is [System.Collections.IDictionary]) {
        foreach ($subKey in $value.Keys) {
            Add-TreeNode -parentNode $node -key $subKey -value $value[$subKey]
        }
    }
    elseif ($value -is [System.Collections.IEnumerable] -and $value -isnot [string]) {
        $index = 0
        foreach ($item in $value) {
            Add-TreeNode -parentNode $node -key "Item $index" -value $item
            $index++
        }
    }
    else {
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
    }
    
    $parentNode.Items.Add($node)
}

# Function to Load Audit Log Data
function Load-AuditLogData {
    param ([object]$DataInput)

    if ($DataInput -is [string] -and (Test-Path $DataInput)) {
        $PursedDataInput = Import-Csv -Path $DataInput
    }
    elseif ($DataInput -is [System.Collections.IEnumerable]) {
        # Use in-memory Hashtable or Object Array directly
        $PursedDataInput = $DataInput
    }
    else {
        Write-Host "Invalid input! Provide a valid CSV file path or in-memory data."
        exit
    }

    # Load from CSV file
    $logDataArray =  $PursedDataInput | ForEach-Object {
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
        $_
    }

    return $logDataArray
}

# Load data from either CSV file or in-memory object
$logDataArray = Load-AuditLogData -DataInput $InputData

# Populate TreeView
foreach ($logData in $logDataArray) {
    $entryNode = New-Object System.Windows.Controls.TreeViewItem
    $entryNode.Header = "Log Entry - $($logData.ResultIndex)"
    $treeView.Items.Add($entryNode)

    foreach ($key in $logData.PSObject.Properties.Name) {
        if ($key -eq "AuditData") {
            $auditNode = New-Object System.Windows.Controls.TreeViewItem
            $auditNode.Header = "AuditData"
            $entryNode.Items.Add($auditNode)

            # Add ALL properties of AuditData (not just Parameters)
            foreach ($auditKey in $logData.AuditData.PSObject.Properties.Name) {
                $auditValue = $logData.AuditData.$auditKey

                # Special handling for the "Parameters" field (nested JSON parsing)
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

# Show Window
$window.ShowDialog()



















#######################
param (
    [object]$InputData   # Can be a CSV file path (string) OR in-memory data (Hashtable/Array)
)

# Load WPF assemblies
Add-Type -AssemblyName PresentationFramework
Add-Type -AssemblyName System.Windows.Forms

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
$searchPanel.Orientation = "Horizontal"  # Arrange children horizontally
$searchPanel.Margin = "5"
$searchPanel.VerticalAlignment = "Center"  # Align vertically in the center
$searchPanel.HorizontalAlignment = "Left"  # Align horizontally to the left

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
$searchBox.TextAlignment = "Center"  # Center-align the text inside the TextBox
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
$refreshButton.ToolTip ="Refresh reloads the data sets"
$refreshButton.Add_Click({
    $treeView.Items.Clear()
    $logDataArray = Load-AuditLogData -DataInput $InputData
    Populate-Filters
    Filter-TreeView
    $statusBar.Text = "Data refreshed successfully!"
})

# Add Theme Toggle Button
$themeButton = New-Object System.Windows.Controls.Button
$themeButton.Content = "Toggle Theme"
$themeButton.Width = 100
$themeButton.Height = 25
$themeButton.ToolTip ="Change UI to dark mode"
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
$expandButton.ToolTip ="Expand all collapsed logs"
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
$expandButton.ToolTip ="Collapse all expanded logs"
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


# Add the search StackPanel to the grid
$grid.Children.Add($searchPanel)
[System.Windows.Controls.Grid]::SetRow($searchPanel, 0)
[System.Windows.Controls.Grid]::SetColumn($searchPanel, 0)


# Add Advanced Filter Panel
$filterPanel = New-Object System.Windows.Controls.StackPanel
$filterPanel.Orientation = "horizontal"
$filterPanel.HorizontalAlignment = "Stretch"  # Stretch to fill the window width
$filterPanel.VerticalAlignment = "Stretch"  # Stretch to fill the window height
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


$searchPanel.Children.Add($searchBoxLabel)  # Add the label to the StackPanel
$searchPanel.Children.Add($searchBox)  # Add the search box to the StackPanel

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
[System.Windows.Controls.Grid]::SetColumnSpan($textBox,2)


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

# Function to recursively add JSON data to the TreeView
function Add-TreeNode {
    param (
        [System.Windows.Controls.TreeViewItem]$parentNode,
        [string]$key,
        $value
    )

    $node = New-Object System.Windows.Controls.TreeViewItem
    $node.Header = $key
    $node.Tag = $value

    if ($value -is [System.Collections.IDictionary]) {
        foreach ($subKey in $value.Keys) {
            Add-TreeNode -parentNode $node -key $subKey -value $value[$subKey]
        }
    }
    elseif ($value -is [System.Collections.IEnumerable] -and $value -isnot [string]) {
        $index = 0
        foreach ($item in $value) {
            Add-TreeNode -parentNode $node -key "Item $index" -value $item
            $index++
        }
    }
    else {
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
    }
    
    $parentNode.Items.Add($node)
}

# Function to Load Audit Log Data
function Load-AuditLogData {
    param ([object]$DataInput)

    if ($DataInput -is [string] -and (Test-Path $DataInput)) {
        $ParsedDataInput = Import-Csv -Path $DataInput
    }
    elseif ($DataInput -is [System.Collections.IEnumerable]) {
        # Use in-memory Hashtable or Object Array directly
        $ParsedDataInput = $DataInput
    }
    else {
        Write-Host "Invalid input! Provide a valid CSV file path or in-memory data."
        exit
    }

    # Load from CSV file
    $logDataArray =  $ParsedDataInput | ForEach-Object {
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
        $_
    }

    return $logDataArray
}

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

# Function to filter TreeView based on dropdown selections
function Filter-TreeView {
    $searchText = $searchBox.Text.ToLower()
    $selectedRecordType = $recordTypeFilter.SelectedValue
    $selectedOperation = $operationsFilter.SelectedValue

    $treeView.Items.Clear()

    foreach ($logData in $logDataArray) {
        # Apply filters
        $matchesRecordType = ($selectedRecordType -eq "All" -or $logData.RecordType -eq $selectedRecordType)
        $matchesOperation = ($selectedOperation -eq "All" -or $logData.Operations -eq $selectedOperation)
        $matchesSearch = ($logData.AuditData -match $searchText -or $logData.ResultIndex -match $searchText)

        if ($matchesRecordType -and $matchesOperation -and $matchesSearch) {
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

# Load data from either CSV file or in-memory object
$logDataArray = Load-AuditLogData -DataInput $InputData

# Populate dropdowns with unique values
Populate-Filters

# Populate TreeView
Filter-TreeView

# Show Window
$window.ShowDialog()