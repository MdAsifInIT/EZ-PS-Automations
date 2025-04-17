@echo off
:: Check for administrative privileges
net session >nul 2>&1
if %errorlevel% neq 0 (
    :: Relaunch the script with elevated privileges
    powershell -Command "Start-Process '%~f0' -Verb RunAs"
    exit /b
)

:: Change to the directory where the batch file is located
cd /d "%~dp0"
 
:: Execute intunewinutil.exe and keep the terminal open
cmd /k "powershell.exe -executionpolicy bypass .\intunewin3.ps1"