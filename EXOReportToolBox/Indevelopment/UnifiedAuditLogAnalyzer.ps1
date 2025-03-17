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
        [System.Windows.MessageBox]::Show("Error: File not found at $FilePath") | Out-Null
        return $false
    }

    if ((Get-Item $FilePath).Length -eq 0) {
        [System.Windows.MessageBox]::Show("Error: File is empty.") | Out-Null
        return $false
    }

    return $true
}

# Function to check if input is valid in-memory data
function Test-ValidData {
    param ([object]$Data)

    if (($Data | Measure-Object).Count -eq 0) {
        [System.Windows.MessageBox]::Show("Error: Provided data is empty or invalid.") | Out-Null
        return $false
    }

    return $true
}

# Function to load data from a file
function Load-DataFromFile {
    param ([string]$FilePath)

    if ($FilePath -match '\.csv$') {
        return Import-Csv -Path $FilePath
    }
    elseif ($FilePath -match '\.json$') {
        return Get-Content -Path $FilePath | ConvertFrom-Json
    }
    else {
        [System.Windows.MessageBox]::Show("Error: Unsupported file format. Only CSV and JSON files are supported.") | Out-Null
        return $null
    }
}

# Create Window
$window = New-Object System.Windows.Window
$window.Title = "Unified Audit Log Viewer"
$window.Width = 1400
$window.Height = 800
$window.MinWidth = 800
$window.MinHeight = 500
$window.WindowStartupLocation = "CenterScreen"

# Enable drag-and-drop
$window.AllowDrop = $true

# DragEnter event handler
$window.Add_DragEnter({
        param ($sender, $e)

        if ($e.Data.GetDataPresent([System.Windows.DataFormats]::FileDrop)) {
            $e.Effects = [System.Windows.DragDropEffects]::Copy
        }
        else {
            $e.Effects = [System.Windows.DragDropEffects]::None
        }
    })

# Drop event handler
$window.Add_Drop({
        param ($sender, $e)

        $filePaths = $e.Data.GetData([System.Windows.DataFormats]::FileDrop)

        if ($filePaths.Count -gt 0) {
            $filePath = $filePaths[0]

            if (Test-ValidFile -FilePath $filePath) {
                $global:logDataArray = Load-DataFromFile -FilePath $filePath

                if ($null -ne $global:logDataArray) {
                    Update-Filters
                    Update-TreeView
                    Update-StatusBar -Message "File loaded successfully: $filePath"
                }
            }
        }
    })

################## Parameters #####################
# Define standard button size
$buttonWidth = 100
$buttonHeight = 25
$uIMargin = 5

#################### Window Configuration #################################
# Styling for a modern UI feel
$window.FontFamily = "Segoe UI"
$window.FontSize = 13   # Slightly larger for readability
$window.FontWeight = "Normal"
$window.Background = [System.Windows.Media.Brushes]::WhiteSmoke  # Light background for contrast

# Enable resizing while maintaining structure
$window.ResizeMode = "CanResize"

# Optional: Add a subtle border around the window
$window.BorderThickness = 1
$window.BorderBrush = [System.Windows.Media.Brushes]::Gray

# Optional: Add a drop shadow effect for a modern UI
$shadowEffect = New-Object System.Windows.Media.Effects.DropShadowEffect
$shadowEffect.BlurRadius = 10
$shadowEffect.ShadowDepth = 5
$shadowEffect.Opacity = 0.4
$window.Effect = $shadowEffect

$window.Add_KeyDown({
        param ($sender, $e)

        if ($e.Key -eq "C" -and ([System.Windows.Input.Keyboard]::IsKeyDown("LeftCtrl") -or [System.Windows.Input.Keyboard]::IsKeyDown("RightCtrl"))) {
            # Select all text in the Preview Pane
            $previewPane.SelectAll()
            # Copy the selected text to the clipboard
            $previewPane.Copy()
            # Deselect the text
            $previewPane.SelectionLength = 0
            # Update the status bar
            Update-StatusBar -Message "Text copied to clipboard."
        }
    })

# Create Grid
$grid = New-Object System.Windows.Controls.Grid
$grid.Margin = "10"  # Add margin around the grid
$window.Content = $grid  # Set the grid as the window's content

# Define columns for the main Grid (percentage-based)
$grid.ColumnDefinitions.Add((New-Object System.Windows.Controls.ColumnDefinition -Property @{ Width = "3*" }))  # Column 0: TreeView (25%)
$grid.ColumnDefinitions.Add((New-Object System.Windows.Controls.ColumnDefinition -Property @{ Width = "5*" }))  # Column 1: Preview Pane (50%)
$grid.ColumnDefinitions.Add((New-Object System.Windows.Controls.ColumnDefinition -Property @{ Width = "3*" }))  # Column 2: Detailed Info Pane (25%)

# Define rows for the main Grid
$grid.RowDefinitions.Add((New-Object System.Windows.Controls.RowDefinition -Property @{ Height = "Auto" }))  # Row 0: Header
$grid.RowDefinitions.Add((New-Object System.Windows.Controls.RowDefinition -Property @{ Height = "*" }))      # Row 1: Main Content (stretches to fill remaining space)
$grid.RowDefinitions.Add((New-Object System.Windows.Controls.RowDefinition -Property @{ Height = "Auto" }))  # Row 2: Footer

# Add Status Bar (NEW: Added for drag-and-drop support)
$statusBar = New-Object System.Windows.Controls.TextBlock
$statusBar.Width = 300
$statusBar.Height = 20
$statusBar.Margin = $uIMargin
$statusBar.VerticalAlignment = "Bottom"
$statusBar.HorizontalAlignment = "Left"
$grid.Children.Add($statusBar)
[System.Windows.Controls.Grid]::SetRow($statusBar, 2)
[System.Windows.Controls.Grid]::SetColumn($statusBar, 1)

############ Tree View Configuration ######################

# Create the Grid for the TreeView section
$treeViewGrid = New-Object System.Windows.Controls.Grid
$treeViewGrid.Margin = $uIMargin
$treeViewGrid.VerticalAlignment = "Stretch"
$treeViewGrid.HorizontalAlignment = "Stretch"

# Define rows for the Grid
$treeViewGrid.RowDefinitions.Add((New-Object System.Windows.Controls.RowDefinition -Property @{ Height = "Auto" })) # Row 0: Label
$treeViewGrid.RowDefinitions.Add((New-Object System.Windows.Controls.RowDefinition -Property @{ Height = "*" }))    # Row 1: TreeView (fills remaining space)

# Add the TreeView Grid to the main Grid
$grid.Children.Add($treeViewGrid)
[System.Windows.Controls.Grid]::SetRow($treeViewGrid, 1)
[System.Windows.Controls.Grid]::SetColumn($treeViewGrid, 0)

