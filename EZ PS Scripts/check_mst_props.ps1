<#
.SYNOPSIS
    Displays properties that would be modified by an MST transform file.
    
.DESCRIPTION
    Opens an MSI database, applies an MST transform in view mode to see what
    properties the transform would change, add, or remove.
    
.PARAMETER MsiPath
    Path to a base MSI file (can be any MSI, but preferably the target MSI).
    
.PARAMETER MstPath
    Path to the MST transform file to analyze.
    
.EXAMPLE
    .\Get-MstChanges.ps1 -MsiPath "C:\Installer\App.msi" -MstPath "C:\Installer\Custom.mst"
#>

[CmdletBinding()]
param(
    [Parameter(Mandatory=$true)]
    [ValidateScript({Test-Path $_})]
    [string]$MsiPath,
    
    [Parameter(Mandatory=$true)]
    [ValidateScript({Test-Path $_})]
    [string]$MstPath
)

try {
    # Constants
    $msiOpenDatabaseModeReadOnly = 0
    $msiTransformErrorViewTransform = 256
    
    # Create Windows Installer COM object
    $installer = New-Object -ComObject WindowsInstaller.Installer
    
    Write-Host "Opening MSI database: $MsiPath" -ForegroundColor Cyan
    
    # Open the MSI database in read-only mode
    $database = $installer.GetType().InvokeMember(
        "OpenDatabase",
        "InvokeMethod",
        $null,
        $installer,
        @($MsiPath, $msiOpenDatabaseModeReadOnly)
    )
    
    Write-Host "Applying transform in view mode: $MstPath" -ForegroundColor Cyan
    
    # Apply transform with view flag to create _TransformView table
    try {
        $database.GetType().InvokeMember(
            "ApplyTransform",
            "InvokeMethod",
            $null,
            $database,
            @($MstPath, $msiTransformErrorViewTransform)
        )
    } catch {
        Write-Warning "Transform view creation failed. Attempting standard application..."
    }
    
    Write-Host "`nQuerying _TransformView table for changes..." -ForegroundColor Cyan
    Write-Host ("=" * 80) -ForegroundColor Green
    
    # Query the _TransformView table to see what the transform changes
    try {
        $query = "SELECT ``Table``, ``Column``, ``Row``, ``Data`` FROM ``_TransformView``"
        
        $view = $database.GetType().InvokeMember(
            "OpenView",
            "InvokeMethod",
            $null,
            $database,
            $query
        )
        
        $view.GetType().InvokeMember("Execute", "InvokeMethod", $null, $view, $null)
        
        $transformChanges = @()
        $record = $view.GetType().InvokeMember("Fetch", "InvokeMethod", $null, $view, $null)
        
        Write-Host "`nTransform Changes:" -ForegroundColor Yellow
        Write-Host ("{0,-20} {1,-20} {2,-25} {3}" -f "Table", "Column", "Row", "Data") -ForegroundColor White
        Write-Host ("-" * 80) -ForegroundColor Gray
        
        while ($record -ne $null) {
            $table = $record.GetType().InvokeMember("StringData", "GetProperty", $null, $record, 1)
            $column = $record.GetType().InvokeMember("StringData", "GetProperty", $null, $record, 2)
            $row = $record.GetType().InvokeMember("StringData", "GetProperty", $null, $record, 3)
            $data = $record.GetType().InvokeMember("StringData", "GetProperty", $null, $record, 4)
            
            $changeObj = [PSCustomObject]@{
                Table = $table
                Column = $column
                Row = $row
                Data = $data
            }
            
            $transformChanges += $changeObj
            
            Write-Host ("{0,-20} {1,-20} {2,-25} {3}" -f $table, $column, $row, $data) -ForegroundColor White
            
            $record = $view.GetType().InvokeMember("Fetch", "InvokeMethod", $null, $view, $null)
        }
        
        $view.GetType().InvokeMember("Close", "InvokeMethod", $null, $view, $null)
        [System.Runtime.InteropServices.Marshal]::ReleaseComObject($view) | Out-Null
        
        # Filter for Property table changes
        Write-Host "`n" -NoNewline
        Write-Host ("=" * 80) -ForegroundColor Green
        Write-Host "`nProperty Changes Only:" -ForegroundColor Yellow
        Write-Host ("{0,-35} : {1}" -f "Property", "Value") -ForegroundColor White
        Write-Host ("-" * 80) -ForegroundColor Gray
        
        # Filter for Property table and exclude INSERT/DELETE operations
        $propertyChanges = $transformChanges | Where-Object { 
            $_.Table -eq "Property" -and 
            $_.Column -ne "INSERT" -and 
            $_.Column -ne "DELETE" -and
            $_.Column -ne "CREATE" -and
            $_.Column -ne "DROP"
        }
        
        foreach ($change in $propertyChanges) {
            # For Property table, Row contains the property name, Data contains the value
            Write-Host ("{0,-35} : {1}" -f $change.Row, $change.Data) -ForegroundColor White
        }
        
        if ($propertyChanges.Count -eq 0) {
            Write-Host "No property changes found in this transform." -ForegroundColor Yellow
        } else {
            Write-Host "`nTotal property changes: $($propertyChanges.Count)" -ForegroundColor Cyan
        }
        
    } catch {
        Write-Warning "_TransformView table not available. This is normal for some transforms."
        Write-Host "`nFalling back to comparing properties after applying transform..." -ForegroundColor Yellow
    }
    
    # Clean up
    [System.Runtime.InteropServices.Marshal]::ReleaseComObject($database) | Out-Null
    [System.Runtime.InteropServices.Marshal]::ReleaseComObject($installer) | Out-Null
    
} catch {
    Write-Error "Failed to process MST file: $_"
} finally {
    [System.GC]::Collect()
    [System.GC]::WaitForPendingFinalizers()
}
