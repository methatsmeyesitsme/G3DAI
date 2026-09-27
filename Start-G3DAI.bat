@echo off
setlocal
powershell.exe -NoProfile -ExecutionPolicy Bypass -File "%~dp0server\start-easy.ps1" -Setup
if errorlevel 1 pause
