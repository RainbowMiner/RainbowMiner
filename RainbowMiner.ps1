using module .\Include.psm1

[CmdletBinding()]
param(
    [Parameter(Mandatory = $false)]
    [Alias("BTC")]
    [String]$Wallet, 
    [Parameter(Mandatory = $false)]
    [Alias("User")]
    [String]$UserName, 
    [Parameter(Mandatory = $false)]
    [Alias("Worker")]
    [String]$WorkerName = "rainbowminer", 
    [Parameter(Mandatory = $false)]
    [Int]$API_ID = 0, 
    [Parameter(Mandatory = $false)]
    [String]$API_Key = "", 
    [Parameter(Mandatory = $false)]
    [Int]$Interval = 60, #seconds before reading hash rate from miners
    [Parameter(Mandatory = $false)]
    [Alias("Location")]
    [String]$Region = "europe", #europe/us/asia
    [Parameter(Mandatory = $false)]
    [Switch]$SSL = $false, 
    [Parameter(Mandatory = $false)]
    [Alias("Device", "Type")]
    [Array]$DeviceName = @(), #i.e. CPU, GPU, GPU#02, AMD, NVIDIA, AMD#02, OpenCL#03#02 etc.
    [Parameter(Mandatory = $false)]
    [Array]$Algorithm = @(), #i.e. Ethash,Equihash,CryptoNightV7 etc.
    [Parameter(Mandatory = $false)]
    [Alias("Miner")]
    [Array]$MinerName = @(), 
    [Parameter(Mandatory = $false)]
    [Alias("Pool")]
    [Array]$PoolName = @(), 
    [Parameter(Mandatory = $false)]
    [Array]$ExcludeAlgorithm = @(), #i.e. Ethash,Equihash,CryptoNight etc.
    [Parameter(Mandatory = $false)]
    [Alias("ExcludeMiner")]
    [Array]$ExcludeMinerName = @(), 
    [Parameter(Mandatory = $false)]
    [Alias("ExcludePool")]
    [Array]$ExcludePoolName = @(), 
    [Parameter(Mandatory = $false)]
    [Array]$Currency = ("BTC", "USD"), #i.e. GBP,EUR,ZEC,ETH etc.
    [Parameter(Mandatory = $false)]
    [Int]$Donate = 24, #Minutes per Day
    [Parameter(Mandatory = $false)]
    [String]$Proxy = "", #i.e http://192.0.0.1:8080
    [Parameter(Mandatory = $false)]
    [Int]$Delay = 0, #seconds before opening each miner
    [Parameter(Mandatory = $false)]
    [Switch]$Watchdog = $false,
    [Parameter(Mandatory = $false)]
    [Alias("Uri", "Url")]
    [String]$MinerStatusUrl = "", #i.e https://multipoolminer.io/monitor/miner.php
    [Parameter(Mandatory = $false)]
    [String]$MinerStatusKey = $Wallet, #For backwards compatibility, set the MinerStatusKey to $Wallet if it's not specified
    [Parameter(Mandatory = $false)]
    [Double]$SwitchingPrevention = 2, #zero does not prevent miners switching
    [Parameter(Mandatory = $false)]
    [Switch]$DisableAutoUpdate = $false,
    [Parameter(Mandatory = $false)]
    [Switch]$ShowMinerWindow = $false, #if true all miner windows will be visible (they can steal focus)
    [Parameter(Mandatory = $false)]
    [Switch]$FastestMinerOnly = $false, #Use only use fastest miner per algo and device index. E.g. if there are 2 miners available to mine the same algo, only the faster of the two will ever be used, the slower ones will also be hidden in the summary screen
    [Parameter(Mandatory = $false)]
    [Switch]$IgnoreFees = $false,
    [Parameter(Mandatory = $false)]
    [Switch]$ExcludeMinersWithFee = $false,
    [Parameter(Mandatory = $false)]
    [Switch]$ShowPoolBalances = $false,
    [Parameter(Mandatory = $false)]
    [Switch]$DisableDualMining = $false,
    [Parameter(Mandatory = $false)]
    [Switch]$RemoteAPI = $false,
    [Parameter(Mandatory = $false)]
    [String]$ConfigFile = "Config\config.txt", # Path to config file
    [Parameter(Mandatory = $false)]
    [Switch]$RebootOnGPUFailure = $false, # if set to $true, and a GPU fails, the mining rig will be restarted
    [Parameter(Mandatory = $false)]
    [String]$MiningMode = "combo", # set to "legacy","device","combo"
    [Parameter(Mandatory = $false)]
    [String]$MSIApath = "c:\Program Files (x86)\MSI Afterburner\MSIAfterburner.exe", # installation path of MSI Afterburner
    [Parameter(Mandatory = $false)]
    [Int]$MSIAprofile = 2, # default MSI Afterburner profile to be set
    [Parameter(Mandatory = $false)]
    [String]$UIstyle = "full" # ui style: full=show all, lite=show only active miner
)

Clear-Host

$Version = "3.7.5.2"
$Strikes = 3
$SyncWindow = 5 #minutes

Write-Host "__________        .__      ___.                   _____  .__                     " -ForegroundColor Red
Write-Host "\______   \_____  |__| ____\_ |__   ______  _  __/     \ |__| ____   ___________ " -ForegroundColor DarkYellow
Write-Host " |       _/\__  \ |  |/    \| __ \ /  _ \ \/ \/ /  \ /  \|  |/    \_/ __ \_  __ \" -ForegroundColor Yellow
Write-Host " |    |   \ / __ \|  |   |  \ \_\ (  <_> )     /    Y    \  |   |  \  ___/|  | \/" -ForegroundColor Green
Write-Host " |____|_  /(____  /__|___|  /___  /\____/ \/\_/\____|__  /__|___|  /\___  >__|   " -ForegroundColor Blue
Write-Host "        \/      \/        \/    \/                     \/        \/     \/       " -ForegroundColor DarkMagenta
Write-Host " "
Write-Host "Starting up v$($Version)! Please wait.."
Write-Host " "

Set-Location (Split-Path $MyInvocation.MyCommand.Path)

Import-Module NetSecurity -ErrorAction Ignore
Import-Module Defender -ErrorAction Ignore
Import-Module "$env:Windir\System32\WindowsPowerShell\v1.0\Modules\NetSecurity\NetSecurity.psd1" -ErrorAction Ignore
Import-Module "$env:Windir\System32\WindowsPowerShell\v1.0\Modules\Defender\Defender.psd1" -ErrorAction Ignore

Test-TimeSync

$Timer = (Get-Date).ToUniversalTime()
$StatEnd = $Timer
$DecayStart = $Timer
$DecayPeriod = 60 #seconds
$DecayBase = 1 - 0.1 #decimal percentage

[System.Collections.ArrayList]$WatchdogTimers = @()
[System.Collections.ArrayList]$ActiveMiners = @()
[hashtable]$Rates = @{BTC = [Double]1}

$LastDonated = 0

$SkipSwitchingPrevention = $false
$StartDownloader = $false
$PauseMiners = $false
$RestartMiners = $false
$Readers = [PSCustomObject]@{}
$ShowTimer = $false
$LastBalances = $Timer
$MSIAcurrentprofile = -1
$RunSetup = $false
$IsInitialSetup = $false
$MinersUriHash = $null

[hashtable]$Updatetracker = @{
    Config = [hashtable]@{ConfigFile=0;PoolsConfigFile=0;MinersConfigFile=0}
    APIs = [hashtable]@{}
}

if ($MyInvocation.MyCommand.Parameters -eq $null) {
    $MyCommandParameters = @("Wallet","UserName","WorkerName","API_ID","API_Key","Interval","Region","SSL","DeviceName","Algorithm","MinerName","ExcludeAlgorithm","ExcludeMinerName","ExcludePoolName","Currency","Donate","Proxy","Delay","Watchdog","MinerStatusUrl","MinerStatusKey","SwitchingPrevention","DisableAutoUpdate","ShowMinerWindow","FastestMinerOnly","IgnoreFees","ExcludeMinersWithFee","ShowPoolBalances","DisableDualMining","RemoteAPI","ConfigFile","RebootOnGPUFailure","MiningMode","MSIApath","MSIAprofile","UIstyle")
} else {
    $MyCommandParameters = $MyInvocation.MyCommand.Parameters.Keys
}

#Cleanup the log
if (Test-Path ".\Logs"){
    Get-ChildItem -Path ".\Logs" -Filter "*" | Where-Object {$_.LastWriteTime -lt (Get-Date).AddDays(-5)} | Remove-Item -ErrorAction Ignore
}

#Start the log
Start-Transcript ".\Logs\RainbowMiner_$(Get-Date -Format "yyyy-MM-dd_HH-mm-ss").txt"

#Start the async loader
Start-AsyncLoader

Write-Log "Starting RainbowMiner v$Version"

#Set process priority to BelowNormal to avoid hash rate drops on systems with weak CPUs
(Get-Process -Id $PID).PriorityClass = "BelowNormal"

try {
    $ConfigPath = [IO.Path]::GetDirectoryName($ConfigFile)
    if (-not $ConfigPath) {$ConfigPath = ".\Config"; $ConfigFile = "$($ConfigPath)\$($ConfigFile)"}
    if (-not (Test-Path $ConfigPath)) {New-Item $ConfigPath -ItemType "directory" -Force | Out-Null}
    if (-not [IO.Path]::GetExtension($ConfigFile)) {$ConfigFile = "$($ConfigFile).txt"}   
    if (-not (Test-Path $ConfigFile)) {
        $Parameters = @{VersionCompatibility=$Version}
        $MyCommandParameters | Where-Object {$_ -ne "ConfigFile" -and (Get-Variable $_ -ErrorAction SilentlyContinue)} | ForEach-Object {$Parameters | Add-Member $_ "`$$($_)" -ErrorAction SilentlyContinue}
        $Parameters | ConvertTo-Json | Set-Content $ConfigFile -Encoding utf8
    }
    $ConfigFile = Get-Item $ConfigFile | Foreach-Object {
        $ConfigFile_Path = $_ | Select-Object -ExpandProperty DirectoryName
        $ConfigFile_Name = $_ | Select-Object -ExpandProperty Name
        $PoolsConfigFile = @($ConfigFile_Path,"\pools.",$ConfigFile_Name) -join ''
        $MinersConfigFile = @($ConfigFile_Path,"\miners.",$ConfigFile_Name) -join ''
        $DevicesConfigFile = @($ConfigFile_Path,"\devices.",$ConfigFile_Name) -join ''
        
        # Create pools.config.txt if it is missing
        Set-PoolsConfigDefault -PathToFile $PoolsConfigFile -Force
        $PoolsConfigFile = $PoolsConfigFile | Resolve-Path -Relative

        # Create miners.config.txt if it is missing
        Set-MinersConfigDefault -PathToFile $MinersConfigFile -Force
        $MinersConfigFile = $MinersConfigFile | Resolve-Path -Relative

        # Create devices.config.txt if it is missing
        Set-DevicesConfigDefault -PathToFile $DevicesConfigFile -Force
        $DevicesConfigFile = $DevicesConfigFile | Resolve-Path -Relative

        $_ | Resolve-Path -Relative
    }

    #cleanup legacy data
    if (-not (Test-Path ".\Data")) {New-Item -Name "Data" -ItemType "directory" -Force | Out-Null}
    @("Algorithms","Devices","Regions") | Where-Object {-not (Test-Path "Data\$($_.ToLower()).json")} | Foreach-Object {
        if (Test-Path "$($_).txt") {Move-Item "$($_).txt" "Data\$($_.ToLower()).json" -Force | Out-Null}
        else {
            throw "Data\$($_.ToLower()).json is missing."
        }
    }
}
catch {
    Write-Log -Level Error "$($_) Cannot run RainbowMiner. "
    Exit
}

if (Get-Command "Unblock-File" -ErrorAction SilentlyContinue) {Get-ChildItem . -Recurse | Unblock-File}
if ((Get-Command "Get-MpPreference" -ErrorAction SilentlyContinue) -and (Get-MpComputerStatus -ErrorAction SilentlyContinue) -and (Get-MpPreference).ExclusionPath -notcontains (Convert-Path .)) {
    Start-Process (@{desktop = "powershell"; core = "pwsh"}.$PSEdition) "-Command Import-Module '$env:Windir\System32\WindowsPowerShell\v1.0\Modules\Defender\Defender.psd1'; Add-MpPreference -ExclusionPath '$(Convert-Path .)'" -Verb runAs
}

#[console]::TreatControlCAsInput = $true

Confirm-Version $Version

