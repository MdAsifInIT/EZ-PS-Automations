# IntuneWin Bulk Packaging Script v3.0 - Multi-Format Edition
#
# Automates bulk creation of .intunewin packages.
# 
# What it does:
# - Scans a parent folder and processes all package subfolders
# - Auto-detects setup files (.exe, .ps1, .msi) in package root or App subfolder
# - Creates .intunewin files using Microsoft's Content Prep Tool
# - Renames output files to match your package folder names
# - Validates paths and tools before starting
# - Logs everything with detailed error messages
# - Runs completely unattended - perfect for automation and CI/CD
# - Supports multiple file types with smart auto-detection
#
# Updated: 8th October 2025

# PackageFolder/
# ├── App/
# │   └── Deploy-Application.ps1  ← Detected and packaged
# └── Intune/ (output)

# PackageFolder/
# ├── Deploy-Application.exe  ← This is packaged (highest priority)
# ├── setup.exe              ← Ignored (lower priority)
# └── install.msi            ← Ignored (lower priority)


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

# Setup file detection strategy
# Array of file patterns to search for (in priority order)
# The script will use the FIRST matching file found in each package
# Supports: .exe, .ps1, .msi, .bat, .cmd, .vbs, etc.
[string[]]$script:setupFilePatterns = @(
    'Deploy-Application.exe',
    'Deploy-Application.ps1',
    'setup.exe',
    'install.exe',
    'setup.msi',
    'install.msi',
    '*.msi',
    '*.exe'
)

# Legacy variable kept for backward compatibility (will be overridden by auto-detection)
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

#endregion Configuration Variables

#region Core Functions - DO NOT MODIFY UNLESS NECESSARY

# ============================================================================
# LOGGING FUNCTIONS
# ============================================================================

function Write-Log {
    <#
    .SYNOPSIS
        Writes log messages to console and optionally to a log file.
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
    #>
    param (
        [int]$ExitCode = $script:exitCode
    )

    Write-Log "Script completed with exit code: $ExitCode" -Level $(if ($ExitCode -eq 0) { 'Success' } else { 'Error' })
    exit $ExitCode
}

function Test-Prerequisites {
    <#
    .SYNOPSIS
        Validates that all required tools exist.
    #>
    
    Write-Log "Validating prerequisites" -Level 'Info'

    # Check for IntuneWinAppUtil in multiple locations
    $searchPaths = @(
        $script:intuneWinUtilPath,
        (Join-Path $PSScriptRoot $script:intuneWinUtilPath),
        (Join-Path (Get-Location) $script:intuneWinUtilPath)
    )
    
    foreach ($path in $searchPaths) {
        if (Test-Path -Path $path -PathType Leaf) {
            $script:intuneWinUtilPath = $path
            Write-Log "IntuneWinAppUtil found: $path" -Level 'Success'
            return $true
        }
    }
    
    # Not found in any location
    Write-Log "FATAL: IntuneWinAppUtil.exe not found" -Level 'Error'
    Write-Log "  Searched locations:" -Level 'Error'
    foreach ($path in $searchPaths) {
        Write-Log "    - $path" -Level 'Error'
    }
    Write-Log "  " -Level 'Error'
    Write-Log "  SOLUTION: Download from: https://github.com/microsoft/Microsoft-Win32-Content-Prep-Tool" -Level 'Error'
    Write-Log "  Place it in the same directory as this script or update the path in configuration" -Level 'Error'
    $script:exitCode = 1
    return $false
}

