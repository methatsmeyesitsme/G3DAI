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
  try{
    $running=Get-CimInstance Win32_Process -ErrorAction SilentlyContinue | Where-Object {
      $_.CommandLine -and $_.CommandLine -like ("*" + $InstalledScript + "*")
    }
    foreach($proc in @($running)){try{Stop-Process -Id ([int]$proc.ProcessId) -Force -ErrorAction SilentlyContinue}catch{}}
    if(@($running).Count){Start-Sleep -Milliseconds 500}
  }catch{}
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
  Start-Process -FilePath (Get-Command powershell.exe).Source -WindowStyle Hidden -ArgumentList @("-NoProfile","-ExecutionPolicy","Bypass","-WindowStyle","Hidden","-File",$InstalledScript,"-NoBrowser")
  Start-Sleep -Seconds 2
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
function Run-Grok([string]$DesignPrompt,[int]$MaxTurns=4,[string]$WorkingDir="",[switch]$PlannerMode){
  $timeoutSeconds=if($PlannerMode){120}else{300}
  $run=$null
  $oldKey=$env:XAI_API_KEY
  try{
    $env:XAI_API_KEY=$null
    $run=Start-Job -ScriptBlock {
      param($Exe,$Prompt,$Home,$Turns,$Cwd,$Planner)
      $env:XAI_API_KEY=$null
      $env:GROK_HOME=$Home
      $args=@()
      if($Cwd){$args+=@("--cwd",$Cwd)}
      $args+=@("-p",$Prompt,"--no-auto-update","--output-format","plain","--no-alt-screen","--no-plan","--no-subagents","--no-memory","--disable-web-search","--effort","low","--max-turns",$Turns)
      if($Planner){$args+=@("--disallowed-tools","Bash,Edit,Read,Grep,WebFetch,WebSearch,MCPTool")}else{$args+=@("--always-approve")}
      & $Exe @args 2>&1 | Out-String
    } -ArgumentList $GrokExe,$DesignPrompt,$GrokHome,$MaxTurns,$WorkingDir,[bool]$PlannerMode
    if(-not (Wait-Job -Job $run -Timeout $timeoutSeconds)){Stop-Job -Job $run -ErrorAction SilentlyContinue;throw "Grok timed out before returning the model build instructions."}
    $output=(Receive-Job -Job $run -ErrorAction SilentlyContinue | Out-String).Trim()
    if($run.State -ne "Completed"){if(!$output){$output="Grok did not complete the request."};throw $output}
    return $output
  }finally{if($run){Remove-Job -Job $run -Force -ErrorAction SilentlyContinue};$env:XAI_API_KEY=$oldKey}
}

function Extract-StlScript([string]$Output){
  if(!$Output){throw "Grok returned no model-building script."}
  $m=[regex]::Match($Output,"(?s)G3DAI_STL_SCRIPT_START\s*(.*?)\s*G3DAI_STL_SCRIPT_END")
  if(!$m.Success){throw "Grok did not return the required STL build script."}
  $script=$m.Groups[1].Value.Trim()
  if(!$script){throw "Grok returned an empty STL build script."}
  return $script
}

function Test-StlFile([string]$Path){
  if(!(Test-Path $Path -PathType Leaf)){return $false}
  $item=Get-Item $Path
  if($item.Length -le 84){return $false}
  try{
    $bytes=[IO.File]::ReadAllBytes($Path)
    if($bytes.Length -ge 84){$count=[BitConverter]::ToUInt32($bytes,80);if($count -gt 0 -and $count -lt 10000000 -and (84 + (50 * [int64]$count)) -eq $bytes.Length){return $true}}
    $head=[Text.Encoding]::ASCII.GetString($bytes,0,[Math]::Min($bytes.Length,256))
    return ($head -match "(?i)^solid\b" -and $head -match "(?i)facet\s+normal")
  }catch{return $false}
}

