using module .\Include.psm1

$DownloadList = $args

if ($script:MyInvocation.MyCommand.Path) {Set-Location (Split-Path $script:MyInvocation.MyCommand.Path)}

$Progress = 0

[System.Collections.ArrayList]$RunningMiners_Paths = @()
try {
    $RunningMiners_Request = Invoke-RestMethod "http://localhost:4000/runningminers" -UseBasicParsing -TimeoutSec 10 -ErrorAction Stop
    if ($RunningMiners_Request -isnot [array]) {
        if (-not $RunningMiners_Paths.Contains($RunningMiners_Request.Path)) {
            $RunningMiners_Paths.Add($RunningMiners_Request.Path) | Out-Null
        }
    }
    else {
        $RunningMiners_Request | Foreach-Object {$RunningMiners_Paths += $_.Path}
    }
}
catch {
    Write-Log -Level Warn "RainbowMiner API is down!"
}

$DownloadList | Where-Object {-not $RunningMiners_Paths.Contains($_.Path)} | ForEach-Object {
    $URI = $_.URI
    $Path = $_.Path
    $Searchable = $_.Searchable

    $Progress += 100 / $DownloadList.Count

    $UriJson = (Split-Path $Path) + "\_uri.json"
    $UriJsonData = [PSCustomObject]@{URI = ""}

    if ((Test-Path $Path) -and (Test-Path $UriJson)) {
        $UriJsonData = Get-Content $UriJson -Raw -ErrorAction Ignore | ConvertFrom-Json -ErrorAction Ignore
    }

    if (-not (Test-Path $Path) -or $URI -ne $UriJsonData.URI) {
       
        $ProgressPreferenceBackup = $ProgressPreference
        try {
            $ProgressPreference = $ProgressPreferenceBackup
            Write-Progress -Activity "Downloader" -Status $Path -CurrentOperation "Acquiring Online ($URI)" -PercentComplete $Progress

            $ProgressPreference = "SilentlyContinue"
            if ($URI -and (Split-Path $URI -Leaf) -eq (Split-Path $Path -Leaf)) {
                New-Item (Split-Path $Path) -ItemType "Directory" | Out-Null
                Invoke-WebRequest $URI -OutFile $Path -UseBasicParsing -ErrorAction Stop
            }
            else {
                Expand-WebRequest $URI (Split-Path $Path) -ErrorAction Stop
            }
            [PSCustomObject]@{URI = $URI} | ConvertTo-Json | Set-Content $UriJson -Encoding UTF8
        }
        catch {
            $ProgressPreference = $ProgressPreferenceBackup
            Write-Progress -Activity "Downloader" -Status $Path -CurrentOperation "Acquiring Offline (Computer)" -PercentComplete $Progress

            $ProgressPreference = "SilentlyContinue"
            Write-Log -Level Warn "Downloader-error: $($_.Exception.Message)"
            if ($URI) {Write-Log -Level Warn "Cannot download $($Path) distributed at $($URI). "}
            else {Write-Log -Level Warn "Cannot download $($Path). "}

            if ($Searchable) {
                Write-Log -Level Warn "Searching for $($Path). "

                $Path_Old = Get-PSDrive -PSProvider FileSystem | ForEach-Object {Get-ChildItem -Path $_.Root -Include (Split-Path $Path -Leaf) -Recurse -ErrorAction Ignore} | Sort-Object LastWriteTimeUtc -Descending | Select-Object -First 1
                $Path_New = $Path
            }

            if ($Path_Old) {
                if (Test-Path (Split-Path $Path_New)) {(Split-Path $Path_New) | Remove-Item -Recurse -Force}
                (Split-Path $Path_Old) | Copy-Item -Destination (Split-Path $Path_New) -Recurse -Force
            }
            else {
                if ($URI) {Write-Log -Level Warn "Cannot find $($Path) distributed at $($URI). "}
                else {Write-Log -Level Warn "Cannot find $($Path). "}
            }
        }
        $ProgressPreference = $ProgressPreferenceBackup
    } elseif (-not (Test-Path $UriJson)) {
        [PSCustomObject]@{URI = $URI} | ConvertTo-Json | Set-Content $UriJson -Encoding UTF8
    }

}

Write-Progress -Activity "Downloader" -Completed