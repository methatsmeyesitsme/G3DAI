$ErrorActionPreference = "Stop"

if (-not (Get-Command node -ErrorAction SilentlyContinue)) {
  Write-Error "Node.js 20+ is required. Install Node.js, then run this script again."
}

if (-not (Get-Command npm -ErrorAction SilentlyContinue)) {
  Write-Error "npm is required. Install Node.js, then run this script again."
}

if (-not (Get-Command grok -ErrorAction SilentlyContinue)) {
  Write-Host "Installing the official Grok CLI..."
  npm install -g @xai-official/grok
}

$env:HOST = "127.0.0.1"
$env:PORT = "8787"
$env:CORS_ORIGIN = "https://methatsmeyesitsme.github.io"
if (-not $env:GROK_HOME) {
  $env:GROK_HOME = Join-Path $HOME ".grok"
}

Write-Host ""
Write-Host "G3DAI local Grok bridge"
Write-Host "Address: http://127.0.0.1:8787"
Write-Host "Grok data: $env:GROK_HOME"
Write-Host ""
Write-Host "Leave this window running while using G3DAI."
Write-Host "Opening local G3DAI in your browser..."
Start-Process "http://127.0.0.1:8787/"
Write-Host ""

node (Join-Path $PSScriptRoot "index.js")
