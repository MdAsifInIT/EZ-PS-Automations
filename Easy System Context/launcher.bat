@echo off
:: Check for administrator privileges
net session >nul 2>&1
if %errorLevel% neq 0 (
  echo Requesting administrative privileges...
  powershell -Command "Start-Process '%~0' -Verb RunAs"
  exit /b
)

:: Change directory to the script's location
cd /d "%~dp0"

:: Check if psexec.exe is present
if not exist "psexec.exe" (
  echo psexec.exe not found. Please ensure it is in the same directory as this script.
  pause
  exit /b
)

:: Present user with options
echo.
echo Select the mode for running PSADT:
echo 1. Integrated (-is cmd)
echo 2. Silent (-s cmd)
set /p mode="Enter your choice (1 or 2): "

:: Validate user input and run the corresponding PSADT command
if "%mode%"=="1" (
  echo Launching PSADT in Integrated Mode...
  start "" psexec.exe -i -s cmd.exe
  timeout /t 1 /nobreak >nul
  exit
) else if "%mode%"=="2" (
  echo Launching PSADT in Silent Mode...
  start "" psexec.exe -s cmd.exe
  timeout /t 1 /nobreak >nul
  exit
) else (
  echo Invalid option. Please run the script again and select a valid option.
  pause
  exit /b
)

:: Close the original window
exit