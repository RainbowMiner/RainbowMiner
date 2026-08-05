
if ($script:MyInvocation.MyCommand.Path) {Set-Location (Split-Path $script:MyInvocation.MyCommand.Path)}

#[Environment]::CurrentDirectory = $ExecutionContext.SessionState.Path.CurrentFileSystemLocation

if ($Global:IsWindows -eq $null) {
    $Global:IsWindows = [System.Environment]::OSVersion.Platform -eq "Win32NT" -or [System.Boolean](Get-CimInstance -ClassName Win32_OperatingSystem -ErrorAction Ignore)
    $Global:IsLinux   = -not $IsWindows
    $Global:IsMacOS   = $false
}

$Global:7zip = if ($Global:IsWindows) {".\7z.exe"} else {"7z"}

# fresh or broken install: materialize 7-Zip from the staging folder so extraction can work
if ($Global:IsWindows -and -not (Test-Path ".\7z.exe") -and (Test-Path ".\Includes\dist\7z.exe")) {
    try {
        Copy-Item ".\Includes\dist\7z.exe" ".\7z.exe" -Force
        if (Test-Path ".\Includes\dist\7z.dll") {Copy-Item ".\Includes\dist\7z.dll" ".\7z.dll" -Force}
    } catch {
    }
}

if ($Global:IsLinux) {
    $Global:OSArch = try {
        Switch -Regex ("$(uname -m)".Trim()) {
            "(i386|i686)" {"i386"; Break}
            "x86_64" {"amd64"; Break}
            "(arm|aarch64)" {if ("$(dpkg --print-architecture)" -match "arm64") {"arm64"} else {"arm"}; Break}
            default {$PSItem}
        }
    } catch {
        "amd64"
    }

    if (-not (Get-Command $Global:7zip -ErrorAction Ignore)) {
        $Path_7zz = ".\IncludesLinux\bin\7zz-$(if ($Global:OSArch -eq "arm") {"arm64"} else {$Global:OSArch})"
        if (Test-Path $Path_7zz) {
            $Global:7zip = $Path_7zz
            try {
                Get-ChildItem $Global:7zip -File -ErrorAction Stop | Foreach-Object {
                    & chmod +x "$($_.FullName)" > $null
                }
            } catch {
            }
        }
    }
} elseif ($Global:IsWindows) {
    $Global:OSArch = if ([System.Environment]::Is64BitOperatingSystem) {"amd64"} else {"i386"}
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
    }
}
if (-not $DownloaderConfig) {
    $DownloaderConfig = [PSCustomObject]@{
            EnableMinerBackups  = $true
            EnableKeepDownloads = $true
        }
}

$Name = "RainbowMiner"