# Create the Label
$treeViewLabel = New-Object System.Windows.Controls.Label
$treeViewLabel.Content = "Audit Data:"
$treeViewLabel.FontSize = 18
$treeViewLabel.FontWeight = "Bold"

# Add the Label to Row 0 of the TreeView Grid
$treeViewGrid.Children.Add($treeViewLabel)
[System.Windows.Controls.Grid]::SetRow($treeViewLabel, 0)

# Create the TreeView
$treeView = New-Object System.Windows.Controls.TreeView
$treeView.ToolTip = "Browse the audit log data hierarchically."
$treeView.VerticalAlignment = "Stretch"  # Ensure TreeView stretches vertically
$treeView.HorizontalAlignment = "Stretch"
$treeView.Background = "LightYellow"
$treeView.Padding = "10"
$treeView.Margin = $uIMargin
$treeView.FontFamily = "Segoe UI"
$treeView.FontSize = "12"
$treeView.BorderBrush = "DarkGreen"
$treeView.BorderThickness = "1"

# Enable virtualization for TreeView
$treeView.ItemsPanel = New-Object System.Windows.Controls.ItemsPanelTemplate -ArgumentList @(
    [System.Windows.FrameworkElementFactory]::new([System.Windows.Controls.VirtualizingStackPanel])
    $treeView.SetValue([System.Windows.Controls.VirtualizingStackPanel]::IsVirtualizingProperty, $true)
    $treeView.SetValue([System.Windows.Controls.VirtualizingStackPanel]::VirtualizationModeProperty, [System.Windows.Controls.VirtualizationMode]::Recycling))

# Add the TreeView to Row 1 of the TreeView Grid
$treeViewGrid.Children.Add($treeView)
[System.Windows.Controls.Grid]::SetRow($treeView, 1)

# Event Handler for TreeView Selection Changed
$treeView.Add_SelectedItemChanged({
        $selectedItem = $treeView.SelectedItem

        if ($selectedItem -and $selectedItem.Tag) {
            # Update the Preview Pane with the selected log entry
            Update-PreviewPane -SelectedItem $selectedItem.Tag
        }
        else {
            $previewPane.Text = "No log entry selected."
        }
    })

$treeView.Add_MouseDoubleClick({
        param ($sender, $e)

        # Check if the TreeView is empty
        if ($treeView.Items.Count -eq 0) {
            # Open a file dialog to browse for a file
            $openFileDialog = New-Object Microsoft.Win32.OpenFileDialog
            $openFileDialog.Filter = "CSV Files (*.csv)|*.csv|JSON Files (*.json)|*.json"
            $openFileDialog.Title = "Select a CSV or JSON file to load"

            if ($openFileDialog.ShowDialog() -eq $true) {
                $filePath = $openFileDialog.FileName

                if (Test-ValidFile -FilePath $filePath) {
                    $global:logDataArray = Load-DataFromFile -FilePath $filePath

                    if ($null -ne $global:logDataArray) {
                        Update-Filters
                        Update-TreeView
                        Update-StatusBar -Message "File loaded successfully: $filePath"
                    }
                }
            }
        }
    })

############ Preview Pane Configuration ##################

# Create the Preview Pane Grid
$previewPaneGrid = New-Object System.Windows.Controls.Grid
$previewPaneGrid.Margin = $uIMargin
$previewPaneGrid.VerticalAlignment = "Stretch"
$previewPaneGrid.HorizontalAlignment = "Stretch"

# Define rows for the Grid
$previewPaneGrid.RowDefinitions.Add((New-Object System.Windows.Controls.RowDefinition -Property @{ Height = "Auto" })) # Row 0: Label
$previewPaneGrid.RowDefinitions.Add((New-Object System.Windows.Controls.RowDefinition -Property @{ Height = "*" }))    # Row 1: TextBox (fills remaining space)

# Add the Preview Pane Grid to the main Grid
$grid.Children.Add($previewPaneGrid)
[System.Windows.Controls.Grid]::SetRow($previewPaneGrid, 1)
[System.Windows.Controls.Grid]::SetColumn($previewPaneGrid, 1)

# Create a Grid for the Label and Copy Button
$labelButtonGrid = New-Object System.Windows.Controls.Grid
$labelButtonGrid.HorizontalAlignment = "Stretch"  # Ensure it stretches horizontally

# Define columns for the Label and Button Grid
$labelButtonGrid.ColumnDefinitions.Add((New-Object System.Windows.Controls.ColumnDefinition -Property @{ Width = "Auto" })) # Column 0: Label (left-aligned)
$labelButtonGrid.ColumnDefinitions.Add((New-Object System.Windows.Controls.ColumnDefinition -Property @{ Width = "*" }))    # Column 1: Spacer (fills remaining space)
$labelButtonGrid.ColumnDefinitions.Add((New-Object System.Windows.Controls.ColumnDefinition -Property @{ Width = "Auto" })) # Column 2: Button (right-aligned)

# Create the Label
$previewPaneLabel = New-Object System.Windows.Controls.Label
$previewPaneLabel.Content = "Audit Preview:"
$previewPaneLabel.HorizontalAlignment = "Left"
$previewPaneLabel.FontSize = 18
$previewPaneLabel.FontWeight = "Bold"
$previewPaneLabel.Margin = "0,0,10,0"  # Add some margin between the Label and the Copy Button

# Add the Label to Column 0 of the Label and Button Grid
$labelButtonGrid.Children.Add($previewPaneLabel)
[System.Windows.Controls.Grid]::SetColumn($previewPaneLabel, 0)

# Add a Copy Button next to the Preview Pane
$copyButton = New-Object System.Windows.Controls.Button
$copyButton.Content = "Copy"
$copyButton.Width = $buttonWidth
$copyButton.Height = $buttonHeight
$copyButton.Margin = $uIMargin
$copyButton.HorizontalAlignment = "Right"
$copyButton.ToolTip = "Copy the preview text to the clipboard"
$copyButton.Add_Click({
        # Select all text in the Preview Pane
        $previewPane.SelectAll()
        # Copy the selected text to the clipboard
        $previewPane.Copy()
        # Deselect the text
        $previewPane.SelectionLength = 0
        # Update the status bar
        Update-StatusBar -Message "Text copied to clipboard."
    })

# Create the Preview Pane (TextBox)
$previewPane = New-Object System.Windows.Controls.TextBox
$previewPane.IsReadOnly = $true
$previewPane.VerticalScrollBarVisibility = "Auto"
$previewPane.HorizontalScrollBarVisibility = "Auto"
$previewPane.ToolTip = "Preview of the selected log entry."
$previewPane.VerticalAlignment = "Stretch"  # Ensure it stretches vertically
$previewPane.HorizontalAlignment = "Stretch"  # Ensure it stretches horizontally
$previewPane.Padding = "10"
$previewPane.Margin = $uIMargin