function Get-ValidatedParentFolderPath {
    <#
    .SYNOPSIS
        Validates the parent folder path for unattended execution.
    #>
    
    # Set from parameter or default
    if ([string]::IsNullOrWhiteSpace($ParentFolderPath)) {
        $script:ParentFolderPath = $script:defaultParentFolderPath
    }
    else {
        $script:ParentFolderPath = $ParentFolderPath
    }
    
    # Check if path is configured
    if ([string]::IsNullOrWhiteSpace($script:ParentFolderPath)) {
        Write-Log "FATAL: No parent folder path configured" -Level 'Error'
        Write-Log "  SOLUTION: Provide path via -ParentFolderPath parameter or set defaultParentFolderPath in configuration" -Level 'Error'
        Write-Log "  Example: .\Create-BulkIntuneWin.ps1 -ParentFolderPath 'C:\Packages'" -Level 'Error'
        $script:exitCode = 1
        return $false
    }

    # Clean the path (single location)
    $script:ParentFolderPath = $script:ParentFolderPath.Trim().Replace('"', '')

    # Validate path exists
    if (-not (Test-Path -Path $script:ParentFolderPath -PathType Container)) {
        Write-Log "FATAL: Parent folder path does not exist or is not accessible" -Level 'Error'
        Write-Log "  Configured Path: $script:ParentFolderPath" -Level 'Error'
        Write-Log "  SOLUTION: Verify the path exists and is accessible" -Level 'Error'
        $script:exitCode = 1
        return $false
    }

    Write-Log "Parent folder path validated: $script:ParentFolderPath" -Level 'Success'
    return $true
}

# ============================================================================
# PROCESSING FUNCTIONS
# ============================================================================


function Find-SetupFile {
    <#
    .SYNOPSIS
        Searches for a setup file in the specified path using configured patterns.
    .OUTPUTS
        Hashtable with 'Found' (bool), 'Path' (string), and 'FileName' (string) keys.
    #>
    param (
        [Parameter(Mandatory = $true)]
        [string]$SearchPath
    )

    Write-Log "  Searching for setup file in: $SearchPath" -Level 'Verbose'

    foreach ($pattern in $script:setupFilePatterns) {
        Write-Log "    Checking pattern: $pattern" -Level 'Verbose'

        # Check for exact match first
        $exactPath = Join-Path -Path $SearchPath -ChildPath $pattern
        if (Test-Path -Path $exactPath -PathType Leaf) {
            $fileName = Split-Path -Path $exactPath -Leaf
            Write-Log "    Found (exact match): $fileName" -Level 'Verbose'
            return @{
                Found = $true
                Path = $exactPath
                FileName = $fileName
            }
        }

        # If pattern contains wildcard, search for matching files
        if ($pattern -like '*`**' -or $pattern -like '*`?*') {
            try {
                $matchingFiles = Get-ChildItem -Path $SearchPath -Filter $pattern -File -ErrorAction SilentlyContinue
                if ($matchingFiles -and $matchingFiles.Count -gt 0) {
                    # Take the first matching file
                    $firstMatch = $matchingFiles | Select-Object -First 1
                    Write-Log "    Found (wildcard match): $($firstMatch.Name)" -Level 'Verbose'
                    return @{
                        Found = $true
                        Path = $firstMatch.FullName
                        FileName = $firstMatch.Name
                    }
                }
            }
            catch {
                Write-Log "    Error searching with pattern '$pattern': $_" -Level 'Verbose'
            }
        }
    }

    Write-Log "    No setup file found matching any configured pattern" -Level 'Verbose'
    return @{
        Found = $false
        Path = $null
        FileName = $null
    }
}

