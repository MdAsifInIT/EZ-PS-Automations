# IntuneWin Bulk Packaging Script v2.0 - Unattended Edition
#
# This PowerShell script automates the bulk creation of .intunewin files for Microsoft Intune Win32 app deployment.
#
# Functionality:
# - Processes multiple application packages in a parent folder structure
# - Locates Deploy-Application.exe in App subfolder or package root
# - Creates .intunewin files using Microsoft Win32 Content Prep Tool
# - Renames output files to match package folder names
# - Validates all paths and prerequisites before processing
# - Logs all actions, errors, and summary statistics with detailed output
# - Designed for completely unattended execution (no user prompts)
# - Suitable for automation, scheduled tasks, and CI/CD pipelines
#
# Script Updated on: 10-07-2025

param(
    [Parameter(Mandatory = $false)]
    [string]$ParentFolderPath = $null,

    [Parameter(Mandatory = $false)]
    [string]$LogPath = $null
)

# Disable confirmation prompts and progress bars for unattended execution
$ConfirmPreference = 'None'
$ProgressPreference = 'SilentlyContinue'
$ErrorActionPreference = 'Stop'

#region Configuration Variables - MODIFY THESE AS NEEDED

# ============================================================================
# PATH CONFIGURATION
# ============================================================================

# Parent folder containing all application package subfolders
# REQUIRED: Must be set here or provided via -ParentFolderPath parameter
# Example: 'C:\Temp\Packages' or '\\server\share\Packages'
[string]$script:defaultParentFolderPath = 'C:\Temp\Packages'

# Name of the subfolder within each package containing app files
# Example: If your structure is "Package\App\Deploy-Application.exe", set this to "App"
[string]$script:appFolderName = 'App'

# Name of the output folder where .intunewin files will be created
# This folder will be created inside each package folder or in the parent directory
[string]$script:outputFolderName = 'Intune'

# ============================================================================
# FILE CONFIGURATION
# ============================================================================

# Name of the deployment executable file to package
# This is the setup file that will be packaged into the .intunewin file
[string]$script:deployAppName = 'Deploy-Application.exe'

# Path to IntuneWinAppUtil.exe (Microsoft Win32 Content Prep Tool)
# Can be relative path, full path, or just filename if in PATH/same directory
# Download from: https://github.com/microsoft/Microsoft-Win32-Content-Prep-Tool
[string]$script:intuneWinUtilPath = 'IntuneWinAppUtil.exe'

# Output file naming pattern
# Use {FolderName} as placeholder for the package folder name
# Example: "{FolderName}.intunewin" will create "MyApp.intunewin" for folder "MyApp"
[string]$script:outputFilePattern = '{FolderName}.intunewin'

# ============================================================================
# PROCESSING CONFIGURATION
# ============================================================================

# Automatically skip folders that don't contain the deployment executable
# $true = Skip and continue processing other folders
# $false = Treat as error and increment failure count
[bool]$script:autoSkipInvalidFolders = $true

# Remove existing .intunewin files before creating new ones
# $true = Always overwrite existing files
# $false = Keep existing files (may cause errors)
[bool]$script:overwriteExistingFiles = $true

# Determine output folder location
# $true = Create output folder at parent level (one shared output folder)
# $false = Create output folder inside each package folder (separate output per package)
[bool]$script:centralizedOutputFolder = $false

# Show detailed processing information for each package
# This provides comprehensive logging of all operations
[bool]$script:showDetailedOutput = $true

#endregion Configuration Variables

#region Core Functions - DO NOT MODIFY UNLESS NECESSARY

# ============================================================================
# LOGGING FUNCTIONS
# ============================================================================