$previewPane.BorderBrush = [System.Windows.Media.Brushes]::Gray
$previewPane.BorderThickness = 1
$previewPane.Background = [System.Windows.Media.Brushes]::White  # Subtle background color for contrast

# Add the Copy Button to Column 2 of the Label and Button Grid
$labelButtonGrid.Children.Add($copyButton)
[System.Windows.Controls.Grid]::SetColumn($copyButton, 2)

# Add the Label and Button Grid to Row 0 of the Preview Pane Grid
$previewPaneGrid.Children.Add($labelButtonGrid)
[System.Windows.Controls.Grid]::SetRow($labelButtonGrid, 0)

# Add the Preview Pane (TextBox) to Row 1 of the Preview Pane Grid
$previewPaneGrid.Children.Add($previewPane)
[System.Windows.Controls.Grid]::SetRow($previewPane, 1)

############ Detailed Info Pane Configuration ##################

# Create the Detailed Info Pane Grid
$detailedInfoPaneGrid = New-Object System.Windows.Controls.Grid
$detailedInfoPaneGrid.Margin = $uIMargin
$detailedInfoPaneGrid.VerticalAlignment = "Stretch"
$detailedInfoPaneGrid.HorizontalAlignment = "Stretch"

# Define rows for the Grid
$detailedInfoPaneGrid.RowDefinitions.Add((New-Object System.Windows.Controls.RowDefinition -Property @{ Height = "Auto" })) # Row 0: Label
$detailedInfoPaneGrid.RowDefinitions.Add((New-Object System.Windows.Controls.RowDefinition -Property @{ Height = "*" }))    # Row 1: TextBox (fills remaining space)

# Add the Detailed Info Pane Grid to the main Grid
$grid.Children.Add($detailedInfoPaneGrid)
[System.Windows.Controls.Grid]::SetRow($detailedInfoPaneGrid, 1)
[System.Windows.Controls.Grid]::SetColumn($detailedInfoPaneGrid, 2)

# Create the Label
$detailedInfoPaneLabel = New-Object System.Windows.Controls.Label
$detailedInfoPaneLabel.Content = "Audit Detail:"
$detailedInfoPaneLabel.FontSize = 18
$detailedInfoPaneLabel.FontWeight = "Bold"

# Add the Label to Row 0 of the Detailed Info Pane Grid
$detailedInfoPaneGrid.Children.Add($detailedInfoPaneLabel)
[System.Windows.Controls.Grid]::SetRow($detailedInfoPaneLabel, 0)

# Create the Detailed Info Pane (TextBox)
$detailedInfoTextBox = New-Object System.Windows.Controls.TextBox
$detailedInfoTextBox.IsReadOnly = $true
$detailedInfoTextBox.VerticalAlignment = "Stretch"  # Ensure it stretches vertically
$detailedInfoTextBox.HorizontalAlignment = "Stretch"  # Ensure it stretches horizontally
$detailedInfoTextBox.VerticalScrollBarVisibility = "Auto"
$detailedInfoTextBox.HorizontalScrollBarVisibility = "Auto"
$detailedInfoTextBox.Padding = "10"
$detailedInfoTextBox.Margin = $uIMargin
$detailedInfoTextBox.ToolTip = "View detailed information about the selected item."
$detailedInfoTextBox.TextWrapping = "Wrap"
$detailedInfoTextBox.BorderBrush = [System.Windows.Media.Brushes]::Gray
$detailedInfoTextBox.BorderThickness = 1
$detailedInfoTextBox.Background = [System.Windows.Media.Brushes]::WhiteSmoke

# Add the TextBox to Row 1 of the Detailed Info Pane Grid
$detailedInfoPaneGrid.Children.Add($detailedInfoTextBox)
[System.Windows.Controls.Grid]::SetRow($detailedInfoTextBox, 1)

################### Filter by Search ###################

# Add a Grid to hold the search components
$searchPanel = New-Object System.Windows.Controls.Grid
$searchPanel.Margin = "10"
$searchPanel.VerticalAlignment = "Center"
$searchPanel.HorizontalAlignment = "Stretch"  # Stretch to fill available space

# Define columns for the search panel
$searchPanel.ColumnDefinitions.Add((New-Object System.Windows.Controls.ColumnDefinition -Property @{ Width = "*" }))  # Column 0: Search Box (fills remaining space)
$searchPanel.ColumnDefinitions.Add((New-Object System.Windows.Controls.ColumnDefinition -Property @{ Width = "Auto" }))  # Column 1: Filter Button (fits content)

# Add Search Box
$searchBox = New-Object System.Windows.Controls.TextBox
$searchBox.Width = [double]::NaN  # Auto-size width to fill available space
$searchBox.Height = 30
$searchBox.Margin = $uIMargin
$searchBox.VerticalAlignment = "Center"
$searchBox.HorizontalAlignment = "Stretch"  # Stretch to fill available space
$searchBox.TextAlignment = "Left"
$searchBox.FontSize = "14"
$searchBox.ToolTip = "Enter a keyword to filter log entries."
$searchBox.Background = "White"
$searchBox.BorderBrush = "Gray"
$searchBox.BorderThickness = "1"
$searchBox.Padding = "5"

# Add Filter Button
$filterButton = New-Object System.Windows.Controls.Button
$filterButton.Content = "Keyword"
$filterButton.Height = 30
$filterButton.Margin = $uIMargin
$filterButton.VerticalAlignment = "Center"
$filterButton.HorizontalAlignment = "Left"
$filterButton.FontSize = "14"
$filterButton.Padding = "10,5,10,5"  # Inner padding (left, top, right, bottom)
$filterButton.BorderThickness = "1"
$filterButton.ToolTip = "Filter log entries based on the search term/keyword."
$filterButton.Add_Click({
        Update-TreeView  # Call the filter function
    })

# Add the search components to the grid
$searchPanel.Children.Add($searchBox)
[System.Windows.Controls.Grid]::SetColumn($searchBox, 0)

$searchPanel.Children.Add($filterButton)
[System.Windows.Controls.Grid]::SetColumn($filterButton, 1)

# Add the search panel to the grid or parent container
$grid.Children.Add($searchPanel)
[System.Windows.Controls.Grid]::SetRow($searchPanel, 0)  # Place in Row 0 (Header)
[System.Windows.Controls.Grid]::SetColumn($searchPanel, 0)  # Place in Column 0

#################### Filter by RecordType, Operation, Date and Time #####################

