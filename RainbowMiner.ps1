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
    [String]$API_ID = "", 
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
    [Array]$ExcludeCoin = @(),
    [Parameter(Mandatory = $false)]
    [Array]$ExcludeCoinSymbol = @(),
    [Parameter(Mandatory = $false)]
    [Array]$Currency = ("BTC", "USD"), #i.e. GBP,EUR,ZEC,ETH etc.
    [Parameter(Mandatory = $false)]
    [Int]$Donate = 24, #Minutes per Day
    [Parameter(Mandatory = $false)]
    [String]$Proxy = "", #i.e http://192.0.0.1:8080
    [Parameter(Mandatory = $false)]
    [Int]$Delay = 1, #seconds before opening each miner
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
    [Int]$MSIAprofile = 0, # default MSI Afterburner profile to be set
    [Parameter(Mandatory = $false)]
    [String]$UIstyle = "full", # ui style: full=show all, lite=show only active miner
    [Parameter(Mandatory = $false)]
    [Switch]$UseTimeSync = $false, # if set to $true, the windows time service will be used to synchronize the PC time with world time (needs admin rights)
    [Parameter(Mandatory = $false)]
    [Double]$PowerPrice = 0, # price for 1 kW/h (kilowatt per hour) in USD, EUR or other (set currency with parameter PowerPriceCurrency)
    [Parameter(Mandatory = $false)]
    [String]$PowerPriceCurrency = 'USD', # currency for price of power
    [Parameter(Mandatory = $false)]
    [Switch]$UsePowerPrice = $false, # if set to $true, the price for power will be taken into account in profit calculation
    [Parameter(Mandatory = $false)]
    [Switch]$CheckProfitability = $false, # if set to $true, miners with negative profit will be excluded
    [Parameter(Mandatory = $false)]
    [Switch]$DisableExtendInterval = $false, # if set to $true, benchmark intervals will never be extended
    [Parameter(Mandatory = $false)]
    [String]$EthPillEnable = "disable", # set to RevA or RevB to enable the OhGodAnETHlargementPill
    [Parameter(Mandatory = $false)]
    [Switch]$EnableOCProfiles = $false, # if set to $true, the build in overclocking profiles will be used
    [Parameter(Mandatory = $false)]
    [Switch]$EnableAutoUpdate = $false # if set to $true, RainbowMiner will trigger the update process, as soon as a new release is published
)

Clear-Host

$Version = "3.8.4.2"
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

if ($UseTimeSync) {Test-TimeSync}

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

[hashtable]$Updatetracker = @{
    Config = [hashtable]@{ConfigFile=0;PoolsConfigFile=0;MinersConfigFile=0}
    APIs = [hashtable]@{}
}

if (-not $psISE) {
    $MyCommandParameters = $MyInvocation.MyCommand.Parameters.Keys | Where-Object {$_ -and $_ -ne "ConfigFile" -and (Get-Variable $_ -ErrorAction SilentlyContinue)}
}
if (-not $MyCommandParameters) {
    $MyCommandParameters = @("Wallet","UserName","WorkerName","API_ID","API_Key","Interval","Region","SSL","DeviceName","Algorithm","MinerName","ExcludeAlgorithm","ExcludeMinerName","PoolName","ExcludePoolName","ExcludeCoin","ExcludeCoinSymbol","Currency","Donate","Proxy","Delay","Watchdog","MinerStatusUrl","MinerStatusKey","SwitchingPrevention","ShowMinerWindow","FastestMinerOnly","IgnoreFees","ExcludeMinersWithFee","ShowPoolBalances","DisableDualMining","RemoteAPI","RebootOnGPUFailure","MiningMode","MSIApath","MSIAprofile","UIstyle","UseTimeSync","PowerPrice","PowerPriceCurrency","UsePowerPrice","CheckProfitability","DisableExtendInterval","EthPillEnable","EnableOCProfiles","EnableAutoUpdate")
}

#Cleanup the log
if (Test-Path ".\Logs"){
    Get-ChildItem -Path ".\Logs" -Filter "*" | Where-Object {$_.LastWriteTime -lt (Get-Date).AddDays(-5)} | Remove-Item -ErrorAction Ignore
} else {
    New-Item ".\Logs" -ItemType "directory" -Force > $null
}

#Start the log
if (-not $psISE) {Start-Transcript ".\Logs\RainbowMiner_$(Get-Date -Format "yyyy-MM-dd_HH-mm-ss").txt"}

#Start the async loader
Start-AsyncLoader

Write-Log "Starting RainbowMiner v$Version"

#Set process priority to BelowNormal to avoid hash rate drops on systems with weak CPUs
(Get-Process -Id $PID).PriorityClass = "BelowNormal"

Write-Host "Detecting devices .."
$AllDevices = Get-Device "cpu","gpu"

Write-Host "Initialize configuration .."
try {
    $ConfigPath = [IO.Path]::GetDirectoryName($ConfigFile)
    if (-not $ConfigPath) {$ConfigPath = ".\Config"; $ConfigFile = "$($ConfigPath)\$($ConfigFile)"}
    if (-not (Test-Path $ConfigPath)) {New-Item $ConfigPath -ItemType "directory" -Force > $null}
    if (-not [IO.Path]::GetExtension($ConfigFile)) {$ConfigFile = "$($ConfigFile).txt"}   
    if (-not (Test-Path $ConfigFile)) {
        $Parameters = @{VersionCompatibility=$Version}
        $MyCommandParameters | ForEach-Object {$Parameters | Add-Member $_ "`$$($_)" -ErrorAction SilentlyContinue}
        $Parameters | ConvertTo-Json | Set-Content $ConfigFile -Encoding utf8
    } else {
        $ConfigForUpdate = Get-Content $ConfigFile | ConvertFrom-Json
        $ConfigForUpdate_changed = $false
        Compare-Object @($ConfigForUpdate.PSObject.Properties.Name) @($MyCommandParameters) | Foreach-Object {
            if ($_.SideIndicator -eq "=>") {$ConfigForUpdate | Add-Member $_.InputObject "`$$($_.InputObject)";$ConfigForUpdate_changed=$true}
            elseif ($_.SideIndicator -eq "<=" -and @("ConfigFile","ExcludeNegativeProfit","DisableAutoUpdate","Regin","Debug","Verbose","ErrorAction","WarningAction","InformationAction","ErrorVariable","WarningVariable","InformationVariable","OutVariable","OutBuffer","PipelineVariable") -icontains $_.InputObject) {$ConfigForUpdate.PSObject.Properties.Remove($_.InputObject);$ConfigForUpdate_changed=$true}
        }
        if ($ConfigForUpdate_changed) {$ConfigForUpdate | ConvertTo-Json | Set-Content $ConfigFile -Encoding utf8}
    }
    $ConfigFile = Get-Item $ConfigFile | Foreach-Object {
        $ConfigFile_Path = $_ | Select-Object -ExpandProperty DirectoryName
        $ConfigFile_Name = $_ | Select-Object -ExpandProperty Name
        $PoolsConfigFile = @($ConfigFile_Path,"\pools.",$ConfigFile_Name) -join ''
        $MinersConfigFile = @($ConfigFile_Path,"\miners.",$ConfigFile_Name) -join ''
        $DevicesConfigFile = @($ConfigFile_Path,"\devices.",$ConfigFile_Name) -join ''
        $OCProfilesConfigFile = @($ConfigFile_Path,"\ocprofiles.",$ConfigFile_Name) -join ''
        
        # Create pools.config.txt if it is missing
        Set-PoolsConfigDefault -PathToFile $PoolsConfigFile -Force
        $PoolsConfigFile = $PoolsConfigFile | Resolve-Path -Relative

        # Create miners.config.txt if it is missing
        Set-MinersConfigDefault -PathToFile $MinersConfigFile -Force
        $MinersConfigFile = $MinersConfigFile | Resolve-Path -Relative

        # Create devices.config.txt if it is missing
        Set-DevicesConfigDefault -PathToFile $DevicesConfigFile -Force
        $DevicesConfigFile = $DevicesConfigFile | Resolve-Path -Relative

        # Create ocprofiles.config.txt if it is missing
        Set-OCProfilesConfigDefault -PathToFile $OCProfilesConfigFile -Force
        $OCProfilesConfigFile = $OCProfilesConfigFile | Resolve-Path -Relative

        $_ | Resolve-Path -Relative
    }

    #cleanup legacy data
    if (Test-Path ".\Cleanup.ps1") {
        Write-Host "Cleanup legacy data .."
        [hashtable]$Cleanup_Parameters = @{
            ConfigFile = $ConfigFile
            PoolsConfigFile = $PoolsConfigFile
            MinersConfigFile = $MinersConfigFile
            DevicesConfigFile = $DevicesConfigFile
            OCProfilesConfigFile = $OCProfilesConfigFile
            AllDevices = $AllDevices
            MyCommandParameters = $MyCommandParameters
            Version = if (Test-Path ".\Data\Version.json") {(Get-Content ".\Data\Version.json" -Raw | ConvertFrom-Json -ErrorAction Ignore).Version}else{"0.0.0.0"}
        }        
        Get-Item ".\Cleanup.ps1" | Foreach-Object {
            $Cleanup_Result = & {
                foreach ($k in $Cleanup_Parameters.Keys) {Set-Variable $k $Cleanup_Parameters.$k}
                & $_.FullName @Cleanup_Parameters
            }
            if ($Cleanup_Result) {Write-Host $Cleanup_Result}
        }
        Remove-Item ".\Cleanup.ps1" -Force
    }

    #write version to data
    [PSCustomObject]@{Version=$Version} | ConvertTo-Json | Set-Content ".\Data\Version.json" -Encoding utf8
}
catch {
    Write-Log -Level Error "$($_) Cannot run RainbowMiner. "
    Exit
}

if (Get-Command "Unblock-File" -ErrorAction SilentlyContinue) {Get-ChildItem . -Recurse | Unblock-File}
if ((Get-Command "Get-MpPreference" -ErrorAction SilentlyContinue) -and (Get-MpComputerStatus -ErrorAction SilentlyContinue) -and (Get-MpPreference).ExclusionPath -notcontains (Convert-Path .)) {
    Start-Process (@{desktop = "powershell"; core = "pwsh"}.$PSEdition) "-Command Import-Module '$env:Windir\System32\WindowsPowerShell\v1.0\Modules\Defender\Defender.psd1'; Add-MpPreference -ExclusionPath '$(Convert-Path .)'" -Verb runAs
}

Write-Host "Start afterburner library .."
Start-Afterburner

#[console]::TreatControlCAsInput = $true

