# Ensure running as admin
if (-not ([Security.Principal.WindowsPrincipal][Security.Principal.WindowsIdentity]::GetCurrent()).IsInRole([Security.Principal.WindowsBuiltInRole]::Administrator)) {
    Start-Process powershell.exe "-NoProfile -ExecutionPolicy Bypass -File `"$PSCommandPath`"" -Verb RunAs
    exit
}

Add-Type -AssemblyName PresentationFramework

$xaml = @"
<Window xmlns="http://schemas.microsoft.com/winfx/2006/xaml/presentation"
        Title="System Context Launcher" Height="200" Width="400" 
        WindowStartupLocation="CenterScreen" ResizeMode="NoResize">
    <Grid Margin="10">
        <StackPanel>
            <Label Content="Select System Context Mode:" FontSize="14" Margin="0,0,0,10"/>
            <Button x:Name="btnIntegrated" Content="Integrated Mode" Height="40" Margin="0,0,0,10"/>
            <Button x:Name="btnSilent" Content="Silent Mode" Height="40" Margin="0,0,0,10"/>
            <TextBlock x:Name="txtStatus" TextWrapping="Wrap" Margin="0,10,0,0"/>
        </StackPanel>
    </Grid>
</Window>
"@

$reader = [System.Xml.XmlNodeReader]::New([xml]$xaml)
$window = [Windows.Markup.XamlReader]::Load($reader)

# Get controls
$btnIntegrated = $window.FindName("btnIntegrated")
$btnSilent = $window.FindName("btnSilent")
$txtStatus = $window.FindName("txtStatus")

# Check for PSExec
$psExecPath = Join-Path $PSScriptRoot "psexec.exe"
if (-not (Test-Path $psExecPath)) {
    $txtStatus.Text = "Error: psexec.exe not found in script directory!"
    $btnIntegrated.IsEnabled = $false
    $btnSilent.IsEnabled = $false
}

# Button click handlers
$btnIntegrated.Add_Click({
        Start-Process -FilePath $psExecPath -ArgumentList "-i -s cmd.exe"
        $window.Close()
    })

$btnSilent.Add_Click({
        Start-Process -FilePath $psExecPath -ArgumentList "-s cmd.exe"
        $window.Close()
    })

# Show window
$window.ShowDialog() | Out-Null