# Add Advanced Filter Panel
# Define StackPanels for CheckBoxes globally
$recordTypeCheckBoxPanel = New-Object System.Windows.Controls.StackPanel
$operationsCheckBoxPanel = New-Object System.Windows.Controls.StackPanel

# Flag to prevent recursive events
# Define these variables at script scope level (outside any function)
$script:allRecordTypeCheckBox = $null
$script:allOperationsCheckBox = $null
$script:isUpdatingCheckBoxes = $false
# $isUpdatingCheckBoxes = $false

$filterPanel = New-Object System.Windows.Controls.WrapPanel  # Use StackPanel for vertical layout
$filterPanel.Orientation = "Horizontal"
$filterPanel.HorizontalAlignment = "Stretch"
$filterPanel.VerticalAlignment = "Center"
$filterPanel.Margin = "10"
$grid.Children.Add($filterPanel)
[System.Windows.Controls.Grid]::SetRow($filterPanel, 0)
[System.Windows.Controls.Grid]::SetColumn($filterPanel, 1)

# Add Parent Label "Filters"
$filtersLabel = New-Object System.Windows.Controls.Label
$filtersLabel.Content = "Filters:"
$filtersLabel.Margin = $uIMargin
$filtersLabel.VerticalAlignment = "Center"
$filtersLabel.FontSize = "16"
$filtersLabel.FontWeight = "Bold"
$filterPanel.Children.Add($filtersLabel)

# Group RecordType Label and Dropdown
$recordTypeGroup = New-Object System.Windows.Controls.StackPanel
$recordTypeGroup.Orientation = "Horizontal"
$recordTypeGroup.Margin = $uIMargin
$recordTypeGroup.VerticalAlignment = "Center"

# Add Label for RecordType Filter
$recordTypeLabel = New-Object System.Windows.Controls.Label
$recordTypeLabel.Content = "RecordType:"
$recordTypeLabel.Margin = $uIMargin
$recordTypeLabel.VerticalAlignment = "Center"
$recordTypeLabel.FontSize = "14"

# Add RecordType Filter Dropdown
$recordTypeFilter = New-Object System.Windows.Controls.ComboBox
$recordTypeFilter.Width = 150
$recordTypeFilter.Height = $buttonHeight
$recordTypeFilter.Margin = $uIMargin
$recordTypeFilter.ToolTip = "Filter by RecordType"
$recordTypeFilter.FontSize = "14"
$recordTypeFilter.IsEditable = $true  # Allow text input
$recordTypeFilter.IsReadOnly = $true  # Prevent editing the text
$recordTypeFilter.StaysOpenOnEdit = $true  # Keep dropdown open when clicking
$recordTypeFilter.Add_SelectionChanged({
        Update-TreeView
    })

# Add Label and Dropdown to the RecordType Group
$recordTypeGroup.Children.Add($recordTypeLabel)
$recordTypeGroup.Children.Add($recordTypeFilter)

# Group Operations Label and Dropdown
$operationsGroup = New-Object System.Windows.Controls.StackPanel
$operationsGroup.Orientation = "Horizontal"
$operationsGroup.Margin = $uIMargin
$operationsGroup.VerticalAlignment = "Center"

# Add Label for Operations Filter
$operationsLabel = New-Object System.Windows.Controls.Label
$operationsLabel.Content = "Operation:"
$operationsLabel.Margin = $uIMargin
$operationsLabel.VerticalAlignment = "Center"
$operationsLabel.FontSize = "14"

# Add Operations Filter Dropdown
$operationsFilter = New-Object System.Windows.Controls.ComboBox
$operationsFilter.Width = 150
$operationsFilter.Height = 25
$operationsFilter.Margin = $uIMargin
$operationsFilter.ToolTip = "Filter by Operations"
$operationsFilter.FontSize = "14"
$operationsFilter.IsEditable = $true  # Allow text input
$operationsFilter.IsReadOnly = $true  # Prevent editing the text
$operationsFilter.StaysOpenOnEdit = $true  # Keep dropdown open when clicking
$operationsFilter.Add_SelectionChanged({
        Update-TreeView
    })

# Add Label and Dropdown to the Operations Group
$operationsGroup.Children.Add($operationsLabel)
$operationsGroup.Children.Add($operationsFilter)

# Group Date Range Label, Start Date, and End Date
$dateRangeGroup = New-Object System.Windows.Controls.StackPanel
$dateRangeGroup.Orientation = "Horizontal"
$dateRangeGroup.Margin = $uIMargin
$dateRangeGroup.VerticalAlignment = "Center"

# Add Label for Date Range Filter
$dateRangeLabel = New-Object System.Windows.Controls.Label
$dateRangeLabel.Content = "Date Range:"
$dateRangeLabel.Margin = $uIMargin
$dateRangeLabel.VerticalAlignment = "Center"
$dateRangeLabel.FontSize = "14"

# Add Start Date Picker
$startDatePicker = New-Object System.Windows.Controls.DatePicker
$startDatePicker.Width = 110
$startDatePicker.Margin = $uIMargin
$startDatePicker.ToolTip = "Select start date"
$startDatePicker.FontSize = "14"
$startDatePicker.Add_SelectedDateChanged({
        Update-TreeView
    })

# Add End Date Picker
$endDatePicker = New-Object System.Windows.Controls.DatePicker
$endDatePicker.Width = 110
$endDatePicker.Margin = $uIMargin
$endDatePicker.ToolTip = "Select end date"
$endDatePicker.FontSize = "14"
$endDatePicker.Add_SelectedDateChanged({
        Update-TreeView
    })

# Add Date Range components to the Date Range Group
$dateRangeGroup.Children.Add($dateRangeLabel)
$dateRangeGroup.Children.Add($startDatePicker)
$dateRangeGroup.Children.Add($endDatePicker)

# Group Time Label, Start Time, and End Time
$timeGroup = New-Object System.Windows.Controls.StackPanel
$timeGroup.Orientation = "Horizontal"
$timeGroup.Margin = $uIMargin
$timeGroup.VerticalAlignment = "Center"

# Add Label for Time Filter
$timeLabel = New-Object System.Windows.Controls.Label
$timeLabel.Content = "Time:"
$timeLabel.Margin = $uIMargin
$timeLabel.VerticalAlignment = "Center"
$timeLabel.FontSize = "14"

# Add Start Time ComboBox
$startTimeComboBox = New-Object System.Windows.Controls.ComboBox
$startTimeComboBox.Width = 80
$startTimeComboBox.Margin = $uIMargin
$startTimeComboBox.ToolTip = "Select start time"
$startTimeComboBox.IsEditable = $true  # Allow manual input
$startTimeComboBox.Text = "00:00:00"   # Default start time
$startTimeComboBox.FontSize = "14"
$startTimeComboBox.AddHandler([System.Windows.Controls.TextBox]::TextChangedEvent, [System.Windows.RoutedEventHandler] {
        Update-TreeView
    })

