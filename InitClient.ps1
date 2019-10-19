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

$ConfigSetup  = Get-ChildItemContent ".\Data\ConfigDefault.ps1" | Select-Object -ExpandProperty Content

$Config | Add-Member RunMode $(if ($Config.RunMode -eq "`$RunMode") {"Standalone"} else {$Config.RunMode}) -Force
$Config | Add-Member APIport $(if ($Config.APIport -eq "`$APIport" -or -not $Config.APIport) {4000} else {[int]$Config.APIport}) -Force
$Config | Add-Member ServerName $(if ($Config.ServerName -eq "`$ServerName") {""} else {$Config.ServerName}) -Force
$Config | Add-Member ServerPort $(if ($Config.ServerPort -eq "`$ServerPort" -or -not $Config.ServerPort) {4000} else {[int]$Config.ServerPort}) -Force
$Config | Add-Member ServerUser $(if ($Config.ServerUser -eq "`$ServerUser") {""} else {$Config.ServerUser}) -Force
$Config | Add-Member ServerPassword $(if ($Config.ServerPassword -eq "`$ServerPassword") {""} else {$Config.ServerPassword}) -Force
$Config | Add-Member GroupName $(if ($Config.GroupName -eq "`$GroupName") {""} else {$Config.GroupName}) -Force
$Config | Add-Member StartPaused $(if ($Config.StartPaused -eq "`$StartPaused") {$false} else {Get-Yes $Config.StartPaused}) -Force
$Config | Add-Member EnableServerConfig $(if ($Config.EnableServerConfig -eq "`$EnableServerConfig") {$ConfigSetup.EnableServerConfig} else {$Config.EnableServerConfig}) -Force
$Config | Add-Member ServerConfigName $(if ($Config.ServerConfigName -eq "`$ServerConfigName" -or $Config.ServerConfigName -eq "") {$ConfigSetup.ServerConfigName} else {@(Get-ConfigArray $Config.ServerConfigName)}) -Force
$Config | Add-Member ExcludeServerConfigVars $(if ($Config.ExcludeServerConfigVars -eq "`$ExcludeServerConfigVars" -or $Config.ExcludeServerConfigVars -eq "") {$ConfigSetup.ExcludeServerConfigVars} else {@(Get-ConfigArray $Config.ExcludeServerConfigVars)}) -Force
$Config | Add-Member EnableServerExcludeList $(if ($Config.EnableServerExcludeList -eq "`$EnableServerExcludeList") {$ConfigSetup.EnableServerExcludeList} else {$Config.EnableServerExcludeList}) -Force

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
    $Config.EnableServerConfig = Read-HostBool -Prompt "Enable automatic download of selected server config files? " -Default $Config.EnableServerConfig
    if (Get-Yes $Config.EnableServerConfig) {
        $Config.ServerConfigName = Read-HostArray -Prompt "Enter the config files to be copied to this machine" -Default $Config.ServerConfigName -Characters "A-Z" -Valid @("algorithms","coins","config","miners","mrr","ocprofiles","pools","scheduler")
        $Config.GroupName = Read-HostString -Prompt "Enter a group name, if you want to group clients together for shared config files " -Default $Config.GroupName -Characters "A-Z0-9"
        $Config.EnableServerExcludeList = Read-HostBool -Prompt "Use the server's exclusion variable list?" -Default $Config.EnableServerExcludeList
        if (-not (Get-Yes $Config.EnableServerExcludeList)) {
            $Config.ExcludeServerConfigVars = Read-HostArray -Prompt "Enter all config parameters, that should not be overwritten (if unclear, use default values!)" -Default $Config.ExcludeServerConfigVars -Characters "A-Z0-9:_"
        }
    }

    if (Get-Yes $Config.StartPaused) {
        $Config.StartPaused = -not (Read-HostBool -Prompt "RainbowMiner is currently configured to start in pause/no-mining mode. Do you want to disable that?" -Default $true)
    }

    $Config.StartPaused = if (Get-Yes $Config.StartPaused) {"1"} else {"0"}
    $Config.EnableServerConfig = if (Get-Yes $Config.EnableServerConfig) {"1"} else {"0"}
    $Config.EnableServerExcludeList = if (Get-Yes $Config.EnableServerExcludeList) {"1"} else {"0"}
    $Config.ServerConfigName = $Config.ServerConfigName -join ','
    $Config.ExcludeServerConfigVars = $Config.ExcludeServerConfigVars -join ','

    Write-Host " "
    Write-Host "Check your data:"
    Write-Host " ServerName = $($Config.ServerName)"
    Write-Host " ServerPort = $($Config.ServerPort)"
    Write-Host " ServerUser = $($Config.ServerUser)"
    Write-Host " ServerPassword = $($Config.ServerPassword)"
    if (Get-Yes $Config.EnableServerConfig) {
        Write-Host " ServerConfigName = $($Config.ServerConfigName) (automatic download from server enabled)"
        Write-Host " GroupName = $($Config.GroupName)"
        Write-Host " EnableServerExcludeList = $($Config.EnableServerExcludeList) $(if (Get-Yes $Config.EnableServerExcludeList) {"(server's list will be used)"} else {"(the following list will be used)"})"
        if (-not (Get-Yes $Config.EnableServerExcludeList)) {
            Write-Host " ExcludeServerConfigVars = $($Config.ExcludeServerConfigVars)"
        }
    }
    Write-Host " "
    if ($Config.ServerName -and $Config.ServerPort -and (Test-TcpServer -Server $Config.ServerName -Port $Config.ServerPort -Timeout 2)) {
        Write-Host "Server connected successfully!" -ForegroundColor Green
    } else {
        Write-Host "Server not found!" -ForegroundColor Red
    }    
    Write-Host " "
} until (Read-HostBool "Save the data and initialize Client? (press Ctrl-C to exit)" -Default $true)

Write-Host " "
Write-Host "Initializing Client"
Write-Host " "
if ($IsWindows -and -not (Test-IsElevated)) {
    Write-Host " Please select `"Yes`" for all UAC prompts! " -BackgroundColor Yellow -ForegroundColor Black
    Write-Host " "
}

Initialize-APIServer -Port $Config.APIport

$Config | ConvertTo-Json | Out-File ".\Config\config.txt" -Encoding utf8 

Write-Host "Done!"
