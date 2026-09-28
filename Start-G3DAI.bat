@echo off
setlocal EnableExtensions
set "G3DAI_SERVER=%TEMP%\g3dai-start-easy-%RANDOM%-%RANDOM%.ps1"
set "G3DAI_SERVER_URL=https://api.github.com/repos/methatsmeyesitsme/G3DAI/contents/server/start-easy.ps1?ref=main"
echo Updating G3DAI local server...
powershell.exe -NoProfile -ExecutionPolicy Bypass -Command "$ErrorActionPreference='Stop';$ProgressPreference='SilentlyContinue';$r=Invoke-WebRequest -UseBasicParsing -Headers @{'Accept'='application/vnd.github.raw+json';'Cache-Control'='no-cache';'User-Agent'='G3DAI'} -Uri '%G3DAI_SERVER_URL%';[IO.File]::WriteAllText('%G3DAI_SERVER%',$r.Content,(New-Object System.Text.UTF8Encoding($false)));if(-not (Select-String -Path '%G3DAI_SERVER%' -Pattern 'function Extract-StlScript' -Quiet)){throw 'Downloaded G3DAI server is not the current STL bridge.'}"
if errorlevel 1 (
  echo.
  echo Could not download the current G3DAI local server.
  echo.
  echo Make sure you are connected to the internet and try again.
  pause
  exit /b 1
)
powershell.exe -NoProfile -ExecutionPolicy Bypass -File "%G3DAI_SERVER%" -Setup
if errorlevel 1 pause
