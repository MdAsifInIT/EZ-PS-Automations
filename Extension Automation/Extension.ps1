param(
    [Parameter(Mandatory = $false)]
    [ValidateSet('Install', 'Uninstall')]
    [string]$Action = 'Install'
)

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

function Install {
    if (-not (Test-Path -Path $chromePolicyPath)) {
        New-Item -Path $chromePolicyPath -Force | Out-Null
    }
    Set-ItemProperty -Path $chromePolicyPath -Name $rdid -Value "$chromeExtensionId;$chromeExtensionUrl" -Type String

    if (-not (Test-Path -Path $edgePolicyPath)) {
        New-Item -Path $edgePolicyPath -Force | Out-Null
    }
    Set-ItemProperty -Path $edgePolicyPath -Name $rdid -Value "$edgeExtensionId;$edgeExtensionUrl" -Type String

    if (Test-Path -Path $appregpath) {
        Remove-Item -Path $appregpath -Recurse -Force
    }
    New-Item -Path $appregpath -Force | Out-Null

    Set-ItemProperty -Path $appregpath -Name 'DisplayName' -Value $pkgName -Type String
    Set-ItemProperty -Path $appregpath -Name 'DisplayVersion' -Value $appVersion -Type String
    Set-ItemProperty -Path $appregpath -Name 'Publisher' -Value $appVendor -Type String
    Set-ItemProperty -Path $appregpath -Name 'UninstallString' -Value 'NA' -Type String
    Set-ItemProperty -Path $appregpath -Name 'NoRemove' -Value 1 -Type DWord
    Set-ItemProperty -Path $appregpath -Name 'NoRepair' -Value 1 -Type DWord
    Set-ItemProperty -Path $appregpath -Name 'NoModify' -Value 1 -Type DWord
}

function Uninstall {
    if (Test-Path -Path $chromePolicyPath) {
        Remove-ItemProperty -Path $chromePolicyPath -Name $rdid -Force -ErrorAction SilentlyContinue
    }
    if (Test-Path -Path $edgePolicyPath) {
        Remove-ItemProperty -Path $edgePolicyPath -Name $rdid -Force -ErrorAction SilentlyContinue
    }
    if (Test-Path -Path $appregpath) {
        Remove-Item -Path $appregpath -Recurse -Force
    }
}

switch ($Action) {
    'Install' { Install }
    'Uninstall' { Uninstall }
}