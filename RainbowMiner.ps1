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
    [String]$Region = "us", #europe/us/asia
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
    [String]$MinerStatusUrl = "https://rbminer.net", #i.e https://multipoolminer.io/monitor/miner.php
    [Parameter(Mandatory = $false)]
    [String]$MinerStatusKey = "", #will be generated during setup
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
    [Switch]$ShowPoolBalancesDetails = $false,
    [Parameter(Mandatory = $false)]
    [Switch]$ShowPoolBalancesExcludedPools = $false,
    [Parameter(Mandatory = $false)]
    [Switch]$DisableDualMining = $false,
    [Parameter(Mandatory = $false)]
    [int]$LocalAPIPort = 4000,
    [Parameter(Mandatory = $false)]
    [Switch]$RemoteAPI = $false,
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
    [Double]$PowerOffset = 0, # power offset to allow consideration for overhead power
    [Parameter(Mandatory = $false)]
    [Switch]$CheckProfitability = $false, # if set to $true, miners with negative profit will be excluded
    [Parameter(Mandatory = $false)]
    [Switch]$DisableExtendInterval = $false, # if set to $true, benchmark intervals will never be extended
    [Parameter(Mandatory = $false)]
    [String]$EthPillEnable = "disable", # set to RevA or RevB to enable the OhGodAnETHlargementPill
    [Parameter(Mandatory = $false)]
    [Switch]$EnableOCProfiles = $false, # if set to $true, the build in overclocking profiles will be used
    [Parameter(Mandatory = $false)]
    [Switch]$EnableOCVoltage = $false, # if set to $true, overclocking setting include voltage
    [Parameter(Mandatory = $false)]
    [Switch]$EnableAutoUpdate = $false, # if set to $true, RainbowMiner will trigger the update process, as soon as a new release is published
    [Parameter(Mandatory = $false)]
    [Switch]$EnableAutoBenchmark = $false, # if set to $true, RainbowMiner will start benchmarking updated miners automatically
    [Parameter(Mandatory = $false)]
    [Switch]$EnableAutoMinerPorts = $false,
    [Parameter(Mandatory = $false)]
    [Switch]$DisableMSIAmonitor = $false,
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
    [int]$BalanceUpdateMinutes = 30, #Update balances every BalanceUpdateMinutes minutes
    [Parameter(Mandatory = $false)]
    [Switch]$Quickstart = $false, #use cached values to restart miner
    [Parameter(Mandatory = $false)]
    [String]$PoolDataWindow = "", #default pool data window
    [Parameter(Mandatory = $false)]
    [String]$PoolStatAverage = "", #default pool data moving average (Live, Minute_5, Minute_10, Hour, Day, ThreeDay, Week)
    [Parameter(Mandatory = $false)]
    [Switch]$EnableAutoAlgorithmAdd = $false,
    [Parameter(Mandatory = $false)]
    [Switch]$EnableResetVega = $false,
    [Parameter(Mandatory = $false)]
    [Switch]$StartPaused = $false
)

Clear-Host

$ForceFullCollection = $true
$EnableMinerStatus = $true

$Global:Session = [hashtable]::Synchronized(@{}) 

$Session.Version = "3.9.1.7"

$Session.Strikes           = 3
$Session.SyncWindow        = 10 #minutes, after that time, the pools bias price will start to decay
$Session.OutofsyncWindow   = 60 #minutes, after that time, the pools price bias will be 0
$Session.DecayPeriod       = 60 #seconds
$Session.DecayBase         = 1 - 0.1 #decimal percentage
$Session.BenchmarkInterval = 60 #seconds

$Session.MainWindowTitle   = "RainbowMiner v$($Session.Version)"

$host.ui.RawUI.WindowTitle = $Session.MainWindowTitle

Write-Host "__________        .__      ___.                   _____  .__                     " -ForegroundColor Red
Write-Host "\______   \_____  |__| ____\_ |__   ______  _  __/     \ |__| ____   ___________ " -ForegroundColor DarkYellow
Write-Host " |       _/\__  \ |  |/    \| __ \ /  _ \ \/ \/ /  \ /  \|  |/    \_/ __ \_  __ \" -ForegroundColor Yellow
Write-Host " |    |   \ / __ \|  |   |  \ \_\ (  <_> )     /    Y    \  |   |  \  ___/|  | \/" -ForegroundColor Green
Write-Host " |____|_  /(____  /__|___|  /___  /\____/ \/\_/\____|__  /__|___|  /\___  >__|   " -ForegroundColor Blue
Write-Host "        \/      \/        \/    \/                     \/        \/     \/       " -ForegroundColor DarkMagenta
Write-Host " "
Write-Host "Starting up v$($Session.Version)! Please wait.."
Write-Host " "