function Invoke-StlBuild([string]$Script,[string]$OutputDir,[string]$StlPath){
  if($Script -match "(?i)(subprocess|os\.system|socket|urllib|requests|ftplib|ctypes|winreg|powershell|cmd\.exe|Start-Process|Invoke-WebRequest|https?://)"){throw "Grok returned a build script containing a disallowed system or network operation."}
  $jobDir=Join-Path $OutputDir ("build-"+[guid]::NewGuid().ToString("N"))
  New-Item -ItemType Directory -Force -Path $jobDir | Out-Null
  $scriptPath=Join-Path $jobDir "build_model.py"
  Set-Content -Path $scriptPath -Value $Script -Encoding UTF8
  $py=Get-Command py.exe -ErrorAction SilentlyContinue
  if(!$py){$py=Get-Command python.exe -ErrorAction SilentlyContinue}
  if(!$py){$py=Get-Command python3.exe -ErrorAction SilentlyContinue}
  if(!$py){throw "Python 3 is required to build the STL locally."}
  $run=$null
  try{
    $run=Start-Job -ScriptBlock {
      param($Python,$ScriptFile,$IsPyLauncher)
      if($IsPyLauncher){& $Python -3 $ScriptFile 2>&1 | Out-String}else{& $Python $ScriptFile 2>&1 | Out-String}
    } -ArgumentList $py.Source,$scriptPath,($py.Name -ieq "py.exe")
    if(-not (Wait-Job -Job $run -Timeout 120)){Stop-Job -Job $run -ErrorAction SilentlyContinue;throw "The local STL build timed out after 2 minutes."}
    $output=(Receive-Job -Job $run -ErrorAction SilentlyContinue | Out-String).Trim()
    if($run.State -ne "Completed"){if($output){throw $output};throw "The local STL build did not complete."}
    if(!(Test-StlFile $StlPath)){if($output){throw "Grok code ran, but no valid STL was found at the required path. $output"};throw "Grok code ran, but no valid STL was found at the required path."}
    return $output
  }finally{if($run){Remove-Job -Job $run -Force -ErrorAction SilentlyContinue};Remove-Item $jobDir -Recurse -Force -ErrorAction SilentlyContinue}
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
      if($body.history){foreach($item in @($body.history|Select-Object -Last 8)){$role=[string]$item.role;$txt=[string]$item.text;if($txt){$lines+=($role.ToUpper()+": "+$txt)}}}
      $contextText=if($lines.Count){$lines -join ([Environment]::NewLine+[Environment]::NewLine)}else{"(no previous messages)"}
      $isStl=Test-StlRequest $prompt
      $outputDir=Join-Path (Join-Path $HOME "Downloads") "G3DAI"
      if($isStl){New-Item -ItemType Directory -Force -Path $outputDir | Out-Null}
      $stlName="grok-model-"+([guid]::NewGuid().ToString("N"))+".stl"
      $stlPath=Join-Path $outputDir $stlName
      $stlInstructions=if($isStl){
        "Return only a real STL build script for G3DAI to execute locally. Do not execute tools and do not inspect the workspace. Do not browse the web, plan, or ask questions. Return exactly G3DAI_STL_SCRIPT_START followed by one Python 3 script and then G3DAI_STL_SCRIPT_END. The Python script must use only the standard library, generate the requested watertight mesh itself, and write the finished STL to this exact path: $stlPath. Do not create OpenSCAD, do not call shell commands, do not use subprocess, do not access the network, and do not use external packages. For a simple ball, directly generate the sphere triangle mesh and write a valid binary STL. The response must contain only the two markers and the Python script."
      }      }else{
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
        if($isStl){
          $answer=Run-Grok $designPrompt 2 "" -PlannerMode
          $script=Extract-StlScript $answer
          $answer=Invoke-StlBuild $script $outputDir $stlPath
          if(!$answer){$answer="Grok designed the model and G3DAI built the STL locally."}
        }else{$answer=Run-Grok $designPrompt 4}
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
