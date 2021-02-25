﻿using module .\Modules\Include.psm1

[CmdletBinding()]
param(
    [Parameter(Mandatory = $false)]
    [Alias("BTC")]
    [String]$Wallet,
    [Parameter(Mandatory = $false)]
    [Alias("Worker")]
    [String]$WorkerName = "$([System.Environment]::MachineName)",
    [Parameter(Mandatory = $false)]
    [Int]$Interval = 60, #seconds before reading hash rate from miners
    [Parameter(Mandatory = $false)]
    [Alias("Location")]
    [String]$Region = "us", #europe/us/asia
    [Parameter(Mandatory = $false)]
    [Array]$DefaultPoolRegion = @("us","eu"), #europe/us/asia
    [Parameter(Mandatory = $false)]
    [Switch]$SSL = $false, 
    [Parameter(Mandatory = $false)]
    [Alias("Device", "Type")]
    [Array]$DeviceName = @(), #i.e. CPU, GPU, GPU#02, AMD, NVIDIA, AMD#02, OpenCL#03#02 etc.
    [Parameter(Mandatory = $false)]
    [Alias("ExcludeDevice")]
    [Array]$ExcludeDeviceName = @(), #i.e. CPU, GPU, GPU#02, AMD, NVIDIA, AMD#02, OpenCL#03#02 etc.
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
    [String]$MinerStatusUrl = "https://rbminer.net", #i.e https://multipoolminer.io/monitor/miner.php
    [Parameter(Mandatory = $false)]
    [String]$MinerStatusKey = "", #will be generated during setup
    [Parameter(Mandatory = $false)]
    [String]$MinerStatusEmail = "", #if miners go offline on rbminer.net, send email to this address
    [Parameter(Mandatory = $false)]
    [Double]$MinerStatusMaxTemp = 90.0, #enter a maximum temperature for triggering a notification
    [Parameter(Mandatory = $false)]
    [Int]$MinerStatusMaxCrashesPerHour = 5, #enter the maximum crashes per hour allowed, before triggering a notification
    [Parameter(Mandatory = $false)]
    [String]$PushOverUserKey = "", #if miners go offline on rbminer.net, send notification via https://pushover.net
    [Parameter(Mandatory = $false)]
    [Double]$SwitchingPrevention = 2, #zero does not prevent miners switching
    [Parameter(Mandatory = $false)]
    [Double]$PoolSwitchingHysteresis = 3, #switching prevention against pool-to-pool hopping, hysteresis offset in percent
    [Parameter(Mandatory = $false)]
    [Double]$MinerSwitchingHysteresis = 3, #switching prevention against on pool miner-to-miner hopping, hysteresis offset in percent
    [Parameter(Mandatory = $false)]
    [Double]$MaxRejectedShareRatio = 0.3, #maximum rejected share ratio (rejected shares divided by all shares)
    [Parameter(Mandatory = $false)]
    [Double]$MaxAllowedLuck = 3, #maximum allowed luck (0.5=50%, 1=100%, 2=200% ..)
    [Parameter(Mandatory = $false)]
    [String]$MaxTimeSinceLastBlock = "12h", #maximum time since last block was found (units allowed, e.h. 1h=one hour, default unit is s=seconds)
    [Parameter(Mandatory = $false)]
    [Double]$MinComboOverSingleRatio = 0.9, #minimum ratio to prefer multi-miner over single miners (0..1)
    [Parameter(Mandatory = $false)]
    [Switch]$ShowMinerWindow = $false, #if true all miner windows will be visible (they can steal focus)
    [Parameter(Mandatory = $false)]
    [Switch]$FastestMinerOnly = $false, #if true, show the most profitable miner per algo and device index, only. E.g. if there are 2 miners available to mine the same algo, only the more profitable of the two will ever be used, the other ones will be hidden in the summary screen
    [Parameter(Mandatory = $false)]
    [Switch]$IgnoreFees = $false,
    [Parameter(Mandatory = $false)]
    [Switch]$ExcludeMinersWithFee = $false,
    [Parameter(Mandatory = $false)]
    [Switch]$DisableUnprofitableAlgolist = $false,
    [Parameter(Mandatory = $false)]
    [Switch]$DisableUnprofitableCpuAlgolist = $false,
    [Parameter(Mandatory = $false)]
    [Switch]$EnableCheckMiningConflict = $false,
    [Parameter(Mandatory = $false)]
    [Switch]$EnableEthashZombieMode = $false,
    [Parameter(Mandatory = $false)]
    [Switch]$ShowPoolBalances = $false,
    [Parameter(Mandatory = $false)]
    [Switch]$ShowPoolBalancesDetails = $false,
    [Parameter(Mandatory = $false)]
    [Switch]$ShowPoolBalancesExcludedPools = $false,
    [Parameter(Mandatory = $false)]
    [Array]$ExcludeCoinsymbolBalances = @(),
    [Parameter(Mandatory = $false)]
    [Switch]$ShowWalletBalances = $false,
    [Parameter(Mandatory = $false)]
    [Array]$WalletBalances = @(),
    [Parameter(Mandatory = $false)]
    [Switch]$DisableDualMining = $false,
    [Parameter(Mandatory = $false)]
    [int]$APIport = 4000,
    [Parameter(Mandatory = $false)]
    [String]$APIuser = "",
    [Parameter(Mandatory = $false)]
    [String]$APIpassword = "",
    [Parameter(Mandatory = $false)]
    [Bool]$APIauth = $false,
    [Parameter(Mandatory = $false)]
    [int]$APIthreads = 0,
    [Parameter(Mandatory = $false)]
    [String]$ConfigFile = "Config\config.txt", # Path to config file
    [Parameter(Mandatory = $false)]
    [Switch]$RebootOnGPUFailure = $false, # if set to $true, and a GPU fails, the mining rig will be restarted
    [Parameter(Mandatory = $false)]
    [String]$MiningMode = "combo", # set to "legacy","device","combo"
    [Parameter(Mandatory = $false)]
    [String]$MSIApath = "$(if (${env:ProgramFiles(x86)}) {${env:ProgramFiles(x86)}} else {"C:\Program Files (x86)"})\MSI Afterburner\MSIAfterburner.exe", # installation path of MSI Afterburner
    [Parameter(Mandatory = $false)]
    [Int]$MSIAprofile = 0, # default MSI Afterburner profile to be set
    [Parameter(Mandatory = $false)]
    [String]$UIstyle = "lite", # ui style: full=show all, lite=show only active miner
    [Parameter(Mandatory = $false)]
    [String]$UIsorting = "biased", # ui sorting: biased=sorted by internal switching calculus, profit=sorted by pure BTC profit number
    [Parameter(Mandatory = $false)]
    [Switch]$UseTimeSync = $false, # if set to $true, the windows time service will be used to synchronize the PC time with world time (needs admin rights)
    [Parameter(Mandatory = $false)]
    [Double]$PowerPrice = 0, # price for 1 kW/h (kilowatt per hour) in USD, EUR or other (set currency with parameter PowerPriceCurrency)
    [Parameter(Mandatory = $false)]
    [String]$PowerPriceCurrency = 'USD', # currency for price of power
    [Parameter(Mandatory = $false)]
    [Switch]$UsePowerPrice = $false, # if set to $true, the price for power will be taken into account in profit calculation
    [Parameter(Mandatory = $false)]
    [Double]$PowerOffset = 0, # power offset to allow consideration for overhead power, absolute in W
    [Parameter(Mandatory = $false)]
    [Double]$PowerOffsetPercent = 0, # power offset to allow consideration for overhead power, relative in %
    [Parameter(Mandatory = $false)]
    [Switch]$CheckProfitability = $false, # if set to $true, miners with negative profit will be excluded
    [Parameter(Mandatory = $false)]
    [Switch]$DisableExtendInterval = $false, # if set to $true, benchmark intervals will never be extended
    [Parameter(Mandatory = $false)]
    [String]$EthPillEnable = "disable", # set to RevA or RevB to enable the OhGodAnETHlargementPill for Ethash
    [Parameter(Mandatory = $false)]
    [String]$EthPillEnableMTP = "disable", # set to RevA or RevB to enable the OhGodAnETHlargementPill for MTP
    [Parameter(Mandatory = $false)]
    [Switch]$EnableOCProfiles = $false, # if set to $true, the build in overclocking profiles will be used
    [Parameter(Mandatory = $false)]
    [Switch]$EnableOCVoltage = $false, # if set to $true, overclocking setting include voltage
    [Parameter(Mandatory = $false)]
    [Switch]$EnableOCLinuxSetAllPStates = $false, # if set to $true, all P-States will be get the mem/core clock offsets.
    [Parameter(Mandatory = $false)]
    [Switch]$EnableOCLinuxForcePState = $false, # if set to $true, all P-States will be forced to it's workload state.
    [Parameter(Mandatory = $false)]
    [Switch]$EnableLinuxHeadless = $false, # if set to $true, overclocking settings will include export DISPLAY=:0
    [Parameter(Mandatory = $false)]
    [Switch]$EnableAutoUpdate = $false, # if set to $true, RainbowMiner will trigger the update process, as soon as a new release is published
    [Parameter(Mandatory = $false)]
    [Switch]$EnableAutoBenchmark = $false, # if set to $true, RainbowMiner will start benchmarking updated miners automatically
    [Parameter(Mandatory = $false)]
    [Switch]$EnableAutoMinerPorts = $false,
    [Parameter(Mandatory = $false)]
    [Int]$StaticCPUMinerPort = 0,
    [Parameter(Mandatory = $false)]
    [Int]$StaticGPUMinerPort = 0,
    [Parameter(Mandatory = $false)]
    [Switch]$DisableMSIAmonitor = $false,
    [Parameter(Mandatory = $false)]
    [Switch]$EnableAutoAdjustAffinity = $false, # if set to $true and all threads are assigned for CPU mining, 1 or 2 thread/s will be freed automatically
    [Parameter(Mandatory = $false)]
    [int]$CPUMiningThreads = 0,
    [Parameter(Mandatory = $false)]
    [String]$CPUMiningAffinity = "",
    [Parameter(Mandatory = $false)]
    [String]$GPUMiningAffinity = "",
    [Parameter(Mandatory = $false)]
    [Switch]$DisableAPI = $false,
    [Parameter(Mandatory = $false)]
    [Switch]$DisableAsyncLoader = $false,
    [Parameter(Mandatory = $false)]
    [Switch]$EnableMinerStatus = $false,
    [Parameter(Mandatory = $false)]
    [Switch]$EnableFastSwitching = $false,
    [Parameter(Mandatory = $false)]
    [Switch]$ForceStablePrice = $false,
    [Parameter(Mandatory = $false)]
    [Switch]$EnableMinersAsRoot = $false,
    [Parameter(Mandatory = $false)]
    [String]$NVSMIpath =  "$(if (${env:ProgramFiles}) {${env:ProgramFiles}} else {"C:\Program Files"})\NVIDIA Corporation\NVSMI",
    [Parameter(Mandatory = $false)]
    [int]$MiningPriorityCPU = -2,
    [Parameter(Mandatory = $false)]
    [int]$MiningPriorityGPU = -1,
    [Parameter(Mandatory = $false)]
    [int]$AutoexecPriority = -1,
    [Parameter(Mandatory = $false)]
    [int]$HashrateWeight = 20, #Adjust weight of pool hashrates on the profit comparison in % (0..100, 0=disable) 
    [Parameter(Mandatory = $false)]
    [int]$HashrateWeightStrength = 50, #Adjust the strength of the weight (integer, 0=no weight, 100=linear, 200=square)
    [Parameter(Mandatory = $false)]
    [int]$PoolAccuracyWeight = 15, #Adjust weight of pools accuracy on the profit comparison in % (0..100, 0=disable)
    [Parameter(Mandatory = $false)]
    [int]$MinerFaultToleranceGPU = 10, #Adjust the default GPU miner tolerance in % (0..100)
    [Parameter(Mandatory = $false)]
    [int]$MinerFaultToleranceCPU = 25, #Adjust the default CPU miner tolerance in % (0..100)
    [Parameter(Mandatory = $false)]
    [int]$BalanceUpdateMinutes = 30, #Update balances every BalanceUpdateMinutes minutes
    [Parameter(Mandatory = $false)]
    [Double]$ProfitSpikeProtection = 0, # profit files will not be updated, if the actual value is above the average profit x this factor (0=disable)
    [Parameter(Mandatory = $false)]
    [Switch]$Quickstart = $false, #use cached values to restart miner
    [Parameter(Mandatory = $false)]
    [String]$PoolDataWindow = "", #default pool data window
    [Parameter(Mandatory = $false)]
    [String]$PoolStatAverage = "", #default pool data moving average (Live, Minute_5, Minute_10, Hour, Day, ThreeDay, Week)
    [Parameter(Mandatory = $false)]
    [Switch]$EnableErrorRatio = $false, #enable automatic yiimp pool price correction
    [Parameter(Mandatory = $false)]
    [Double]$MaxErrorRatio = 1.5, #maxium error ratio for yiimp pool price correction
    [Parameter(Mandatory = $false)]
    [Switch]$EnableAutoAlgorithmAdd = $false,
    [Parameter(Mandatory = $false)]
    [Switch]$EnableAlgorithmMapping = $false, # if set to $true, some algos will be more readable in console and api
    [Parameter(Mandatory = $false)]
    [Switch]$EnableResetVega = $false,
    [Parameter(Mandatory = $false)]
    [Switch]$EnableMiningHeatControl = $false,
    [Parameter(Mandatory = $false)]
    [Double]$MiningHeatControl = 2,
    [Parameter(Mandatory = $false)]
    [int]$MaxActivityDays = 2, # maximum days for the activity list on localhost
    [Parameter(Mandatory = $false)]
    [int]$MaxLogfileDays = 5, # maximum days for the logfiles to keep
    [Parameter(Mandatory = $false)]
    [int]$MaxDownloadfileDays = 14, # maximum days for the downloads to keep
    [Parameter(Mandatory = $false)]
    [int]$MaxCachefileDays = 14, # maximum days for the cachefiles to keep
    [Parameter(Mandatory = $false)]
    [Switch]$StartPaused = $false,
    [Parameter(Mandatory = $false)]
    [Switch]$EnablePauseOnActivity = $false,
    [Parameter(Mandatory = $false)]
    [Switch]$EnableUpdateDuringPause = $false,
    [Parameter(Mandatory = $false)]
    [Switch]$EnableUpdateWhenScheduled = $false,
    [Parameter(Mandatory = $false)]
    [int]$ResumeOnInactivitySeconds = 300, #resume after 5 minutes
    [Parameter(Mandatory = $false)]
    [Int]$MinimumMiningIntervals = 1, #minimum mining intervals, before the regular interval time is used
    [Parameter(Mandatory = $false)]
    [Int]$BenchmarkInterval = 60, #the interval used for benchmarks
    [Parameter(Mandatory = $false)]
    [String]$ServerName = "", # if RunMode=client: this is the name of the main RainbowMiner server
    [Parameter(Mandatory = $false)]
    [int]$ServerPort = 4000,  # if RunMode=server or client: main RainbowMiner server port address
    [Parameter(Mandatory = $false)]
    [String]$ServerUser = "",
    [Parameter(Mandatory = $false)]
    [String]$ServerPassword = "",
    [Parameter(Mandatory = $false)]
    [Switch]$EnableServerConfig = $false, # enable download of config files from the server
    [Parameter(Mandatory = $false)]
    [Switch]$EnableServerPools = $false, # use server's pools + balance, except MiningRigRentals
    [Parameter(Mandatory = $false)]
    [Array]$ServerConfigName = @(), # list of config files to be downloaded from the server
    [Parameter(Mandatory = $false)]
    [String]$GroupName = "", # client group name for shared server config
    [Parameter(Mandatory = $false)]
    [Array]$ExcludeServerConfigVars = @("APIauth","APIpassword","APIport","APIuser","APIthreads","CPUMiningAffinity","CPUMiningThreads","DeviceName","EnableServerConfig","ExcludeDeviceName","ExcludeServerConfigVars","GPUMiningAffinity","GroupName","LinuxDisplay","LinuxXAuthority","MSIApath","NVSMIpath","Proxy","RunMode","ServerConfigName","ServerName","ServerPassword","ServerPort","ServerUser","StartPaused","WorkerName","StaticCPUMinerPort","StaticGPUMinerPort"), # do not copy these vars from the server's config.txt
    [Parameter(Mandatory = $false)]
    [Switch]$EnableServerExcludeList = $false,
    [Parameter(Mandatory = $false)]
    [Switch]$EnableMinerBackups = $false,
    [Parameter(Mandatory = $false)]
    [Switch]$EnableKeepDownloads = $false,
    [Parameter(Mandatory = $false)]
    [String]$RunMode = "standalone", # enter standalone, server or client
    [Parameter(Mandatory = $false)]
    [Switch]$SetupOnly = $false,
    [Parameter(Mandatory = $false)]
    [Switch]$EnableDebugMode = $false,
    [Parameter(Mandatory = $false)]
    [Switch]$EnableRestartComputer = $false, # enable automatic computer restart, if one of the following conditions is met
    [Parameter(Mandatory = $false)]
    [Double]$RestartComputerHours = 0, # condition 1: restart after xx hours runtime
    [Parameter(Mandatory = $false)]
    [String]$LinuxDisplay = ":0", # default Linux DISPLAY for headless operation
    [Parameter(Mandatory = $false)]
    [String]$LinuxXAuthority = "", # default Linux XAUTHORITY for headless operation
    [Parameter(Mandatory = $false)]
    [String]$LogLevel = "Info" #select log level from "Debug", "Info", "Warn", "Error" and "Silent"
)

