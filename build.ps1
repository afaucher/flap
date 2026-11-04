# build.ps1 - import, run the full test gate, then export build\windows\Flap.exe and package
# build\Flap_Windows_v<version>.zip (ported from ..\cast\build.ps1).
#
#   .\build.ps1              # tests, then export + zip
#   .\build.ps1 -SkipTests   # export only (UNVERIFIED build)
#   .\build.ps1 -Force       # export even if tests failed
#
# Export templates (4.7.stable) live in build\deps\godot-data; APPDATA is pointed there for the export
# process only, so nothing machine-wide is read or written. If they are missing they are copied from
# ..\cast\build\deps\godot-data (build\ is gitignored).
#
# Every build is stamped yyyy-MM-dd.HHmmss: into version.txt (project root, gitignored, packed into
# Flap.pck), into build\windows\version.txt and into the zip's name.
param([switch]$SkipTests, [switch]$Force)

$GameName = "Flap"
$buildVersion = Get-Date -Format "yyyy-MM-dd.HHmmss"
Write-Host "Build version: $buildVersion" -ForegroundColor Cyan

. "$PSScriptRoot\godot_env.ps1"
$godot = Resolve-FlapGodot
Write-Host "Engine: $godot" -ForegroundColor DarkCyan
Write-Host "Importing project..." -ForegroundColor Cyan
Invoke-FlapImport $godot

$ok = $true
if (-not $SkipTests) {
    & "$PSScriptRoot\test_runner.ps1" -TestAll -NoImport
    $ok = ($LASTEXITCODE -eq 0)
    if (-not $ok -and -not $Force) { Write-Host "BUILD ABORTED: tests failed." -ForegroundColor Red; exit 1 }
}

$dataDir = Join-Path $PSScriptRoot "build\deps\godot-data"
$templates = Join-Path $dataDir "Godot\export_templates\4.7.stable\windows_release_x86_64.exe"
if (-not (Test-Path $templates)) {
    $castData = Join-Path $PSScriptRoot "..\cast\build\deps\godot-data"
    if (Test-Path (Join-Path $castData "Godot\export_templates\4.7.stable\windows_release_x86_64.exe")) {
        Write-Host "Copying export templates from ..\cast ..." -ForegroundColor Cyan
        New-Item -ItemType Directory -Force -Path (Split-Path $dataDir) | Out-Null
        Copy-Item $castData -Destination $dataDir -Recurse -Force
    }
}
if (-not (Test-Path $templates)) {
    Write-Host "Missing export templates: $templates" -ForegroundColor Red
    Write-Host "Copy ..\cast\build\deps\godot-data\Godot\export_templates\4.7.stable there." -ForegroundColor Yellow
    exit 1
}

$buildDir = Join-Path $PSScriptRoot "build"
$outDir = Join-Path $buildDir "windows"
Stop-Process -Name $GameName -ErrorAction SilentlyContinue
if (Test-Path $outDir) { Remove-Item $outDir -Recurse -Force }
New-Item -ItemType Directory -Force -Path $outDir | Out-Null
$exe = Join-Path $outDir "$GameName.exe"

# Written right before the export so the .pck carries this build's stamp.
Set-Content -Path "$PSScriptRoot\version.txt" -Value $buildVersion
Write-Host "Exporting $exe ..." -ForegroundColor Cyan
$oldAppData = $env:APPDATA
$env:APPDATA = $dataDir
try {
    & $godot --path $PSScriptRoot --headless --export-release "Windows Desktop" $exe 2>&1 |
        Where-Object { $_ -match "ERROR|WARNING|error" } | ForEach-Object { Write-Host "  $_" -ForegroundColor Yellow }
} finally { $env:APPDATA = $oldAppData }

