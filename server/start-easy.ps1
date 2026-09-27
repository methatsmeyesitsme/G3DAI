param([switch]$Setup,[switch]$NoBrowser)
$ErrorActionPreference = "Stop"
$ScriptDir = Split-Path -Parent $PSScriptRoot
$IndexPath = Join-Path $ScriptDir "index.html"
if(!(Test-Path $IndexPath -PathType Leaf)){
  $IndexPath=$null
  $probe=$PSScriptRoot
  for($i=0;$i -lt 6 -and !$IndexPath;$i++){
    $candidate=Join-Path $probe "index.html"
    if(Test-Path $candidate -PathType Leaf){$IndexPath=(Resolve-Path $candidate).Path;break}
    $probe=Split-Path -Parent $probe
  }
}
if(!$IndexPath){throw "G3DAI index.html could not be found."}
$Port=8787
$HostAddress="127.0.0.1"
$GrokHome=if($env:GROK_HOME){$env:GROK_HOME}else{Join-Path $HOME ".grok"}
$GrokBin=Join-Path $HOME ".grok\bin"
$GrokExe=Join-Path $GrokBin "grok.exe"
$AuthFile=Join-Path $GrokHome "auth.json"

function Ensure-Grok {
  if(Test-Path $GrokExe){return}
  Write-Host "Installing the official Grok CLI..." -ForegroundColor Cyan
  $oldKey=$env:XAI_API_KEY
  try{$env:XAI_API_KEY=$null;irm https://x.ai/cli/install.ps1 | iex}finally{$env:XAI_API_KEY=$oldKey}
  if(!(Test-Path $GrokExe)){throw "The official Grok CLI did not finish installing."}
}

function Is-G3DAIRunning {
  try{$r=Invoke-WebRequest -Uri ("http://"+$HostAddress+":"+ $Port +"/api/health") -UseBasicParsing -TimeoutSec 1;return $r.StatusCode -eq 200}catch{return $false}
}

Ensure-Grok
$env:PATH="$GrokBin;$env:PATH"
$env:GROK_HOME=$GrokHome

if($Setup){
  $InstallDir=Join-Path $env:LOCALAPPDATA "G3DAI"
  $InstallServer=Join-Path $InstallDir "server"
  New-Item -ItemType Directory -Force -Path $InstallServer | Out-Null
  Copy-Item $IndexPath (Join-Path $InstallDir "index.html") -Force
  Copy-Item $PSCommandPath (Join-Path $InstallServer "start-easy.ps1") -Force
  $InstalledScript=Join-Path $InstallServer "start-easy.ps1"
  $Startup=Join-Path $env:APPDATA "Microsoft\Windows\Start Menu\Programs\Startup"
  New-Item -ItemType Directory -Force -Path $Startup | Out-Null
  $ShortcutPath=Join-Path $Startup "G3DAI.lnk"
  $ws=New-Object -ComObject WScript.Shell
  $sc=$ws.CreateShortcut($ShortcutPath)
  $sc.TargetPath=(Get-Command powershell.exe).Source
  $sc.Arguments="-NoProfile -ExecutionPolicy Bypass -WindowStyle Hidden -File `"$InstalledScript`" -NoBrowser"
  $sc.WorkingDirectory=$InstallDir
  $sc.IconLocation=(Join-Path $InstallDir "index.html")
  $sc.Save()
  $taskName="G3DAI Local Server"
  if(Get-ScheduledTask -TaskName $taskName -ErrorAction SilentlyContinue){Unregister-ScheduledTask -TaskName $taskName -Confirm:$false -ErrorAction SilentlyContinue}
  if(!(Is-G3DAIRunning)){
    Start-Process -FilePath (Get-Command powershell.exe).Source -WindowStyle Hidden -ArgumentList @("-NoProfile","-ExecutionPolicy","Bypass","-WindowStyle","Hidden","-File",$InstalledScript,"-NoBrowser")
    Start-Sleep -Seconds 2
  }
  Start-Process ("http://"+$HostAddress+":"+ $Port +"/")
  Write-Host ""
  Write-Host "G3DAI is installed." -ForegroundColor Green
  Write-Host "It is now running in the background." -ForegroundColor Green
  Write-Host "You can close this window and delete the downloaded ZIP/folder." -ForegroundColor Cyan
  Write-Host "G3DAI will start automatically when you sign into Windows." -ForegroundColor Cyan
  Write-Host ""
  exit 0
}

function Set-Cors([System.Net.HttpListenerResponse]$Response,[string]$Origin){
  if($Origin -eq "https://methatsmeyesitsme.github.io" -or $Origin -like "http://127.0.0.1:*" -or $Origin -like "http://localhost:*"){
    $Response.Headers["Access-Control-Allow-Origin"]=$Origin
    $Response.Headers["Access-Control-Allow-Headers"]="Content-Type"
    $Response.Headers["Access-Control-Allow-Methods"]="GET,POST,OPTIONS"
  }
}
function Send-Json($Context,[int]$Status,$Object){
  Set-Cors $Context.Response $Context.Request.Headers["Origin"]
  $Context.Response.StatusCode=$Status
  $Context.Response.ContentType="application/json; charset=utf-8"
  $bytes=[Text.Encoding]::UTF8.GetBytes(($Object|ConvertTo-Json -Depth 8 -Compress))
  $Context.Response.OutputStream.Write($bytes,0,$bytes.Length)
  $Context.Response.Close()
}
function Send-Text($Context,[int]$Status,[string]$Text,[string]$ContentType){
  Set-Cors $Context.Response $Context.Request.Headers["Origin"]
  $Context.Response.StatusCode=$Status
  $Context.Response.ContentType=$ContentType
  $bytes=[Text.Encoding]::UTF8.GetBytes($Text)
  $Context.Response.OutputStream.Write($bytes,0,$bytes.Length)
  $Context.Response.Close()
}
function Read-JsonBody($Context){
  $reader=New-Object IO.StreamReader($Context.Request.InputStream,[Text.Encoding]::UTF8)
  try{$raw=$reader.ReadToEnd()}finally{$reader.Dispose()}
  if(!$raw){return $null}
  return $raw|ConvertFrom-Json
}
function Run-Grok([string]$DesignPrompt){
  $oldKey=$env:XAI_API_KEY
  try{$env:XAI_API_KEY=$null;$output=(& $GrokExe -p $DesignPrompt 2>&1|Out-String);$exitCode=$LASTEXITCODE}finally{$env:XAI_API_KEY=$oldKey}
  if($exitCode -ne 0){$message=$output.Trim();if(!$message){$message="Grok exited with code $exitCode."};throw $message}
  return $output.Trim()
}
$listener=New-Object Net.HttpListener
$listener.Prefixes.Add(("http://"+$HostAddress+":"+ $Port +"/"))
$listener.Start()
if(-not $NoBrowser){Start-Process ("http://"+$HostAddress+":"+ $Port +"/")}
Write-Host "G3DAI background server running." -ForegroundColor Green

while($listener.IsListening){
  try{
    $context=$listener.GetContext()
    $path=$context.Request.Url.AbsolutePath
    $method=$context.Request.HttpMethod
    if($method -eq "OPTIONS"){Set-Cors $context.Response $context.Request.Headers["Origin"];$context.Response.StatusCode=204;$context.Response.Close();continue}
    if($path -eq "/" -or $path -eq "/index.html"){$html=Get-Content $IndexPath -Raw;Send-Text $context 200 $html "text/html; charset=utf-8";continue}
    if($path -eq "/api/health" -and $method -eq "GET"){Send-Json $context 200 @{ok=$true;provider="Grok";mode="local";apiKeyRequired=$false};continue}
    if($path -eq "/api/grok/status" -and $method -eq "GET"){Send-Json $context 200 @{ok=$true;authenticated=(Test-Path $AuthFile)};continue}
    if($path -eq "/api/grok/login" -and $method -eq "POST"){$oldKey=$env:XAI_API_KEY;try{$env:XAI_API_KEY=$null;Start-Process -FilePath $GrokExe -ArgumentList "login"}finally{$env:XAI_API_KEY=$oldKey};Send-Json $context 200 @{ok=$true};continue}
    if($path -eq "/api/grok/chat" -and $method -eq "POST"){
      if(!(Test-Path $AuthFile)){Send-Json $context 401 @{error="Grok is not signed in yet. Press Connect and sign in in your browser."};continue}
      $body=Read-JsonBody $context
      $prompt=[string]$body.prompt
      $printer=[string]$body.printer
      $nozzle=[string]$body.nozzle
      $material=[string]$body.material
      $lines=@()
      if($body.history){foreach($item in @($body.history|Select-Object -Last 16)){$role=[string]$item.role;$txt=[string]$item.text;if($txt){$lines+=($role.ToUpper()+": "+$txt)}}}
      $contextText=if($lines.Count){$lines -join ([Environment]::NewLine+[Environment]::NewLine)}else{"(no previous messages)"}
      $designPrompt=@"
You are G3DAI, a professional 3D modeling and 3D printing design partner.
Help the user create real, printable 3D models.
Think in exact dimensions, clearances, tolerances, wall thicknesses, print orientation, supports, infill, material, and assembly.
When useful, provide complete directly usable OpenSCAD or Blender Python code.
Never claim an STL exists unless a real file or complete reproducible model data is actually provided.

Printer: $printer
Nozzle: $nozzle mm
Material: $material

Conversation:
$contextText

Current user request:
$prompt
"@
      try{$answer=Run-Grok $designPrompt;Send-Json $context 200 @{ok=$true;output=$answer}}catch{Send-Json $context 500 @{error=$_.Exception.Message}}
      continue
    }
    Send-Text $context 404 "Not found" "text/plain; charset=utf-8"
  }catch{try{Send-Text $context 500 $_.Exception.Message "text/plain; charset=utf-8"}catch{}}
  }
}
$listener.Stop()
$listener.Close()