try {
    $ReposURI = "https://api.github.com/repos/rainbowminer/$Name/releases/latest"
    $Request = Invoke-RestMethod $ReposURI -UseBasicParsing -TimeoutSec 30

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

    Write-Host "Repair & Update v$($RemoteVersion)" -ForegroundColor Yellow
    Write-Host " (1/3) Downloading $($DownloadURI) .. "
        
    if (-not (Test-Path ".\Downloads")) {New-Item "Downloads" -ItemType "directory" | Out-Null}
    $FileName = Join-Path ".\Downloads" (Split-Path $DownloadURI -Leaf)
    if (Test-Path $FileName) {Remove-Item $FileName}

    if ($DownloadURI -eq "") {throw}

    Invoke-WebRequest $DownloadURI -OutFile $FileName -UseBasicParsing

    if (-not (Test-Path $FileName) -or (Get-Item $FileName).Length -lt 2MB) {throw}

    Write-Host " (2/3) Deleting and backup old files .."

    @("Start.bat","start.sh") | Foreach-Object {if (Test-Path $_) {Copy-Item $_ "$($_).saved" -Force -ErrorAction Ignore}}
    if ((Test-Path "Miners") -and (Test-Path "MinersOldVersions")) {$PreserveMiners = Compare-Object @(Get-ChildItem "Miners" | Select-Object -ExpandProperty Name) @(Get-ChildItem "MinersOldVersions" | Select-Object -ExpandProperty Name) -IncludeEqual -ExcludeDifferent | Select-Object -ExpandProperty InputObject}
    @("Miners","APIs","Balances","Pools") | Foreach-Object {if (Test-Path ".\$($_)") {Remove-Item ".\$($_)" -Recurse -Force -ErrorAction Ignore}}
    Get-ChildItem ".\Data" -Filter "*.json" -File | Where-Object {$_.Name -notin @("lastdrun.json","localapiport.json","minerdata.json","mrrinfo.json","poolsdata.json","unprofitable.json","version.json")} | Foreach-Object {Remove-Item $_.FullName -Force -ErrorAction Ignore}

    Write-Host " (3/3) Extracting new files .."
        
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

    if ($PreserveMiners) {$PreserveMiners | Foreach-Object {if (Test-Path "MinersOldVersions\$_") {Copy-Item "MinersOldVersions\$_" "Miners\$_" -Force}}}

    if ($IsWindows) {
        # Handle write locks: the helper binaries are staged in .\Includes\dist by the
        # archive and synced to their live positions here - the extracting 7z.exe has
        # exited at this point, so even 7z.exe/7z.dll can be overwritten
        try {
            $DistPath = Join-Path $ToFullPath "Includes\dist"
            if (Test-Path $DistPath) {
                $DistFullPath = (Get-Item $DistPath).FullName.TrimEnd("\")
                Get-ChildItem $DistFullPath -Recurse -File | Foreach-Object {
                    $FileNameTo = Join-Path $ToFullPath $_.FullName.Substring($DistFullPath.Length + 1)
                    $CopyNeeded = $true
                    if (Test-Path $FileNameTo) {
                        try {
                            if ((Get-FileHash $FileNameTo -Algorithm MD5).Hash -eq (Get-FileHash $_.FullName -Algorithm MD5).Hash) {$CopyNeeded = $false}
                        } catch {
                        }
                    }
                    if ($CopyNeeded) {
                        Write-Host "Update $FileNameTo"
                        $FileDirTo = Split-Path $FileNameTo
                        if ($FileDirTo -and -not (Test-Path $FileDirTo)) {New-Item $FileDirTo -ItemType "directory" -Force > $null}
                        $RetryLock = 20
                        $IsLocked  = $true
                        do {
                            try {
                                Copy-Item -Path $_.FullName -Destination $FileNameTo -Force -ErrorAction Stop
                                $IsLocked = $false
                            } catch {
                                $RetryLock--
                                if ($RetryLock -gt 0) {Start-Sleep -Milliseconds 250}
                            }
                        } while ($IsLocked -and ($RetryLock -gt 0))
                        if ($IsLocked) {
                            Write-Host "Failed to update $FileNameTo. Please download manually from Github." -ForegroundColor Yellow
                        }
                    }
                }
            }
        } catch {
            Write-Host "Failed to update exe files. Please download manually from Github." -ForegroundColor Yellow
        }
    } else {
        Get-ChildItem ".\*.sh" -File | Foreach-Object {try {& chmod +x "$($_.FullName)" > $null} catch {}}
        Get-ChildItem ".\IncludesLinux\bash\*" -File | Foreach-Object {try {& chmod +x "$($_.FullName)" > $null} catch {}}
        Get-ChildItem ".\IncludesLinux\bin\*" -File | Foreach-Object {try {& chmod +x "$($_.FullName)" > $null} catch {}}
    }

    if (-not $DownloaderConfig.EnableKeepDownloads -and (Test-Path $FileName)) {
        Get-ChildItem $FileName -File | Foreach-Object {Remove-Item $_}
    }

    Write-Host "Repair & Update finished." -ForegroundColor Green
}
catch {
    Write-Host "$Name failed to update. Please download manually at $($DownloadURI)" -ForegroundColor Yellow
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
