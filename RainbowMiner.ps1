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
    [Int]$Interval = 60, #seconds before reading hash rate from miners
    [Parameter(Mandatory = $false)]
    [Int]$API_ID = 0, 
    [Parameter(Mandatory = $false)]
    [String]$API_Key = "", 
    [Parameter(Mandatory = $false)]
    [Alias("Location")]
    [String]$Region = "europe", #europe/us/asia
    [Parameter(Mandatory = $false)]
    [Switch]$SSL = $false, 
    [Parameter(Mandatory = $false)]
    [Alias("Device", "Type")]
    [Array]$DeviceName = @(), #i.e. CPU, GPU, GPU#02, AMD, NVIDIA, AMD#02, OpenCL#03#02 etc.
    [Parameter(Mandatory = $false)]
    [Array]$Algorithm = @(), #i.e. Ethash,Equihash,CryptoNight etc.
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
    [String]$MinerStatusKey = "",
    [Parameter(Mandatory = $false)]
    [Double]$SwitchingPrevention = 2, #zero does not prevent miners switching
    [Parameter(Mandatory = $false)]
    [Switch]$ShowMinerWindow = $false, #if true all miner windows will be visible (they can steal focus)
    [Parameter(Mandatory = $false)]
    [Switch]$FastestMinerOnly = $false, #Use only use fastest miner per algo and device index. E.g. if there are 2 miners available to mine the same algo, only the faster of the two will ever be used, the slower ones will also be hidden in the summary screen
    [Parameter(Mandatory = $false)]
    [Switch]$DisableAutoUpdate = $false,
    [Parameter(Mandatory = $false)]
    [Switch]$ShowPoolBalances = $false,
    [Parameter(Mandatory = $false)]
    [Switch]$IgnoreFees = $false,    
    [Parameter(Mandatory = $false)]
    [String]$ConfigFile = "Config\config.txt", # Path to config file
    [Parameter(Mandatory = $false)]
    [Switch]$RebootOnGPUFailure = $false, # if set to $true, and a GPU fails, the mining rig will be restarted
    [Parameter(Mandatory = $false)]
    [String]$MiningMode = "device", # set to "legacy","device","combo"
    [Parameter(Mandatory = $false)]
    [String]$MSIApath = "c:\Program Files (x86)\MSI Afterburner\MSIAfterburner.exe", # installation path of MSI Afterburner
    [Parameter(Mandatory = $false)]
    [Int]$MSIAprofile = 2, # default MSI Afterburner profile to be set
    [Parameter(Mandatory = $false)]
    [String]$UIstyle = "full" # ui style: full=show all, lite=show only active miner
)

Clear-Host

$Version = "3.7.0.1"
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

$WatchdogTimers = @()
$ActiveMiners = @()
$Rates = [PSCustomObject]@{BTC = [Double]1}

$ConfigTimeStamp = 0
$PoolsConfigTimeStamp = 0
$MinersConfigTimeStamp = 0

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

#Cleanup the log
if (Test-Path ".\Logs"){
    Get-ChildItem -Path ".\Logs" -Filter "*" | Where-Object {$_.LastWriteTime -lt (Get-Date).AddDays(-5)} | Remove-Item -ErrorAction Ignore
}

#Start the log
Start-Transcript ".\Logs\RainbowMiner_$(Get-Date -Format "yyyy-MM-dd_HH-mm-ss").txt"

Write-Log "Starting RainbowMiner v$Version"

#Set process priority to BelowNormal to avoid hash rate drops on systems with weak CPUs
(Get-Process -Id $PID).PriorityClass = "BelowNormal"

if (Get-Command "Unblock-File" -ErrorAction SilentlyContinue) {Get-ChildItem . -Recurse | Unblock-File}
if ((Get-Command "Get-MpPreference" -ErrorAction SilentlyContinue) -and (Get-MpComputerStatus -ErrorAction SilentlyContinue) -and (Get-MpPreference).ExclusionPath -notcontains (Convert-Path .)) {
    Start-Process (@{desktop = "powershell"; core = "pwsh"}.$PSEdition) "-Command Import-Module '$env:Windir\System32\WindowsPowerShell\v1.0\Modules\Defender\Defender.psd1'; Add-MpPreference -ExclusionPath '$(Convert-Path .)'" -Verb runAs
}

#Check for software updates
if (-not $DisableAutoUpdate -and (Test-Path .\Updater.ps1)) {$Downloader = Start-Job -InitializationScript ([scriptblock]::Create("Set-Location('$(Get-Location)')")) -ArgumentList ($Version, $PSVersionTable.PSVersion, "") -FilePath .\Updater.ps1}

#Set donation parameters
$LastDonated = 0

#Initialize the API
Import-Module .\API.psm1
Start-APIServer
$API.Version = $Version

