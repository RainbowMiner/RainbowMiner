using module .\Include.psm1

Initialize-Session

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
$Config | Add-Member StartPaused $(if ($Config.StartPaused -eq "`$StartPaused") {$false} else {Get-Yes $Config.StartPaused}) -Force

if (-not (Read-HostBool "Setup $([System.Environment]::MachineName) as STANDALONE?" -default ($Config.RunMode -ne "Server" -and $Config.RunMode -ne "Client"))) {exit}

if (Get-Yes $Config.StartPaused) {
    $Config.StartPaused = -not (Read-HostBool -Prompt "RainbowMiner is currently configured to start in pause/no-mining mode. Do you want to disable that?" -Default $true)
}
$Config.StartPaused = if (Get-Yes $Config.StartPaused) {"1"} else {"0"}

Write-Host " "
Write-Host "Initializing Standalone"
Write-Host " "
if ($IsWindows -and -not (Test-IsElevated)) {
    Write-Host " Please select `"Yes`" for all UAC prompts! " -BackgroundColor Yellow -ForegroundColor Black
    Write-Host " "
}

Initialize-APIServer -Port $Config.APIport

$Config | ConvertTo-Json | Out-File ".\Config\config.txt" -Encoding utf8 

Write-Host "Done!"
