param(
    [Parameter(Mandatory = $false)]
    [ValidateSet('Install', 'Uninstall')]
    [string]$Action = 'Install',
    
    [Parameter(Mandatory = $false)]
    [string]$LogPath = "$env:TEMP\ExtensionDeployment.log"
)

# Application Variables
[String]$appName = ''
[String]$appVendor = 'Munich Re'
[String]$appVersion = ''

[String]$rdid = ''
[String]$pkgName = ''
[String]$appregpath = "HKLM:\SOFTWARE\Microsoft\Windows\CurrentVersion\Uninstall\$appName"

# Extension Variables
[String]$chromeExtensionId = ''
[String]$edgeExtensionId = ''

[String]$chromePolicyPath = 'HKLM:\SOFTWARE\Policies\Google\Chrome\ExtensionInstallForcelist'
[String]$edgePolicyPath = 'HKLM:\SOFTWARE\Policies\Microsoft\Edge\ExtensionInstallForcelist'

[String]$chromeExtensionUrl = 'https://clients2.google.com/service/update2/crx'
[String]$edgeExtensionUrl = 'https://edge.microsoft.com/extensionwebstorebase/v1/crx'

# Add logging function
function Write-Log {
    param (
        [Parameter(Mandatory = $true)]
        [string]$Message,
        [ValidateSet('Info', 'Warning', 'Error')]
        [string]$Level = 'Info'
    )
    
    $timestamp = Get-Date -Format "yyyy-MM-dd HH:mm:ss"
    $logMessage = "[$timestamp] [$Level] $Message"
    Write-Host $logMessage
    
    # Only write to log file if LogPath was explicitly provided
    if ($PSBoundParameters.ContainsKey('LogPath')) {
        # Ensure log directory exists
        $logDir = Split-Path -Path $LogPath -Parent
        if (-not (Test-Path -Path $logDir)) {
            New-Item -Path $logDir -ItemType Directory -Force | Out-Null
        }
        Add-Content -Path $LogPath -Value $logMessage
    }
}

# Add exit code handling
$script:exitCode = 0

function Exit-Script {
    param (
        [int]$ExitCode = $script:exitCode
    )
    
    Write-Log "Script completed with exit code: $ExitCode" -Level $(if ($ExitCode -eq 0) { 'Info' } else { 'Error' })
    exit $ExitCode
}

function Install {
    Write-Log "Starting installation of $pkgName version $appVersion" -Level 'Info'
    
    try {
        # Chrome extension
        if (-not [string]::IsNullOrEmpty($chromeExtensionId)) {
            if (-not (Test-Path -Path $chromePolicyPath)) {
                Write-Log "Creating Chrome policy path" -Level 'Info'
                New-Item -Path $chromePolicyPath -Force | Out-Null
            }
            Write-Log "Setting Chrome extension policy for $chromeExtensionId" -Level 'Info'
            Set-ItemProperty -Path $chromePolicyPath -Name $rdid -Value "$chromeExtensionId;$chromeExtensionUrl" -Type String
        }
        
        # Edge extension
        if (-not [string]::IsNullOrEmpty($edgeExtensionId)) {
            if (-not (Test-Path -Path $edgePolicyPath)) {
                Write-Log "Creating Edge policy path" -Level 'Info'
                New-Item -Path $edgePolicyPath -Force | Out-Null
            }
            Write-Log "Setting Edge extension policy for $edgeExtensionId" -Level 'Info'
            Set-ItemProperty -Path $edgePolicyPath -Name $rdid -Value "$edgeExtensionId;$edgeExtensionUrl" -Type String
        }
        
        # Registry entry for application
        if (Test-Path -Path $appregpath) {
            Write-Log "Removing existing application registry entry" -Level 'Info'
            Remove-Item -Path $appregpath -Recurse -Force
        }
        
        Write-Log "Creating application registry entry" -Level 'Info'
        New-Item -Path $appregpath -Force | Out-Null
        
        Set-ItemProperty -Path $appregpath -Name 'DisplayName' -Value $pkgName -Type String
        Set-ItemProperty -Path $appregpath -Name 'DisplayVersion' -Value $appVersion -Type String
        Set-ItemProperty -Path $appregpath -Name 'Publisher' -Value $appVendor -Type String
        Set-ItemProperty -Path $appregpath -Name 'UninstallString' -Value 'NA' -Type String
        Set-ItemProperty -Path $appregpath -Name 'NoRemove' -Value 1 -Type DWord
        Set-ItemProperty -Path $appregpath -Name 'NoRepair' -Value 1 -Type DWord
        Set-ItemProperty -Path $appregpath -Name 'NoModify' -Value 1 -Type DWord
        
        Write-Log "Installation completed successfully" -Level 'Info'
    }
    catch {
        Write-Log "Error during installation: $_" -Level 'Error'
        $script:exitCode = 1
    }
}

function Uninstall {
    Write-Log "Starting uninstallation of $pkgName" -Level 'Info'
    
    try {
        # Chrome extension
        if (Test-Path -Path $chromePolicyPath) {
            Write-Log "Removing Chrome extension policy" -Level 'Info'
            Remove-ItemProperty -Path $chromePolicyPath -Name $rdid -Force -ErrorAction SilentlyContinue
        }
        
        # Edge extension
        if (Test-Path -Path $edgePolicyPath) {
            Write-Log "Removing Edge extension policy" -Level 'Info'
            Remove-ItemProperty -Path $edgePolicyPath -Name $rdid -Force -ErrorAction SilentlyContinue
        }
        
        # Registry entry
        if (Test-Path -Path $appregpath) {
            Write-Log "Removing application registry entry" -Level 'Info'
            Remove-Item -Path $appregpath -Recurse -Force
        }
        
        Write-Log "Uninstallation completed successfully" -Level 'Info'
    }
    catch {
        Write-Log "Error during uninstallation: $_" -Level 'Error'
        $script:exitCode = 1
    }
}

# Main execution
Write-Log "Script started with Action: $Action" -Level 'Info'

switch ($Action) {
    'Install' { 
        Install 
    }
    'Uninstall' { 
        Uninstall 
    }
}

Exit-Script
