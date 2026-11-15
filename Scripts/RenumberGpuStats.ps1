#
# RenumberGpuStats.ps1 - rename the miner stats after the GPU numbering has changed
#
# Useful if cards were added, removed or moved to other slots and the device numbers have shifted.
# Stop RainbowMiner first, and run this before the first start with the new card layout.
#
#   .\Scripts\RenumberGpuStats.ps1                               asks for the mapping, lists the changes, asks before renaming
#   .\Scripts\RenumberGpuStats.ps1 -Map "0=0,1=1,2=x,3=4"        lists the changes, asks before renaming
#   .\Scripts\RenumberGpuStats.ps1 -Map "0=0,1=1,2=x,3=4" -Apply renames without asking
#
# -Map lists every old GPU number: old=new renames, old=x drops the stats of a removed card.
# Old numbers that are not listed are treated as stale and dropped, too.
# A file naming at least one dropped card (single or combo) is dropped as a whole.
# Cards that are new in the rig need no entry, they will simply be benchmarked.
#
# Handles Stats\Miners, Stats\Disabled and the Stats\Profit-GPU#.. files.
# Nothing is deleted: every touched file is first moved to Stats\Renumber-backup-<timestamp>
# under its old name. To undo, delete the renamed files and copy the backup back.
#

param(
    [string]$Path = "",
    [string]$Map = "",
    [switch]$Apply
)

$Root = $null
foreach ($Candidate in @($Path, $(if ($PSScriptRoot) {Split-Path $PSScriptRoot -Parent}), $PWD.Path)) {
    if ($Candidate -and (Test-Path (Join-Path $Candidate "Stats/Miners"))) {$Root = (Resolve-Path $Candidate).Path; break}
}
if (-not $Root) {
    Write-Host "Folder Stats/Miners not found. Use -Path to point to the RainbowMiner folder." -ForegroundColor Red
    exit 1
}
$StatsPath = Join-Path $Root "Stats"

Write-Host "Make sure RainbowMiner is stopped, or it may overwrite the renamed stats." -ForegroundColor Yellow
Write-Host " "

if ($Map -eq "") {
    Write-Host "Enter one entry per old GPU number: old=new renames, old=x drops a removed card."
    $Map = Read-Host "Mapping (e.g. 0=0,1=1,2=x,3=4)"
}

$GpuMap = @{}
foreach ($Pair in ($Map -split "[,;\s]+" | Where-Object {$_})) {
    if ($Pair -notmatch "^(\d+)=(\d+|x)$") {
        Write-Host "Invalid mapping entry '$Pair' (use old=new or old=x)." -ForegroundColor Red
        exit 1
    }
    $GpuMap[[int]$Matches[1]] = if ($Matches[2] -eq "x") {-1} else {[int]$Matches[2]}
}
if (-not $GpuMap.Count) {
    Write-Host "No mapping given." -ForegroundColor Red
    exit 1
}
$Targets = @($GpuMap.Values | Where-Object {$_ -ge 0})
if (@($Targets | Select-Object -Unique).Count -ne $Targets.Count) {
    Write-Host "Invalid mapping: two old GPUs point to the same new number." -ForegroundColor Red
    exit 1
}

Write-Host "RainbowMiner folder: $Root"
Write-Host "Mapping:"
foreach ($Old in ($GpuMap.Keys | Sort-Object)) {
    $New = $GpuMap[$Old]
    Write-Host ("  GPU#{0:d2} -> {1}" -f $Old, $(if ($New -lt 0) {"dropped"} elseif ($New -eq $Old) {"unchanged"} else {"GPU#{0:d2}" -f $New}))
}
Write-Host "  all other GPU numbers -> dropped"
Write-Host " "

$Files = @()
$Files += @(Get-ChildItem -Path (Join-Path $StatsPath "Miners") -Filter "*.txt" -File -ErrorAction Ignore)
$Files += @(Get-ChildItem -Path (Join-Path $StatsPath "Disabled") -Filter "*.txt" -File -ErrorAction Ignore)
$Files += @(Get-ChildItem -Path $StatsPath -Filter "Profit-*.txt" -File -ErrorAction Ignore)

