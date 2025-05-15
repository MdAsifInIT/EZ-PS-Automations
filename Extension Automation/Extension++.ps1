param(
    [Parameter(Mandatory = $false)]
    [ValidateSet('Install', 'Uninstall')]
    [string]$Action = 'Install',

    [Parameter(Mandatory = $false)]
    [string]$LogPath = $null
)

#### Caution: The following variables are placeholders and should be replaced with actual values

# Application Variables
[String]$appName = ''
[String]$appVendor = ''
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

#### Caution: Fuctionality below this line should not be modified unless necessary

# Logging function
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

    # Write logs if LogPath is set
    if (-not [string]::IsNullOrWhiteSpace($LogPath)) {
        $logDir = Split-Path -Path $LogPath -Parent
        if (-not (Test-Path -Path $logDir)) {
            New-Item -Path $logDir -ItemType Directory -Force | Out-Null
        }
        Add-Content -Path $LogPath -Value $logMessage
    }
}

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
        # Validate critical variables
        if ([string]::IsNullOrEmpty($appName)) {
            Write-Log "Application name is empty. Registry operations may fail." -Level 'Error'
            $script:exitCode = 1
            return
        }
        
        if ([string]::IsNullOrEmpty($rdid)) {
            Write-Log "RDID is empty. Extension policy operations will fail." -Level 'Error'
            $script:exitCode = 1
            return
        }

        # Chrome extension
        if (-not [string]::IsNullOrEmpty($chromeExtensionId)) {
            if (-not (Test-Path -Path $chromePolicyPath)) {
                Write-Log "Creating Chrome policy path" -Level 'Info'
                New-Item -Path $chromePolicyPath -Force -ErrorAction Stop | Out-Null
            }
            Write-Log "Setting Chrome extension policy for $chromeExtensionId" -Level 'Info'
            Set-ItemProperty -Path $chromePolicyPath -Name $rdid -Value "$chromeExtensionId;$chromeExtensionUrl" -Type String -ErrorAction Stop
        }

        # Edge extension
        if (-not [string]::IsNullOrWhiteSpace($edgeExtensionId)) {
            if (-not (Test-Path -Path $edgePolicyPath)) {
                Write-Log "Creating Edge policy path" -Level 'Info'
                New-Item -Path $edgePolicyPath -Force -ErrorAction Stop | Out-Null
            }
            Write-Log "Setting Edge extension policy for $edgeExtensionId" -Level 'Info'
            Set-ItemProperty -Path $edgePolicyPath -Name $rdid -Value "$edgeExtensionId;$edgeExtensionUrl" -Type String -ErrorAction Stop
        }

        # ARP Entry
        if (Test-Path -Path $appregpath) {
            Write-Log "Removing existing ARP entry" -Level 'Info'
            Remove-Item -Path $appregpath -Recurse -Force -ErrorAction SilentlyContinue
        }

        Write-Log "Creating ARP entry" -Level 'Info'
        New-Item -Path $appregpath -Force -ErrorAction Stop | Out-Null

        Set-ItemProperty -Path $appregpath -Name 'DisplayName' -Value $pkgName -Type String -ErrorAction Stop
        Set-ItemProperty -Path $appregpath -Name 'DisplayVersion' -Value $appVersion -Type String -ErrorAction Stop
        Set-ItemProperty -Path $appregpath -Name 'Publisher' -Value $appVendor -Type String -ErrorAction Stop
        Set-ItemProperty -Path $appregpath -Name 'UninstallString' -Value 'NA' -Type String -ErrorAction Stop
        Set-ItemProperty -Path $appregpath -Name 'NoRemove' -Value 1 -Type DWord -ErrorAction Stop
        Set-ItemProperty -Path $appregpath -Name 'NoRepair' -Value 1 -Type DWord -ErrorAction Stop
        Set-ItemProperty -Path $appregpath -Name 'NoModify' -Value 1 -Type DWord -ErrorAction Stop

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
        # Validate critical variables
        if ([string]::IsNullOrEmpty($appName)) {
            Write-Log "Application name is empty. Registry operations may fail." -Level 'Error'
            $script:exitCode = 1
            return
        }
        
        if ([string]::IsNullOrEmpty($rdid)) {
            Write-Log "RDID is empty. Extension policy operations will fail." -Level 'Error'
            $script:exitCode = 1
            return
        }

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

        # ARP Entry
        if (Test-Path -Path $appregpath) {
            Write-Log "Removing ARP entry" -Level 'Info'
            Remove-Item -Path $appregpath -Recurse -Force -ErrorAction SilentlyContinue
        }

        Write-Log "Uninstallation completed successfully" -Level 'Info'
    }
    catch {
        Write-Log "Error during uninstallation: $_" -Level 'Error'
        $script:exitCode = 1
    }
}

Write-Log "Script started with Action: $Action" -Level 'Info'

# Main execution
switch ($Action) {
    'Install' { Install }
    'Uninstall' { Uninstall }
}

Exit-Script
