@echo off
setlocal
set "G3DAI_SERVER=%TEMP%\g3dai-start-easy-%RANDOM%-%RANDOM%.ps1"
set "G3DAI_SERVER_URL=https://raw.githubusercontent.com/methatsmeyesitsme/G3DAI/main/server/start-easy.ps1?cacheBust=%RANDOM%%RANDOM%"
powershell.exe -NoProfile -ExecutionPolicy Bypass -Command "$ProgressPreference='SilentlyContinue'; Invoke-WebRequest -UseBasicParsing -Headers @{'Cache-Control'='no-cache'} -Uri '%G3DAI_SERVER_URL%' -OutFile '%G3DAI_SERVER%'; if(!(Test-Path '%G3DAI_SERVER%')){exit 1}; if(-not (Select-String -Path '%G3DAI_SERVER%' -Pattern 'function Extract-StlScript' -Quiet)){exit 2}; exit 0"
if errorlevel 1 (
  echo Could not download the current G3DAI local server.
  echo Falling back to the bundled server.
  set "G3DAI_SERVER=%~dp0server\start-easy.ps1"
)
powershell.exe -NoProfile -ExecutionPolicy Bypass -File "%G3DAI_SERVER%" -Setup
if errorlevel 1 pause
