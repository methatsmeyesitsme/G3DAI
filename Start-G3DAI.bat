@echo off
setlocal
set "G3DAI_SERVER=%TEMP%\g3dai-start-easy.ps1"
powershell.exe -NoProfile -ExecutionPolicy Bypass -Command "$u='https://raw.githubusercontent.com/methatsmeyesitsme/G3DAI/main/server/start-easy.ps1'; Invoke-WebRequest -UseBasicParsing -Uri $u -OutFile '%G3DAI_SERVER%'; exit $LASTEXITCODE"
if errorlevel 1 (
  echo Could not update the G3DAI local server from GitHub.
  echo Falling back to the bundled server.
  set "G3DAI_SERVER=%~dp0server\start-easy.ps1"
)
powershell.exe -NoProfile -ExecutionPolicy Bypass -File "%G3DAI_SERVER%" -Setup
if errorlevel 1 pause
