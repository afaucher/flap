# Packs this machine's Flap logs into Flap_logs_v<version>_<timestamp>.zip next to the game, for a playtest report
# (ported from ..\cast\tools\release). Pack_logs.bat runs it (double-click). build.ps1 ships both beside Flap.exe.
# The logs are copied to a temp folder first, so a running Flap (holding godot.log open) is fine.
$ErrorActionPreference = "Stop"
$data = Join-Path $env:APPDATA "Godot\app_userdata\Flap"
# What a playtest report needs: the engine's logs (godot.log and its rotations) and any frame profiles (--perf).
# Left out: shader_cache\, vulkan\ (the GPU's caches: large, and rebuilt on their own).
$items = @("logs", "perf")

if (-not (Test-Path $data)) {
    Write-Host "No Flap logs found at $data" -ForegroundColor Yellow
    exit 1
}
$version = "unknown"
$versionFile = Join-Path $PSScriptRoot "version.txt"
if (Test-Path $versionFile) { $version = (Get-Content $versionFile -TotalCount 1).Trim() }
$name = "Flap_logs_v${version}_$(Get-Date -Format 'yyyy-MM-dd_HHmmss')"

Write-Host "Packing Flap logs from $data ..."
$stage = Join-Path $env:TEMP $name
New-Item -ItemType Directory -Force -Path $stage | Out-Null
try {
    foreach ($item in $items) {
        $src = Join-Path $data $item
        if (-not (Test-Path $src)) { continue }
        try { Copy-Item -Path $src -Destination $stage -Recurse -Force }
        catch { Write-Host "  Skipped $item ($($_.Exception.Message))" -ForegroundColor Yellow }
    }
    # Next to the game; the Desktop when that folder is read-only (Program Files).
    $outDir = $PSScriptRoot
    try { [IO.File]::WriteAllText((Join-Path $outDir ".pack_logs_probe"), ""); Remove-Item (Join-Path $outDir ".pack_logs_probe") }
    catch { $outDir = [Environment]::GetFolderPath("Desktop") }
    $zip = Join-Path $outDir "$name.zip"
    # Entry by entry: PowerShell 5.1's CreateFromDirectory writes `\` into entry names, which other unzippers misread.
    Add-Type -AssemblyName System.IO.Compression, System.IO.Compression.FileSystem
    $archive = [IO.Compression.ZipFile]::Open($zip, [IO.Compression.ZipArchiveMode]::Create)
    try {
        foreach ($f in Get-ChildItem $stage -File -Recurse) {
            $entry = "$name/" + $f.FullName.Substring($stage.Length).TrimStart('\').Replace('\', '/')
            [IO.Compression.ZipFileExtensions]::CreateEntryFromFile($archive, $f.FullName, $entry, [IO.Compression.CompressionLevel]::Optimal) | Out-Null
        }
    } finally { $archive.Dispose() }
} finally {
    Remove-Item -Recurse -Force $stage -ErrorAction SilentlyContinue
}

$mb = [math]::Round((Get-Item $zip).Length / 1MB, 1)
Write-Host "Saved $zip ($mb MB)" -ForegroundColor Green
Write-Host "Send this file to whoever runs the playtest."
Start-Process explorer.exe -ArgumentList "/select,`"$zip`""
