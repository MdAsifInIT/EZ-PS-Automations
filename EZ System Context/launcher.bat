@echo off

net session >nul 2>&1
if %errorLevel% neq 0 (
  echo Requesting administrative privileges...
  powershell -Command "Start-Process '%~0' -Verb RunAs"
  exit /b
)

cd /d "%~dp0"

if not exist "psexec.exe" (
  echo psexec.exe not found. Please ensure it is in the same directory as this script.
  pause
  exit /b
)

echo.
echo Welcome to System Context Command Prompt Launcher
echo Select the mode for running PSADT:
echo 1. Interactive (-i 1 -s cmd)
echo 2. Silent (-s cmd)
set /p mode="Enter your choice (1 or 2): "

if "%mode%"=="1" (
  echo Launching PSADT in Interactive Mode...Enjoy!
  psexec.exe -d -i -s cmd.exe >nul 2>&1
  exit /b
) else if "%mode%"=="2" (
  echo Launching PSADT in Silent Mode...
  start "" psexec.exe -s cmd.exe
  exit
  
) else (
  echo Invalid option. Please run the script again and select a valid option.
  pause
  exit /b
)

exit