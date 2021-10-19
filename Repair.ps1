
if ($script:MyInvocation.MyCommand.Path) {Set-Location (Split-Path $script:MyInvocation.MyCommand.Path)}

#[Environment]::CurrentDirectory = $ExecutionContext.SessionState.Path.CurrentFileSystemLocation

if ($Global:IsWindows -eq $null) {
    $Global:IsWindows = [System.Environment]::OSVersion.Platform -eq "Win32NT" -or [System.Boolean](Get-CimInstance -ClassName Win32_OperatingSystem -ErrorAction Ignore)
    $Global:IsLinux   = -not $IsWindows
    $Global:IsMacOS   = $false
}

if ("$((Get-Culture).NumberFormat.NumberGroupSeparator)$((Get-Culture).NumberFormat.NumberDecimalSeparator)" -notmatch "^[,.]{2}$") {
    [CultureInfo]::CurrentCulture = 'en-US'
}

if (-not (Get-Command "Start-ThreadJob" -ErrorAction SilentlyContinue)) {Set-Alias -Scope Global Start-ThreadJob Start-Job}

if ([Net.ServicePointManager]::SecurityProtocol -notmatch [Net.SecurityProtocolType]::Tls12) {
    [Net.ServicePointManager]::SecurityProtocol += [Net.SecurityProtocolType]::Tls12
}

if (Test-Path ".\Downloads\config.json") {
    try {
        $DownloaderConfig = Get-Content -Raw ".\Downloads\config.json" | ConvertFrom-Json -ErrorAction Ignore
    } catch {
        if ($Error.Count){$Error.RemoveAt(0)}
    }
}
if (-not $DownloaderConfig) {
    $DownloaderConfig = [PSCustomObject]@{
            EnableMinerBackups  = $true
            EnableKeepDownloads = $true
        }
}

$Name = "RainbowMiner"

$Proxy = Get-Proxy

try {
    $ReposURI = "https://api.github.com/repos/rainbowminer/$Name/releases/latest"
    $Request = Invoke-RestMethod $ReposURI -UseBasicParsing -TimeoutSec 30 -Proxy $Proxy.Proxy -ProxyCredential $Proxy.Credentials

    $RemoteVersion = ($Request.tag_name -replace '^v')
    if ($RemoteVersion) {
        if ($IsWindows) {
            $DownloadURI = $Request.assets | Where-Object Name -EQ "$($Name)V$($RemoteVersion)_win.zip" | Select-Object -ExpandProperty browser_download_url
        } elseif ($IsLinux) {
            $DownloadURI = $Request.assets | Where-Object Name -EQ "$($Name)V$($RemoteVersion)_linux.zip" | Select-Object -ExpandProperty browser_download_url
        }
        if (-not $DownloadURI) {
            $DownloadURI = $Request.assets | Where-Object Name -EQ "$($Name)V$($RemoteVersion).zip" | Select-Object -ExpandProperty browser_download_url
        }
    }

    Write-Host "Repair & Update v$($RemoveVersion)" -ForegroundColor Yellow
    Write-Host " (1/3) Downloading $($DownloadURI) .. "
        
    if (-not (Test-Path ".\Downloads")) {New-Item "Downloads" -ItemType "directory" | Out-Null}
    $FileName = Join-Path ".\Downloads" (Split-Path $DownloadURI -Leaf)
    if (Test-Path $FileName) {Remove-Item $FileName}

    if ($DownloadURI -eq "") {throw}

    Invoke-WebRequest $DownloadURI -OutFile $FileName -UseBasicParsing -Proxy $Proxy.Proxy -ProxyCredential $Proxy.Credentials

    if (-not (Test-Path $FileName) -or (Get-Item $FileName).Length -lt 2MB) {throw}

    Write-Host " (2/3) Deleting and backup old files .."

    @("Start.bat","start.sh") | Foreach-Object {if (Test-Path $_) {Copy-Item $_ "$($_).saved" -Force -ErrorAction Ignore}}
    if (Test-Path "MinersOldVersions") {$PreserveMiners = Compare-Object @(Get-ChildItem "Miners" | Select-Object -ExpandProperty Name) @(Get-ChildItem "MinersOldVersions" | Select-Object -ExpandProperty Name) -IncludeEqual -ExcludeDifferent | Select-Object -ExpandProperty InputObject}
    @("Miners","APIs","Balances","Pools") | Foreach-Object {if (Test-Path ".\$($_)") {Remove-Item ".\$($_)" -Recurse -Force -ErrorAction Ignore}}
    Get-ChildItem ".\Data" -Filter "*.json" -File | Where-Object {$_.Name -notin @("lastdrun.json","localapiport.json","minerdata.json","mrrinfo.json","poolsdata.json","unprofitable.json","version.json")} | Foreach-Object {Remove-Item $_.FullName -Force -ErrorAction Ignore}

    Write-Host " (3/3) Extracting new files .."
        
    $FromFullPath = [IO.Path]::GetFullPath($FileName)
    $ToFullPath   = [IO.Path]::GetFullPath(".")

    if ($IsLinux) {
        $Params = @{
            FilePath     = "7z"
            ArgumentList = "x `"$FromFullPath`" -o`"$ToFullPath`" -y"
            RedirectStandardOutput = Join-Path ".\Logs" "7z-console.log"
            RedirectStandardError  = Join-Path ".\Logs" "7z-error.log"
        }
    } else {
        $Params = @{
            FilePath     = "7z"
            ArgumentList = "x `"$FromFullPath`" -o`"$ToFullPath`" -y -spe"
        }
    }

    $Params.PassThru = $true
    (Start-Process @Params).WaitForExit() > $null

    if ($PreserveMiners) {$PreserveMiners | Foreach-Object {if (Test-Path "MinersOldVersions\$_") {Copy-Item "MinersOldVersions\$_" "Miners\$_" -Force}}}

    if ($IsLinux) {
        Get-ChildItem ".\*.sh" -File | Foreach-Object {try {& chmod +x "$($_.FullName)" > $null} catch {}}
        Get-ChildItem ".\IncludesLinux\bash\*" -File | Foreach-Object {try {& chmod +x "$($_.FullName)" > $null} catch {}}
        Get-ChildItem ".\IncludesLinux\bin\*" -File | Foreach-Object {try {& chmod +x "$($_.FullName)" > $null} catch {}}
    } elseif ($IsWindows) {
        #Handle write locks
        try {
            if (-not (Test-Path "_update")) {New-Item "_update" -ItemType "directory" > $null}
            $Params = @{
                FilePath     = "7z"
                ArgumentList = "x `"$FromFullPath`" -o`"$(Join-Path $ToFullPath "_update")`" 7z.exe 7z.dll `"Includes\curl\x32\curl.exe`" `"Includes\curl\x64\curl.exe`" `"Includes\curl\x32\libcurl.dll`" `"Includes\curl\x64\libcurl-x64.dll`" `"Includes\getcpu\GetCPU.exe`" `"Includes\getcpu\OpenHardwareMonitorLib.dll`" -y -spe"
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
                        if ($Error.Count){$Error.RemoveAt(0)}
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
            if ($Error.Count){$Error.RemoveAt(0)}
            Write-Host "Failed to update exe files. Please download manually from Github." -ForegroundColor Yellow
        }
    }

    if (-not $DownloaderConfig.EnableKeepDownloads -and (Test-Path $FileName)) {
        Get-ChildItem $FileName -File | Foreach-Object {Remove-Item $_}
    }

    Write-Host "Repair & Update finished." -ForegroundColor Green
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