function Process-PackageFolder {
    <#
    .SYNOPSIS
        Processes a single package folder to create .intunewin file.
    .OUTPUTS
        Hashtable with 'Success' (bool) and 'SizeMB' (double) keys.
    #>
    param (
        [System.IO.DirectoryInfo]$PackageFolder
    )

    $folderName = $PackageFolder.Name
    $appFolder = Join-Path -Path $PackageFolder.FullName -ChildPath $script:appFolderName

    Write-Log "Processing package: $folderName" -Level 'Info'

    # Search for setup file in package root first
    Write-Log "  Searching for setup file in package root" -Level 'Verbose'
    $setupFileInRoot = Find-SetupFile -SearchPath $PackageFolder.FullName

    # Search for setup file in App subfolder if it exists
    $setupFileInAppFolder = @{ Found = $false; Path = $null; FileName = $null }
    if (Test-Path -Path $appFolder -PathType Container) {
        Write-Log "  Searching for setup file in App subfolder" -Level 'Verbose'
        $setupFileInAppFolder = Find-SetupFile -SearchPath $appFolder
    }

    # Determine which setup file to use (prioritize root over App folder)
    $setupFile = $null
    $sourcePath = $null

    if ($setupFileInRoot.Found) {
        $setupFile = $setupFileInRoot
        $sourcePath = $PackageFolder.FullName
        Write-Log "  Setup file found in package root: $($setupFile.FileName)" -Level 'Success'
        Write-Log "  Source: Package root folder" -Level 'Verbose'
    }
    elseif ($setupFileInAppFolder.Found) {
        $setupFile = $setupFileInAppFolder
        $sourcePath = $appFolder
        Write-Log "  Setup file found in App subfolder: $($setupFile.FileName)" -Level 'Success'
        Write-Log "  Source: App subfolder" -Level 'Verbose'
    }
    else {
        # No setup file found
        if ($script:autoSkipInvalidFolders) {
            Write-Log "Skipping $folderName - No setup file found matching configured patterns" -Level 'Warning'
            return @{ Success = $null; SizeMB = 0 }
        }
        else {
            Write-Log "Error processing $folderName - No setup file found matching configured patterns" -Level 'Error'
            return @{ Success = $false; SizeMB = 0 }
        }
    }

    # Update script variable for compatibility with rest of the code
    $script:deployAppName = $setupFile.FileName

    # Determine output folder (inlined logic)
    if ($script:centralizedOutputFolder) {
        $outputFolder = Join-Path -Path $script:ParentFolderPath -ChildPath $script:outputFolderName
    }
    else {
        $outputFolder = Join-Path -Path $PackageFolder.FullName -ChildPath $script:outputFolderName
    }

    Write-Log "  Source path: $sourcePath" -Level 'Verbose'
    Write-Log "  Output folder: $outputFolder" -Level 'Verbose'

    # Create output folder if it doesn't exist
    if (-not (Test-Path -Path $outputFolder)) {
        try {
            New-Item -Path $outputFolder -ItemType Directory -Force -ErrorAction Stop | Out-Null
            Write-Log "  Created output folder: $outputFolder" -Level 'Verbose'
        }
        catch {
            Write-Log "Failed to create output folder: $_" -Level 'Error' -FunctionName $_.InvocationInfo.FunctionName -LineNumber $_.InvocationInfo.ScriptLineNumber
            return @{ Success = $false; SizeMB = 0 }
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

        Write-Log "  Executing: $script:intuneWinUtilPath" -Level 'Verbose'
        Write-Log "  Arguments: $($processArgs -join ' ')" -Level 'Verbose'

        $processInfo = Start-Process -FilePath $script:intuneWinUtilPath -ArgumentList $processArgs -Wait -PassThru -NoNewWindow -ErrorAction Stop

        if ($processInfo.ExitCode -ne 0) {
            Write-Log "IntuneWinAppUtil failed with exit code: $($processInfo.ExitCode)" -Level 'Error'
            return @{ Success = $false; SizeMB = 0 }
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
            return @{ Success = $true; SizeMB = $fileSizeMB }
        }
        else {
            Write-Log "Failed to create .intunewin file - output file not found" -Level 'Error'
            Write-Log "  Expected at: $createdIntuneWinFile" -Level 'Error'
            return @{ Success = $false; SizeMB = 0 }
        }
    }
    catch {
        Write-Log "Error creating .intunewin file: $_" -Level 'Error' -FunctionName $_.InvocationInfo.FunctionName -LineNumber $_.InvocationInfo.ScriptLineNumber
        return @{ Success = $false; SizeMB = 0 }
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
        
        if ($result.Success -eq $true) {
            $successCount++
            $totalSizeMB += $result.SizeMB
        }
        elseif ($result.Success -eq $false) {
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

# Display configuration
Write-Log "Configuration Details:" -Level 'Info'
Write-Log "  App Folder Name: $script:appFolderName" -Level 'Verbose'
Write-Log "  Output Folder Name: $script:outputFolderName" -Level 'Verbose'
Write-Log "  Setup File Patterns: $($script:setupFilePatterns -join ', ')" -Level 'Verbose'
Write-Log "  Output File Pattern: $script:outputFilePattern" -Level 'Verbose'
Write-Log "  Centralized Output: $script:centralizedOutputFolder" -Level 'Verbose'
Write-Log "  Auto Skip Invalid: $script:autoSkipInvalidFolders" -Level 'Verbose'
Write-Log "  Overwrite Existing: $script:overwriteExistingFiles" -Level 'Verbose'

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
