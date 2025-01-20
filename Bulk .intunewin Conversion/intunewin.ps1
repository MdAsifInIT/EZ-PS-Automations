# Execution Policy Must be unrestricted

# Input Params
param ([string[]]$userargs)

# Check if no paths were provided
if (-not $userargs) {
	$userinput = Read-Host 'Please Enter the Path of Package Folders (comma separated)'
	$values = $userinput -split ','
	$trimmedvalues = $values | ForEach-Object { $_.Trim() }
	$replacedvalues = $trimmedvalues | ForEach-Object { $_ -replace '"', '' }
	$packageFolderPaths = $replacedvalues

}
else {
	$packageFolderPaths = $userargs | ForEach-Object { $_.Trim() }
}

if (-not $packageFolderPaths -or $packageFolderPaths.Count -eq 0) {
	Write-Host 'No valid paths provided. Exiting!'
	exit 1
}
else {
	Write-Host "$($packageFolderPaths.Count) folders selected."
}

foreach ($packageFolder in $packageFolderPaths) {
	if (Test-Path -Path "$packageFolder\App\Deploy-Application.exe") {
		Write-Host "Selected folder is $packageFolder and is a valid path."

		# Define variables
		$appFolder = Join-Path -Path $packageFolder -ChildPath 'App'
		$outputFolder = Join-Path -Path $packageFolder -ChildPath 'Intune'
		$intuneWinUtilPath = 'intunewin.exe'  # Path to IntuneWinAppUtil.exe
		$folderName = Split-Path -Leaf $packageFolder

		# Check if output directory exists, if not, create it
		if (!(Test-Path -Path $outputFolder)) {
			New-Item -Path $outputFolder -ItemType Directory
		}

		# Check if intune file exists, if it does, delete it
		if (Test-Path -Path "$outputFolder\$foldername.intunewin") {
			Remove-Item -Path "$outputFolder\$foldername.intunewin" -Force
		}

		if (Test-Path -Path "$outputFolder\Deploy-Application.intunewin") {
			Remove-Item -Path "$outputFolder\Deploy-Application.intunewin" -Force
		}

		# Build and run the command
		$arguments = "-c `"$appFolder`" -s `"$appFolder\Deploy-Application.exe`" -o `"$outputFolder`""
		Start-Process -FilePath $intuneWinUtilPath -ArgumentList $arguments -Wait -NoNewWindow -PassThru

		Rename-Item -Path "$outputFolder\Deploy-Application.intunewin" -NewName "$foldername.intunewin"

		# Verify if the .intunewin file was created successfully
		if (Test-Path -Path $outputFolder) {
			Write-Host ".intunewin file created successfully at: $outputFolder"
		}
		else {
			Write-Host 'Failed to create .intunewin file.'
		}
	}
 else {
		Write-Host "Selected folder path $packageFolder is invalid, skipping."
	}
}
exit 0
