using module .\Include.psm1

Set-OsFlags

if ($MyInvocation.MyCommand.Path) {Set-Location (Split-Path $MyInvocation.MyCommand.Path)}

if ($IsWindows) {
    if ($PSVersionTable.PSVersion -ge (Get-Version "6.1")) {
        Import-Module NetSecurity -ErrorAction Ignore -SkipEditionCheck
        Import-Module Defender -ErrorAction Ignore -SkipEditionCheck
        Import-Module "$env:Windir\System32\WindowsPowerShell\v1.0\Modules\NetSecurity\NetSecurity.psd1" -ErrorAction Ignore -SkipEditionCheck
        Import-Module "$env:Windir\System32\WindowsPowerShell\v1.0\Modules\Defender\Defender.psd1" -ErrorAction Ignore -SkipEditionCheck
    } else {
        Import-Module NetSecurity -ErrorAction Ignore
        Import-Module Defender -ErrorAction Ignore
        Import-Module "$env:Windir\System32\WindowsPowerShell\v1.0\Modules\NetSecurity\NetSecurity.psd1" -ErrorAction Ignore
        Import-Module "$env:Windir\System32\WindowsPowerShell\v1.0\Modules\Defender\Defender.psd1" -ErrorAction Ignore
    }
}
Import-Module .\API.psm1

if (-not (Test-Path ".\Config\config.txt")) {
    Write-Host "No config file found. Please start RainbowMiner first."
    exit
}

try {
    $Config = Get-Content ".\Config\config.txt" -Raw | ConvertFrom-Json
} catch {
    Write-Host "Invalid config file. Please correct or reset."
    exit
}

$Config | Add-Member RunMode $(if ($Config.RunMode -eq "`$RunMode") {"Standalone"} else {$Config.RunMode}) -Force
$Config | Add-Member APIport $(if ($Config.APIport -eq "`$APIport" -or -not $Config.APIport) {4000} else {[int]$Config.APIport}) -Force
$Config | Add-Member ServerName $(if ($Config.ServerName -eq "`$ServerName") {""} else {$Config.ServerName}) -Force
$Config | Add-Member ServerPort $(if ($Config.ServerPort -eq "`$ServerPort" -or -not $Config.ServerPort) {4000} else {[int]$Config.ServerPort}) -Force
$Config | Add-Member ServerUser $(if ($Config.ServerUser -eq "`$ServerUser") {""} else {$Config.ServerUser}) -Force
$Config | Add-Member ServerPassword $(if ($Config.ServerPassword -eq "`$ServerPassword") {""} else {$Config.ServerPassword}) -Force
$Config | Add-Member StartPaused $(if ($Config.StartPaused -eq "`$StartPaused") {$false} else {Get-Yes $Config.StartPaused}) -Force

do {
    if (-not (Read-HostBool "Setup $([System.Environment]::MachineName) as CLIENT?" -default ($Config.RunMode -eq "Client"))) {exit}

    Write-Host " "
    Write-Host "Please check your server's credentials first:"
    Write-Host " "

    $Config.RunMode    = "Client"
    $Config.ServerName = Read-HostString -Prompt "Enter the server's name or IP-address " -Default $Config.ServerName -Characters "A-Z0-9\-_\."
    $Config.ServerPort = Read-HostInt -Prompt "Enter the server's API port " -Default $Config.ServerPort -Min 0 -Max 9999
    $Config.ServerUser = Read-HostString -Prompt "If you have auth enabled on your server's API, enter the username " -Default $Config.ServerUser -Characters "A-Z0-9"
    $Config.ServerPassword = Read-HostString -Prompt "If you have auth enabled on your server's API, enter the password " -Default $Config.ServerPassword -Characters ""

    if (Get-Yes $Config.StartPaused) {
        $Config.StartPaused = -not (Read-HostBool -Prompt "RainbowMiner is currently configured to start in pause/no-mining mode. Do you want to disable that?" -Default $true)
    }
    $Config.StartPaused = if (Get-Yes $Config.StartPaused) {"1"} else {"0"}

    Write-Host " "
    Write-Host "Check your data:"
    Write-Host " ServerName = $($Config.ServerName)"
    Write-Host " ServerPort = $($Config.ServerPort)"
    Write-Host " ServerUser = $($Config.ServerUser)"
    Write-Host " ServerPassword = $($Config.ServerPassword)"
    Write-Host " "
    if ($Config.ServerName -and $Config.ServerPort -and (Test-TcpServer -Server $Config.ServerName -Port $Config.ServerPort -Timeout 2)) {
        Write-Host "Server connected successfully!" -ForegroundColor Green
    } else {
        Write-Host "Server not found!" -ForegroundColor Red
    }    
    Write-Host " "
} until (Read-HostBool "Safe the data and initialize Client? (press Ctrl-C to exit)")

Write-Host " "
Write-Host "Initializing Client"
Write-Host " "
if ($IsWindows -and -not (Test-IsElevated)) {
    Write-Host " Please select `"Yes`" for all UACL prompts! " -BackgroundColor Yellow -ForegroundColor Black
    Write-Host " "
}

Initialize-APIServer -Port $Config.APIport

$Config | ConvertTo-Json | Out-File ".\Config\config.txt" -Encoding utf8 

Write-Host "Done!"