while ($true) {
    #Load the config
    $ConfigBackup = if ($Config -is [object]){$Config.PSObject.Copy()}else{$null}
    $ConfigCheckFields = $true
    
    [string[]]$AvailPools = Get-ChildItem ".\Pools\*.ps1" -File | Select-Object -ExpandProperty BaseName | Sort-Object
    [string[]]$AvailMiners = Get-ChildItem ".\Miners\*.ps1" -File | Select-Object -ExpandProperty BaseName | Sort-Object

    if (Test-Path $ConfigFile) {
        if (-not $Config -or $RunSetup -or (Get-ChildItem $ConfigFile).LastWriteTime.ToUniversalTime() -gt $UpdateTracker["Config"]["ConfigFile"]) {        

            do {
                $UpdateTracker["Config"]["ConfigFile"] = (Get-ChildItem $ConfigFile).LastWriteTime.ToUniversalTime()
                $Parameters = @{}
                $MyCommandParameters | Where-Object {$_ -ne "ConfigFile"} | ForEach-Object {
                    $Parameters.Add($_ , (Get-Variable $_ -ValueOnly -ErrorAction SilentlyContinue))
                }
                $Config = Get-ChildItemContent $ConfigFile -Force -Parameters $Parameters | Select-Object -ExpandProperty Content
                $Config | Add-Member Pools ([PSCustomObject]@{}) -Force
                $Config | Add-Member Miners ([PSCustomObject]@{}) -Force

                if (-not $Config.Wallet -or -not $Config.WorkerName -or -not $Config.PoolName -or -not $Config.Algorithm) {
                    $IsInitialSetup = $true
                    $RunSetup = $true
                }

                $ReReadConfig = $false

                if ($RunSetup) {

                    do {
                        $ConfigActual = Get-Content $ConfigFile | ConvertFrom-Json
                        $MinersActual = Get-Content $MinersConfigFile | ConvertFrom-Json
                        $PoolsActual = Get-Content $PoolsConfigFile | ConvertFrom-Json
                        $SetupDevices = Get-Device "nvidia","amd","cpu"

                        Write-Host " "
                        Write-Host "*** RainbowMiner Configuration ***" -ForegroundColor Green
                        Write-Host " "

                        if ($IsInitialSetup) {
                            $SetupType = "G" 
                            $ConfigSetup = Get-ChildItemContent ".\Data\ConfigDefault.ps1" | Select-Object -ExpandProperty Content
                            $ConfigSetup.PSObject.Properties | Where-Object Membertype -eq NoteProperty | Select-Object Name,Value | Foreach-Object {
                                $ConfigSetup_Name = $_.Name
                                if ($_.Value -is [bool] -or -not $Config.$ConfigSetup_Name) {$Config | Add-Member $ConfigSetup_Name $($_.Value) -Force}
                            }

                        } else {
                            Write-Host "Please choose, what to configure:" -ForegroundColor Yellow
                            $SetupType = Read-HostString -Prompt "[G]lobal, [M]iner, [P]ools, E[x]it configuration and start mining" -Default "X"  -Mandatory -Characters "GMPX"
                            Write-Host " "
                        }

                        if ($SetupType -eq "X") {
                            $RunSetup = $false
                        }
                        elseif ($SetupType -eq "G") {                            
                            
                            Write-Host "*** Global Configuration ***" -ForegroundColor Green
                            Write-Host " "
                            Write-Host "Hints:" -ForegroundColor Yellow
                            Write-Host "- your current configuration defines the defaults. Press Return to accept the them." -ForegroundColor Yellow
                            Write-Host "- fields marked with * are mandatory" -ForegroundColor Yellow
                            Write-Host "- use comma `",`" to separate list entries" -ForegroundColor Yellow
                            Write-Host "- add new entries to a list, by adding a `"+`" in front of your input" -ForegroundColor Yellow
                            Write-Host "- remove entries from a list, by adding a `"-`" in front of your input" -ForegroundColor Yellow
                            Write-Host "- enter `"list`" or `"help`" to show a list of all valid entries" -ForegroundColor Yellow
                            Write-Host "- enter `"back`" or `"<`" to repeat the last input" -ForegroundColor Yellow
                            Write-Host "- enter `"delete`" to clear a non-mandatory entry" -ForegroundColor Yellow
                            Write-Host "- enter `"exit`" or `"cancel`" to abort without any changes to the configuration" -ForegroundColor Yellow
                            Write-Host " "

                            $GlobalSetupDone = $false
                            $GlobalSetupStep = $GlobalSetupStepBack = 1
                            do {
                                try {
                                   Switch ($GlobalSetupStep) {
                                        1 {                       
                                            # Start setup procedure
                                            Write-Host ' '
                                            Write-Host '(1) Basic Setup' -ForegroundColor Green
                                            Write-Host ' '
                                                                             
                                            if ($IsInitialSetup) {
                                                Write-Host " "
                                                Write-Host "At first, please lookup your BTC wallet address, you want to mine to. It is easy: copy it into your clipboard and then press the right mouse key in this window to paste" -ForegroundColor Cyan
                                                Write-Host " "
                                            }
                                            $Config.Wallet = Read-HostString -Prompt "Enter your BTC wallet address" -Default $Config.Wallet -Length 34 -Mandatory -Characters "A-Z0-9" | Foreach-Object {if (@("cancel","exit","back","<") -icontains $_) {throw $_};$_}
                                        }

                                        2 {
                                            if ($IsInitialSetup) {
                                                Write-Host " "
                                                Write-Host "If you plan to mine using the Nicehash-pool, I recommend you register an account with them, to get a NiceHash wallet address (please read the Pools section of our readme!). I would not mine to your standard wallet ($($Config.Wallet)), since Nicehash has a minimum payout amount of 0.1BTC (compared to 0.001BTC, when using their wallet). " -ForegroundColor Cyan
                                                Write-Host "If you do not want to use Nicehash as a pool, leave this empty (or enter `"clear`" to make it empty) and press return " -ForegroundColor Cyan
                                                Write-Host " "
                                            }

                                            if ($PoolsActual | Get-Member Nicehash -MemberType NoteProperty) {
                                                $NicehashWallet = $PoolsActual.Nicehash.BTC
                                                $NicehashWorkerName = $PoolsActual.Nicehash.Worker
                                            } else {
                                                $NicehashWallet = '$Wallet'
                                                $NicehashWorkerName = '$WorkerName'
                                            }
                                            if ($NicehashWallet -eq '$Wallet'){$NicehashWallet=$Config.Wallet}
                                            $NicehashWallet = Read-HostString -Prompt "Enter your NiceHash-BTC wallet address" -Default $NicehashWallet -Length 34 -Characters "A-Z0-9" | Foreach-Object {if (@("cancel","exit","back","<") -icontains $_) {throw $_};$_}

                                            if ($NiceHashWallet -eq '$Wallet' -or $NiceHashWallet -eq $Config.Wallet) {
                                                if (Read-HostBool "You have entered your default wallet as Nicehash wallet. NiceHash will have a minimum payout of 0.1BTC. Do you want to disable NiceHash mining for now?" -Default $true) {
                                                    $NiceHashWallet = ''
                                                }
                                            }

                                            if (-not $NicehashWallet) {
                                                $Config.PoolName = $Config.PoolName | Where-Object {$_ -ne "Nicehash"}
                                                $NicehashWallet = '$Wallet'
                                            } else {
                                                $Config.PoolName = @($Config.PoolName | Select-Object) + @("Nicehash") | Select-Object -Unique
                                            }
                                        }

                                        3 {
                                            if ($IsInitialSetup) {
                                                Write-Host " "
                                                Write-Host "Every pool (except the MiningPoolHub) wants the miner to send a worker's name. You can change the name later. Please enter only letters and numbers. " -ForegroundColor Cyan
                                                Write-Host " "
                                            }
                                            $Config.WorkerName = Read-HostString -Prompt "Enter your worker name" -Default $Config.WorkerName -Mandatory -Characters "A-Z0-9" | Foreach-Object {if (@("cancel","exit","back","<") -icontains $_) {throw $_};$_}
                                        }

                                        4 {
                                            if ($IsInitialSetup) {
                                                Write-Host " "
                                                Write-Host "If you plan to use MiningPoolHub for mining, you will have to register an account with them and choose a username. Enter this username now, or leave empty to disable MiningPoolHub (can be activated, later) " -ForegroundColor Cyan
                                                Write-Host " "
                                            }
                                            $Config.UserName = Read-HostString -Prompt "Enter your Miningpoolhub user name" -Default $Config.UserName -Characters "A-Z0-9" | Foreach-Object {if (@("cancel","exit","back","<") -icontains $_) {throw $_};$_}
                                            if (-not $Config.UserName) {
                                                $Config.PoolName = $Config.PoolName | Where-Object {$_ -notlike "MiningPoolHub*"}
                                            } else {
                                                $Config.PoolName = @($Config.PoolName | Select-Object) + @("MiningPoolHub") | Select-Object -Unique
                                            }
                                        }

                                        5 {
                                            if ($IsInitialSetup) {
                                                Write-Host " "
                                                Write-Host "Choose the region, you live in, from this list (remember: you can always simply accept the default by pressing return): " -ForegroundColor Cyan
                                                @(Get-Regions) | Foreach-Object {Write-Host " $($_)" -ForegroundColor Cyan}
                                                Write-Host " "
                                            }
                                            $Config.Region = Read-HostString -Prompt "Enter your region" -Default $Config.Region -Mandatory -Characters "A-Z" -Valid @(Get-Regions) | Foreach-Object {if (@("cancel","exit","back","<") -icontains $_) {throw $_};$_}
                                        }

                                        6 {
                                            $Config.Currency = Read-HostArray -Prompt "Enter all currencies to be displayed (e.g. EUR,USD,BTC)" -Default $Config.Currency -Mandatory -Characters "A-Z" | Foreach-Object {if (@("cancel","exit","back","<") -icontains $_) {throw $_};$_}
                                        }

                                        7 {
                                            Write-Host ' '
                                            Write-Host '(2) Select your pools, miners and algorithm (be sure you read the notes in the README.md)' -ForegroundColor Green
                                            Write-Host ' '

                                            if ($IsInitialSetup) {
                                                Write-Host " "
                                                Write-Host "Choose your mining pools from this list or accept the default for a head start (read the Pools section of our readme for more details): " -ForegroundColor Cyan
                                                $AvailPools | Foreach-Object {Write-Host " $($_)" -ForegroundColor Cyan}
                                                Write-Host " "
                                            }
                                            $Config.PoolName = Read-HostArray -Prompt "Enter the pools you want to mine" -Default $Config.PoolName -Mandatory -Characters "A-Z0-9" -Valid $AvailPools | Foreach-Object {if (@("cancel","exit","back","<") -icontains $_) {throw $_};$_}
                                            $Config.ExcludePoolName = $AvailPools | Where-Object {$Config.PoolName -inotcontains $_}
                                            throw "Goto 9"
                                        }
                                        8 {
                                            $Config.ExcludePoolName = Read-HostArray -Prompt "Enter the pools you do want to exclude from mining" -Default $Config.ExcludePoolName -Characters "A-Z0-9" -Valid $AvailPools | Foreach-Object {if (@("cancel","exit","back","<") -icontains $_) {throw $_};$_}
                                        }
                                        9 {
                                            if ($IsInitialSetup) {
                                                Write-Host " "
                                                Write-Host "You are almost done :) Our defaults for miners and algorithms give you a good start. If you want, you can skip the settings for now " -ForegroundColor Cyan
                                                Write-Host " "

                                                if (Read-HostBool -Prompt "Do you want to skip the miner and algorithm setup?" -Default $true) {throw "Goto 15"}
                                            }
                                            $Config.MinerName = Read-HostArray -Prompt "Enter the miners your want to use (leave empty for all)" -Default $Config.MinerName -Characters "A-Z0-9.-_" -Valid $AvailMiners | Foreach-Object {if (@("cancel","exit","back","<") -icontains $_) {throw $_};$_}
                                        }
                                        10 {
                                            $Config.ExcludeMinerName = Read-HostArray -Prompt "Enter the miners you do want to exclude" -Default $Config.ExcludeMinerName -Characters "A-Z0-9\.-_" -Valid $AvailMiners | Foreach-Object {if (@("cancel","exit","back","<") -icontains $_) {throw $_};$_}
                                        }
                                        11 {
                                            $Config.Algorithm = Read-HostArray -Prompt "Enter the algorithm you want to mine (leave empty for all)" -Default $Config.Algorithm -Characters "A-Z0-9" -Valid (Get-Algorithms) | Foreach-Object {if (@("cancel","exit","back","<") -icontains $_) {throw $_};$_}
                                        }
                                        12 {
                                            $Config.ExcludeAlgorithm = Read-HostArray -Prompt "Enter the algorithm you do want to exclude (leave empty for none)" -Default $Config.ExcludeAlgorithm -Characters "A-Z0-9" -Valid (Get-Algorithms) | Foreach-Object {if (@("cancel","exit","back","<") -icontains $_) {throw $_};$_}
                                        }
                                        13 {
                                            $Config.DisableDualMining = Read-HostBool -Prompt "Disable all dual mining algorithm" -Default $Config.DisableDualMining | Foreach-Object {if (@("cancel","exit","back","<") -icontains $_) {throw $_};$_}
                                        }
                                        14 {
                                            $Config.ExcludeMinersWithFee = Read-HostBool -Prompt "Exclude all miners with developer fee" -Default $Config.ExcludeMinersWithFee | Foreach-Object {if (@("cancel","exit","back","<") -icontains $_) {throw $_};$_}
                                        }
                                        15 {
                                            Write-Host ' '
                                            Write-Host '(3) Select the devices to mine on and miningmode' -ForegroundColor Green
                                            Write-Host ' '

                                            $AvailDeviceName = @()                                
                                            if ((Select-Device $SetupDevices "nvidia" | Measure-Object).Count -gt 0) {$AvailDeviceName += "nvidia"}
                                            if ((Select-Device $SetupDevices "amd" | Measure-Object).Count -gt 0) {$AvailDeviceName += "amd"}               

                                            $WizardDeviceNameSet = $false                                                                
                                            if ($IsInitialSetup -and -not $Config.DeviceName) {
                                                $Config.DeviceName = @()
                                                if ($AvailDeviceName.Count -gt 0) { #GPU mining possible
                                                    if ($AvailDeviceName.Count -gt 1) {
                                                        if (Read-HostBool -Prompt "Mine on all available GPU ($(($AvailDeviceName -join '&').ToUpper()), choose no to select devices)" -Default $true | Foreach-Object {if (@("cancel","exit","back","<") -icontains $_) {throw $_};$_}) {
                                                            $Config.DeviceName += $AvailDeviceName                                            
                                                        }
                                                    }
                                                    if ($Config.DeviceName.Count -eq 0) {
                                                        $AvailDeviceName | Foreach-Object {
                                                            if (Read-HostBool -Prompt "Mine on all $($_.ToUpper()) GPU (choose no to select devices)" -Default $true | Foreach-Object {if (@("cancel","exit","back","<") -icontains $_) {throw $_};$_}) {$Config.DeviceName += @($_)}
                                                        }
                                                    }
                                                    $WizardDeviceNameSet = $Config.DeviceName.Count -gt 0
                                                }
                                   
                                                if (Read-HostBool -Prompt "Mine on your CPU" -Default $false | Foreach-Object {if (@("cancel","exit","back","<") -icontains $_) {throw $_};$_}) {
                                                    $Config.DeviceName += @("cpu")
                                                }                                                                        
                                            }                                                             

                                            if (-not $IsInitialSetup) {
                                                $Config.MiningMode = Read-HostString "Select mining mode (legacy/device/combo)" -Default $Config.MiningMode -Mandatory -Characters "A-Z" | Foreach-Object {if (@("cancel","exit","back","<") -icontains $_) {throw $_};$_}
                                                if ($Config.MiningMode -like "l*") {$Config.MiningMode="legacy"}
                                                elseif ($Config.MiningMode -like "c*") {$Config.MiningMode="combo"}
                                                else {$Config.MiningMode="device"}
                                            }
                        
                                            if ($Config.MiningMode -ne "legacy") {$SetupDevices | Select-Object -ExpandProperty Model -Unique | Foreach-Object {$AvailDeviceName += $_}}else{$AvailDeviceName+="cpu"}

                                            if (-not $WizardDeviceNameSet) {
                                                $Config.DeviceName = Read-HostArray -Prompt "Enter the devices you want to use for mining (leave empty for all)" -Default $Config.DeviceName -Characters "A-Z0-9#" -Valid $AvailDeviceName | Foreach-Object {if (@("cancel","exit","back","<") -icontains $_) {throw $_};$_}
                                            }

                                            if ($IsInitialSetup) {throw "Goto 999"}
                                        }

                                        16 {
                                            Write-Host ' '
                                            Write-Host '(4) Select desired output' -ForegroundColor Green
                                            Write-Host ' '

                                            $Config.UIstyle = Read-HostString -Prompt "Select style of user interface (full/lite)" -Default $Config.UIstyle -Mandatory -Characters "A-Z" | Foreach-Object {if (@("cancel","exit","back","<") -icontains $_) {throw $_};$_}
                                            if ($Config.UIstyle -like "l*"){$Config.UIstyle="lite"}else{$Config.UIstyle="full"}   
                                        }
                                        17 {
                                            $Config.FastestMinerOnly = Read-HostBool -Prompt "Show fastest miner only" -Default $Config.FastestMinerOnly | Foreach-Object {if (@("cancel","exit","back","<") -icontains $_) {throw $_};$_}
                                        }
                                        18 {
                                            $Config.ShowPoolBalances = Read-HostBool -Prompt "Show all available pool balances" -Default $Config.ShowPoolBalances | Foreach-Object {if (@("cancel","exit","back","<") -icontains $_) {throw $_};$_}
                                        }
                                        19 {
                                            $Config.ShowMinerWindow = Read-HostBool -Prompt "Show miner in own windows (will steal your focus, not recommended)" -Default $Config.ShowMinerWindow | Foreach-Object {if (@("cancel","exit","back","<") -icontains $_) {throw $_};$_}
                                        }
                                        20 {
                                            Write-Host ' '
                                            Write-Host '(5) Setup other / technical' -ForegroundColor Green
                                            Write-Host ' '

                                            $Config.IgnoreFees = Read-HostBool -Prompt "Ignore Pool/Miner developer fees" -Default $Config.IgnoreFees | Foreach-Object {if (@("cancel","exit","back","<") -icontains $_) {throw $_};$_}
                                        }
                                        21 {
                                            $Config.Watchdog = Read-HostBool -Prompt "Enable watchdog" -Default $Config.Watchdog | Foreach-Object {if (@("cancel","exit","back","<") -icontains $_) {throw $_};$_}
                                        }
                                        22 {
                                            do {
                                                $Config.MSIAprofile = Read-HostInt -Prompt "Enter default MSI Afterburner profile (0 to disable all MSI action)" -Default $Config.MSIAprofile -Mandatory -Min 0 -Max 5 | Foreach-Object {if (@("cancel","exit","back","<") -icontains $_) {throw $_};$_}                             
                                                if ($Config.MSIAprofile -gt 0) {
                                                    $Config.MSIApath = Read-HostString -Prompt "Enter path to MSI Afterburner" -Default $Config.MSIApath -Characters '' | Foreach-Object {if (@("cancel","exit","back","<") -icontains $_) {throw $_};$_}
                                                    if (-not (Test-Path $Config.MSIApath)) {Write-Host "MSI Afterburner not found at given path. Please try again or disable."}
                                                }
                                            } until ($Config.MSIAprofile -eq 0 -or (Test-Path $Config.MSIApath));
                                        }
                                        23 {
                                            $Config.Proxy = Read-HostString -Prompt "Enter proxy address, if used" -Default $Config.Proxy -Characters "A-Z0-9:/\.%-_" | Foreach-Object {if (@("cancel","exit","back","<") -icontains $_) {throw $_};$_}
                                        }
                                        24 {
                                            $Config.Interval = Read-HostInt -Prompt "Enter the script's loop interval in seconds" -Default $Config.Interval -Mandatory -Min 30 | Foreach-Object {if (@("cancel","exit","back","<") -icontains $_) {throw $_};$_}
                                        }
                                        25 {
                                            $Config.Donate = [int]($(Read-HostDouble -Prompt "Enter the developer donation fee in %" -Default ([Math]::Round($Config.Donate/0.1440)/100) -Mandatory -Min 0.69 -Max 100)*14.40) | Foreach-Object {if (@("cancel","exit","back","<") -icontains $_) {throw $_};$_}
                                        }
                                        default {
                                            $ConfigActual | Add-Member Wallet $Config.Wallet -Force
                                            $ConfigActual | Add-Member WorkerName $Config.WorkerName -Force
                                            $ConfigActual | Add-Member UserName $Config.UserName -Force
                                            $ConfigActual | Add-Member Proxy $Config.Proxy -Force
                                            $ConfigActual | Add-Member Regin $Config.Region -Force
                                            $ConfigActual | Add-Member Currency $($Config.Currency -join ",") -Force
                                            $ConfigActual | Add-Member PoolName $($Config.PoolName -join ",") -Force
                                            $ConfigActual | Add-Member ExcludePoolName $($Config.ExcludePoolName -join ",") -Force
                                            $ConfigActual | Add-Member MinerName $($Config.MinerName -join ",") -Force
                                            $ConfigActual | Add-Member ExcludeMinerName $($Config.ExcludeMinerName -join ",") -Force
                                            $ConfigActual | Add-Member Algorithm $($Config.Algorithm -join ",") -Force
                                            $ConfigActual | Add-Member ExcludeAlgorithm $($Config.ExcludeAlgorithm -join ",") -Force
                                            $ConfigActual | Add-Member MiningMode $Config.MiningMode -Force
                                            $ConfigActual | Add-Member ShowPoolBalances $(if ($Config.ShowPoolBalances){"1"}else{"0"}) -Force
                                            $ConfigActual | Add-Member ShowMinerWindow $(if ($Config.ShowMinerWindow){"1"}else{"0"}) -Force
                                            $ConfigActual | Add-Member FastestMinerOnly $(if ($Config.FastestMinerOnly){"1"}else{"0"}) -Force
                                            $ConfigActual | Add-Member UIstyle $Config.UIstyle -Force
                                            $ConfigActual | Add-Member DeviceName $($Config.DeviceName -join ",") -Force                      
                                            $ConfigActual | Add-Member Interval $Config.Interval -Force
                                            $ConfigActual | Add-Member Donate $Config.Donate -Force
                                            $ConfigActual | Add-Member Watchdog $(if ($Config.Watchdog){"1"}else{"0"}) -Force
                                            $ConfigActual | Add-Member IgnoreFees $(if ($Config.IgnoreFees){"1"}else{"0"}) -Force
                                            $ConfigActual | Add-Member DisableDualMining $(if ($Config.DisableDualMining){"1"}else{"0"}) -Force
                                            $ConfigActual | Add-Member MSIAprofile $Config.MSIAprofile -Force
                                            $ConfigActual | Add-Member MSIApath $Config.MSIApath -Force

                                            $PoolsActual | Add-Member NiceHash ([PSCustomObject]@{
                                                    BTC = if($NicehashWallet -eq $Config.Wallet -or $NicehashWallet -eq ''){'$Wallet'}else{$NicehashWallet}
                                                    Worker = if($NicehashWorkerName -eq $Config.WorkerName -or $NicehashWorkerName -eq ''){'$WorkerName'}else{$NicehashWorkerName}
                                            }) -Force

                                            $ConfigActual | ConvertTo-Json | Out-File $ConfigFile                                               
                                            $PoolsActual | ConvertTo-Json | Out-File $PoolsConfigFile

                                            Write-Host " "
                                            Write-Host "Changes written to configuration. " -ForegroundColor Yellow
                                            Write-Host " "

                                            if ($IsInitialSetup) {
                                                Write-Host "Well done! You made it through the setup wizard - an initial configuration has been created " -ForegroundColor Yellow
                                                Write-Host "If you want to start mining, please select to exit the configuration at the following prompt. After this, in the next minutes, RainbowMiner will download all miner programs. So please be patient and let it run. There will pop up some windows, from time to time. If you happen to click into one of those black popup windows, they will hang: press return in this window to resume operation" -ForegroundColor Yellow
                                                Write-Host " "
                                            }
                                            $IsInitialSetup = $false
                                            $GlobalSetupDone = $true
                                        }
                                    }
                                    $GlobalSetupStepBack = $GlobalSetupStep
                                    $GlobalSetupStep++
                                }
                                catch {
                                    if (@("back","<") -icontains $_.Exception.Message) {
                                        $GlobalSetupStep = $GlobalSetupStepBack
                                    }
                                    elseif ($_.Exception.Message -like "Goto*") {
                                        $GlobalSetupStepBack = $GlobalSetupStep
                                        $GlobalSetupStep = [int]($_.Exception.Message -split "\s+")[1]
                                    }
                                    else {
                                        Write-Host " "
                                        Write-Host "Cancelled without changing the configuration" -ForegroundColor Red
                                        Write-Host " "
                                        $ReReadConfig = $GlobalSetupDone = $true
                                    }
                                }
                            } until ($GlobalSetupDone)
                        }
                        elseif ($SetupType -eq "M") {

                            Write-Host "*** Miner Configuration ***" -ForegroundColor Green
                            Write-Host " "
                            Write-Host "Hints:" -ForegroundColor Yellow
                            Write-Host "- the defaults are your current configuration. Press Return to accept the defaults." -ForegroundColor Yellow
                            Write-Host "- fields marked with * are mandatory" -ForegroundColor Yellow
                            Write-Host "- use comma `",`" to separate list entries" -ForegroundColor Yellow
                            Write-Host "- add new entries to a list, by adding a `"+`" in front of your input" -ForegroundColor Yellow
                            Write-Host "- remove entries from a list, by adding a `"-`" in front of your input" -ForegroundColor Yellow
                            Write-Host "- enter `"list`" or `"help`" to show a list of all valid entries" -ForegroundColor Yellow
                            Write-Host "- enter `"delete`" to clear a non-mandatory entry" -ForegroundColor Yellow
                            Write-Host " "

                            $AvailDeviceName = @()
                            if ($Config.MiningMode -ne "legacy") {$SetupDevices | Select-Object -ExpandProperty Model -Unique | Foreach-Object {$AvailDeviceName += $_}}
                            if (Select-Device $SetupDevices "nvidia") {$AvailDeviceName += "NVIDIA"}
                            if (Select-Device $SetupDevices "amd") {$AvailDeviceName += "AMD"}
                            if (Select-Device $SetupDevices "cpu") {$AvailDeviceName += "CPU"}
                            $AvailDeviceName = $AvailDeviceName | Select-Object -Unique | Sort-Object

                            $MinerSetupDone = $false
                            do {
                                try {
                                    $EditMinerName = Read-HostString -Prompt "Which miner do you want to configure? (leave empty to end miner config)" -Characters "A-Z0-9.-_" -Valid $AvailMiners
                                    if ($EditMinerName -eq '') {throw}
                                    if ($Config.MiningMode -eq "Legacy") {
                                        $EditDeviceName = Read-HostString -Prompt ".. running on which devices (amd/nvidia/cpu)? (leave empty to end miner config)" -Characters "A-Z" -Valid $AvailDeviceName
                                        if ($EditDeviceName -eq '') {throw}
                                    } else {
                                        [String[]]$EditDeviceName_Array = Read-HostArray -Prompt ".. running on which device(s)? (leave empty to end miner config)" -Characters "A-Z0-9#" -Valid $AvailDeviceName
                                        ForEach ($EditDevice0 in @("nvidia","amd","cpu")) {
                                            if ($EditDeviceName_Array -icontains $EditDevice0) {
                                                $EditDeviceName_Array = @(Select-Device $SetupDevices "nvidia" | Select-Object -ExpandProperty Model -Unique)
                                                break
                                            }
                                        }
                                        [String]$EditDeviceName = @($EditDeviceName_Array | Sort-Object) -join '-'
                                        if ($EditDeviceName -eq '') {throw}
                                    }
                                    $EditAlgorithm = Read-HostString -Prompt ".. calculating which main algorithm? (leave empty to end miner config)" -Characters "A-Z0-9" -Valid (Get-Algorithms)
                                    if ($EditAlgorithm -eq '') {throw}
                                    $EditSecondaryAlgorithm = Read-HostString -Prompt ".. calculating which secondary algorithm?" -Characters "A-Z0-9" -Valid (Get-Algorithms)
                        
                                    $EditMinerName += "-" + $EditDeviceName
                                    Write-Host "Configuration for $($EditMinerName), calculating $($EditAlgorithm)$(if($EditSecondaryAlgorithm -ne ''){"+"+$EditSecondaryAlgorithm})"

                                    $EditMinerConfig = [PSCustomObject]@{
                                        MainAlgorithm = $EditAlgorithm
                                        SecondaryAlgorithm = $EditSecondaryAlgorithm
                                        Params = ""
                                        Profile = ""
                                    }
                        
                                    if (Get-Member -InputObject $MinersActual -Name $EditMinerName -Membertype Properties) {
                                        $MinersActual.$EditMinerName | Where-Object {$_.MainAlgorithm -eq $EditAlgorithm -and $_.SecondaryAlgorithm -eq $EditSecondaryAlgorithm} | Foreach-Object {
                                            $EditMinerConfig.Params = $_.Params
                                            $EditMinerConfig.Profile = $_.Profile
                                        }
                                    }

                                    $EditMinerConfig.Params = Read-HostString -Prompt "Additional command line parameters" -Default $EditMinerConfig.Params -Characters " -~"
                                    $EditMinerConfig.Profile = Read-HostString -Prompt "MSI Afterburner Profile" -Default $EditMinerConfig.Profile -Characters "12345" -Length 1

                                    if (Read-HostBool "Really write Params=`"$($EditMinerConfig.Params)`", Profile=`"$($EditMinerConfig.Profile)`" to $($PoolsConfigFile)?") {
                                        $MinersActual | Add-Member $EditMinerName -Force (@($MinersActual.$EditMinerName | Where-Object {$_.MainAlgorithm -ne $EditAlgorithm -or $_.SecondaryAlgorithm -ne $EditSecondaryAlgorithm})+@($EditMinerConfig))
                                        $MinersActual | ConvertTo-Json | Out-File $MinersConfigFile
                                    }                        

                                    if (-not (Read-HostBool "Edit another miner?")){throw}
                        
                                } catch {$MinerSetupDone = $true}
                            } until ($MinerSetupDone)
                        }
                        elseif ($SetupType -eq "P") {

                            Write-Host "*** Pool Configuration ***" -ForegroundColor Green
                            Write-Host " "
                            Write-Host "Hints:" -ForegroundColor Yellow
                            Write-Host "- the defaults are your current configuration. Press Return to accept the defaults." -ForegroundColor Yellow
                            Write-Host "- fields marked with * are mandatory" -ForegroundColor Yellow
                            Write-Host "- use comma `",`" to separate list entries" -ForegroundColor Yellow
                            Write-Host "- add new entries to a list, by adding a `"+`" in front of your input" -ForegroundColor Yellow
                            Write-Host "- remove entries from a list, by adding a `"-`" in front of your input" -ForegroundColor Yellow
                            Write-Host "- enter `"list`" or `"help`" to show a list of all valid entries" -ForegroundColor Yellow
                            Write-Host "- enter `"delete`" to clear a non-mandatory entry" -ForegroundColor Yellow
                            Write-Host " "
                            Write-Host "(under development)" -ForegroundColor Red
                            Write-Host " "                           

                            $PoolSetupDone = $false
                            do {
                                try {
                                    $Pool_Name = Read-HostString -Prompt "Which pool do you want to configure? (leave empty to end pool config)" -Characters "A-Z0-9" -Valid $AvailPools
                                    if ($Pool_Name -eq '') {throw}

                                    if (-not $PoolsActual.$Pool_Name) {
                                    }

                                    $Pool_Parameters = @{StatSpan = [TimeSpan]::FromSeconds(0);InfoOnly = $true}
                                    $Pool_Config = @{}
                                    if ($Config.Pools.$Pool_Name) {
                                        $Config.Pools.$Pool_Name | Get-Member -MemberType NoteProperty | ForEach-Object {$Pool_Parameters.($_.Name) = $Config.Pools.$Pool_Name.($_.Name)}                      
                                        Compare-Object @("Penalty","PoolFee","DataWindow") @($Pool_Parameters.Keys) -ExcludeDifferent -IncludeEqual | Select-Object -ExpandProperty InputObject | Foreach-Object {$Pool_Config.$_ = $Pool_Parameters.$_}
                                    }
                                    $Pool = Get-ChildItemContent "Pools\$($Pool_Name).ps1" -Parameters $Pool_Parameters | Foreach-Object {if ($Pool_Config.Count){$_.Content | Add-Member -NotePropertyMembers $Pool_Config -Force};$_}

                                    $Pool_Algorithm = Read-HostArray -Prompt "Enter the algorithm you want to mine (leave empty for all)" -Default $Config.Algorithm -Characters "A-Z0-9" -Valid (Get-Algorithms) | Foreach-Object {if (@("cancel","exit","back","<") -icontains $_) {throw $_};$_}
                                    $Pool_ExcludeAlgorithm = Read-HostArray -Prompt "Enter the algorithm you do want to exclude (leave empty for none)" -Default $Config.ExcludeAlgorithm -Characters "A-Z0-9" -Valid (Get-Algorithms) | Foreach-Object {if (@("cancel","exit","back","<") -icontains $_) {throw $_};$_}
                                                                        

                                    if ($false) {
                                    $EditMinerConfig = [PSCustomObject]@{
                                        MainAlgorithm = $EditAlgorithm
                                        SecondaryAlgorithm = $EditSecondaryAlgorithm
                                        Params = ""
                                        Profile = ""
                                    }
                        
                                    if (Get-Member -InputObject $MinersActual -Name $EditMinerName -Membertype Properties) {
                                        $MinersActual.$EditMinerName | Where-Object {$_.MainAlgorithm -eq $EditAlgorithm -and $_.SecondaryAlgorithm -eq $EditSecondaryAlgorithm} | Foreach-Object {
                                            $EditMinerConfig.Params = $_.Params
                                            $EditMinerConfig.Profile = $_.Profile
                                        }
                                    }

                                    $EditMinerConfig.Params = Read-HostString -Prompt "Additional command line parameters" -Default $EditMinerConfig.Params -Characters " -~"
                                    $EditMinerConfig.Profile = Read-HostString -Prompt "MSI Afterburner Profile" -Default $EditMinerConfig.Profile -Characters "12345" -Length 1

                                    if (Read-HostBool "Really write Params=`"$($EditMinerConfig.Params)`", Profile=`"$($EditMinerConfig.Profile)`" to $($PoolsConfigFile)?") {
                                        $MinersActual | Add-Member $EditMinerName -Force (@($MinersActual.$EditMinerName | Where-Object {$_.MainAlgorithm -ne $EditAlgorithm -or $_.SecondaryAlgorithm -ne $EditSecondaryAlgorithm})+@($EditMinerConfig))
                                        $MinersActual | ConvertTo-Json | Out-File $MinersConfigFile
                                    }                        
                                    }

                                    if (-not (Read-HostBool "Edit another pool?")){throw}
                        
                                } catch {$PoolSetupDone = $true}
                            } until ($PoolSetupDone)
                        }
                    } until (-not $RunSetup)
                    $RestartMiners = $true
                    $ReReadConfig = $true
                    Write-Host " "
                    Write-Host "Exiting configuration setup - all miners will be restarted. Please be patient!" -ForegroundColor Yellow
                    Write-Host " "
                }
            } until (-not $ReReadConfig)
        } else {
            $ConfigCheckFields = $false
        }
    }
    
    #Error in Config.txt
    if ($Config -isnot [PSCustomObject]) {
        Write-Log -Level Error "$($ConfigFile) is invalid. Cannot continue. "
        Start-Sleep 10
        Exit
    }

    #Convert to array, if needed and check contents of some fields, if Config has been reread or reset
    if ($ConfigCheckFields) {
        #for backwards compatibility
        if ($Config.Type -ne $null) {$Config | Add-Member DeviceName $Config.Type -Force}
        if ($Config.GPUs -ne $null -and $Config.GPUs) {
            if ($Config.GPUs -is [string]) {$Config.GPUs = [regex]::split($Config.GPUs,"[,;:\s]+")}
            $Config | Add-Member DeviceName @() -Force
            Get-Device "nvidia" | Where-Object {$Config.GPUs -contains $_.PlatformId_Index} | Foreach-Object {$Config.DeviceName += [string]("GPU#{0:d2}" -f $_.Type_Index)}
        }

        $Config.PSObject.Properties | Where-Object {$_.TypeNameOfValue -ne "System.Object" -and $_.MemberType -eq "NoteProperty"} | Select-Object Name,Value | Foreach-Object {
            $name = $_.Name;
            $var = Get-Variable -ValueOnly $name -ErrorAction SilentlyContinue
            if ( $var -is [array] -and $Config.$name -is [string] ) {$Config.$name = $Config.$name.Trim(); $Config.$name = if ($Config.$name -ne ''){[regex]::split($Config.$name.Trim(),"[,;:\s]+")}else{@()}}
            elseif ( ($var -is [bool] -or $var -is [switch]) -and $Config.$name -isnot [bool] ) {$Config.$name = Get-Yes $Config.$name}
            elseif ( $var -is [int] -and $Config.$name -isnot [int] ) { $Config.$name = [int]$Config.$name }            
        }
        $Config.Algorithm = $Config.Algorithm | ForEach-Object {Get-Algorithm $_}
        $Config.ExcludeAlgorithm = $Config.ExcludeAlgorithm | ForEach-Object {Get-Algorithm $_}
        $Config.Region = $Config.Region | ForEach-Object {Get-Region $_}
        $Config.Currency = $Config.Currency | ForEach-Object {$_.ToUpper()}
        $Config.UIstyle = if ( $Config.UIstyle -ne "full" -and $Config.UIstyle -ne "lite" ) {"full"} else {$Config.UIstyle}            

        #For backwards compatibility
        if ($Config.Wallet -and -not $Config.MinerStatusKey) {$Config.MinerStatusKey = $Config.Wallet}      
        if ($Config.LegacyMode -ne $null) {$Config.MiningMode = if (Get-Yes $Config.LegacyMode){"legacy"}else{"device"}}
    }

    #Initialize the API and Get-Device
    if(!(Test-Path Variable:API)) {
        Import-Module .\API.psm1
        Start-APIServer -RemoteAPI:$Config.RemoteAPI
        $API.Version = $Version
    }
    if ($API.AllDevices -eq $null) {$API.AllDevices = @(Get-Device -Refresh | Select-Object)}

    $MSIAenabled = $Config.MSIAprofile -gt 0 -and (Test-Path $Config.MSIApath)

    #Check for devices config
    Set-DevicesConfigDefault $DevicesConfigFile
    if (Test-Path $DevicesConfigFile) {
        if ($ConfigCheckFields -or -not $Config.Devices -or (Get-ChildItem $DevicesConfigFile).LastWriteTime.ToUniversalTime() -gt $Updatetracker["Config"]["DevicesConfigFile"]) {        
            $Updatetracker["Config"]["DevicesConfigFile"] = (Get-ChildItem $DevicesConfigFile).LastWriteTime.ToUniversalTime()
            $Config | Add-Member Devices (Get-ChildItemContent $DevicesConfigFile).Content -Force
            foreach ($p in @($Config.Devices.PSObject.Properties.Name)) {
                $Config.Devices.$p | Add-Member Algorithm @(($Config.Devices.$p.Algorithm | Select-Object) | Where-Object {$_} | Foreach-Object {Get-Algorithm $_}) -Force
                $Config.Devices.$p | Add-Member ExcludeAlgorithm @(($Config.Devices.$p.ExcludeAlgorithm | Select-Object) | Where-Object {$_} | Foreach-Object {Get-Algorithm $_}) -Force
                foreach ($q in @("MinerName","PoolName","ExcludeMinerName","ExcludePoolName")) {
                    if ($Config.Devices.$p.$q -is [string]){$Config.Devices.$p.$q = if ($Config.Devices.$p.$q.Trim() -eq ""){@()}else{[regex]::split($Config.Devices.$p.$q.Trim(),"[,;:\s]+")}}
                }
                $Config.Devices.$p | Add-Member DisableDualMining ($Config.Devices.$p.DisableDualMining -and (Get-Yes $Config.Devices.$p.DisableDualMining)) -Force
            }
        }
    }   

    #Check for pool config
    Set-PoolsConfigDefault $PoolsConfigFile
    if (Test-Path $PoolsConfigFile) {
        if ($ConfigCheckFields -or -not $Config.Pools -or (Get-ChildItem $PoolsConfigFile).LastWriteTime.ToUniversalTime() -gt $Updatetracker["Config"]["PoolsConfigFile"]) {        
            $Updatetracker["Config"]["PoolsConfigFile"] = (Get-ChildItem $PoolsConfigFile).LastWriteTime.ToUniversalTime()
            $Config | Add-Member Pools (Get-ChildItemContent $PoolsConfigFile -Parameters @{
                Wallet              = $Config.Wallet
                UserName            = $Config.UserName
                WorkerName          = $Config.WorkerName
                API_ID              = $Config.API_ID
                API_Key             = $Config.API_Key
            } | Select-Object -ExpandProperty Content) -Force
            foreach ($p in @($Config.Pools.PSObject.Properties.Name)) {
                $Config.Pools.$p | Add-Member Algorithm @(($Config.Pools.$p.Algorithm | Select-Object) | Where-Object {$_} | Foreach-Object {Get-Algorithm $_}) -Force
                $Config.Pools.$p | Add-Member ExcludeAlgorithm @(($Config.Pools.$p.ExcludeAlgorithm | Select-Object) | Where-Object {$_} | Foreach-Object {Get-Algorithm $_}) -Force
            }
        }
    }    

    $AvailPools | Where-Object {-not $Config.Pools.$_} | ForEach-Object {
        $Config.Pools | Add-Member $_ (
            [PSCustomObject]@{
                BTC     = $Config.Wallet
                User    = $Config.UserName
                Worker  = $Config.WorkerName
                API_ID  = $Config.API_ID
                API_Key = $Config.API_Key
            }
        )
    }
    
    # Copy the user's config before changing anything for donation runs
    # This is used when getting pool balances so it doesn't get pool balances of the donation address instead
    $UserConfig = $Config.PSObject.Copy()

    #Activate or deactivate donation  
    $DonateNow = $false
    $DonateMinutes = if ($Config.Donate -lt 10) {10} else {$Config.Donate}
    $DonateDelayHours = 24
    if ($DonateMinutes -gt 15) {
        $DonateMinutes /= 2
        $DonateDelayHours /= 2
    }
    if (-not $LastDonated) {$LastDonated = $Timer.AddHours(1 - $DonateDelayHours).AddMinutes($DonateMinutes)}
    if ($Timer.AddHours(-$DonateDelayHours) -ge $LastDonated) {$LastDonated = $Timer;Write-Log "Donation run finished. "}    
    if ($Timer.AddHours(-$DonateDelayHours).AddMinutes($DonateMinutes) -ge $LastDonated) {    
        $DonationPools = @()        
        if (-not $DonationData) {$DonationData = '{"Wallets":{"NiceHash":{"BTC":"3HFhYADZvybBstETYNEVMqVWMU9EJRfs4f","Worker":"mpx"},"Ravenminer":{"RVN":"RGo5UgbnyNkfA8sUUbv62cYnV4EfYziNxH","Worker":"mpx"},"Default":{"BTC":"3DxRETpBoXKrEBQxFb2HsPmG6apxHmKmUx","Worker":"mpx"}},"Pools":["nicehash","blazepool","ravenminer"],"Algorithm":["bitcore","blake2s","c11","cryptonightheavy","cryptonightv7","equihash","ethash","hmq1725","hsr","keccak","keccakc","lyra2re2","lyra2z","neoscrypt","pascal","phi","skein","skunk","timetravel","tribus","vit","x16r","x16s","x17","xevan","yescrypt","yescryptr16"]}' | ConvertFrom-Json}
        $AvailPools | ForEach-Object {
            $DonationData1 = if (Get-Member -InputObject ($DonationData.Wallets) -Name $_ -MemberType NoteProperty) {$DonationData.Wallets.$_} else {$DonationData.Wallets.Default};
            $DonationPools += $_
            $Config.Pools | Add-Member $_ $DonationData1 -Force
            $DonateNow = $true
        }
        if ($DonateNow) {
            $Updatetracker["Config"]["ConfigFile"] = 0
            $DonationPoolsAvail = Compare-Object @($DonationData.Pools) @($DonationPools) -IncludeEqual -ExcludeDifferent | Select-Object -ExpandProperty InputObject
            $Config | Add-Member Algorithm $($DonationData.Algorithm | ForEach-Object {Get-Algorithm $_}) -Force
            if (-not $DonationPoolsAvail.Count) {            
                $Config | Add-Member ExcludePoolName @() -Force
            } else {
                $Config | Add-Member PoolName $DonationPoolsAvail -Force
                $Config | Add-Member ExcludePoolName @(Compare-Object @($DonationPools) @($DonationPoolsAvail) | Select-Object -ExpandProperty InputObject) -Force
            }
            Write-Log "Donation run started for the next $(($LastDonated-($Timer.AddHours(-$DonateDelayHours))).Minutes +1) minutes. "
        }
    } else {
        Write-Log ("Next donation run will start in {0:hh} hour(s) {0:mm} minute(s). " -f $($LastDonated.AddHours($DonateDelayHours) - ($Timer.AddMinutes($DonateMinutes))))
    }

    #Give API access to the current running configuration
    $API.Config = $Config

    #Clear pool cache if the pool configuration has changed
    if (($ConfigBackup.Pools | ConvertTo-Json -Compress) -ne ($Config.Pools | ConvertTo-Json -Compress)) {$AllPools = $null}

    #Clear balances if pool configuration flag has changed
    if ($ConfigBackup.ShowPoolBalances -ne $Config.ShowPoolBalances) {$Balances = $null}

    if ($ConfigCheckFields) {
        #Actions, when config has changes (or initial)
        # .. for every change

        #load device(s) informatino and device combos
        if ($ConfigBackup.MiningMode -ne $Config.MiningMode -or (Compare-Object $Config.DeviceName $ConfigBackup.DeviceName | Measure-Object).Count -gt 0) {
            Write-Log "Device configuration changed. Refreshing now. "

            #Load information about the devices
            $Devices = @(Get-Device $Config.DeviceName | Select-Object)
            $DevicesByTypes = [PSCustomObject]@{
                NVIDIA = @(Select-Device $Devices "NVIDIA")
                AMD = @(Select-Device $Devices "AMD")
                CPU = @(Select-Device $Devices "CPU")
                Combos = [PSCustomObject]@{}
                FullComboModels = [PSCustomObject]@{}
            }

            #Create combos
            @($DevicesByTypes.PSObject.Properties.Name) | Where {@("Combos","FullComboModels") -inotcontains $_} | Foreach-Object {
                $SubsetType = [String]$_
                $DevicesByTypes.Combos | Add-Member $SubsetType @() -Force
                $DevicesByTypes.FullComboModels | Add-Member $SubsetType $(@($DevicesByTypes.$SubsetType | Select-Object -ExpandProperty Model -Unique | Sort-Object) -join '-') -Force
                Get-DeviceSubSets @($DevicesByTypes.$SubsetType) | Foreach-Object {                       
                    $SubsetModel= $_
                    $DevicesByTypes.Combos.$SubsetType += @($DevicesByTypes.$SubsetType | Where-Object {$SubsetModel.Model -icontains $_.Model} | Foreach-Object {$SubsetNew = $_.PSObject.Copy();$SubsetNew.Model = $($SubsetModel.Model -join '-');$SubsetNew.Model_Name = $($SubsetModel.Model_Name -join '+');$SubsetNew})
                }                                        
            }     

            if ($Config.MiningMode -eq "legacy") {
                @($DevicesByTypes.FullComboModels.PSObject.Properties.Name) | ForEach-Object {
                    $Device_LegacyModel = $_
                    if ($DevicesByTypes.FullComboModels.$Device_LegacyModel -match '-') {
                        $DevicesByTypes.$Device_LegacyModel = $DevicesByTypes.Combos.$Device_LegacyModel | Where-Object Model -eq $DevicesByTypes.FullComboModels.$Device_LegacyModel
                    }
                }
            } elseif ($Config.MiningMode -eq "combo") {
                #add combos to DevicesbyTypes
                @("NVIDIA","AMD","CPU") | Foreach-Object {$DevicesByTypes.$_ += $DevicesByTypes.Combos.$_}     
            }

            #Give API access to the device information
            $API.Devices = $Devices
            $API.DeviceCombos = @($DevicesByTypes.FullComboModels.PSObject.Properties.Name) | ForEach-Object {$DevicesByTypes.$_ | Select-Object -ExpandProperty Model -Unique} | Sort-Object
        }
    }

    #Check for miner config
    Set-MinersConfigDefault -PathToFile $MinersConfigFile
    if (Test-Path $MinersConfigFile) {
        if ($ConfigCheckFields -or -not $Config.Miners -or (Get-ChildItem $MinersConfigFile).LastWriteTime.ToUniversalTime() -gt $Updatetracker["Config"]["MinersConfigFile"]) {        
            $Updatetracker["Config"]["MinersConfigFile"] = (Get-ChildItem $MinersConfigFile).LastWriteTime.ToUniversalTime()
            $Config | Add-Member Miners ([PSCustomObject]@{}) -Force            
            (Get-ChildItemContent -Path $MinersConfigFile).Content.PSObject.Properties | Foreach-Object { 
                $CcMiner = $_               
                $CcMinerName_Array = @($CcMiner.Name -split '-')
                [String[]]$CcMinerNames = @()
                @($DevicesByTypes.FullComboModels.PSObject.Properties.Name) | Where-Object {$CcMinerName_Array.Count -eq 1 -or $_ -eq $CcMinerName_Array[1]} | Foreach-Object {$CcMinerNames += $CcMinerName_Array[0] + "-" + $DevicesByTypes.FullComboModels.$_}
                if ($CcMinerNames.Count -eq 0) {$CcMinerNames += $CcMiner.Name}
                $CcMinerNames | Foreach-Object {
                    $CcMinerName = $_
                    $CcMiner.Value | Foreach-Object {                   
                        $Config.Miners | Add-Member -Name (@($CcMinerName,(Get-Algorithm $_.MainAlgorithm)) + @(if($_.SecondaryAlgorithm){Get-Algorithm $_.SecondaryAlgorithm}) -join '-') -Value ([PSCustomObject]@{Params=$_.Params;Profile=$_.Profile}) -MemberType NoteProperty -Force
                    }
                }
            }
        }
    }

    #Check for GPU failure and reboot, if needed
    if ($Config.RebootOnGPUFailure) { 
        Write-Log "Testing for GPU failure. "
        Test-GPU
    }

    if ($Config.Proxy) {$PSDefaultParameterValues["*:Proxy"] = $Config.Proxy}
    else {$PSDefaultParameterValues.Remove("*:Proxy")}

    foreach ($APIfile in (Get-ChildItem "APIs" -File)) {
        $APIfilelastwritetime = $APIfile.LastWriteTime.ToUniversalTime()
        if ($APIfilelastwritetime -gt $Updatetracker["APIs"][$APIfile.BaseName]) {
            . $APIfile.FullName
            $Updatetracker["APIs"][$APIfile.BaseName] = $APIfilelastwritetime
        }
    }

    Test-TimeSync
    $Timer = (Get-Date).ToUniversalTime()

    $StatStart = $StatEnd
    $StatEnd = $Timer.AddSeconds($Config.Interval)
    $StatSpan = New-TimeSpan $StatStart $StatEnd

    $DecayExponent = [int](($Timer - $DecayStart).TotalSeconds / $DecayPeriod)

    $WatchdogInterval = ($WatchdogInterval / $Strikes * ($Strikes - 1)) + $StatSpan.TotalSeconds
    $WatchdogReset = ($WatchdogReset / ($Strikes * $Strikes * $Strikes) * (($Strikes * $Strikes * $Strikes) - 1)) + $StatSpan.TotalSeconds
    
    #Update the exchange rates
    try {
        Write-Log "Updating exchange rates from Coinbase. "
        [hashtable]$NewRates = @{}
        Invoke-RestMethodAsync "https://api.coinbase.com/v2/exchange-rates?currency=BTC" | Select-Object -ExpandProperty data | Select-Object -ExpandProperty rates | Foreach-Object {$_.PSObject.Properties | Foreach-Object {$NewRates[$_.Name] = $_.Value}}
        $Config.Currency | Where-Object {$NewRates.$_} | ForEach-Object {$Rates[$_] = ([Double]$NewRates.$_)}
        $Config.Currency | Where-Object {-not $NewRates.$_} | Foreach-Object {$Rates[$_] = $($Ticker=Get-Ticker -Symbol $_ -BTCprice;if($Ticker){[Double]1/$Ticker}else{0})}
    }
    catch {
        Write-Log -Level Warn "Coinbase is down. "
    }

    #Update the pool balances every 10 Minutes
    if ($Config.ShowPoolBalances) {
        if ( -not $Balances -or $LastBalances -lt $Timer.AddMinutes(-10) ) {
            Write-Log "Getting pool balances. "
            $Balances = Get-Balance -Config $UserConfig -Rates $Rates -NewRates $NewRates
            $API.Balances = $Balances
            $LastBalances = $Timer
        }
    }

    #Give API access to the current rates
    $API.Rates = $Rates

    #Load the stats
    Write-Log "Loading saved statistics. "

    [hashtable]$Stats = Get-Stat

    #Give API access to the current stats
    $API.Stats = $Stats

    #Load information about the pools
    Write-Log "Loading pool information. "
    [System.Collections.ArrayList]$NewPools = @()
    [System.Collections.ArrayList]$SelectedPoolNames = @()
    if (Test-Path "Pools") {
        $NewPools = $AvailPools | Where-Object {$Config.Pools.$_ -and $Config.ExcludePoolName -inotcontains $_} | ForEach-Object {
            $Pool_Name = $_
            $SelectedPoolNames.Add($Pool_Name) | Out-Null
            [hashtable]$Pool_Config = @{Name = $Pool_Name}
            [hashtable]$Pool_Parameters = @{StatSpan = $StatSpan}
            foreach($p in $Config.Pools.$Pool_Name.PSObject.Properties.Name) {$Pool_Parameters[$p] = $Config.Pools.$Pool_Name.$p}                      
            Compare-Object @("Penalty","PoolFee","DataWindow") @($Pool_Parameters.Keys) -ExcludeDifferent -IncludeEqual | Select-Object -ExpandProperty InputObject | Foreach-Object {$Pool_Config[$_] = $Pool_Parameters[$_]}
            Get-ChildItemContent "Pools\$($Pool_Name).ps1" -Parameters $Pool_Parameters | Foreach-Object {
                $Pool_Config.AlgorithmList = if ($_.Content.Algorithm -match "-") {@((Get-Algorithm $_.Content.Algorithm), ($_.Content.Algorithm -split "-" | Select-Object -Index 0) | Select-Object -Unique)}else{@($_.Content.Algorithm)}
                $_.Content | Add-Member -NotePropertyMembers $Pool_Config -Force -PassThru
                }
        } |
        Where-Object {$Pool_Parameters.Algorithm.Count -eq 0 -or (Compare-Object @($Pool_Parameters.Algorithm | Select-Object) @($_.AlgorithmList | Select-Object) -IncludeEqual -ExcludeDifferent | Measure-Object).Count -gt 0} | 
        Where-Object {$Pool_Parameters.ExcludeAlgorithm.Count -eq 0 -or (Compare-Object @($Pool_Parameters.ExcludeAlgorithm | Select-Object) @($_.AlgorithmList | Select-Object) -IncludeEqual -ExcludeDifferent | Measure-Object).Count -eq 0} | 
        ForEach-Object {
            $Pool_Factor = 1-[Double]($_.Penalty + $(if (-not $Config.IgnoreFees){$_.PoolFee}))/100
            $_.Price *= $Pool_Factor
            $_.StablePrice *= $Pool_Factor     
            $_
        }      
    }

    #Remove stats from pools & miners not longer in use
    if (-not $DonateNow -and (Test-Path "Stats")) {
        Compare-Object @($SelectedPoolNames | Select-Object) @($Stats.Keys | Where-Object {$_ -match '^(.+?)_.+Profit$'} | % {$Matches[1]} | Select-Object -Unique) | Where-Object SideIndicator -eq "=>" | Foreach-Object {Remove-Item "Stats\$($_.InputObject)_*_Profit.txt"}
        Compare-Object @($AvailMiners | Select-Object) @($Stats.Keys | Where-Object {$_ -match '^(.+?)-.+Hashrate$'} | % {$Matches[1]} | Select-Object -Unique) | Where-Object SideIndicator -eq "=>" | Foreach-Object {Remove-Item "Stats\$($_.InputObject)-*_Hashrate.txt"}
    }

    #Give API access to the current running configuration
    $API.NewPools = $NewPools

    #This finds any pools that were already in $AllPools (from a previous loop) but not in $NewPools. Add them back to the list. Their API likely didn't return in time, but we don't want to cut them off just yet
    #since mining is probably still working.  Then it filters out any algorithms that aren't being used.
    [System.Collections.ArrayList]$AllPoolsAdd = @()    
    foreach ($Pool in @(Compare-Object @($NewPools.Name | Select-Object -Unique) @($AllPools.Name | Select-Object -Unique) | Where-Object SideIndicator -EQ "=>" | Select-Object -ExpandProperty InputObject | ForEach-Object {$AllPools | Where-Object Name -EQ $_})) {$AllPoolsAdd.Add($Pool) | Out-Null}    
    [System.Collections.ArrayList]$AllPools = @($NewPools)
    if ($AllPoolsAdd.Count) {$AllPools.Add($AllPoolsAdd) | Out-Null}
    $AllPoolsAdd.Clear()

    #Now remove all deselected pool/algorithm from AllPools
    [System.Collections.ArrayList]$AllPoolsRemove = @()
    $i=0
    foreach ($Pool in $AllPools) {    
        if (
            ($Config.Algorithm.Count -and -not (Compare-Object @($Config.Algorithm | Select-Object) @($Pool.AlgorithmList | Select-Object) -IncludeEqual -ExcludeDifferent | Measure-Object).Count) -or
            ($Config.ExcludeAlgorithm.Count -and (Compare-Object @($Config.ExcludeAlgorithm | Select-Object) @($Pool.AlgorithmList | Select-Object)  -IncludeEqual -ExcludeDifferent | Measure-Object).Count) -or 
            ($Config.ExcludePoolName.Count -and (Compare-Object $Config.ExcludePoolName $Pool.Name -IncludeEqual -ExcludeDifferent | Measure-Object).Count)
            ) {$AllPoolsRemove.Add($Pool) | Out-Null}           
        $i++
    }
    foreach($Pool in $AllPoolsRemove) {$AllPools.Remove($Pool)}
    $AllPoolsRemove.Clear()

    #Give API access to the current running configuration
    $API.AllPools = $AllPools

    #Apply watchdog to pools
    foreach ($Pool in $AllPools) {
        $Pool_WatchdogTimers = $WatchdogTimers | Where-Object PoolName -EQ $Pool.Name | Where-Object Kicked -LT $Timer.AddSeconds( - $WatchdogInterval) | Where-Object Kicked -GT $Timer.AddSeconds( - $WatchdogReset)
        if (($Pool_WatchdogTimers | Measure-Object).Count -ge <#stage#>3 -or ($Pool_WatchdogTimers | Where-Object {$Pool.Algorithm -contains $_.Algorithm} | Measure-Object).Count -ge <#statge#>2) {$AllPoolsRemove.Add($Pool) | Out-Null}
    }
    foreach($Pool in $AllPoolsRemove) {$AllPools.Remove($Pool)}
    $AllPoolsRemove.Clear()

    #Update the active pools
    if ($AllPools.Count -eq 0) {
        Write-Log -Level Warn "No pools available. "
        if ($Downloader) {$Downloader | Receive-Job}
        Start-Sleep $Config.Interval
        continue
    }

    $Pools = [PSCustomObject]@{}

    Write-Log "Selecting best pool for each algorithm. "
    $AllPools.Algorithm | ForEach-Object {$_.ToLower()} | Select-Object -Unique | ForEach-Object {$Pools | Add-Member $_ ($AllPools | Where-Object Algorithm -EQ $_ | Sort-Object -Descending {$Config.PoolName.Count -eq 0 -or (Compare-Object $Config.PoolName $_.Name -IncludeEqual -ExcludeDifferent | Measure-Object).Count -gt 0}, {($Timer - $_.Updated).TotalMinutes -le ($SyncWindow * $Strikes)}, {$_.StablePrice * (1 - $_.MarginOfError)}, {$_.Region -EQ $Config.Region}, {$_.SSL -EQ $Config.SSL} | Select-Object -First 1)}
    if (($Pools | Get-Member -MemberType NoteProperty -ErrorAction Ignore | Select-Object -ExpandProperty Name | ForEach-Object {$Pools.$_.Name} | Select-Object -Unique | ForEach-Object {$AllPools | Where-Object Name -EQ $_ | Measure-Object Updated -Maximum | Select-Object -ExpandProperty Maximum} | Measure-Object -Minimum -Maximum | ForEach-Object {$_.Maximum - $_.Minimum} | Select-Object -ExpandProperty TotalMinutes) -gt $SyncWindow) {
        Write-Log -Level Warn "Pool prices are out of sync ($([Int]($Pools | Get-Member -MemberType NoteProperty -ErrorAction Ignore | Select-Object -ExpandProperty Name | ForEach-Object {$Pools.$_} | Measure-Object Updated -Minimum -Maximum | ForEach-Object {$_.Maximum - $_.Minimum} | Select-Object -ExpandProperty TotalMinutes)) minutes). "
        $PoolsPrice = "StablePrice"
    } else {
        $PoolsPrice = "Price"
    }
    $Pools | Get-Member -MemberType NoteProperty -ErrorAction Ignore | Select-Object -ExpandProperty Name | ForEach-Object {
        $Pools.$_ | Add-Member Price_Bias ($Pools.$_.$PoolsPrice * (1 - ([Math]::Floor(($Pools.$_.MarginOfError * [Math]::Min($Config.SwitchingPrevention,1) * [Math]::Pow($DecayBase, $DecayExponent / ([Math]::Max($Config.SwitchingPrevention,1)))) * 100.00) / 100.00))) -Force
        $Pools.$_ | Add-Member Price_Unbias $Pools.$_.$PoolsPrice -Force
    }

    #Give API access to the pools information
    $API.Pools = $Pools
 
    #Load information about the miners
    Write-Log "Getting miner information. "
    # select only the ones that have a HashRate matching our algorithms, and that only include algorithms we have pools for
    # select only the miners that match $Config.MinerName, if specified, and don't match $Config.ExcludeMinerName
    $AllMiners = if (Test-Path "Miners") {
        Get-ChildItemContent "Miners" -Parameters @{Pools = $Pools; Stats = $Stats; Config = $Config; Devices = $DevicesByTypes} | ForEach-Object {
            if (@($DevicesByTypes.FullComboModels.PSObject.Properties.Name) -icontains $_.Content.DeviceModel) {$_.Content.DeviceModel = $($DevicesByTypes.FullComboModels."$($_.Content.DeviceModel)")}
            $_.Content | Add-Member -NotePropertyMembers @{Name=$_.Name;BaseName=$_.BaseName;BaseAlgorithm=@($_.Content.HashRates.PSObject.Properties.Name | Foreach-Object {$_ -split '-' | Select-Object -Index 0} | Select-Object)} -PassThru -Force
        } | 
            Where-Object {$_.DeviceName} | #filter miners for non-present hardware
            Where-Object {-not $Config.DisableDualMining -or $_.HashRates.PSObject.Properties.Name.Count -eq 1} | #filter dual algo miners
            Where-Object {(Compare-Object @($Devices.Name | Select-Object) @($_.DeviceName | Select-Object) | Where-Object SideIndicator -EQ "=>" | Measure-Object).Count -eq 0} | 
            Where-Object {(Compare-Object @($Pools.PSObject.Properties.Name | Select-Object) @($_.HashRates.PSObject.Properties.Name | Select-Object) | Where-Object SideIndicator -EQ "=>" | Measure-Object).Count -eq 0} |             
            Where-Object {$Config.MinerName.Count -eq 0 -or (Compare-Object $Config.MinerName $_.BaseName -IncludeEqual -ExcludeDifferent | Measure-Object).Count -gt 0} | 
            Where-Object {$Config.ExcludeMinerName.Count -eq 0 -or (Compare-Object $Config.ExcludeMinerName $_.BaseName -IncludeEqual -ExcludeDifferent | Measure-Object).Count -eq 0} |
            Foreach-Object {
                $MinerOk = $true
                foreach ($p in @($_.DeviceModel -split '-')) {
                    if ($Config.Devices.$p -and
                        (
                            ($Config.Devices.$p.DisableDualMining -and $_.HashRates.PSObject.Properties.Name.Count -gt 1) -or
                            ($Config.Devices.$p.Algorithm.Count -gt 0 -and (Compare-Object $Config.Devices.$p.Algorithm $_.BaseAlgorithm -IncludeEqual -ExcludeDifferent | Measure-Object).Count -eq 0) -or
                            ($Config.Devices.$p.ExcludeAlgorithm.Count -gt 0 -and (Compare-Object $Config.Devices.$p.ExcludeAlgorithm $_.BaseAlgorithm -IncludeEqual -ExcludeDifferent | Measure-Object).Count -gt 0) -or
                            ($Config.Devices.$p.MinerName.Count -gt 0 -and ($Config.Devices.$p.MinerName -inotcontains $_.Basename)) -or
                            ($Config.Devices.$p.ExcludeMinerName.Count -gt 0 -and ($Config.Devices.$p.ExcludeMinerName -icontains $_.Basename))
                        )
                    ) {$MinerOk=$false;break}
                }
                if ($MinerOk) {$_}
            }
    }


    if ($Config.MiningMode -eq "combo") {
        if (($AllMiners | Where-Object {$_.HashRates.PSObject.Properties.Value -eq $null -and $_.DeviceModel -notmatch '-'} | Measure-Object).Count -gt 1) {
            #Benchmarking is still ongoing - remove device combos from miners
            $AllMiners = $AllMiners | Where-Object {$_.DeviceModel -notmatch '-'}
        } else {
            #Remove device combos, where the parameter-preset is different and there does not exist an own definition
            $AllMiners = $AllMiners | Where-Object {
                $_.DeviceModel -notmatch '-' -or 
                (Get-Member -InputObject $Config.Miners -Name $(@($_.BaseName | Select-Object) + @($_.DeviceModel | Select-Object) + @($_.BaseAlgorithm | Select-Object) -join '-') -MemberType NoteProperty) -or 
                $($Miner = $_; (@($Miner.DeviceModel -split '-') | Foreach-Object {
                    $Miner_ConfigName = @($Miner.BaseName | Select-Object) + @($_ | Select-Object) + @($Miner.BaseAlgorithm | Select-Object) -join '-'
                    if (Get-Member -InputObject $Config.Miners -Name $Miner_ConfigName -MemberType NoteProperty){$Config.Miners.$Miner_ConfigName.Params}
                } | Select-Object -Unique | Measure-Object).Count -le 1)
            }

            #Gather mining statistics for fresh combos
            $AllMiners | Where-Object {$_.HashRates.PSObject.Properties.Value -eq $null -and $_.DeviceModel -match '-'} | Foreach-Object {
                $ComboMiner = $_
                $ComboAlgos = $ComboMiner.HashRates.PSObject.Properties.Name
                $AllMiners | 
                    Where-Object {$_.BaseName -eq $ComboMiner.BaseName -and $_.DeviceModel -notmatch '-' -and $($ComboMiner.Name -replace "-GPU.+$","") -eq $($_.Name -replace "-GPU.+$","") -and @($ComboMiner.DeviceModel -split '-') -icontains $_.DeviceModel -and (Compare-Object @($ComboAlgos) @($_.HashRates.PSObject.Properties.Name) | Measure-Object).Count -eq 0} | 
                    Select-Object -ExpandProperty HashRates |
                    Measure-Object -Sum @($ComboAlgos) |
                    Foreach-Object {$ComboMiner.HashRates."$($_.Property)" = $_.Sum * 1.001} 
                    #we exagerate a bit to prefer combos over single miners for startup. If the combo runs less good, later, it will fall back by itself
            }
        }
    }
    
    Write-Log "Calculating profit for each miner. "
    $AllMiners | ForEach-Object {
        $Miner = $_

        $Miner_HashRates = [PSCustomObject]@{}
        $Miner_DevFees = [PSCustomObject]@{}
        $Miner_Pools = [PSCustomObject]@{}
        $Miner_Pools_Comparison = [PSCustomObject]@{}
        $Miner_Profits = [PSCustomObject]@{}
        $Miner_Profits_Comparison = [PSCustomObject]@{}
        $Miner_Profits_MarginOfError = [PSCustomObject]@{}
        $Miner_Profits_Bias = [PSCustomObject]@{}
        $Miner_Profits_Unbias = [PSCustomObject]@{}        

        $Miner_CommonCommands = @($Miner.BaseName | Select-Object) + @($Miner.DeviceModel | Select-Object) + @($Miner.BaseAlgorithm | Select-Object) -join '-'
        if ($Config.Miners -and (Get-Member -InputObject $Config.Miners -Name $Miner_CommonCommands -MemberType NoteProperty)) {
            if ($Config.Miners.$Miner_CommonCommands.Params -and $Miner.Arguments -is [string]) {
                $Miner | Add-Member -Name Arguments -Value (@($Miner.Arguments,$Config.Miners.$Miner_CommonCommands.Params) -join ' ') -MemberType NoteProperty -Force
            }
            if ($Config.Miners.$Miner_CommonCommands.Profile) {
                $Miner | Add-Member -Name MSIAprofile -Value $Config.Miners.$Miner_CommonCommands.Profile -MemberType NoteProperty -Force
            }
        } elseif ($Config.MiningMode -eq "combo" -and $Miner.DeviceModel -match '-') {
            #combo handling - we know that combos always have equal params, because we preselected them, already
            $Miner_CommonCommands = @($Miner.BaseName | Select-Object) + @($Miner.DeviceModel -split '-' | Select-Object -First 1) + @($Miner.BaseAlgorithm | Select-Object) -join '-'
            if ($Config.Miners -and (Get-Member -InputObject $Config.Miners -Name $Miner_CommonCommands -MemberType NoteProperty)) {
                if ($Config.Miners.$Miner_CommonCommands.Params -and $Miner.Arguments -is [string]) {
                    $Miner | Add-Member -Name Arguments -Value (@($Miner.Arguments,$Config.Miners.$Miner_CommonCommands.Params) -join ' ') -MemberType NoteProperty -Force
                }
            }
            [Int[]]$Miner_MSIAprofile = @($Miner.DeviceModel -split '-') | Foreach-Object {
                $Miner_CommonCommands = @($Miner.BaseName | Select-Object) + @($_ | Select-Object) + @($Miner.BaseAlgorithm | Select-Object) -join '-'
                if ($Config.Miners.$Miner_CommonCommands.Profile) {$Config.Miners.$Miner_CommonCommands.Profile}
            } | Select-Object -Unique
            if (($Miner_MSIAprofile | Measure-Object).Count -eq 1 -and $Miner_MSIAprofile[0]) {
                $Miner | Add-Member -Name MSIAprofile -Value $($Miner_MSIAprofile[0]) -MemberType NoteProperty -Force
            }
        }

        $Miner.HashRates.PSObject.Properties.Name | ForEach-Object { #temp fix, must use 'PSObject.Properties' to preserve order
            $Miner_DevFees | Add-Member $_ ([Double]$(if (-not $Config.IgnoreFees -and $Miner.DevFee) {[Double]$(if (@("Hashtable","PSCustomObject") -icontains $Miner.DevFee.GetType().Name) {$Miner.DevFee.$_} else {$Miner.DevFee})} else {0})) -Force
            $Miner_DevFeeFactor = (1-$Miner_DevFees.$_/100)
            $Miner_HashRates | Add-Member $_ ([Double]$Miner.HashRates.$_)
            $Miner_Pools | Add-Member $_ ([PSCustomObject]$Pools.$_)
            $Miner_Pools_Comparison | Add-Member $_ ([PSCustomObject]$Pools.$_)
            $Miner_Profits | Add-Member $_ ([Double]$Miner.HashRates.$_ * $Pools.$_.Price * $Miner_DevFeeFactor)
            $Miner_Profits_Comparison | Add-Member $_ ([Double]$Miner.HashRates.$_ * $Pools.$_.StablePrice * $Miner_DevFeeFactor)
            $Miner_Profits_Bias | Add-Member $_ ([Double]$Miner.HashRates.$_ * $Pools.$_.Price_Bias * $Miner_DevFeeFactor)
            $Miner_Profits_Unbias | Add-Member $_ ([Double]$Miner.HashRates.$_ * $Pools.$_.Price_Unbias * $Miner_DevFeeFactor)
        }

        $Miner_Profit = [Double]($Miner_Profits.PSObject.Properties.Value | Measure-Object -Sum).Sum
        $Miner_Profit_Comparison = [Double]($Miner_Profits_Comparison.PSObject.Properties.Value | Measure-Object -Sum).Sum
        $Miner_Profit_Bias = [Double]($Miner_Profits_Bias.PSObject.Properties.Value | Measure-Object -Sum).Sum
        $Miner_Profit_Unbias = [Double]($Miner_Profits_Unbias.PSObject.Properties.Value | Measure-Object -Sum).Sum
        
        $Miner.HashRates | Get-Member -MemberType NoteProperty | Select-Object -ExpandProperty Name | ForEach-Object {
            $Miner_Profits_MarginOfError | Add-Member $_ ([Double]$Pools.$_.MarginOfError * (& {if ($Miner_Profit) {([Double]$Miner.HashRates.$_ * $Pools.$_.StablePrice) / $Miner_Profit}else {1}}))
        }

        $Miner_Profit_MarginOfError = [Double]($Miner_Profits_MarginOfError.PSObject.Properties.Value | Measure-Object -Sum).Sum

        $Miner.HashRates | Get-Member -MemberType NoteProperty | Select-Object -ExpandProperty Name | ForEach-Object {
            if (-not [String]$Miner.HashRates.$_) {
                $Miner_HashRates.$_ = $null
                $Miner_Profits.$_ = $null
                $Miner_Profits_Comparison.$_ = $null
                $Miner_Profits_Bias.$_ = $null
                $Miner_Profits_Unbias.$_ = $null
                $Miner_Profit = $null
                $Miner_Profit_Comparison = $null
                $Miner_Profits_MarginOfError = $null
                $Miner_Profit_Bias = $null
                $Miner_Profit_Unbias = $null
            }
        }

        $Miner | Add-Member HashRates $Miner_HashRates -Force
        $Miner | Add-Member DevFee $Miner_DevFees -Force

        $Miner | Add-Member Pools $Miner_Pools
        $Miner | Add-Member Profits $Miner_Profits
        $Miner | Add-Member Profits_Comparison $Miner_Profits_Comparison
        $Miner | Add-Member Profits_Bias $Miner_Profits_Bias
        $Miner | Add-Member Profits_Unbias $Miner_Profits_Unbias
        $Miner | Add-Member Profit $Miner_Profit
        $Miner | Add-Member Profit_Comparison $Miner_Profit_Comparison
        $Miner | Add-Member Profit_MarginOfError $Miner_Profit_MarginOfError
        $Miner | Add-Member Profit_Bias $Miner_Profit_Bias
        $Miner | Add-Member Profit_Unbias $Miner_Profit_Unbias

        $Miner | Add-Member DeviceName @($Miner.DeviceName | Select-Object -Unique | Sort-Object) -Force

        $Miner.Path = $ExecutionContext.SessionState.Path.GetUnresolvedProviderPathFromPSPath($Miner.Path)
        if ($Miner.PrerequisitePath) {$Miner.PrerequisitePath = $ExecutionContext.SessionState.Path.GetUnresolvedProviderPathFromPSPath($Miner.PrerequisitePath)}

        if ($Miner.Arguments -is [string]) {$Miner.Arguments = ($Miner.Arguments -replace "\s+"," ").trim()}
        else {$Miner.Arguments = $Miner.Arguments | ConvertTo-Json -Depth 10 -Compress} 
        
        #if ($Miner.MSIAprofile -eq $null) {$Miner | Add-Member MSIAprofile $Config.MSIAprofile -Force}
        if ($Miner.ExtendInterval -eq $null) {$Miner | Add-Member ExtendInterval 0 -Force}              
        if ($Miner.ExecName -eq $null) {$Miner | Add-Member ExecName ([IO.FileInfo]($Miner.Path | Split-Path -Leaf -ErrorAction Ignore)).BaseName -Force}
        if ($Miner.FaultTolerance -eq $null) {$Miner | Add-Member FaultTolerance 0.1 -Force}               

        if (-not $Miner.API) {$Miner | Add-Member API "Miner" -Force}
    }

    if ($AllMiners.Count -gt 0) {
        $AllMinersUriHash = Get-MD5Hash $(@($AllMiners.URI | Select-Object -Unique | Sort-Object) -join ':')
    } else {
        $AllMinersUriHash = $null
    }
    if ($MinersUriHash -eq $null) {$MinersUriHash = $AllMinersUriHash}
    $Miners = $AllMiners | Where-Object {(Test-Path $_.Path) -and ((-not $_.PrerequisitePath) -or (Test-Path $_.PrerequisitePath))}
    if ( ($StartDownloader -or $MinersUriHash -ne $AllMinersUriHash -or $Miners.Count -ne $AllMiners.Count) -and $Downloader.State -ne "Running") {
        if ($StartDownloader) {
            Write-Log -Level Warn "User requested to start downloader. "
        }
        $Downloader = Start-Job -InitializationScript ([scriptblock]::Create("Set-Location('$(Get-Location)')")) -ArgumentList (@($AllMiners | Where-Object {$_.PrerequisitePath} | Select-Object @{name = "URI"; expression = {$_.PrerequisiteURI}}, @{name = "Path"; expression = {$_.PrerequisitePath}}, @{name = "Searchable"; expression = {$false}}) + @($AllMiners | Select-Object URI, Path, @{name = "Searchable"; expression = {$Miner = $_; ($AllMiners | Where-Object {(Split-Path $_.Path -Leaf) -eq (Split-Path $Miner.Path -Leaf) -and $_.URI -ne $Miner.URI}).Count -eq 0}}) | Select-Object * -Unique) -FilePath .\Downloader.ps1
        $StartDownloader = $false
        $MinersUriHash = $AllMinersUriHash
    }
    # Open firewall ports for all miners
    if (Get-Command "Get-MpPreference" -ErrorAction SilentlyContinue) {
        if ((Get-Command "Get-MpComputerStatus" -ErrorAction SilentlyContinue) -and (Get-MpComputerStatus -ErrorAction SilentlyContinue)) {
            if (Get-Command "Get-NetFirewallRule" -ErrorAction SilentlyContinue) {
                if ($MinerFirewalls -eq $null) {$MinerFirewalls = Get-NetFirewallApplicationFilter | Select-Object -ExpandProperty Program}
                if (@($AllMiners | Select-Object -ExpandProperty Path -Unique) | Compare-Object @($MinerFirewalls) | Where-Object SideIndicator -EQ "=>") {
                    Start-Process (@{desktop = "powershell"; core = "pwsh"}.$PSEdition) ("-Command Import-Module '$env:Windir\System32\WindowsPowerShell\v1.0\Modules\NetSecurity\NetSecurity.psd1'; ('$(@($AllMiners | Select-Object -ExpandProperty Path -Unique) | Compare-Object @($MinerFirewalls) | Where-Object SideIndicator -EQ '=>' | Select-Object -ExpandProperty InputObject | ConvertTo-Json -Compress)' | ConvertFrom-Json) | ForEach {New-NetFirewallRule -DisplayName 'RainbowMiner' -Program `$_}" -replace '"', '\"') -Verb runAs
                    $MinerFirewalls = $null
                }
            }
        }
    }

    #Remove miners with developer fee
    if ($Config.ExcludeMinersWithFee) {$Miners = $Miners | Where-Object {($_.DevFee.PSObject.Properties.Value | Foreach-Object {[Double]$_} | Measure-Object -Sum).Sum -eq 0}}

    #Apply watchdog to miners
    $Miners = $Miners | Where-Object {
        $Miner = $_
        $Miner_WatchdogTimers = $WatchdogTimers | Where-Object MinerName -EQ $Miner.Name | Where-Object Kicked -LT $Timer.AddSeconds( - $WatchdogInterval) | Where-Object Kicked -GT $Timer.AddSeconds( - $WatchdogReset)
        ($Miner_WatchdogTimers | Measure-Object | Select-Object -ExpandProperty Count) -lt <#stage#>2 -and ($Miner_WatchdogTimers | Where-Object {$Miner.HashRates.PSObject.Properties.Name -contains $_.Algorithm} | Measure-Object | Select-Object -ExpandProperty Count) -lt <#stage#>1
    }

    #Give API access to the miners information
    $API.Miners = $Miners

    #Use only use fastest miner per algo and device index. E.g. if there are 2 miners available to mine the same algo, only the faster of the two will ever be used, the slower ones will also be hidden in the summary screen
    if ($Config.FastestMinerOnly) {$Miners = $Miners | Sort-Object -Descending {"$($_.DeviceName -join '')$($_.BaseAlgorithm -join '')$(if($_.HashRates.PSObject.Properties.Value -eq $null) {$_.Name})"}, {($_ | Where-Object Profit -EQ $null | Measure-Object).Count}, {([Double]($_ | Measure-Object Profit_Bias -Sum).Sum)}, {($_ | Where-Object Profit -NE 0 | Measure-Object).Count} | Group-Object {"$($_.DeviceName -join '')$($_.BaseAlgorithm -join '')$(if($_.HashRates.PSObject.Properties.Value -eq $null) {$_.Name})"} | Foreach-Object {$_.Group[0]}}
 
    #Give API access to the fasted miners information
    $API.FastestMiners = $Miners

    #Update the active miners
    if ($Miners.Count -eq 0) {
        Write-Log -Level Warn "No miners available. "
        if ($Downloader) {$Downloader | Receive-Job}
        Start-Sleep $Config.Interval
        continue
    }

    $ActiveMiners | ForEach-Object {
        $_.Profit = 0
        $_.Profit_Comparison = 0
        $_.Profit_MarginOfError = 0
        $_.Profit_Bias = 0
        $_.Profit_Unbias = 0
        $_.Best = $false
        $_.Best_Comparison = $false
    }
    $Miners | ForEach-Object {
        $Miner = $_
        $ActiveMiner = $ActiveMiners | Where-Object {
            $_.Name -eq $Miner.Name -and 
            $_.Path -eq $Miner.Path -and 
            $_.Arguments -eq $Miner.Arguments -and 
            $_.API -eq $Miner.API -and 
            $_.Port -eq $Miner.Port -and
            (Compare-Object $_.Algorithm ($Miner.HashRates | Get-Member -MemberType NoteProperty | Select-Object -ExpandProperty Name) | Measure-Object).Count -eq 0
        }
        if ($ActiveMiner) {
            $ActiveMiner.Profit = $Miner.Profit
            $ActiveMiner.Profit_Comparison = $Miner.Profit_Comparison
            $ActiveMiner.Profit_MarginOfError = $Miner.Profit_MarginOfError
            $ActiveMiner.Profit_Bias = $Miner.Profit_Bias
            $ActiveMiner.Profit_Unbias = $Miner.Profit_Unbias
            $ActiveMiner.Speed = $Miner.HashRates.PSObject.Properties.Value #temp fix, must use 'PSObject.Properties' to preserve order
            $ActiveMiner.DeviceName = $Miner.DeviceName
            $ActiveMiner.DeviceModel = $Miner.DeviceModel
            $ActiveMiner.DevFee = $Miner.DevFee
            $ActiveMiner.MSIAprofile = $Miner.MSIAprofile
            $ActiveMiner.FaultTolerance = $Miner.FaultTolerance
        }
        else {
            $ActiveMiners += New-Object $Miner.API -Property @{
                Name                 = $Miner.Name
                BaseName             = $Miner.BaseName
                Path                 = $Miner.Path
                Arguments            = $Miner.Arguments
                API                  = $Miner.API
                Port                 = $Miner.Port
                Algorithm            = $Miner.HashRates.PSObject.Properties.Name #temp fix, must use 'PSObject.Properties' to preserve order
                BaseAlgorithm        = $Miner.BaseAlgorithm
                DeviceName           = $Miner.DeviceName
                DeviceModel          = $Miner.DeviceModel
                Profit               = $Miner.Profit
                Profit_Comparison    = $Miner.Profit_Comparison
                Profit_MarginOfError = $Miner.Profit_MarginOfError
                Profit_Bias          = $Miner.Profit_Bias
                Profit_Unbias        = $Miner.Profit_Unbias
                Speed                = $Miner.HashRates.PSObject.Properties.Value #temp fix, must use 'PSObject.Properties' to preserve order
                Speed_Live           = 0
                Best                 = $false
                Best_Comparison      = $false
                New                  = $false
                Benchmarked          = 0
                Pool                 = $Miner.Pools.PSObject.Properties.Value.Name
                MSIAprofile          = $Miner.MSIAprofile
                ExtendInterval       = $Miner.ExtendInterval
                ShowMinerWindow      = ($Miner.ShowMinerWindow -or $Config.ShowMinerWindow)
                DevFee               = $Miner.DevFee
                ExecName             = $Miner.ExecName
                FaultTolerance       = $Miner.FaultTolerance
            }
        }
    }

    #Don't penalize active miners
    if ($SkipSwitchingPrevention) {
        $SkipSwitchingPrevention = $false
        $ActiveMiners | ForEach-Object {$_.Profit_Bias = $_.Profit_Unbias}
    } else {
        $ActiveMiners | Where-Object {$_.GetStatus() -eq [MinerStatus]::Running} | ForEach-Object {$_.Profit_Bias = $_.Profit_Unbias}
    }

    #Get most profitable miner combination i.e. AMD+NVIDIA+CPU
    $BestMiners = $ActiveMiners | Select-Object DeviceName -Unique | ForEach-Object {$Miner_GPU = $_; ($ActiveMiners | Where-Object {(Compare-Object $Miner_GPU.DeviceName $_.DeviceName | Measure-Object).Count -eq 0} | Sort-Object -Descending {($_ | Where-Object Profit -EQ $null | Measure-Object).Count}, {($_ | Measure-Object Profit_Bias -Sum).Sum}, {($_ | Where-Object Profit -NE 0 | Measure-Object).Count}, {$_.Benchmarked}, {$_.ExtendInterval} | Select-Object -First 1)}
    $BestMiners_Comparison = $ActiveMiners | Select-Object DeviceName -Unique | ForEach-Object {$Miner_GPU = $_; ($ActiveMiners | Where-Object {(Compare-Object $Miner_GPU.DeviceName $_.DeviceName | Measure-Object).Count -eq 0} | Sort-Object -Descending {($_ | Where-Object Profit -EQ $null | Measure-Object).Count}, {($_ | Measure-Object Profit_Comparison -Sum).Sum}, {($_ | Where-Object Profit -NE 0 | Measure-Object).Count}, {$_.Benchmarked}, {$_.ExtendInterval} | Select-Object -First 1)}
    $Miners_Device_Combos = (Get-Combination ($ActiveMiners | Select-Object DeviceName -Unique) | Where-Object {(Compare-Object ($_.Combination | Select-Object -ExpandProperty DeviceName -Unique) ($_.Combination | Select-Object -ExpandProperty DeviceName) | Measure-Object).Count -eq 0})
    $BestMiners_Combos = $Miners_Device_Combos | ForEach-Object {
        $Miner_Device_Combo = $_.Combination
        [PSCustomObject]@{
            Combination = $Miner_Device_Combo | ForEach-Object {
                $Miner_Device_Count = $_.DeviceName.Count
                [Regex]$Miner_Device_Regex = "^(" + (($_.DeviceName | ForEach-Object {[Regex]::Escape($_)}) -join '|') + ")$"
                $BestMiners | Where-Object {([Array]$_.DeviceName -notmatch $Miner_Device_Regex).Count -eq 0 -and ([Array]$_.DeviceName -match $Miner_Device_Regex).Count -eq $Miner_Device_Count}
            }
        }
    }
    $BestMiners_Combos_Comparison = $Miners_Device_Combos | ForEach-Object {
        $Miner_Device_Combo = $_.Combination
        [PSCustomObject]@{
            Combination = $Miner_Device_Combo | ForEach-Object {
                $Miner_Device_Count = $_.DeviceName.Count
                [Regex]$Miner_Device_Regex = "^(" + (($_.DeviceName | ForEach-Object {[Regex]::Escape($_)}) -join '|') + ")$"
                $BestMiners_Comparison | Where-Object {([Array]$_.DeviceName -notmatch $Miner_Device_Regex).Count -eq 0 -and ([Array]$_.DeviceName -match $Miner_Device_Regex).Count -eq $Miner_Device_Count}
            }
        }
    }
    $BestMiners_Combo = $BestMiners_Combos | Sort-Object -Descending {($_.Combination | Where-Object Profit -EQ $null | Measure-Object).Count}, {($_.Combination | Measure-Object Profit_Bias -Sum).Sum}, {($_.Combination | Where-Object Profit -NE 0 | Measure-Object).Count} | Select-Object -First 1 | Select-Object -ExpandProperty Combination
    $BestMiners_Combo_Comparison = $BestMiners_Combos_Comparison | Sort-Object -Descending {($_.Combination | Where-Object Profit -EQ $null | Measure-Object).Count}, {($_.Combination | Measure-Object Profit_Comparison -Sum).Sum}, {($_.Combination | Where-Object Profit -NE 0 | Measure-Object).Count} | Select-Object -First 1 | Select-Object -ExpandProperty Combination
    if (-not $PauseMiners) {
        $BestMiners_Combo | ForEach-Object {$_.Best = $true}
        $BestMiners_Combo_Comparison | ForEach-Object {$_.Best_Comparison = $true}
    }

    #Stop or start miners in the active list depending on if they are the most profitable
    $ActiveMiners | Where-Object {$_.GetActivateCount() -GT 0} | Where-Object {($_.Best -EQ $false) -or $RestartMiners} | ForEach-Object {
        $Miner = $_

        if ($Miner.GetStatus() -eq [MinerStatus]::Running) {
            Write-Log "Stopping miner ($($Miner.Name)). "
            $Miner.SetStatus([MinerStatus]::Idle)

            #Remove watchdog timer
            $Miner_Name = $Miner.Name
            $Miner.Algorithm | ForEach-Object {
                $Miner_Algorithm = $_
                $WatchdogTimer = $WatchdogTimers | Where-Object {$_.MinerName -eq $Miner_Name -and $_.PoolName -eq $Pools.$Miner_Algorithm.Name -and $_.Algorithm -eq $Miner_Algorithm}
                if ($WatchdogTimer) {
                    if (($WatchdogTimer.Kicked -lt $Timer.AddSeconds( - $WatchdogInterval)) -and -not $RestartMiners) {
                        $Miner.SetStatus([MinerStatus]::Failed)
                    }
                    else {
                        $WatchdogTimers = $WatchdogTimers -notmatch $WatchdogTimer
                    }
                }
            }
        }
    }

    if (($ActiveMiners | ForEach-Object {$_.GetProcessNames()} | Measure-Object).Count -gt 0) {
        $Running = @($ActiveMiners | Where-Object Best -EQ $true | Foreach-Object {if ($_.GetStatus() -eq [MinerStatus]::Running -and $_.GetProcessId() -gt 0) {$_.GetProcessId()}})
        Get-Process | Where-Object {@($ActiveMiners | Foreach-Object {$_.GetExecNames()}) -contains $_.ProcessName} | Select-Object -ExpandProperty ProcessName | Compare-Object @($ActiveMiners | Where-Object Best -EQ $true | Where-Object {$_.GetStatus() -eq [MinerStatus]::Running} | ForEach-Object {$_.GetExecNames()}) | Where-Object SideIndicator -EQ "=>" | Select-Object -ExpandProperty InputObject | Select-Object -Unique | ForEach-Object {Get-Process -Name $_ -ErrorAction Ignore | Where-Object {$Running -notcontains $_.Id} | ForEach-Object {Write-Warning "Stop-Process $($_.ProcessName) with Id $($_.Id)"; Stop-Process -Id $_.Id -Force -ErrorAction Ignore}}
    }
    if ($Downloader) {$Downloader | Receive-Job}
    Start-Sleep $Config.Delay #Wait to prevent BSOD

    $ActiveMiners | Where-Object Best -EQ $true | ForEach-Object {
        if ($_.GetStatus() -ne [MinerStatus]::Running) {

            #Set MSI Afterburner profile
            if ($MSIAenabled) {
                $MSIAplannedprofile = $ActiveMiners | Where-Object {$_.Best -eq $true -and $_.MSIAprofile -ne $null -and $_.MSIAprofile -gt 0} | Select-Object -ExpandProperty MSIAprofile -Unique
                if (-not $MSIAplannedprofile.Count) {$MSIAplannedprofile = $Config.MSIAprofile}                
                else {$MSIAplannedprofile = $MSIAplannedprofile | Select-Object -Index 0}
                Start-Process -FilePath "$($Config.MSIApath)" -ArgumentList "-Profile$($MSIAplannedprofile)" -Verb RunAs
                if ( $MSIAplannedprofile -ne $MSIAcurrentprofile ) {
                    Write-Log "New MSI Afterburner profile set: $($MSIAplannedprofile)"                
                    $MSIAcurrentprofile = $MSIAplannedprofile
                    Start-Sleep 1
                }
            }
            if ($_.Speed -contains $null) {
                Write-Log "Benchmarking miner ($($_.Name)): '$($_.Path) $($_.Arguments)' (Extend Interval $($_.ExtendInterval))"
            }
            else {
                Write-Log "Starting miner ($($_.Name)): '$($_.Path) $($_.Arguments)'"
            }            
            $DecayStart = $Timer
            $_.SetStatus([MinerStatus]::Running)

            #Add watchdog timer
            if ($Config.Watchdog -and $_.Profit -ne $null) {
                $Miner_Name = $_.Name
                $Miner_DeviceModel = $_.DeviceModel
                $_.Algorithm | ForEach-Object {
                    $Miner_Algorithm = $_
                    $WatchdogTimer = $WatchdogTimers | Where-Object {$_.MinerName -eq $Miner_Name -and $_.PoolName -eq $Pools.$Miner_Algorithm.Name -and $_.Algorithm -eq $Miner_Algorithm}
                    if (-not $WatchdogTimer) {
                        $WatchdogTimers += [PSCustomObject]@{
                            MinerName = $Miner_Name
                            DeviceModel= $Miner_DeviceModel
                            PoolName  = $Pools.$Miner_Algorithm.Name
                            Algorithm = $Miner_Algorithm
                            Kicked    = $Timer
                        }
                    }
                    elseif (-not ($WatchdogTimer.Kicked -GT $Timer.AddSeconds( - $WatchdogReset))) {
                        $WatchdogTimer.Kicked = $Timer
                    }
                }
            }
        }
    }

    if ($Config.MinerStatusURL -and $Config.MinerStatusKey) {& .\ReportStatus.ps1 -Key $Config.MinerStatusKey -WorkerName $Config.WorkerName -ActiveMiners $ActiveMiners -MinerStatusURL $Config.MinerStatusURL}

    Clear-Host

    #Get count of miners, that need to be benchmarked. If greater than 0, the UIstyle "full" will be used    
    $MinersNeedingBenchmark = @($Miners | Where-Object {$_.HashRates.PSObject.Properties.Value -contains $null})
    $API.MinersNeedingBenchmark = $MinersNeedingBenchmark
    $LimitMiners = if ( $Config.UIstyle -eq "full" -or $MinersNeedingBenchmark.Count -gt 0 ) {100} else {3}

    #Display mining information
    $Miners | Select-Object DeviceName, DeviceModel -Unique | Sort-Object DeviceModel | ForEach-Object {
        $Miner_DeviceName = $_.DeviceName
        $Miner_DeviceModel = $_.DeviceModel
        $Miner_DeviceTitle = @($Devices | Where-Object {$Miner_DeviceName -icontains $_.Name} | Select-Object -ExpandProperty Model_Name -Unique | Sort-Object | Foreach-Object {"$($_) ($(@($Devices | Where-Object Model_Name -eq $_ | Select-Object -ExpandProperty Name | Sort-Object) -join ','))"}) -join ', '
        Write-Host $Miner_DeviceTitle
        Write-Host $("=" * $Miner_DeviceTitle.Length)

        $Miners | Where-Object {$_.DeviceModel -eq $Miner_DeviceModel} | Where-Object {$_.Profit -ge 1E-5 -or $_.Profit -eq $null} | Sort-Object DeviceModel, @{Expression = {if ($MinersNeedingBenchmark.Count -gt 0) {$_.HashRates.PSObject.Properties.Name}}}, @{Expression = {if ($MinersNeedingBenchmark.Count -gt 0) {$_.Profit}}; Descending = $true}, @{Expression = {if ($MinersNeedingBenchmark.Count -lt 1) {[double]$_.Profit_Bias}}; Descending = $true} | Select-Object -First $($LimitMiners) | Format-Table (
            @{Label = "Miner"; Expression = {$_.Name -split '-' | Select-Object -Index 0}},
            @{Label = "Algorithm"; Expression = {$_.HashRates.PSObject.Properties.Name}}, 
            @{Label = "Speed"; Expression = {$_.HashRates.PSObject.Properties.Value | ForEach-Object {if ($_ -ne $null) {"$($_ | ConvertTo-Hash)/s"}else {"Benchmarking"}}}; Align = 'right'}, 
            @{Label = "$($Config.Currency | Select-Object -Index 0)/Day"; Expression = {if ($_.Profit) {ConvertTo-LocalCurrency $($_.Profit) $($Rates.$($Config.Currency | Select-Object -Index 0)) -Offset 2} else {"Unknown"}}; Align = "right"},
            @{Label = "Accuracy"; Expression = {$_.Pools.PSObject.Properties.Value.MarginOfError | ForEach-Object {(1 - $_).ToString("P0")}}; Align = 'right'}, 
            @{Label = "Fee"; Expression = {$_.DevFee.PSObject.Properties.Value | ForEach-Object {if ($_) {($_/100).ToString("P0")}else {"-"}}}; Align = 'right'}, 
            @{Label = "Pool"; Expression = {$_.Pools.PSObject.Properties.Value | ForEach-Object {"$($_.Name)$(if ($_.CoinName) {"-$($_.CoinName)"})"}}}
        ) | Out-Host
    }

    if ($RestartMiners) {
        Write-Host "Miners have been restarted!" -ForegroundColor Yellow
        Write-Host " "
        $RestartMiners = $false
    }
    if ($PauseMiners) {
        Write-Host -NoNewline "Status: "
        Write-Host -NoNewLine "PAUSED" -ForegroundColor Red
        Write-Host " (press P to resume)"
        Write-Host " "
    } else {
        #Display benchmarking progres
        if ($MinersNeedingBenchmark.Count -gt 0) {
            Write-Log -Level Warn "Benchmarking in progress: $($MinersNeedingBenchmark.Count) miner$(if ($MinersNeedingBenchmark.Count -gt 1){'s'}) left to benchmark."
        }
    }

    #Check for updated RainbowMiner
    Confirm-Version $Version

    #Display active miners list
    $ActiveMiners | Where-Object {$_.GetActivateCount() -GT 0 -and ($Config.UIstyle -eq "full" -or $MinersNeedingBenchmark.Count -gt 0 -or $_.GetStatus() -eq [MinerStatus]::Running)} | Sort-Object -Property @{Expression = {$_.GetStatus()}; Descending = $False}, @{Expression = {$_.GetActiveLast()}; Descending = $True} | Select-Object -First (1 + 6 + 6) | Format-Table -GroupBy @{Label = "Status"; Expression = {$_.GetStatus()}} -Wrap (
        @{Label = "Last Speed"; Expression = {$_.Speed_Live | ForEach-Object {"$($_ | ConvertTo-Hash)/s"}}; Align = 'right'}, 
        @{Label = "Active"; Expression = {"{0:dd} Days {0:hh} Hours {0:mm} Minutes" -f $_.GetActiveTime()}}, 
        @{Label = "Launched"; Expression = {Switch ($_.GetActivateCount()) {0 {"Never"} 1 {"Once"} Default {"$_ Times"}}}},      
        @{Label = "Miner"; Expression = {@($_.Name -split '-') | Select-Object -Index 0}},
        @{Label = "Device"; Expression = {@(Get-DeviceModelName $Devices -Name @($_.DeviceName) -Short) -join ','}}, 
        @{Label = "Command"; Expression = {"$($_.Path.TrimStart((Convert-Path ".\"))) $($_.Arguments)"}}
    ) | Out-Host

    if ( $Config.UIstyle -eq "full" -or $MinersNeedingBenchmark.Count -gt 0 ) {
        #Display watchdog timers
        $WatchdogTimers | Where-Object Kicked -gt $Timer.AddSeconds( - $WatchdogReset) | Format-Table -Wrap (
            @{Label = "Miner"; Expression = {@($_.MinerName -split '-') | Select-Object -Index 0}},
            @{Label = "Device"; Expression = {@(Get-DeviceModelName $Devices -Name @($_.DeviceName) -Short) -join ','}}, 
            @{Label = "Pool"; Expression = {$_.PoolName}}, 
            @{Label = "Algorithm"; Expression = {$_.Algorithm}}, 
            @{Label = "Watchdog Timer"; Expression = {"{0:n0} Seconds" -f ($Timer - $_.Kicked | Select-Object -ExpandProperty TotalSeconds)}; Align = 'right'}
        ) | Out-Host
    }

    #Display profit comparison
    if ($Downloader.State -eq "Running") {$Downloader | Wait-Job -Timeout 10 | Out-Null}
    if (($BestMiners_Combo | Where-Object Profit -EQ $null | Measure-Object).Count -eq 0 -and $Downloader.State -ne "Running") {
        $MinerComparisons = 
        [PSCustomObject]@{"Miner" = "RainbowMiner"}, 
        [PSCustomObject]@{"Miner" = $BestMiners_Combo_Comparison | ForEach-Object {"$($_.Name -split '-' | Select-Object -Index 0)-$($_.Algorithm -join '/')"}}

        $BestMiners_Combo_Stat = Set-Stat -Name "Profit" -Value ($BestMiners_Combo | Measure-Object Profit -Sum).Sum -Duration $StatSpan

        $MinerComparisons_Profit = $BestMiners_Combo_Stat.Week, ($BestMiners_Combo_Comparison | Measure-Object Profit_Comparison -Sum).Sum

        $MinerComparisons_MarginOfError = $BestMiners_Combo_Stat.Week_Fluctuation, ($BestMiners_Combo_Comparison | ForEach-Object {$_.Profit_MarginOfError * (& {if ($MinerComparisons_Profit[1]) {$_.Profit_Comparison / $MinerComparisons_Profit[1]}else {1}})} | Measure-Object -Sum).Sum

        $Config.Currency | ForEach-Object {
            $MinerComparisons[0] | Add-Member $_.ToUpper() ("{0:N5} $([Char]0x00B1){1:P0} ({2:N5}-{3:N5})" -f ($MinerComparisons_Profit[0] * $Rates.$_), $MinerComparisons_MarginOfError[0], (($MinerComparisons_Profit[0] * $Rates.$_) / (1 + $MinerComparisons_MarginOfError[0])), (($MinerComparisons_Profit[0] * $Rates.$_) * (1 + $MinerComparisons_MarginOfError[0])))
            $MinerComparisons[1] | Add-Member $_.ToUpper() ("{0:N5} $([Char]0x00B1){1:P0} ({2:N5}-{3:N5})" -f ($MinerComparisons_Profit[1] * $Rates.$_), $MinerComparisons_MarginOfError[1], (($MinerComparisons_Profit[1] * $Rates.$_) / (1 + $MinerComparisons_MarginOfError[1])), (($MinerComparisons_Profit[1] * $Rates.$_) * (1 + $MinerComparisons_MarginOfError[1])))
        }

        if ( $Config.UIstyle -eq "full" -or $MinersNeedingBenchmark.Count -gt 0 ) {
            if ([Math]::Round(($MinerComparisons_Profit[0] - $MinerComparisons_Profit[1]) / $MinerComparisons_Profit[1], 2) -gt 0) {
                $MinerComparisons_Range = ($MinerComparisons_MarginOfError | Measure-Object -Average | Select-Object -ExpandProperty Average), (($MinerComparisons_Profit[0] - $MinerComparisons_Profit[1]) / $MinerComparisons_Profit[1]) | Measure-Object -Minimum | Select-Object -ExpandProperty Minimum
                Write-Host -BackgroundColor Yellow -ForegroundColor Black "RainbowMiner is between $([Math]::Round((((($MinerComparisons_Profit[0]-$MinerComparisons_Profit[1])/$MinerComparisons_Profit[1])-$MinerComparisons_Range)*100)))% and $([Math]::Round((((($MinerComparisons_Profit[0]-$MinerComparisons_Profit[1])/$MinerComparisons_Profit[1])+$MinerComparisons_Range)*100)))% more profitable than the fastest miner: "
            }

            $MinerComparisons | Out-Host
        }
    }

    #Display pool balances, formatting it to show all the user specified currencies
    if ($Config.ShowPoolBalances) {
        $NextBalances = 10-[int]((Get-Date).ToUniversalTime()-$LastBalances).TotalMinutes
        $NextBalances = if ($NextBalances -gt 0){"in $($NextBalances) minutes"}else{"now"}
        Write-Host "Pool Balances as of $([System.Timezone]::CurrentTimeZone.ToLocalTime($LastBalances)) (next update $($NextBalances)): "
        $Balances | Format-Table Name, Total_*
    }

    #Display exchange rates
    if ($Config.Currency | Where-Object {$_ -ne "BTC" -and $NewRates.$_}) {Write-Host "Exchange rates: 1 BTC = $(($Config.Currency | Where-Object {$_ -ne "BTC" -and $NewRates.$_} | ForEach-Object { "$($_) $($NewRates.$_)"})  -join ' = ')"}

    #Give API access to WatchdogTimers information
    $API.WatchdogTimers = $WatchdogTimers

    #Update API miner information
    $API.ActiveMiners = $ActiveMiners
    $API.RunningMiners = $RunningMiners = $ActiveMiners | Where-Object {$_.GetStatus() -eq [MinerStatus]::Running} | Foreach-Object {$_ | Add-Member ActiveTime $_.GetActiveTime() -Force -PassThru}
    $API.FailedMiners = $ActiveMiners | Where-Object {$_.GetStatus() -eq [MinerStatus]::Failed}

    #Reduce Memory
    Get-Job -State Completed | Remove-Job
    [GC]::Collect()

    #Extend benchmarking interval to the maximum from running miners    
    $ExtendInterval = (@(1) + [int[]]@($RunningMiners | Where-Object {$_.Speed -eq $null} | Select-Object -ExpandProperty ExtendInterval) | Measure-Object -Maximum).Maximum
    if ($ExtendInterval -gt 1) {
        $StatEnd = $StatEnd.AddSeconds($Config.Interval * $ExtendInterval)
        $StatSpan = New-TimeSpan $StatStart $StatEnd
        $WatchdogInterval = ($WatchdogInterval / $Strikes * ($Strikes - 1)) + $StatSpan.TotalSeconds
        $WatchdogReset = ($WatchdogReset / ($Strikes * $Strikes * $Strikes) * (($Strikes * $Strikes * $Strikes) - 1)) + $StatSpan.TotalSeconds
        Write-Log "Benchmarking watchdog sensitive algorithm or miner. Increasing interval time temporarily to $($ExtendInterval)x interval ($($Config.Interval * $ExtendInterval) seconds). "
    }
    
    #Do nothing for a few seconds as to not overload the APIs and display miner download status
    $Stopp = $false
    Write-Log "Start waiting before next run. "

    $Host.UI.RawUI.FlushInputBuffer()

    $cursorPosition = $host.UI.RawUI.CursorPosition
    Write-Host -NoNewline "Waiting for next run: E[x]it Miningscript, [S]kip switching prevention, start [D]ownloader, [C]onfiguration"
    if ( $Config.UIstyle -eq "full" ) { Write-Host -NoNewline ", [V]erbose off" } else { Write-Host -NoNewline ", [V]erbose" }
    if ( $PauseMiners ) { Write-Host -NoNewline ", [P]ause off" } else { Write-Host -NoNewline ", [P]ause" }
    Write-Host " "
    if ( $ShowTimer ) { $cursorPosition = $host.UI.RawUI.CursorPosition }

    $keyPressed = $false
    $TimerBackup = $Timer
    $WaitTimer = (Get-Date).ToUniversalTime()
    $WaitTotalSeconds = [int](($StatEnd - $WaitTimer).TotalSeconds / 2 + 0.5)
    $WaitMaxI = $Strikes*5
    for ($i = $WaitMaxI; -not $keyPressed -and -not $SkipSwitchingPrevention -and -not $StartDownloader -and -not $Stopp -and (($i -ge 0) -or ($Timer -lt $StatEnd)); $i--) {

        if ( $ShowTimer ) {
            $host.UI.RawUI.CursorPosition = $CursorPosition
    
            if ( $WaitTotalSeconds -gt $WaitMaxI ) {
                $WaitRmgSeconds = [int](($StatEnd - $WaitTimer).TotalSeconds / 2 + 0.5)
                if ( $WaitRmgSeconds -gt $WaitTotalSeconds ) {$WaitRmgSeconds = $WaitTotalSeconds}
                Write-Host -NoNewline "[$("*" * ($WaitTotalSeconds - $WaitRmgSeconds))$("." * $WaitRmgSeconds)]"
            } else {
                Write-Host -NoNewline "[$("*" * ($WaitMaxI - $i))$("." * $i)]"
            }
        }

        if ( ($WaitMaxI-$i) % 5 -eq 0 ) {
            #get data from downloader every ten seconds, starting at once
            if ($Downloader) {$Downloader | Receive-Job}
        }

        Start-Sleep 2

        if ( ($WaitMaxI-$i+1) % 5 -eq 0 ) {
            #pick up a sample every ten seconds, starting after ten seconds
            $ActiveMiners | ForEach-Object {
                $Miner = $_
                $Miner.UpdateMinerData() > $null # | ForEach-Object {Write-Log -Level Verbose "$($Miner.Name): $_"}
            
                if ($Miner.Speed -contains $null) {
                    $Miner.Algorithm | ForEach-Object {
                        $HashRate_Name = $_
                        $Miner.Data | Where-Object {$_.HashRate.PSObject.Properties.Value} | Sort-Object -Unique | Foreach-Object {
                            Write-Log -Level Verbose (("Benchmarking $($Miner.Name) $($HashRate_Name): $($Miner.Data.HashRate.$HashRate_Name | Select-Object -last 10 | ForEach-Object {$_ | ConvertTo-Hash}) (Avg: $(($Miner.Data.HashRate.$HashRate_Name | ForEach-Object {$_} | Measure-Object -Average | Select-Object -ExpandProperty Average) | ConvertTo-Hash)) (ExtendInterval $($Miner.ExtendInterval))") -replace "\s+", " ")
                        }
                    }
                }
            }
        }

        $Timer = (Get-Date).ToUniversalTime()
        if ( $Timer -le $TimerBackup ) {
            Test-TimeSync
            $Timer = (Get-Date).ToUniversalTime()
        }
        $WaitTimer = $Timer
        $keyPressedValue = $false

        if ((Test-Path ".\stopp.txt") -or $API.Stop) {$keyPressedValue = "X"}
        elseif ($API.Pause -ne $PauseMiners) {$keyPressedValue = "P"}
        elseif ([console]::KeyAvailable) {$keyPressedValue = $([System.Console]::ReadKey($true)).key}

        if ($keyPressedValue) {
            switch ($keyPressedValue) {
                "K" { 
                    $SkipSwitchingPrevention = $true
                    $host.UI.RawUI.CursorPosition = $CursorPosition
                    Write-Log "User requests to skip switching prevention. "
                    Write-Host -NoNewline "[K] pressed - skip switching prevention in next run. "
                    $keyPressed = $true
                }
                "X" {
                    $Stopp = $true
                    $host.UI.RawUI.CursorPosition = $CursorPosition
                    Write-Log "User requests to stop script. "
                    Write-Host -NoNewline "[X] pressed - stopping script. Type 'exit' and press enter to close powershell-window."
                    $keyPressed = $true
                }
                "D" {
                    $StartDownloader = $true
                    $host.UI.RawUI.CursorPosition = $CursorPosition
                    Write-Log "User requests to start downloader. "
                    Write-Host -NoNewline "[D] pressed - starting downloader in next run. "
                    $keyPressed = $true
                }
                "V" {
                    $Config.UIstyle = if ( $Config.UIstyle -eq "full" ) {"lite"} else {"full"}
                    Write-Host -NoNewline "[V] pressed - UI will be set to $($Config.UIstyle) in next run. "
                    $keyPressed = $true
                }
                "P" {
                    $PauseMiners = -not $PauseMiners
                    $API.Pause = $PauseMiners
                    Write-Host -NoNewline "[P] pressed - miner script will be $(if ($PauseMiners) {"PAUSED"} else {"RESTARTED"})"
                    $keyPressed = $true
                }
                "C" {
                    $RunSetup = $true
                    Write-Host -NoNewline "[C] pressed - configuration setup will be started"
                    $keyPressed = $true
                }
            }
        }
    }

    if (-not $keyPressed) {
        $host.UI.RawUI.CursorPosition = $CursorPosition
        Write-Log "Finish waiting before next run. "
        Write-Host -NoNewline "Finished waiting - starting next run "
    }

    Write-Host (" " * 100)

    #Save current hash rates
    Write-Log "Saving hash rates. "
    $ActiveMiners | ForEach-Object {
        $Miner = $_
        $Miner.Speed_Live = [Double[]]@()

        if ($Miner.New) {$Miner.New = [Boolean]($Miner.Algorithm | Where-Object {-not (Get-Stat -Name "$($Miner.Name)_$($_)_HashRate")})}

        if ($Miner.New) {$Miner.Benchmarked++}

        if ($Miner.GetStatus() -eq "Running" -or $Miner.New) {
            $Miner.Algorithm | ForEach-Object {
                $Miner_Speed = $Miner.GetHashRate($_, $Config.Interval * $ExtendInterval, $Miner.New)
                $Miner.Speed_Live += [Double]$Miner_Speed

                if ($Miner.New -and (-not $Miner_Speed)) {$Miner_Speed = $Miner.GetHashRate($_, ($Config.Interval * $Miner.Benchmarked * $ExtendInterval), ($Miner.Benchmarked -lt $Strikes))}

                if ((-not $Miner.New) -or $Miner_Speed -or $Miner.Benchmarked -ge ($Strikes * $Strikes) -or $Miner.GetActivateCount() -ge $Strikes) {
                    $Stat = Set-Stat -Name "$($Miner.Name)_$($_)_HashRate" -Value $Miner_Speed -Duration $StatSpan -FaultDetection $true -FaultTolerance $Miner.FaultTolerance
                }

                #Update watchdog timer
                $Miner_Name = $Miner.Name
                $Miner_Algorithm = $_
                $WatchdogTimer = $WatchdogTimers | Where-Object {$_.MinerName -eq $Miner_Name -and $_.PoolName -eq $Pools.$Miner_Algorithm.Name -and $_.Algorithm -eq $Miner_Algorithm}
                if ($Stat -and $WatchdogTimer -and $Stat.Updated -gt $WatchdogTimer.Kicked) {
                    $WatchdogTimer.Kicked = $Stat.Updated
                }
            }
        }
    }

    if ( $Stopp ) {
        break
    } else {
        Write-Log "Starting next run..."
    }    
}

[console]::TreatControlCAsInput = $false

#Stop the API, if still running
Stop-APIServer
Stop-AsyncLoader

Remove-Item ".\stopp.txt" -Force -ErrorAction Ignore
Write-Log "Gracefully halting RainbowMiner"
$ActiveMiners | Where-Object {$_.GetActivateCount() -gt 0} | ForEach-Object {
    $Miner = $_
    if ($Miner.GetStatus() -eq [MinerStatus]::Running) {
        Write-Log "Closing $($Miner.Type) miner $($Miner.Name)"
        $Miner.StopMining()            
    }
}
 
#Stop the log
Stop-Transcript