# Godot exits 0 on some failed exports -- the artifacts decide.
foreach ($f in @("$GameName.exe", "$GameName.pck")) {
    if (-not (Test-Path (Join-Path $outDir $f))) { Write-Host "BUILD FAILED: missing $f" -ForegroundColor Red; exit 1 }
}
Set-Content -Path (Join-Path $outDir "version.txt") -Value $buildVersion
# The playtest log packer (from cast): double-click Pack_logs.bat to zip this PC's Flap logs next to the exe.
foreach ($f in @("Pack_logs.bat", "pack_logs.ps1")) { Copy-Item (Join-Path "$PSScriptRoot\tools\release" $f) -Destination $outDir -Force }

# --- Package -------------------------------------------------------------------------------------
# From cast: Compress-Archive silently skips a file it cannot open (an antivirus scan of the fresh .exe),
# and Windows leaves `*~RF*.TMP` copies of a replaced binary. Sweep leftovers, pack an explicit list,
# then verify the zip against the folder and retry a few times.
$zipPath = Join-Path $buildDir "${GameName}_Windows_v$buildVersion.zip"
Get-ChildItem -Path $buildDir -Filter "${GameName}_Windows_v*.zip" -File -ErrorAction SilentlyContinue |
    Remove-Item -Force -ErrorAction SilentlyContinue
Get-ChildItem -Path $outDir -Filter '*~RF*.TMP' -File -ErrorAction SilentlyContinue | Remove-Item -Force -ErrorAction SilentlyContinue
Add-Type -AssemblyName System.IO.Compression.FileSystem

function Get-ArchiveFaults([string]$SourceDir, [string]$ZipPath) {
    $expected = @{}
    foreach ($file in (Get-ChildItem -Path $SourceDir -File -Recurse)) {
        if ($file.Name -like '*~RF*.TMP') { continue }
        $rel = $file.FullName.Substring($SourceDir.Length).TrimStart('\', '/').Replace('\', '/')
        $expected[$rel] = $file.Length
    }
    $packed = @{}
    $zip = [System.IO.Compression.ZipFile]::OpenRead($ZipPath)
    try { foreach ($e in $zip.Entries) { $packed[$e.FullName.Replace('\', '/')] = $e.Length } } finally { $zip.Dispose() }
    $faults = @()
    foreach ($rel in $expected.Keys) {
        if (-not $packed.ContainsKey($rel)) { $faults += "MISSING  $rel" }
        elseif ($packed[$rel] -ne $expected[$rel]) { $faults += "TRUNCATED  $rel" }
    }
    foreach ($rel in $packed.Keys) { if (-not $expected.ContainsKey($rel)) { $faults += "UNWANTED  $rel" } }
    return $faults
}

Write-Host "Packaging $zipPath ..." -ForegroundColor Cyan
$faults = @()
for ($attempt = 1; $attempt -le 3; $attempt++) {
    if (Test-Path $zipPath) { Remove-Item $zipPath -Force }
    $toPack = Get-ChildItem -Path $outDir -File -Recurse | Where-Object { $_.Name -notlike '*~RF*.TMP' } | ForEach-Object { $_.FullName }
    Compress-Archive -Path $toPack -DestinationPath $zipPath -Force
    $faults = @(Get-ArchiveFaults $outDir $zipPath)
    if ($faults.Count -eq 0) { break }
    Write-Host "Archive does not match the build (attempt $attempt of 3):" -ForegroundColor Yellow
    foreach ($m in $faults) { Write-Host "    $m" -ForegroundColor Yellow }
    if ($attempt -lt 3) { Start-Sleep -Seconds 5 }
}
if ($faults.Count -gt 0) { Write-Host "BUILD FAILED: could not package a complete archive." -ForegroundColor Red; exit 1 }

$zipSize = [math]::Round((Get-Item $zipPath).Length / 1MB, 1)
Write-Host "Build complete: $buildVersion" -ForegroundColor Green
Write-Host "  Executable: $exe"
Write-Host "  ZIP: $zipPath  ($zipSize MB)"
if (-not $ok -or $SkipTests) { Write-Host "WARNING: this build did not pass a clean test gate." -ForegroundColor Yellow }
exit 0
