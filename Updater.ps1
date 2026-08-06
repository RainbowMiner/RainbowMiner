[CmdletBinding()]
param(
    [Parameter(Mandatory = $false)]
    [String]$calledfrom = "bat",
    [Parameter(Mandatory = $false)]
    [Bool]$UpdateToMaster = $false
)

if ($script:MyInvocation.MyCommand.Path) {Set-Location (Split-Path $script:MyInvocation.MyCommand.Path)}

#[Environment]::CurrentDirectory = $ExecutionContext.SessionState.Path.CurrentFileSystemLocation

if ([Net.ServicePointManager]::SecurityProtocol -notmatch [Net.SecurityProtocolType]::Tls12) {
    [Net.ServicePointManager]::SecurityProtocol += [Net.SecurityProtocolType]::Tls12
}

if (-not (Test-Path ".\Data\version.json")) {
    Write-Host "No version info found. Update will be stopped"
    exit
}

if (Test-Path "Start.bat.saved") {
    $SavedAge = (Get-Date) - (Get-Item "Start.bat.saved").LastWriteTime
    if (($calledfrom -ne "core") -and ($SavedAge.TotalMinutes -le 15)) {exit}
    Remove-Item "Start.bat.saved" -Force
    if (Test-Path "start.sh.saved") {Remove-Item "start.sh.saved" -Force}
    if (Test-Path "StartWD.bat.saved") {Remove-Item "StartWD.bat.saved" -Force}
    if (Test-Path "startwd.sh.saved") {Remove-Item "startwd.sh.saved" -Force}
}

if (-not (Get-Module -Name Include)) { Import-Module .\Modules\Include.psm1 }
if (-not (Get-Module -Name WebLib)) { Import-Module .\Modules\WebLib.psm1 }

Set-OsFlags

# materialize/refresh the helper binaries from .\Includes\dist first, so that .\7z.exe
# exists for the extraction below (fresh installs and master updates stage them only)
if ($IsWindows) {try {Update-HelperBinaries} catch {}}

$RBMVersion = Confirm-Version (Get-Content ".\Data\version.json" -Raw | ConvertFrom-Json -ErrorAction Ignore).Version -Force -Silent

