using module .\Include.psm1

if ($script:MyInvocation.MyCommand.Path) {Set-Location (Split-Path $script:MyInvocation.MyCommand.Path)}

[Environment]::CurrentDirectory = $ExecutionContext.SessionState.Path.CurrentFileSystemLocation

$ProgressPreferenceBackup = $ProgressPreference

# Support SSL connection
[Net.ServicePointManager]::SecurityProtocol = "tls12, tls11, tls"

if (-not (Test-Path ".\Data\Version.json")) {
    Write-Host "No version info found. Update will be stopped"
    exit
}

$RBMVersion = (Get-Content ".\Data\Version.json" | ConvertFrom-Json).Version
$PSVersion = $PSVersionTable.PSVersion

$Name = "RainbowMiner"
try {
    $ProgressPreference = "SilentlyContinue"
    $Request = Invoke-RestMethod -Uri "https://api.github.com/repos/rainbowminer/$Name/releases/latest" -UseBasicParsing -TimeoutSec 10 -ErrorAction Stop
    $Version = ($Request.tag_name -replace '^v')
    $Uri = $Request.assets | Where-Object Name -EQ "$($Name)V$($Version).zip" | Select-Object -ExpandProperty browser_download_url

    if ( (Get-Version($Version)) -gt (Get-Version($RBMVersion)) ) {
        Write-Host "$Name is out of date. Updating from v$(Get-Version($RBMVersion)) to v$(Get-Version($Version))" -ForegroundColor Yellow
        $ProgressPreference = $ProgressPreferenceBackup
        Write-Host " (1/3) Downloading $URI .. "
        
        $ProgressPreference = "SilentlyContinue"

        if (-not (Test-Path ".\Downloads")) {New-Item "Downloads" -ItemType "directory" | Out-Null}
        $FileName = Join-Path ".\Downloads" (Split-Path $Uri -Leaf)
        if (Test-Path $FileName) {Remove-Item $FileName}
        Invoke-WebRequest $Uri -OutFile $FileName -UseBasicParsing

        Write-Host " (2/3) Deleting old files .."

        @("Miners","APIs","Benchmarks","Pools") | Foreach-Object {if (Test-Path ".\$($_)") {Remove-Item ".\$($_)" -Recurse -Force}}

        Write-Host " (3/3) Extracting new files .."

        Start-Process "7z" "x `"$([IO.Path]::GetFullPath($FileName))`" -o`"$([IO.Path]::GetFullPath("."))`" -y -spe" -Wait

        Write-Host "Update finished. Restarting $Name .." -ForegroundColor Green
    }
}
catch {
    Write-Host "$Name failed to update. Please download manually at https://github.com/rainbowminer/$Name/releases/latest" -ForegroundColor Yellow
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
        exit 0
    }
}

if (-not $psISE) {
    exit 1
}
