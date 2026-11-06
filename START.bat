@echo off
cd /d "%~dp0"
if exist "%~dp0PCToolkitPro.exe" (
    start "" "%~dp0PCToolkitPro.exe"
) else (
    start powershell.exe -NoProfile -ExecutionPolicy Bypass -WindowStyle Hidden -STA -File "%~dp0PCToolkitGUI.ps1"
)
exit
