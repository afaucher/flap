# render_art.ps1 - CLI tool for Claude / external agents to generate art using Antigravity's Imagen billing.
#
# Usage:
#   .\tools\render_art.ps1 -Prompt "A cybernetic falcon soaring at dusk, 16:9" -OutFile "docs\images\concepts\cyber_falcon.png"
#   .\tools\render_art.ps1 -Prompt "..." -OutFile "..." -Aspect "16:9" -TimeoutSeconds 120
param(
    [Parameter(Mandatory=$true)]
    [string]$Prompt,

    [Parameter(Mandatory=$true)]
    [string]$OutFile,

    [string]$Aspect = "16:9",
    [int]$TimeoutSeconds = 120
)

$ErrorActionPreference = "Stop"

# 1. Resolve absolute output path
$resolvedOut = $ExecutionContext.SessionState.Path.GetUnresolvedProviderPathFromPSPath($OutFile)
$outParent = Split-Path -Parent $resolvedOut
if (-not (Test-Path $outParent)) {
    New-Item -ItemType Directory -Path $outParent -Force | Out-Null
}

# 2. Locate Antigravity Language Server & agentapi
$agentExe = $env:ANTIGRAVITY_AGENTAPI_EXE
if (-not $agentExe -or -not (Test-Path $agentExe)) {
    $candidates = @(
        "$env:LOCALAPPDATA\Programs\Antigravity IDE\resources\app\extensions\antigravity\bin\language_server_windows_x64.exe",
        "$env:LOCALAPPDATA\Programs\Antigravity\resources\bin\language_server.exe"
    )
    foreach ($cand in $candidates) {
        if (Test-Path $cand) { $agentExe = $cand; break }
    }
}

if (-not $agentExe) {
    Write-Error "Could not locate Antigravity language_server / agentapi executable."
    exit 1
}

# 3. Discover active LS address and CSRF token if not already in environment
if (-not $env:ANTIGRAVITY_LS_ADDRESS -or -not $env:ANTIGRAVITY_CSRF_TOKEN) {
    $proc = Get-CimInstance Win32_Process -Filter "Name LIKE '%language_server%'" | 
        Where-Object { $_.CommandLine -match "--csrf_token" } | 
        Select-Object -First 1

    if ($proc -and $proc.CommandLine -match "--csrf_token\s+([a-f0-9\-]+)") {
        $env:ANTIGRAVITY_CSRF_TOKEN = $matches[1]
        $conn = Get-NetTCPConnection -State Listen -OwningProcess $proc.ProcessId -ErrorAction SilentlyContinue | 
            Select-Object -First 1
        if ($conn) {
            $env:ANTIGRAVITY_LS_ADDRESS = "localhost:$($conn.LocalPort)"
        }
    }
}

if (-not $env:ANTIGRAVITY_LS_ADDRESS) {
    Write-Error "No running Antigravity IDE instance detected. Please ensure Antigravity IDE is open."
    exit 1
}

# 4. Resolve Active Conversation ID
$targetConv = $env:ANTIGRAVITY_CONVERSATION_ID
if (-not $targetConv) {
    $brainDir = Join-Path $env:USERPROFILE ".gemini\antigravity-ide\brain"
    if (Test-Path $brainDir) {
        $latest = Get-ChildItem $brainDir -Directory | Sort-Object LastWriteTime -Descending | Select-Object -First 1
        if ($latest) {
            $targetConv = $latest.Name
        }
    }
}

if (-not $targetConv) {
    Write-Error "Could not find active Antigravity conversation."
    exit 1
}

# 5. Remove existing target file if present so we can accurately detect generation
if (Test-Path $resolvedOut) {
    Remove-Item $resolvedOut -Force
}

$startTime = [DateTime]::UtcNow
Write-Host ">> Dispatching render request to Antigravity conversation [$targetConv]..."
Write-Host "   Aspect: $Aspect"
Write-Host "   Target: $resolvedOut"
Write-Host "   Prompt: $Prompt"

# 6. Send render request via agentapi
$messagePayload = "RENDER_REQUEST: Generate an image with aspect ratio '$Aspect' and save it as a PNG directly to '$resolvedOut'. Prompt: $Prompt"
$apiResult = & "$agentExe" agentapi send-message --title="Art Render Request" "$targetConv" "$messagePayload" 2>&1

if ($LASTEXITCODE -ne 0) {
    Write-Error "Failed to send message via agentapi: $apiResult"
    exit 1
}

# 7. Await output file with timeout
Write-Host ">> Waiting for image render (timeout: ${TimeoutSeconds}s)..."
$deadline = (Get-Date).AddSeconds($TimeoutSeconds)
while ((Get-Date) -lt $deadline) {
    Start-Sleep -Seconds 2
    if (Test-Path $resolvedOut) {
        $item = Get-Item $resolvedOut
        if ($item.Length -gt 1000) {
            $elapsed = [Math]::Round(([DateTime]::UtcNow - $startTime).TotalSeconds, 1)
            Write-Host ">> SUCCESS: Render complete in ${elapsed}s!" -ForegroundColor Green
            Write-Host "   Path: $($item.FullName)"
            Write-Host "   Size: $([Math]::Round($item.Length / 1MB, 2)) MB"
            exit 0
        }
    }
}

Write-Error "Timed out waiting for Antigravity to write $resolvedOut after ${TimeoutSeconds}s."
exit 1