function Write-Log {
    <#
    .SYNOPSIS
        Writes log messages to console and optionally to a log file.
    .PARAMETER Message
        The message to log.
    .PARAMETER Level
        The severity level (Info, Warning, Error, Success, Verbose).
    .PARAMETER FunctionName
        The name of the function generating the log.
    .PARAMETER LineNumber
        The line number where the log was generated.
    #>
    param (
        [Parameter(Mandatory = $true)]
        [string]$Message,
        
        [ValidateSet('Info', 'Warning', 'Error', 'Success', 'Verbose')]
        [string]$Level = 'Info',
        
        [string]$FunctionName = $null,
        
        [int]$LineNumber = $null
    )

    $timestamp = Get-Date -Format "yyyy-MM-dd HH:mm:ss"
    $context = ''
    if ($FunctionName) { $context += " [$FunctionName]" }
    if ($LineNumber) { $context += " [Line $LineNumber]" }
    $logMessage = "[$timestamp] [$Level]$context $Message"
    
    # Console output with color coding
    switch ($Level) {
        'Error'   { Write-Host $logMessage -ForegroundColor Red }
        'Warning' { Write-Host $logMessage -ForegroundColor Yellow }
        'Success' { Write-Host $logMessage -ForegroundColor Green }
        'Verbose' { Write-Host $logMessage -ForegroundColor Cyan }
        default   { Write-Host $logMessage }
    }

    # Write to log file if LogPath is set
    if (-not [string]::IsNullOrWhiteSpace($script:LogPath)) {
        try {
            $logDir = Split-Path -Path $script:LogPath -Parent
            if ($logDir -and -not (Test-Path -Path $logDir)) {
                New-Item -Path $logDir -ItemType Directory -Force -ErrorAction Stop | Out-Null
            }
            Add-Content -Path $script:LogPath -Value $logMessage -ErrorAction SilentlyContinue
        }
        catch {
            Write-Host "[$timestamp] [Warning] Failed to write to log file: $_" -ForegroundColor Yellow
        }
    }
}

# ============================================================================
# SCRIPT MANAGEMENT FUNCTIONS
# ============================================================================

$script:exitCode = 0

function Exit-Script {
    <#
    .SYNOPSIS
        Exits the script with the appropriate exit code.
    .PARAMETER ExitCode
        The exit code to return (0 = success, 1 = failure).
    #>
    param (
        [int]$ExitCode = $script:exitCode
    )

    Write-Log "Script completed with exit code: $ExitCode" -Level $(if ($ExitCode -eq 0) { 'Success' } else { 'Error' })
    exit $ExitCode
}

function Initialize-Configuration {
    <#
    .SYNOPSIS
        Initializes and validates script configuration.
    #>
    
    Write-Log "Initializing configuration for unattended execution" -Level 'Info'

    # Set parent folder path from parameter or default
    if ([string]::IsNullOrWhiteSpace($ParentFolderPath)) {
        $script:ParentFolderPath = $script:defaultParentFolderPath
    }
    else {
        $script:ParentFolderPath = $ParentFolderPath
    }

    Write-Log "Configuration Details:" -Level 'Info'
    Write-Log "  App Folder Name: $script:appFolderName" -Level 'Verbose'
    Write-Log "  Output Folder Name: $script:outputFolderName" -Level 'Verbose'
    Write-Log "  Deploy App Name: $script:deployAppName" -Level 'Verbose'
    Write-Log "  IntuneWinAppUtil Path: $script:intuneWinUtilPath" -Level 'Verbose'
    Write-Log "  Output File Pattern: $script:outputFilePattern" -Level 'Verbose'
    Write-Log "  Centralized Output: $script:centralizedOutputFolder" -Level 'Verbose'
    Write-Log "  Auto Skip Invalid: $script:autoSkipInvalidFolders" -Level 'Verbose'
    Write-Log "  Overwrite Existing: $script:overwriteExistingFiles" -Level 'Verbose'
    Write-Log "Configuration initialized successfully" -Level 'Success'
}

# ============================================================================
# VALIDATION FUNCTIONS
# ============================================================================

function Test-Prerequisites {
    <#
    .SYNOPSIS
        Validates that all required tools and paths exist.
    .OUTPUTS
        Boolean indicating whether prerequisites are met.
    #>
    
    Write-Log "Validating prerequisites" -Level 'Info'

    # Validate IntuneWinAppUtil exists
    $intuneUtilFullPath = $null
    
    # Check if it's a full path
    if (Test-Path -Path $script:intuneWinUtilPath -PathType Leaf) {
        $intuneUtilFullPath = $script:intuneWinUtilPath
    }
    # Check in script directory
    elseif (Test-Path -Path (Join-Path $PSScriptRoot $script:intuneWinUtilPath) -PathType Leaf) {
        $intuneUtilFullPath = Join-Path $PSScriptRoot $script:intuneWinUtilPath
        $script:intuneWinUtilPath = $intuneUtilFullPath
    }
    # Check in current directory
    elseif (Test-Path -Path (Join-Path (Get-Location) $script:intuneWinUtilPath) -PathType Leaf) {
        $intuneUtilFullPath = Join-Path (Get-Location) $script:intuneWinUtilPath
        $script:intuneWinUtilPath = $intuneUtilFullPath
    }
    
    if (-not $intuneUtilFullPath) {
        Write-Log "FATAL: IntuneWinAppUtil.exe not found" -Level 'Error'
        Write-Log "  Searched Path: $script:intuneWinUtilPath" -Level 'Error'
        Write-Log "  Script Directory: $PSScriptRoot" -Level 'Error'
        Write-Log "  Current Directory: $(Get-Location)" -Level 'Error'
        Write-Log "  " -Level 'Error'
        Write-Log "  SOLUTION: Download IntuneWinAppUtil.exe from:" -Level 'Error'
        Write-Log "  https://github.com/microsoft/Microsoft-Win32-Content-Prep-Tool" -Level 'Error'
        Write-Log "  Place it in the same directory as this script or update the path in configuration" -Level 'Error'
        $script:exitCode = 1
        return $false
    }

    Write-Log "IntuneWinAppUtil found: $intuneUtilFullPath" -Level 'Success'
    return $true
}

