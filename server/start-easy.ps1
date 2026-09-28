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
function Send-File($Context,[string]$FilePath,[string]$DownloadName){
  Set-Cors $Context.Response $Context.Request.Headers["Origin"]
  if(!(Test-Path $FilePath -PathType Leaf)){
    Send-Text $Context 404 "File not found" "text/plain; charset=utf-8"
    return
  }
  $bytes=[IO.File]::ReadAllBytes($FilePath)
  $Context.Response.StatusCode=200
  $Context.Response.ContentType="model/stl"
  $Context.Response.ContentLength64=$bytes.Length
  $Context.Response.AddHeader("Content-Disposition",'attachment; filename="'+$DownloadName+'"')
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
function Test-StlRequest([string]$Prompt){
  if(!$Prompt){return $false}
  $q=$Prompt.ToLower()
  return (($q -match '\bstl\b') -or ($q -match '\.stl\b'))
}
function Run-Grok([string]$DesignPrompt,[int]$MaxTurns=4,[string]$WorkingDir="",[switch]$StlMode){
  $timeoutSeconds=300
  $run=$null
  $oldKey=$env:XAI_API_KEY
  try{
    $env:XAI_API_KEY=$null
    $run=Start-Job -ScriptBlock {
      param($Exe,$Prompt,$Home,$Turns,$Cwd,$IsStl)
      $env:XAI_API_KEY=$null
      $env:GROK_HOME=$Home
      $args=@()
      if($Cwd){$args+=@("--cwd",$Cwd)}
      $args+=@("-p",$Prompt,"--always-approve","--no-auto-update","--output-format","plain","--no-alt-screen","--no-plan","--no-subagents","--disable-web-search","--effort","low","--max-turns",$Turns)
      if($IsStl){$args+=@("--tools","Bash")}
      & $Exe @args 2>&1 | Out-String
    } -ArgumentList $GrokExe,$DesignPrompt,$GrokHome,$MaxTurns,$WorkingDir,[bool]$StlMode
    if(-not (Wait-Job -Job $run -Timeout $timeoutSeconds)){
      Stop-Job -Job $run -ErrorAction SilentlyContinue
      throw "Grok timed out after 5 minutes. The request was stopped so G3DAI does not hang forever."
    }
    $output=(Receive-Job -Job $run -ErrorAction SilentlyContinue | Out-String).Trim()
    if($run.State -ne "Completed"){
      if(!$output){$output="Grok did not complete the request."}
      throw $output
    }
    return $output
  }finally{
    if($run){Remove-Job -Job $run -Force -ErrorAction SilentlyContinue}
    $env:XAI_API_KEY=$oldKey
  }
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
    if($path -like "/api/files/*.stl" -and $method -eq "GET"){
      $encodedName=$path.Substring("/api/files/".Length)
      $fileName=[uri]::UnescapeDataString($encodedName)
      if($fileName -notmatch '^[A-Za-z0-9._-]+\.stl$'){
        Send-Text $context 400 "Invalid file name" "text/plain; charset=utf-8"
        continue
      }
      $fileRoot=Join-Path (Join-Path $HOME "Downloads") "G3DAI"
      $filePath=Join-Path $fileRoot $fileName
      Send-File $context $filePath $fileName
      continue
    }
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
      $isStl=Test-StlRequest $prompt
      $outputDir=Join-Path (Join-Path $HOME "Downloads") "G3DAI"
      if($isStl){New-Item -ItemType Directory -Force -Path $outputDir | Out-Null}
      $stlName="grok-model-"+([guid]::NewGuid().ToString("N"))+".stl"
      $stlPath=Join-Path $outputDir $stlName
      $stlInstructions=if($isStl){
        "THIS REQUEST REQUIRES A REAL STL FILE.`nImmediately create the actual printable mesh. Do not inspect the project, browse the web, plan the task, ask questions, or create an OpenSCAD/Python source file instead of the STL.`nUse the terminal with one short Python script using only the Python standard library to write the STL directly.`nWrite the completed STL to this exact path:`n$stlPath`nFor a simple primitive such as a ball, create the mesh directly with mathematically generated triangles; do not wait for external CAD software or packages.`nUse millimeters and make the STL valid and non-empty.`nAfter writing it, verify the file exists and has a size greater than 84 bytes, then reply with one brief sentence only."
      }else{
        "Answer the user normally. For design tasks, provide concrete dimensions and practical 3D-printing guidance. Do not claim to have created a file unless you actually created one."
      }
      $designPrompt=@"
You are G3DAI, a professional 3D modeling and 3D printing design partner.
Everything related to model creation must be handled by you, Grok. Do not use a built-in shape template or hardcoded generator.
Think through exact dimensions, printability, wall thicknesses, clearances, tolerances, orientation, supports, and material.

Printer: $printer
Nozzle: $nozzle mm
Material: $material

Conversation:
$contextText

Current user request:
$prompt

$stlInstructions
"@
      try{
        if($isStl){$answer=Run-Grok $designPrompt 2 $outputDir -StlMode}else{$answer=Run-Grok $designPrompt 4}
        if($isStl -and (Test-Path $stlPath -PathType Leaf)){
          $item=Get-Item $stlPath
          if($item.Length -gt 84){
            $publicName=[uri]::EscapeDataString($stlName)
            Send-Json $context 200 @{ok=$true;output=$answer;stlGenerated=$true;fileName=$stlName;url="/api/files/$publicName";name=($stlName -replace "\.stl$","")}
          }else{
            Send-Json $context 200 @{ok=$true;output=($answer+" STL file was empty.");stlGenerated=$false}
          }
        }else{Send-Json $context 200 @{ok=$true;output=$answer;stlGenerated=$false}
        }
      }catch{Send-Json $context 500 @{error=$_.Exception.Message}}

    }
    Send-Text $context 404 "Not found" "text/plain; charset=utf-8"
  }catch{try{Send-Text $context 500 $_.Exception.Message "text/plain; charset=utf-8"}catch{}}
  }
$listener.Stop()
$listener.Close()
