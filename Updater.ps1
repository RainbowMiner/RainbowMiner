using module .\Include.psm1

if ($script:MyInvocation.MyCommand.Path) {Set-Location (Split-Path $script:MyInvocation.MyCommand.Path)}

[Environment]::CurrentDirectory = $ExecutionContext.SessionState.Path.CurrentFileSystemLocation

# Support SSL connection
[Net.ServicePointManager]::SecurityProtocol = "tls12, tls11, tls"

if (-not (Test-Path ".\Data\Version.json")) {
    Write-Host "No version info found. Update will be stopped"
    exit
}

$RBMVersion = Confirm-Version (Get-Content ".\Data\Version.json" | ConvertFrom-Json).Version -Force

$Name = "RainbowMiner"
try {
    if ($RBMVersion.RemoteVersion -gt $RBMVersion.Version -and $RBMVersion.DownloadURI) {
        Write-Host "Updating from v$($RBMVersion.Version) to v$($RBMVersion.RemoteVersion)" -ForegroundColor Yellow
        Write-Host " (1/3) Downloading $($RBMVersion.DownloadURI) .. "
        
        if (-not (Test-Path ".\Downloads")) {New-Item "Downloads" -ItemType "directory" | Out-Null}
        $FileName = Join-Path ".\Downloads" (Split-Path $RBMVersion.DownloadURI -Leaf)
        if (Test-Path $FileName) {Remove-Item $FileName}
        Invoke-WebRequest $RBMVersion.DownloadURI -OutFile $FileName -UseBasicParsing

        Write-Host " (2/3) Deleting old files .."

        @("Miners","APIs","Benchmarks","Pools") | Foreach-Object {if (Test-Path ".\$($_)") {Remove-Item ".\$($_)" -Recurse -Force}}

        Write-Host " (3/3) Extracting new files .."

        Start-Process "7z" "x `"$([IO.Path]::GetFullPath($FileName))`" -o`"$([IO.Path]::GetFullPath("."))`" -y -spe" -Wait

        Write-Host "Update finished. Restarting $Name .." -ForegroundColor Green
    } else {
        Write-Host "RainbowMiner is already uptodate. Restarting .." -ForegroundColor Green
    }
}
catch {
    Write-Host "$Name failed to update. Please download manually at $($RBMVersion.ManuaURI)" -ForegroundColor Yellow
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
