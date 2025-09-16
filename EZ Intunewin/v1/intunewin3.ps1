# Input Params
param (
    [string]$parentFolderPath
)

function Load_Config {
    $configPath = Join-Path $PSScriptRoot "config\config.xml"
    if (Test-Path $configPath) {
        try {
            [xml]$xmlConfig = Get-Content $configPath
            return $xmlConfig.Configuration.Settings
        }
        catch {
            Write-Warning "Error loading config file: $_"
            return $null
        }
    }
    Write-Warning "Config file not found at: $configPath"
    return $null
}

# Load configuration with error handling
$config = Load_Config

# Safer null checks for older PowerShell versions
$appFolderName = if (($config -and $config.Paths -and $config.Paths.AppFolderName)) { 
    $config.Paths.AppFolderName 
}
else { 
    "App" 
}

$outputFolderName = if (($config -and $config.Paths -and $config.Paths.OutputFolderName)) { 
    $config.Paths.OutputFolderName 
}
else { 
    "Intune" 
}

$deployAppName = if (($config -and $config.Files -and $config.Files.DeployApplicationName)) { 
    $config.Files.DeployApplicationName 
}
else { 
    "Deploy-Application.exe" 
}

$intuneWinUtilPath = if (($config -and $config.Files -and $config.Files.IntuneWinUtilPath)) { 
    $config.Files.IntuneWinUtilPath 
}
else { 
    "intunewin.exe" 
}

$verboseLogging = if (($config -and $config.Logging -and $config.Logging.Verbose)) { 
    [System.Convert]::ToBoolean($config.Logging.Verbose) 
}
else { 
    $false 
}

# Check if no path was provided
if (-not $parentFolderPath) {
    if ($config.Paths -and $config.Paths.ParentFolderPath) {
        $parentFolderPath = $config.Paths.ParentFolderPath
    }
    else {
        $parentFolderPath = Read-Host 'Please Enter the Path of the Parent Folder'
    }
}

# Trim the path and remove double quotes
$parentFolderPath = $parentFolderPath.Trim().Replace('"', '')

if (-not (Test-Path -Path $parentFolderPath)) {
    Write-Host 'Invalid path provided. Exiting!'
    exit 1
}

# Get all subfolders
$packageFolderPaths = Get-ChildItem -Path $parentFolderPath -Directory

if (-not $packageFolderPaths -or $packageFolderPaths.Count -eq 0) {
    Write-Host 'No valid subfolders found. Exiting!'
    exit 1
}
else {
    Write-Host "$($packageFolderPaths.Count) subfolders found."
}

# Initialize counter
$intuneWinFileCount = 0

foreach ($packageFolder in $packageFolderPaths) {
    $appFolder = Join-Path -Path $packageFolder.FullName -ChildPath $appFolderName
    $deployApplicationPath = Join-Path -Path $appFolder -ChildPath $deployAppName
    $deployApplicationPathRoot = Join-Path -Path $packageFolder.FullName -ChildPath $deployAppName
    
    if ($verboseLogging) {
        Write-Host "Checking paths:"
        Write-Host "App folder path: $deployApplicationPath"
        Write-Host "Root folder path: $deployApplicationPathRoot"
    }
    
    $deployApplicationExists = Test-Path -Path $deployApplicationPath
    $deployApplicationRootExists = Test-Path -Path $deployApplicationPathRoot
    
    if ($deployApplicationExists -or $deployApplicationRootExists) {
        if ($verboseLogging) {
            Write-Host "Selected folder is $($packageFolder.FullName) and is a valid path."
        }

        $folderName = $packageFolder.Name

        # Determine the source path for Deploy-Application.exe
        if ($deployApplicationRootExists) {
            $sourcePath = $packageFolder.FullName
            $outputFolder = Join-Path -Path $parentFolderPath -ChildPath $outputFolderName
        }
        else {
            $sourcePath = $appFolder
            $outputFolder = Join-Path -Path $packageFolder.FullName -ChildPath $outputFolderName
        }

        $intuneWinFileName = "$folderName.intunewin"

        # Check if output directory exists, if not, create it
        if (!(Test-Path -Path $outputFolder)) {
            New-Item -Path $outputFolder -ItemType Directory
        }

        # Check if intune file exists, if it does, delete it
        if (Test-Path -Path "$outputFolder\$intuneWinFileName") {
            Remove-Item -Path "$outputFolder\$intuneWinFileName" -Force
        }

        # Create the .intunewin file
        if ($verboseLogging) {
            Write-Host "Creating .intunewin file: $outputFolder\$intuneWinFileName"
        }
        
        & $intuneWinUtilPath -c $sourcePath -s "$sourcePath\$deployAppName" -o $outputFolder

        # Verify if the file was created
        $createdIntuneWinFile = Join-Path -Path $outputFolder -ChildPath "Deploy-Application.intunewin"
        if (Test-Path -Path $createdIntuneWinFile) {
            # Rename the file to the desired name
            Rename-Item -Path $createdIntuneWinFile -NewName $intuneWinFileName
            if ($verboseLogging) {
                Write-Host ".intunewin file created and renamed successfully: $outputFolder\$intuneWinFileName"
            }
            # Increment counter
            $intuneWinFileCount++
        }
        else {
            Write-Host "Failed to create .intunewin file: $outputFolder\$intuneWinFileName"
        }
    }
}

# Output the count of created .intunewin files
Write-Host "$intuneWinFileCount .intunewin files were created."