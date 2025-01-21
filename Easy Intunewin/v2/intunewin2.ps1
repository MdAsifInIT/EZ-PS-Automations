# Execution Policy Must be unrestricted

# Input Params
param ([string]$parentFolderPath)

# Check if no path was provided
if (-not $parentFolderPath) {
    $parentFolderPath = Read-Host 'Please Enter the Path of the Parent Folder'
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
    $appFolder = Join-Path -Path $packageFolder.FullName -ChildPath 'App'
    $deployApplicationPath = Join-Path -Path $appFolder -ChildPath 'Deploy-Application.exe'
    $deployApplicationPathRoot = Join-Path -Path $packageFolder.FullName -ChildPath 'Deploy-Application.exe'
    
    Write-Host "Checking paths:"
    Write-Host "App folder path: $deployApplicationPath"
    Write-Host "Root folder path: $deployApplicationPathRoot"
    
    $deployApplicationExists = Test-Path -Path $deployApplicationPath
    $deployApplicationRootExists = Test-Path -Path $deployApplicationPathRoot
    
    if ($deployApplicationExists -or $deployApplicationRootExists) {
        Write-Host "Selected folder is $($packageFolder.FullName) and is a valid path."

        # Define variables
        $intuneWinUtilPath = 'intunewin.exe'  # Path to IntuneWinAppUtil.exe
        $folderName = $packageFolder.Name

        # Determine the source path for Deploy-Application.exe
        if ($deployApplicationRootExists) {
            $sourcePath = $packageFolder.FullName
            $outputFolder = Join-Path -Path $parentFolderPath -ChildPath 'Intune'
        }
        else {
            $sourcePath = $appFolder
            $outputFolder = Join-Path -Path $packageFolder.FullName -ChildPath 'Intune'
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
        Write-Host "Creating .intunewin file: $outputFolder\$intuneWinFileName"
        & $intuneWinUtilPath -c $sourcePath -s "$sourcePath\Deploy-Application.exe" -o $outputFolder

        # Verify if the file was created
        $createdIntuneWinFile = Join-Path -Path $outputFolder -ChildPath "Deploy-Application.intunewin"
        if (Test-Path -Path $createdIntuneWinFile) {
            # Rename the file to the desired name
            Rename-Item -Path $createdIntuneWinFile -NewName $intuneWinFileName
            Write-Host ".intunewin file created and renamed successfully: $outputFolder\$intuneWinFileName"
            # Increment counter
            $intuneWinFileCount++
        }
        else {
            Write-Host "Failed to create .intunewin file: $outputFolder\$intuneWinFileName"
        }
    }
    else {
        Write-Host "Deploy-Application.exe not found in $($packageFolder.FullName)"
    }
}

# Output the count of created .intunewin files
Write-Host "$intuneWinFileCount .intunewin files were created."