﻿$DownloadList = $args

if (-not (Get-Module Include)) { Import-Module .\Modules\Include.psm1 }
if (-not (Get-Module WebLib)) { Import-Module .\Modules\WebLib.psm1 }

$LocalAPIport = $(if (Test-Path ".\Data\localapiport.json") {Get-Content ".\Data\localapiport.json" -Raw | ConvertFrom-Json}).LocalAPIport
if (-not $LocalAPIport) {$LocalAPIport = 4000}

Set-OsFlags -NoDLLs

$ProtectedMinerFiles = if (Test-Path ".\Data\protectedminerfiles.json") {Get-Content ".\Data\protectedminerfiles.json" -Raw | ConvertFrom-Json}
if (Test-Path ".\Config\minerconfigfiles.txt") {Get-Content ".\Config\minerconfigfiles.txt" | Where-Object {$_ -match "^([^;]+)"} | Foreach-Object {if ($File = $Matches[1].Trim()) {$ProtectedMinerFiles += $File}}}

$Sha256 = if (Test-Path (".\Data\minersha256.json")) {Get-Content ".\Data\minersha256.json" -Raw | ConvertFrom-Json}

[System.Collections.ArrayList]$RunningMiners_Paths = @()
try {
    $RunningMiners_Request = Invoke-RestMethod "http://localhost:$($LocalAPIport)/runningminers" -UseBasicParsing -ErrorAction Stop
    if ($RunningMiners_Request -isnot [array]) {
        if (-not $RunningMiners_Paths.Contains($RunningMiners_Request.Path)) {
            [void]$RunningMiners_Paths.Add($RunningMiners_Request.Path)
        }
    }
    else {
        $RunningMiners_Request | Foreach-Object {[void]$RunningMiners_Paths.Add($_.Path)}
    }
}
catch {
    Write-Log -Level Warn "RainbowMiner API is down!"
}

if ([Net.ServicePointManager]::SecurityProtocol -notmatch [Net.SecurityProtocolType]::Tls12) {
    [Net.ServicePointManager]::SecurityProtocol += [Net.SecurityProtocolType]::Tls12
}

if (Test-Path ".\Downloads\config.json") {
    try {
        $DownloaderConfig = Get-ContentByStreamReader ".\Downloads\config.json" | ConvertFrom-Json -ErrorAction Ignore
    } catch {
    }
}
if (-not $DownloaderConfig) {
    $DownloaderConfig = [PSCustomObject]@{
            EnableMinerBackups  = $true
            EnableKeepDownloads = $true
        }
}

$Proxy = Get-Proxy

$DownloadList | Where-Object {-not $RunningMiners_Paths.Contains($_.Path)} | ForEach-Object {
    $URI = $_.URI
    $Path = $_.Path
    $IsMiner = $_.IsMiner

    if ($IsMiner) {
        $UriJson = Join-Path (Get-MinerInstPath $Path) "_uri.json"
        $UriJsonData = [PSCustomObject]@{URI = ""}

        if ((Test-Path $Path) -and (Test-Path $UriJson)) {
            $UriJsonData = Get-Content $UriJson -Raw -ErrorAction Ignore | ConvertFrom-Json -ErrorAction Ignore
        }
    }

    if (-not (Test-Path $Path) -or ($IsMiner -and ($URI -ne $UriJsonData.URI))) {
        $oldProgressPreference = $Global:ProgressPreference
        $Global:ProgressPreference = "SilentlyContinue"
        try {
            if ($URI -and (Split-Path $URI -Leaf) -eq (Split-Path $Path -Leaf)) {
                $PathFolder = Split-Path $Path
                $FileName = Join-Path ".\Downloads" (Split-Path $Uri -Leaf)

                if (-not (Test-Path $PathFolder)) {New-Item $PathFolder -ItemType "Directory" > $null}
                if (-not (Test-Path ".\Downloads"))  {New-Item "Downloads" -ItemType "directory" > $null}

                if (Test-Path $FileName) {Remove-Item $FileName}

                Invoke-WebRequest $URI -OutFile $FileName -UseBasicParsing -ErrorAction Stop -Proxy $Proxy.Proxy -ProxyCredential $Proxy.Credentials

                if ((Test-Path $FileName) -and (Get-Item $FileName).Length) {
                    Move-Item -Path $FileName -Destination $PathFolder
                }
            }
            else {
                Expand-WebRequest $URI $(if ($IsMiner) {Get-MinerInstPath $Path} else {Split-Path $Path}) -ProtectedFiles @(if ($IsMiner) {$ProtectedMinerFiles}) -Sha256 ($Sha256.$URI) -ErrorAction Stop -EnableMinerBackups:$DownloaderConfig.EnableMinerBackups -EnableKeepDownloads:$DownloaderConfig.EnableKeepDownloads -IsMiner:$IsMiner
            }
            if ($IsMiner) {[PSCustomObject]@{URI = $URI} | ConvertTo-Json -Depth 10 | Set-Content $UriJson -Encoding UTF8}
        }
        catch {
            Write-Log -Level Warn "Downloader-error: $($_.Exception.Message)"
            if ($URI) {Write-Log -Level Warn "Cannot download $($Path) distributed at $($URI). "}
            else {Write-Log -Level Warn "Cannot download $($Path). "}
        }
        $Global:ProgressPreference = $oldProgressPreference
    } elseif ($IsMiner -and -not (Test-Path $UriJson)) {
        [PSCustomObject]@{URI = $URI} | ConvertTo-Json -Depth 10 | Set-Content $UriJson -Encoding UTF8
    }
}
