@echo off
powershell.exe -NoProfile -ExecutionPolicy Bypass -File "%~dp0\Brains\UnblockBannerlordDLLs_GUI.ps1"
if %ERRORLEVEL% NEQ 0 pause