$ForceFullCollection = $true
$EnableMinerStatus = $true

Initialize-Session

$Session.Version         = "4.6.9.5"
$Session.MainWindowTitle = "RainbowMiner v$($Session.Version)"
$Session.SetupOnly       = $SetupOnly
$Session.LogLevel        = $LogLevel

$Session.SupportedPSVersion = "7.1.2"

if ($MyInvocation.MyCommand.Path) {Set-Location (Split-Path $MyInvocation.MyCommand.Path)}

Add-Type -Path .\DotNet\OpenCL\*.cs
#Add-Type -Path .\DotNet\Tools\RBMTools.cs

if ($IsWindows) {
    if ($Session.IsCore) {
        Import-Module NetSecurity -ErrorAction Ignore -SkipEditionCheck
        Import-Module Defender -ErrorAction Ignore -SkipEditionCheck
        Import-Module NetTCPIP -ErrorAction Ignore -SkipEditionCheck
        Import-Module "$env:Windir\System32\WindowsPowerShell\v1.0\Modules\NetSecurity\NetSecurity.psd1" -ErrorAction Ignore -SkipEditionCheck
        Import-Module "$env:Windir\System32\WindowsPowerShell\v1.0\Modules\Defender\Defender.psd1" -ErrorAction Ignore -SkipEditionCheck
        Import-Module "$env:Windir\System32\WindowsPowerShell\v1.0\Modules\NetTCPIP\NetTCPIP.psd1" -ErrorAction Ignore -SkipEditionCheck
    } else {
        Import-Module NetSecurity -ErrorAction Ignore
        Import-Module Defender -ErrorAction Ignore
        Import-Module "$env:Windir\System32\WindowsPowerShell\v1.0\Modules\NetSecurity\NetSecurity.psd1" -ErrorAction Ignore
        Import-Module "$env:Windir\System32\WindowsPowerShell\v1.0\Modules\Defender\Defender.psd1" -ErrorAction Ignore
    }
}

