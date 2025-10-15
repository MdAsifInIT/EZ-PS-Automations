<#
.SYNOPSIS
    Displays properties from an MSI file and optionally shows changes applied by an MST transform.
    
.DESCRIPTION
    Opens an MSI database and displays all properties. When an MST transform is provided,
    it shows what properties the transform would change, add, or remove with their values.
    
.PARAMETER MsiPath
    Path to an MSI file.
    
.PARAMETER MstPath
    (Optional) Path to an MST transform file to analyze changes.
    
.EXAMPLE
    .\Get-MstChanges.ps1 -MsiPath "C:\Installer\App.msi"
    Displays all properties in the MSI.
    
.EXAMPLE
    .\Get-MstChanges.ps1 -MsiPath "C:\Installer\App.msi" -MstPath "C:\Installer\Custom.mst"
    Displays property changes and additions from the transform.
#>

[CmdletBinding()]
param(
    [Parameter(Mandatory=$true)]
    [ValidateScript({Test-Path $_})]
    [string]$MsiPath,
    
    [Parameter(Mandatory=$false)]
    [ValidateScript({Test-Path $_})]
    [string]$MstPath
)

try {
    # Constants
    $msiOpenDatabaseModeReadOnly = 0
    $msiOpenDatabaseModeTransact = 1
    $msiTransformErrorViewTransform = 256
    
    # Create Windows Installer COM object
    $installer = New-Object -ComObject WindowsInstaller.Installer
    
    Write-Host "Opening MSI database: $MsiPath" -ForegroundColor Cyan
    
    if ([string]::IsNullOrEmpty($MstPath)) {
        # ===== MSI PROPERTIES ONLY =====
        Write-Host "No transform specified. Displaying MSI properties..." -ForegroundColor Yellow
        Write-Host ("=" * 80) -ForegroundColor Green
        
        # Open the MSI database in read-only mode
        $database = $installer.GetType().InvokeMember(
            "OpenDatabase",
            "InvokeMethod",
            $null,
            $installer,
            @($MsiPath, $msiOpenDatabaseModeReadOnly)
        )
        
        # Query the Property table
        $query = "SELECT ``Property``, ``Value`` FROM ``Property``"
        
        $view = $database.GetType().InvokeMember(
            "OpenView",
            "InvokeMethod",
            $null,
            $database,
            $query
        )
        
        $view.GetType().InvokeMember("Execute", "InvokeMethod", $null, $view, $null)
        
        Write-Host "`nMSI Properties:" -ForegroundColor Yellow
        Write-Host ("{0,-40} : {1}" -f "Property", "Value") -ForegroundColor White
        Write-Host ("-" * 80) -ForegroundColor Gray
        
        $propertyCount = 0
        $record = $view.GetType().InvokeMember("Fetch", "InvokeMethod", $null, $view, $null)
        
        while ($null -ne $record) {
            $property = $record.GetType().InvokeMember("StringData", "GetProperty", $null, $record, 1)
            $value = $record.GetType().InvokeMember("StringData", "GetProperty", $null, $record, 2)
            
            Write-Host ("{0,-40} : {1}" -f $property, $value) -ForegroundColor White
            $propertyCount++
            
            $record = $view.GetType().InvokeMember("Fetch", "InvokeMethod", $null, $view, $null)
        }
        
        $view.GetType().InvokeMember("Close", "InvokeMethod", $null, $view, $null)
        [System.Runtime.InteropServices.Marshal]::ReleaseComObject($view) | Out-Null
        
        Write-Host "`nTotal properties: $propertyCount" -ForegroundColor Cyan
        Write-Host ("=" * 80) -ForegroundColor Green
        
    } else {
        # ===== MST TRANSFORM ANALYSIS =====
        
        # Open the MSI database in transact mode for transform application
        $database = $installer.GetType().InvokeMember(
            "OpenDatabase",
            "InvokeMethod",
            $null,
            $installer,
            @($MsiPath, $msiOpenDatabaseModeTransact)
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
            Write-Warning "Transform view creation failed: $_"
        }
        
        Write-Host "`nQuerying _TransformView table for changes..." -ForegroundColor Cyan
        Write-Host ("=" * 80) -ForegroundColor Green
        
        # Query the _TransformView table to see what the transform changes
        try {
            $query = "SELECT ``Table``, ``Column``, ``Row``, ``Data``, ``Current`` FROM ``_TransformView``"
            
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
            
            Write-Host "`nAll Transform Changes:" -ForegroundColor Yellow
            Write-Host ("{0,-20} {1,-20} {2,-25} {3,-25} {4}" -f "Table", "Column", "Row", "Data", "Current") -ForegroundColor White
            Write-Host ("-" * 100) -ForegroundColor Gray
            
            while ($null -ne $record) {
                $table = $record.GetType().InvokeMember("StringData", "GetProperty", $null, $record, 1)
                $column = $record.GetType().InvokeMember("StringData", "GetProperty", $null, $record, 2)
                $row = $record.GetType().InvokeMember("StringData", "GetProperty", $null, $record, 3)
                $data = $record.GetType().InvokeMember("StringData", "GetProperty", $null, $record, 4)
                $current = $record.GetType().InvokeMember("StringData", "GetProperty", $null, $record, 5)
                
                $changeObj = [PSCustomObject]@{
                    Table = $table
                    Column = $column
                    Row = $row
                    Data = $data
                    Current = $current
                }
                
                $transformChanges += $changeObj
                
                Write-Host ("{0,-20} {1,-20} {2,-25} {3,-25} {4}" -f $table, $column, $row, $data, $current) -ForegroundColor White
                
                $record = $view.GetType().InvokeMember("Fetch", "InvokeMethod", $null, $view, $null)
            }
            
            $view.GetType().InvokeMember("Close", "InvokeMethod", $null, $view, $null)
            [System.Runtime.InteropServices.Marshal]::ReleaseComObject($view) | Out-Null
            
            # ===== PROPERTY CHANGES ANALYSIS =====
            Write-Host "`n" -NoNewline
            Write-Host ("=" * 80) -ForegroundColor Green
            Write-Host "`nProperty Changes Summary:" -ForegroundColor Yellow
            Write-Host ("{0,-10} {1,-35} {2,-30} {3}" -f "Action", "Property", "New Value", "Old Value") -ForegroundColor White
            Write-Host ("-" * 100) -ForegroundColor Gray
            
            # Get all Property table changes
            $propertyChanges = $transformChanges | Where-Object { $_.Table -eq "Property" }
            
            # Build a hashtable to map property names to their values for INSERT operations
            # For each INSERT operation, find the corresponding Value row
            $insertedPropertyValues = @{}
            $insertOperations = $propertyChanges | Where-Object { $_.Column -eq "INSERT" }
            
            foreach ($insertOp in $insertOperations) {
                $propName = $insertOp.Row
                # Find the corresponding row where Column = "Value" for this property
                $valueRow = $propertyChanges | Where-Object { 
                    $_.Column -eq "Value" -and $_.Row -eq $propName 
                } | Select-Object -First 1
                
                if ($null -ne $valueRow) {
                    $insertedPropertyValues[$propName] = $valueRow.Data
                }
            }
            
            # Separate by action type
            $insertedProps = @()
            $modifiedProps = @()
            $deletedProps = @()
            
            foreach ($change in $propertyChanges) {
                if ($change.Column -eq "INSERT") {
                    # This is an INSERT operation
                    $insertedProps += [PSCustomObject]@{
                        Property = $change.Row
                        NewValue = $insertedPropertyValues[$change.Row]
                    }
                } elseif ($change.Column -eq "DELETE") {
                    # This is a DELETE operation
                    $deletedProps += [PSCustomObject]@{
                        Property = $change.Row
                    }
                } elseif ($change.Column -eq "Value") {
                    # Check if this is part of an INSERT operation
                    $isPartOfInsert = $insertOperations | Where-Object { $_.Row -eq $change.Row }
                    
                    if ($null -eq $isPartOfInsert) {
                        # This is a standalone MODIFY operation (not part of INSERT)
                        $modifiedProps += [PSCustomObject]@{
                            Property = $change.Row
                            NewValue = $change.Data
                            OldValue = $change.Current
                        }
                    }
                    # If it's part of an INSERT, we already handled it above
                }
            }
            
            # Display INSERTED properties with values
            foreach ($insert in $insertedProps) {
                $value = if ($null -ne $insert.NewValue) { $insert.NewValue } else { "(no value)" }
                Write-Host ("{0,-10} {1,-35} {2,-30} {3}" -f "INSERT", $insert.Property, $value, "") -ForegroundColor Green
            }
            
            # Display MODIFIED properties
            foreach ($modify in $modifiedProps) {
                Write-Host ("{0,-10} {1,-35} {2,-30} {3}" -f "MODIFY", $modify.Property, $modify.NewValue, $modify.OldValue) -ForegroundColor Yellow
            }
            
            # Display DELETED properties
            foreach ($delete in $deletedProps) {
                Write-Host ("{0,-10} {1,-35} {2,-30} {3}" -f "DELETE", $delete.Property, "", "") -ForegroundColor Red
            }
            
            # Summary
            Write-Host "`n" -NoNewline
            Write-Host ("=" * 80) -ForegroundColor Green
            Write-Host "`nSummary:" -ForegroundColor Cyan
            Write-Host "  Inserted properties: $($insertedProps.Count)" -ForegroundColor Green
            Write-Host "  Modified properties: $($modifiedProps.Count)" -ForegroundColor Yellow
            Write-Host "  Deleted properties: $($deletedProps.Count)" -ForegroundColor Red
            Write-Host "  Total property operations: $($insertedProps.Count + $modifiedProps.Count + $deletedProps.Count)" -ForegroundColor Cyan
            
        } catch {
            Write-Warning "_TransformView table not available or query failed: $_"
            Write-Host "`nThis might occur with certain transform types or if the transform is empty." -ForegroundColor Yellow
        }
    }
    
    # Clean up
    [System.Runtime.InteropServices.Marshal]::ReleaseComObject($database) | Out-Null
    [System.Runtime.InteropServices.Marshal]::ReleaseComObject($installer) | Out-Null
    
} catch {
    Write-Error "Failed to process file(s): $_"
} finally {
    [System.GC]::Collect()
    [System.GC]::WaitForPendingFinalizers()
}