$Jobs = @(foreach ($File in $Files) {
    $Numbers = @([regex]::Matches($File.Name, "GPU#(\d+)") | Foreach-Object {[int]$_.Groups[1].Value} | Select-Object -Unique)
    if (-not $Numbers.Count) {continue}

    $Drop = $false
    foreach ($Number in $Numbers) {
        if (-not $GpuMap.ContainsKey($Number) -or $GpuMap[$Number] -lt 0) {$Drop = $true}
    }

    $NewName = $File.Name
    if (-not $Drop) {
        # two steps via a placeholder, so that 4->5 and 5->6 cannot chain
        foreach ($Number in $Numbers) {$NewName = $NewName -replace ("GPU#{0:d2}(?!\d)" -f $Number), ("GPU@{0:d2}" -f $GpuMap[$Number])}
        $NewName = $NewName -replace "GPU@", "GPU#"
        if ($NewName -eq $File.Name) {continue}
    }

    [PSCustomObject]@{
        Action     = if ($Drop) {"drop"} else {"rename"}
        Dir        = $File.DirectoryName
        RelDir     = $File.DirectoryName.Substring($StatsPath.Length).TrimStart("\", "/")
        Name       = $File.Name
        NewName    = $NewName
        BackupFile = $null
    }
})

$Renames = @($Jobs | Where-Object Action -eq "rename")
$Drops   = @($Jobs | Where-Object Action -eq "drop")

Write-Host "$($Files.Count) stat files scanned: $($Renames.Count) to rename, $($Drops.Count) to drop, the rest stays as it is."

if (-not $Jobs.Count) {exit 0}

if (-not $Apply) {
    Write-Host " "
    Write-Host "Examples (rename):" -ForegroundColor Cyan
    $Renames | Select-Object -First 15 | Foreach-Object {Write-Host "  $($_.Name) -> $($_.NewName)"}
    Write-Host "Examples (drop):" -ForegroundColor Cyan
    $Drops | Select-Object -First 15 | Foreach-Object {Write-Host "  $($_.Name)"}
    Write-Host " "
    $Answer = Read-Host "Rename $($Renames.Count) and drop $($Drops.Count) file(s) now? [Y/N]"
    if ($Answer -notmatch "^y") {
        Write-Host "Nothing changed." -ForegroundColor Yellow
        exit 0
    }
}

$BackupPath = Join-Path $StatsPath ("Renumber-backup-{0}" -f (Get-Date -Format "yyyyMMdd-HHmmss"))
$Moved = 0
$Renamed = 0
$Failed = 0

# first move every touched file out of the way, so no rename can hit an occupied name
foreach ($Job in $Jobs) {
    try {
        $BackupDir = if ($Job.RelDir) {Join-Path $BackupPath $Job.RelDir} else {$BackupPath}
        if (-not (Test-Path $BackupDir)) {New-Item -ItemType Directory -Path $BackupDir -Force -ErrorAction Stop | Out-Null}
        Move-Item -LiteralPath (Join-Path $Job.Dir $Job.Name) -Destination (Join-Path $BackupDir $Job.Name) -Force -ErrorAction Stop
        $Job.BackupFile = Join-Path $BackupDir $Job.Name
        $Moved++
    } catch {
        Write-Host "Failed to move $($Job.Name): $($_.Exception.Message)" -ForegroundColor Red
        $Failed++
    }
}

# then bring the renamed ones back under the new name
foreach ($Job in $Renames) {
    if (-not $Job.BackupFile) {continue}
    $Target = Join-Path $Job.Dir $Job.NewName
    try {
        if (Test-Path -LiteralPath $Target) {throw "target $($Job.NewName) still exists"}
        Copy-Item -LiteralPath $Job.BackupFile -Destination $Target -ErrorAction Stop
        $Renamed++
    } catch {
        Write-Host "Failed to rename $($Job.Name): $($_.Exception.Message)" -ForegroundColor Red
        $Failed++
    }
}

Write-Host "$Renamed file(s) renamed, $($Moved - $Renamed) dropped, $Failed failed." -ForegroundColor $(if ($Failed) {"Yellow"} else {"Green"})
Write-Host "Originals are in $BackupPath" -ForegroundColor Green
