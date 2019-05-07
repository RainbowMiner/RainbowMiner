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
$Config | Add-Member APIauth $(if ($Config.APIauth -eq "`$APIauth") {$false} else {Get-Yes $Config.APIauth}) -Force
$Config | Add-Member APIuser $(if ($Config.APIuser -eq "`$APIuser") {""} else {$Config.APIuser}) -Force
$Config | Add-Member APIpassword $(if ($Config.APIpassword -eq "`$APIPassword") {""} else {$Config.APIpassword}) -Force
$Config | Add-Member StartPaused $(if ($Config.StartPaused -eq "`$StartPaused") {$false} else {Get-Yes $Config.StartPaused}) -Force

do {
    if (-not (Read-HostBool "Setup $([System.Environment]::MachineName) as SERVER?" -default ($Config.RunMode -eq "Server"))) {exit}

    Write-Host " "
    Write-Host "Please check your credentials first:"
    Write-Host " "

    $Config.RunMode    = "Server"
    $Config.APIport = Read-HostInt -Prompt "Enter the API port " -Default $Config.APIport -Min 0 -Max 9999
    $Config.APIauth = Read-HostBool "Enable username/password to protect access to the API?" -Default $Config.APIAuth
    if (Get-Yes $Config.APIauth) {
        $Config.APIuser = Read-HostString -Prompt "Enter an API username (leave empty to disable auth) " -Default $Config.APIuser -Characters "A-Z0-9"
        $Config.APIPassword = Read-HostString -Prompt "Enter an API password " -Default $Config.APIPassword -Characters ""
    }    
    $Config.StartPaused = Read-HostBool "Start the Server machine in pause/no-mining mode automatically? " -Default $Config.StartPaused

    $Config.APIauth = if (Get-Yes $Config.APIauth) {"1"} else {"0"}
    $Config.StartPaused = if (Get-Yes $Config.StartPaused) {"1"} else {"0"}

    Write-Host " "
    Write-Host "Check your data:"
    Write-Host " APIport = $($Config.APIport)"
    Write-Host " APIauth = $(if (Get-Yes $Config.APIauth) {"enabled"} else {"disabled"})"
    if (Get-Yes $Config.APIauth) {
        Write-Host " APIuser = $($Config.APIuser)"
        Write-Host " APIpassword = $($Config.APIpassword)"
    }
    Write-Host " "
    Write-Host "Write down the following:" -ForegroundColor Green
    Write-Host "- Servername: $([System.Environment]::MachineName)" -ForegroundColor Green
    Write-Host "- IP-Address: $(Get-MyIP)" -Foreground Green
    Write-Host "- Serverport: $($Config.APIport)" -Foreground Green
    Write-Host " "
} until (Read-HostBool "Save the data and initialize Server? (press Ctrl-C to exit)" -Default $true)

$Config | Add-Member RunMode "Server" -Force

Write-Host " "
Write-Host "Initializing API-Server"
Write-Host " "
if ($IsWindows -and -not (Test-IsElevated)) {
    Write-Host " Please select `"Yes`" for all UAC prompts! " -BackgroundColor Yellow -ForegroundColor Black
    Write-Host " "
}

Initialize-APIServer -Port $Config.APIport

$Config | ConvertTo-Json | Out-File ".\Config\config.txt" -Encoding utf8 

Write-Host "Done!"