function Get-ValidatedParentFolderPath {
    <#
    .SYNOPSIS
        Validates the parent folder path for unattended execution.
    .OUTPUTS
        Boolean indicating whether a valid path was obtained.
    #>
    
    # Check if path is configured
    if ([string]::IsNullOrWhiteSpace($script:ParentFolderPath)) {
        Write-Log "FATAL: No parent folder path configured" -Level 'Error'
        Write-Log "  " -Level 'Error'
        Write-Log "  SOLUTION: Provide path in one of these ways:" -Level 'Error'
        Write-Log "  1. Set defaultParentFolderPath variable in script configuration section" -Level 'Error'
        Write-Log "  2. Pass -ParentFolderPath parameter when running the script" -Level 'Error'
        Write-Log "  " -Level 'Error'
        Write-Log "  Example: .\Create-BulkIntuneWin.ps1 -ParentFolderPath 'C:\Packages'" -Level 'Error'
        $script:exitCode = 1
        return $false
    }

    # Clean the path
    $script:ParentFolderPath = $script:ParentFolderPath.Trim().Replace('"', '')

    # Validate path exists
    if (-not (Test-Path -Path $script:ParentFolderPath -PathType Container)) {
        Write-Log "FATAL: Parent folder path does not exist or is not accessible" -Level 'Error'
        Write-Log "  Configured Path: $script:ParentFolderPath" -Level 'Error'
        Write-Log "  " -Level 'Error'
        Write-Log "  SOLUTION:" -Level 'Error'
        Write-Log "  1. Verify the path exists and is accessible" -Level 'Error'
        Write-Log "  2. Check permissions on the folder" -Level 'Error'
        Write-Log "  3. Verify network path if using UNC path" -Level 'Error'
        $script:exitCode = 1
        return $false
    }

    Write-Log "Parent folder path validated: $script:ParentFolderPath" -Level 'Success'
    return $true
}

# ============================================================================
# PROCESSING FUNCTIONS
# ============================================================================

function Get-OutputFolderPath {
    <#
    .SYNOPSIS
        Determines the output folder path based on configuration.
    .PARAMETER PackageFolderPath
        The full path to the package folder.
    .OUTPUTS
        String containing the output folder path.
    #>
    param (
        [string]$PackageFolderPath
    )

    if ($script:centralizedOutputFolder) {
        # Create output folder at parent level
        return Join-Path -Path $script:ParentFolderPath -ChildPath $script:outputFolderName
    }
    else {
        # Create output folder inside package folder
        return Join-Path -Path $PackageFolderPath -ChildPath $script:outputFolderName
    }
}

