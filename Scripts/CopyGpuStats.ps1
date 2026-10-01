#
# CopyGpuStats.ps1 - copy the single-device miner stats of one GPU to another GPU
#
# Useful if a card drops out and the device numbers shift: the remaining cards
# keep their benchmarks instead of starting over.
#
#   .\Scripts\CopyGpuStats.ps1                       asks for the GPU numbers, lists the files, asks before copying
#   .\Scripts\CopyGpuStats.ps1 -From 5 -To 3         lists the files, asks before copying
#   .\Scripts\CopyGpuStats.ps1 -From 5 -To 3 -Apply  copies without asking
#
# Only stats of exactly one device are copied (e.g. NVIDIA-BzMiner-GPU#05_KawPOW_HashRate.txt),
# multi-device stats (GPU#03-GPU#05_...) stay untouched. Existing target files are moved to
# Stats\Miners-backup-<timestamp> first. Stop RainbowMiner before running this script.
#

param(
    [string]$From = "",
    [string]$To = "",
    [switch]$Apply
)

$Path = Join-Path (Split-Path $PSScriptRoot -Parent) "Stats/Miners"

if (-not (Test-Path $Path)) {
    Write-Host "Folder $Path not found." -ForegroundColor Red
    exit 1
}

Write-Host "Make sure RainbowMiner is stopped, or it may overwrite the copied stats." -ForegroundColor Yellow
Write-Host " "

if ($From -eq "") {$From = Read-Host "Copy stats from GPU number (e.g. 5)"}
if ($To -eq "")   {$To   = Read-Host "Copy stats to GPU number (e.g. 3)"}

if ($From -notmatch "^\d+$" -or $To -notmatch "^\d+$" -or [int]$From -eq [int]$To) {
    Write-Host "Please enter two different GPU numbers." -ForegroundColor Red
    exit 1
}

$FromName = "GPU#{0:d2}" -f [int]$From
$ToName   = "GPU#{0:d2}" -f [int]$To

$Files = @(Get-ChildItem -Path $Path -Filter "*.txt" -File | Where-Object {
    $_.Name -match "-$([regex]::Escape($FromName))_" -and [regex]::Matches($_.Name, "GPU#\d+").Count -eq 1
})

if (-not $Files.Count) {
    Write-Host "No single-device stats for $FromName found." -ForegroundColor Yellow
    exit 0
}

$Jobs = @(foreach ($File in $Files) {
    $TargetName = $File.Name -replace "-$([regex]::Escape($FromName))_", "-$($ToName)_"
    [PSCustomObject]@{
        Source     = $File.FullName
        TargetName = $TargetName
        TargetFile = Join-Path $Path $TargetName
        Exists     = Test-Path -LiteralPath (Join-Path $Path $TargetName)
    }
    Write-Host "$($File.Name) -> $TargetName$(if (Test-Path -LiteralPath (Join-Path $Path $TargetName)) {' (replace)'})"
})

Write-Host " "

if (-not $Apply) {
    $Answer = Read-Host "Copy $($Jobs.Count) file(s) from $FromName to $ToName now? [Y/N]"
    if ($Answer -notmatch "^y") {
        Write-Host "Nothing copied." -ForegroundColor Yellow
        exit 0
    }
}

$BackupPath = Join-Path (Split-Path $Path -Parent) ("Miners-backup-{0}" -f (Get-Date -Format "yyyyMMdd-HHmmss"))
$Copied = 0
$Replaced = 0

foreach ($Job in $Jobs) {
    try {
        if ($Job.Exists) {
            if (-not (Test-Path $BackupPath)) {New-Item -ItemType Directory -Path $BackupPath -ErrorAction Stop | Out-Null}
            Move-Item -LiteralPath $Job.TargetFile -Destination (Join-Path $BackupPath $Job.TargetName) -Force -ErrorAction Stop
            $Replaced++
        }
        Copy-Item -LiteralPath $Job.Source -Destination $Job.TargetFile -Force -ErrorAction Stop
        $Copied++
    } catch {
        Write-Host "Failed to copy $($Job.TargetName): $($_.Exception.Message)" -ForegroundColor Red
    }
}

Write-Host "$Copied file(s) copied from $FromName to $ToName, $Replaced replaced." -ForegroundColor Green
if ($Replaced) {Write-Host "The replaced files were moved to $BackupPath" -ForegroundColor Green}
