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
    [Switch]$EnableOCVoltage = $false, # if set to $true, overclocking setting include voltage
    [Parameter(Mandatory = $false)]
    [Switch]$EnableAutoUpdate = $false, # if set to $true, RainbowMiner will trigger the update process, as soon as a new release is published
    [Parameter(Mandatory = $false)]
    [Switch]$EnableAutoMinerPorts = $false,
    [Parameter(Mandatory = $false)]
    [Switch]$DisableMSIAmonitor = $false
)

Clear-Host

$Version = "3.8.6.5"
$Strikes = 3
$SyncWindow = 10 #minutes
$OutofsyncWindow = 60 #minutes

Write-Host "__________        .__      ___.                   _____  .__                     " -ForegroundColor Red
Write-Host "\______   \_____  |__| ____\_ |__   ______  _  __/     \ |__| ____   ___________ " -ForegroundColor DarkYellow
Write-Host " |       _/\__  \ |  |/    \| __ \ /  _ \ \/ \/ /  \ /  \|  |/    \_/ __ \_  __ \" -ForegroundColor Yellow
Write-Host " |    |   \ / __ \|  |   |  \ \_\ (  <_> )     /    Y    \  |   |  \  ___/|  | \/" -ForegroundColor Green
Write-Host " |____|_  /(____  /__|___|  /___  /\____/ \/\_/\____|__  /__|___|  /\___  >__|   " -ForegroundColor Blue
Write-Host "        \/      \/        \/    \/                     \/        \/     \/       " -ForegroundColor DarkMagenta
Write-Host " "
Write-Host "Starting up v$($Version)! Please wait.."
Write-Host " "

if ($MyInvocation.MyCommand.Path) {Set-Location (Split-Path $MyInvocation.MyCommand.Path)}

Import-Module NetSecurity -ErrorAction Ignore
Import-Module Defender -ErrorAction Ignore
Import-Module "$env:Windir\System32\WindowsPowerShell\v1.0\Modules\NetSecurity\NetSecurity.psd1" -ErrorAction Ignore
Import-Module "$env:Windir\System32\WindowsPowerShell\v1.0\Modules\Defender\Defender.psd1" -ErrorAction Ignore

if ($UseTimeSync) {Test-TimeSync}

$Timer = (Get-Date).ToUniversalTime()
$NextReport = $Timer
$StatEnd = $Timer
$DecayStart = $Timer
$DecayPeriod = 60 #seconds
$DecayBase = 1 - 0.1 #decimal percentage