# Add End Time ComboBox
$endTimeComboBox = New-Object System.Windows.Controls.ComboBox
$endTimeComboBox.Width = 80
$endTimeComboBox.Margin = $uIMargin
$endTimeComboBox.ToolTip = "Select end time"
$endTimeComboBox.IsEditable = $true    # Allow manual input
$endTimeComboBox.Text = "23:59:59"     # Default end time
$endTimeComboBox.FontSize = "14"
$endTimeComboBox.AddHandler([System.Windows.Controls.TextBox]::TextChangedEvent, [System.Windows.RoutedEventHandler] {
        Update-TreeView
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

# Add Time components to the Time Group
$timeGroup.Children.Add($timeLabel)
$timeGroup.Children.Add($startTimeComboBox)
$timeGroup.Children.Add($endTimeComboBox)

# Add groups to the filter panel
$filterPanel.Children.Add($recordTypeGroup)
$filterPanel.Children.Add($operationsGroup)
$filterPanel.Children.Add($dateRangeGroup)
$filterPanel.Children.Add($timeGroup)

################ Other feature ####################

# Add a StackPanel to Row 1, Column 1 for buttons
$buttonPanel = New-Object System.Windows.Controls.WrapPanel
$buttonPanel.Orientation = "Horizontal"
$buttonPanel.HorizontalAlignment = "Stretch"
$buttonPanel.VerticalAlignment = "Center"
$buttonPanel.Margin = "10"
$grid.Children.Add($buttonPanel)
[System.Windows.Controls.Grid]::SetRow($buttonPanel, 0)
[System.Windows.Controls.Grid]::SetColumn($buttonPanel, 2)

# Add Export to JSON Button
$exportJsonButton = New-Object System.Windows.Controls.Button
$exportJsonButton.Content = "Export to JSON"
$exportJsonButton.Width = $buttonWidth
$exportJsonButton.Height = $buttonHeight
$exportJsonButton.Margin = $uIMargin
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
$exportCsvButton.Width = $buttonWidth
$exportCsvButton.Height = $buttonHeight
$exportCsvButton.Margin = $uIMargin
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
$refreshButton.Width = $buttonWidth
$refreshButton.Height = $buttonHeight
$refreshButton.Margin = $uIMargin
$refreshButton.ToolTip = "Refresh reloads the data sets"
$refreshButton.Add_Click({
    # Prevent triggering events while updating
    $isUpdatingCheckBoxes = $true

    # Clear all filters
    $searchBox.Text = ""
    $recordTypeFilter.SelectedIndex = -1
    $operationsFilter.SelectedIndex = -1
    $startDatePicker.SelectedDate = $null
    $endDatePicker.SelectedDate = $null
    $startTimeComboBox.Text = "00:00:00"
    $endTimeComboBox.Text = "23:59:59"

    # Clear the TreeView
    $treeView.Items.Clear()

    # Reload the data if a file was previously loaded via drag-and-drop or double-click
    if ($global:logDataArray) {
        $global:logDataArray = $global:logDataArray  # Reuse existing data
    }
    else {
        # If no data is loaded, prompt the user to select a file
        $openFileDialog = New-Object Microsoft.Win32.OpenFileDialog
        $openFileDialog.Filter = "CSV Files (*.csv)|*.csv|JSON Files (*.json)|*.json"
        $openFileDialog.Title = "Select a CSV or JSON file to load"

        if ($openFileDialog.ShowDialog() -eq $true) {
            $filePath = $openFileDialog.FileName

            if (Test-ValidFile -FilePath $filePath) {
                $global:logDataArray = Load-DataFromFile -FilePath $filePath
            }
        }
    }

    if ($null -ne $global:logDataArray) {
        Update-Filters  # Ensure filters are populated correctly

        # Ensure "All" is checked for RecordType filter
        foreach ($checkBox in $recordTypeCheckBoxPanel.Children) {
            if ($checkBox.Content -eq "All") {
                $checkBox.IsChecked = $true
            } else {
                $checkBox.IsChecked = $false
            }
        }
        Update-SelectedRecordTypes  # Ensure UI updates correctly

        # Ensure "All" is checked for Operations filter
        foreach ($checkBox in $operationsCheckBoxPanel.Children) {
            if ($checkBox.Content -eq "All") {
                $checkBox.IsChecked = $true
            } else {
                $checkBox.IsChecked = $false
            }
        }
        Update-SelectedOperations  # Ensure UI updates correctly

        Update-TreeView
        Update-StatusBar -Message "Data refreshed successfully! 'All' selected for RecordType & Operations."
    }
    else {
        Update-StatusBar -Message "No data loaded."
    }

    # Re-enable updates
    $isUpdatingCheckBoxes = $false
})


# Add Theme Toggle Button
$themeButton = New-Object System.Windows.Controls.Button
$themeButton.Content = "Toggle Theme"
$themeButton.Width = $buttonWidth
$themeButton.Height = $buttonHeight
$themeButton.ToolTip = "Change UI to dark mode"
$themeButton.Margin = $uIMargin
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
$expandButton.Width = $buttonWidth
$expandButton.Height = $buttonHeight
$expandButton.Margin = $uIMargin
$expandButton.ToolTip = "Expand all collapsed logs"
$expandButton.Add_Click({
        foreach ($item in $treeView.Items) {
            $item.IsExpanded = $true
        }
    })

$collapseButton = New-Object System.Windows.Controls.Button
$collapseButton.Content = "Collapse All"
$collapseButton.Width = $buttonWidth
$collapseButton.Height = $buttonHeight
$collapseButton.Margin = $uIMargin
$collapseButton.ToolTip = "Collapse all expanded logs"
$collapseButton.Add_Click({
        foreach ($item in $treeView.Items) {
            $item.IsExpanded = $false
        }
    })

$clearFiltersButton = New-Object System.Windows.Controls.Button
$clearFiltersButton.Content = "Clear Filters"
$clearFiltersButton.Width = $buttonWidth
$clearFiltersButton.Height = $buttonHeight
$clearFiltersButton.Margin = $uIMargin
$clearFiltersButton.Add_Click({
    # Prevent triggering events while updating
    $isUpdatingCheckBoxes = $true

    # Clear search box
    $searchBox.Text = ""

    # Reset RecordType (RecipientType) filter
    foreach ($checkBox in $recordTypeCheckBoxPanel.Children) {
        if ($checkBox.Content -eq "All") {
            $checkBox.IsChecked = $true  # Ensure "All" is checked
        } else {
            $checkBox.IsChecked = $false  # Uncheck all other options
        }
    }
    Update-SelectedRecordTypes  # Ensure UI updates after resetting

    # Reset Operations filter
    foreach ($checkBox in $operationsCheckBoxPanel.Children) {
        if ($checkBox.Content -eq "All") {
            $checkBox.IsChecked = $true  # Ensure "All" is checked
        } else {
            $checkBox.IsChecked = $false  # Uncheck all other options
        }
    }
    Update-SelectedOperations  # Ensure UI updates after resetting

    # Reset date and time filters
    $startDatePicker.SelectedDate = $null
    $endDatePicker.SelectedDate = $null
    $startTimeComboBox.Text = "00:00:00"
    $endTimeComboBox.Text = "23:59:59"

    # Update the TreeView
    Update-TreeView

    # Re-enable event handlers
    $isUpdatingCheckBoxes = $false

    # Update the status bar
    Update-StatusBar -Message "Filters cleared. 'All' is selected for both RecordType and Operations."
})



# Add Clear Audit Data Button (NEW: Added for clearing all data)
$clearLoadedData = New-Object System.Windows.Controls.Button
$clearLoadedData.Content = "Clear Audit Data"
$clearLoadedData.Width = $buttonWidth
$clearLoadedData.Height = $buttonHeight
$clearLoadedData.Margin = $uIMargin
$clearLoadedData.ToolTip = "Clear all loaded data and reset the UI"
$clearLoadedData.Add_Click({
    # Prevent triggering events while updating
    $isUpdatingCheckBoxes = $true

    # Clear search box
    $searchBox.Text = ""

    # Fully remove all RecordType (RecipientType) filter options
    $recordTypeCheckBoxPanel.Children.Clear()
    Update-SelectedRecordTypes  # Ensure UI updates correctly

    # Fully remove all Operations filter options
    $operationsCheckBoxPanel.Children.Clear()
    Update-SelectedOperations  # Ensure UI updates correctly

    # Reset date and time filters
    $startDatePicker.SelectedDate = $null
    $endDatePicker.SelectedDate = $null
    $startTimeComboBox.Text = "00:00:00"
    $endTimeComboBox.Text = "23:59:59"

    # Fully clear the TreeView
    $treeView.Items.Clear()

    # Fully reset global data
    $global:logDataArray = @()  # Empty array instead of $null for stability

    # Update the status bar
    Update-StatusBar -Message "All data cleared. No RecordType or Operations entries remain."

    # Re-enable updates
    $isUpdatingCheckBoxes = $false
})


# Add buttons to the button panel
$buttonPanel.Children.Add($exportJsonButton)
$buttonPanel.Children.Add($exportCsvButton)
$buttonPanel.Children.Add($refreshButton)
$buttonPanel.Children.Add($expandButton)
$buttonPanel.Children.Add($collapseButton)
$buttonPanel.Children.Add($clearFiltersButton)
$buttonPanel.Children.Add($clearLoadedData)
$buttonPanel.Children.Add($themeButton)

###################################################

# Create a Grid for the status bar and progress bar
$statusBarGrid = New-Object System.Windows.Controls.Grid
$statusBarGrid.Margin = $uIMargin
$statusBarGrid.VerticalAlignment = "Bottom"
$statusBarGrid.HorizontalAlignment = "Stretch"
$statusBarGrid.Background = [System.Windows.Media.Brushes]::LightGray

# Define columns for the status bar grid
$statusBarGrid.ColumnDefinitions.Add((New-Object System.Windows.Controls.ColumnDefinition -Property @{ Width = "Auto" }))  # Column 0: Status text
$statusBarGrid.ColumnDefinitions.Add((New-Object System.Windows.Controls.ColumnDefinition -Property @{ Width = "*" }))    # Column 1: Spacer
$statusBarGrid.ColumnDefinitions.Add((New-Object System.Windows.Controls.ColumnDefinition -Property @{ Width = "Auto" }))  # Column 2: Progress bar

# Add the status bar grid to the main grid
$grid.Children.Add($statusBarGrid)
[System.Windows.Controls.Grid]::SetRow($statusBarGrid, 2)
[System.Windows.Controls.Grid]::SetColumnSpan($statusBarGrid, 3)  # Span across all columns

# Create a TextBlock for status messages
$statusBar = New-Object System.Windows.Controls.TextBlock
$statusBar.VerticalAlignment = "Center"
$statusBar.HorizontalAlignment = "Left"
$statusBar.Text = "Unified log analyzer application started successfully."
$statusBar.FontSize = "14"
$statusBar.FontWeight = "Normal"
$statusBar.Margin = "5,0,0,0"

# Add the TextBlock to the first column of the status bar grid
$statusBarGrid.Children.Add($statusBar)
[System.Windows.Controls.Grid]::SetColumn($statusBar, 0)

# Create a ProgressBar for loading/processing status
$progressBar = New-Object System.Windows.Controls.ProgressBar
$progressBar.Width = 200
$progressBar.Height = $buttonHeight
$progressBar.Margin = $uIMargin
$progressBar.VerticalAlignment = "Center"
$progressBar.HorizontalAlignment = "Right"
$progressBar.IsIndeterminate = $false  # Set to $true for indeterminate progress
$progressBar.Visibility = "Visible"  # Visible by default

# Add the ProgressBar to the last column of the status bar grid
$statusBarGrid.Children.Add($progressBar)
[System.Windows.Controls.Grid]::SetColumn($progressBar, 2)

# Example: Update status bar with a message and progress
function Update-StatusBar {
    param (
        [string]$Message,
        [int]$Progress = -1  # -1 means no progress bar
    )

    # Update the status text
    $statusBar.Text = $Message
}

# Function to Update the Preview Pane
function Format-PropertyValue {
    param (
        [object]$Value,
        [int]$IndentLevel = 0
    )

    $indent = "  " * $IndentLevel  # Create indentation based on the nesting level

    if ($null -eq $Value) {
        return "${indent}N/A"
    }
    elseif ($Value -is [array]) {
        $result = @()
        foreach ($item in $Value) {
            $result += Format-PropertyValue -Value $item -IndentLevel ($IndentLevel + 1)
        }
        return $result -join "`n"
    }
    elseif ($Value -is [System.Management.Automation.PSCustomObject] -or $Value -is [System.Collections.IDictionary]) {
        $result = @()
        foreach ($key in $Value.PSObject.Properties.Name) {
            $subValue = Format-PropertyValue -Value $Value.$key -IndentLevel ($IndentLevel + 1)
            
            # If the value is an array or nested object, format it with proper indentation
            if ($Value.$key -is [array] -or $Value.$key -is [System.Management.Automation.PSCustomObject]) {
                $result += "${indent}- ${key}:`n$subValue"
            }
            else {
                $result += "${indent}- ${key}: $subValue"
            }
        }
        return $result -join "`n"
    }
    elseif ($Value -is [string]) {
        # Attempt to parse JSON strings
        try {
            $parsedValue = $Value | ConvertFrom-Json -ErrorAction Stop
            return Format-PropertyValue -Value $parsedValue -IndentLevel $IndentLevel
        }
        catch {
            # If parsing fails, treat it as a regular string
            return "${indent}$($Value)"
        }
    }
    else {
        return "${indent}$($Value.ToString())"
    }
}

function Update-PreviewPane {
    param (
        [object]$SelectedItem
    )

    if ($null -eq $SelectedItem) {
        $previewPane.Text = "No log entry selected."
        return
    }

    # Extract all properties dynamically
    $previewText = @()

    $previewText += "===== Log Entry =====`n"
    
    foreach ($key in $SelectedItem.PSObject.Properties.Name) {
        $value = $SelectedItem.$key
        $formattedValue = Format-PropertyValue -Value $value
        $previewText += "$($key):   $($formattedValue)`n"
    }

    $previewText += "`n===== Log End =====`n"

    # Update the Preview Pane
    $previewPane.Text = $previewText -join ""
}

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
                    $detailedInfoTextBox.Text = "Null or empty data"
                }
                else {
                    $detailedInfoTextBox.Text = $sender.Tag | ConvertTo-Json -Depth 10
                }
            }
        )

        # Highlight search results if a search term is provided
        if (-not [string]::IsNullOrEmpty($searchBox.Text)) {
            $searchText = $searchBox.Text
            $text = if ($null -eq $value) { "" } else { $value.ToString() }

            if ($regexCheckBox.IsChecked) {
                try {
                    $matchesText = [regex]::Matches($text, $searchText)
                    $lastIndex = 0
                    $textBlock = New-Object System.Windows.Controls.TextBlock

                    foreach ($match in $matchesText) {
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
    Update-StatusBar -Message "Loading data..."

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
        Update-StatusBar -Message "Loading item $currentCount of $totalCount..."

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
    Update-StatusBar -Message "Data loaded successfully!"

    return $logDataArray
}

# Function to update the selected RecordTypes
function Update-SelectedRecordTypes {
    # Get selected RecordTypes
    $selectedRecordTypes = $recordTypeCheckBoxPanel.Children | Where-Object { $_.IsChecked -eq $true } | ForEach-Object { $_.Content }

    # Update the ComboBox text
    $recordTypeFilter.Text = $selectedRecordTypes -join ", "

    # Update the TreeView (or other UI elements)
    Update-TreeView
}

function Update-SelectedOperations {
    # Get selected Operations
    $selectedOperations = $operationsCheckBoxPanel.Children | Where-Object { $_.IsChecked -eq $true } | ForEach-Object { $_.Content }

    # Update the ComboBox text
    $operationsFilter.Text = $selectedOperations -join ", "

    # Update the TreeView (or other UI elements)
    Update-TreeView
}
# Function to populate dropdowns with unique values


function Update-Filters {
    # Clear existing items
    $recordTypeFilter.Items.Clear()
    $operationsFilter.Items.Clear()

    # Clear existing CheckBoxes
    $recordTypeCheckBoxPanel.Children.Clear()
    $operationsCheckBoxPanel.Children.Clear()

    # Add "All" option to RecordType dropdown
    $script:allRecordTypeCheckBox = New-Object System.Windows.Controls.CheckBox
    $script:allRecordTypeCheckBox.Content = "All"
    $script:allRecordTypeCheckBox.Margin = "2"
    $script:allRecordTypeCheckBox.IsChecked = $true  # Default to checked

    $script:allRecordTypeCheckBox.Add_Checked({
        if (-not $script:isUpdatingCheckBoxes) {
            $script:isUpdatingCheckBoxes = $true
            foreach ($checkBox in $recordTypeCheckBoxPanel.Children) {
                if ($checkBox -ne $script:allRecordTypeCheckBox) {
                    $checkBox.IsChecked = $false
                }
            }
            Update-SelectedRecordTypes
            $script:isUpdatingCheckBoxes = $false
        }
    })

    $script:allRecordTypeCheckBox.Add_Unchecked({
        if (-not $script:isUpdatingCheckBoxes) {
            $script:isUpdatingCheckBoxes = $true
            Update-SelectedRecordTypes
            $script:isUpdatingCheckBoxes = $false
        }
    })

    # Add the "All" CheckBox for RecordType to the StackPanel
    $recordTypeCheckBoxPanel.Children.Add($script:allRecordTypeCheckBox)

    # Get unique RecordType values
    $uniqueRecordTypes = $logDataArray | ForEach-Object { $_.RecordType } | Sort-Object -Unique

    # Add unique RecordType values with CheckBoxes
    foreach ($recordType in $uniqueRecordTypes) {
        $checkBox = New-Object System.Windows.Controls.CheckBox
        $checkBox.Content = $recordType
        $checkBox.Margin = "2"

        $checkBox.Add_Checked({
            if (-not $script:isUpdatingCheckBoxes) {
                $script:isUpdatingCheckBoxes = $true
                $script:allRecordTypeCheckBox.IsChecked = $false  # Ensure "All" is unchecked
                Update-SelectedRecordTypes
                $script:isUpdatingCheckBoxes = $false
            }
        })

        $checkBox.Add_Unchecked({
            if (-not $script:isUpdatingCheckBoxes) {
                $script:isUpdatingCheckBoxes = $true
                if (-not ($recordTypeCheckBoxPanel.Children | Where-Object { $_.IsChecked -eq $true -and $_.Content -ne "All" })) {
                    $script:allRecordTypeCheckBox.IsChecked = $true  # Recheck "All" if no others are checked
                }
                Update-SelectedRecordTypes
                $script:isUpdatingCheckBoxes = $false
            }
        })

        $recordTypeCheckBoxPanel.Children.Add($checkBox)
    }

    $recordTypeFilter.Items.Add($recordTypeCheckBoxPanel)

    # Add "All" option to Operations dropdown
    $script:allOperationsCheckBox = New-Object System.Windows.Controls.CheckBox
    $script:allOperationsCheckBox.Content = "All"
    $script:allOperationsCheckBox.Margin = "2"
    $script:allOperationsCheckBox.IsChecked = $true  # Default to checked

    $script:allOperationsCheckBox.Add_Checked({
        if (-not $script:isUpdatingCheckBoxes) {
            $script:isUpdatingCheckBoxes = $true
            foreach ($checkBox in $operationsCheckBoxPanel.Children) {
                if ($checkBox -ne $script:allOperationsCheckBox) {
                    $checkBox.IsChecked = $false
                }
            }
            Update-SelectedOperations
            $script:isUpdatingCheckBoxes = $false
        }
    })

    $script:allOperationsCheckBox.Add_Unchecked({
        if (-not $script:isUpdatingCheckBoxes) {
            $script:isUpdatingCheckBoxes = $true
            Update-SelectedOperations
            $script:isUpdatingCheckBoxes = $false
        }
    })

    # Add the "All" CheckBox for Operations to the StackPanel
    $operationsCheckBoxPanel.Children.Add($script:allOperationsCheckBox)

    # Get unique Operations values
    $uniqueOperations = $logDataArray | ForEach-Object { $_.Operations } | Sort-Object -Unique

    # Add unique Operations values with CheckBoxes
    foreach ($operation in $uniqueOperations) {
        $checkBox = New-Object System.Windows.Controls.CheckBox
        $checkBox.Content = $operation
        $checkBox.Margin = "2"

        $checkBox.Add_Checked({
            if (-not $script:isUpdatingCheckBoxes) {
                $script:isUpdatingCheckBoxes = $true
                $script:allOperationsCheckBox.IsChecked = $false  # Ensure "All" is unchecked
                Update-SelectedOperations
                $script:isUpdatingCheckBoxes = $false
            }
        })

        $checkBox.Add_Unchecked({
            if (-not $script:isUpdatingCheckBoxes) {
                $script:isUpdatingCheckBoxes = $true
                if (-not ($operationsCheckBoxPanel.Children | Where-Object { $_.IsChecked -eq $true -and $_.Content -ne "All" })) {
                    $script:allOperationsCheckBox.IsChecked = $true  # Recheck "All" if no others are checked
                }
                Update-SelectedOperations
                $script:isUpdatingCheckBoxes = $false
            }
        })

        $operationsCheckBoxPanel.Children.Add($checkBox)
    }

    $operationsFilter.Items.Add($operationsCheckBoxPanel)
}

# # # Function to Filter TreeView
function Update-TreeView {
    # Get selected RecordTypes, excluding "All" if it's checked
    $selectedRecordTypes = $recordTypeCheckBoxPanel.Children | Where-Object { $_.IsChecked -eq $true -and $_.Content -ne "All" } | ForEach-Object { $_.Content }
    $isAllRecordTypesChecked = ($recordTypeCheckBoxPanel.Children | Where-Object { $_.Content -eq "All" }).IsChecked

    # Get selected Operations, excluding "All" if it's checked
    $selectedOperations = $operationsCheckBoxPanel.Children | Where-Object { $_.IsChecked -eq $true -and $_.Content -ne "All" } | ForEach-Object { $_.Content }
    $isAllOperationsChecked = ($operationsCheckBoxPanel.Children | Where-Object { $_.Content -eq "All" }).IsChecked

    # Combine date and time for start and end filters
    
    $startDate = $startDatePicker.SelectedDate
    $startTime = $startTimeComboBox.Text
    $endDate = $endDatePicker.SelectedDate
    $endTime = $endTimeComboBox.Text

    # Parse start and end DateTime
    $startDateTime = $null
    $endDateTime = $null

    if ($null -ne $startDate -and -not [string]::IsNullOrEmpty($startTime)) {
        try {
            $startDateTime = [datetime]::ParseExact("$($startDate.ToString('MM/dd/yyyy')) $startTime", "MM/dd/yyyy HH:mm:ss", $null)
        }
        catch {
            Write-Warning "Invalid start date or time format."
        }
    }

    if ($null -ne $endDate -and -not [string]::IsNullOrEmpty($endTime)) {
        try {
            $endDateTime = [datetime]::ParseExact("$($endDate.ToString('MM/dd/yyyy')) $endTime", "MM/dd/yyyy HH:mm:ss", $null)
        }
        catch {
            Write-Warning "Invalid end date or time format."
        }
    }

    # Clear the TreeView before populating it
    $treeView.Items.Clear()

    # Iterate through log data and apply filters
    foreach ($logData in $logDataArray) {
        $logDate = $null

        # Parse the log entry's CreationDate
        if (-not [string]::IsNullOrEmpty($logData.CreationDate)) {
            $dateFormats = @("M/d/yyyy h:mm:ss tt", "MM/dd/yyyy HH:mm:ss", "yyyy-MM-ddTHH:mm:ss", "yyyy/MM/dd HH:mm:ss")

            $parsedSuccessfully = $false
            foreach ($format in $dateFormats) {
                try {
                    $logDate = [datetime]::ParseExact($logData.CreationDate, $format, $null)
                    $parsedSuccessfully = $true
                    break  # Exit loop once parsing succeeds
                }
                catch {
                    continue  # Try the next format
                }
            }

            if (-not $parsedSuccessfully) {
                Write-Warning "Failed to parse CreationDate for entry: $($logData.CreationDate)"
                continue  # Skip this entry if parsing fails
            }
        }

        # Apply filters
        $matchesRecordType = $isAllRecordTypesChecked -or $logData.RecordType -in $selectedRecordTypes
        $matchesOperation = $isAllOperationsChecked -or $logData.Operations -in $selectedOperations
        $matchesSearch = ($logData.AuditData -match $searchBox.Text -or $logData.ResultIndex -match $searchBox.Text)
        $matchesDateRange = ($null -eq $startDateTime -or $logDate -ge $startDateTime) -and ($null -eq $endDateTime -or $logDate -le $endDateTime)

        # If all filters match, add the log entry to the TreeView
        if ($matchesRecordType -and $matchesOperation -and $matchesSearch -and $matchesDateRange) {
            $entryNode = New-Object System.Windows.Controls.TreeViewItem
            $entryNode.Header = "$($logData.RecordType) - $($logData.Operations)"
            $entryNode.Tag = $logData  # Store the log entry data in the Tag property
            $treeView.Items.Add($entryNode)

            # Add child nodes for AuditData and other properties
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



# Load initial data if provided via -InputData
if ($PSBoundParameters.ContainsKey('InputData')) {
    if ($InputData -is [string] -and (Test-Path $InputData)) {
        # Load from CSV file
        $global:logDataArray = Load-DataFromFile -FilePath $InputData
    }
    elseif ($InputData -is [System.Collections.IEnumerable]) {
        # Use in-memory data
        $global:logDataArray = $InputData
    }
    else {
        [System.Windows.MessageBox]::Show("Error: Invalid input. Provide a valid CSV file path or in-memory data.") | Out-Null
        exit
    }

    if ($null -ne $global:logDataArray) {
        Update-Filters
        Update-TreeView
        Update-StatusBar -Message "Data loaded successfully from input parameter."
    }
}

# Show Window
$window.ShowDialog()