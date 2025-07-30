# Minimal output version
$targetFolder = "AppData\Local\Programs\nitro"
$userDirectories = Get-ChildItem "C:\Users" -Directory -ErrorAction SilentlyContinue

foreach ($userDir in $userDirectories) {
    $folderPath = Join-Path $userDir.FullName $targetFolder
    
    if (Test-Path $folderPath -ErrorAction SilentlyContinue) {
        Write-Host "Deleting: $($userDir.Name)\$targetFolder"
        Remove-Item $folderPath -Recurse -Force -ErrorAction SilentlyContinue
    }
}
