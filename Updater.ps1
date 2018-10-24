using module .\Include.psm1

[CmdletBinding()]
param(
    [Parameter(Mandatory = $false)]
    [String]$calledfrom = "bat"
)

if ($script:MyInvocation.MyCommand.Path) {Set-Location (Split-Path $script:MyInvocation.MyCommand.Path)}

#[Environment]::CurrentDirectory = $ExecutionContext.SessionState.Path.CurrentFileSystemLocation

# Support SSL connection
[Net.ServicePointManager]::SecurityProtocol = "tls12, tls11, tls"

if (-not (Test-Path ".\Data\version.json")) {
    Write-Host "No version info found. Update will be stopped"
    exit
}

if (Test-Path "Start.bat.saved") {
    if ($calledfrom -ne "core") {exit}
    Remove-Item "Start.bat.saved" -Force    
}

$RBMVersion = Confirm-Version (Get-Content ".\Data\version.json" | ConvertFrom-Json).Version -Force -Silent

$Name = "RainbowMiner"
try {
    if ($RBMVersion.RemoteVersion -gt $RBMVersion.Version -and $RBMVersion.DownloadURI) {
        Write-Host "Updating from v$($RBMVersion.Version) to v$($RBMVersion.RemoteVersion)" -ForegroundColor Yellow
        Write-Host " (1/3) Downloading $($RBMVersion.DownloadURI) .. "
        
        if (-not (Test-Path ".\Downloads")) {New-Item "Downloads" -ItemType "directory" | Out-Null}
        $FileName = Join-Path ".\Downloads" (Split-Path $RBMVersion.DownloadURI -Leaf)
        if (Test-Path $FileName) {Remove-Item $FileName}

        if ($RBMVersion.DownloadURI -eq "") {throw}

        Invoke-WebRequest $RBMVersion.DownloadURI -OutFile $FileName -UseBasicParsing

        if (-not (Test-Path $FileName) -or (Get-Item $FileName).Length -lt 2MB) {throw}

        Write-Host " (2/3) Deleting and backup old files .."

        @("Start.bat") | Foreach-Object {if (Test-Path $_) {Copy-Item $_ "$($_).saved" -Force -ErrorAction Ignore}}
        if (Test-Path "MinersOldVersions") {$PreserveMiners = Compare-Object @(Get-ChildItem "Miners" | Select-Object -ExpandProperty Name) @(Get-ChildItem "MinersOldVersions" | Select-Object -ExpandProperty Name) -IncludeEqual -ExcludeDifferent | Select-Object -ExpandProperty InputObject}
        @("Miners","APIs","Balances","Pools") | Foreach-Object {if (Test-Path ".\$($_)") {Remove-Item ".\$($_)" -Recurse -Force -ErrorAction Ignore}}        

        Write-Host " (3/3) Extracting new files .."

        Start-Process "7z" "x `"$([IO.Path]::GetFullPath($FileName))`" -o`"$([IO.Path]::GetFullPath("."))`" -y -spe" -Wait

        if ($PreserveMiners) {$PreserveMiners | Foreach-Object {if (Test-Path "MinersOldVersions\$_") {Copy-Item "MinersOldVersions\$_" "Miners\$_" -Force}}}

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
