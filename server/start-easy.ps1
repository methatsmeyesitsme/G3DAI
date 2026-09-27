$ErrorActionPreference = "Stop"
$ScriptDir = $PSScriptRoot
$Root = Split-Path -Parent $ScriptDir

# Find the real G3DAI index.html even when Windows extracted the ZIP into a nested folder.
$IndexPath = $null
$probe = $ScriptDir
for ($i = 0; $i -lt 6 -and !$IndexPath; $i++) {
  $candidate = Join-Path $probe "index.html"
  if (Test-Path $candidate -PathType Leaf) {
    $IndexPath = (Resolve-Path $candidate).Path
    break
  }
  $candidate = Join-Path $probe "..\index.html"
  if (Test-Path $candidate -PathType Leaf) {
    $IndexPath = (Resolve-Path $candidate).Path
    break
  }
  $probe = Split-Path -Parent $probe
}
if (!$IndexPath) {
  throw "G3DAI index.html could not be found. Keep Start-G3DAI.bat, the server folder, and index.html inside the same extracted G3DAI folder."
}
$Port = 8787
$HostAddress = "127.0.0.1"
$GrokHome = if ($env:GROK_HOME) { $env:GROK_HOME } else { Join-Path $HOME ".grok" }
$GrokBin = Join-Path $HOME ".grok\bin"
$GrokExe = Join-Path $GrokBin "grok.exe"
$AuthFile = Join-Path $GrokHome "auth.json"
function Ensure-Grok {
  if (Test-Path $GrokExe) { return }
  Write-Host ""
  Write-Host "Installing the official Grok CLI..." -ForegroundColor Cyan
  $previousKey=$env:XAI_API_KEY
  try{$env:XAI_API_KEY=$null;irm https://x.ai/cli/install.ps1 | iex}finally{$env:XAI_API_KEY=$previousKey}
  if(!(Test-Path $GrokExe)){throw "The official Grok CLI did not finish installing."}
}
Ensure-Grok
$env:PATH="$GrokBin;$env:PATH"
$env:GROK_HOME=$GrokHome
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
  $previousKey=$env:XAI_API_KEY
  try{$env:XAI_API_KEY=$null;$output=(& $GrokExe -p $DesignPrompt 2>&1|Out-String);$exitCode=$LASTEXITCODE}finally{$env:XAI_API_KEY=$previousKey}
  if($exitCode -ne 0){$message=$output.Trim();if(!$message){$message="Grok exited with code $exitCode."};throw $message}
  return $output.Trim()
}
$listener=New-Object Net.HttpListener
$listener.Prefixes.Add(("http://"+$HostAddress+":"+ $Port +"/"))
$listener.Start()
Start-Process ("http://"+$HostAddress+":"+ $Port +"/")
Write-Host ""
Write-Host ("G3DAI is running at http://"+$HostAddress+":"+ $Port +"/") -ForegroundColor Green
Write-Host "No xAI API key is used." -ForegroundColor DarkGray
Write-Host "Close this window to stop G3DAI." -ForegroundColor Yellow
Write-Host ""
while($listener.IsListening){
  try{
    $context=$listener.GetContext()
    $path=$context.Request.Url.AbsolutePath
    $method=$context.Request.HttpMethod
    if($method -eq "OPTIONS"){Set-Cors $context.Response $context.Request.Headers["Origin"];$context.Response.StatusCode=204;$context.Response.Close();continue}
    if($path -eq "/" -or $path -eq "/index.html"){$html=Get-Content (Join-Path $Root "..\index.html") -Raw;Send-Text $context 200 $html "text/html; charset=utf-8";continue}
    if($path -eq "/api/health" -and $method -eq "GET"){Send-Json $context 200 @{ok=$true;provider="Grok";mode="local";apiKeyRequired=$false};continue}
    if($path -eq "/api/grok/status" -and $method -eq "GET"){Send-Json $context 200 @{ok=$true;authenticated=(Test-Path $AuthFile)};continue}
    if($path -eq "/api/grok/login" -and $method -eq "POST"){$previousKey=$env:XAI_API_KEY;try{$env:XAI_API_KEY=$null;Start-Process -FilePath $GrokExe -ArgumentList "login"}finally{$env:XAI_API_KEY=$previousKey};Send-Json $context 200 @{ok=$true};continue}
    if($path -eq "/api/grok/chat" -and $method -eq "POST"){
      if(!(Test-Path $AuthFile)){Send-Json $context 401 @{error="Grok is not signed in yet. Press Connect and sign in in your browser."};continue}
      $body=Read-JsonBody $context
      $prompt=[string]$body.prompt
      $printer=[string]$body.printer
      $nozzle=[string]$body.nozzle
      $material=[string]$body.material
      $lines=@()
      if($body.history){foreach($item in @($body.history|Select-Object -Last 16)){$role=[string]$item.role;$text=[string]$item.text;if($text){$lines+=($role.ToUpper()+": "+$text)}}}
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
$listener.Stop()
$listener.Close()