if ($MyInvocation.MyCommand.Path) {Set-Location (Split-Path $MyInvocation.MyCommand.Path)}

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
Import-Module .\API.psm1
Import-Module .\Asyncloader.psm1
Import-Module .\Core.psm1

if ($UseTimeSync) {Test-TimeSync}

#Start the log
if (-not $psISE) {Start-Transcript ".\Logs\RainbowMiner_$(Get-Date -Format "yyyy-MM-dd_HH-mm-ss").txt"}

Write-Log "Starting RainbowMiner v$($Session.Version)"

#Set process priority to BelowNormal to avoid hash rate drops on systems with weak CPUs
if (-not $psISE) {(Get-Process -Id $PID).PriorityClass = "BelowNormal"}

if (Get-Command "Unblock-File" -ErrorAction SilentlyContinue) {Get-ChildItem . -Recurse | Unblock-File}

[hashtable]$Session.DefaultValues = @{}

if (-not $psISE) {$MyCommandParameters = $MyInvocation.MyCommand.Parameters.Keys | Where-Object {$_ -and $_ -ne "ConfigFile" -and (Get-Variable $_ -ErrorAction Ignore)}}
if (-not $MyCommandParameters) {$MyCommandParameters = @("Wallet","UserName","WorkerName","API_ID","API_Key","Interval","Region","SSL","DeviceName","Algorithm","MinerName","ExcludeAlgorithm","ExcludeMinerName","PoolName","ExcludePoolName","ExcludeCoin","ExcludeCoinSymbol","Currency","Donate","Proxy","Delay","Watchdog","MinerStatusUrl","MinerStatusKey","SwitchingPrevention","ShowMinerWindow","FastestMinerOnly","IgnoreFees","ExcludeMinersWithFee","ShowPoolBalances","ShowPoolBalancesDetails","ShowPoolBalancesExcludedPools","DisableDualMining","RemoteAPI","LocalAPIPort","RebootOnGPUFailure","MiningMode","MSIApath","MSIAprofile","UIstyle","UseTimeSync","PowerPrice","PowerPriceCurrency","UsePowerPrice","PowerOffset","CheckProfitability","DisableExtendInterval","EthPillEnable","EnableOCProfiles","EnableOCVoltage","EnableAutoUpdate","EnableAutoBenchmark","EnableAutoMinerPorts","DisableMSIAmonitor","CPUMiningThreads","CPUMiningAffinity","GPUMiningAffinity","DisableAPI","DisableAsyncLoader","EnableMinerStatus","EnableFastSwitching","NVSMIpath","MiningPriorityCPU","MiningPriorityGPU","AutoexecPriority","HashrateWeight","HashrateWeightStrength","PoolAccuracyWeight","BalanceUpdateMinutes","Quickstart","PoolDataWindow","PoolStatAverage","EnableAutoAlgorithmAdd","EnableResetVega","StartPaused")}
$MyCommandParameters | Where-Object {Get-Variable $_ -ErrorAction Ignore} | Foreach-Object {$Session.DefaultValues[$_] = Get-Variable $_ -ValueOnly -ErrorAction SilentlyContinue}

if (-not (Start-Core -ConfigFile $ConfigFile)) {Exit}

if ((Get-Command "Get-MpPreference" -ErrorAction Ignore) -and (Get-MpComputerStatus -ErrorAction Ignore) -and (Get-MpPreference).ExclusionPath -notcontains (Convert-Path .)) {
    Start-Process (@{desktop = "powershell"; core = "pwsh"}.$PSEdition) "-Command Import-Module '$env:Windir\System32\WindowsPowerShell\v1.0\Modules\Defender\Defender.psd1' -SkipEditionCheck; Add-MpPreference -ExclusionPath '$(Convert-Path .)'" -Verb runAs -WindowStyle Hidden
}

while (-not $Session.Stopp) {

    Invoke-Core

    if (-not $Session.Stopp) {
        Write-Log "Starting next run..."
        if ($ForceFullCollection) {
            [System.GC]::Collect()
            [System.GC]::WaitForPendingFinalizers()
            [System.GC]::Collect()
            Get-MemoryUsage -ForceFullCollection >$null
        }
        Write-Log (Get-MemoryUsage).MemText
    }
}

Stop-Core

#Stop the log
Stop-Transcript

if ($Session.AutoUpdate -and -not $psISE) {Exit 999}