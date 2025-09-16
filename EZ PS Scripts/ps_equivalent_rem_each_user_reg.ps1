param(
    [string]$RegistryPath = "SOFTWARE\Microsoft\Windows\CurrentVersion\Uninstall\b6931e4b-b45c-5836-9bb2-5a2504553a62",
    [string]$ValueName = "",
    [switch]$DeleteEntireKey = $true
)

$osVersion = [Environment]::OSVersion.Version
if ($osVersion.Major -eq 5) {
    $userProfilesPath = "$env:SYSTEMDRIVE\Documents and Settings"
} else {
    $userProfilesPath = "$env:SYSTEMDRIVE\Users"
}

Write-Host "Scanning for user profiles in: $userProfilesPath" -ForegroundColor Cyan

try {
    $userFolders = Get-ChildItem -Path $userProfilesPath -Directory -ErrorAction Stop
} catch {
    Write-Host "Error accessing user profiles directory: $($_.Exception.Message)" -ForegroundColor Red
    Write-Host "Script completed with errors but returning success exit code." -ForegroundColor Yellow
    exit 0
}

$excludedAccounts = @(
    "All Users", "LocalService", "NetworkService", 
    "Default User", "Default", "Public", "DefaultAppPool"
)

$processedUsers = 0

foreach ($userFolder in $userFolders) {
    if ($excludedAccounts -contains $userFolder.Name) {
        Write-Host "Skipping system account: $($userFolder.Name)" -ForegroundColor Gray
        continue
    }
    
    $ntUserDatPath = Join-Path $userFolder.FullName "NTUSER.DAT"
    
    if (-not (Test-Path $ntUserDatPath)) {
        Write-Host "Skipping $($userFolder.Name) - No NTUSER.DAT found (not a user profile)" -ForegroundColor Gray
        continue
    }
    
    Write-Host "`nProcessing user profile: $($userFolder.Name)" -ForegroundColor Yellow
    Write-Host "Profile path: $($userFolder.FullName)"
    
    $timestamp = Get-Date -Format "yyyyMMdd_HHmmss"
    $tempHiveName = "TempUserHive_$($userFolder.Name)_$timestamp"
    $registryProcessed = $false
    
    try {
        Write-Host "  Loading registry hive..." -ForegroundColor Gray
        $loadResult = Start-Process -FilePath "reg.exe" -ArgumentList "load", "HKLM\$tempHiveName", "`"$ntUserDatPath`"" -Wait -PassThru -WindowStyle Hidden
        
        if ($loadResult.ExitCode -eq 0) {
            Write-Host "  [SUCCESS] Registry hive loaded successfully" -ForegroundColor Green
            
            $fullRegistryPath = "HKLM:\$tempHiveName\$RegistryPath"
            
            if ($DeleteEntireKey) {
                if (Test-Path $fullRegistryPath) {
                    Remove-Item -Path $fullRegistryPath -Recurse -Force -ErrorAction Stop
                    Write-Host "  [SUCCESS] Deleted registry key: $RegistryPath" -ForegroundColor Green
                    $registryProcessed = $true
                } else {
                    Write-Host "  [INFO] Registry key not found: $RegistryPath" -ForegroundColor Yellow
                }
            } else {
                if (Test-Path $fullRegistryPath) {
                    $registryValue = Get-ItemProperty -Path $fullRegistryPath -Name $ValueName -ErrorAction SilentlyContinue
                    if ($null -ne $registryValue.$ValueName) {
                        Remove-ItemProperty -Path $fullRegistryPath -Name $ValueName -Force -ErrorAction Stop
                        Write-Host "  [SUCCESS] Deleted registry value: $ValueName" -ForegroundColor Green
                        $registryProcessed = $true
                    } else {
                        Write-Host "  [INFO] Registry value not found: $ValueName" -ForegroundColor Yellow
                    }
                } else {
                    Write-Host "  [INFO] Registry path not found: $RegistryPath" -ForegroundColor Yellow
                }
            }
            
        } else {
            Write-Host "  [ERROR] Failed to load registry hive (Exit code: $($loadResult.ExitCode))" -ForegroundColor Red
        }
        
    } catch {
        Write-Host "  [ERROR] Error processing registry: $($_.Exception.Message)" -ForegroundColor Red
    } finally {
        Write-Host "  Unloading registry hive..." -ForegroundColor Gray
        $unloadAttempts = 0
        $maxAttempts = 3

        do {
            $unloadAttempts++
            $unloadResult = Start-Process -FilePath "reg.exe" -ArgumentList "unload", "HKLM\$tempHiveName" -Wait -PassThru -WindowStyle Hidden
            
            if ($unloadResult.ExitCode -eq 0) {
                Write-Host "  [SUCCESS] Registry hive unloaded successfully" -ForegroundColor Green
                break
            } else {
                if ($unloadAttempts -lt $maxAttempts) {
                    Write-Host "  [WARNING] Unload attempt $unloadAttempts failed, retrying..." -ForegroundColor Yellow
                    Start-Sleep -Seconds 2
                } else {
                    Write-Host "  [FAILED] Failed to unload registry hive after $maxAttempts attempts (Exit code: $($unloadResult.ExitCode))" -ForegroundColor Red
                }
            }
        } while ($unloadResult.ExitCode -ne 0 -and $unloadAttempts -lt $maxAttempts)
    }
    
    if ($registryProcessed) {
        $processedUsers++
    }
    
    Write-Host "  " + ("=" * 50)
}

Write-Host "`nRegistry cleanup completed!" -ForegroundColor Cyan
Write-Host "Total user profiles processed: $processedUsers" -ForegroundColor White
Write-Host "Registry target: HKCU\$RegistryPath" -ForegroundColor White

if (-not $DeleteEntireKey -and $ValueName) {
    Write-Host "Value deleted: $ValueName" -ForegroundColor White
} elseif ($DeleteEntireKey) {
    Write-Host "Action: Deleted entire registry key" -ForegroundColor White
}