if (Test-Path ".\Downloads\config.json") {
    try {
        $DownloaderConfig = Get-Content ".\Downloads\config.json" -Raw | ConvertFrom-Json -ErrorAction Ignore
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

$Name = "RainbowMiner"

$MaxPages = if ($IsWindows) {"3"} else {"4"}

try {
    if (($RBMVersion.RemoteVersion -gt $RBMVersion.Version -and $RBMVersion.DownloadURI) -or $UpdateToMaster) {
        if ($UpdateToMaster) {
            $UpdateTo = "MASTER"
            $DownloadURI = "https://github.com/RainbowMiner/RainbowMiner/archive/master.zip"
        } else {
            $UpdateTo = "v$($RBMVersion.RemoteVersion)"
            $DownloadURI = $RBMVersion.DownloadURI
        }
        Write-Host "Updating from v$($RBMVersion.Version) to $UpdateTo" -ForegroundColor Yellow
        Write-Host " (1/$($MaxPages)) Downloading $($DownloadURI) .. "
        
        if (-not (Test-Path ".\Downloads")) {New-Item "Downloads" -ItemType "directory" | Out-Null}
        $FileName = Join-Path ".\Downloads" (Split-Path $DownloadURI -Leaf)
        if (Test-Path $FileName) {Remove-Item $FileName}

        if ($DownloadURI -eq "") {throw}

        Invoke-WebRequest $DownloadURI -OutFile $FileName -UseBasicParsing -Proxy $Proxy.Proxy -ProxyCredential $Proxy.Credentials

        if (-not (Test-Path $FileName) -or (Get-Item $FileName).Length -lt 2MB) {throw}

        Write-Host " (2/$($MaxPages)) Deleting and backup old files .."

        # Copy-Item preserves the source LastWriteTime (which stems from the release archive), so
        # stamp the copies fresh - the sentinel age check at the top compares against LastWriteTime
        @("Start.bat","start.sh","StartWD.bat","startwd.sh") | Foreach-Object {if (Test-Path $_) {Copy-Item $_ "$($_).saved" -Force -ErrorAction Ignore;try {(Get-Item "$($_).saved" -ErrorAction Stop).LastWriteTime = Get-Date} catch {}}}
        if ((Test-Path "MinersOldVersions") -and (Test-Path "Miners")) {$PreserveMiners = Compare-Object @(Get-ChildItem "Miners" | Select-Object -ExpandProperty Name) @(Get-ChildItem "MinersOldVersions" | Select-Object -ExpandProperty Name) -IncludeEqual -ExcludeDifferent | Select-Object -ExpandProperty InputObject}
        if (-not $UpdateToMaster) {
            # release archives extract in-place, so retired files must be removed up front - master
            # archives extract into .\RainbowMiner-master first, their delete runs after verification
            @("Miners","APIs","Balances","Pools") | Foreach-Object {if (Test-Path ".\$($_)") {Remove-Item ".\$($_)" -Recurse -Force -ErrorAction Ignore}}
            Get-ChildItem ".\Data" -Filter "*.json" -File | Where-Object {$_.Name -notin @("lastdrun.json","localapiport.json","minerdata.json","mrrinfo.json","poolsdata.json","unprofitable.json","version.json")} | Foreach-Object {Remove-Item $_.FullName -Force -ErrorAction Ignore}
        }

        Write-Host " (3/$($MaxPages)) Extracting new files .."

        $FromFullPath = [IO.Path]::GetFullPath($FileName)
        $ToFullPath   = [IO.Path]::GetFullPath(".")

        if ($IsWindows) {
            $Params = @{
                FilePath     = $Global:7zip
                ArgumentList = "x `"$FromFullPath`" -o`"$ToFullPath`" -y -spe"
            }
        } else {
            $Params = @{
                FilePath     = $Global:7zip
                ArgumentList = "x `"$FromFullPath`" -o`"$ToFullPath`" -y"
                RedirectStandardOutput = Join-Path ".\Logs" "7z-console.log"
                RedirectStandardError  = Join-Path ".\Logs" "7z-error.log"
            }
        }

        $Params.PassThru = $true

        # essential files that must exist after the update - if any of them is missing, the
        # installation would crash-loop on the next start
        $RequiredFiles = @("RainbowMiner.ps1","Modules\Include.psm1","Data\algorithms.json","Data\regions.json")

        $UpdateOK = $false

        for ($Attempt = 1; $Attempt -le 2; $Attempt++) {

            # a stale folder from an earlier failed run would resurrect retired files during the merge
            if ($UpdateToMaster -and (Test-Path ".\RainbowMiner-master")) {Remove-Item ".\RainbowMiner-master" -Recurse -Force -ErrorAction Ignore}

            $UpdateProcess = Start-Process @Params
            $UpdateProcess.WaitForExit() > $null
            # 7z exit code 1 = warnings only, exit code 2 can be caused by files that are
            # write-locked by a running instance (legacy archives) - the extraction result
            # is verified below, everything above 2 is a fatal extraction error
            if ($UpdateProcess.ExitCode -gt 2) {
                Write-Host "WARNING: extraction failed with exit code $($UpdateProcess.ExitCode)$(if ($Attempt -lt 2) {", retrying"})" -ForegroundColor Yellow
                continue
            }
            if ($UpdateProcess.ExitCode -eq 2) {
                Write-Host "WARNING: 7-Zip reported locked or failed files - verifying the extracted installation" -ForegroundColor Yellow
                if (-not $UpdateToMaster) {
                    # a successfully completed extraction has refreshed RainbowMiner.ps1 to the remote version
                    $ExtractedVersion = $null
                    try {
                        if ((Get-Content ".\RainbowMiner.ps1" -Raw) -match '\$Session\.Version\s*=\s*"([0-9\.]+)"') {$ExtractedVersion = $Matches[1]}
                    } catch {
                    }
                    if (-not $ExtractedVersion -or (Compare-Version $ExtractedVersion "$($RBMVersion.RemoteVersion)") -lt 0) {
                        Write-Host "WARNING: the extracted files do not match v$($RBMVersion.RemoteVersion)$(if ($Attempt -lt 2) {", retrying"})" -ForegroundColor Yellow
                        continue
                    }
                }
            }

            if ($UpdateToMaster) {
                $PathToMaster = ".\RainbowMiner-master"
                if (-not (Test-Path (Join-Path $PathToMaster "RainbowMiner.ps1"))) {
                    Write-Host "WARNING: the extracted archive is incomplete$(if ($Attempt -lt 2) {", retrying"})" -ForegroundColor Yellow
                    Remove-Item -Path $PathToMaster -Recurse -Force -ErrorAction Ignore
                    continue
                }
                # extraction is verified - only now it is safe to remove the old files
                @("Miners","APIs","Balances","Pools") | Foreach-Object {if (Test-Path ".\$($_)") {Remove-Item ".\$($_)" -Recurse -Force -ErrorAction Ignore}}
                Get-ChildItem ".\Data" -Filter "*.json" -File | Where-Object {$_.Name -notin @("lastdrun.json","localapiport.json","minerdata.json","mrrinfo.json","poolsdata.json","unprofitable.json","version.json")} | Foreach-Object {Remove-Item $_.FullName -Force -ErrorAction Ignore}
                try {
                    $FolderToSkip = if ($IsWindows) {"IncludesLinux"} else {"Includes"}
                    Get-ChildItem -Path $PathToMaster -Force | Where-Object {-not ($_.PSIsContainer -and $_.Name -eq $FolderToSkip)} | ForEach-Object {
                        $CopyErrors = $null
                        if ($_.PSIsContainer -and (Test-Path (Join-Path $ToFullPath $_.Name))) {
                            Copy-Item -Path (Join-Path $_.FullName "*") -Destination (Join-Path $ToFullPath $_.Name) -Recurse -Force -ErrorAction SilentlyContinue -ErrorVariable CopyErrors
                        } else {
                            Move-Item -Path $_.FullName -Destination $ToFullPath -Force -ErrorAction SilentlyContinue -ErrorVariable CopyErrors
                        }
                        if ($CopyErrors) {
                            Write-Host "WARNING: $($CopyErrors.Count) file(s) could not be updated in $($_.Name)" -ForegroundColor Yellow
                            $CopyErrors | Foreach-Object {Write-Host "  $($_.TargetObject)" -ForegroundColor Yellow}
                        }
                    }
                } catch {
                    Write-Host "WARNING: master update incomplete: $($_.Exception.Message)" -ForegroundColor Yellow
                } finally {
                    Remove-Item -Path $PathToMaster -Recurse -Force -ErrorAction Ignore
                }
            }

            $MissingFiles = @($RequiredFiles | Where-Object {-not (Test-Path ".\$($_)")})
            if ($MissingFiles.Count -eq 0) {
                $UpdateOK = $true
                break
            }
            Write-Host "WARNING: files are missing after the update: $($MissingFiles -join ', ')$(if ($Attempt -lt 2) {", retrying"})" -ForegroundColor Yellow
        }

        if (-not $UpdateOK) {
            throw "the update did not complete - the downloaded archive is kept at $($FromFullPath): extract it over this folder (overwrite all) to repair the installation"
        }

        if ($PreserveMiners) {$PreserveMiners | Foreach-Object {if (Test-Path "MinersOldVersions\$_") {Copy-Item "MinersOldVersions\$_" "Miners\$_" -Force}}}

        if ($IsWindows) {
            # Handle write locks: the helper binaries are staged in .\Includes\dist by the
            # archive and synced to their live positions here - the extracting 7z.exe has
            # exited at this point, so even 7z.exe/7z.dll can be overwritten
            try {
                Update-HelperBinaries
            } catch {
                Write-Host "Failed to update exe files. Please download manually from Github." -ForegroundColor Yellow
            }
        } else {
            Get-ChildItem ".\*.sh" -File | Foreach-Object {try {& chmod +x "$($_.FullName)" > $null} catch {}}
            Get-ChildItem ".\IncludesLinux\bash\*" -File | Foreach-Object {try {& chmod +x "$($_.FullName)" > $null} catch {}}
            Get-ChildItem ".\IncludesLinux\bin\*" -File | Foreach-Object {try {& chmod +x "$($_.FullName)" > $null} catch {}}
            Write-Host " (4/$($MaxPages)) Checking for libraries and dependencies .."
            Start-Process ".\IncludesLinux\bash\libnv.sh" -Wait
        }

        if (-not $DownloaderConfig.EnableKeepDownloads -and (Test-Path $FileName)) {
            Get-ChildItem $FileName -File | Foreach-Object {Remove-Item $_}
        }

        Write-Host "Update finished. Restarting $Name .." -ForegroundColor Green
    } else {
        Write-Host "RainbowMiner is already uptodate. Restarting .." -ForegroundColor Green
    }
}
catch {
    Write-Host "$Name failed to update: $($_.Exception.Message)" -ForegroundColor Yellow
    Write-Host "Please download manually at $($RBMVersion.ManualURI)" -ForegroundColor Yellow
    if ($calledfrom -ne "core") {
        $message = "Press any key to return to $name"
        if ($psISE)
        {
            Add-Type -AssemblyName System.Windows.Forms
            [System.Windows.Forms.MessageBox]::Show("$message")
        }
        else
        {
            Write-Host "$message" -ForegroundColor Yellow
            [void]($Host.UI.RawUI.ReadKey('NoEcho,IncludeKeyDown'))
        }
    } else {
        Sleep 2
    }
    exit 0
}

if (-not $psISE) {
    exit 1
}
