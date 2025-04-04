﻿[CmdletBinding()]
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
    if ($calledfrom -ne "core") {exit}
    Remove-Item "Start.bat.saved" -Force
    if (Test-Path "start.sh.saved") {Remove-Item "start.sh.saved" -Force}
}

if (-not (Get-Module -Name Include)) { Import-Module .\Modules\Include.psm1 }
if (-not (Get-Module -Name WebLib)) { Import-Module .\Modules\WebLib.psm1 }

Set-OsFlags

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

        @("Start.bat","start.sh") | Foreach-Object {if (Test-Path $_) {Copy-Item $_ "$($_).saved" -Force -ErrorAction Ignore}}
        if ((Test-Path "MinersOldVersions") -and (Test-Path "Miners")) {$PreserveMiners = Compare-Object @(Get-ChildItem "Miners" | Select-Object -ExpandProperty Name) @(Get-ChildItem "MinersOldVersions" | Select-Object -ExpandProperty Name) -IncludeEqual -ExcludeDifferent | Select-Object -ExpandProperty InputObject}
        @("Miners","APIs","Balances","Pools") | Foreach-Object {if (Test-Path ".\$($_)") {Remove-Item ".\$($_)" -Recurse -Force -ErrorAction Ignore}}
        Get-ChildItem ".\Data" -Filter "*.json" -File | Where-Object {$_.Name -notin @("lastdrun.json","localapiport.json","minerdata.json","mrrinfo.json","poolsdata.json","unprofitable.json","version.json")} | Foreach-Object {Remove-Item $_.FullName -Force -ErrorAction Ignore}

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
        (Start-Process @Params).WaitForExit() > $null

        if ($UpdateToMaster) {
            $PathToMaster = ".\RainbowMiner-master"
            if (Test-Path $PathToMaster) {
                try {
                    $FolderToRemove = if ($IsWindows) {"IncludesLinux"} else {"Includes"}
                    $FolderToRemove = Join-Path $PathToMaster $FolderToRemove
                    if (Test-Path $FolderToRemove) {
                        Remove-Item -Path $FolderToRemove -Recurse -Force
                    }
                    Move-Item -Path (Join-Path $PathToMaster "*") -Destination $ToFullPath -Force
                    Remove-Item -Path $PathToMaster -Recurse -Force
                } catch {}
            }
        }

        if ($PreserveMiners) {$PreserveMiners | Foreach-Object {if (Test-Path "MinersOldVersions\$_") {Copy-Item "MinersOldVersions\$_" "Miners\$_" -Force}}}

        if ($IsWindows) {
            #Handle write locks
            try {
                if (-not (Test-Path "_update")) {New-Item "_update" -ItemType "directory" > $null}
                $Params = @{
                    FilePath     = $Global:7zip
                    ArgumentList = "x `"$FromFullPath`" -o`"$(Join-Path $ToFullPath "_update")`" 7z.exe 7z.dll `"Includes\curl\x32\curl.exe`" `"Includes\curl\x64\curl.exe`" `"Includes\curl\x32\libcurl.dll`" `"Includes\curl\x64\libcurl-x64.dll`" `"Includes\getcpu\GetCPU.exe`" `"Includes\getcpu\LibreHardwareMonitorLib.dll`" -y -spe"
                    PassThru     = $true
                }
                (Start-Process @Params).WaitForExit() > $null
                Get-ChildItem "_update" -Recurse -File | Foreach-Object {
                    $FileNameTo   = $_.FullName -replace "^.+\\_update\\"
                    if (-not (Test-Path $FileNameTo) -or ((Get-FileHash $FileNameTo -Algorithm MD5).Hash -ne (Get-FileHash $_.FullName -Algorithm MD5).Hash)) {
                        Write-Host "Update $FileNameTo"
                        try {
                            $RetryLock = 20
                            $IsLocked  = $true
                            do {
                                Try {
                                    Copy-Item -Path $_.FullName -Destination $FileNameTo -Force
                                    $IsLocked = $False
                                } Catch {
                                    $RetryLock--
                                    if ($RetryLock -gt 0) {Sleep -Milliseconds 250}
                                }
                            } while ($IsLocked -and ($RetryLock -gt 0))
                        } catch {
                        }
                        if ($IsLocked) {
                            Write-Host "Failed to update $FileNameTo. Please download manually from Github." -ForegroundColor Yellow
                        }
                    }
                }
                if (Test-Path "_update") {
                    Remove-Item "_update" -Force -Recurse
                }
            } catch {
                Write-Host "Failed to update exe files. Please download manually from Github." -ForegroundColor Yellow
            }
        } else {
            Get-ChildItem ".\*.sh" -File | Foreach-Object {try {& chmod +x "$($_.FullName)" > $null} catch {}}
            Get-ChildItem ".\IncludesLinux\bash\*" -File | Foreach-Object {try {& chmod +x "$($_.FullName)" > $null} catch {}}
            Get-ChildItem ".\IncludesLinux\bin\*" -File | Foreach-Object {try {& chmod +x "$($_.FullName)" > $null} catch {}}
            Write-Host " (4/$($MaxPages)) Checking for libraries and dependancies .."
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
    Write-Host "$Name failed to update. Please download manually at $($RBMVersion.ManuaURI)" -ForegroundColor Yellow
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