[System.Collections.ArrayList]$WatchdogTimers = @()
[System.Collections.ArrayList]$ActiveMiners = @()
[System.Collections.ArrayList]$SelectedPoolNames = @()
[hashtable]$Rates = @{BTC = [Double]1}
[hashtable]$NewRates = @{}

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
    $MyCommandParameters = $MyInvocation.MyCommand.Parameters.Keys | Where-Object {$_ -and $_ -ne "ConfigFile" -and (Get-Variable $_ -ErrorAction Ignore)}
}
if (-not $MyCommandParameters) {
    $MyCommandParameters = @("Wallet","UserName","WorkerName","API_ID","API_Key","Interval","Region","SSL","DeviceName","Algorithm","MinerName","ExcludeAlgorithm","ExcludeMinerName","PoolName","ExcludePoolName","ExcludeCoin","ExcludeCoinSymbol","Currency","Donate","Proxy","Delay","Watchdog","MinerStatusUrl","MinerStatusKey","SwitchingPrevention","ShowMinerWindow","FastestMinerOnly","IgnoreFees","ExcludeMinersWithFee","ShowPoolBalances","DisableDualMining","RemoteAPI","LocalAPIPort","RebootOnGPUFailure","MiningMode","MSIApath","MSIAprofile","UIstyle","UseTimeSync","PowerPrice","PowerPriceCurrency","UsePowerPrice","CheckProfitability","DisableExtendInterval","EthPillEnable","EnableOCProfiles","EnableOCVoltage","EnableAutoUpdate","EnableAutoMinerPorts","DisableMSIAmonitor")
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
if (-not $psISE) {(Get-Process -Id $PID).PriorityClass = "BelowNormal"}

Write-Host "Detecting devices .."
$AllDevices = Get-Device "cpu","gpu"

if (Get-Command "Unblock-File" -ErrorAction SilentlyContinue) {Get-ChildItem . -Recurse | Unblock-File}

Write-Host "Initialize configuration .."
try {
    $RunCleanup = $true
    $ConfigPath = [IO.Path]::GetDirectoryName($ConfigFile)
    if (-not $ConfigPath) {$ConfigPath = ".\Config"; $ConfigFile = "$($ConfigPath)\$($ConfigFile)"}
    if (-not (Test-Path $ConfigPath)) {$RunCleanup = $false;New-Item $ConfigPath -ItemType "directory" -Force > $null}
    if (-not (Test-Path "$ConfigPath\Backup")) {New-Item "$ConfigPath\Backup" -ItemType "directory" -Force > $null}    
    if (-not [IO.Path]::GetExtension($ConfigFile)) {$ConfigFile = "$($ConfigFile).txt"}
    if (-not (Test-Path $ConfigFile)) {
        $Parameters = @{VersionCompatibility=$Version}
        $MyCommandParameters | ForEach-Object {$Parameters | Add-Member $_ "`$$($_)" -ErrorAction SilentlyContinue}
        Set-ContentJson -PathToFile $ConfigFile -Data $Parameters > $null        
    } else {
        $ConfigForUpdate = Get-Content $ConfigFile | ConvertFrom-Json
        $ConfigForUpdate_changed = $false
        Compare-Object @($ConfigForUpdate.PSObject.Properties.Name) @($MyCommandParameters) | Foreach-Object {
            if ($_.SideIndicator -eq "=>") {$ConfigForUpdate | Add-Member $_.InputObject "`$$($_.InputObject)";$ConfigForUpdate_changed=$true}
            elseif ($_.SideIndicator -eq "<=" -and @("ConfigFile","ExcludeNegativeProfit","DisableAutoUpdate","Regin","Debug","Verbose","ErrorAction","WarningAction","InformationAction","ErrorVariable","WarningVariable","InformationVariable","OutVariable","OutBuffer","PipelineVariable") -icontains $_.InputObject) {$ConfigForUpdate.PSObject.Properties.Remove($_.InputObject);$ConfigForUpdate_changed=$true}
        }
        if ($ConfigForUpdate_changed) {Set-ContentJson -PathToFile $ConfigFile -Data $ConfigForUpdate > $null}
    }
    $ConfigFile = Get-Item $ConfigFile | Foreach-Object {
        $ConfigFile_Path = $_ | Select-Object -ExpandProperty DirectoryName
        $ConfigFile_Name = $_ | Select-Object -ExpandProperty Name
        $PoolsConfigFile = @($ConfigFile_Path,"\pools.",$ConfigFile_Name) -join ''
        $MinersConfigFile = @($ConfigFile_Path,"\miners.",$ConfigFile_Name) -join ''
        $DevicesConfigFile = @($ConfigFile_Path,"\devices.",$ConfigFile_Name) -join ''
        $OCProfilesConfigFile = @($ConfigFile_Path,"\ocprofiles.",$ConfigFile_Name) -join ''

        if (-not $psISE) {
            $BackupDate = Get-Date -Format "yyyyMMddHHmmss"
            if (Test-Path $ConfigFile) {Copy-Item $ConfigFile -Destination "$($ConfigFile_Path)\Backup\$($BackupDate)_$($ConfigFile_Name)"}
            if (Test-Path $PoolsConfigFile) {Copy-Item $PoolsConfigFile -Destination "$($ConfigFile_Path)\Backup\$($BackupDate)_pools.$($ConfigFile_Name)"}
            if (Test-Path $MinersConfigFile) {Copy-Item $MinersConfigFile -Destination "$($ConfigFile_Path)\Backup\$($BackupDate)_miners.$($ConfigFile_Name)"}
            if (Test-Path $DevicesConfigFile) {Copy-Item $DevicesConfigFile -Destination "$($ConfigFile_Path)\Backup\$($BackupDate)_devices.$($ConfigFile_Name)"}
            if (Test-Path $OCProfilesConfigFile) {Copy-Item $OCProfilesConfigFile -Destination "$($ConfigFile_Path)\Backup\$($BackupDate)_ocprofiles.$($ConfigFile_Name)"}
        }
        
        # Create pools.config.txt if it is missing
        Set-PoolsConfigDefault -PathToFile $PoolsConfigFile -Force
        $PoolsConfigFile = $PoolsConfigFile | Resolve-Path -Relative

        # Create miners.config.txt and cpu.miners.config.txt, if they are missing
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
        if ($RunCleanup) {
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
        }
        Remove-Item ".\Cleanup.ps1" -Force
    }

    #write version to data
    Set-ContentJson -PathToFile ".\Data\Version.json" -Data ([PSCustomObject]@{Version=$Version}) > $null
}
catch {
    Write-Log -Level Error "$($_) Cannot run RainbowMiner. "
    Exit
}

Write-Host "Start afterburner library .."
Start-Afterburner

if ((Get-Command "Get-MpPreference" -ErrorAction SilentlyContinue) -and (Get-MpComputerStatus -ErrorAction Ignore) -and (Get-MpPreference).ExclusionPath -notcontains (Convert-Path .)) {
    Start-Process (@{desktop = "powershell"; core = "pwsh"}.$PSEdition) "-Command Import-Module '$env:Windir\System32\WindowsPowerShell\v1.0\Modules\Defender\Defender.psd1'; Add-MpPreference -ExclusionPath '$(Convert-Path .)'" -Verb runAs
}

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

                if ($RunSetup) {. ".\Setup.ps1"}

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
            $var = Get-Variable -ValueOnly $name -ErrorAction Ignore
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
        if (-not $Config.LocalAPIport) {$Config | Add-Member LocalAPIport 4000 -Force}
        Set-ContentJson -PathToFile ".\Data\localapiport.json" -Data @{LocalAPIport = $Config.LocalAPIport} > $null

        #For backwards compatibility
        if ($Config.Wallet -and -not $Config.MinerStatusKey) {$Config.MinerStatusKey = $Config.Wallet}      
        if ($Config.LegacyMode -ne $null) {$Config.MiningMode = if (Get-Yes $Config.LegacyMode){"legacy"}else{"device"}}
    }

    #Initialize the API and Get-Device
    $StartAPI = $false
    if(!(Test-Path Variable:API)) {
        Import-Module .\API.psm1
        $StartAPI = $true
    } elseif ($Config.LocalAPIport -and ($API.LocalAPIport -ne $Config.LocalAPIport)) {
        #restart API server
        Write-Log -Level Warn "Restarting API at new port $($Config.LocalAPIport)"
        Stop-APIServer
        Sleep 2
        $StartAPI = $true
    }
    if ($StartAPI) {
        Start-APIServer -RemoteAPI:$Config.RemoteAPI -LocalAPIport:$Config.LocalAPIport
        $API.Version = Confirm-Version $Version
    }

    #Give API access to computerstats
    $API.ComputerStats = $AsyncLoader.ComputerStats

    #Give API access to all possible devices
    if ($API.AllDevices -eq $null) {$API.AllDevices = $AllDevices}

    $MSIAenabled = -not $Config.EnableOCProfiles -and $Config.MSIAprofile -gt 0 -and (Test-Path $Config.MSIApath)

    #Check for oc profile config
    Set-OCProfilesConfigDefault $OCProfilesConfigFile
    if (Test-Path $OCProfilesConfigFile) {
        if ($ConfigCheckFields -or -not $Config.OCProfiles -or (Get-ChildItem $OCProfilesConfigFile).LastWriteTime.ToUniversalTime() -gt $Updatetracker["Config"]["OCProfilesConfigFile"]) {        
            $Updatetracker["Config"]["OCProfilesConfigFile"] = (Get-ChildItem $OCProfilesConfigFile).LastWriteTime.ToUniversalTime()
            $Config | Add-Member OCProfiles (Get-ChildItemContent $OCProfilesConfigFile).Content -Force
        }
    }   

    #Check for devices config
    Set-DevicesConfigDefault $DevicesConfigFile
    if (Test-Path $DevicesConfigFile) {
        if ($ConfigCheckFields -or -not $Config.Devices -or (Get-ChildItem $DevicesConfigFile).LastWriteTime.ToUniversalTime() -gt $Updatetracker["Config"]["DevicesConfigFile"]) {        
            $Updatetracker["Config"]["DevicesConfigFile"] = (Get-ChildItem $DevicesConfigFile).LastWriteTime.ToUniversalTime()
            $Config | Add-Member Devices (Get-ChildItemContent $DevicesConfigFile).Content -Force
            $OCprofileFirst = $Config.OCProfiles.PSObject.Properties.Name | Select-Object -First 1
            foreach ($p in @($Config.Devices.PSObject.Properties.Name)) {
                $Config.Devices.$p | Add-Member Algorithm @(($Config.Devices.$p.Algorithm | Select-Object) | Where-Object {$_} | Foreach-Object {Get-Algorithm $_}) -Force
                $Config.Devices.$p | Add-Member ExcludeAlgorithm @(($Config.Devices.$p.ExcludeAlgorithm | Select-Object) | Where-Object {$_} | Foreach-Object {Get-Algorithm $_}) -Force
                foreach ($q in @("MinerName","PoolName","ExcludeMinerName","ExcludePoolName")) {
                    if ($Config.Devices.$p.$q -is [string]){$Config.Devices.$p.$q = if ($Config.Devices.$p.$q.Trim() -eq ""){@()}else{[regex]::split($Config.Devices.$p.$q.Trim(),"\s*[,;:]+\s*")}}
                }
                $Config.Devices.$p | Add-Member DisableDualMining ($Config.Devices.$p.DisableDualMining -and (Get-Yes $Config.Devices.$p.DisableDualMining)) -Force
                if ($p -ne "CPU" -and -not $Config.Devices.$p.DefaultOCprofile) {
                    $Config.Devices.$p | Add-Member DefaultOCprofile $OCprofileFirst -Force
                    if ($Config.EnableOCprofiles) {
                        Write-Log -Level Warn "No default overclocking profile defined for `"$p`" in $($OCProfilesConfigFile). Using `"$OCprofileFirst`" for now!"
                    }
                }
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
                foreach($q in @("Algorithm","ExcludeAlgorithm","CoinName","ExcludeCoin","CoinSymbol","ExcludeCoinSymbol")) {
                    if ($Config.Pools.$p.$q -is [string]) {$Config.Pools.$p.$q = @(($Config.Pools.$p.$q -split "[,;]" | Select-Object) | Where-Object {$_} | Foreach-Object {$_.Trim()})}
                    $Config.Pools.$p | Add-Member $q @(($Config.Pools.$p.$q | Select-Object) | Where-Object {$_} | Foreach-Object {if ($q -match "algorithm"){Get-Algorithm $_}else{$_}} | Select-Object -Unique | Sort-Object) -Force
                }
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
        if (-not $DonationData) {$DonationData = '{"Wallets":{"NiceHash":{"BTC":"3HFhYADZvybBstETYNEVMqVWMU9EJRfs4f","Worker":"mpx"},"Default":{"BTC":"3DxRETpBoXKrEBQxFb2HsPmG6apxHmKmUx","RVN":"RGo5UgbnyNkfA8sUUbv62cYnV4EfYziNxH","PGN":"PAH9NZow4ut9ewGCdv548V832EMU5PWKJL","Worker":"mpx","User":"rbm"}},"Pools":["AHashPool","Nicehash","BlazePool","Ravenminer","ZergPool"],"Algorithm":["allium","balloon","blake2s","c11","cryptonightheavy","cryptonightv7","equihash","equihash21x9","equihash24x5","equihash24x7","ethash","hmq1725","hodl","hsr","keccak","keccakc","lyra2re2","lyra2z","neoscrypt","pascal","phi","phi2","poly","skein","skunk","timetravel","tribus","x16r","x16s","x17","xevan","yescrypt","yescryptr16","yespower"]}' | ConvertFrom-Json}                                                                                                                                                                                                                                                                                                                                                                     
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
    if ($AllPools -ne $null -and ($ConfigBackup.Pools | ConvertTo-Json -Compress) -ne ($Config.Pools | ConvertTo-Json -Compress)) {Remove-Variable "AllPools"}

    #Clear balances if pool configuration flag has changed
    if ($Balances -ne $null -and $ConfigBackup.ShowPoolBalances -ne $Config.ShowPoolBalances) {Remove-Variable "Balances"}

    #load device(s) informatino and device combos
    if ($ConfigCheckFields -or $ConfigBackup.MiningMode -ne $Config.MiningMode -or (Compare-Object $Config.DeviceName $ConfigBackup.DeviceName | Measure-Object).Count -gt 0) {
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
        [hashtable]$DevicesToVendors = @{}

        $Config | Add-Member DeviceModel @($Devices | Select-Object -ExpandProperty Model -Unique | Sort-Object) -Force

        #Create combos
        @($DevicesByTypes.PSObject.Properties.Name) | Where {@("Combos","FullComboModels") -inotcontains $_} | Foreach-Object {
            $SubsetType = [String]$_
            $DevicesByTypes.Combos | Add-Member $SubsetType @() -Force
            $DevicesByTypes.FullComboModels | Add-Member $SubsetType $(@($DevicesByTypes.$SubsetType | Select-Object -ExpandProperty Model -Unique | Sort-Object) -join '-') -Force
            Get-DeviceSubSets @($DevicesByTypes.$SubsetType) | Foreach-Object {                       
                $SubsetModel= $_
                $DevicesByTypes.Combos.$SubsetType += @($DevicesByTypes.$SubsetType | Where-Object {$SubsetModel.Model -icontains $_.Model} | Foreach-Object {$SubsetNew = $_.PSObject.Copy();$SubsetNew.Model = $($SubsetModel.Model -join '-');$SubsetNew.Model_Name = $($SubsetModel.Model_Name -join '+');$SubsetNew})
            }
            if ($DevicesByTypes.$SubsetType) {
                @($DevicesByTypes.$SubsetType | Select-Object -ExpandProperty Model -Unique) + @($DevicesByTypes.Combos.$SubsetType | Select-Object -ExpandProperty Model) | Where-Object {$_} | Foreach-Object {$DevicesToVendors[$_] = $SubsetType}
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

    Update-DeviceInformation @($Devices.Name | Select-Object -Unique) -UseAfterburner (-not $Config.DisableMSIAmonitor)

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
            $ConfigFullComboModelNames = @($DevicesByTypes.FullComboModels.PSObject.Properties.Name)
            foreach ($CcMiner in @((Get-ChildItemContent -Path $MinersConfigFile).Content.PSObject.Properties)) {
                $CcMinerName = $CcMiner.Name
                [String[]]$CcMinerName_Array = @($CcMinerName -split '-')
                if ($CcMinerName_Array.Count -gt 1 -and ($ConfigFullComboModelNames -icontains $CcMinerName_Array[1]) -and ($DevicesByTypes.FullComboModels."$($CcMinerName_Array[1])")) {$CcMinerName = "$($CcMinerName_Array[0])-$($DevicesByTypes.FullComboModels."$($CcMinerName_Array[1])")";$CcMinerName_Array = @($CcMinerName -split '-')}                
                $CcMinerOk = $true
                for($i=1;($i -lt $CcMinerName_Array.Count) -and $CcMinerOk;$i++) {if ($Config.DeviceModel -inotcontains $CcMinerName_Array[$i]) {$CcMinerOk=$false}}
                if ($CcMinerOk) {
                    foreach($p in @($CcMiner.Value)) {
                        if ($(foreach($q in $p.PSObject.Properties.Name) {if ($q -ne "MainAlgorithm" -and $q -ne "SecondaryAlgorithm" -and ($p.$q -isnot [string] -or $p.$q.Trim() -ne "")) {$true;break}})) {
                            $CcMinerNameToAdd = $CcMinerName
                            if ($p.MainAlgorithm -ne '*') {
                                $CcMinerNameToAdd += "-$(Get-Algorithm $p.MainAlgorithm)"
                                if ($p.SecondaryAlgorithm) {$CcMinerNameToAdd += "-$(Get-Algorithm $p.SecondaryAlgorithm)"}
                            }
                            $Config.Miners | Add-Member -Name $CcMinerNameToAdd -Value $p -MemberType NoteProperty -Force
                        }
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

    if ($UseTimeSync) {Test-TimeSync}
    $Timer = (Get-Date).ToUniversalTime()

    $StatStart = $StatEnd
    $StatEnd = $Timer.AddSeconds($Config.Interval)
    $StatSpan = New-TimeSpan $StatStart $StatEnd

    $DecayExponent = [int](($Timer - $DecayStart).TotalSeconds / $DecayPeriod)

    $WatchdogInterval = ($WatchdogInterval / $Strikes * ($Strikes - 1)) + $StatSpan.TotalSeconds
    $WatchdogReset = ($WatchdogReset / ($Strikes * $Strikes * $Strikes) * (($Strikes * $Strikes * $Strikes) - 1)) + $StatSpan.TotalSeconds

    #Update the exchange rates
    $NewRates.Clear()    
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
        if (-not $Balances -or $LastBalances -lt $Timer.AddMinutes(-10)) {
            Write-Log "Getting pool balances. "
            $Balances = Get-Balance -Config $UserConfig -Rates $Rates -NewRates $NewRates
            $API.Balances = $Balances
            $LastBalances = $Timer
        }
    }

    Remove-Variable "UserConfig", "ConfigBackup"

    #Give API access to the current rates
    $API.Rates = $Rates

    #Load the stats
    Write-Log "Loading saved statistics. "

    [hashtable]$Stats = Get-Stat

    #Give API access to the current stats
    $API.Stats = $Stats

    #Load information about the pools
    Write-Log "Loading pool information. "
    $SelectedPoolNames.Clear()
    if (Test-Path "Pools") {        
        $NewPools = @($AvailPools | Where-Object {$Config.Pools.$_ -and ($Config.PoolName.Count -eq 0 -or $Config.PoolName -icontains $_) -and ($Config.ExcludePoolName.Count -eq 0 -or $Config.ExcludePoolName -inotcontains $_)} | ForEach-Object {
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
                $Pool.Price *= $Pool_Factor
                $Pool.StablePrice *= $Pool_Factor
                $Pool | Add-Member -NotePropertyMembers $Pool_Config -Force -PassThru
            }
        })
    }

    #Remove stats from pools & miners not longer in use
    if (-not $DonateNow -and (Test-Path "Stats")) {
        if ($SelectedPoolNames -and $SelectedPoolNames.Count -gt 0) {Compare-Object @($SelectedPoolNames | Select-Object) @($Stats.Keys | Where-Object {$_ -match '^(.+?)_.+Profit$'} | % {$Matches[1]} | Select-Object -Unique) | Where-Object SideIndicator -eq "=>" | Foreach-Object {Get-ChildItem "Stats\Pools\$($_.InputObject)_*_Profit.txt" -File | Where-Object LastWriteTime -lt (Get-Date).AddDays(-7) | Remove-Item -Force}}
        if ($AvailMiners -and $AvailMiners.Count -gt 0) {Compare-Object @($AvailMiners | Select-Object) @($Stats.Keys | Where-Object {$_ -match '^(.+?)-.+Hashrate$'} | % {$Matches[1]} | Select-Object -Unique) | Where-Object SideIndicator -eq "=>" | Foreach-Object {Get-ChildItem "Stats\Miners\$($_.InputObject)-*_Hashrate.txt" -File | Where-Object LastWriteTime -lt (Get-Date).AddDays(-7) | Remove-Item -Force}}
    }

    #Give API access to the current running configuration
    $API.NewPools = $NewPools

    #This finds any pools that were already in $AllPools (from a previous loop) but not in $NewPools. Add them back to the list. Their API likely didn't return in time, but we don't want to cut them off just yet
    #since mining is probably still working.  Then it filters out any algorithms that aren't being used.    
    $OutofsyncTime = (Get-Date).ToUniversalTime().AddMinutes(-$OutofsyncWindow)
    $AllPools = @($NewPools) + @(Compare-Object @($NewPools.Name | Select-Object -Unique) @($AllPools.Name | Select-Object -Unique) | Where-Object SideIndicator -EQ "=>" | Select-Object -ExpandProperty InputObject | ForEach-Object {$AllPools | Where-Object Name -EQ $_}) |
        Where-Object {
            $Pool = $_
            $Pool_Name = $_.Name
            -not (
                (-not $Config.Pools.$Pool_Name) -or
                ($Config.Algorithm.Count -and -not (Compare-Object @($Config.Algorithm | Select-Object) @($Pool.AlgorithmList | Select-Object) -IncludeEqual -ExcludeDifferent | Measure-Object).Count) -or
                ($Config.ExcludeAlgorithm.Count -and (Compare-Object @($Config.ExcludeAlgorithm | Select-Object) @($Pool.AlgorithmList | Select-Object)  -IncludeEqual -ExcludeDifferent | Measure-Object).Count) -or 
                ($Config.PoolName.Count -and $Config.PoolName -inotcontains $Pool_Name) -or
                ($Config.ExcludePoolName.Count -and $Config.ExcludePoolName -icontains $Pool_Name) -or
                ($Config.ExcludeCoin.Count -and $Pool.CoinName -and @($Config.ExcludeCoin) -icontains $Pool.CoinName) -or
                ($Config.ExcludeCoinSymbol.Count -and $Pool.CoinSymbol -and @($Config.ExcludeCoinSymbol) -icontains $Pool.CoinSymbol) -or
                ($Config.Pools.$Pool_Name.Algorithm.Count -and -not (Compare-Object @($Config.Pools.$Pool_Name.Algorithm | Select-Object) @($Pool.AlgorithmList | Select-Object) -IncludeEqual -ExcludeDifferent | Measure-Object).Count) -or
                ($Config.Pools.$Pool_Name.ExcludeAlgorithm.Count -and (Compare-Object @($Config.Pools.$Pool_Name.ExcludeAlgorithm | Select-Object) @($Pool.AlgorithmList | Select-Object) -IncludeEqual -ExcludeDifferent | Measure-Object).Count) -or
                ($Pool.CoinName -and $Config.Pools.$Pool_Name.CoinName.Count -and @($Config.Pools.$Pool_Name.CoinName) -inotcontains $Pool.CoinName) -or
                ($Pool.CoinName -and $Config.Pools.$Pool_Name.ExcludeCoin.Count -and @($Config.Pools.$Pool_Name.ExcludeCoin) -icontains $Pool.CoinName) -or
                ($Pool.CoinSymbol -and $Config.Pools.$Pool_Name.CoinSymbol.Count -and @($Config.Pools.$Pool_Name.CoinSymbol) -inotcontains $Pool.CoinSymbol) -or
                ($Pool.CoinSymbol -and $Config.Pools.$Pool_Name.ExcludeCoinSymbol.Count -and @($Config.Pools.$Pool_Name.ExcludeCoinSymbol) -icontains $Pool.CoinSymbol) -or
                ($Pool.Updated -lt $OutofsyncTime)
            )
        }

    #Give API access to the current running configuration
    $API.AllPools = $AllPools

    #Apply watchdog to pools
    $AllPools = $AllPools | Where-Object {
        $Pool = $_
        $Pool_WatchdogTimers = $WatchdogTimers | Where-Object PoolName -EQ $Pool.Name | Where-Object Kicked -LT $Timer.AddSeconds( - $WatchdogInterval) | Where-Object Kicked -GT $Timer.AddSeconds( - $WatchdogReset)
        ($Pool_WatchdogTimers | Measure-Object).Count -lt <#stage#>3 -and ($Pool_WatchdogTimers | Where-Object {$Pool.Algorithm -contains $_.Algorithm} | Measure-Object).Count -lt <#statge#>2
    }

    #Update the active pools
    if ($AllPools.Count -eq 0) {
        Write-Log -Level Warn "No pools available. "
        if ($Downloader.HasMoreData) {$Downloader | Receive-Job}
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
    if ($Config.EnableAutoMinerPorts) {Set-ActiveMinerPorts @($ActiveMiners | Where-Object {$_.GetActivateCount() -GT 0 -and $_.GetStatus() -eq [MinerStatus]::Running} | Select-Object);Set-ActiveTcpPorts} else {Set-ActiveTcpPorts -Disable}
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
    [System.Collections.ArrayList]$Miner_Arguments_List = @()
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
        $Miner_OCprofile = [PSCustomObject]@{}

        foreach($p in @($Miner.DeviceModel -split '-')) {$Miner_OCprofile | Add-Member $p ""}

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
                    if ($Config.Miners.$Miner_CommonCommands.Penalty -ne $null -and $Config.Miners.$Miner_CommonCommands.Penalty -ne '' -and $Miner_Penalty -eq -1) {$Miner_Penalty = [double]$Config.Miners.$Miner_CommonCommands.Penalty}
                    if ($Config.Miners.$Miner_CommonCommands.ExtendInterval -and $Miner_ExtendInterval -eq -1) {$Miner_ExtendInterval = [int]$Config.Miners.$Miner_CommonCommands.ExtendInterval}
                    if ($Config.Miners.$Miner_CommonCommands.FaultTolerance -and $Miner_FaultTolerance -eq -1) {$Miner_FaultTolerance = [double]$Config.Miners.$Miner_CommonCommands.FaultTolerance}
                    if ($Config.Miners.$Miner_CommonCommands.OCprofile -and $i -gt 1) {foreach ($p in @($Miner.DeviceModel -split '-')) {if (-not $Miner_OCprofile.$p) {$Miner_OCprofile.$p=$Config.Miners.$Miner_CommonCommands.OCprofile}}}
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
                    if ($Config.Miners.$Miner_CommonCommands.Penalty -ne $null -and $Config.Miners.$Miner_CommonCommands.Penalty -ne '' -and [double]$Config.Miners.$Miner_CommonCommands.Penalty -gt $Miner_Penalty) {$Miner_Penalty = [double]$Config.Miners.$Miner_CommonCommands.Penalty}
                    if ($Config.Miners.$Miner_CommonCommands.ExtendInterval -and [int]$Config.Miners.$Miner_CommonCommands.ExtendInterval -gt $Miner_ExtendInterval) {$Miner_ExtendInterval = [int]$Config.Miners.$Miner_CommonCommands.ExtendInterval}
                    if ($Config.Miners.$Miner_CommonCommands.FaultTolerance -and [double]$Config.Miners.$Miner_CommonCommands.FaultTolerance -gt $Miner_FaultTolerance) {$Miner_FaultTolerance = [double]$Config.Miners.$Miner_CommonCommands.FaultTolerance}
                }
            }           

            #overclocking is different
            foreach($p in @($Miner.DeviceModel -split '-')) {
                if ($Miner_OCprofiles.$p -ne '') {continue}
                $Miner_CommonCommands_array[1] = $p
                for($i=$Miner_CommonCommands_array.Count;$i -gt 1; $i--) {
                    $Miner_CommonCommands = $Miner_CommonCommands_array.GetRange(0,$i) -join '-'
                    if (Get-Member -InputObject $Config.Miners -Name $Miner_CommonCommands -MemberType NoteProperty) {
                        if ($Config.Miners.$Miner_CommonCommands.OCprofile) {$Miner_OCprofile.$p=$Config.Miners.$Miner_CommonCommands.OCprofile}
                    }
                }
            }           
            if ($Miner_Arguments -ne '' -and $Miner.Arguments -is [string]) {
                $Miner_Arguments_List.Clear()
                foreach ($p in @(" $Miner_Arguments" -split '\s+-')) {
                    if (-not $p) {continue}
                    $p="-$p"
                    if ($p -match "([\s=]+)") {
                        $pdiv = $matches[1].Trim()
                        if ($pdiv -eq ''){$pdiv=" "}
                        $q = $p -split "[\s=]+"
                        $Miner.Arguments = $Miner.Arguments -replace "$($q[0])[\s=]+[^\s=]+\s*"
                        $Miner_Arguments_List.Add($q -join $pdiv)>$null
                    } else {
                        $Miner_Arguments_List.Add($p)>$null
                    }
                }
                $Miner | Add-Member -Name Arguments -Value "$($Miner.Arguments.Trim()) $($Miner_Arguments_List -join ' ')" -MemberType NoteProperty -Force
                #$Miner | Add-Member -Name Arguments -Value (@($Miner.Arguments,$Miner_Arguments) -join ' ') -MemberType NoteProperty -Force
            }
            if ($Miner_MSIAprofile -ne 0) {$Miner | Add-Member -Name MSIAprofile -Value $($Miner_MSIAprofile) -MemberType NoteProperty -Force}           
            if ($Miner_Penalty -ne -1) {$Miner | Add-Member -Name Penalty -Value $($Miner_Penalty) -MemberType NoteProperty -Force}
            if ($Miner_ExtendInterval -ne -1) {$Miner | Add-Member -Name ExtendInterval -Value $($Miner_ExtendInterval) -MemberType NoteProperty -Force}
            if ($Miner_FaultTolerance -ne -1) {$Miner | Add-Member -Name FaultTolerance -Value $($Miner_FaultTolerance) -MemberType NoteProperty -Force}            
        }

        foreach($p in @($Miner.DeviceModel -split '-')) {if ($Miner_OCprofile.$p -eq '') {$Miner_OCprofile.$p=$Config.Devices.$p.DefaultOCprofile}}

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
    $Miners_DownloadList = @()
    $Miners = $AllMiners | Where-Object {(Test-Path $_.Path) -and ((-not $_.PrerequisitePath) -or (Test-Path $_.PrerequisitePath)) -and $_.VersionCheck}
    if (($AllMiners.Count -ne $Miners.Count) -or $StartDownloader) {
        $Miners_DownloadList = @($AllMiners | Where-Object {$_.PrerequisitePath} | Select-Object -Unique PrerequisiteURI,PrerequisitePath | Where-Object {-not (Test-Path $_.PrerequisitePath)} | Select-Object @{name = "URI"; expression = {$_.PrerequisiteURI}}, @{name = "Path"; expression = {$_.PrerequisitePath}}, @{name = "Searchable"; expression = {$false}}, @{name = "IsMiner"; expression = {$false}}) + @($AllMiners | Where-Object {$_.VersionCheck -ne $true} | Sort-Object {$_.ExtendInterval} -Descending | Select-Object -Unique @{name = "URI"; expression = {$_.URI}}, @{name = "Path"; expression = {$_.Path}}, @{name = "Searchable"; expression = {$true}}, @{name = "IsMiner"; expression = {$true}})        
        if ($Miners_DownloadList.Count -gt 0 -and $Downloader.State -ne "Running") {
            Clear-Host
            Write-Log "Starting download of $($Miners_DownloadList.Count) files."
            $Downloader = Start-Job -InitializationScript ([scriptblock]::Create("Set-Location('$(Get-Location)')")) -ArgumentList ($Miners_DownloadList) -FilePath .\Downloader.ps1
        }
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
        if ($Miners_DownloadList.Count -gt 0) {
            Write-Host " "
            Write-Host "Downloading first miners, mining operation will start in $($Config.Interval) seconds. Command windows will popup and close during extraction. Please be patient!" -ForegroundColor Black -BackgroundColor Yellow
        }
        if ($Downloader.HasMoreData) {$Downloader | Receive-Job}
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

    $StoppedMiners = @()

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
            $StoppedMiners += $Miner
        }
    }

    if (($ActiveMiners | ForEach-Object {$_.GetProcessNames()} | Measure-Object).Count -gt 0) {
        $Running = @($ActiveMiners | Where-Object Best -EQ $true | Foreach-Object {if ($_.GetStatus() -eq [MinerStatus]::Running -and $_.GetProcessId() -gt 0) {$_.GetProcessId()}})
        Get-Process | Where-Object {@($ActiveMiners | Foreach-Object {$_.GetExecNames()}) -contains $_.ProcessName} | Select-Object -ExpandProperty ProcessName | Compare-Object @($ActiveMiners | Where-Object Best -EQ $true | Where-Object {$_.GetStatus() -eq [MinerStatus]::Running} | ForEach-Object {$_.GetExecNames()}) | Where-Object SideIndicator -EQ "=>" | Select-Object -ExpandProperty InputObject | Select-Object -Unique | ForEach-Object {Get-Process -Name $_ -ErrorAction Ignore | Where-Object {$Running -notcontains $_.Id} | ForEach-Object {Write-Warning "Stop-Process $($_.ProcessName) with Id $($_.Id)"; Stop-Process -Id $_.Id -Force -ErrorAction Ignore}}
    }
    if ($Downloader.HasMoreData) {$Downloader | Receive-Job}
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
                $_.SetOCprofile($Config)
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

    #Get count of miners, that need to be benchmarked. If greater than 0, the UIstyle "full" will be used    
    $MinersNeedingBenchmark = @($Miners | Where-Object {$_.HashRates.PSObject.Properties.Value -contains $null})
    $API.MinersNeedingBenchmark = $MinersNeedingBenchmark

    #Move donation run into the future, if benchmarks are ongoing
    if ($MinersNeedingBenchmark.Count -gt 0) {$LastDonated = $Timer.AddHours(1 - $DonateDelayHours).AddMinutes($DonateMinutes)}

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
        if ($MinersNeedingBenchmark.Count -gt 0 -or $Miners_DownloadList.Count -gt 0) {Write-Host " "}
        #Display benchmarking progres
        if ($MinersNeedingBenchmark.Count -gt 0) {
            Write-Log -Level Warn "Benchmarking in progress: $($MinersNeedingBenchmark.Count) miner$(if ($MinersNeedingBenchmark.Count -gt 1){'s'}) left."
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
        if ($Miners_DownloadList.Count -gt 0) {
            Write-Log -Level Warn "Download in progress: $($Miners_DownloadList.Count) miner$(if($Miners_DownloadList.Count -gt 1){"s"}) left. Command windows will popup during extraction."
        }
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
    Get-Job -State Completed | Remove-Job -Force
    [GC]::Collect()
    Sleep -Milliseconds 200

    if ($Error.Count) {$Error | Out-File "Logs\errors_$(Get-Date -Format "yyyy-MM-dd").main.txt" -Append}
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
            if ($Downloader.HasMoreData) {$Downloader | Receive-Job}
            #Give API access to computerstats
            $API.ComputerStats = $AsyncLoader.ComputerStats
        }

        Start-Sleep 2

        if (($WaitMaxI-$i+1) % 5 -eq 0) {
            #pick up a sample every ten seconds, starting after ten seconds

            if ($Config.MinerStatusURL -and $Config.MinerStatusKey) {
                if ($Timer -gt $NextReport) {
                    & .\ReportStatus.ps1 -Key $Config.MinerStatusKey -WorkerName $Config.WorkerName -ActiveMiners $ActiveMiners -MinerStatusURL $Config.MinerStatusURL
                    $NextReport = $Timer.AddSeconds($Config.Interval)
                }
            }
            Update-DeviceInformation @($ActiveMiners.DeviceName | Select-Object -Unique) -UseAfterburner (-not $Config.DisableMSIAmonitor)

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

        if ($Miner.New) {$Miner.New = [Boolean]($Miner.Algorithm | Where-Object {-not (Get-Stat -Name "$($Miner.Name)_$($_ -replace '\-.*$')_HashRate" -Sub $DevicesToVendors[$Miner.DeviceModel])})}

        if ($Miner.New) {$Miner.Benchmarked++}

        if ($Miner.GetStatus() -eq "Running" -or $Miner.New) {
            $Miner_PowerDraw = $Miner.GetPowerDraw($Config.Interval * $ExtendInterval)
            $Miner.Algorithm | ForEach-Object {
                $Miner_Speed = $Miner.GetHashRate($_, $Config.Interval * $ExtendInterval, $Miner.New)
                $Miner.Speed_Live += [Double]$Miner_Speed

                if ($Miner.New -and (-not $Miner_Speed)) {$Miner_Speed = $Miner.GetHashRate($_, ($Config.Interval * $Miner.Benchmarked * $ExtendInterval), ($Miner.Benchmarked -lt $Strikes))}

                if ((-not $Miner.New) -or $Miner_Speed -or $Miner.Benchmarked -ge ($Strikes * $Strikes) -or $Miner.GetActivateCount() -ge $Strikes) {
                    $Stat = Set-Stat -Name "$($Miner.Name)_$($_ -replace '\-.*$')_HashRate" -Value $Miner_Speed -Duration $StatSpan -FaultDetection $true -FaultTolerance $Miner.FaultTolerance -PowerDraw $Miner_PowerDraw -Sub $DevicesToVendors[$Miner.DeviceModel]
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

    #Cleanup stopped miners
    $StoppedMiners | Foreach-Object {$_.Cleanup()}
    Remove-Variable "StoppedMiners"

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
        $Miner.ShutDownMiner()
        $ExcavatorWindowsClosed.Add($Miner.BaseName) > $null
    }
}

#Stop the log
Stop-Transcript

if ($AutoUpdate -and -not $psISE) {Exit 999}