Import-Module .\Modules\API.psm1
Import-Module .\Modules\Asyncloader.psm1
Import-Module .\Modules\Core.psm1
if ($IsLinux) {
    Import-Module .\Modules\OCDaemon.psm1
}

if ($UseTimeSync) {Test-TimeSync}

#Get loglevel
if (Test-Path $ConfigFile) {
    $Config_LogLevel = try {(Get-Content $ConfigFile -Raw -ErrorAction Stop | ConvertFrom-Json -ErrorAction Stop).LogLevel} catch {if ($Error.Count) {$Error.RemoveAt(0)};$LogLevel}
    if ($Config_LogLevel -and $Config_LogLevel -ne "`$LogLevel") {$Session.LogLevel = $Config_LogLevel}
}

#Start the log
if (-not $psISE -and $Session.LogLevel -ne "Silent") {Start-Transcript ".\Logs\$(if ($SetupOnly) {"Setup"} else {"RainbowMiner"})_$(Get-Date -Format "yyyy-MM-dd_HH-mm-ss").txt"}

Write-Log "Starting RainbowMiner v$($Session.Version)"

#Set process priority to BelowNormal to avoid hash rate drops on systems with weak CPUs
if (-not $psISE) {(Get-Process -Id $PID).PriorityClass = "BelowNormal"}

