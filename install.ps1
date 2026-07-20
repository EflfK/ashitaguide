param(
    [string]$AshitaRoot = "C:\Games\CatsEyeXI\catseyexi-client\Ashita",
    [switch]$Force
)

$ErrorActionPreference = 'Stop'

$target = Join-Path $AshitaRoot 'addons\ashitaguide'
$backupRoot = Join-Path $PSScriptRoot '.local-backups'
$timestamp = Get-Date -Format 'yyyyMMdd-HHmmss'
$backup = Join-Path $backupRoot $timestamp
$addonFiles = @('ashitaguide.lua', 'ashitaguide_config.lua')

if (-not (Test-Path -LiteralPath $AshitaRoot)) {
    throw "Ashita root does not exist: $AshitaRoot"
}

foreach ($fileName in $addonFiles) {
    $sourceFile = Join-Path $PSScriptRoot $fileName
    if (-not (Test-Path -LiteralPath $sourceFile)) {
        throw "Source addon file does not exist: $sourceFile"
    }
}

if (Test-Path -LiteralPath $target) {
    New-Item -ItemType Directory -Force -Path $backup | Out-Null
    Copy-Item -LiteralPath $target -Destination (Join-Path $backup 'ashitaguide') -Recurse -Force
    if (-not $Force) {
        Write-Host "Existing addon backed up to: $backup"
    }
}

New-Item -ItemType Directory -Force -Path $target | Out-Null
foreach ($fileName in $addonFiles) {
    Copy-Item -LiteralPath (Join-Path $PSScriptRoot $fileName) -Destination (Join-Path $target $fileName) -Force
}

Write-Host "Installed ashitaguide addon to: $target"
Write-Host 'Reload in game through AshitaDevTools or run: /addon reload ashitaguide'