function Process-PackageFolder {
    <#
    .SYNOPSIS
        Processes a single package folder to create .intunewin file.
    .PARAMETER PackageFolder
        The DirectoryInfo object representing the package folder.
    .OUTPUTS
        Boolean indicating success ($true), failure ($false), or skip ($null).
    #>
    param (
        [System.IO.DirectoryInfo]$PackageFolder
    )

    $folderName = $PackageFolder.Name
    $appFolder = Join-Path -Path $PackageFolder.FullName -ChildPath $script:appFolderName
    $deployAppPathInAppFolder = Join-Path -Path $appFolder -ChildPath $script:deployAppName
    $deployAppPathInRoot = Join-Path -Path $PackageFolder.FullName -ChildPath $script:deployAppName

    Write-Log "Processing package: $folderName" -Level 'Info'
    
    if ($script:showDetailedOutput) {
        Write-Log "  Checking for $script:deployAppName in App subfolder" -Level 'Verbose'
        Write-Log "  Path: $deployAppPathInAppFolder" -Level 'Verbose'
        Write-Log "  Exists: $(Test-Path -Path $deployAppPathInAppFolder -PathType Leaf)" -Level 'Verbose'
        Write-Log "  Checking for $script:deployAppName in package root" -Level 'Verbose'
        Write-Log "  Path: $deployAppPathInRoot" -Level 'Verbose'
        Write-Log "  Exists: $(Test-Path -Path $deployAppPathInRoot -PathType Leaf)" -Level 'Verbose'
    }

    # Determine deploy application location
    $deployAppExistsInAppFolder = Test-Path -Path $deployAppPathInAppFolder -PathType Leaf
    $deployAppExistsInRoot = Test-Path -Path $deployAppPathInRoot -PathType Leaf

    if (-not $deployAppExistsInAppFolder -and -not $deployAppExistsInRoot) {
        if ($script:autoSkipInvalidFolders) {
            Write-Log "Skipping $folderName - $script:deployAppName not found in App folder or root" -Level 'Warning'
            return $null
        }
        else {
            Write-Log "Error processing $folderName - $script:deployAppName not found in App folder or root" -Level 'Error'
            return $false
        }
    }

    # Determine source path based on where Deploy-Application.exe is located
    if ($deployAppExistsInRoot) {
        $sourcePath = $PackageFolder.FullName
        Write-Log "  Source: Package root folder" -Level 'Verbose'
    }
    else {
        $sourcePath = $appFolder
        Write-Log "  Source: App subfolder" -Level 'Verbose'
    }

    # Determine output folder
    $outputFolder = Get-OutputFolderPath -PackageFolderPath $PackageFolder.FullName

    if ($script:showDetailedOutput) {
        Write-Log "  Source path: $sourcePath" -Level 'Verbose'
        Write-Log "  Output folder: $outputFolder" -Level 'Verbose'
    }

    # Create output folder if it doesn't exist
    if (-not (Test-Path -Path $outputFolder)) {
        try {
            New-Item -Path $outputFolder -ItemType Directory -Force -ErrorAction Stop | Out-Null
            Write-Log "  Created output folder: $outputFolder" -Level 'Verbose'
        }
        catch {
            Write-Log "Failed to create output folder: $_" -Level 'Error' -FunctionName $_.InvocationInfo.FunctionName -LineNumber $_.InvocationInfo.ScriptLineNumber
            return $false
        }
    }

    # Generate output file name
    $intuneWinFileName = $script:outputFilePattern.Replace('{FolderName}', $folderName)
    if (-not $intuneWinFileName.EndsWith('.intunewin')) {
        $intuneWinFileName += '.intunewin'
    }
    $finalOutputPath = Join-Path -Path $outputFolder -ChildPath $intuneWinFileName

    # Remove existing file if configured to do so
    if ($script:overwriteExistingFiles -and (Test-Path -Path $finalOutputPath)) {
        try {
            Remove-Item -Path $finalOutputPath -Force -ErrorAction Stop
            Write-Log "  Removed existing file: $intuneWinFileName" -Level 'Verbose'
        }
        catch {
            Write-Log "Failed to remove existing file: $_" -Level 'Warning'
        }
    }

    # Create .intunewin file
    try {
        Write-Log "  Creating .intunewin file..." -Level 'Info'
        
        $processArgs = @(
            '-c', "`"$sourcePath`""
            '-s', "`"$sourcePath\$script:deployAppName`""
            '-o', "`"$outputFolder`""
            '-q'  # Quiet mode for unattended execution
        )

        if ($script:showDetailedOutput) {
            Write-Log "  Executing: $script:intuneWinUtilPath" -Level 'Verbose'
            Write-Log "  Arguments: $($processArgs -join ' ')" -Level 'Verbose'
        }

        $processInfo = Start-Process -FilePath $script:intuneWinUtilPath -ArgumentList $processArgs -Wait -PassThru -NoNewWindow -ErrorAction Stop

        if ($processInfo.ExitCode -ne 0) {
            Write-Log "IntuneWinAppUtil failed with exit code: $($processInfo.ExitCode)" -Level 'Error'
            return $false
        }

        # Verify and rename the created file
        $defaultIntuneWinName = "$($script:deployAppName -replace '\.[^.]+$', '').intunewin"
        $createdIntuneWinFile = Join-Path -Path $outputFolder -ChildPath $defaultIntuneWinName
        
        if (Test-Path -Path $createdIntuneWinFile) {
            if ($createdIntuneWinFile -ne $finalOutputPath) {
                Rename-Item -Path $createdIntuneWinFile -NewName $intuneWinFileName -Force -ErrorAction Stop
                Write-Log "  Renamed to: $intuneWinFileName" -Level 'Verbose'
            }
            
            $fileSize = (Get-Item -Path $finalOutputPath).Length
            $fileSizeMB = [math]::Round($fileSize / 1MB, 2)
            
            Write-Log "  Successfully created: $intuneWinFileName ($fileSizeMB MB)" -Level 'Success'
            return $true
        }
        else {
            Write-Log "Failed to create .intunewin file - output file not found" -Level 'Error'
            Write-Log "  Expected at: $createdIntuneWinFile" -Level 'Error'
            return $false
        }
    }
    catch {
        Write-Log "Error creating .intunewin file: $_" -Level 'Error' -FunctionName $_.InvocationInfo.FunctionName -LineNumber $_.InvocationInfo.ScriptLineNumber
        return $false
    }
}

function Start-BulkProcessing {
    <#
    .SYNOPSIS
        Main processing function that handles all package folders.
    #>
    
    Write-Log "Starting bulk IntuneWin packaging process" -Level 'Info'
    Write-Log "=========================================" -Level 'Info'

    # Get all package subfolders
    try {
        $packageFolders = Get-ChildItem -Path $script:ParentFolderPath -Directory -ErrorAction Stop
    }
    catch {
        Write-Log "Error reading subfolders from parent path: $_" -Level 'Error' -FunctionName $_.InvocationInfo.FunctionName -LineNumber $_.InvocationInfo.ScriptLineNumber
        $script:exitCode = 1
        return
    }

    if (-not $packageFolders -or $packageFolders.Count -eq 0) {
        Write-Log "No subfolders found in: $script:ParentFolderPath" -Level 'Warning'
        Write-Log "Please ensure the parent folder contains package subfolders to process" -Level 'Warning'
        $script:exitCode = 1
        return
    }

    Write-Log "Found $($packageFolders.Count) package folder(s) to process" -Level 'Info'
    Write-Log "=========================================" -Level 'Info'

    # Process each package folder
    $successCount = 0
    $failureCount = 0
    $skippedCount = 0
    $totalSizeMB = 0

    foreach ($packageFolder in $packageFolders) {
        $result = Process-PackageFolder -PackageFolder $packageFolder
        
        if ($result -eq $true) {
            $successCount++
            # Calculate size if file was created
            $intuneWinFileName = $script:outputFilePattern.Replace('{FolderName}', $packageFolder.Name)
            if (-not $intuneWinFileName.EndsWith('.intunewin')) {
                $intuneWinFileName += '.intunewin'
            }
            $outputFolder = Get-OutputFolderPath -PackageFolderPath $packageFolder.FullName
            $filePath = Join-Path -Path $outputFolder -ChildPath $intuneWinFileName
            if (Test-Path -Path $filePath) {
                $fileSize = (Get-Item -Path $filePath).Length
                $totalSizeMB += [math]::Round($fileSize / 1MB, 2)
            }
        }
        elseif ($result -eq $false) {
            $failureCount++
        }
        else {
            $skippedCount++
        }

        Write-Log "-----------------------------------------" -Level 'Info'
    }

    # Summary
    Write-Log "=========================================" -Level 'Info'
    Write-Log "Processing Summary:" -Level 'Info'
    Write-Log "  Total packages found: $($packageFolders.Count)" -Level 'Info'
    Write-Log "  Successfully created: $successCount" -Level 'Success'
    Write-Log "  Total size created: $totalSizeMB MB" -Level 'Info'
    
    if ($skippedCount -gt 0) {
        Write-Log "  Skipped (no executable): $skippedCount" -Level 'Warning'
    }
    
    if ($failureCount -gt 0) {
        Write-Log "  Failed: $failureCount" -Level 'Error'
        $script:exitCode = 1
    }
    
    Write-Log "=========================================" -Level 'Info'

    # Set exit code based on results
    if ($successCount -eq 0 -and $failureCount -gt 0) {
        $script:exitCode = 1
    }
    elseif ($successCount -eq 0 -and $skippedCount -gt 0 -and $failureCount -eq 0) {
        Write-Log "Warning: All packages were skipped. Please verify your folder structure." -Level 'Warning'
        $script:exitCode = 1
    }
}

#endregion Core Functions

#region Main Execution

# ============================================================================
# MAIN SCRIPT EXECUTION - UNATTENDED MODE
# ============================================================================

Write-Log "=========================================" -Level 'Info'
Write-Log "IntuneWin Bulk Packaging Script Started" -Level 'Info'
Write-Log "Mode: Unattended Execution" -Level 'Info'
Write-Log "=========================================" -Level 'Info'

# Initialize configuration
Initialize-Configuration

# Validate prerequisites
if (-not (Test-Prerequisites)) {
    Exit-Script
}

# Get and validate parent folder path
if (-not (Get-ValidatedParentFolderPath)) {
    Exit-Script
}

# Start bulk processing
Start-BulkProcessing

# Exit with appropriate code
Exit-Script

#endregion Main Execution