if ($IsWindows -and (Get-Command "Unblock-File" -ErrorAction SilentlyContinue)) {Get-ChildItem . -Recurse | Unblock-File -ErrorAction Ignore}

[hashtable]$Session.DefaultValues = @{}

if (-not $psISE) {$MyCommandParameters = $MyInvocation.MyCommand.Parameters.Keys | Where-Object {$_ -and $_ -ne "ConfigFile" -and (Get-Variable $_ -ErrorAction Ignore)}}
if (-not $MyCommandParameters) {$MyCommandParameters = @("Wallet","WorkerName","Interval","Region","DefaultPoolRegion","SSL","DeviceName","ExcludeDeviceName","Algorithm","MinerName","ExcludeAlgorithm","ExcludeMinerName","PoolName","ExcludePoolName","ExcludeCoin","ExcludeCoinSymbol","Currency","Donate","Proxy","Delay","Watchdog","MinerStatusUrl","MinerStatusKey","MinerStatusEmail","PushOverUserKey","MinerStatusMaxTemp","MinerStatusMaxCrashesPerHour","SwitchingPrevention","PoolSwitchingHysteresis","MinerSwitchingHysteresis","MaxRejectedShareRatio","MaxAllowedLuck","MaxTimeSinceLastBlock","MinComboOverSingleRatio","ShowMinerWindow","FastestMinerOnly","IgnoreFees","ExcludeMinersWithFee","DisableUnprofitableAlgolist","DisableUnprofitableCpuAlgolist","EnableCheckMiningConflict","EnableEthashZombieMode","ShowPoolBalances","ShowPoolBalancesDetails","ShowPoolBalancesExcludedPools","ExcludeCoinsymbolBalances","ShowWalletBalances","WalletBalances","DisableDualMining","APIport","APIuser","APIpassword","APIauth","APIthreads","RebootOnGPUFailure","MiningMode","MSIApath","MSIAprofile","UIstyle","UIsorting","UseTimeSync","PowerPrice","PowerPriceCurrency","UsePowerPrice","PowerOffset","PowerOffsetPercent","CheckProfitability","DisableExtendInterval","EthPillEnable","EthPillEnableMTP","EnableOCProfiles","EnableOCVoltage","EnableOCLinuxSetAllPStates","EnableOCLinuxForcePState","EnableLinuxHeadless","EnableAutoUpdate","EnableAutoBenchmark","EnableAutoMinerPorts","StaticCPUMinerPort","StaticGPUMinerPort","EnableAutoAdjustAffinity","DisableMSIAmonitor","CPUMiningThreads","CPUMiningAffinity","GPUMiningAffinity","DisableAPI","DisableAsyncLoader","EnableMinerStatus","EnableFastSwitching","ForceStablePrice","EnableMinersAsRoot","NVSMIpath","MiningPriorityCPU","MiningPriorityGPU","AutoexecPriority","HashrateWeight","HashrateWeightStrength","PoolAccuracyWeight","MinerFaultToleranceGPU","MinerFaultToleranceCPU","BalanceUpdateMinutes","ProfitSpikeProtection","Quickstart","PoolDataWindow","PoolStatAverage","EnableErrorRatio","MaxErrorRatio","EnableAutoAlgorithmAdd","EnableAlgorithmMapping","EnableResetVega","EnableMiningHeatControl","MiningHeatControl","MaxActivityDays","MaxLogfileDays","MaxDownloadfileDays","MaxCachefileDays","StartPaused","EnableUpdateDuringPause","EnableUpdateWhenScheduled","EnablePauseOnActivity","ResumeOnInactivitySeconds","MinimumMiningIntervals","BenchmarkInterval","ServerName","ServerPort","ServerUser","ServerPassword","EnableServerConfig","EnableServerPools","ServerConfigName","GroupName","ExcludeServerConfigVars","EnableServerExcludeList","EnableMinerBackups","EnableKeepDownloads","RunMode","SetupOnly","EnableRestartComputer","RestartComputerHours","LinuxDisplay","LinuxXAuthority","LogLevel")}
$MyCommandParameters | Where-Object {Get-Variable $_ -ErrorAction Ignore} | Foreach-Object {$Session.DefaultValues[$_] = Get-Variable $_ -ValueOnly -ErrorAction SilentlyContinue}