try {
    $ConfigFile = Get-Item $ConfigFile | Foreach-Object {
        $ConfigFile_Path = $_ | Select-Object -ExpandProperty DirectoryName
        $ConfigFile_Name = $_ | Select-Object -ExpandProperty Name
        $PoolsConfigFile = @($ConfigFile_Path,"\pools.",$ConfigFile_Name) -join ''
        $MinersConfigFile = @($ConfigFile_Path,"\miners.",$ConfigFile_Name) -join ''

        # Create pools.config.txt if it is missing
        if (-not (Test-Path $PoolsConfigFile)) {
            if(Test-Path "Config\pools.config.default.txt") {
                Copy-Item -Path "Config\pools.config.default.txt" -Destination $PoolsConfigFile
            } else {
                throw "$($PoolsConfigFile) and Config\pools.config.default.txt are missing."
            }
        }
        $PoolsConfigFile = $PoolsConfigFile | Resolve-Path -Relative

        # Create miners.config.txt if it is missing
        if (-not (Test-Path $MinersConfigFile)) {
            Get-MinerConfigDefault | ConvertTo-Json | Out-File $MinersConfigFile
        }
        $MinersConfigFile = $MinersConfigFile | Resolve-Path -Relative
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

#[console]::TreatControlCAsInput = $true

while ($true) {
    #Load the config
    $ConfigBackup = if ($Config -is [object]){$Config.PSObject.Copy()}else{$null}
    $ConfigCheckFields = $true
    if (Test-Path $ConfigFile) {
        if (-not $Config -or $RunSetup -or (Get-ChildItem $ConfigFile).LastWriteTime.ToUniversalTime() -gt $ConfigTimeStamp) {        

            do {
                $ConfigTimeStamp = (Get-ChildItem $ConfigFile).LastWriteTime.ToUniversalTime()
                $Parameters = @{}
                $MyInvocation.MyCommand.Parameters.Keys | Where-Object {$_ -ne "ConfigFile"} | ForEach-Object {
                    $Parameters.Add($_ , (Get-Variable $_ -ValueOnly -ErrorAction SilentlyContinue))
                }
                $Config = Get-ChildItemContent $ConfigFile -Force -Parameters $Parameters | Select-Object -ExpandProperty Content
                $Config | Add-Member Pools ([PSCustomObject]@{}) -Force
                $Config | Add-Member Miners ([PSCustomObject]@{}) -Force

                $ReReadConfig = $false

                if ($RunSetup) {

                    do {
                        Write-Host " "
                        Write-Host "*** RainbowMiner Configuration ***"
                        Write-Host "Please choose, what to configure:"

                        if ($IsInitialSetup) {
                            $SetupType = "G"  
                            $Config.PoolName = @("nicehash","blazepool","miningpoolhub")
                            $Config.Algorithm = @("bitcore","blake2s","c11","cryptonightheavy","cryptonightv7","ethash","equihash","hmq1725","hsr","keccak","keccakc","lyra2re2","lyra2z","neoscrypt","pascal","phi","skein","skunk","timetravel","tribus","x16r","x16s","x17","vit","xevan","yescrypt","yescryptr16")
                            $Config.FastestMinerOnly = $true 
                            $Config.ShowPoolBalances = $true
                            $Config.ShowMinerWindow = $false
                            $Config.Watchdog = $true                                                        
                        } else {
                            $SetupType = Read-HostString -Prompt "[G]lobal, [M]iner, [P]ools, E[x]it configuration" -Default "X"  -Mandatory -Characters "GMPX"
                            Write-Host " "
                        }

                        if ($SetupType -eq "X") {
                            $RunSetup = $false
                        }
                        elseif ($SetupType -eq "G") {

                            $ConfigActual = Get-Content $ConfigFile | ConvertFrom-Json
                            $PoolsActual = Get-Content $PoolsConfigFile | ConvertFrom-Json
                            
                            Write-Host "*** Global Configuration ***"                            
                            Write-Host "Hints:"
                            Write-Host "- your current configuration defines the defaults. Press Return to accept the them."
                            Write-Host "- fields marked with * are mandatory"
                            Write-Host "- use comma `",`" to separate list entries"
                            Write-Host "- enter `"list`" or `"help`" to show a list of all valid entries"
                            Write-Host "- enter `"delete`" to clear a non-mandatory entry"
                            Write-Host "- enter `"exit`" or `"cancel`" to abort without any changes to the configuration"
                            Write-Host " "

                            try {
                                $SetupDevices = Get-Device "nvidia","amd","cpu"

                                # Start setup procedure
                                Write-Host ' '
                                Write-Host '(1) Basic Setup'
                                Write-Host ' '
                                $Config.Wallet = Read-HostString -Prompt "Enter your BTC wallet address" -Default $Config.Wallet -Length 34 -Mandatory -Characters "A-Z0-9" | Foreach-Object {if (@("cancel","exit") -icontains $_) {throw};$_}

                                if ($PoolsActual | Get-Member Nicehash -MemberType NoteProperty) {
                                    $NicehashWallet = $PoolsActual.Nicehash.BTC
                                    $NicehashWorkerName = $PoolsActual.Nicehash.Worker
                                } else {
                                    $NicehashWallet = '$Wallet'
                                    $NicehashWorkerName = '$WorkerName'
                                }
                                if ($NicehashWallet -eq '$Wallet'){$NicehashWallet=$Config.Wallet}
                                $NicehashWallet = Read-HostString -Prompt "Enter your NiceHash-BTC wallet address" -Default $NicehashWallet -Length 34 -Mandatory -Characters "A-Z0-9" | Foreach-Object {if (@("cancel","exit") -icontains $_) {throw};$_}
                                $Config.WorkerName = Read-HostString -Prompt "Enter your worker name" -Default $Config.WorkerName -Mandatory -Characters "A-Z0-9" | Foreach-Object {if (@("cancel","exit") -icontains $_) {throw};$_}
                                $Config.UserName = Read-HostString -Prompt "Enter your Miningpoolhub user name" -Default $Config.UserName -Characters "A-Z0-9" | Foreach-Object {if (@("cancel","exit") -icontains $_) {throw};$_}
                                $Config.Region = Read-HostString -Prompt "Enter your region" -Default $Config.Region -Mandatory -Characters "A-Z" -Valid @(Get-Regions) | Foreach-Object {if (@("cancel","exit") -icontains $_) {throw};$_}
                                $Config.Currency = Read-HostArray -Prompt "Enter all currencies to be displayed (e.g. EUR,USD,BTC)" -Default $Config.Currency -Mandatory -Characters "A-Z" | Foreach-Object {if (@("cancel","exit") -icontains $_) {throw};$_}

                                Write-Host ' '
                                Write-Host '(2) Select your pools, miners and algorithm (be sure you read the notes in the README.md)'
                                Write-Host ' '

                                $Config.PoolName = Read-HostArray -Prompt "Enter the pools you want to mine" -Default $Config.PoolName -Mandatory -Characters "A-Z0-9" -Valid @(Get-ChildItem "Pools\*.ps1" | Select-Object -ExpandProperty BaseName) | Foreach-Object {if (@("cancel","exit") -icontains $_) {throw};$_}
                                $Config.ExcludePoolName = Read-HostArray -Prompt "Enter the pools you do want to exclude from mining" -Default $Config.ExcludePoolName -Characters "A-Z0-9" -Valid (Get-ChildItem "Pools\*.ps1" | Select-Object -ExpandProperty BaseName) | Foreach-Object {if (@("cancel","exit") -icontains $_) {throw};$_}
                                $Config.MinerName = Read-HostArray -Prompt "Enter the miners your want to use (leave empty for all)" -Default $Config.MinerName -Characters "A-Z0-9.-_" -Valid (Get-ChildItem "Miners\*.ps1" | Select-Object -ExpandProperty BaseName) | Foreach-Object {if (@("cancel","exit") -icontains $_) {throw};$_}
                                $Config.ExcludeMinerName = Read-HostArray -Prompt "Enter the miners you do want to exclude" -Default $Config.ExcludeMinerName -Characters "A-Z0-9\.-_" -Valid (Get-ChildItem "Miners\*.ps1" | Select-Object -ExpandProperty BaseName)                 | Foreach-Object {if (@("cancel","exit") -icontains $_) {throw};$_}
                                $Config.Algorithm = Read-HostArray -Prompt "Enter the algorithm you want to mine (leave empty for all)" -Default $Config.Algorithm -Characters "A-Z0-9" -Valid (Get-Algorithms) | Foreach-Object {if (@("cancel","exit") -icontains $_) {throw};$_}

                                Write-Host ' '
                                Write-Host '(3) Select the devices to mine on and miningmode'
                                Write-Host ' '

                                $AvailDeviceName = @()                                
                                if ((Select-Device $SetupDevices "nvidia" | Measure-Object).Count -gt 0) {$AvailDeviceName += "nvidia"}
                                if ((Select-Device $SetupDevices "amd" | Measure-Object).Count -gt 0) {$AvailDeviceName += "amd"}               

                                $WizardDeviceNameSet = $false                                                                
                                if ($IsInitialSetup -and @($Config.DeviceName).Count -eq 0) {
                                    $Config.DeviceName = @()
                                    if ($AvailDeviceName.Count -gt 0) { #GPU mining possible
                                        if ($AvailDeviceName.Count -gt 1) {
                                            if (Read-HostBool -Prompt "Mine on all available GPU ($(($AvailDeviceName -join '&').ToUpper()), choose no to select devices)" -Default $true | Foreach-Object {if (@("cancel","exit") -icontains $_) {throw};$_}) {
                                                $Config.DeviceName += $AvailDeviceName                                            
                                            }
                                        }
                                        if ($Config.DeviceName.Count -eq 0) {
                                            $AvailDeviceName | Foreach-Object {
                                                if (Read-HostBool -Prompt "Mine on all $($_.ToUpper()) GPU (choose no to select devices)" -Default $true | Foreach-Object {if (@("cancel","exit") -icontains $_) {throw};$_}) {$Config.DeviceName += @($_)}
                                            }
                                        }
                                        $WizardDeviceNameSet = $Config.DeviceName.Count -gt 0
                                    }
                                   
                                    if (Read-HostBool -Prompt "Mine on your CPU" -Default $false | Foreach-Object {if (@("cancel","exit") -icontains $_) {throw};$_}) {
                                        $Config.DeviceName += @("cpu")
                                    }                                                                        
                                }                                                             

                                $Config.MiningMode = Read-HostString "Select mining mode (legacy/device/combo)" -Default $Config.MiningMode -Mandatory -Characters "A-Z" | Foreach-Object {if (@("cancel","exit") -icontains $_) {throw};$_}
                                if ($Config.MiningMode -like "l*") {$Config.MiningMode="legacy"}
                                elseif ($Config.MiningMode -like "c*") {$Config.MiningMode="combo"}
                                else {$Config.MiningMode="device"}
                        
                                if ($Config.MiningMode -ne "legacy") {$SetupDevices | Select-Object -ExpandProperty Model -Unique | Foreach-Object {$AvailDeviceName += $_}}else{$AvailDeviceName+="cpu"}

                                if (-not $WizardDeviceNameSet) {
                                    $Config.DeviceName = Read-HostArray -Prompt "Enter the devices you want to use for mining (leave empty for all)" -Default $Config.DeviceName -Characters "A-Z0-9#" -Valid $AvailDeviceName | Foreach-Object {if (@("cancel","exit") -icontains $_) {throw};$_}
                                }

                                Write-Host ' '
                                Write-Host '(4) Select desired output'
                                Write-Host ' '

                                $Config.UIstyle = Read-HostString -Prompt "Select style of user interface (full/lite)" -Default $Config.UIstyle -Mandatory -Characters "A-Z" | Foreach-Object {if (@("cancel","exit") -icontains $_) {throw};$_}
                                if ($Config.UIstyle -like "l*"){$Config.UIstyle="lite"}else{$Config.UIstyle="full"}   
                                $Config.FastestMinerOnly = Read-HostBool -Prompt "Show fastest miner only" -Default $Config.FastestMinerOnly | Foreach-Object {if (@("cancel","exit") -icontains $_) {throw};$_}
                                $Config.ShowPoolBalances = Read-HostBool -Prompt "Show all available pool balances" -Default $Config.ShowPoolBalances | Foreach-Object {if (@("cancel","exit") -icontains $_) {throw};$_}
                                $Config.ShowMinerWindow = Read-HostBool -Prompt "Show miner in own windows (will steal your focus, not recommended)" -Default $Config.ShowMinerWindow | Foreach-Object {if (@("cancel","exit") -icontains $_) {throw};$_}

                                Write-Host ' '
                                Write-Host '(5) Setup other / technical'
                                Write-Host ' '
                                $Config.Watchdog = Read-HostBool -Prompt "Enable watchdog" -Default $Config.Watchdog | Foreach-Object {if (@("cancel","exit") -icontains $_) {throw};$_}
                                do {
                                    $Config.MSIAprofile = Read-HostInt -Prompt "Enter default MSI Afterburner profile (0 to disable all MSI action)" -Default $Config.MSIAprofile -Mandatory -Min 0 -Max 5 | Foreach-Object {if (@("cancel","exit") -icontains $_) {throw};$_}                             
                                    if ($Config.MSIAprofile -gt 0) {
                                        $Config.MSIApath = Read-HostString -Prompt "Enter path to MSI Afterburner" -Default $Config.MSIApath -Characters '' | Foreach-Object {if (@("cancel","exit") -icontains $_) {throw};$_}
                                        if (-not (Test-Path $Config.MSIApath)) {Write-Host "MSI Afterburner not found at given path. Please try again or disable."}
                                    }
                                } until ($Config.MSIAprofile -eq 0 -or (Test-Path $Config.MSIApath));
                                
                                $Config.Proxy = Read-HostString -Prompt "Enter proxy address, if used" -Default $Config.Proxy -Characters "A-Z0-9:/\.%-_" | Foreach-Object {if (@("cancel","exit") -icontains $_) {throw};$_}
                                $Config.Interval = Read-HostInt -Prompt "Enter the script's loop interval in seconds" -Default $Config.Interval -Mandatory -Min 30 | Foreach-Object {if (@("cancel","exit") -icontains $_) {throw};$_}
                                $Config.Donate = [int]($(Read-HostDouble -Prompt "Enter the developer donation fee in %" -Default ([Math]::Round($Config.Donate/0.1440)/100) -Mandatory -Min 0.69 -Max 100)*14.40) | Foreach-Object {if (@("cancel","exit") -icontains $_) {throw};$_}
           
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
                                $ConfigActual | Add-Member MiningMode $Config.MiningMode -Force
                                $ConfigActual | Add-Member ShowPoolBalances $(if ($Config.ShowPoolBalances){"1"}else{"0"}) -Force
                                $ConfigActual | Add-Member ShowMinerWindow $(if ($Config.ShowMinerWindow){"1"}else{"0"}) -Force
                                $ConfigActual | Add-Member FastestMinerOnly $(if ($Config.FastestMinerOnly){"1"}else{"0"}) -Force
                                $ConfigActual | Add-Member UIstyle $Config.UIstyle -Force
                                $ConfigActual | Add-Member DeviceName $($Config.DeviceName -join ",") -Force                      
                                $ConfigActual | Add-Member Interval $Config.Interval -Force
                                $ConfigActual | Add-Member Donate $Config.Donate -Force
                                $ConfigActual | Add-Member Watchdog $(if ($Config.Watchdog){"1"}else{"0"}) -Force                                
                                $ConfigActual | Add-Member MSIAprofile $Config.MSIAprofile -Force
                                $ConfigActual | Add-Member MSIApath $Config.MSIApath -Force

                                $PoolsActual | Add-Member NiceHash ([PSCustomObject]@{
                                        BTC = if($NicehashWallet -eq $Config.Wallet -or $NicehashWallet -eq ''){'$Wallet'}else{$NicehashWallet}
                                        Worker = if($NicehashWorkerName -eq $Config.WorkerName -or $NicehashWorkerName -eq ''){'$WorkerName'}else{$NicehashWorkerName}
                                }) -Force

                                $ConfigActual | ConvertTo-Json | Out-File $ConfigFile                                               
                                $PoolsActual | ConvertTo-Json | Out-File $PoolsConfigFile

                                Write-Host "Changes written to configuration"
                                Write-Host" "

                                $IsInitialSetup = $false
                            }
                            catch {
                                Write-Host "Cancelled without changing the configuration"
                                Write-Host " "
                                $ReReadConfig = $true
                            }
                        }
                        elseif ($SetupType -eq "M") {

                            $MinersActual = Get-Content $MinersConfigFile | ConvertFrom-Json

                            Write-Host "*** Miner Configuration ***"
                            Write-Host "Hints:"
                            Write-Host "- the defaults are your current configuration. Press Return to accept the defaults."
                            Write-Host "- fields marked with * are mandatory"
                            Write-Host "- use comma `",`" to separate list entries"
                            Write-Host "- enter `"list`" or `"help`" to show a list of all valid entries"
                            Write-Host "- enter `"delete`" to clear a non-mandatory entry"
                            Write-Host " "

                            $AvailDeviceName = @()
                            $SetupDevices = Get-Device "nvidia","amd","cpu"
                            if ($Config.MiningMode -ne "legacy") {$SetupDevices | Select-Object -ExpandProperty Model -Unique | Foreach-Object {$AvailDeviceName += $_}}
                            if (Select-Device $SetupDevices "nvidia") {$AvailDeviceName += "NVIDIA"}
                            if (Select-Device $SetupDevices "amd") {$AvailDeviceName += "AMD"}
                            if (Select-Device $SetupDevices "cpu") {$AvailDeviceName += "CPU"}
                            $AvailDeviceName = $AvailDeviceName | Select-Object -Unique | Sort-Object

                            $MinerSetupDone = $false
                            do {
                                try {
                                    $EditMinerName = Read-HostString -Prompt "Which miner do you want to configure? (leave empty to end miner config)" -Characters "A-Z0-9.-_" -Valid (Get-ChildItem "Miners\*.ps1" | Select-Object -ExpandProperty BaseName)
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

                            $PoolsActual = Get-Content $PoolsConfigFile | ConvertFrom-Json

                            Write-Host "*** Pool Configuration ***"
                            Write-Host "Hints:"
                            Write-Host "- the defaults are your current configuration. Press Return to accept the defaults."
                            Write-Host "- fields marked with * are mandatory"
                            Write-Host "- use comma `",`" to separate list entries"
                            Write-Host "- enter `"list`" or `"help`" to show a list of all valid entries"
                            Write-Host "- enter `"delete`" to clear a non-mandatory entry"
                            Write-Host " "
                            Write-Host "(under development)"
                            Write-Host " "

                        }
                    } until (-not $RunSetup)
                    $RestartMiners = $true
                    $ReReadConfig = $true
                    Write-Host " "
                    Write-Host "Exiting configuration setup - all miners will be restarted. Please be patient!"
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

        $Config | Get-Member -MemberType *Property | Foreach-Object {
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
    $MSIAenabled = $Config.MSIAprofile -gt 0 -and (Test-Path $Config.MSIApath)

    if (Test-Path $PoolsConfigFile) {
        if ($ConfigCheckFields -or -not $Config.Pools -or (Get-ChildItem $PoolsConfigFile).LastWriteTime.ToUniversalTime() -gt $PoolsConfigTimeStamp) {        
            $PoolsConfigTimeStamp = (Get-ChildItem $PoolsConfigFile).LastWriteTime.ToUniversalTime()
            $Config | Add-Member Pools (Get-ChildItemContent $PoolsConfigFile -Parameters @{
                Wallet              = $Config.Wallet
                UserName            = $Config.UserName
                WorkerName          = $Config.WorkerName
                API_ID              = $Config.API_ID
                API_Key             = $Config.API_Key
            } | Select-Object -ExpandProperty Content) -Force
        }
    }    

    Get-ChildItem "Pools" -File | Where-Object {-not $Config.Pools.($_.BaseName)} | ForEach-Object {
        $Config.Pools | Add-Member $_.BaseName (
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
        Get-ChildItem "Pools" -File | ForEach-Object {
            $DonationData1 = if (Get-Member -InputObject ($DonationData.Wallets) -Name ($_.BaseName) -MemberType NoteProperty) {$DonationData.Wallets.($_.BaseName)} else {$DonationData.Wallets.Default};
            $DonationPools += $_.BaseName
            $Config.Pools | Add-Member $_.BaseName $DonationData1 -Force
            $DonateNow = $true
        }
        if ($DonateNow) {
            $ConfigTimeStamp = 0
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

    if (Test-Path $MinersConfigFile) {
        if ($ConfigCheckFields -or -not $Config.Miners -or (Get-ChildItem $MinersConfigFile).LastWriteTime.ToUniversalTime() -gt $MinersConfigTimeStamp) {        
            $MinersConfigTimeStamp = (Get-ChildItem $MinersConfigFile).LastWriteTime.ToUniversalTime()
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
    if ( $Config.RebootOnGPUFailure ) { 
        Write-Log "Testing for GPU failure. "
        Test-GPU
    }

    if ($Config.Proxy) {$PSDefaultParameterValues["*:Proxy"] = $Config.Proxy}
    else {$PSDefaultParameterValues.Remove("*:Proxy")}

    Get-ChildItem "APIs" -File | ForEach-Object {. $_.FullName}

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
        $NewRates = Invoke-RestMethod "https://api.coinbase.com/v2/exchange-rates?currency=BTC" -UseBasicParsing -TimeoutSec 10 -ErrorAction Stop | Select-Object -ExpandProperty data | Select-Object -ExpandProperty rates
        $Config.Currency | Where-Object {$NewRates.$_} | ForEach-Object {$Rates | Add-Member $_ ([Double]$NewRates.$_) -Force}
        $Config.Currency | Where-Object {-not $NewRates.$_} | Foreach-Object {$Rates | Add-Member $_ $($Ticker=Get-Ticker -Symbol $_ -BTCprice;if($Ticker){[Double]1/$Ticker}else{0})}
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

    #Load the stats
    Write-Log "Loading saved statistics. "
    $Stats = Get-Stat

    #Give API access to the current stats
    $API.Stats = $Stats

    #Load information about the pools
    Write-Log "Loading pool information. "
    $NewPools = @()
    if (Test-Path "Pools") {
        $NewPools = Get-ChildItem "Pools" -File | Where-Object {$Config.Pools.$($_.BaseName) -and $Config.ExcludePoolName -inotcontains $_.BaseName} | ForEach-Object {
            $Pool_Name = $_.BaseName
            $Pool_Parameters = @{StatSpan = $StatSpan}
            $Config.Pools.$Pool_Name | Get-Member -MemberType NoteProperty | ForEach-Object {$Pool_Parameters.($_.Name) = $Config.Pools.$Pool_Name.($_.Name)}                      
            $Pool_Config = @{}
            Compare-Object @("Penalty","PoolFee") @($Pool_Parameters.Keys) -ExcludeDifferent -IncludeEqual | Select-Object -ExpandProperty InputObject | Foreach-Object {$Pool_Config.$_ = $Pool_Parameters.$_}
            Get-ChildItemContent "Pools\$($_.Name)" -Parameters $Pool_Parameters | Foreach-Object {if ($Pool_Config.Count){$_.Content | Add-Member -NotePropertyMembers $Pool_Config -Force};$_}
        } | ForEach-Object {
            $Pool_Factor = 1-[Double]($_.Content.Penalty + $(if (-not $Config.IgnoreFees){$_.Content.PoolFee}))/100
            $_.Content.Price *= $Pool_Factor
            $_.Content.StablePrice *= $Pool_Factor                
            $_.Content | Add-Member Name $_.Name -PassThru
        }        
    }

    #Remove stats from pools & miners not longer in use
    if (-not $DonateNow -and (Test-Path "Stats")) {
        Compare-Object @($NewPools | Foreach-Object {"$($_.Name)_$($_.Algorithm)_Profit"} | Select-Object -Unique) @($Stats.PSObject.Properties | Where-Object Name -like '*_Profit' | Select-Object -Unique -ExpandProperty Name) | Where-Object {$_.SideIndicator -eq "=>" -and (Test-Path "Stats\$($_.InputObject).txt")} | Foreach-Object {Remove-Item "Stats\$($_.InputObject).txt"}
        Compare-Object @(Get-ChildItem "Miners" | Select-Object -ExpandProperty BaseName) @($Stats.PSObject.Properties | Where-Object Name -like '*_Hashrate' | Foreach-Object {($_.Name -split '-')[0]} | Select-Object -Unique) | Where-Object {$_.SideIndicator -eq "=>"} | Foreach-Object {Get-ChildItem "Stats\$($_.InputObject)-*_Hashrate.txt" | Remove-Item}
    }

    #Give API access to the current running configuration
    $API.NewPools = $NewPools

    # This finds any pools that were already in $AllPools (from a previous loop) but not in $NewPools. Add them back to the list. Their API likely didn't return in time, but we don't want to cut them off just yet
    # since mining is probably still working.  Then it filters out any algorithms that aren't being used.
    $AllPools = @($NewPools) + @(Compare-Object @($NewPools | Select-Object -ExpandProperty Name -Unique) @($AllPools | Select-Object -ExpandProperty Name -Unique) | Where-Object SideIndicator -EQ "=>" | Select-Object -ExpandProperty InputObject | ForEach-Object {$AllPools | Where-Object Name -EQ $_}) | 
        Where-Object {$Config.Algorithm.Count -eq 0 -or (Compare-Object $Config.Algorithm $_.Algorithm -IncludeEqual -ExcludeDifferent | Measure-Object).Count -gt 0} | 
        Where-Object {$Config.ExcludeAlgorithm.Count -eq 0 -or (Compare-Object $Config.ExcludeAlgorithm $_.Algorithm -IncludeEqual -ExcludeDifferent | Measure-Object).Count -eq 0} | 
        Where-Object {$Config.ExcludePoolName.Count -eq 0 -or (Compare-Object $Config.ExcludePoolName $_.Name -IncludeEqual -ExcludeDifferent | Measure-Object).Count -eq 0}

    #Give API access to the current running configuration
    $API.AllPools = $AllPools

    #Apply watchdog to pools
    $AllPools = $AllPools | Where-Object {
        $Pool = $_
        $Pool_WatchdogTimers = $WatchdogTimers | Where-Object PoolName -EQ $Pool.Name | Where-Object Kicked -LT $Timer.AddSeconds( - $WatchdogInterval) | Where-Object Kicked -GT $Timer.AddSeconds( - $WatchdogReset)
        ($Pool_WatchdogTimers | Measure-Object | Select-Object -ExpandProperty Count) -lt <#stage#>3 -and ($Pool_WatchdogTimers | Where-Object {$Pool.Algorithm -contains $_.Algorithm} | Measure-Object | Select-Object -ExpandProperty Count) -lt <#statge#>2
    }

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
    #Messy...?
    Write-Log "Getting miner information. "
    # Get all the miners, get just the .Content property and add the name, select only the ones that match our $Config.Type (CPU, AMD, NVIDIA) or all of them if type is unset,
    # select only the ones that have a HashRate matching our algorithms, and that only include algorithms we have pools for
    # select only the miners that match $Config.MinerName, if specified, and don't match $Config.ExcludeMinerName
    $AllMiners = if (Test-Path "Miners") {
        Get-ChildItemContent "Miners" -Parameters @{Pools = $Pools; Stats = $Stats; Config = $Config; Devices = $DevicesByTypes} | ForEach-Object {$_.Content | Add-Member -NotePropertyMembers @{Name=$_.Name;BaseName=$_.BaseName} -PassThru -Force} | 
            ForEach-Object {              
                if (-not $_.DeviceName) {$_ | Add-Member DeviceName (Get-Device $_.Type).Name -Force}
                if (-not $_.DeviceModel) {$_ | Add-Member DeviceModel ($_.Type) -Force}
                if (@($DevicesByTypes.FullComboModels.PSObject.Properties.Name) -icontains $_.DeviceModel) {$_.DeviceModel = $($DevicesByTypes.FullComboModels."$($_.DeviceModel)")}                
                $_
            } | #for backward compatibility            
            Where-Object {$_.DeviceName} | #filter miners for non-present hardware
            Where-Object {(Compare-Object @($Devices.Name | Select-Object) @($_.DeviceName | Select-Object) | Where-Object SideIndicator -EQ "=>" | Measure-Object).Count -eq 0} | 
            Where-Object {($Config.Algorithm.Count -eq 0 -or (Compare-Object $Config.Algorithm $_.HashRates.PSObject.Properties.Name | Where-Object SideIndicator -EQ "=>" | Measure-Object).Count -eq 0) -and ((Compare-Object $Pools.PSObject.Properties.Name $_.HashRates.PSObject.Properties.Name | Where-Object SideIndicator -EQ "=>" | Measure-Object).Count -eq 0)} | 
            Where-Object {$Config.ExcludeAlgorithm.Count -eq 0 -or (Compare-Object $Config.ExcludeAlgorithm $_.HashRates.PSObject.Properties.Name -IncludeEqual -ExcludeDifferent | Measure-Object).Count -eq 0} | 
            Where-Object {$Config.MinerName.Count -eq 0 -or (Compare-Object $Config.MinerName $_.BaseName -IncludeEqual -ExcludeDifferent | Measure-Object).Count -gt 0} | 
            Where-Object {$Config.ExcludeMinerName.Count -eq 0 -or (Compare-Object $Config.ExcludeMinerName $_.BaseName -IncludeEqual -ExcludeDifferent | Measure-Object).Count -eq 0}
    }

    if ($Config.MiningMode -eq "combo") {
        if (($AllMiners | Where-Object {$_.HashRates.PSObject.Properties.Value -eq $null -and $_.DeviceModel -notmatch '-'} | Measure-Object).Count -gt 1) {
            #Benchmarking is still ongoing - remove device combos from miners
            $AllMiners = $AllMiners | Where-Object {$_.DeviceModel -notmatch '-'}
        } else {
            #Remove device combos, where the parameter-preset is different and there does not exist an own definition
            $AllMiners = $AllMiners | Where-Object {
                $_.DeviceModel -notmatch '-' -or 
                (Get-Member -InputObject $Config.Miners -Name $(@($_.BaseName) + @($_.DeviceModel) + @($_.HashRates.PSObject.Properties.Name) -join '-') -MemberType NoteProperty) -or 
                $($Miner = $_; (@($Miner.DeviceModel -split '-') | Foreach-Object {
                    $Miner_ConfigName = @($Miner.BaseName) + @($_) + @($Miner.HashRates.PSObject.Properties.Name) -join '-'
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
        $Miner_Pools = [PSCustomObject]@{}
        $Miner_Pools_Comparison = [PSCustomObject]@{}
        $Miner_Profits = [PSCustomObject]@{}
        $Miner_Profits_Comparison = [PSCustomObject]@{}
        $Miner_Profits_MarginOfError = [PSCustomObject]@{}
        $Miner_Profits_Bias = [PSCustomObject]@{}
        $Miner_Profits_Unbias = [PSCustomObject]@{}
        $Miner_DevFees = [PSCustomObject]@{}

        $Miner_CommonCommands = @($Miner.BaseName) + @($Miner.DeviceModel) + @($Miner.HashRates.PSObject.Properties.Name) -join '-'
        if ($Config.Miners -and (Get-Member -InputObject $Config.Miners -Name $Miner_CommonCommands -MemberType NoteProperty)) {
            if ($Config.Miners.$Miner_CommonCommands.Params) {
                $Miner | Add-Member -Name Arguments -Value (@($Miner.Arguments,$Config.Miners.$Miner_CommonCommands.Params) -join ' ') -MemberType NoteProperty -Force
            }
            if ($Config.Miners.$Miner_CommonCommands.Profile) {
                $Miner | Add-Member -Name MSIAprofile -Value $Config.Miners.$Miner_CommonCommands.Profile -MemberType NoteProperty -Force
            }
        } elseif ($Config.MiningMode -eq "combo" -and $Miner.DeviceModel -match '-') {
            #combo handling - we know that combos always have equal params, because we preselected them, already
            $Miner_CommonCommands = @($Miner.BaseName) + @($Miner.DeviceModel -split '-' | Select-Object -First 1) + @($Miner.HashRates.PSObject.Properties.Name) -join '-'
            if ($Config.Miners -and (Get-Member -InputObject $Config.Miners -Name $Miner_CommonCommands -MemberType NoteProperty)) {
                if ($Config.Miners.$Miner_CommonCommands.Params) {
                    $Miner | Add-Member -Name Arguments -Value (@($Miner.Arguments,$Config.Miners.$Miner_CommonCommands.Params) -join ' ') -MemberType NoteProperty -Force
                }
            }
            [Int[]]$Miner_MSIAprofile = @($Miner.DeviceModel -split '-') | Foreach-Object {
                $Miner_CommonCommands = @($Miner.BaseName) + @($_) + @($Miner.HashRates.PSObject.Properties.Name) -join '-'
                if ($Config.Miners.$Miner_CommonCommands.Profile) {$Config.Miners.$Miner_CommonCommands.Profile} else {$Config.MSIAprofile}
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
        else {$Miner.Arguments = $Miner.Arguments | ConvertTo-Json -Compress} 
        
        if ($Miner.MSIAprofile -eq $null) {$Miner | Add-Member MSIAprofile $Config.MSIAprofile -Force}
        if ($Miner.ExtendInterval -eq $null) {$Miner | Add-Member ExtendInterval 0 -Force}              
        if ($Miner.ExecName -eq $null) {$Miner | Add-Member ExecName ([IO.FileInfo]($Miner.Path | Split-Path -Leaf -ErrorAction Ignore)).BaseName -Force}
        if ($Miner.FaultTolerance -eq $null) {$Miner | Add-Member FaultTolerance 0.1 -Force}               

        if (-not $Miner.API) {$Miner | Add-Member API "Miner" -Force}
    }
    $AllMinersUriHash = Get-MD5Hash $(@($AllMiners.URI | Select-Object -Unique | Sort-Object) -join ':')
    if ($MinersUriHash -eq $null) {$MinersUriHash = $AllMinersUriHash}
    $Miners = $AllMiners | Where-Object {(Test-Path $_.Path) -and ((-not $_.PrerequisitePath) -or (Test-Path $_.PrerequisitePath))}
    if ( ($StartDownloader -or $Miners.Count -ne $AllMiners.Count -or $MinersUriHash -ne $AllMinersUriHash) -and $Downloader.State -ne "Running") {
        if ($StartDownloader) {
            Write-Log -Level Warn "User requested to start downloader. "
        } else {
            Write-Log -Level Warn "Some miners binaries are missing or are out of date, starting downloader. "
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

    #Apply watchdog to miners
    $Miners = $Miners | Where-Object {
        $Miner = $_
        $Miner_WatchdogTimers = $WatchdogTimers | Where-Object MinerName -EQ $Miner.Name | Where-Object Kicked -LT $Timer.AddSeconds( - $WatchdogInterval) | Where-Object Kicked -GT $Timer.AddSeconds( - $WatchdogReset)
        ($Miner_WatchdogTimers | Measure-Object | Select-Object -ExpandProperty Count) -lt <#stage#>2 -and ($Miner_WatchdogTimers | Where-Object {$Miner.HashRates.PSObject.Properties.Name -contains $_.Algorithm} | Measure-Object | Select-Object -ExpandProperty Count) -lt <#stage#>1
    }

    #Give API access to the miners information
    $API.Miners = $Miners

    #Use only use fastest miner per algo and device index. E.g. if there are 2 miners available to mine the same algo, only the faster of the two will ever be used, the slower ones will also be hidden in the summary screen
    if ($Config.FastestMinerOnly) {$Miners = $Miners | Sort-Object -Descending {"$($_.DeviceName -join '')$($_.HashRates.PSObject.Properties.Name -join '')$(if($_.HashRates.PSObject.Properties.Value -eq $null) {$_.Name})"}, {($_ | Where-Object Profit -EQ $null | Measure-Object).Count}, {([Double]($_ | Measure-Object Profit_Bias -Sum).Sum)}, {($_ | Where-Object Profit -NE 0 | Measure-Object).Count} | Group-Object {"$($_.DeviceName -join '')$($_.HashRates.PSObject.Properties.Name -join '')$(if($_.HashRates.PSObject.Properties.Value -eq $null) {$_.Name})"} | Foreach-Object {$_.Group[0]}}

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
                Path                 = $Miner.Path
                Arguments            = $Miner.Arguments
                API                  = $Miner.API
                Port                 = $Miner.Port
                Algorithm            = $Miner.HashRates.PSObject.Properties.Name #temp fix, must use 'PSObject.Properties' to preserve order
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
    if ( $SkipSwitchingPrevention ) {
        $SkipSwitchingPrevention = $false
        $ActiveMiners | ForEach-Object {$_.Profit_Bias = $_.Profit_Unbias}
    } else {
        $ActiveMiners | Where-Object {$_.GetStatus() -eq [MinerStatus]::Running} | ForEach-Object {$_.Profit_Bias = $_.Profit_Unbias}
    }

    #Get most profitable miner combination i.e. AMD+NVIDIA+CPU
    $BestMiners = $ActiveMiners | Select-Object DeviceName -Unique | ForEach-Object {$Miner_GPU = $_; ($ActiveMiners | Where-Object {(Compare-Object $Miner_GPU.DeviceName $_.DeviceName | Measure-Object).Count -eq 0} | Sort-Object -Descending {($_ | Where-Object Profit -EQ $null | Measure-Object).Count}, {($_ | Measure-Object Profit_Bias -Sum).Sum}, {($_ | Where-Object Profit -NE 0 | Measure-Object).Count}, {$_.Benchmarked} | Select-Object -First 1)}
    $BestMiners_Comparison = $ActiveMiners | Select-Object DeviceName -Unique | ForEach-Object {$Miner_GPU = $_; ($ActiveMiners | Where-Object {(Compare-Object $Miner_GPU.DeviceName $_.DeviceName | Measure-Object).Count -eq 0} | Sort-Object -Descending {($_ | Where-Object Profit -EQ $null | Measure-Object).Count}, {($_ | Measure-Object Profit_Comparison -Sum).Sum}, {($_ | Where-Object Profit -NE 0 | Measure-Object).Count}, {$_.Benchmarked} | Select-Object -First 1)}
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

    if ( $ActiveMiners | ForEach-Object {$_.GetProcessNames()} ) {
        $Running = @($ActiveMiners | Where-Object Best -EQ $true | Foreach-Object {if ( $_.GetStatus() -eq [MinerStatus]::Running -and $_.GetProcessId() -gt 0 ) {$_.GetProcessId()}})
        Get-Process | Where-Object { @($ActiveMiners | Select-Object -ExpandProperty ExecName) -contains $_.ProcessName } | Select-Object -ExpandProperty ProcessName | Compare-Object @($ActiveMiners | Where-Object Best -EQ $true | Where-Object {$_.GetStatus() -eq [MinerStatus]::Running} | Select-Object -ExpandProperty ExecName) | Where-Object SideIndicator -EQ "=>" | Select-Object -ExpandProperty InputObject | Select-Object -Unique | ForEach-Object {Get-Process -Name $_ -ErrorAction Ignore | Where-Object { $Running -notcontains $_.Id } | ForEach-Object {Write-Warning "Stop-Process $($_.ProcessName) with Id $($_.Id)"; Stop-Process -Id $_.Id -Force -ErrorAction Ignore}}
    }
    if ($Downloader) {$Downloader | Receive-Job}
    Start-Sleep $Config.Delay #Wait to prevent BSOD

    $ActiveMiners | Where-Object Best -EQ $true | ForEach-Object {
        if ($_.GetStatus() -ne [MinerStatus]::Running) {

            #Set MSI Afterburner profile
            if ($MSIAenabled) {
                $MSIAplannedprofile = $ActiveMiners | Where-Object Best -eq $true | Foreach-Object {if ($_.MSIAprofile -ne $null -and $_.MSIAprofile -gt 0) {$_.MSIAprofile} else {$Config.MSIAprofile}} | Select-Object -Unique

                if ($MSIAplannedprofile.Count -ne 1) {$MSIAplannedprofile=$Config.MSIAprofile}
                else {$MSIAplannedprofile = $MSIAplannedprofile | Select-Object -Index 0}

                if ( $MSIAplannedprofile -ne $MSIAcurrentprofile ) {
                    Write-Log "New MSI Afterburner profile set: $($MSIAplannedprofile)"
                    Start-Process -FilePath "$($Config.MSIApath)" -ArgumentList "-Profile$($MSIAplannedprofile)" -Verb RunAs
                    $MSIAcurrentprofile = $MSIAplannedprofile
                    Start-Sleep 1
                }
            }

            Write-Log "Starting miner ($($_.Name)): '$($_.Path) $($_.Arguments)'"
            $DecayStart = $Timer
            $_.SetStatus([MinerStatus]::Running)

            #Add watchdog timer
            if ($Config.Watchdog -and $_.Profit -ne $null) {
                $Miner_Name = $_.Name
                $Miner_DeviceName = $_.DeviceName
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
    $MinersNeedingBenchmark = @($Miners | Where-Object {$_.HashRates.PSObject.Properties.Value -eq $null})
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
            #@{Label = "$($Config.Currency | Select-Object -Index 0)/GH/Day"; Expression = {$_.Pools.PSObject.Properties.Value.Price | ForEach-Object {ConvertTo-LocalCurrency $($_ * 1000000000) $($Rates.$($Config.Currency | Select-Object -Index 0)) -Offset 2}}; Align = "right"}, 
            @{Label = "Pool"; Expression = {$_.Pools.PSObject.Properties.Value | ForEach-Object {"$($_.Name)$(if ($_.Info) {"-$($_.Info)"})"}}}
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

    #Display active miners list
    $ActiveMiners | Where-Object {$_.GetActivateCount() -GT 0 -and ($Config.UIstyle -eq "full" -or $MinersNeedingBenchmark.Count -gt 0 -or $_.GetStatus() -eq [MinerStatus]::Running)} | Sort-Object -Property @{Expression = {$_.GetStatus()}; Descending = $False}, @{Expression = {$_.GetActiveLast()}; Descending = $True} | Select-Object -First (1 + 6 + 6) | Format-Table -GroupBy @{Label = "Status"; Expression = {$_.GetStatus()}} (
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
                $Miner.UpdateMinerData() | ForEach-Object {Write-Log -Level Verbose "$($Miner.Name): $_"}
            }
        }

        $Timer = (Get-Date).ToUniversalTime()
        if ( $Timer -le $TimerBackup ) {
            Test-TimeSync
            $Timer = (Get-Date).ToUniversalTime()
        }
        $WaitTimer = $Timer

        if ((Test-Path ".\stopp.txt") -or $API.Stop) {
            $Stopp = $true
            $host.UI.RawUI.CursorPosition = $CursorPosition
            Write-Log "API request to stop script "
            Write-Host -NoNewline "[API] stopping script "
            $keyPressed = $true
        }
        if ( [console]::KeyAvailable ) {
            $x = [System.Console]::ReadKey($true)
            switch ( $x.key ) {
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

    if ( -not $keyPressed ) {
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