while ($true) {
    #Load the config
    $ConfigBackup = if ($Config -is [object]){$Config.PSObject.Copy()}else{$null}
    $ConfigCheckFields = $true
    
    [string[]]$AvailPools = Get-ChildItem ".\Pools\*.ps1" -File | Select-Object -ExpandProperty BaseName | Sort-Object
    [string[]]$AvailMiners = Get-ChildItem ".\Miners\*.ps1" -File | Select-Object -ExpandProperty BaseName | Sort-Object

    if (Test-Path $ConfigFile) {
        if (-not $Config -or $RunSetup -or (Get-ChildItem $ConfigFile).LastWriteTime.ToUniversalTime() -gt $UpdateTracker["Config"]["ConfigFile"]) {        

            do {
                if ($Config -eq $null) {Write-Host "Read configuration .."}
                $UpdateTracker["Config"]["ConfigFile"] = (Get-ChildItem $ConfigFile).LastWriteTime.ToUniversalTime()
                $Parameters = @{}
                $MyCommandParameters | ForEach-Object {
                    $val = Get-Variable $_ -ValueOnly -ErrorAction SilentlyContinue
                    if ($val -is [array]) {$val = $val -join ','}
                    $Parameters.Add($_ , $val)
                }
                $Config = Get-ChildItemContent $ConfigFile -Force -Parameters $Parameters | Select-Object -ExpandProperty Content
                $Config | Add-Member Pools ([PSCustomObject]@{}) -Force
                $Config | Add-Member Miners ([PSCustomObject]@{}) -Force
                $Config | Add-Member OCProfiles ([PSCustomObject]@{}) -Force

                if (-not $Config.Wallet -or -not $Config.WorkerName -or -not $Config.PoolName -or -not $Config.Algorithm) {
                    $IsInitialSetup = $true
                    $RunSetup = $true
                }

                $ReReadConfig = $false

                if ($RunSetup) {

                    [System.Collections.ArrayList]$SetupMessage = @()

                    do {
                        $ConfigActual = Get-Content $ConfigFile | ConvertFrom-Json
                        $MinersActual = Get-Content $MinersConfigFile | ConvertFrom-Json
                        $PoolsActual = Get-Content $PoolsConfigFile | ConvertFrom-Json
                        $DevicesActual = Get-Content $DevicesConfigFile | ConvertFrom-Json
                        $OCProfilesActual = Get-Content $OCProfilesConfigFile | ConvertFrom-Json
                        $SetupDevices = Get-Device "nvidia","amd","cpu"

                        Clear-Host
              
                        if ($SetupMessage.Count -gt 0) {
                            Write-Host " "
                            foreach($m in $SetupMessage) {
                                Write-Host $m -ForegroundColor Cyan
                            }
                            Write-Host " "
                            $SetupMessage.Clear()
                        }

                        Write-Host " "
                        Write-Host "*** RainbowMiner Configuration ***" -BackgroundColor Green -ForegroundColor Black
                        Write-Host " "

                        if ($IsInitialSetup) {
                            $SetupType = "A" 
                            $ConfigSetup = Get-ChildItemContent ".\Data\ConfigDefault.ps1" | Select-Object -ExpandProperty Content
                            $ConfigSetup.PSObject.Properties | Where-Object Membertype -eq NoteProperty | Select-Object Name,Value | Foreach-Object {
                                $ConfigSetup_Name = $_.Name
                                $val = $_.Value
                                if ($val -is [array]) {$val = $val -join ','}
                                if ($val -is [bool] -or -not $Config.$ConfigSetup_Name) {$Config | Add-Member $ConfigSetup_Name $val -Force}
                            }

                        } else {
                            Write-Host "Please choose, what to configure:" -ForegroundColor Yellow
                            Write-Host " "
                            Write-Host "- Wallet: setup wallet addresses, worker- and username, API-keys" -ForegroundColor Yellow
                            Write-Host "- Common: setup the most common RainbowMiner settings and flags" -ForegroundColor Yellow
                            Write-Host "- Energycosts: setup energy consumtion values" -ForegroundColor Yellow
                            Write-Host "- Selection: select which pools, miners, algorithm to use" -ForegroundColor Yellow
                            Write-Host "- All: step through the full setup, configuring all" -ForegroundColor Yellow
                            Write-Host "- Miners: finetune miners, add commandline arguments, penalty values and more (only for the technical savy user)" -ForegroundColor Yellow
                            Write-Host "- Pools: finetune pools, add different coin wallets, penalty values and more" -ForegroundColor Yellow
                            Write-Host "- Devices: finetune devices, select algorithms, coins and more" -ForegroundColor Yellow
                            Write-Host "- OC-Profiles: create or edit overclocking profiles" -ForegroundColor Yellow
                            Write-Host " "
                            $SetupType = Read-HostString -Prompt "[W]allets, [C]ommon, [E]nergycosts, [S]elections, [A]ll, [M]iners, [P]ools, [D]evices, [O]C-Profiles, E[x]it configuration and start mining" -Default "X"  -Mandatory -Characters "WCESAMPDOX"
                        }

                        if ($SetupType -eq "X") {
                            $RunSetup = $false
                        }
                        elseif (@("W","C","E","S","A") -contains $SetupType) {
                            
                            $GlobalSetupDone = $false
                            $GlobalSetupStep = 0
                            [System.Collections.ArrayList]$GlobalSetupSteps = @()
                            [System.Collections.ArrayList]$GlobalSetupStepBack = @()

                            Switch ($SetupType) {
                                "W" {$GlobalSetupName = "Wallet";$GlobalSetupSteps.AddRange(@("wallet","nicehash","workername","username","apiid","apikey")) > $null}
                                "C" {$GlobalSetupName = "Common";$GlobalSetupSteps.AddRange(@("miningmode","devicename","devicenameend","region","currency","uistyle","fastestmineronly","showpoolbalances","showminerwindow","ignorefees","enableocprofiles","msia","msiapath","ethpillenable","enableautoupdate")) > $null}
                                "E" {$GlobalSetupName = "Energycost";$GlobalSetupSteps.AddRange(@("powerpricecurrency","powerprice","usepowerprice","checkprofitability")) > $null}
                                "S" {$GlobalSetupName = "Selection";$GlobalSetupSteps.AddRange(@("poolname","minername","excludeminername","excludeminerswithfee","disabledualmining","algorithm","excludealgorithm","excludecoinsymbol","excludecoin")) > $null}
                                "A" {$GlobalSetupName = "All";$GlobalSetupSteps.AddRange(@("wallet","nicehash","workername","username","apiid","apikey","region","currency","enableautoupdate","poolname","minername","excludeminername","algorithm","excludealgorithm","excludecoinsymbol","excludecoin","disabledualmining","excludeminerswithfee","devicenamebegin","miningmode","devicename","devicenamewizard","devicenamewizardgpu","devicenamewizardamd1","devicenamewizardamd2","devicenamewizardnvidia1","devicenamewizardnvidia2","devicenamewizardcpu1","devicenamewizardcpu2","devicenamewizardend","devicenameend","uistyle","fastestmineronly","showpoolbalances","showminerwindow","ignorefees","watchdog","enableocprofiles","msia","msiapath","ethpillenable","proxy","delay","interval","disableextendinterval","switchingprevention","usetimesync","powerpricecurrency","powerprice","usepowerprice","checkprofitability","donate")) > $null}
                            }
                            $GlobalSetupSteps.Add("save") > $null                            

                            if (-not $IsInitialSetup) {
                                Clear-Host
                                Write-Host " "
                                Write-Host "*** $GlobalSetupName Configuration ***" -BackgroundColor Green -ForegroundColor Black
                            }
                            Write-HostSetupHints

                            if ($PoolsActual | Get-Member Nicehash -MemberType NoteProperty) {
                                $NicehashWallet = $PoolsActual.Nicehash.BTC
                                $NicehashWorkerName = $PoolsActual.Nicehash.Worker
                            } else {
                                $NicehashWallet = "`$Wallet"
                                $NicehashWorkerName = "`$WorkerName"
                            }

                            do {
                                $GlobalSetupStepStore = $true
                                try {
                                   Switch ($GlobalSetupSteps[$GlobalSetupStep]) {
                                        "wallet" {                
                                            if ($SetupType -eq "A") {
                                                # Start setup procedure
                                                Write-Host ' '
                                                Write-Host '(1) Basic Setup' -ForegroundColor Green
                                                Write-Host ' '
                                            }
                                                                             
                                            if ($IsInitialSetup) {
                                                Write-Host " "
                                                Write-Host "At first, please lookup your BTC wallet address, you want to mine to. It is easy: copy it into your clipboard and then press the right mouse key in this window to paste" -ForegroundColor Cyan
                                                Write-Host " "
                                            }
                                            $Config.Wallet = Read-HostString -Prompt "Enter your BTC wallet address" -Default $Config.Wallet -Length 34 -Mandatory -Characters "A-Z0-9" | Foreach-Object {if (@("cancel","exit","back","<") -icontains $_) {throw $_};$_}
                                        }

                                        "nicehash" {
                                            if ($IsInitialSetup) {
                                                Write-Host " "
                                                Write-Host "If you plan to mine using the Nicehash-pool, I recommend you register an account with them, to get a NiceHash wallet address (please read the Pools section of our readme!). I would not mine to your standard wallet ($($Config.Wallet)), since Nicehash has a minimum payout amount of 0.1BTC (compared to 0.001BTC, when using their wallet). " -ForegroundColor Cyan
                                                Write-Host "If you do not want to use Nicehash as a pool, leave this empty (or enter `"clear`" to make it empty) and press return " -ForegroundColor Cyan
                                                Write-Host " "
                                            }

                                            if ($NicehashWallet -eq "`$Wallet"){$NicehashWallet=$Config.Wallet}
                                            $NicehashWallet = Read-HostString -Prompt "Enter your NiceHash-BTC wallet address" -Default $NicehashWallet -Length 34 -Characters "A-Z0-9" | Foreach-Object {if (@("cancel","exit","back","<") -icontains $_) {throw $_};$_}

                                            if ($NiceHashWallet -eq "`$Wallet" -or $NiceHashWallet -eq $Config.Wallet) {
                                                if (Read-HostBool "You have entered your default wallet as Nicehash wallet. NiceHash will have a minimum payout of 0.1BTC. Do you want to disable NiceHash mining for now?" -Default $true) {
                                                    $NiceHashWallet = ''
                                                }
                                            }
                                            
                                            $Config.PoolName = if ($Config.PoolName -ne ''){[regex]::split($Config.PoolName.Trim(),"\s*[,;:]+\s*")}else{@()}
                                            if (-not $NicehashWallet) {
                                                $Config.PoolName = $Config.PoolName | Where-Object {$_ -ne "NiceHash"}
                                                $NicehashWallet = "`$Wallet"
                                            } elseif ($Config.PoolName -inotcontains "NiceHash") {
                                                $Config.PoolName = @($Config.PoolName | Select-Object) + @("NiceHash") | Select-Object -Unique
                                            }
                                            $Config.PoolName = $Config.PoolName -join ','
                                        }

                                        "workername" {
                                            if ($IsInitialSetup) {
                                                Write-Host " "
                                                Write-Host "Every pool (except the MiningPoolHub) wants the miner to send a worker's name. You can change the name later. Please enter only letters and numbers. " -ForegroundColor Cyan
                                                Write-Host " "
                                            }
                                            $Config.WorkerName = Read-HostString -Prompt "Enter your worker name" -Default $Config.WorkerName -Mandatory -Characters "A-Z0-9" | Foreach-Object {if (@("cancel","exit","back","<") -icontains $_) {throw $_};$_}
                                        }

                                        "username" {
                                            if ($IsInitialSetup) {
                                                Write-Host " "
                                                Write-Host "If you plan to use MiningPoolHub for mining, you will have to register an account with them and choose a username. Enter this username now, or leave empty to disable MiningPoolHub (can be activated, later) " -ForegroundColor Cyan
                                                Write-Host " "
                                            }
                                            $Config.UserName = Read-HostString -Prompt "Enter your Miningpoolhub user name" -Default $Config.UserName -Characters "A-Z0-9" | Foreach-Object {if (@("cancel","exit","back","<") -icontains $_) {throw $_};$_}

                                            $Config.PoolName = if ($Config.PoolName -ne ''){[regex]::split($Config.PoolName.Trim(),"\s*[,;:]+\s*")}else{@()}
                                            if (-not $Config.UserName) {
                                                $Config.PoolName = $Config.PoolName | Where-Object {$_ -notlike "MiningPoolHub*"}                                                
                                            } elseif ($Config.PoolName -inotcontains "MiningPoolHub") {
                                                $Config.PoolName = @($Config.PoolName | Select-Object) + @("MiningPoolHub") | Select-Object -Unique
                                            }
                                            $Config.PoolName = $Config.PoolName -join ','
                                            if ($IsInitialSetup -and -not $Config.UserName -and $GlobalSetupSteps.Contains("region")) {throw "Goto region"}
                                        }

                                        "apiid" {
                                            if ($IsInitialSetup) {
                                                Write-Host " "
                                                Write-Host "You will mine on MiningPoolHub as $($Config.UserName). If you want to see your balance in RainbowMiner, you can now enter your USER ID (a number) and the API KEY. You find these two values on MiningPoolHub's `"Edit account`" page. " -ForegroundColor Cyan
                                                Write-Host " "
                                            }
                                            $Config.API_ID = Read-HostString -Prompt "Enter your Miningpoolhub USER ID (found on `"Edit account`" page)" -Default $Config.API_ID -Characters "0-9" | Foreach-Object {if (@("cancel","exit","back","<") -icontains $_) {throw $_};$_}
                                        }

                                        "apikey" {
                                            $Config.API_Key = Read-HostString -Prompt "Enter your Miningpoolhub API KEY (found on `"Edit account`" page)" -Default $Config.API_Key -Characters "0-9a-f" | Foreach-Object {if (@("cancel","exit","back","<") -icontains $_) {throw $_};$_}
                                        }

                                        "region" {
                                            if ($IsInitialSetup) {
                                                Write-Host " "
                                                Write-Host "Choose the region, you live in, from this list (remember: you can always simply accept the default by pressing return): " -ForegroundColor Cyan
                                                @(Get-Regions) | Foreach-Object {Write-Host " $($_)" -ForegroundColor Cyan}
                                                Write-Host " "
                                            }
                                            $Config.Region = Read-HostString -Prompt "Enter your region" -Default $Config.Region -Mandatory -Characters "A-Z" -Valid @(Get-Regions) | Foreach-Object {if (@("cancel","exit","back","<") -icontains $_) {throw $_};$_}
                                        }

                                        "currency" {
                                            $Config.Currency = Read-HostArray -Prompt "Enter all currencies to be displayed (e.g. EUR,USD,BTC)" -Default $Config.Currency -Mandatory -Characters "A-Z" | Foreach-Object {if (@("cancel","exit","back","<") -icontains $_) {throw $_};$_}
                                        }

                                        "poolname" {
                                            if ($SetupType -eq "A") {
                                                Write-Host ' '
                                                Write-Host '(2) Select your pools, miners and algorithm (be sure you read the notes in the README.md)' -ForegroundColor Green
                                                Write-Host ' '
                                            }

                                            if ($IsInitialSetup) {
                                                Write-Host " "
                                                Write-Host "Choose your mining pools from this list or accept the default for a head start (read the Pools section of our readme for more details): " -ForegroundColor Cyan
                                                $AvailPools | Foreach-Object {Write-Host " $($_)" -ForegroundColor Cyan}
                                                Write-Host " "
                                            }
                                            $Config.PoolName = Read-HostArray -Prompt "Enter the pools you want to mine" -Default $Config.PoolName -Mandatory -Characters "A-Z0-9" -Valid $AvailPools | Foreach-Object {if (@("cancel","exit","back","<") -icontains $_) {throw $_};$_}
                                            $Config.ExcludePoolName = $AvailPools | Where-Object {$Config.PoolName -inotcontains $_}                                            
                                        }
                                        "excludepoolname" {
                                            $Config.ExcludePoolName = Read-HostArray -Prompt "Enter the pools you do want to exclude from mining" -Default $Config.ExcludePoolName -Characters "A-Z0-9" -Valid $AvailPools | Foreach-Object {if (@("cancel","exit","back","<") -icontains $_) {throw $_};$_}
                                        }
                                        "minername" {
                                            if ($IsInitialSetup) {
                                                Write-Host " "
                                                Write-Host "You are almost done :) Our defaults for miners and algorithms give you a good start. If you want, you can skip the settings for now " -ForegroundColor Cyan
                                                Write-Host " "

                                                if (Read-HostBool -Prompt "Do you want to skip the miner and algorithm setup?" -Default $true) {throw "Goto devicenamebegin"}
                                            }
                                            $Config.MinerName = Read-HostArray -Prompt "Enter the miners your want to use (leave empty for all)" -Default $Config.MinerName -Characters "A-Z0-9.-_" -Valid $AvailMiners | Foreach-Object {if (@("cancel","exit","back","<") -icontains $_) {throw $_};$_}
                                        }
                                        "excludeminername" {
                                            $Config.ExcludeMinerName = Read-HostArray -Prompt "Enter the miners you do want to exclude" -Default $Config.ExcludeMinerName -Characters "A-Z0-9\.-_" -Valid $AvailMiners | Foreach-Object {if (@("cancel","exit","back","<") -icontains $_) {throw $_};$_}
                                        }
                                        "algorithm" {
                                            $Config.Algorithm = Read-HostArray -Prompt "Enter the algorithm you want to mine (leave empty for all)" -Default $Config.Algorithm -Characters "A-Z0-9" -Valid (Get-Algorithms) | Foreach-Object {if (@("cancel","exit","back","<") -icontains $_) {throw $_};$_}
                                        }
                                        "excludealgorithm" {
                                            $Config.ExcludeAlgorithm = Read-HostArray -Prompt "Enter the algorithm you do want to exclude (leave empty for none)" -Default $Config.ExcludeAlgorithm -Characters "A-Z0-9" -Valid (Get-Algorithms) | Foreach-Object {if (@("cancel","exit","back","<") -icontains $_) {throw $_};$_}
                                        }
                                        "excludecoinsymbol" {
                                            $Config.ExcludeCoinSymbol = Read-HostArray -Prompt "Enter the name of coins by currency symbol, you want to globaly exclude (leave empty for none)" -Default $Config.ExcludeCoinSymbol -Characters "\`$A-Z0-9" | Foreach-Object {if (@("cancel","exit","back","<") -icontains $_) {throw $_};$_}
                                        }
                                        "excludecoin" {
                                            $Config.ExcludeCoin = Read-HostArray -Prompt "Enter the name of coins by name, you want to globaly exclude (leave empty for none)" -Default $Config.ExcludeCoin -Characters "`$A-Z0-9. " | Foreach-Object {if (@("cancel","exit","back","<") -icontains $_) {throw $_};$_}
                                        }
                                        "disabledualmining" {
                                            $Config.DisableDualMining = Read-HostBool -Prompt "Disable all dual mining algorithm" -Default $Config.DisableDualMining | Foreach-Object {if (@("cancel","exit","back","<") -icontains $_) {throw $_};$_}
                                        }
                                        "excludeminerswithfee" {
                                            $Config.ExcludeMinersWithFee = Read-HostBool -Prompt "Exclude all miners with developer fee" -Default $Config.ExcludeMinersWithFee | Foreach-Object {if (@("cancel","exit","back","<") -icontains $_) {throw $_};$_}
                                        }
                                        "devicenamebegin" {
                                            $GlobalSetupStepStore = $false
                                            if ($SetupType -eq "A") {
                                                Write-Host ' '
                                                Write-Host '(3) Select the devices to mine on and miningmode' -ForegroundColor Green
                                                Write-Host ' '
                                            }
                                            if ($IsInitialSetup) {
                                                throw "Goto devicenamewizard"
                                            }
                                        }
                                        "miningmode" {
                                            $Config.MiningMode = Read-HostString "Select mining mode (legacy/device/combo)" -Default $Config.MiningMode -Mandatory -Characters "A-Z" | Foreach-Object {if (@("cancel","exit","back","<") -icontains $_) {throw $_};$_}
                                            if ($Config.MiningMode -like "l*") {$Config.MiningMode="legacy"}
                                            elseif ($Config.MiningMode -like "c*") {$Config.MiningMode="combo"}
                                            else {$Config.MiningMode="device"}
                                        }
                                        "devicename" {
                                            $Config.DeviceName = Read-HostArray -Prompt "Enter the devices you want to use for mining (leave empty for all)" -Default $Config.DeviceName -Characters "A-Z0-9#" -Valid @($AllDevices | Foreach-Object {$_.Type.ToUpper();if ($Config.MiningMode -eq "legacy") {if (@("nvidia","amd") -icontains $_.Vendor) {$_.Vendor}} else {if (@("nvidia","amd") -icontains $_.Vendor) {$_.Vendor;$_.Model};$_.Name}} | Select-Object -Unique | Sort-Object) | Foreach-Object {if (@("cancel","exit","back","<") -icontains $_) {throw $_};$_}
                                            if ($GlobalSetupSteps.Contains("devicenameend")) {throw "Goto devicenameend"}
                                        }
                                        "devicenamewizard" {
                                            $GlobalSetupStepStore = $false
                                            $Config.DeviceName = @("GPU")                                            
                                            [hashtable]$NewDeviceName = @{}
                                            [hashtable]$AvailDeviceCounts = @{}
                                            $AvailDeviceGPUVendors = @($AllDevices | Where-Object {$_.Type -eq "gpu" -and @("nvidia","amd") -icontains $_.Vendor} | Select-Object -ExpandProperty Vendor -Unique | Sort-Object)
                                            $AvailDevicecounts["CPU"] = @($AllDevices | Where-Object {$_.Type -eq "cpu"} | Select-Object -ExpandProperty Name -Unique | Sort-Object).Count
                                            $AvailDeviceCounts["GPU"] = 0

                                            if ($AvailDeviceGPUVendors.Count -eq 0) {throw "Goto devicenamewizardcpu1"}  
                                                                                      
                                            foreach ($p in $AvailDeviceGPUVendors) {
                                                $NewDeviceName[$p] = @()
                                                $AvailDevicecounts[$p] = @($AllDevices | Where-Object {$_.Type -eq "gpu" -and $_.Vendor -eq $p} | Select-Object -ExpandProperty Name -Unique | Sort-Object).Count
                                                $AvailDeviceCounts["GPU"] += $AvailDevicecounts[$p]
                                            }
                                        }
                                        "devicenamewizardgpu" {
                                            if ($AvailDeviceGPUVendors.Count -eq 1 -and $AvailDeviceCounts["GPU"] -gt 1) {
                                                $GlobalSetupStepStore = $false
                                                throw "Goto devicenamewizard$($p.ToLower())1"
                                            }
                                            if ($AvailDeviceCounts["GPU"] -eq 1) {
                                                if (Read-HostBool -Prompt "Mine on your $($AllDevices | Where-Object {$_.Type -eq "gpu" -and $_.Vendor -eq $p} | Select -ExpandProperty Model_Name -Unique)" -Default $true | Foreach-Object {if (@("cancel","exit","back","<") -icontains $_) {throw $_};$_}) {
                                                    $NewDeviceName[$p] = $p
                                                }
                                                throw "Goto devicenamewizardcpu1"
                                            }
                                            if (Read-HostBool -Prompt "Mine on all available GPU ($($AvailDeviceGPUVendors -join '&'), choose no to select devices)" -Default $true | Foreach-Object {if (@("cancel","exit","back","<") -icontains $_) {throw $_};$_}) {
                                                foreach ($p in $AvailDeviceGPUVendors) {$NewDeviceName[$p] = @($p)}
                                                throw "Goto devicenamewizardcpu1"
                                            }
                                        }
                                        "devicenamewizardamd1" {
                                            $NewDeviceName["AMD"] = @()
                                            if ($AvailDeviceCounts["AMD"] -gt 1) {
                                                if (Read-HostBool -Prompt "Do you want to mine on all AMD GPUs" -Default $true | Foreach-Object {if (@("cancel","exit","back","<") -icontains $_) {throw $_};$_}) {
                                                    $NewDeviceName["AMD"] = @("AMD")
                                                }
                                            } else {
                                                $GlobalSetupStepStore = $false
                                            }
                                        }
                                        "devicenamewizardamd2" {
                                            if ($AvailDeviceCounts["AMD"] -gt 1 -and $NewDeviceName["AMD"].Count -eq 0) {
                                                $NewDeviceName["AMD"] = Read-HostArray -Prompt "Enter the AMD devices you want to use for mining (leave empty for none)" -Characters "A-Z0-9#" -Valid @($AllDevices | Where-Object {$_.Vendor -eq "AMD" -and $_.Type -eq "GPU"} | Foreach-Object {$_.Vendor;$_.Model;$_.Name} | Select-Object -Unique | Sort-Object) | Foreach-Object {if (@("cancel","exit","back","<") -icontains $_) {throw $_};$_}
                                            } else {
                                                $GlobalSetupStepStore = $false
                                            }
                                        }
                                        "devicenamewizardnvidia1" {
                                            $NewDeviceName["NVIDIA"] = @()
                                            if ($AvailDeviceCounts["NVIDIA"] -gt 1) {
                                                if (Read-HostBool -Prompt "Do you want to mine on all NVIDIA GPUs" -Default $true | Foreach-Object {if (@("cancel","exit","back","<") -icontains $_) {throw $_};$_}) {
                                                    $NewDeviceName["NVIDIA"] = @("NVIDIA")
                                                }
                                            } else {
                                                $GlobalSetupStepStore = $false
                                            }
                                        }
                                        "devicenamewizardnvidia2" {
                                            if ($AvailDeviceCounts["NVIDIA"] -gt 1 -and $NewDeviceName["NVIDIA"].Count -eq 0) {
                                                $NewDeviceName["NVIDIA"] = Read-HostArray -Prompt "Enter the NVIDIA devices you want to use for mining (leave empty for none)" -Characters "A-Z0-9#" -Valid @($AllDevices | Where-Object {$_.Vendor -eq "NVIDIA" -and $_.Type -eq "GPU"} | Foreach-Object {$_.Vendor;$_.Model;$_.Name} | Select-Object -Unique | Sort-Object) | Foreach-Object {if (@("cancel","exit","back","<") -icontains $_) {throw $_};$_}
                                            } else {
                                                $GlobalSetupStepStore = $false
                                            }
                                        }
                                        "devicenamewizardcpu1" {
                                            $NewDeviceName["CPU"] = @()
                                            if (Read-HostBool -Prompt "Do you want to mine on $(if ($AvailDeviceCounts["cpu"] -gt 1){"all CPUs"}else{"your CPU"})" -Default $false | Foreach-Object {if (@("cancel","exit","back","<") -icontains $_) {throw $_};$_}) {
                                                $NewDeviceName["CPU"] = @("CPU")
                                            }
                                        }
                                        "devicenamewizardcpu2" {
                                            if ($AvailDeviceCounts["CPU"] -gt 1 -and $NewDeviceName["CPU"].Count -eq 0) {
                                                $NewDeviceName["CPU"] = Read-HostArray -Prompt "Enter the CPUs you want to use for mining (leave empty for none)" -Characters "A-Z0-9#" -Valid @($AllDevices | Where-Object {$_.Type -eq "CPU"} | Select-Object -ExpandProperty Name -Unique | Sort-Object) | Foreach-Object {if (@("cancel","exit","back","<") -icontains $_) {throw $_};$_}
                                            } else {
                                                $GlobalSetupStepStore = $false
                                            }
                                        }
                                        "devicenamewizardend" {
                                            $GlobalSetupStepStore = $false
                                            $Config.DeviceName = @($NewDeviceName.Values | Foreach-Object {$_} | Foreach-Object {$_} | Select-Object -Unique | Sort-Object)
                                            if ($Config.DeviceName.Count -eq 0) {
                                                Write-Host " "
                                                Write-Host "No devices selected. You cannot mine without devices. Restarting device input" -ForegroundColor Yellow
                                                Write-Host " "
                                                $GlobalSetupStepBack = $GlobalSetupStepBack.Where({$_ -notmatch "^devicenamewizard"})                                                
                                                throw "Goto devicenamewizard"
                                            }                                            
                                        }
                                        "devicenameend" {
                                            $GlobalSetupStepStore = $false
                                            if ($IsInitialSetup) {throw "Goto save"}
                                        }
                                        "uistyle" {
                                            if ($SetupType -eq "A") {
                                                Write-Host ' '
                                                Write-Host '(4) Select desired output' -ForegroundColor Green
                                                Write-Host ' '
                                            }

                                            $Config.UIstyle = Read-HostString -Prompt "Select style of user interface (full/lite)" -Default $Config.UIstyle -Mandatory -Characters "A-Z" | Foreach-Object {if (@("cancel","exit","back","<") -icontains $_) {throw $_};$_}
                                            if ($Config.UIstyle -like "l*"){$Config.UIstyle="lite"}else{$Config.UIstyle="full"}   
                                        }
                                        "fastestmineronly" {
                                            $Config.FastestMinerOnly = Read-HostBool -Prompt "Show fastest miner only" -Default $Config.FastestMinerOnly | Foreach-Object {if (@("cancel","exit","back","<") -icontains $_) {throw $_};$_}
                                        }
                                        "showpoolbalances" {
                                            $Config.ShowPoolBalances = Read-HostBool -Prompt "Show all available pool balances" -Default $Config.ShowPoolBalances | Foreach-Object {if (@("cancel","exit","back","<") -icontains $_) {throw $_};$_}
                                        }
                                        "showminerwindow" {
                                            $Config.ShowMinerWindow = Read-HostBool -Prompt "Show miner in own windows (will steal your focus, not recommended)" -Default $Config.ShowMinerWindow | Foreach-Object {if (@("cancel","exit","back","<") -icontains $_) {throw $_};$_}
                                        }
                                        "ignorefees" {
                                            if ($SetupType -eq "A") {
                                                Write-Host ' '
                                                Write-Host '(5) Setup other / technical' -ForegroundColor Green
                                                Write-Host ' '
                                            }

                                            $Config.IgnoreFees = Read-HostBool -Prompt "Ignore Pool/Miner developer fees" -Default $Config.IgnoreFees | Foreach-Object {if (@("cancel","exit","back","<") -icontains $_) {throw $_};$_}
                                        }
                                        "watchdog" {
                                            $Config.Watchdog = Read-HostBool -Prompt "Enable watchdog" -Default $Config.Watchdog | Foreach-Object {if (@("cancel","exit","back","<") -icontains $_) {throw $_};$_}
                                        }
                                        "msia" {
                                            $GlobalSetupStepStore = $false
                                            if (-not $Config.EnableOCProfiles) {
                                                $Config.MSIAprofile = Read-HostInt -Prompt "Enter default MSI Afterburner profile (0 to disable all MSI profile action)" -Default $Config.MSIAprofile -Min 0 -Max 5 | Foreach-Object {if (@("cancel","exit","back","<") -icontains $_) {throw $_};$_}
                                                $GlobalSetupStepStore = $true                                                
                                            }
                                        }
                                        "msiapath" {
                                            $GlobalSetupStepStore = $false
                                            if (-not $Config.EnableOCProfiles -and $Config.MSIAprofile -gt 0) {
                                                $Config.MSIApath = Read-HostString -Prompt "Enter path to MSI Afterburner" -Default $Config.MSIApath -Characters '' | Foreach-Object {if (@("cancel","exit","back","<") -icontains $_) {throw $_};$_}
                                                if (-not (Test-Path $Config.MSIApath)) {Write-Host "MSI Afterburner not found at given path. Please try again or disable.";throw "Goto msiapath"}
                                                $GlobalSetupStepStore = $true
                                            }
                                        }
                                        "ethpillenable" {
                                            if ((Compare-Object @($SetupDevices.Model | Select-Object -Unique) @('GTX1080','GTX1080Ti','TITANXP') -ExcludeDifferent -IncludeEqual | Measure-Object).Count -gt 0) {
                                                $Config.EthPillEnable = Read-HostString -Prompt "Enable OhGodAnETHlargementPill https://bitcointalk.org/index.php?topic=3370685.0 (only when mining Ethash)" -Default $Config.EthPillEnable -Valid @('disable','RevA','RevB') | Foreach-Object {if (@("cancel","exit","back","<") -icontains $_) {throw $_};$_}
                                            } else {
                                                $GlobalSetupStepStore = $false
                                            }
                                        }
                                        "enableocprofiles" {
                                            $Config.EnableOCProfiles = Read-HostBool -Prompt "Enable custom overclocking profiles (MSI Afterburner profiles will be disabled)" -Default $Config.EnableOCProfiles | Foreach-Object {if (@("cancel","exit","back","<") -icontains $_) {throw $_};$_}
                                        }
                                        "enableautoupdate" {
                                            $Config.EnableAutoUpdate = Read-HostBool -Prompt "Enable automatic update, as soon as a new release is published" -Default $Config.EnableAutoUpdate | Foreach-Object {if (@("cancel","exit","back","<") -icontains $_) {throw $_};$_}
                                        }
                                        "proxy" {
                                            $Config.Proxy = Read-HostString -Prompt "Enter proxy address, if used" -Default $Config.Proxy -Characters "A-Z0-9:/\.%-_" | Foreach-Object {if (@("cancel","exit","back","<") -icontains $_) {throw $_};$_}
                                        }
                                        "interval" {
                                            $Config.Interval = Read-HostInt -Prompt "Enter the script's loop interval in seconds" -Default $Config.Interval -Mandatory -Min 30 | Foreach-Object {if (@("cancel","exit","back","<") -icontains $_) {throw $_};$_}
                                        }
                                        "delay" {
                                            $Config.Delay = Read-HostInt -Prompt "Enter the delay before each minerstart in seconds (set to a value > 0 if you experience BSOD)" -Default $Config.Delay -Min 0 -Max 10 | Foreach-Object {if (@("cancel","exit","back","<") -icontains $_) {throw $_};$_}
                                        }
                                        "disableextendinterval" {
                                            $Config.DisableExtendInterval = Read-HostBool -Prompt "Disable interval extension during benchmark (speeds benchmark up, but will be less accurate for some algorithm)" -Default $Config.DisableExtendInterval | Foreach-Object {if (@("cancel","exit","back","<") -icontains $_) {throw $_};$_}
                                        }
                                        "switchingprevention" {
                                            $Config.SwitchingPrevention = Read-HostInt -Prompt "Adjust switching prevention: the higher, the less switching of miners will happen (0 to disable)" -Default $Config.SwitchingPrevention -Min 0 -Max 10 | Foreach-Object {if (@("cancel","exit","back","<") -icontains $_) {throw $_};$_}
                                        }
                                        "usetimesync" {
                                            $Config.UseTimeSync = Read-HostBool -Prompt "Enable automatic time/NTP synchronization (needs admin rights)" -Default $Config.UseTimeSync | Foreach-Object {if (@("cancel","exit","back","<") -icontains $_) {throw $_};$_}
                                        }
                                        "powerpricecurrency" {
                                            $Config.PowerPriceCurrency = Read-HostString -Prompt "Enter currency of power price (e.g. USD,EUR,CYN)" -Default $Config.PowerPriceCurrency -Characters "A-Z" | Foreach-Object {if (@("cancel","exit","back","<") -icontains $_) {throw $_};$_}
                                        }
                                        "powerprice" {
                                            $Config.PowerPrice = Read-HostDouble -Prompt "Enter the power price per kW/h (kilowatt per hour), you pay to your electricity supplier" -Default $Config.PowerPrice | Foreach-Object {if (@("cancel","exit","back","<") -icontains $_) {throw $_};$_}
                                        }
                                        "usepowerprice" {
                                            $Config.UsePowerPrice = Read-HostBool -Prompt "Include cost of electricity into profit calculations" -Default $Config.UsePowerPrice | Foreach-Object {if (@("cancel","exit","back","<") -icontains $_) {throw $_};$_}
                                        }
                                        "checkprofitability" {
                                            $Config.CheckProfitability = Read-HostBool -Prompt "Check for profitability and stop mining, if no longer profitable." -Default $Config.CheckProfitability | Foreach-Object {if (@("cancel","exit","back","<") -icontains $_) {throw $_};$_}
                                        }
                                        "donate" {
                                            $Config.Donate = [int]($(Read-HostDouble -Prompt "Enter the developer donation fee in %" -Default ([Math]::Round($Config.Donate/0.1440)/100) -Mandatory -Min 0.69 -Max 100)*14.40) | Foreach-Object {if (@("cancel","exit","back","<") -icontains $_) {throw $_};$_}
                                        }
                                        "save" {
                                            Write-Host " "
                                            $ConfigSave = Read-HostBool -Prompt "Done! Do you want to save the changed values?" -Default $True | Foreach-Object {if (@("cancel","exit","back","<") -icontains $_) {throw $_};$_}

                                            if (-not $ConfigSave) {throw "cancel"}

                                            $ConfigActual | Add-Member Wallet $Config.Wallet -Force
                                            $ConfigActual | Add-Member WorkerName $Config.WorkerName -Force
                                            $ConfigActual | Add-Member UserName $Config.UserName -Force
                                            $ConfigActual | Add-Member API_ID $Config.API_ID -Force
                                            $ConfigActual | Add-Member API_Key $Config.API_Key -Force
                                            $ConfigActual | Add-Member Proxy $Config.Proxy -Force
                                            $ConfigActual | Add-Member Region $Config.Region -Force
                                            $ConfigActual | Add-Member Currency $($Config.Currency -join ",") -Force
                                            $ConfigActual | Add-Member PoolName $($Config.PoolName -join ",") -Force
                                            $ConfigActual | Add-Member ExcludePoolName $($Config.ExcludePoolName -join ",") -Force
                                            $ConfigActual | Add-Member MinerName $($Config.MinerName -join ",") -Force
                                            $ConfigActual | Add-Member ExcludeMinerName $($Config.ExcludeMinerName -join ",") -Force
                                            $ConfigActual | Add-Member Algorithm $($Config.Algorithm -join ",") -Force
                                            $ConfigActual | Add-Member ExcludeAlgorithm $($Config.ExcludeAlgorithm -join ",") -Force
                                            $ConfigActual | Add-Member ExcludeCoin $($Config.ExcludeCoin -join ",") -Force
                                            $ConfigActual | Add-Member ExcludeCoinSymbol $($Config.ExcludeCoinSymbol -join ",") -Force
                                            $ConfigActual | Add-Member MiningMode $Config.MiningMode -Force
                                            $ConfigActual | Add-Member ShowPoolBalances $(if (Get-Yes $Config.ShowPoolBalances){"1"}else{"0"}) -Force
                                            $ConfigActual | Add-Member ShowMinerWindow $(if (Get-Yes $Config.ShowMinerWindow){"1"}else{"0"}) -Force
                                            $ConfigActual | Add-Member FastestMinerOnly $(if (Get-Yes $Config.FastestMinerOnly){"1"}else{"0"}) -Force
                                            $ConfigActual | Add-Member UIstyle $Config.UIstyle -Force
                                            $ConfigActual | Add-Member DeviceName $($Config.DeviceName -join ",") -Force                      
                                            $ConfigActual | Add-Member Interval $Config.Interval -Force
                                            $ConfigActual | Add-Member DisableExtendInterval $(if (Get-Yes $Config.DisableExtendInterval){"1"}else{"0"}) -Force
                                            $ConfigActual | Add-Member SwitchingPrevention $Config.SwitchingPrevention -Force                                            
                                            $ConfigActual | Add-Member Donate $Config.Donate -Force
                                            $ConfigActual | Add-Member Watchdog $(if (Get-Yes $Config.Watchdog){"1"}else{"0"}) -Force
                                            $ConfigActual | Add-Member IgnoreFees $(if (Get-Yes $Config.IgnoreFees){"1"}else{"0"}) -Force
                                            $ConfigActual | Add-Member DisableDualMining $(if (Get-Yes $Config.DisableDualMining){"1"}else{"0"}) -Force
                                            $ConfigActual | Add-Member MSIAprofile $Config.MSIAprofile -Force
                                            $ConfigActual | Add-Member MSIApath $Config.MSIApath -Force
                                            $ConfigActual | Add-Member UseTimeSync $(if (Get-Yes $Config.UseTimeSync){"1"}else{"0"}) -Force
                                            $ConfigActual | Add-Member PowerPrice $Config.PowerPrice -Force
                                            $ConfigActual | Add-Member PowerPriceCurrency $Config.PowerPriceCurrency -Force
                                            $ConfigActual | Add-Member UsePowerPrice $(if (Get-Yes $Config.UsePowerPrice){"1"}else{"0"}) -Force
                                            $ConfigActual | Add-Member CheckProfitability $(if (Get-Yes $Config.CheckProfitability){"1"}else{"0"}) -Force
                                            $ConfigActual | Add-Member EthPillEnable $Config.EthPillEnable -Force
                                            $ConfigActual | Add-Member EnableOCProfiles $(if (Get-Yes $Config.EnableOCProfiles){"1"}else{"0"}) -Force
                                            $ConfigActual | Add-Member EnableAutoupdate $(if (Get-Yes $Config.EnableAutoupdate){"1"}else{"0"}) -Force
                                            $ConfigActual | Add-Member Delay $Config.Delay -Force

                                            $PoolsActual | Add-Member NiceHash ([PSCustomObject]@{
                                                    BTC = if($NicehashWallet -eq $Config.Wallet -or $NicehashWallet -eq ''){"`$Wallet"}else{$NicehashWallet}
                                                    Worker = if($NicehashWorkerName -eq $Config.WorkerName -or $NicehashWorkerName -eq ''){"`$WorkerName"}else{$NicehashWorkerName}
                                            }) -Force

                                            $ConfigActual | ConvertTo-Json | Out-File $ConfigFile -Encoding utf8                                             
                                            $PoolsActual | ConvertTo-Json | Out-File $PoolsConfigFile -Encoding utf8

                                            if ($IsInitialSetup) {
                                                $SetupMessage.Add("Well done! You made it through the setup wizard - an initial configuration has been created ") > $null
                                                $SetupMessage.Add("If you want to start mining, please select to exit the configuration at the following prompt. After this, in the next minutes, RainbowMiner will download all miner programs. So please be patient and let it run. There will pop up some windows, from time to time. If you happen to click into one of those black popup windows, they will hang: press return in this window to resume operation") > $null                                                
                                            } else {
                                                $SetupMessage.Add("Changes written to configuration. ") > $null
                                            }
                                            $IsInitialSetup = $false
                                            $GlobalSetupDone = $true                                            
                                        }
                                        default {
                                            Write-Log -Level Error "Unknown setup command `"$($GlobalSetupSteps[$GlobalSetupStep])`". You should never reach here. Please open an issue on github.com"
                                        }
                                    }
                                    if ($GlobalSetupStepStore) {$GlobalSetupStepBack.Add($GlobalSetupStep) > $null}
                                    $GlobalSetupStep++
                                }
                                catch {
                                    if (@("back","<") -icontains $_.Exception.Message) {
                                        if ($GlobalSetupStepBack.Count) {$GlobalSetupStep = $GlobalSetupStepBack[$GlobalSetupStepBack.Count-1];$GlobalSetupStepBack.RemoveAt($GlobalSetupStepBack.Count-1)}
                                    }
                                    elseif ($_.Exception.Message -like "Goto*") {
                                        if ($GlobalSetupStepStore) {$GlobalSetupStepBack.Add($GlobalSetupStep) > $null}
                                        $GlobalSetupStep = $GlobalSetupSteps.IndexOf(($_.Exception.Message -split "\s+")[1])
                                        if ($GlobalSetupStep -lt 0) {
                                            Write-Log -Level Error "Unknown goto command `"$(($_.Exception.Message -split "\s+")[1])`". You should never reach here. Please open an issue on github.com"
                                            $GlobalSetupStep = $GlobalSetupStepBack[$GlobalSetupStepBack.Count-1];$GlobalSetupStepBack.RemoveAt($GlobalSetupStepBack.Count-1)
                                        }
                                    }
                                    elseif (@("exit","cancel") -icontains $_.Exception.Message) {
                                        Write-Host " "
                                        Write-Host "Cancelled without changing the configuration" -ForegroundColor Red
                                        Write-Host " "
                                        $ReReadConfig = $GlobalSetupDone = $true
                                    }
                                    else {
                                        Write-Log -Level Warn "`"$($_.Exception.Message)`". You should never reach here. Please open an issue on github.com"
                                    }
                                }
                            } until ($GlobalSetupDone)
                        }
                        elseif ($SetupType -eq "M") {

                            Clear-Host

                            Write-Host " "
                            Write-Host "*** Miner Configuration ***" -BackgroundColor Green -ForegroundColor Black
                            Write-HostSetupHints
                            Write-Host " "

                            [System.Collections.ArrayList]$AvailDeviceName = @("*")
                            $AvailDeviceName.AddRange(@($AllDevices | Foreach-Object {$_.Type.ToUpper();if ($Config.MiningMode -eq "legacy") {if (@("nvidia","amd") -icontains $_.Vendor) {$_.Vendor}} else {if (@("nvidia","amd") -icontains $_.Vendor) {$_.Vendor;$_.Model};$_.Name}} | Select-Object -Unique | Sort-Object))
                            
                            $MinerSetupDone = $false
                            do {             
                                $MinersActual = Get-Content $MinersConfigFile | ConvertFrom-Json                                                     
                                $MinerSetupStepsDone = $false
                                $MinerSetupStep = 0
                                [System.Collections.ArrayList]$MinerSetupSteps = @()
                                [System.Collections.ArrayList]$MinerSetupStepBack = @()
                                                                    
                                $MinerSetupSteps.AddRange(@("minername","devices","algorithm","secondaryalgorithm","configure","params","ocprofile","msiaprofile","extendinterval","faulttolerance","penalty")) > $null                                    
                                $MinerSetupSteps.Add("save") > $null                         

                                do { 
                                    try {
                                        $MinerSetupStepStore = $true
                                        Switch ($MinerSetupSteps[$MinerSetupStep]) {
                                            "minername" {                                                    
                                                $Miner_Name = Read-HostString -Prompt "Which miner do you want to configure? (leave empty to end miner config)" -Characters "A-Z0-9.-_" -Valid $AvailMiners | Foreach-Object {if (@("cancel","exit","back","<") -icontains $_) {throw $_};$_}
                                                if ($Miner_Name -eq '') {throw "cancel"}
                                            }
                                            "devices" {
                                                if ($Config.MiningMode -eq "Legacy") {
                                                    $EditDeviceName = Read-HostString -Prompt ".. running on which devices (amd/nvidia/cpu)? (enter `"*`" for all or leave empty to end miner config)" -Characters "A-Z\*" -Valid $AvailDeviceName | Foreach-Object {if (@("cancel","exit","back","<") -icontains $_) {throw $_};$_}
                                                    if ($EditDeviceName -eq '') {throw "cancel"}
                                                } else {
                                                    [String[]]$EditDeviceName_Array = Read-HostArray -Prompt ".. running on which device(s)? (enter `"*`" for all or leave empty to end miner config)" -Characters "A-Z0-9#\*" -Valid $AvailDeviceName | Foreach-Object {if (@("cancel","exit","back","<") -icontains $_) {throw $_};$_}
                                                    ForEach ($EditDevice0 in @("nvidia","amd","cpu")) {
                                                        if ($EditDeviceName_Array -icontains $EditDevice0) {
                                                            $EditDeviceName_Array = @($AllDevices | Where-Object {$_.Vendor -eq $EditDevice0 -and $_.Type -eq "gpu" -or $_.Type -eq $EditDevice0} | Select-Object -ExpandProperty Model -Unique | Sort-Object)
                                                            break
                                                        }
                                                    }
                                                    [String]$EditDeviceName = @($EditDeviceName_Array) -join '-'
                                                    if ($EditDeviceName -eq '') {throw "cancel"}
                                                }
                                            }
                                            "algorithm" {
                                                $EditAlgorithm = Read-HostString -Prompt ".. calculating which main algorithm? (enter `"*`" for all or leave empty to end miner config)" -Characters "A-Z0-9\*" | Foreach-Object {if (@("cancel","exit","back","<") -icontains $_) {throw $_};$_}
                                                if ($EditAlgorithm -eq '') {throw "cancel"}
                                                elseif ($EditAlgorithm -ne "*") {$EditAlgorithm = Get-Algorithm $EditAlgorithm}
                                            }
                                            "secondaryalgorithm" {
                                                $EditSecondaryAlgorithm = Read-HostString -Prompt ".. calculating which secondary algorithm?" -Characters "A-Z0-9" | Foreach-Object {if (@("cancel","exit","back","<") -icontains $_) {throw $_};$_}
                                                $EditSecondaryAlgorithm = Get-Algorithm $EditSecondaryAlgorithm
                                            }
                                            "configure" {
                                                $EditMinerName = "$($Miner_Name)$(if ($EditDeviceName -ne '*'){"-$EditDeviceName"})"                
                                                Write-Host " "
                                                Write-Host "Configuration for $EditMinerName, $(if ($EditAlgorithm -eq '*'){"all algorithms"}else{$EditAlgorithm})$(if($EditSecondaryAlgorithm -ne ''){"+"+$EditSecondaryAlgorithm})" -BackgroundColor Yellow -ForegroundColor Black
                                                Write-Host " "

                                                $EditMinerConfig = [PSCustomObject]@{
                                                    MainAlgorithm = $EditAlgorithm
                                                    SecondaryAlgorithm = $EditSecondaryAlgorithm
                                                    Params = ""
                                                    MSIAprofile = ""
                                                    OCprofile = ""
                                                    ExtendInterval = ""
                                                    FaultTolerance = ""
                                                    Penalty = ""
                                                }
                        
                                                if (Get-Member -InputObject $MinersActual -Name $EditMinerName -Membertype Properties) {$MinersActual.$EditMinerName | Where-Object {$_.MainAlgorithm -eq $EditAlgorithm -and $_.SecondaryAlgorithm -eq $EditSecondaryAlgorithm} | Foreach-Object {foreach ($p in @($_.PSObject.Properties.Name)) {$EditMinerConfig | Add-Member $p $_.$p -Force}}}
                                                $MinerSetupStepStore = $false
                                            }
                                            "params" {
                                                $EditMinerConfig.Params = Read-HostString -Prompt "Additional command line parameters" -Default $EditMinerConfig.Params -Characters " -~" | Foreach-Object {if (@("cancel","exit","back","<") -icontains $_) {throw $_};$_}
                                            }
                                            "ocprofile" {
                                                $MinerSetupStepStore = $false
                                                if ($Config.EnableOCProfile) {
                                                    $EditMinerConfig.OCprofile = Read-HostString -Prompt "Custom overclocking profile (leave empty for none)" -Default $EditMinerConfig.OCprofile -Valid @($ProfilesActual.PSObject.Properties.Name) | Foreach-Object {if (@("cancel","exit","back","<") -icontains $_) {throw $_};$_}
                                                    $MinerSetupStepStore = $true
                                                }
                                            }
                                            "msiaprofile" {
                                                $MinerSetupStepStore = $false
                                                if (-not $Config.EnableOCProfile) {
                                                    $EditMinerConfig.MSIAprofile = Read-HostString -Prompt "MSI Afterburner Profile" -Default $EditMinerConfig.MSIAprofile -Characters "012345" -Length 1 | Foreach-Object {if (@("cancel","exit","back","<") -icontains $_) {throw $_};$_}
                                                    if ($EditMinerConfig.MSIAprofile -eq "0") {$EditMinerConfig.MSIAprofile = ""}
                                                    $MinerSetupStepStore = $true
                                                }
                                            }
                                            "extendinterval" {
                                                $EditMinerConfig.ExtendInterval = Read-HostInt -Prompt "Extend interval for X times" -Default ([int]$EditMinerConfig.ExtendInterval) -Min 0 -Max 10 | Foreach-Object {if (@("cancel","exit","back","<") -icontains $_) {throw $_};$_}
                                            }
                                            "faulttolerance" {
                                                $EditMinerConfig.FaultTolerance = Read-HostDouble -Prompt "Use fault tolerance in %" -Default ([double]$EditMinerConfig.FaultTolerance) -Min 0 -Max 100 | Foreach-Object {if (@("cancel","exit","back","<") -icontains $_) {throw $_};$_}
                                            }
                                            "penalty" {
                                                $EditMinerConfig.Penalty = Read-HostDouble -Prompt "Use a penalty in % (enter -1 to not change penalty)" -Default $(if ($EditMinerConfig.Penalty -eq ''){-1}else{$EditMinerConfig.Penalty}) -Min -1 -Max 100 | Foreach-Object {if (@("cancel","exit","back","<") -icontains $_) {throw $_};$_}
                                                if ($EditMinerConfig.Penalty -lt 0) {$EditMinerConfig.Penalty=""}
                                            }
                                            "save" {
                                                Write-Host " "
                                                if (-not (Read-HostBool "Really write entered values to $($MinersConfigFile)?" | Foreach-Object {if (@("cancel","exit","back","<") -icontains $_) {throw $_};$_})) {throw "cancel"}
                                                $MinersActual | Add-Member $EditMinerName -Force (@($MinersActual.$EditMinerName | Where-Object {$_.MainAlgorithm -ne $EditAlgorithm -or $_.SecondaryAlgorithm -ne $EditSecondaryAlgorithm} | Select-Object)+@($EditMinerConfig))

                                                $MinersActualSave = [PSCustomObject]@{}
                                                $MinersActual.PSObject.Properties.Name | Sort-Object | Foreach-Object {$MinersActualSave | Add-Member $_ @($MinersActual.$_ | Sort-Object MainAlgorithm,SecondaryAlgorithm)}
                                                $MinersActualSave | ConvertTo-Json | Set-Content $MinersConfigFile -Encoding Utf8

                                                Write-Host " "
                                                Write-Host "Changes written to Miner configuration. " -ForegroundColor Cyan
                                                    
                                                $MinerSetupStepsDone = $true                                                  
                                            }
                                        }
                                        if ($MinerSetupStepStore) {$MinerSetupStepBack.Add($MinerSetupStep) > $null}                                                
                                        $MinerSetupStep++
                                    }
                                    catch {
                                        if (@("back","<") -icontains $_.Exception.Message) {
                                            if ($MinerSetupStepBack.Count) {$MinerSetupStep = $MinerSetupStepBack[$MinerSetupStepBack.Count-1];$MinerSetupStepBack.RemoveAt($MinerSetupStepBack.Count-1)}
                                        }
                                        elseif ($_.Exception.Message -like "Goto*") {
                                            if ($MinerSetupStepStore) {$MinerSetupStepBack.Add($MinerSetupStep) > $null}
                                            $MinerSetupStep = $MinerSetupSteps.IndexOf(($_.Exception.Message -split "\s+")[1])
                                            if ($MinerSetupStep -lt 0) {
                                                Write-Log -Level Error "Unknown goto command `"$(($_.Exception.Message -split "\s+")[1])`". You should never reach here. Please open an issue on github.com"
                                                $MinerSetupStep = $MinerSetupStepBack[$MinerSetupStepBack.Count-1];$MinerSetupStepBack.RemoveAt($MinerSetupStepBack.Count-1)
                                            }
                                        }
                                        elseif (@("exit","cancel") -icontains $_.Exception.Message) {
                                            Write-Host " "
                                            Write-Host "Cancelled without changing the configuration" -ForegroundColor Red
                                            Write-Host " "
                                            $MinerSetupStepsDone = $true                                               
                                        }
                                        else {
                                            Write-Log -Level Warn "`"$($_.Exception.Message)`". You should never reach here. Please open an issue on github.com"
                                            $MinerSetupStepsDone = $true
                                        }
                                    }
                                } until ($MinerSetupStepsDone)                               
                        
                            } until (-not (Read-HostBool "Edit another miner?"))
                        }
                        elseif ($SetupType -eq "P") {

                            Clear-Host

                            Write-Host " "
                            Write-Host "*** Pool Configuration ***" -BackgroundColor Green -ForegroundColor Black
                            Write-HostSetupHints
                            Write-Host " "

                            $Config_Avail_Algorithm = @(if ($Config.Algorithm -ne ''){[regex]::split($Config.Algorithm.Trim(),"\s*[,;:]+\s*")}else{@()}) | Foreach-Object {Get-Algorithm $_} | Select-Object -Unique | Sort-Object

                            $PoolSetupDone = $false
                            do {
                                try {
                                    $PoolsActual = Get-Content $PoolsConfigFile | ConvertFrom-Json
                                    $Pool_Name = Read-HostString -Prompt "Which pool do you want to configure? (leave empty to end pool config)" -Characters "A-Z0-9" -Valid $AvailPools | Foreach-Object {if (@("cancel","exit","back","<") -icontains $_) {throw $_};$_}
                                    if ($Pool_Name -eq '') {throw}

                                    if (-not $PoolsActual.$Pool_Name) {
                                       $PoolsActual | Add-Member $Pool_Name (
                                            [PSCustomObject]@{
                                                BTC     = "`Wallet"
                                                User    = "`$UserName"
                                                Worker  = "`$WorkerName"
                                                API_ID  = "`$API_ID"
                                                API_Key = "`$API_Key"
                                            }
                                        ) -Force
                                        $PoolsActual | ConvertTo-Json | Set-Content $PoolsConfigFile -Encoding utf8 
                                    }

                                    [hashtable]$Pool_Config = @{Name = $Pool_Name}
                                    [hashtable]$Pool_Parameters = @{StatSpan = [TimeSpan]::FromSeconds(0);InfoOnly = $true}
                                    foreach($p in $Config.Pools.$Pool_Name.PSObject.Properties.Name) {$Pool_Parameters[$p] = $Config.Pools.$Pool_Name.$p}                                        
                                    $Pool_Parameters.DataWindow = Get-YiiMPDataWindow $Pool_Parameters.DataWindow
                                    $Pool_Config.Penalty = $Pool_Parameters.Penalty = [double]$Pool_Parameters.Penalty           
                                    $Pool = Get-ChildItemContent "Pools\$($Pool_Name).ps1" -Parameters $Pool_Parameters | Foreach-Object {$_.Content | Add-Member -NotePropertyMembers $Pool_Config -Force -PassThru}

                                    if ($Pool) {
                                        $PoolSetupStepsDone = $false
                                        $PoolSetupStep = 0
                                        [System.Collections.ArrayList]$PoolSetupSteps = @()
                                        [System.Collections.ArrayList]$PoolSetupStepBack = @()

                                        $PoolConfig = $PoolsActual.$Pool_Name.PSObject.Copy()

                                        if ($Pool_Name -notlike "MiningPoolHub*") {$PoolSetupSteps.Add("currency") > $null}
                                        $PoolSetupSteps.AddRange(@("basictitle","worker","user","apiid","apikey","penalty","algorithmtitle","algorithm","excludealgorithm","coinsymbol","excludecoinsymbol","coinname","excludecoin")) > $null
                                        if (($Pool.Content.UsesDataWindow | Measure-Object).Count -gt 0) {$PoolSetupSteps.Add("datawindow") > $null} 
                                        $PoolSetupSteps.Add("save") > $null                                        
                                                                                
                                        $Pool_Avail_Currency = @($Pool.Content.Currency | Select-Object -Unique | Sort-Object)
                                        $Pool_Avail_CoinName = @($Pool.Content | Foreach-Object {@($_.CoinName | Select-Object) -join ' '} | Select-Object -Unique | Where-Object {$_} | Sort-Object)
                                        $Pool_Avail_CoinSymbol = @($Pool.Content | Where CoinSymbol | Foreach-Object {@($_.CoinSymbol | Select-Object) -join ' '} | Select-Object -Unique | Sort-Object)

                                        if ($PoolConfig.PSObject.Properties.Name -inotcontains "User") {$PoolConfig | Add-Member User "`$UserName" -Force}
                                        if ($PoolConfig.PSObject.Properties.Name -inotcontains "API_ID") {$PoolConfig | Add-Member API_ID "`$API_ID" -Force}
                                        if ($PoolConfig.PSObject.Properties.Name -inotcontains "API_Key") {$PoolConfig | Add-Member API_Key "`$API_Key" -Force}
                                        if ($PoolConfig.PSObject.Properties.Name -inotcontains "Worker") {$PoolConfig | Add-Member Worker "`$WorkerName" -Force}
                                        if ($PoolConfig.PSObject.Properties.Name -inotcontains "Penalty") {$PoolConfig | Add-Member Penalty 0 -Force}
                                        if ($PoolConfig.PSObject.Properties.Name -inotcontains "Algorithm") {$PoolConfig | Add-Member Algorithm "" -Force}
                                        if ($PoolConfig.PSObject.Properties.Name -inotcontains "ExcludeAlgorithm") {$PoolConfig | Add-Member ExcludeAlgorithm "" -Force}            
                                        if ($PoolConfig.PSObject.Properties.Name -inotcontains "CoinName") {$PoolConfig | Add-Member CoinName "" -Force}
                                        if ($PoolConfig.PSObject.Properties.Name -inotcontains "ExcludeCoin") {$PoolConfig | Add-Member ExcludeCoin "" -Force}
                                        if ($PoolConfig.PSObject.Properties.Name -inotcontains "CoinSymbol") {$PoolConfig | Add-Member CoinSymbol "" -Force}
                                        if ($PoolConfig.PSObject.Properties.Name -inotcontains "ExcludeCoinSymbol") {$PoolConfig | Add-Member ExcludeCoinSymbol "" -Force}
                                        if ($Pool.UsesDataWindow -and $PoolConfig.PSObject.Properties.Name -inotcontains "DataWindow") {$PoolConfig | Add-Member DataWindow "estimate_current" -Force}  
                                        
                                        do { 
                                            try {
                                                Switch ($PoolSetupSteps[$PoolSetupStep]) {
                                                    "basictitle" {
                                                        Write-Host " "
                                                        Write-Host "*** Edit pool's basic settings ***" -ForegroundColor Green
                                                        Write-Host " "
                                                    }
                                                    "algorithmtitle" {
                                                        Write-Host " "
                                                        Write-Host "*** Edit pool's algorithms and coins ***" -ForegroundColor Green
                                                        Write-Host " "
                                                    }
                                                    "worker" {
                                                        $PoolConfig.Worker = Read-HostString -Prompt "Enter the worker name (leave empty to use config.txt default)" -Default ($PoolConfig.Worker -replace "^\`$.+") -Characters "A-Z0-9" | Foreach-Object {if (@("cancel","exit","back","<") -icontains $_) {throw $_};$_} 
                                                        if ($PoolConfig.Worker.Trim() -eq '') {$PoolConfig.Worker = "`$WorkerName"}
                                                    }
                                                    "user" {
                                                        $PoolConfig.User = Read-HostString -Prompt "Enter the pool's user name, if applicable (leave empty to use config.txt default)" -Default ($PoolConfig.User -replace "^\`$.+") -Characters "A-Z0-9" | Foreach-Object {if (@("cancel","exit","back","<") -icontains $_) {throw $_};$_} 
                                                        if ($PoolConfig.User.Trim() -eq '') {$PoolConfig.User = "`$UserName"}
                                                    }
                                                    "apiid" {
                                                        $PoolConfig.API_ID = Read-HostString -Prompt "Enter the pool's API-ID, if applicable (for MPH this is the USER ID, leave empty to use config.txt default)" -Default ($PoolConfig.API_ID -replace "^\`$.+") -Characters "A-Z0-9" | Foreach-Object {if (@("cancel","exit","back","<") -icontains $_) {throw $_};$_} 
                                                        if ($PoolConfig.API_ID.Trim() -eq '') {$PoolConfig.API_ID = "`$API_ID"}
                                                    }
                                                    "apikey" {
                                                        $PoolConfig.API_Key = Read-HostString -Prompt "Enter the pool's API-Key, if applicable (for MPH this is the API Key, leave empty to use config.txt default)" -Default ($PoolConfig.API_Key -replace "^\`$.+") -Characters "A-Z0-9" | Foreach-Object {if (@("cancel","exit","back","<") -icontains $_) {throw $_};$_} 
                                                        if ($PoolConfig.API_Key.Trim() -eq '') {$PoolConfig.API_Key = "`$API_Key"}
                                                    }
                                                    "algorithm" {
                                                        $PoolConfig.Algorithm = Read-HostArray -Prompt "Enter algorithms you want to mine (leave empty for all)" -Default $PoolConfig.Algorithm -Characters "A-Z0-9" | Foreach-Object {if (@("cancel","exit","back","<") -icontains $_) {throw $_};$_}
                                                    }
                                                    "excludealgorithm" {
                                                        $PoolConfig.ExcludeAlgorithm = Read-HostArray -Prompt "Enter algorithms you do want to exclude (leave empty for none)" -Default $PoolConfig.ExcludeAlgorithm -Characters "A-Z0-9" | Foreach-Object {if (@("cancel","exit","back","<") -icontains $_) {throw $_};$_}
                                                    }
                                                    "coinname" {
                                                        $PoolConfig.CoinName = Read-HostArray -Prompt "Enter coins by name, you want to mine (leave empty for all)" -Default $PoolConfig.CoinName -Characters "`$A-Z0-9. " -Valid $Pool_Avail_CoinName | Foreach-Object {if (@("cancel","exit","back","<") -icontains $_) {throw $_};$_}
                                                    }
                                                    "excludecoin" {
                                                        $PoolConfig.ExcludeCoin = Read-HostArray -Prompt "Enter coins by name, you do want to exclude (leave empty for none)" -Default $PoolConfig.ExcludeCoin -Characters "`$A-Z0-9. " -Valid $Pool_Avail_CoinName | Foreach-Object {if (@("cancel","exit","back","<") -icontains $_) {throw $_};$_}
                                                    }
                                                    "coinsymbol" {
                                                        $PoolConfig.CoinSymbol = Read-HostArray -Prompt "Enter coins by currency-symbol, you want to mine (leave empty for all)" -Default $PoolConfig.CoinSymbol -Characters "`$A-Z0-9" -Valid $Pool_Avail_CoinSymbol | Foreach-Object {if (@("cancel","exit","back","<") -icontains $_) {throw $_};$_}
                                                    }
                                                    "excludecoinsymbol" {
                                                        $PoolConfig.ExcludeCoinSymbol = Read-HostArray -Prompt "Enter coins by currency-symbol, you do want to exclude (leave empty for none)" -Default $PoolConfig.ExcludeCoinSymbol -Characters "`$A-Z0-9" -Valid $Pool_Avail_CoinSymbol | Foreach-Object {if (@("cancel","exit","back","<") -icontains $_) {throw $_};$_}
                                                    }
                                                    "penalty" {                                                    
                                                        $PoolConfig.Penalty = Read-HostDouble -Prompt "Enter penalty in percent. This value will decrease all reported values." -Default $PoolConfig.Penalty -Min 0 -Max 100 | Foreach-Object {if (@("cancel","exit","back","<") -icontains $_) {throw $_};$_}
                                                    }
                                                    "currency" {
                                                        $PoolEditCurrencyDone = $false
                                                        Write-Host " "
                                                        Write-Host "*** Define your wallets for this pool ***" -ForegroundColor Green
                                                        do {
                                                            $Pool_Actual_Currency = @(Compare-Object @($Pool_Avail_Currency) @($PoolConfig.PSObject.Properties.Name) -ExcludeDifferent -IncludeEqual | Select-Object -ExpandProperty InputObject | Sort-Object)
                                                            Write-Host " "
                                                            if ($Pool_Actual_Currency.Count -gt 0) {
                                                                Write-Host "Currently defined wallets:" -ForegroundColor Cyan
                                                                foreach ($p in $Pool_Actual_Currency) {
                                                                    $v = $PoolConfig.$p
                                                                    if ($v -eq "`$Wallet") {$v = "default (wallet $($Config.Wallet) from your config.txt)"}
                                                                    Write-Host "$p = $v" -ForegroundColor Cyan
                                                                }
                                                            } else {
                                                                Write-Host "No wallets defined!" -ForegroundColor Yellow
                                                            }
                                                            Write-Host " "
                                                            $PoolEditCurrency = Read-HostString -Prompt "Enter the currency you want to edit, add or remove (leave empty to end wallet configuration)" -Characters "A-Z0-9" -Valid $Pool_Avail_Currency | Foreach-Object {if (@("cancel","exit","back","<") -icontains $_) {throw $_};$_}
                                                            $PoolEditCurrency = $PoolEditCurrency.Trim()
                                                            if ($PoolEditCurrency -ne "") {
                                                                $v = $PoolConfig.$PoolEditCurrency
                                                                if ($v -eq "`$Wallet" -or (-not $v -and $PoolEditCurrency -eq "BTC")) {$v = "default"}
                                                                $v = Read-HostString -Prompt "Enter your wallet address for $PoolEditCurrency (enter `"remove`" to remove this currency, `"default`" to always use current default wallet from your config.txt)" -Default $v | Foreach-Object {if (@("cancel","exit") -icontains $_) {throw $_};$_}
                                                                $v = $v.Trim()
                                                                if (@("back","<") -inotcontains $v) {
                                                                    if (@("del","delete","remove","clear","rem") -icontains $v) {
                                                                        if (@($PoolConfig.PSObject.Properties.Name) -icontains $PoolEditCurrency) {$PoolConfig.PSObject.Properties.Remove($PoolEditCurrency)} 
                                                                    } else {
                                                                        if (@("def","default","wallet","standard") -icontains $v) {$v = "`$Wallet"}
                                                                        $PoolConfig | Add-Member $PoolEditCurrency $v -Force
                                                                    }
                                                                }
                                                            } else {
                                                                $PoolEditCurrencyDone = $true
                                                            }

                                                        } until ($PoolEditCurrencyDone)                                                                                                          
                                                    }
                                                    "datawindow" {
                                                        Write-Host " "
                                                        Write-Host "*** Define the pool's datawindow ***" -ForegroundColor Green
                                                        Write-Host " "
                                                        Write-Host "- estimate_current (=default): the pool's current calculated profitability-estimation (more switching, relies on the honesty of the pool)" -ForegroundColor Cyan
                                                        Write-Host "- estimate_last24h: the pool's calculated profitability-estimation for the past 24 hours (less switching, relies on the honesty of the pool)" -ForegroundColor Cyan
                                                        Write-Host "- actual_last24h: the actual profitability over the past 24 hours (less switching)" -ForegroundColor Cyan
                                                        Write-Host "- mininum (or minimum-2): the minimum value of estimate_current and actual_last24h will be used" -ForegroundColor Cyan
                                                        Write-Host "- maximum (or maximum-2): the maximum value of estimate_current and actual_last24h will be used" -ForegroundColor Cyan
                                                        Write-Host "- average (or average-2): the calculated average of estimate_current and actual_last24h will be used" -ForegroundColor Cyan
                                                        Write-Host "- mininumall (or minimum-3): the minimum value of the above three values will be used" -ForegroundColor Cyan
                                                        Write-Host "- maximumall (or maximum-3): the maximum value of the above three values will be used" -ForegroundColor Cyan
                                                        Write-Host "- averageall (or average-3): the calculated average of the above three values will be used" -ForegroundColor Cyan
                                                        Write-Host " "
                                                        $PoolConfig.DataWindow = Read-HostString -Prompt "Enter which datawindow is to be used for this pool" -Default (Get-YiiMPDataWindow $PoolConfig.DataWindow) | Foreach-Object {if (@("cancel","exit") -icontains $_) {throw $_};$_}
                                                        $PoolConfig.DataWindow = Get-YiiMPDataWindow $PoolConfig.DataWindow
                                                    }
                                                    "save" {
                                                        Write-Host " "
                                                        if (-not (Read-HostBool -Prompt "Done! Do you want to save the changed values?" -Default $True | Foreach-Object {if (@("cancel","exit","back","<") -icontains $_) {throw $_};$_})) {throw "cancel"}
                                                        
                                                        $PoolConfig | Add-Member Algorithm $($PoolConfig.Algorithm -join ",") -Force
                                                        $PoolConfig | Add-Member ExcludeAlgorithm $($PoolConfig.ExcludeAlgorithm -join ",") -Force
                                                        $PoolConfig | Add-Member CoinName $($PoolConfig.CoinName -join ",") -Force
                                                        $PoolConfig | Add-Member ExcludeCoin $($PoolConfig.ExcludeCoin -join ",") -Force
                                                        $PoolConfig | Add-Member CoinSymbol $($PoolConfig.CoinSymbol -join ",") -Force
                                                        $PoolConfig | Add-Member ExcludeCoinSymbol $($PoolConfig.ExcludeCoinSymbol -join ",") -Force

                                                        $PoolsActual | Add-Member $Pool_Name $PoolConfig -Force
                                                        $PoolsActualSave = [PSCustomObject]@{}
                                                        $PoolsActual.PSObject.Properties.Name | Sort-Object | Foreach-Object {$PoolsActualSave | Add-Member $_ ($PoolsActual.$_) -Force}

                                                        $PoolsActualSave | ConvertTo-Json | Set-Content $PoolsConfigFile -Encoding utf8

                                                        Write-Host " "
                                                        Write-Host "Changes written to pool configuration. " -ForegroundColor Cyan
                                                    
                                                        $PoolSetupStepsDone = $true                                                  
                                                    }
                                                }
                                                if ($PoolSetupSteps[$PoolSetupStep] -notmatch "title") {$PoolSetupStepBack.Add($PoolSetupStep) > $null}                                                
                                                $PoolSetupStep++
                                            }
                                            catch {
                                                if (@("back","<") -icontains $_.Exception.Message) {
                                                    if ($PoolSetupStepBack.Count) {$PoolSetupStep = $PoolSetupStepBack[$PoolSetupStepBack.Count-1];$PoolSetupStepBack.RemoveAt($PoolSetupStepBack.Count-1)}
                                                }
                                                elseif ($_.Exception.Message -like "Goto*") {
                                                    if ($PoolSetupSteps[$PoolSetupStep] -notmatch "title") {$PoolSetupStepBack.Add($PoolSetupStep) > $null}
                                                    $PoolSetupStep = $PoolSetupSteps.IndexOf(($_.Exception.Message -split "\s+")[1])
                                                    if ($PoolSetupStep -lt 0) {
                                                        Write-Log -Level Error "Unknown goto command `"$(($_.Exception.Message -split "\s+")[1])`". You should never reach here. Please open an issue on github.com"
                                                        $PoolSetupStep = $PoolSetupStepBack[$PoolSetupStepBack.Count-1];$PoolSetupStepBack.RemoveAt($PoolSetupStepBack.Count-1)
                                                    }
                                                }
                                                elseif (@("exit","cancel") -icontains $_.Exception.Message) {
                                                    Write-Host " "
                                                    Write-Host "Cancelled without changing the configuration" -ForegroundColor Red
                                                    Write-Host " "
                                                    $PoolSetupStepsDone = $true                                               
                                                }
                                                else {
                                                    Write-Log -Level Warn "`"$($_.Exception.Message)`". You should never reach here. Please open an issue on github.com"
                                                    $PoolSetupStepsDone = $true
                                                }
                                            }
                                        } until ($PoolSetupStepsDone)                                                                        

                                    } else {
                                        Write-Host "Please try again later" -ForegroundColor Yellow
                                    }

                                    Write-Host " "
                                    if (-not (Read-HostBool "Edit another pool?")){throw}
                        
                                } catch {$PoolSetupDone = $true}
                            } until ($PoolSetupDone)
                        }
                        elseif ($SetupType -eq "D") {

                            Clear-Host

                            Write-Host " "
                            Write-Host "*** Device Configuration ***" -BackgroundColor Green -ForegroundColor Black
                            Write-HostSetupHints
                            Write-Host " "

                            $DeviceSetupDone = $false
                            do {
                                try {
                                    $DevicesActual = Get-Content $DevicesConfigFile | ConvertFrom-Json
                                    $Device_Name = Read-HostString -Prompt "Which device do you want to configure? (leave empty to end device config)" -Characters "A-Z0-9" -Valid @($SetupDevices.Model | Select-Object -Unique | Sort-Object) | Foreach-Object {if (@("cancel","exit","back","<") -icontains $_) {throw $_};$_}
                                    if ($Device_Name -eq '') {throw}

                                    if (-not $DevicesActual.$Device_Name) {
                                        $DevicesActual | Add-Member $Device_Name ([PSCustomObject]@{Algorithm="";ExcludeAlgorithm="";MinerName="";ExcludeMinerName="";DisableDualMining=""}) -Force
                                        $DevicesActual | ConvertTo-Json | Set-Content $DevicesConfigFile -Encoding utf8 
                                    }

                                    if ($Device_Name) {
                                        $DeviceSetupStepsDone = $false
                                        $DeviceSetupStep = 0
                                        [System.Collections.ArrayList]$DeviceSetupSteps = @()
                                        [System.Collections.ArrayList]$DeviceSetupStepBack = @()

                                        $DeviceConfig = $DevicesActual.$Device_Name.PSObject.Copy()

                                        $DeviceSetupSteps.AddRange(@("algorithm","excludealgorithm","minername","excludeminername","disabledualmining")) > $null
                                        $DeviceSetupSteps.Add("save") > $null
                                        
                                        do { 
                                            try {
                                                Switch ($DeviceSetupSteps[$DeviceSetupStep]) {
                                                    "algorithm" {
                                                        $DeviceConfig.Algorithm = Read-HostArray -Prompt "Enter algorithms you want to mine (leave empty for all)" -Default $DeviceConfig.Algorithm -Characters "A-Z0-9" | Foreach-Object {if (@("cancel","exit","back","<") -icontains $_) {throw $_};$_}
                                                    }
                                                    "excludealgorithm" {
                                                        $DeviceConfig.ExcludeAlgorithm = Read-HostArray -Prompt "Enter algorithms you do want to exclude (leave empty for none)" -Default $DeviceConfig.ExcludeAlgorithm -Characters "A-Z0-9" | Foreach-Object {if (@("cancel","exit","back","<") -icontains $_) {throw $_};$_}
                                                    }
                                                    "minername" {
                                                        $DeviceConfig.MinerName = Read-HostArray -Prompt "Enter the miners your want to use (leave empty for all)" -Default $DeviceConfig.MinerName -Characters "A-Z0-9.-_" -Valid $AvailMiners | Foreach-Object {if (@("cancel","exit","back","<") -icontains $_) {throw $_};$_}
                                                    }
                                                    "excludeminername" {
                                                        $DeviceConfig.ExcludeMinerName = Read-HostArray -Prompt "Enter the miners you do want to exclude" -Default $DeviceConfig.ExcludeMinerName -Characters "A-Z0-9\.-_" -Valid $AvailMiners | Foreach-Object {if (@("cancel","exit","back","<") -icontains $_) {throw $_};$_}
                                                    }
                                                    "disabledualmining" {
                                                        $DeviceConfig.DisableDualMining = Read-HostBool -Prompt "Disable all dual mining algorithm" -Default $DeviceConfig.DisableDualMining | Foreach-Object {if (@("cancel","exit","back","<") -icontains $_) {throw $_};$_}
                                                    }
                                                    "save" {
                                                        Write-Host " "
                                                        if (-not (Read-HostBool -Prompt "Done! Do you want to save the changed values?" -Default $True | Foreach-Object {if (@("cancel","exit","back","<") -icontains $_) {throw $_};$_})) {throw "cancel"}
                                                        
                                                        $DeviceConfig | Add-Member Algorithm $($DeviceConfig.Algorithm -join ",") -Force
                                                        $DeviceConfig | Add-Member ExcludeAlgorithm $($DeviceConfig.ExcludeAlgorithm -join ",") -Force
                                                        $DeviceConfig | Add-Member MinerName $($DeviceConfig.MinerName -join ",") -Force
                                                        $DeviceConfig | Add-Member ExcludeMinerName $($DeviceConfig.ExcludeMinerName -join ",") -Force
                                                        $DeviceConfig | Add-Member DisableDualMining $(if (Get-Yes $DeviceConfig.DisableDualMining){"1"}else{"0"}) -Force

                                                        $DevicesActual | Add-Member $Device_Name $DeviceConfig -Force
                                                        $DevicesActualSave = [PSCustomObject]@{}
                                                        $DevicesActual.PSObject.Properties.Name | Sort-Object | Foreach-Object {$DevicesActualSave | Add-Member $_ ($DevicesActual.$_) -Force}

                                                        $DevicesActualSave | ConvertTo-Json | Set-Content $DevicesConfigFile -Encoding utf8

                                                        Write-Host " "
                                                        Write-Host "Changes written to device configuration. " -ForegroundColor Cyan
                                                    
                                                        $DeviceSetupStepsDone = $true
                                                    }
                                                }
                                                $DeviceSetupStepBack.Add($DeviceSetupStep) > $null
                                                $DeviceSetupStep++
                                            }
                                            catch {
                                                if (@("back","<") -icontains $_.Exception.Message) {
                                                    if ($DeviceSetupStepBack.Count) {$DeviceSetupStep = $DeviceSetupStepBack[$DeviceSetupStepBack.Count-1];$DeviceSetupStepBack.RemoveAt($DeviceSetupStepBack.Count-1)}
                                                }
                                                elseif ($_.Exception.Message -like "Goto*") {
                                                    $DeviceSetupStepBack.Add($DeviceSetupStep) > $null
                                                    $DeviceSetupStep = $DeviceSetupSteps.IndexOf(($_.Exception.Message -split "\s+")[1])
                                                    if ($DeviceSetupStep -lt 0) {
                                                        Write-Log -Level Error "Unknown goto command `"$(($_.Exception.Message -split "\s+")[1])`". You should never reach here. Please open an issue on github.com"
                                                        $DeviceSetupStep = $DeviceSetupStepBack[$DeviceSetupStepBack.Count-1];$DeviceSetupStepBack.RemoveAt($DeviceSetupStepBack.Count-1)
                                                    }
                                                }
                                                elseif (@("exit","cancel") -icontains $_.Exception.Message) {
                                                    Write-Host " "
                                                    Write-Host "Cancelled without changing the configuration" -ForegroundColor Red
                                                    Write-Host " "
                                                    $DeviceSetupStepsDone = $true                                               
                                                }
                                                else {
                                                    Write-Log -Level Warn "`"$($_.Exception.Message)`". You should never reach here. Please open an issue on github.com"
                                                    $DeviceSetupStepsDone = $true
                                                }
                                            }
                                        } until ($DeviceSetupStepsDone)                                                                        

                                    } else {
                                        Write-Host "Please try again later" -ForegroundColor Yellow
                                    }

                                    Write-Host " "
                                    if (-not (Read-HostBool "Edit another device?")){throw}
                        
                                } catch {$DeviceSetupDone = $true}
                            } until ($DeviceSetupDone)
                        }
                        elseif ($SetupType -eq "O") {

                            Clear-Host

                            Write-Host " "
                            Write-Host "*** Overclocking Profile Configuration ***" -BackgroundColor Green -ForegroundColor Black
                            Write-HostSetupHints
                            Write-Host " "

                            $OCProfileSetupDone = $false
                            do {
                                try {
                                    $OCProfilesActual = Get-Content $OCProfilesConfigFile | ConvertFrom-Json
                                    Write-Host " "
                                    $p = [console]::ForegroundColor
                                    [console]::ForegroundColor = "Cyan"
                                    Write-Host "Current profiles:"
                                    $OCProfilesActual.PSObject.Properties | Format-Table @(
                                        @{Label="Name"; Expression={"$($_.Name)"}}
                                        @{Label="Power Limit"; Expression={"$(if ($_.Value.PowerLimit -eq '0'){'*'}else{"$($_.Value.PowerLimit) %"})"}; Align="center"}
                                        @{Label="Thermal Limit"; Expression={"$(if ($_.Value.ThermalLimit -eq '0'){'*'}else{"$($_.Value.ThermalLimit) %"})"}; Align="center"}
                                        @{Label="Core Clock"; Expression={"$(if ($_.Value.CoreClockBoost -eq '*'){'*'}else{"$(if ($_.Value.CoreClockBoost -gt 0){'+'})$($_.Value.CoreClockBoost)"})"}; Align="center"}
                                        @{Label="Memory Clock"; Expression={"$(if ($_.Value.MemoryClockBoost -eq '*'){'*'}else{"$(if ($_.Value.MemoryClockBoost -gt 0){'+'})$($_.Value.MemoryClockBoost)"})"}; Align="center"}                                        
                                    )
                                    [console]::ForegroundColor = $p

                                    do {
                                        $OCProfile_Name = Read-HostString -Prompt "Which profile do you want to edit/create? (leave empty to end profile config)" -Characters "A-Z0-9" | Foreach-Object {if (@("cancel","exit","back","<") -icontains $_) {throw $_};$_}
                                        if ($OCProfile_Name -eq '') {throw}

                                        if (-not $OCProfilesActual.$OCProfile_Name) {
                                            if (Read-HostBool "Do you want to create new profile `"$($OCProfile_Name)`"?" -Default $true) {
                                                $OCProfilesActual | Add-Member $OCProfile_Name ([PSCustomObject]@{PowerLimit = 0;ThermalLimit = 0;MemoryClockBoost = "*";CoreClockBoost = "*"}) -Force
                                                $OCProfilesActual | ConvertTo-Json | Set-Content $OCProfilesConfigFile -Encoding utf8 
                                            } else {
                                                $OCProfile_Name = ''
                                            }
                                        } else {
                                            $OCProfile_Name = $OCProfilesActual.PSObject.Properties.Name | Where-Object {$_ -eq $OCProfile_Name}
                                        }
                                    } until ($OCProfile_Name -ne '')

                                    if ($OCProfile_Name) {
                                        $OCProfileSetupStepsDone = $false
                                        $OCProfileSetupStep = 0
                                        [System.Collections.ArrayList]$OCProfileSetupSteps = @()
                                        [System.Collections.ArrayList]$OCProfileSetupStepBack = @()

                                        $OCProfileConfig = $OCProfilesActual.$OCProfile_Name.PSObject.Copy()

                                        $OCProfileSetupSteps.AddRange(@("powerlimit","thermallimit","coreclockboost","memoryclockboost")) > $null
                                        $OCProfileSetupSteps.Add("save") > $null
                                        
                                        do { 
                                            try {
                                                Switch ($OCProfileSetupSteps[$OCProfileSetupStep]) {
                                                    "powerlimit" {
                                                        $OCProfileConfig.PowerLimit = Read-HostInt -Prompt "Enter the power limit in % (input 0 to never set)" -Default $OCProfileConfig.PowerLimit -Min 0 -Max 150 | Foreach-Object {if (@("cancel","exit","back","<") -icontains $_) {throw $_};$_}
                                                    }
                                                    "thermallimit" {
                                                        $OCProfileConfig.ThermalLimit = Read-HostInt -Prompt "Enter the thermal limit in °C (input 0 to never set)" -Default $OCProfileConfig.ThermalLimit -Min 0 -Max 100 | Foreach-Object {if (@("cancel","exit","back","<") -icontains $_) {throw $_};$_}
                                                    }
                                                    "memoryclockboost" {
                                                        $p = Read-HostString -Prompt "Enter a value for memory clock boost or `"*`" to never set" -Default $OCProfileConfig.MemoryClockBoost -Characters "0-9*+-" -Mandatory | Foreach-Object {if (@("cancel","exit","back","<") -icontains $_) {throw $_};$_}
                                                        if ($p -ne '*') {
                                                            $p = $p -replace '\+'
                                                            if ($p -match '^.+-' -or $p -eq '') {Write-Host "This is not a correct number" -ForegroundColor Yellow; throw "goto powerlimit"}
                                                        }
                                                        $OCProfileConfig.MemoryClockBoost = $p                                                            
                                                    }
                                                    "coreclockboost" {
                                                        $p = Read-HostString -Prompt "Enter a value for core clock boost or `"*`" to never set" -Default $OCProfileConfig.CoreClockBoost -Characters "0-9*+-" -Mandatory | Foreach-Object {if (@("cancel","exit","back","<") -icontains $_) {throw $_};$_}
                                                        if ($p -ne '*') {
                                                            $p = $p -replace '\+'
                                                            if ($p -match '^.+-' -or $p -eq '') {Write-Host "This is not a correct number" -ForegroundColor Yellow; throw "goto coreclockboost"}
                                                        }
                                                        $OCProfileConfig.CoreClockBoost = $p                                                            
                                                    }

                                                    "save" {
                                                        Write-Host " "
                                                        if (-not (Read-HostBool -Prompt "Done! Do you want to save the changed values?" -Default $True | Foreach-Object {if (@("cancel","exit","back","<") -icontains $_) {throw $_};$_})) {throw "cancel"}
                                                        
                                                        $OCProfilesActual | Add-Member $OCProfile_Name $OCProfileConfig -Force
                                                        $OCProfilesActualSave = [PSCustomObject]@{}
                                                        $OCProfilesActual.PSObject.Properties.Name | Sort-Object | Foreach-Object {$OCProfilesActualSave | Add-Member $_ ($OCProfilesActual.$_) -Force}

                                                        $OCProfilesActualSave | ConvertTo-Json | Set-Content $OCProfilesConfigFile -Encoding utf8

                                                        Write-Host " "
                                                        Write-Host "Changes written to profiles configuration. " -ForegroundColor Cyan
                                                    
                                                        $OCProfileSetupStepsDone = $true
                                                    }
                                                }
                                                $OCProfileSetupStepBack.Add($OCProfileSetupStep) > $null
                                                $OCProfileSetupStep++
                                            }
                                            catch {
                                                if (@("back","<") -icontains $_.Exception.Message) {
                                                    if ($OCProfileSetupStepBack.Count) {$OCProfileSetupStep = $OCProfileSetupStepBack[$OCProfileSetupStepBack.Count-1];$OCProfileSetupStepBack.RemoveAt($OCProfileSetupStepBack.Count-1)}
                                                }
                                                elseif ($_.Exception.Message -like "Goto*") {
                                                    $OCProfileSetupStepBack.Add($OCProfileSetupStep) > $null
                                                    $OCProfileSetupStep = $OCProfileSetupSteps.IndexOf(($_.Exception.Message -split "\s+")[1])
                                                    if ($OCProfileSetupStep -lt 0) {
                                                        Write-Log -Level Error "Unknown goto command `"$(($_.Exception.Message -split "\s+")[1])`". You should never reach here. Please open an issue on github.com"
                                                        $OCProfileSetupStep = $OCProfileSetupStepBack[$OCProfileSetupStepBack.Count-1];$OCProfileSetupStepBack.RemoveAt($OCProfileSetupStepBack.Count-1)
                                                    }
                                                }
                                                elseif (@("exit","cancel") -icontains $_.Exception.Message) {
                                                    Write-Host " "
                                                    Write-Host "Cancelled without changing the configuration" -ForegroundColor Red
                                                    Write-Host " "
                                                    $OCProfileSetupStepsDone = $true                                               
                                                }
                                                else {
                                                    Write-Log -Level Warn "`"$($_.Exception.Message)`". You should never reach here. Please open an issue on github.com"
                                                    $OCProfileSetupStepsDone = $true
                                                }
                                            }
                                        } until ($OCProfileSetupStepsDone)                                                                        

                                    } else {
                                        Write-Host "Please try again later" -ForegroundColor Yellow
                                    }

                                    Write-Host " "
                                    if (-not (Read-HostBool "Edit another device?")){throw}
                        
                                } catch {$OCProfileSetupDone = $true}
                            } until ($OCProfileSetupDone)
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
        Break
    }

    #Convert to array, if needed and check contents of some fields, if Config has been reread or reset
    if ($ConfigCheckFields) {
        #for backwards compatibility
        if ($Config.Type -ne $null) {$Config | Add-Member DeviceName $Config.Type -Force}
        if ($Config.GPUs -ne $null -and $Config.GPUs) {
            if ($Config.GPUs -is [string]) {$Config.GPUs = [regex]::split($Config.GPUs,"\s*[,;:]+\s*")}
            $Config | Add-Member DeviceName @() -Force
            Get-Device "nvidia" | Where-Object {$Config.GPUs -contains $_.Type_Vendor_Index} | Foreach-Object {$Config.DeviceName += [string]("GPU#{0:d2}" -f $_.Type_Vendor_Index)}
        }

        $Config.PSObject.Properties | Where-Object {$_.TypeNameOfValue -ne "System.Object" -and $_.MemberType -eq "NoteProperty"} | Select-Object Name,Value | Foreach-Object {
            $name = $_.Name;
            $var = Get-Variable -ValueOnly $name -ErrorAction SilentlyContinue
            if ($var -is [array] -and $Config.$name -is [string]) {$Config.$name = $Config.$name.Trim(); $Config.$name = @(if ($Config.$name -ne ''){@([regex]::split($Config.$name.Trim(),"\s*[,;:]+\s*") | Where-Object {$_})})}
            elseif (($var -is [bool] -or $var -is [switch]) -and $Config.$name -isnot [bool]) {$Config.$name = Get-Yes $Config.$name}
            elseif ($var -is [int] -and $Config.$name -isnot [int]) {$Config.$name = [int]$Config.$name}
        }
        $Config.Algorithm = @($Config.Algorithm | ForEach-Object {Get-Algorithm $_} | Where-Object {$_})
        $Config.ExcludeAlgorithm = @($Config.ExcludeAlgorithm | ForEach-Object {Get-Algorithm $_} | Where-Object {$_})
        $Config.Region = $Config.Region | ForEach-Object {Get-Region $_}
        $Config.Currency = @($Config.Currency | ForEach-Object {$_.ToUpper()} | Where-Object {$_})
        $Config.UIstyle = if ( $Config.UIstyle -ne "full" -and $Config.UIstyle -ne "lite" ) {"full"} else {$Config.UIstyle}
        $Config.PowerPriceCurrency = $Config.PowerPriceCurrency | ForEach-Object {$_.ToUpper()}

        #For backwards compatibility
        if ($Config.Wallet -and -not $Config.MinerStatusKey) {$Config.MinerStatusKey = $Config.Wallet}      
        if ($Config.LegacyMode -ne $null) {$Config.MiningMode = if (Get-Yes $Config.LegacyMode){"legacy"}else{"device"}}
    }

    #Initialize the API and Get-Device
    if(!(Test-Path Variable:API)) {
        Import-Module .\API.psm1
        Start-APIServer -RemoteAPI:$Config.RemoteAPI
        $API.Version = Confirm-Version $Version
    }

    #Give API access to computerstats
    $API.ComputerStats = $AsyncLoader.ComputerStats

    #Give API access to all possible devices
    if ($API.AllDevices -eq $null) {$API.AllDevices = $AllDevices}

    $MSIAenabled = -not $Config.EnableOCProfiles -and $Config.MSIAprofile -gt 0 -and (Test-Path $Config.MSIApath)

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
                    if ($Config.Devices.$p.$q -is [string]){$Config.Devices.$p.$q = if ($Config.Devices.$p.$q.Trim() -eq ""){@()}else{[regex]::split($Config.Devices.$p.$q.Trim(),"\s*[,;:]+\s*")}}
                }
                $Config.Devices.$p | Add-Member DisableDualMining ($Config.Devices.$p.DisableDualMining -and (Get-Yes $Config.Devices.$p.DisableDualMining)) -Force
            }
        }
    }

    #Check for oc profile config
    Set-OCProfilesConfigDefault $OCProfilesConfigFile
    if (Test-Path $OCProfilesConfigFile) {
        if ($ConfigCheckFields -or -not $Config.OCProfiles -or (Get-ChildItem $OCProfilesConfigFile).LastWriteTime.ToUniversalTime() -gt $Updatetracker["Config"]["OCProfilesConfigFile"]) {        
            $Updatetracker["Config"]["OCProfilesConfigFile"] = (Get-ChildItem $OCProfilesConfigFile).LastWriteTime.ToUniversalTime()
            $Config | Add-Member OCProfiles (Get-ChildItemContent $OCProfilesConfigFile).Content -Force
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
                $Config.Pools.$p | Add-Member CoinName @(($Config.Pools.$p.CoinName | Select-Object) | Where-Object {$_}) -Force
                $Config.Pools.$p | Add-Member ExcludeCoin @(($Config.Pools.$p.ExcludeCoin | Select-Object) | Where-Object {$_}) -Force
                $Config.Pools.$p | Add-Member CoinSymbol @(($Config.Pools.$p.CoinSymbol | Select-Object) | Where-Object {$_}) -Force
                $Config.Pools.$p | Add-Member ExcludeCoinSymbol @(($Config.Pools.$p.ExcludeCoinSymbol | Select-Object) | Where-Object {$_}) -Force
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
        if (-not $DonationData) {$DonationData = '{"Wallets":{"NiceHash":{"BTC":"3HFhYADZvybBstETYNEVMqVWMU9EJRfs4f","Worker":"mpx"},"Default":{"BTC":"3DxRETpBoXKrEBQxFb2HsPmG6apxHmKmUx","RVN":"RGo5UgbnyNkfA8sUUbv62cYnV4EfYziNxH","PGN":"PAH9NZow4ut9ewGCdv548V832EMU5PWKJL","Worker":"mpx","User":"rbm"}},"Pools":["Nicehash","BlazePool","Ravenminer","ZergPool"],"Algorithm":["allium","balloon","blake2s","c11","cryptonightheavy","cryptonightv7","equihash","equihash21x9","equihash24x5","equihash24x7","ethash","hmq1725","hodl","hsr","keccak","keccakc","lyra2re2","lyra2z","neoscrypt","pascal","phi","phi2","poly","skein","skunk","timetravel","tribus","x16r","x16s","x17","xevan","yescrypt","yescryptr16","yespower"]}' | ConvertFrom-Json}                                                                                                                                                                                                                                                                                                                                                                     
        $AvailPools | ForEach-Object {
            $DonationData1 = if (Get-Member -InputObject ($DonationData.Wallets) -Name $_ -MemberType NoteProperty) {$DonationData.Wallets.$_} else {$DonationData.Wallets.Default};
            $Config.Pools | Add-Member $_ $DonationData1 -Force
            $DonateNow = $true
        }
        if ($DonateNow) {
            $Updatetracker["Config"]["ConfigFile"] = 0
            $DonationAlgorithmAvail = $AllPools.Algorithm | Foreach-Object {$_ -replace '\-.*$'} | Select-Object -Unique
            $DonationPoolsAvail = Compare-Object @($DonationData.Pools) @($AvailPools) -IncludeEqual -ExcludeDifferent | Select-Object -ExpandProperty InputObject
            $Config | Add-Member Algorithm $($DonationData.Algorithm | ForEach-Object {Get-Algorithm $_}) -Force
            if ($DonationAlgorithmAvail -inotcontains "x16r") {$Config.Algorithm = $Config.Algorithm | Where-Object {$_ -ne "x16r"}}
            if (-not $DonationPoolsAvail.Count) {            
                $Config | Add-Member ExcludePoolName @() -Force
            } else {
                $Config | Add-Member PoolName $DonationPoolsAvail -Force
                $Config | Add-Member ExcludePoolName @(Compare-Object @($AvailPools) @($DonationPoolsAvail) | Select-Object -ExpandProperty InputObject) -Force
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
            $API.DeviceCombos = @($DevicesByTypes.FullComboModels.PSObject.Properties.Name) | ForEach-Object {$DevicesByTypes.$_ | Select-Object -ExpandProperty Model -Unique} | Sort-Object
        }
    }    

    Update-DeviceInformation @($Devices.Name | Select-Object -Unique)

    $API.Devices = $Devices

    if (-not $Devices) {
        Write-Log -Level Warn "No devices available. Please check your configuration. "
        Start-Sleep $Config.Interval
        continue
    }

    #Check for miner config
    Set-MinersConfigDefault -PathToFile $MinersConfigFile
    if (Test-Path $MinersConfigFile) {
        if ($ConfigCheckFields -or -not $Config.Miners -or (Get-ChildItem $MinersConfigFile).LastWriteTime.ToUniversalTime() -gt $Updatetracker["Config"]["MinersConfigFile"]) {        
            $Updatetracker["Config"]["MinersConfigFile"] = (Get-ChildItem $MinersConfigFile).LastWriteTime.ToUniversalTime()
            $Config | Add-Member Miners ([PSCustomObject]@{}) -Force
            foreach ($CcMiner in @((Get-ChildItemContent -Path $MinersConfigFile).Content.PSObject.Properties)) {
                [String[]]$CcMinerName_Array = @($CcMiner.Name -split '-')
                if ($CcMinerName_Array.Count -gt 1 -and $DevicesByTypes.FullComboModels."$($CcMinerName_Array[1])") {$CcMiner.Name = $CcMinerName_Array[0] + "-" + $DevicesByTypes.FullComboModels."$($CcMinerName_Array[1])"}
                foreach($p in $CcMiner.Value) {
                    $CcMinerName = $CcMiner.Name
                    if ($p.MainAlgorithm -ne '*') {
                        $CcMinerName += "-$(Get-Algorithm $p.MainAlgorithm)"
                        if ($p.SecondaryAlgorithm) {$CcMinerName += "-$(Get-Algorithm $p.SecondaryAlgorithm)"}
                    }
                    $Config.Miners | Add-Member -Name $CcMinerName -Value $p -MemberType NoteProperty -Force
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

    if ($UseTimeSync) {Test-TimeSync}
    $Timer = (Get-Date).ToUniversalTime()

    $StatStart = $StatEnd
    $StatEnd = $Timer.AddSeconds($Config.Interval)
    $StatSpan = New-TimeSpan $StatStart $StatEnd

    $DecayExponent = [int](($Timer - $DecayStart).TotalSeconds / $DecayPeriod)

    $WatchdogInterval = ($WatchdogInterval / $Strikes * ($Strikes - 1)) + $StatSpan.TotalSeconds
    $WatchdogReset = ($WatchdogReset / ($Strikes * $Strikes * $Strikes) * (($Strikes * $Strikes * $Strikes) - 1)) + $StatSpan.TotalSeconds

    #Update the exchange rates
    [hashtable]$NewRates = @{}
    try {
        Write-Log "Updating exchange rates from Coinbase. "
        Invoke-RestMethodAsync "https://api.coinbase.com/v2/exchange-rates?currency=BTC" | Select-Object -ExpandProperty data | Select-Object -ExpandProperty rates | Foreach-Object {$_.PSObject.Properties | Foreach-Object {$NewRates[$_.Name] = $_.Value}}
        $Config.Currency | Where-Object {$NewRates.$_} | ForEach-Object {$Rates[$_] = ([Double]$NewRates.$_)}
        $Config.Currency | Where-Object {-not $NewRates.$_} | Foreach-Object {$Rates[$_] = $($Ticker=Get-Ticker -Symbol $_ -PriceOnly;if($Ticker){[Double]1/$Ticker}else{0})}
    }
    catch {
        Write-Log -Level Warn "Coinbase is down. "
    }

    #PowerPrice check
    [Double]$PowerPriceBTC = 0
    if ($Config.PowerPrice -gt 0) {
        if ($NewRates."$($Config.PowerPriceCurrency)") {
            $PowerPriceBTC = [Double]$Config.PowerPrice/[Double]$NewRates."$($Config.PowerPriceCurrency)"
        } else {
            Write-Log -Level Warn "Powerprice currency $($Config.PowerPriceCurreny) not found on Coinbase. Cost of electricity will be ignored."
        }
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

    $UserConfig = $ConfigBackup = $null

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
        $AvailPools | Where-Object {$Config.Pools.$_ -and ($Config.PoolName.Count -eq 0 -or $Config.PoolName -icontains $_) -and ($Config.ExcludePoolName.Count -eq 0 -or $Config.ExcludePoolName -inotcontains $_)} | ForEach-Object {
            $Pool_Name = $_
            $SelectedPoolNames.Add($Pool_Name) > $null
            [hashtable]$Pool_Config = @{Name = $Pool_Name}
            [hashtable]$Pool_Parameters = @{StatSpan = $StatSpan;InfoOnly = $false}
            foreach($p in $Config.Pools.$Pool_Name.PSObject.Properties.Name) {$Pool_Parameters[$p] = $Config.Pools.$Pool_Name.$p}
            $Pool_Parameters.DataWindow = Get-YiiMPDataWindow $Pool_Parameters.DataWindow
            $Pool_Config.Penalty = $Pool_Parameters.Penalty = [double]$Pool_Parameters.Penalty
            $Pool_Factor = 1-[Double]($Pool_Config.Penalty + $(if (-not $Config.IgnoreFees){$Pool_Config.PoolFee}))/100
            foreach ($Pool in (Get-ChildItemContent "Pools\$($Pool_Name).ps1" -Parameters $Pool_Parameters).Content) {            
                $Pool_Config.AlgorithmList = if ($Pool.Algorithm -match "-") {@((Get-Algorithm $Pool.Algorithm), ($Pool.Algorithm -replace '\-.*$'))}else{@($Pool.Algorithm)}                
                $Pool | Add-Member -NotePropertyMembers $Pool_Config -Force
                $Pool.Price *= $Pool_Factor
                $Pool.StablePrice *= $Pool_Factor
                $NewPools.Add($Pool) > $null
            }
        }
    }

    #Remove stats from pools & miners not longer in use
    if (-not $DonateNow -and (Test-Path "Stats")) {
        if ($SelectedPoolNames -and $SelectedPoolNames.Count -gt 0) {Compare-Object @($SelectedPoolNames | Select-Object) @($Stats.Keys | Where-Object {$_ -match '^(.+?)_.+Profit$'} | % {$Matches[1]} | Select-Object -Unique) | Where-Object SideIndicator -eq "=>" | Foreach-Object {Get-ChildItem "Stats\$($_.InputObject)_*_Profit.txt" -File | Where-Object LastWriteTime -lt (Get-Date).AddDays(-7) | Remove-Item -Force}}
        if ($AvailMiners -and $AvailMiners.Count -gt 0) {Compare-Object @($AvailMiners | Select-Object) @($Stats.Keys | Where-Object {$_ -match '^(.+?)-.+Hashrate$'} | % {$Matches[1]} | Select-Object -Unique) | Where-Object SideIndicator -eq "=>" | Foreach-Object {Get-ChildItem "Stats\$($_.InputObject)-*_Hashrate.txt" -File | Where-Object LastWriteTime -lt (Get-Date).AddDays(-7) | Remove-Item -Force}}
    }

    #Give API access to the current running configuration
    $API.NewPools = $NewPools

    #This finds any pools that were already in $AllPools (from a previous loop) but not in $NewPools. Add them back to the list. Their API likely didn't return in time, but we don't want to cut them off just yet
    #since mining is probably still working.  Then it filters out any algorithms that aren't being used.
    [System.Collections.ArrayList]$AllPoolsAddRemove = @()
    foreach ($Pool in @(Compare-Object @($NewPools.Name | Select-Object -Unique) @($AllPools.Name | Select-Object -Unique) | Where-Object SideIndicator -EQ "=>" | Select-Object -ExpandProperty InputObject | ForEach-Object {$AllPools | Where-Object Name -EQ $_})) {$AllPoolsAddRemove.Add($Pool) > $null}
    [System.Collections.ArrayList]$AllPools = @($NewPools)
    if ($AllPoolsAddRemove.Count) {$AllPools.Add($AllPoolsAddRemove) > $null}
    $AllPoolsAddRemove.Clear()

    #Now remove all deselected pool/algorithm/coin from AllPools
    $i=0
    foreach ($Pool in $AllPools) {
        $Pool_Name = $Pool.Name    
        if (
            (-not $Config.Pools.$Pool_Name) -or
            ($Config.Algorithm.Count -and -not (Compare-Object @($Config.Algorithm | Select-Object) @($Pool.AlgorithmList | Select-Object) -IncludeEqual -ExcludeDifferent | Measure-Object).Count) -or
            ($Config.ExcludeAlgorithm.Count -and (Compare-Object @($Config.ExcludeAlgorithm | Select-Object) @($Pool.AlgorithmList | Select-Object)  -IncludeEqual -ExcludeDifferent | Measure-Object).Count) -or 
            ($Config.PoolName.Count -and $Config.PoolName -inotcontains $Pool.Name) -or
            ($Config.ExcludePoolName.Count -and $Config.ExcludePoolName -icontains $Pool.Name) -or
            ($Config.ExcludeCoin.Count -and $Pool.CoinName -and @($Config.ExcludeCoin) -icontains $Pool.CoinName) -or
            ($Config.ExcludeCoinSymbol.Count -and $Pool.CoinSymbol -and @($Config.ExcludeCoinSymbol) -icontains $Pool.CoinSymbol) -or
            ($Config.Pools.$Pool_Name.Algorithm.Count -and -not (Compare-Object @($Config.Pools.$Pool_Name.Algorithm | Select-Object) @($Pool.AlgorithmList | Select-Object) -IncludeEqual -ExcludeDifferent | Measure-Object).Count) -or
            ($Config.Pools.$Pool_Name.ExcludeAlgorithm.Count -and (Compare-Object @($Config.Pools.$Pool_Name.ExcludeAlgorithm | Select-Object) @($Pool.AlgorithmList | Select-Object) -IncludeEqual -ExcludeDifferent | Measure-Object).Count) -or
            ($Pool.CoinName -and $Config.Pools.$Pool_Name.CoinName.Count -and @($Config.Pools.$Pool_Name.CoinName) -inotcontains $Pool.CoinName) -or
            ($Pool.CoinName -and $Config.Pools.$Pool_Name.ExcludeCoin.Count -and @($Config.Pools.$Pool_Name.ExcludeCoin) -icontains $Pool.CoinName) -or
            ($Pool.CoinSymbol -and $Config.Pools.$Pool_Name.CoinSymbol.Count -and @($Config.Pools.$Pool_Name.CoinSymbol) -inotcontains $Pool.CoinSymbol) -or
            ($Pool.CoinSymbol -and $Config.Pools.$Pool_Name.ExcludeCoinSymbol.Count -and @($Config.Pools.$Pool_Name.ExcludeCoinSymbol) -icontains $Pool.CoinSymbol)
        ) {$AllPoolsAddRemove.Add($Pool) > $null}
        $i++
    }
    foreach($Pool in $AllPoolsAddRemove) {$AllPools.Remove($Pool)}
    $AllPoolsAddRemove.Clear()

    #Give API access to the current running configuration
    $API.AllPools = $AllPools

    #Apply watchdog to pools
    foreach ($Pool in $AllPools) {
        $Pool_WatchdogTimers = $WatchdogTimers | Where-Object PoolName -EQ $Pool.Name | Where-Object Kicked -LT $Timer.AddSeconds( - $WatchdogInterval) | Where-Object Kicked -GT $Timer.AddSeconds( - $WatchdogReset)
        if (($Pool_WatchdogTimers | Measure-Object).Count -ge <#stage#>3 -or ($Pool_WatchdogTimers | Where-Object {$Pool.Algorithm -contains $_.Algorithm} | Measure-Object).Count -ge <#statge#>2) {$AllPoolsAddRemove.Add($Pool) > $null}
    }
    foreach($Pool in $AllPoolsAddRemove) {$AllPools.Remove($Pool)}
    $AllPoolsAddRemove = $null

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
            $p = @($_.Content.HashRates.PSObject.Properties.Name | Foreach-Object {$_ -replace '\-.*$'} | Select-Object)
            $_.Content | Add-Member -NotePropertyMembers @{Name=$_.Name;BaseName=$_.BaseName;BaseAlgorithm=$p;PowerDraw=$Stats."$($_.Name)_$($p[0])_HashRate".PowerDraw_Average} -PassThru -Force
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

                $ComboMiner.PowerDraw = ($AllMiners | 
                    Where-Object {$_.BaseName -eq $ComboMiner.BaseName -and $_.DeviceModel -notmatch '-' -and $($ComboMiner.Name -replace "-GPU.+$","") -eq $($_.Name -replace "-GPU.+$","") -and @($ComboMiner.DeviceModel -split '-') -icontains $_.DeviceModel -and (Compare-Object @($ComboAlgos) @($_.HashRates.PSObject.Properties.Name) | Measure-Object).Count -eq 0} |
                    Select-Object -ExpandProperty PowerDraw |
                    Measure-Object -Sum).Sum 
            }
        }
    }
    
    Write-Log "Calculating profit for each miner. "

    [hashtable]$AllMiners_VersionCheck = @{}
    foreach ($Miner in $AllMiners) {
        $Miner_HashRates = [PSCustomObject]@{}
        $Miner_DevFees = [PSCustomObject]@{}
        $Miner_Pools = [PSCustomObject]@{}
        $Miner_Pools_Comparison = [PSCustomObject]@{}
        $Miner_Profits = [PSCustomObject]@{}
        $Miner_Profits_Comparison = [PSCustomObject]@{}
        $Miner_Profits_MarginOfError = [PSCustomObject]@{}
        $Miner_Profits_Bias = [PSCustomObject]@{}
        $Miner_Profits_Unbias = [PSCustomObject]@{}
        $Miner_OCprofile = [hashtable]@{}

        if ($Config.Miners) {
            $Miner_CommonCommands = $Miner_Arguments = ''
            $Miner_MSIAprofile = 0           
            $Miner_Penalty = $Miner_ExtendInterval = $Miner_FaultTolerance = -1
            $Miner_CommonCommands_found = $false
            [System.Collections.ArrayList]$Miner_CommonCommands_array = @($Miner.BaseName,$Miner.DeviceModel)
            $Miner_CommonCommands_array.AddRange(@($Miner.BaseAlgorithm | Select-Object))
            for($i=$Miner_CommonCommands_array.Count;$i -gt 0; $i--) {
                $Miner_CommonCommands = $Miner_CommonCommands_array.GetRange(0,$i) -join '-'
                if (Get-Member -InputObject $Config.Miners -Name $Miner_CommonCommands -MemberType NoteProperty) {
                    if ($Config.Miners.$Miner_CommonCommands.Params -and $Miner_Arguments -eq '') {$Miner_Arguments = $Config.Miners.$Miner_CommonCommands.Params}
                    if ($Config.Miners.$Miner_CommonCommands.MSIAprofile -and $Miner_MSIAprofile -eq 0) {$Miner_MSIAprofile = [int]$Config.Miners.$Miner_CommonCommands.MSIAprofile}
                    if ($Config.Miners.$Miner_CommonCommands.OCprofile) {if ($Config.MiningMode -eq "combo" -and $Miner.DeviceModel -match '-') {@($Miner.DeviceModel -split '-') | Foreach-Object {$Miner_OCprofile[$_]=$Config.Miners.$Miner_CommonCommands.OCprofile}}else{$Miner_OCprofile[$Miner.DeviceModel]=$Config.Miners.$Miner_CommonCommands.OCprofile}}
                    if ($Config.Miners.$Miner_CommonCommands.Penalty -ne $null -and $Config.Miners.$Miner_CommonCommands.Penalty -ne '' -and $Miner_Penalty -eq -1) {$Miner_Penalty = [double]$Config.Miners.$Miner_CommonCommands.Penalty}
                    if ($Config.Miners.$Miner_CommonCommands.ExtendInterval -and $Miner_ExtendInterval -eq -1) {$Miner_ExtendInterval = [int]$Config.Miners.$Miner_CommonCommands.ExtendInterval}
                    if ($Config.Miners.$Miner_CommonCommands.FaultTolerance -and $Miner_FaultTolerance -eq -1) {$Miner_FaultTolerance = [double]$Config.Miners.$Miner_CommonCommands.FaultTolerance}
                    $Miner_CommonCommands_found = $true
                }
            }
            if (-not $Miner_CommonCommands_found -and $Config.MiningMode -eq "combo" -and $Miner.DeviceModel -match '-') {
                #combo handling - we know that combos always have equal params, because we preselected them, already
                foreach($p in @($Miner.DeviceModel -split '-')) {
                    $Miner_CommonCommands_array[1] = $p
                    $Miner_CommonCommands = $Miner_CommonCommands_array -join '-'
                    if ($Config.Miners.$Miner_CommonCommands.Params -and $Miner_Arguments -eq '') {$Miner_Arguments = $Config.Miners.$Miner_CommonCommands.Params}
                    if ($Config.Miners.$Miner_CommonCommands.MSIAprofile -and $Miner_MSIAprofile -ge 0 -and $Config.Miners.$Miner_CommonCommands.MSIAprofile -ne $Miner_MSIAprofile) {$Miner_MSIAprofile = if (-not $Miner_MSIAprofile){[int]$Config.Miners.$Miner_CommonCommands.MSIAprofile}else{-1}}
                    if ($Config.Miners.$Miner_CommonCommands.OCprofile) {$Miner_OCprofile[$p] = $Config.Miners.$Miner_CommonCommands.OCprofile}
                    if ($Config.Miners.$Miner_CommonCommands.Penalty -ne $null -and $Config.Miners.$Miner_CommonCommands.Penalty -ne '' -and [double]$Config.Miners.$Miner_CommonCommands.Penalty -gt $Miner_Penalty) {$Miner_Penalty = [double]$Config.Miners.$Miner_CommonCommands.Penalty}
                    if ($Config.Miners.$Miner_CommonCommands.ExtendInterval -and [int]$Config.Miners.$Miner_CommonCommands.ExtendInterval -gt $Miner_ExtendInterval) {$Miner_ExtendInterval = [int]$Config.Miners.$Miner_CommonCommands.ExtendInterval}
                    if ($Config.Miners.$Miner_CommonCommands.FaultTolerance -and [double]$Config.Miners.$Miner_CommonCommands.FaultTolerance -gt $Miner_FaultTolerance) {$Miner_FaultTolerance = [double]$Config.Miners.$Miner_CommonCommands.FaultTolerance}
                }
            }
            if ($Miner_Arguments -ne '' -and $Miner.Arguments -is [string]) {$Miner | Add-Member -Name Arguments -Value (@($Miner.Arguments,$Miner_Arguments) -join ' ') -MemberType NoteProperty -Force}
            if ($Miner_MSIAprofile -ne 0) {$Miner | Add-Member -Name MSIAprofile -Value $($Miner_MSIAprofile) -MemberType NoteProperty -Force}           
            if ($Miner_Penalty -ne -1) {$Miner | Add-Member -Name Penalty -Value $($Miner_Penalty) -MemberType NoteProperty -Force}
            if ($Miner_ExtendInterval -ne -1) {$Miner | Add-Member -Name ExtendInterval -Value $($Miner_ExtendInterval) -MemberType NoteProperty -Force}
            if ($Miner_FaultTolerance -ne -1) {$Miner | Add-Member -Name FaultTolerance -Value $($Miner_FaultTolerance) -MemberType NoteProperty -Force}            
        }

        $Miner.HashRates.PSObject.Properties.Name | ForEach-Object { #temp fix, must use 'PSObject.Properties' to preserve order
            $Miner_DevFees | Add-Member $_ ([Double]$(if (-not $Config.IgnoreFees -and $Miner.DevFee) {[Double]$(if (@("Hashtable","PSCustomObject") -icontains $Miner.DevFee.GetType().Name) {$Miner.DevFee.$_} else {$Miner.DevFee})} else {0})) -Force
            $Miner_DevFeeFactor = (1-$Miner_DevFees.$_/100)
            if ($Miner.Penalty) {$Miner_DevFeeFactor -= [Double]$(if (@("Hashtable","PSCustomObject") -icontains $Miner.Penalty.GetType().Name) {$Miner.Penalty.$_} else {$Miner.Penalty})/100;if ($Miner_DevFeeFactor -lt 0){$Miner_DevFeeFactor=0}}
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

        $Miner_Profit_Cost = [Double]($Miner.PowerDraw*24/1000 * $PowerPriceBTC)

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
                $Miner_Profit_Cost = $null
            }
        }

        $Miner | Add-Member HashRates $Miner_HashRates -Force
        $Miner | Add-Member DevFee $Miner_DevFees -Force
        $Miner | Add-Member OCprofile $Miner_OCprofile -Force

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
        $Miner | Add-Member Profit_Cost $Miner_Profit_Cost

        if ($Config.UsePowerPrice -and $Miner.Profit_Cost -ne $null -and $Miner.Profit_Cost -gt 0) {
            $Miner.Profit -= $Miner.Profit_Cost
            $Miner.Profit_Comparison -= $Miner.Profit_Cost
            $Miner.Profit_Bias -= $Miner.Profit_Cost
            $Miner.Profit_Unbias -= $Miner.Profit_Cost
        }

        $Miner | Add-Member DeviceName @($Miner.DeviceName | Select-Object -Unique | Sort-Object) -Force

        $Miner.Path = $ExecutionContext.SessionState.Path.GetUnresolvedProviderPathFromPSPath($Miner.Path)
        if ($Miner.PrerequisitePath) {$Miner.PrerequisitePath = $ExecutionContext.SessionState.Path.GetUnresolvedProviderPathFromPSPath($Miner.PrerequisitePath)}

        if (-not $AllMiners_VersionCheck.ContainsKey($Miner.BaseName)) {
            $Miner_UriJson = (Split-Path $Miner.Path) + "\_uri.json"
            $Miner_Uri = ""
            if ((Test-Path $Miner.Path) -and (Test-Path $Miner_UriJson)) {$Miner_Uri = Get-Content $Miner_UriJson -Raw -ErrorAction Ignore | ConvertFrom-Json -ErrorAction Ignore | Select-Object -ExpandProperty URI}
            $AllMiners_VersionCheck[$Miner.BaseName] = $Miner_Uri -eq $Miner.URI
        }
        $Miner | Add-Member VersionCheck $AllMiners_VersionCheck[$Miner.BaseName]
  
        if ($Miner.Arguments -is [string]) {$Miner.Arguments = ($Miner.Arguments -replace "\s+"," ").trim()}
        else {$Miner.Arguments = $Miner.Arguments | ConvertTo-Json -Depth 10 -Compress}
        
        
        if ($Miner.ExecName -eq $null) {$Miner | Add-Member ExecName ([IO.FileInfo]($Miner.Path | Split-Path -Leaf -ErrorAction Ignore)).BaseName -Force}
        if (-not $Miner.ExtendInterval) {$Miner | Add-Member ExtendInterval 0 -Force}
        if (-not $Miner.FaultTolerance) {$Miner | Add-Member FaultTolerance 0.1 -Force}
        if (-not $Miner.Penalty) {$Miner | Add-Member Penalty 0 -Force}
        if (-not $Miner.API) {$Miner | Add-Member API "Miner" -Force}
        if (-not $Miner.ManualUri -and $Miner.Uri -notmatch "RainbowMiner" -and $Miner.Uri -match "^(.+?github.com/.+?/releases)") {$Miner | Add-Member ManualUri $Matches[1] -Force}
    }
    $Miners = $AllMiners | Where-Object {(Test-Path $_.Path) -and ((-not $_.PrerequisitePath) -or (Test-Path $_.PrerequisitePath)) -and $_.VersionCheck}
    $Miners_Downloading = $AllMiners.Count - $Miners.Count
    if (($StartDownloader -or $Miners_Downloading -ne 0) -and $Downloader.State -ne "Running") {
        $Miners_Downloading = (Compare-Object @($Miners.URI | Select-Object -Unique) @($AllMiners.URI | Select-Object -Unique) | Where-Object SideIndicator -eq "=>" | Measure-Object).Count
        Clear-Host
        Write-Log "Starting downloader."
        $Downloader = Start-Job -InitializationScript ([scriptblock]::Create("Set-Location('$(Get-Location)')")) -ArgumentList (@($AllMiners | Where-Object {$_.PrerequisitePath} | Select-Object @{name = "URI"; expression = {$_.PrerequisiteURI}}, @{name = "Path"; expression = {$_.PrerequisitePath}}, @{name = "Searchable"; expression = {$false}}, @{name = "IsMiner"; expression = {$false}}) + @($AllMiners | Select-Object URI, Path, @{name = "Searchable"; expression = {$Miner = $_; ($AllMiners | Where-Object {(Split-Path $_.Path -Leaf) -eq (Split-Path $Miner.Path -Leaf) -and $_.URI -ne $Miner.URI}).Count -eq 0}}, @{name = "IsMiner"; expression = {$true}}) | Select-Object * -Unique) -FilePath .\Downloader.ps1
        $StartDownloader = $false
    }
    $AllMiners_VersionCheck = $null

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
        if ($Miners_Downloading -gt 0) {
            Write-Host " "
            Write-Host "Downloading first miners, mining operation will start in $($Config.Interval) seconds. Please be patient!" -ForegroundColor Black -BackgroundColor Yellow
        }
        if ($Downloader) {$Downloader | Receive-Job}
        Start-Sleep $Config.Interval
        continue
    }

    foreach($Miner in $ActiveMiners) {
        $Miner.Profit = 0
        $Miner.Profit_Comparison = 0
        $Miner.Profit_MarginOfError = 0
        $Miner.Profit_Bias = 0
        $Miner.Profit_Unbias = 0
        $Miner.Profit_Cost = 0
        $Miner.Best = $false
        $Miner.Best_Comparison = $false
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
            $ActiveMiner.Profit_Cost = $Miner.Profit_Cost
            $ActiveMiner.PowerDraw = $Miner.PowerDraw
            $ActiveMiner.Speed = $Miner.HashRates.PSObject.Properties.Value #temp fix, must use 'PSObject.Properties' to preserve order
            $ActiveMiner.DeviceName = $Miner.DeviceName
            $ActiveMiner.DeviceModel = $Miner.DeviceModel
            $ActiveMiner.ShowMinerWindow = ($Miner.ShowMinerWindow -or $Config.ShowMinerWindow)
            $ActiveMiner.DevFee = $Miner.DevFee
            $ActiveMiner.MSIAprofile = $Miner.MSIAprofile
            $ActiveMiner.OCprofile = $Miner.OCprofile
            $ActiveMiner.FaultTolerance = $Miner.FaultTolerance
            $ActiveMiner.Penalty = $Miner.Penalty
            $ActiveMiner.ManualUri = $Miner.ManualUri
            $ActiveMiner.EthPillEnable = $Config.EthPillEnable
        }
        else {
            $NewMiner = New-Object $Miner.API -Property @{
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
                Profit_Cost          = $Miner.Profit_Cost
                PowerDraw            = $Miner.PowerDraw
                Speed                = $Miner.HashRates.PSObject.Properties.Value #temp fix, must use 'PSObject.Properties' to preserve order
                Speed_Live           = 0
                Best                 = $false
                Best_Comparison      = $false
                New                  = $false
                Benchmarked          = 0
                Pool                 = $Miner.Pools.PSObject.Properties.Value.Name
                MSIAprofile          = $Miner.MSIAprofile
                OCprofile            = $Miner.OCprofile
                ExtendInterval       = $Miner.ExtendInterval
                ShowMinerWindow      = ($Miner.ShowMinerWindow -or $Config.ShowMinerWindow)
                DevFee               = $Miner.DevFee
                ExecName             = $Miner.ExecName
                FaultTolerance       = $Miner.FaultTolerance
                Penalty              = $Miner.Penalty
                ManualUri            = $Miner.ManualUri
                EthPillEnable        = $Config.EthPillEnable
            }
            $ActiveMiners.Add($NewMiner) > $null
        }
    }

    #Don't penalize active miners
    foreach($Miner in $ActiveMiners) {if ($SkipSwitchingPrevention -or ($Miner.GetStatus() -eq [MinerStatus]::Running)) {$Miner.Profit_Bias = $Miner.Profit_Unbias}}

    #Get most profitable miner combination i.e. AMD+NVIDIA+CPU
    $BestMiners = $ActiveMiners | Select-Object DeviceName -Unique | ForEach-Object {$Miner_GPU = $_; ($ActiveMiners | Where-Object {(Compare-Object $Miner_GPU.DeviceName $_.DeviceName | Measure-Object).Count -eq 0} | Sort-Object -Descending {($_ | Where-Object Profit -EQ $null | Measure-Object).Count}, {($_ | Measure-Object Profit_Bias -Sum).Sum}, {($_ | Where-Object Profit -NE 0 | Measure-Object).Count}, {$_.Benchmarked}, {if ($Config.DisableExtendInterval){0}else{$_.ExtendInterval}} | Select-Object -First 1)}
    $BestMiners_Comparison = $ActiveMiners | Select-Object DeviceName -Unique | ForEach-Object {$Miner_GPU = $_; ($ActiveMiners | Where-Object {(Compare-Object $Miner_GPU.DeviceName $_.DeviceName | Measure-Object).Count -eq 0} | Sort-Object -Descending {($_ | Where-Object Profit -EQ $null | Measure-Object).Count}, {($_ | Measure-Object Profit_Comparison -Sum).Sum}, {($_ | Where-Object Profit -NE 0 | Measure-Object).Count}, {$_.Benchmarked}, {if ($Config.DisableExtendInterval){0}else{$_.ExtendInterval}} | Select-Object -First 1)}
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

    $BestMiners_Profitable = $true
    if ($Config.UsePowerPrice -and ($Miners | Where-Object {$_.HashRates.PSObject.Properties.Value -contains $null} | Measure-Object).Count -eq 0 -and ($ActiveMiners | Where-Object Profit -gt 0 | Measure-Object).Count -eq 0) {
        Write-Log -Level Warn "No more miners are profitable. $(if ($Config.CheckProfitability) {" Waiting for profitability."})"
        if ($Config.CheckProfitability) {$BestMiners_Profitable = $false}
    }

    if (-not $PauseMiners -and $BestMiners_Profitable) {
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
    if ($Config.Delay -gt 0) {Start-Sleep $Config.Delay} #Wait to prevent BSOD

    $ActiveMiners | Where-Object Best -EQ $true | ForEach-Object {
        if ($_.GetStatus() -ne [MinerStatus]::Running) {

            #Set MSI Afterburner profile
            if ($MSIAenabled) {
                $MSIAplannedprofile = $ActiveMiners | Where-Object {$_.Best -eq $true -and $_.MSIAprofile -ne $null -and $_.MSIAprofile -gt 0} | Select-Object -ExpandProperty MSIAprofile -Unique
                if (-not $MSIAplannedprofile.Count) {$MSIAplannedprofile = $Config.MSIAprofile}                
                else {$MSIAplannedprofile = $MSIAplannedprofile | Select-Object -Index 0}
                Start-Process -FilePath "$($Config.MSIApath)" -ArgumentList "-Profile$($MSIAplannedprofile)" -Verb RunAs
                if ($MSIAplannedprofile -ne $MSIAcurrentprofile) {
                    Write-Log "New MSI Afterburner profile set: $($MSIAplannedprofile)"                
                    $MSIAcurrentprofile = $MSIAplannedprofile
                    Start-Sleep 1
                }
            } elseif ($Config.EnableOCprofiles) {
                Start-Sleep -Milliseconds 500
                $_.SetOCprofile($Config.OCprofiles)
                Start-Sleep -Milliseconds 500
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

    #Get count of miners, that need to be benchmarked. If greater than 0, the UIstyle "full" will be used    
    $MinersNeedingBenchmark = @($Miners | Where-Object {$_.HashRates.PSObject.Properties.Value -contains $null})
    $API.MinersNeedingBenchmark = $MinersNeedingBenchmark

    #Give API access to WatchdogTimers information
    $API.WatchdogTimers = $WatchdogTimers

    #Update API miner information
    $API.ActiveMiners = $ActiveMiners
    $API.RunningMiners = $RunningMiners = $ActiveMiners | Where-Object {$_.GetStatus() -eq [MinerStatus]::Running} | Foreach-Object {$_ | Add-Member ActiveTime $_.GetActiveTime() -Force -PassThru}
    $API.FailedMiners = $ActiveMiners | Where-Object {$_.GetStatus() -eq [MinerStatus]::Failed}

    #
    #Start output to host
    #
    Clear-Host

    $LimitMiners = if ($Config.UIstyle -eq "full" -or $MinersNeedingBenchmark.Count -gt 0) {100} else {3}

    #Display mining information
    $Miners | Select-Object DeviceName, DeviceModel -Unique | Sort-Object DeviceModel | ForEach-Object {
        $Miner_DeviceName = $_.DeviceName
        $Miner_DeviceModel = $_.DeviceModel
        $Miner_DeviceTitle = @($Devices | Where-Object {$Miner_DeviceName -icontains $_.Name} | Select-Object -ExpandProperty Model_Name -Unique | Sort-Object | Foreach-Object {"$($_) ($(@($Devices | Where-Object Model_Name -eq $_ | Select-Object -ExpandProperty Name | Sort-Object) -join ','))"}) -join ', '
        Write-Host $Miner_DeviceTitle
        Write-Host $("=" * $Miner_DeviceTitle.Length)

        [System.Collections.ArrayList]$Miner_Table = @(
            @{Label = "Miner"; Expression = {$_.Name -replace '\-.*$'}},
            @{Label = "Fee"; Expression = {($_.DevFee.PSObject.Properties.Value | ForEach-Object {if ($_) {'{0:p2}' -f ($_/100) -replace ",*0+\s%"," %"}else {"-"}}) -join ','}; Align = 'right'},
            @{Label = "Algorithm"; Expression = {$_.HashRates.PSObject.Properties.Name}},
            @{Label = "Speed"; Expression = {$_.HashRates.PSObject.Properties.Value | ForEach-Object {if ($_ -ne $null) {"$($_ | ConvertTo-Hash)/s"}else {"Benchmarking"}}}; Align = 'right'},
            @{Label = "Power"; Expression = {"{0:d}W" -f [int]$_.PowerDraw}; Align = 'right'}
        )
        foreach($Miner_Currency in @($Config.Currency | Sort-Object)) {
            $Miner_Table.Add(@{Label = "$Miner_Currency/Day $($_.Profit)"; Expression = [scriptblock]::Create("if (`$_.Profit) {ConvertTo-LocalCurrency `$(`$_.Profit) $($Rates.$Miner_Currency) -Offset 2} else {`"Unknown`"}"); Align = "right"}) > $null
        }                        
        $Miner_Table.AddRange(@(
            @{Label = "Accuracy"; Expression = {$_.Pools.PSObject.Properties.Value.MarginOfError | ForEach-Object {(1 - $_).ToString("P0")}}; Align = 'right'}, 
            @{Label = "Pool"; Expression = {$_.Pools.PSObject.Properties.Value | ForEach-Object {"$($_.Name)$(if ($_.CoinName) {"-$($_.CoinName)"})"}}}
            @{Label = "PoolFee"; Expression = {$_.Pools.PSObject.Properties.Value | ForEach-Object {if ($_.PoolFee) {'{0:p2}' -f ($_.PoolFee/100) -replace ",*0+\s%"," %"}else {"-"}}}; Align = 'right'}
        )) > $null

        $Miners | Where-Object {$_.DeviceModel -eq $Miner_DeviceModel} | Where-Object {$_.Profit -ge 1E-5 -or $_.Profit -eq $null} | Sort-Object DeviceModel, @{Expression = {if ($MinersNeedingBenchmark.Count -gt 0) {$_.HashRates.PSObject.Properties.Name}}}, @{Expression = {if ($MinersNeedingBenchmark.Count -gt 0) {$_.Profit}}; Descending = $true}, @{Expression = {if ($MinersNeedingBenchmark.Count -lt 1) {[double]$_.Profit_Bias}}; Descending = $true} | Select-Object -First $($LimitMiners) | Format-Table $Miner_Table | Out-Host
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
            $MinersNeedingBenchmarkWithEI = ($MinersNeedingBenchmark | Where-Object {$_.ExtendInterval -gt 1 -and $_.ExtendInterval -ne $null} | Measure-Object).Count
            if (-not $Config.DisableExtendInterval -and $MinersNeedingBenchmarkWithEI -gt 0) {
                Write-Host " "
                Write-Host "Please be patient!" -BackgroundColor Yellow -ForegroundColor Black
                Write-Host "RainbowMiner will benchmark the following $($MinersNeedingBenchmarkWithEI) miner$(if ($MinersNeedingBenchmarkWithEI -gt 1){'s'}) with extended intervals!" -ForegroundColor Yellow
                Write-Host "These algorithm need a longer time to reach an accurate average hashrate." -ForegroundColor Yellow
                Write-Host "After that, benchmarking will be much faster (1-2 minutes per miner)." -ForegroundColor Yellow
                Write-Host "If you do not want that accuracy, set DisableExtendInterval to 0 in your config.txt" -ForegroundColor Yellow
                $OldForegroundColor = [console]::ForegroundColor
                [console]::ForegroundColor = "Yellow"
                $MinersNeedingBenchmark | Select-Object BaseName,BaseAlgorithm,ExtendInterval | Where-Object {$_.ExtendInterval -gt 1 -and $_.ExtendInterval -ne $null} | Sort-Object -Property @{Expression = {$_.ExtendInterval}; Descending = $True},@{Expression = {$_.BaseName + $_.BaseAlgorithm -join '-'}; Descending = $False} | Format-Table (
                    @{Label = "Miner"; Expression = {$_.BaseName}},
                    @{Label = "Algorithms"; Expression = {$_.BaseAlgorithm -join '-'}},
                    @{Label = "Aprox. Time"; Expression = {"$($_.ExtendInterval)-$($_.ExtendInterval*2) minutes"}}
                )
                [console]::ForegroundColor = $OldForegroundColor
            }
        }
    }

    if ($Miners_Downloading) {
        Write-Host " "
        Write-Host "Currently downloading $Miners_Downloading miner$(if($Miners_Downloading -gt 1){"s"}) in the background." -ForegroundColor Yellow
    }

    #Extend benchmarking interval to the maximum from running miners
    $WatchdogResetOld = $WatchdogReset
    $ExtendInterval = if ($Config.DisableExtendInterval) {1} else {(@(1) + [int[]]@($RunningMiners | Where-Object {$_.Speed -eq $null} | Select-Object -ExpandProperty ExtendInterval) | Measure-Object -Maximum).Maximum}
    if ($ExtendInterval -gt 1) {
        $StatEnd = $StatEnd.AddSeconds($Config.Interval * $ExtendInterval)
        $StatSpan = New-TimeSpan $StatStart $StatEnd
        $WatchdogInterval = ($WatchdogInterval / $Strikes * ($Strikes - 1)) + $StatSpan.TotalSeconds
        $WatchdogReset = ($WatchdogReset / ($Strikes * $Strikes * $Strikes) * (($Strikes * $Strikes * $Strikes) - 1)) + $StatSpan.TotalSeconds
        Write-Log -Level Warn "Benchmarking watchdog sensitive algorithm or miner. Increasing interval time temporarily to $($ExtendInterval)x interval ($($Config.Interval * $ExtendInterval) seconds). "
    }

    #Display active miners list
    $ActiveMiners | Where-Object {$_.GetActivateCount() -GT 0 -and ($Config.UIstyle -eq "full" -or $MinersNeedingBenchmark.Count -gt 0 -or $_.GetStatus() -eq [MinerStatus]::Running)} | Sort-Object -Property @{Expression = {$_.GetStatus()}; Descending = $False}, @{Expression = {$_.GetActiveLast()}; Descending = $True} | Select-Object -First (1 + 6 + 6) | Format-Table -GroupBy @{Label = "Status"; Expression = {$_.GetStatus()}} -Wrap (
        @{Label = "Last Speed"; Expression = {$_.Speed_Live | ForEach-Object {"$($_ | ConvertTo-Hash)/s"}}; Align = 'right'}, 
        @{Label = "Active"; Expression = {"{0:dd} Days {0:hh} Hours {0:mm} Minutes" -f $_.GetActiveTime()}}, 
        @{Label = "Launched"; Expression = {Switch ($_.GetActivateCount()) {0 {"Never"} 1 {"Once"} Default {"$_ Times"}}}},      
        @{Label = "Miner"; Expression = {$_.Name -replace '\-.*$'}},
        @{Label = "Device"; Expression = {@(Get-DeviceModelName $Devices -Name @($_.DeviceName) -Short) -join ','}},
        @{Label = "Power"; Expression = {"{0:d}W" -f [int]$_.PowerDraw}},
        @{Label = "Command"; Expression = {"$($_.Path.TrimStart((Convert-Path ".\"))) $($_.Arguments)"}}
    ) | Out-Host

    if ( $Config.UIstyle -eq "full" -or $MinersNeedingBenchmark.Count -gt 0 ) {
        #Display watchdog timers
        $WatchdogTimers | Where-Object Kicked -gt $Timer.AddSeconds( - $WatchdogResetOld) | Format-Table -Wrap (
            @{Label = "Miner"; Expression = {$_.MinerName -replace '\-.*$'}},
            @{Label = "Device"; Expression = {@(Get-DeviceModelName $Devices -Name @($_.DeviceName) -Short) -join ','}}, 
            @{Label = "Pool"; Expression = {$_.PoolName}}, 
            @{Label = "Algorithm"; Expression = {$_.Algorithm}}, 
            @{Label = "Watchdog Timer"; Expression = {"{0:n0} Seconds" -f ($Timer - $_.Kicked | Select-Object -ExpandProperty TotalSeconds)}; Align = 'right'}
        ) | Out-Host
    }

    #Display profit comparison
    if ($Downloader.State -eq "Running") {$Downloader | Wait-Job -Timeout 10 > $null}
    if (($BestMiners_Combo | Where-Object Profit -EQ $null | Measure-Object).Count -eq 0 -and $Downloader.State -ne "Running") {
        $MinerComparisons = 
        [PSCustomObject]@{"Miner" = "RainbowMiner"}, 
        [PSCustomObject]@{"Miner" = $BestMiners_Combo_Comparison | ForEach-Object {"$($_.Name -replace '\-.*$')-$($_.Algorithm -join '/')"}}

        $BestMiners_Combo_Stat = Set-Stat -Name "Profit" -Value ($BestMiners_Combo | Measure-Object Profit -Sum).Sum -Duration $StatSpan

        $MinerComparisons_Profit = $BestMiners_Combo_Stat.Week, ($BestMiners_Combo_Comparison | Measure-Object Profit_Comparison -Sum).Sum

        $MinerComparisons_MarginOfError = $BestMiners_Combo_Stat.Week_Fluctuation, ($BestMiners_Combo_Comparison | ForEach-Object {$_.Profit_MarginOfError * (& {if ($MinerComparisons_Profit[1]) {$_.Profit_Comparison / $MinerComparisons_Profit[1]}else {1}})} | Measure-Object -Sum).Sum

        $Config.Currency | ForEach-Object {
            $MinerComparisons[0] | Add-Member $_.ToUpper() ("{0:N5} $([Char]0x00B1){1:P0} ({2:N5}-{3:N5})" -f ($MinerComparisons_Profit[0] * $Rates.$_), $MinerComparisons_MarginOfError[0], (($MinerComparisons_Profit[0] * $Rates.$_) / (1 + $MinerComparisons_MarginOfError[0])), (($MinerComparisons_Profit[0] * $Rates.$_) * (1 + $MinerComparisons_MarginOfError[0])))
            $MinerComparisons[1] | Add-Member $_.ToUpper() ("{0:N5} $([Char]0x00B1){1:P0} ({2:N5}-{3:N5})" -f ($MinerComparisons_Profit[1] * $Rates.$_), $MinerComparisons_MarginOfError[1], (($MinerComparisons_Profit[1] * $Rates.$_) / (1 + $MinerComparisons_MarginOfError[1])), (($MinerComparisons_Profit[1] * $Rates.$_) * (1 + $MinerComparisons_MarginOfError[1])))
        }

        if ($Config.UIstyle -eq "full" -or $MinersNeedingBenchmark.Count -gt 0) {
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
    $CurrentProfitTotal = $($RunningMiners | Measure-Object -Sum -Property Profit).Sum
    [System.Collections.ArrayList]$StatusLine = @()
    foreach($Miner_Currency in @($Config.Currency | Sort-Object)) {
            $Miner_Currency_Out = $Miner_Currency
            $CurrentProfitTotal_Out = $CurrentProfitTotal
            if ($Miner_Currency -eq "BTC" -and $CurrentProfitTotal -gt 0) {
                switch ([math]::truncate([math]::log($CurrentProfitTotal, 1000))) {
                    -1 {$Miner_Currency_Out = "mBTC";$CurrentProfitTotal_Out*=1e3}
                    -2 {$Miner_Currency_Out = "µBTC";$CurrentProfitTotal_Out*=1e6}
                    -3 {$Miner_Currency_Out = "sat";$CurrentProfitTotal_Out*=1e8}
                }
            }
            $StatusLine.Add("$(ConvertTo-LocalCurrency $CurrentProfitTotal_Out $($Rates.$Miner_Currency) -Offset 2) $Miner_Currency_Out/Day") > $null
    }
    if ($Config.Currency | Where-Object {$_ -ne "BTC" -and $NewRates.$_}) {$StatusLine.Add("1 BTC = $(($Config.Currency | Where-Object {$_ -ne "BTC" -and $NewRates.$_} | Sort-Object | ForEach-Object { "$($_) $($NewRates.$_)"})  -join ' = ')") > $null}
    #$StatusLine.Add("CPU = $($AsyncLoader.ComputerStats.CpuLoad) %") > $null
    #$StatusLine.Add("Memory = $($AsyncLoader.ComputerStats.MemoryUsage) %") > $null
    #$StatusLine.Add("VirtualMemory = $($AsyncLoader.ComputerStats.VirtualMemoryUsage) %") > $null
    #$StatusLine.Add("DiskFree = $($AsyncLoader.ComputerStats.DriveFree) %") > $null

    Write-Host " Profit = $($StatusLine -join ' | ') " -BackgroundColor White -ForegroundColor Black
    Write-Host " "

    #Check for updated RainbowMiner
    $API.Version = $ConfirmedVersion = Confirm-Version $Version
    if ($ConfirmedVersion.RemoteVersion -gt $ConfirmedVersion.Version) {
        if ($Config.EnableAutoUpdate) {
            Write-Host "Automatic update to v$($ConfirmedVersion.RemoteVersion) will begin in some seconds" -ForegroundColor Yellow            
            $API.Update = $true
        } else {
            Write-Host "To start update, press key `"U`"" -ForegroundColor Yellow            
        }
        Write-Host " "
    }

    #Reduce Memory
    Get-Job -State Completed | Remove-Job
    [GC]::Collect()
    Sleep -Milliseconds 200

    $Error.Clear()
    
    #Do nothing for a few seconds as to not overload the APIs and display miner download status
    $AutoUpdate = $SkipSwitchingPrevention = $Stopp = $false

    $WaitTimer = (Get-Date).ToUniversalTime()
    $WaitSeconds = [int]($StatEnd - $WaitTimer).TotalSeconds

    Write-Log "Start waiting $($WaitSeconds) seconds before next run. "

    $Host.UI.RawUI.FlushInputBuffer()

    $cursorPosition = $host.UI.RawUI.CursorPosition
    Write-Host ("Waiting $($WaitSeconds)s until next run: $(if ($ConfirmedVersion.RemoteVersion -gt $ConfirmedVersion.Version) {"[U]pdate RainbowMiner, "})E[x]it RainbowMiner, [S]kip switching prevention, [C]onfiguration, [V]erbose{verboseoff}, [P]ause{pauseoff}" -replace "{verboseoff}",$(if ($Config.UIstyle -eq "full"){" off"}) -replace "{pauseoff}",$(if ($PauseMiners){" off"}))
    if ($ShowTimer) {$cursorPosition = $host.UI.RawUI.CursorPosition}

    $keyPressed = $false
    $TimerBackup = $Timer
    $WaitMaxI = $Strikes*5
    $WaitTotalSeconds = [int](($StatEnd - $WaitTimer).TotalSeconds / 2 + 0.5)
    for ($i = $WaitMaxI; -not $keyPressed -and -not $SkipSwitchingPrevention -and -not $StartDownloader -and -not $Stopp -and (($i -ge 0) -or ($Timer -lt $StatEnd)); $i--) {
        if ($ShowTimer) {
            $host.UI.RawUI.CursorPosition = $CursorPosition    
            if ($WaitTotalSeconds -gt $WaitMaxI) {
                $WaitRmgSeconds = [int](($StatEnd - $WaitTimer).TotalSeconds / 2 + 0.5)
                if ($WaitRmgSeconds -gt $WaitTotalSeconds) {$WaitRmgSeconds = $WaitTotalSeconds}
                Write-Host -Verbose -NoNewline "[$("*" * ($WaitTotalSeconds - $WaitRmgSeconds))$("." * $WaitRmgSeconds)]"
            } else {
                Write-Host -Verbose -NoNewline "[$("*" * ($WaitMaxI - $i))$("." * $i)]"
            }
        }
        if (($WaitMaxI-$i) % 5 -eq 0) {
            #get data from downloader every ten seconds, starting at once
            if ($Downloader) {$Downloader | Receive-Job}
            #Give API access to computerstats
            $API.ComputerStats = $AsyncLoader.ComputerStats
        }

        Start-Sleep 2

        if (($WaitMaxI-$i+1) % 5 -eq 0) {
            #pick up a sample every ten seconds, starting after ten seconds
            
            Update-DeviceInformation @($ActiveMiners.DeviceName | Select-Object -Unique)

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
            if ($UseTimeSync) {Test-TimeSync}
            $Timer = (Get-Date).ToUniversalTime()
        }
        $WaitTimer = $Timer
        $keyPressedValue = $false

        if ((Test-Path ".\stopp.txt") -or $API.Stop) {$keyPressedValue = "X"}
        elseif ($API.Pause -ne $PauseMiners) {$keyPressedValue = "P"}
        elseif ($API.Update) {$keyPressedValue = "U"}
        elseif ([console]::KeyAvailable) {$keyPressedValue = $([System.Console]::ReadKey($true)).key}

        if ($keyPressedValue) {
            switch ($keyPressedValue) {
                "S" { 
                    $SkipSwitchingPrevention = $true
                    $host.UI.RawUI.CursorPosition = $CursorPosition
                    Write-Log "User requests to skip switching prevention. "
                    Write-Host -NoNewline "[S] pressed - skip switching prevention in next run. "
                    $keyPressed = $true
                }
                "X" {
                    $Stopp = $true
                    $host.UI.RawUI.CursorPosition = $CursorPosition
                    Write-Log "User requests to stop script. "
                    Write-Host -NoNewline "[X] pressed - stopping script."
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
                "U" {
                    $AutoUpdate = $Stopp = $true
                    Write-Log "User requests to update to v$($ConfirmedVersion.RemoteVersion)"
                    Write-Host -NoNewline "[U] pressed - automatic update of Rainbowminer will be started "
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

        if ($Miner.New) {$Miner.New = [Boolean]($Miner.Algorithm | Where-Object {-not (Get-Stat -Name "$($Miner.Name)_$($_ -replace '\-.*$')_HashRate")})}

        if ($Miner.New) {$Miner.Benchmarked++}

        if ($Miner.GetStatus() -eq "Running" -or $Miner.New) {
            $Miner_PowerDraw = $Miner.GetPowerDraw($Config.Interval * $ExtendInterval)
            $Miner.Algorithm | ForEach-Object {
                $Miner_Speed = $Miner.GetHashRate($_, $Config.Interval * $ExtendInterval, $Miner.New)
                $Miner.Speed_Live += [Double]$Miner_Speed

                if ($Miner.New -and (-not $Miner_Speed)) {$Miner_Speed = $Miner.GetHashRate($_, ($Config.Interval * $Miner.Benchmarked * $ExtendInterval), ($Miner.Benchmarked -lt $Strikes))}

                if ((-not $Miner.New) -or $Miner_Speed -or $Miner.Benchmarked -ge ($Strikes * $Strikes) -or $Miner.GetActivateCount() -ge $Strikes) {
                    $Stat = Set-Stat -Name "$($Miner.Name)_$($_ -replace '\-.*$')_HashRate" -Value $Miner_Speed -Duration $StatSpan -FaultDetection $true -FaultTolerance $Miner.FaultTolerance -PowerDraw $Miner_PowerDraw
                }

                #Update watchdog timer
                $Miner_Name = $Miner.Name
                $Miner_Algorithm = $_
                $WatchdogTimer = $WatchdogTimers | Where-Object {$_.MinerName -eq $Miner_Name -and $_.PoolName -eq $Pools.$Miner_Algorithm.Name -and $_.Algorithm -eq $Miner_Algorithm}
                if ($Stat -and $WatchdogTimer -and $Stat.Updated -gt $WatchdogTimer.Kicked) {
                    $WatchdogTimer.Kicked = $Stat.Updated
                }
                $Miner_PowerDraw = 0
            }
        }
    }

    if ($Stopp) {
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
[System.Collections.ArrayList]$ExcavatorWindowsClosed = @()
$ActiveMiners | Where-Object {$_.GetActivateCount() -gt 0} | ForEach-Object {
    $Miner = $_
    if ($Miner.GetStatus() -eq [MinerStatus]::Running) {
        Write-Log "Closing $($Miner.Type) miner $($Miner.Name)"
        $Miner.StopMining()            
    }
    if ($Miner.BaseName -like "Excavator*" -and -not $ExcavatorWindowsClosed.Contains($Miner.BaseName)) {
        $Miner.SetStatus([MinerStatus]::Failed)
        $ExcavatorWindowsClosed.Add($Miner.BaseName) > $null
    }
}

#Stop the log
Stop-Transcript

if ($AutoUpdate -and -not $psISE) {Exit 999}