if ($IsWindows -and $Session.IsAdmin) {
    if ((Get-Command "Get-MpPreference" -ErrorAction Ignore) -and (Get-MpPreference).ExclusionPath -notcontains (Convert-Path .)) {
        try {
            Start-Process (@{desktop = "powershell"; core = "pwsh"}.$PSEdition) "-Command Import-Module '$env:Windir\System32\WindowsPowerShell\v1.0\Modules\Defender\Defender.psd1'$(if ($Session.IsCore) {" -SkipEditionCheck"}); Add-MpPreference -ExclusionPath '$(Convert-Path .)'" -Verb runAs -WindowStyle Hidden
        } catch {
            Write-Log -Level Warn "WARNING: The RainbowMiner path ($(Convert-Path .)) could not be added to MS Defender's exclusion list. Please do this by hand!"
        }
    }
}

if (-not (Start-Core -ConfigFile $ConfigFile -SetupOnly:$SetupOnly)) {Exit}

while (-not $Session.Stopp) {

    Invoke-Core

    if (-not $Session.Stopp) {
        Write-Log "Starting next run..."
        if ($ForceFullCollection) {
            [System.GC]::Collect()
            [System.GC]::WaitForPendingFinalizers()
            [System.GC]::Collect()
            Get-MemoryUsage -ForceFullCollection >$null
        } else {
            [System.GC]::Collect()
        }
        Write-Log (Get-MemoryUsage -Reset).MemText
    }
}

Stop-Core

#Stop the log
if (-not $psISE -and $Session.LogLevel -ne "Silent") {
    Stop-Transcript
}

if ($IsWindows) {
    if ($Session.AutoUpdate -and -not $psISE) {Exit 999}
} else {
    Exit $(if ($Session.AutoUpdate -or $Session.Restart) {99} else {0})
}