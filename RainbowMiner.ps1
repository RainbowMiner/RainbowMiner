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
    [Array]$ExtendInterval = @("x16r","ravenminer","palginnvidia"), # Extend timing interval for Miners or currencies
    [Parameter(Mandatory = $false)]
    [Alias("Location")]
    [String]$Region = "europe", #europe/us/asia
    [Parameter(Mandatory = $false)]
    [Switch]$SSL = $false, 
    [Parameter(Mandatory = $false)]
    [Alias("Device", "Type")]
    [Array]$DeviceName = @(), #i.e. CPU, GPU, GPU#02, AMD, NVIDIA, AMD#02, OpenCL#03#02 etc.
    [Parameter(Mandatory = $false)]
    [Array]$Algorithm = @("bitcore","blake2s","c11","cryptonightheavy","cryptonightv7","ethash","equihash","hmq1725","hsr","keccak","keccakc","lyra2re2","lyra2z","neoscrypt","pascal","phi","skein","skunk","timetravel","tribus","x16r","x16s","x17","vit","xevan","yescrypt","yescryptr16"), #i.e. Ethash,Equihash,CryptoNight etc.
    [Parameter(Mandatory = $false)]
    [Alias("Miner")]
    [Array]$MinerName = @(), 
    [Parameter(Mandatory = $false)]
    [Alias("Pool")]
    [Array]$PoolName = @("nicehash","blazepool","miningpoolhub"), 
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
    [Switch]$LegacyMining = $false, # if set to $true, all GPUs will only be separated into NVIDIA and AMD
    [Parameter(Mandatory = $false)]
    [String]$MSIApath = "c:\Program Files (x86)\MSI Afterburner\MSIAfterburner.exe", # installation path of MSI Afterburner
    [Parameter(Mandatory = $false)]
    [Int]$MSIAprofile = 2, # default MSI Afterburner profile to be set
    [Parameter(Mandatory = $false)]
    [String]$UIstyle = "full" # ui style: full=show all, lite=show only active miner
)

Clear-Host

$Version = "3.5.2.0"
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

if (-not (Test-Path Config)) {New-Item -Name "Config" -ItemType "directory" -Force}

if (-not $ConfigFile) {$ConfigFile = "Config\config.txt"}# Create config.txt if it is missing
if (-not (Test-Path $ConfigFile)) {
    if(Test-Path "Config\config.default.txt") {
        Copy-Item -Path "Config\config.default.txt" -Destination $ConfigFile
        $RunSetup = $true
    } else {
        Write-Log -Level Error "$($ConfigFile) and Config\config.default.txt are missing. Cannot continue. "
        Exit
    }
}$ConfigFile = Get-Item $ConfigFile | Foreach-Object {    $ConfigFile_Path = $_ | Select-Object -ExpandProperty DirectoryName    $ConfigFile_Name = $_ | Select-Object -ExpandProperty Name    $PoolsConfigFile = @($ConfigFile_Path,"\pools.",$ConfigFile_Name) -join ''    $MinersConfigFile = @($ConfigFile_Path,"\miners.",$ConfigFile_Name) -join ''

    # Create pools.config.txt if it is missing
    if (-not (Test-Path $PoolsConfigFile)) {
        if(Test-Path "Config\pools.config.default.txt") {
            Copy-Item -Path "Config\pools.config.default.txt" -Destination $PoolsConfigFile
        } else {
            Write-Log -Level Error "$($PoolsConfigFile) and Config\pools.config.default.txt are missing. Cannot continue. "
            Exit
        }
    }
    $PoolsConfigFile = $PoolsConfigFile | Resolve-Path -Relative

    # Create miners.config.txt if it is missing
    if (-not (Test-Path $MinersConfigFile)) {
        if(Test-Path "Config\miners.config.default.txt") {
            Copy-Item -Path "Config\miners.config.default.txt" -Destination $MinersConfigFile
        } else {
            Write-Log -Level Error "$($MinersConfigFile) and Config\miners.config.default.txt are missing. Cannot continue. "
            Exit
        }
    }
    $MinersConfigFile = $MinersConfigFile | Resolve-Path -Relative
    $_ | Resolve-Path -Relative
}
[console]::TreatControlCAsInput = $true

while ($true) {
    #Load the config
    $ConfigBackup = if ($Config -is [object]){$Config.PSObject.Copy()}else{$null}
    $ConfigCheckFields = $true
    if (Test-Path $ConfigFile) {
        if (-not $Config -or $RunSetup -or (Get-ChildItem $ConfigFile).LastWriteTime.ToUniversalTime() -gt $ConfigTimeStamp) {        
            $ConfigTimeStamp = (Get-ChildItem $ConfigFile).LastWriteTime.ToUniversalTime()
            $Config = Get-ChildItemContent $ConfigFile -Force -Parameters @{
                Wallet              = $Wallet
                UserName            = $UserName
                WorkerName          = $WorkerName
                API_ID              = $API_ID
                API_Key             = $API_Key
                Interval            = $Interval
                ExtendInterval      = $ExtendInterval
                Region              = $Region
                SSL                 = $SSL
                DeviceName          = $DeviceName
                Algorithm           = $Algorithm
                MinerName           = $MinerName
                PoolName            = $PoolName
                ExcludeAlgorithm    = $ExcludeAlgorithm
                ExcludeMinerName    = $ExcludeMinerName
                ExcludePoolName     = $ExcludePoolName
                Currency            = $Currency
                Donate              = $Donate
                Proxy               = $Proxy
                Delay               = $Delay
                Watchdog            = $Watchdog
                MinerStatusURL      = $MinerStatusURL
                MinerStatusKey      = $MinerStatusKey
                SwitchingPrevention = $SwitchingPrevention
                ShowMinerWindow     = $ShowMinerWindow
                FastestMinerOnly    = $FastestMinerOnly
                IgnoreFees          = $IgnoreFees
                ShowPoolBalances    = $ShowPoolBalances
                RebootOnGPUFailure  = $RebootOnGPUFailure
                MSIApath            = $MSIApath
                MSIAprofile         = $MSIAprofile
                UIstyle             = $UIstyle
                LegacyMining        = $LegacyMining
            } | Select-Object -ExpandProperty Content

            if ($RunSetup) {

                do {
                    Write-Host " "
                    Write-Host "*** RainbowMiner Configuration ***"
                    Write-Host "Please choose, what to configure:"
                    $SetupType = Read-HostString -Prompt "[G]lobal, [M]iner, [P]ools, E[x]it configuration" -Default "X"  -Mandatory -Characters "GMPX"
                    Write-Host " "

                    if ($SetupType -eq "X") {
                        $RunSetup = $false
                    }
                    elseif ($SetupType -eq "G") {

                        $ConfigActual = Get-Content $ConfigFile | ConvertFrom-Json
                        $PoolsActual = Get-Content $PoolsConfigFile | ConvertFrom-Json

                        Write-Host "*** Global Configuration ***"
                        Write-Host "Hints:"
                        Write-Host "- the defaults are your current configuration. Press Return to accept the defaults."
                        Write-Host "- fields marked with * are mandatory"
                        Write-Host "- use comma `",`" to separate list entries"
                        Write-Host "- enter `"list`" or `"help`" to show a list of all valid entries"
                        Write-Host "- enter `"delete`" to clear a non-mandatory entry"
                        Write-Host " "

                        # Start setup procedure
                        $Config.Wallet = Read-HostString -Prompt "Enter your BTC wallet address" -Default $Config.Wallet -Length 34 -Mandatory -Characters "A-Z0-9"               

                        if ($PoolsActual | Get-Member Nicehash -MemberType NoteProperty) {
                            $NicehashWallet = $PoolsActual.Nicehash.BTC
                            $NicehashWorkerName = $PoolsActual.Nicehash.Worker
                        } else {
                            $NicehashWallet = '$Wallet'
                            $NicehashWorkerName = '$WorkerName'
                        }
                        if ($NicehashWallet -eq '$Wallet'){$NicehashWallet=$Config.Wallet}
                        $NicehashWallet = Read-HostString -Prompt "Enter your NiceHash-BTC wallet address" -Default $NicehashWallet -Length 34 -Mandatory -Characters "A-Z0-9"
                        $Config.WorkerName = Read-HostString -Prompt "Enter your worker name" -Default $Config.WorkerName -Mandatory -Characters "A-Z0-9"
                        $Config.UserName = Read-HostString -Prompt "Enter your Miningpoolhub user name" -Default $Config.UserName -Characters "A-Z0-9"
                        $Config.Region = Read-HostString -Prompt "Enter your region" -Default $Config.Region -Mandatory -Characters "A-Z" -Valid @(Get-Regions)
                        $Config.Currency = Read-HostArray -Prompt "Enter all currencies to be displayed (e.g. EUR,USD,BTC)" -Default $Config.Currency -Mandatory -Characters "A-Z"
                        $Config.PoolName = Read-HostArray -Prompt "Enter the pools you want to mine" -Default $Config.PoolName -Mandatory -Characters "A-Z0-9" -Valid @(Get-ChildItem "Pools\*.ps1" | Select-Object -ExpandProperty BaseName)
                        $Config.ExcludePoolName = Read-HostArray -Prompt "Enter the pools you do want to exclude from mining" -Default $Config.ExcludePoolName -Characters "A-Z0-9" -Valid (Get-ChildItem "Pools\*.ps1" | Select-Object -ExpandProperty BaseName)
                        $Config.MinerName = Read-HostArray -Prompt "Enter the miners your want to use (leave empty for all)" -Default $Config.MinerName -Characters "A-Z0-9.-_" -Valid (Get-ChildItem "Miners\*.ps1" | Select-Object -ExpandProperty BaseName)
                        $Config.ExcludeMinerName = Read-HostArray -Prompt "Enter the miners you do want to exclude" -Default $Config.ExcludeMinerName -Characters "A-Z0-9.-_" -Valid (Get-ChildItem "Miners\*.ps1" | Select-Object -ExpandProperty BaseName)                
                        $Config.Algorithm = Read-HostArray -Prompt "Enter the algorithm you want to mine (leave empty for all)" -Default $Config.Algorithm -Characters "A-Z0-9" -Valid (Get-Algorithms)
                        $Config.FastestMinerOnly = Read-HostBool -Prompt "Show fastest miner only" -Default $Config.FastestMinerOnly
                        $Config.UIstyle = Read-HostString -Prompt "Select style of user interface (full/lite)" -Default $Config.UIstyle -Mandatory -Characters "A-Z"
                        if ($Config.UIstyle -like "l*"){$Config.UIstyle="lite"}else{$Config.UIstyle="full"}                
                        $Config.LegacyMining = Read-HostBool "Always use one miner per all nvidia or amd, only" -Default $Config.LegacyMining

                        $AvailDeviceName = @()
                        $SetupDevices = Get-Device "nvidia","amd","cpu"
                        if (Select-Device $SetupDevices "nvidia") {$AvailDeviceName += "nvidia"}
                        if (Select-Device $SetupDevices "amd") {$AvailDeviceName += "amd"}               
                        if (-not $Config.LegacyMining) {$SetupDevices | Select-Object -ExpandProperty Model -Unique | Foreach-Object {$AvailDeviceName += $_}}else{$AvailDeviceName+="cpu"}

                        $Config.DeviceName = Read-HostArray -Prompt "Enter the devices you want to use for mining (leave empty for all)" -Default $Config.DeviceName -Characters "A-Z0-9#" -Valid $AvailDeviceName
           
                        $ConfigActual | Add-Member Wallet $Config.Wallet -Force
                        $ConfigActual | Add-Member WorkerName $Config.WorkerName -Force
                        $ConfigActual | Add-Member UserName $Config.UserName -Force
                        $ConfigActual | Add-Member Regin $Config.Region -Force
                        $ConfigActual | Add-Member Currency $($Config.Currency -join ",") -Force
                        $ConfigActual | Add-Member PoolName $($Config.PoolName -join ",") -Force
                        $ConfigActual | Add-Member ExcludePoolName $($Config.ExcludePoolName -join ",") -Force
                        $ConfigActual | Add-Member MinerName $($Config.MinerName -join ",") -Force
                        $ConfigActual | Add-Member ExcludeMinerName $($Config.ExcludeMinerName -join ",") -Force
                        $ConfigActual | Add-Member Algorithm $($Config.Algorithm -join ",") -Force
                        $ConfigActual | Add-Member LegacyMining $(if ($Config.LegacyMining){"1"}else{"0"}) -Force
                        $ConfigActual | Add-Member FastestMinerOnly $(if ($Config.FastestMinerOnly){"1"}else{"0"}) -Force
                        $ConfigActual | Add-Member UIstyle $(if ($Config.UIstyle -eq "lite"){"lite"}else{"full"}) -Force
                        $ConfigActual | Add-Member DeviceName $($Config.DeviceName -join ",") -Force                      

                        $PoolsActual | Add-Member NiceHash ([PSCustomObject]@{
                                BTC = if($NicehashWallet -eq $Config.Wallet -or $NicehashWallet -eq ''){'$Wallet'}else{$NicehashWallet}
                                Worker = if($NicehashWorkerName -eq $Config.WorkerName -or $NicehashWorkerName -eq ''){'$WorkerName'}else{$NicehashWorkerName}
                        }) -Force

                        $ConfigActual | ConvertTo-Json | Out-File $ConfigFile                                               
                        $PoolsActual | ConvertTo-Json | Out-File $PoolsConfigFile                        
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
                        if ($Config.LegacyMining) {
                            if (Select-Device $SetupDevices "nvidia") {$AvailDeviceName += "nvidia"}
                            if (Select-Device $SetupDevices "amd") {$AvailDeviceName += "amd"}
                            if (Select-Device $SetupDevices "cpu") {$AvailDeviceName += "cpu"}
                        } else {
                            $SetupDevices | Select-Object -ExpandProperty Model -Unique | Foreach-Object {$AvailDeviceName += $_}
                        }

                        $MinerSetupDone = $false
                        do {
                            try {
                                $EditMinerName = Read-HostString -Prompt "Which miner do you want to configure? (leave empty to end miner config)" -Characters "A-Z0-9.-_" -Valid (Get-ChildItem "Miners\*.ps1" | Select-Object -ExpandProperty BaseName)
                                if ($EditMinerName -eq '') {throw}
                                $EditDeviceName = Read-HostString -Prompt ".. running on which device? (leave empty to end miner config)" -Characters "A-Z0-9#" -Valid $AvailDeviceName
                                if (-not $EditDeviceName.Count) {theow}
                                $EditAlgorithm = Read-HostString -Prompt ".. calculating which main algorithm? (leave empty to end miner config)" -Characters "A-Z0-9" -Valid (Get-Algorithms)
                                if (-not $EditAlgorithm.Count) {theow}
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
                Write-Host " "
                Write-Host "Exiting configuration setup - all miners will be restarted. Please be patient!"
                Write-Host " "
            }
        } else {
            $ConfigCheckFields = $false
        }
    }
    if (Test-Path $PoolsConfigFile) {
        if (-not $Config.Pools -or (Get-ChildItem $PoolsConfigFile).LastWriteTime.ToUniversalTime() -gt $PoolsConfigTimeStamp) {        
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
    if (Test-Path $MinersConfigFile) {
        if (-not $Config.Miners -or (Get-ChildItem $MinersConfigFile).LastWriteTime.ToUniversalTime() -gt $MinersConfigTimeStamp) {        
            $MinersConfigTimeStamp = (Get-ChildItem $MinersConfigFile).LastWriteTime.ToUniversalTime()
            $Config | Add-Member Miners ([PSCustomObject]@{}) -Force            
            (Get-ChildItemContent -Path $MinersConfigFile).Content.PSObject.Properties | Foreach-Object {
                $CcMinerName = $_.Name                
                $_.Value | Foreach-Object {                   
                    $Config.Miners | Add-Member -Name (@($CcMinerName,(Get-Algorithm $_.MainAlgorithm)) + @(if($_.SecondaryAlgorithm){Get-Algorithm $_.SecondaryAlgorithm}) -join '-') -Value ([PSCustomObject]@{Params=$_.Params;Profile=$_.Profile}) -MemberType NoteProperty -Force
                }
            }
        }
    }
    
     #Error in Config.txt
    if ($Config -isnot [PSCustomObject]) {
        Write-Log -Level Error "$($ConfigFile) is invalid. Cannot continue. "
        Start-Sleep 10
        Exit
    }

    #Convert to array, if needed and check contents of some fields, if Config has been reread or reset
    if ( $ConfigCheckFields ) {
        #for backwards compatibility
        if ($Config.Type -ne $null) {$Config | Add-Member DeviceName $Config.Type -Force}
        if ($Config.GPUs -ne $null -and $Config.GPUs) {
            if ($Config.GPUs -is [string]) {$Config.GPUs = [regex]::split($Config.GPUs,"[,;:\s]+")}
            $Config | Add-Member DeviceName @() -Force
            Get-Device "nvidia" | Where-Object {$Config.GPUs -contains $_.Type_PlatformId_Index} | Foreach-Object {$Config.DeviceName += [string]("GPU#{0:d2}" -f $_.Type_Index)}
        }

        $Config | Get-Member -MemberType *Property | Foreach-Object {
            $name = $_.Name;
            $var  = Get-Variable -ValueOnly $name -ErrorAction SilentlyContinue
            if ( $var -is [array] -and $Config.$name -is [string] ) {$Config.$name = $Config.$name.Trim(); $Config.$name = if ($Config.$name -ne ''){[regex]::split($Config.$name.Trim(),"[,;:\s]+")}else{@()}}
            elseif ( ($var -is [bool] -or $var -is [switch]) -and $Config.$name -isnot [bool] ) {$Config.$name = "1","yes","y","ja","j","true" -icontains $Config.$name}
            elseif ( $var -is [int] -and $Config.$name -isnot [int] ) { $Config.$name = [int]$Config.$name.Trim() }
        }
        $Config.Algorithm = $Config.Algorithm | ForEach-Object {Get-Algorithm $_}
        $Config.ExcludeAlgorithm = $Config.ExcludeAlgorithm | ForEach-Object {Get-Algorithm $_}
        $Config.Region = $Config.Region | ForEach-Object {Get-Region $_}
        $Config.Currency = $Config.Currency | ForEach-Object {$_.ToUpper()}
        $Config.UIstyle = if ( $Config.UIstyle -ne "full" -and $Config.UIstyle -ne "lite" ) {"full"} else {$Config.UIstyle}            

        #For backwards compatibility, set the MinerStatusKey to $Wallet if it's not specified
        if ($Config.Wallet -and -not $Config.MinerStatusKey) {$Config.MinerStatusKey = $Config.Wallet}      
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
    $Donate = if ($Config.Donate -lt 10) {10} else {$Config.Donate}
    $DonateDelayHours = 24
    if ($Donate -gt 15) {
        $Donate /= 2
        $DonateDelayHours /= 2
    }
    if (-not $LastDonated) {$LastDonated = $Timer.AddHours(1 - $DonateDelayHours).AddMinutes($Donate)}
    if ($Timer.AddHours(-$DonateDelayHours) -ge $LastDonated) {$LastDonated = $Timer}    
    if ($Timer.AddHours(-$DonateDelayHours).AddMinutes($Donate) -ge $LastDonated) {    
        $DonateNow = $false
        $DonationPools = @()
        if (-not $DonationData -and (Test-Path "data.json")) {$DonationData = (Get-ChildItemContent -Path "data.json").Content}
        if (-not $DonationData) {$DonationData = '{"Wallets":{"NiceHash":{"BTC":"3HFhYADZvybBstETYNEVMqVWMU9EJRfs4f","Worker":"mpx"},"Ravenminer":{"RVN":"RGo5UgbnyNkfA8sUUbv62cYnV4EfYziNxH","Worker":"mpx"},"Default":{"BTC":"3DxRETpBoXKrEBQxFb2HsPmG6apxHmKmUx","Worker":"mpx"}},"Pools":["nicehash","blazepool","ravenminer"]}' | ConvertFrom-Json}
        Get-ChildItem "Pools" -File | ForEach-Object {
            $DonationData1 = if ($DonationData.Wallets.($_.BaseName)) {$DonationData.Wallets.($_.BaseName)} else {$DonationData.Wallets.Default};
            $DonationPools += $_.BaseName
            $Config.Pools | Add-Member $_.BaseName $DonationData1 -Force
            $DonateNow = $true
        }
        if ( $DonateNow ) {
            $ConfigTimeStamp = 0
            $DonationPoolsAvail = @(Compare-Object $DonationPools $DonationData.Pools -PassThru -IncludeEqual -ExcludeDifferent)
            if (-not $DonationPoolsAvail) {            
                $Config | Add-Member ExcludePoolName @() -Force
            } else {
                $Config | Add-Member PoolName $DonationPoolsAvail -Force
                $Config | Add-Member ExcludePoolName @(Compare-Object $DonationPools $DonationPoolsAvail -PassThru) -Force
            }
        }
    }

    #Give API access to the current running configuration
    $API.Config = $UserConfig

    #Actions, when config has changes (or initial)
    # .. for every change
    if (($ConfigBackup | ConvertTo-Json -Compress) -ne ($Config | ConvertTo-Json -Compress)) {
        #Clear pool cache if the pool configuration has changed
        if (($ConfigBackup.Pools | ConvertTo-Json -Compress) -ne ($Config.Pools | ConvertTo-Json -Compress)) {
            $AllPools = $null
        }
    }
    # .. for user changes
    if (($ConfigBackup | ConvertTo-Json -Compress) -ne ($UserConfig | ConvertTo-Json -Compress)) {

        Write-Log "Config changed -> Reset "

        #Clear balances if pool configuration or flag has changed
        if ($ConfigBackup.ShowPoolBalances -ne $UserConfig.ShowPoolBalances) {
            $Balances = $null
        }
        if (($ConfigBackup.Pools | ConvertTo-Json -Compress) -ne ($UserConfig.Pools | ConvertTo-Json -Compress)) {
            $Balances = $null
        }

        #Load information about the devices
        $Devices = @(Get-Device $Config.DeviceName | Select-Object)
        $DevicesByTypes = [PSCustomObject]@{
            NVIDIA = @(Select-Device $Devices "NVIDIA")
            AMD = @(Select-Device $Devices "AMD")
            CPU = @(Select-Device $Devices "CPU")
        }
        if ($Config.LegacyMining) {
            $DevicesByTypes.PSObject.Properties | Select-Object -ExpandProperty Name | ForEach-Object {
                $Device_LegacyModel = $_
                $DevicesByTypes.$Device_LegacyModel | Foreach-Object {$_ | Add-Member Model $Device_LegacyModel -Force}
            }
        }

        #Give API access to the device information
        $API.Devices = $Devices
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
        $Config.Currency | Where-Object {-not $NewRates.$_} | Foreach-Object {$Rates | Add-Member $_ ([Double]1/(Get-Ticker -Symbol $_ | Select-Object -ExpandProperty BTC | Select-Object -ExpandProperty price))}
    }
    catch {
        Write-Log -Level Warn "Coinbase is down. "
    }

    #Update the pool balances every 10 Minutes
    if ( $Config.ShowPoolBalances ) {
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
                $_
            } | #for backward compatibility            
            Where-Object {$_.DeviceName} | #filter miners for non-present hardware
            Where-Object {(Compare-Object @($Devices.Name | Select-Object) @($_.DeviceName | Select-Object) | Where-Object SideIndicator -EQ "=>" | Measure-Object).Count -eq 0} | 
            Where-Object {($Config.Algorithm.Count -eq 0 -or (Compare-Object $Config.Algorithm $_.HashRates.PSObject.Properties.Name | Where-Object SideIndicator -EQ "=>" | Measure-Object).Count -eq 0) -and ((Compare-Object $Pools.PSObject.Properties.Name $_.HashRates.PSObject.Properties.Name | Where-Object SideIndicator -EQ "=>" | Measure-Object).Count -eq 0)} | 
            Where-Object {$Config.ExcludeAlgorithm.Count -eq 0 -or (Compare-Object $Config.ExcludeAlgorithm $_.HashRates.PSObject.Properties.Name -IncludeEqual -ExcludeDifferent | Measure-Object).Count -eq 0} | 
            Where-Object {$Config.MinerName.Count -eq 0 -or (Compare-Object $Config.MinerName $_.Name -IncludeEqual -ExcludeDifferent | Measure-Object).Count -gt 0} | 
            Where-Object {$Config.ExcludeMinerName.Count -eq 0 -or (Compare-Object $Config.ExcludeMinerName $_.Name -IncludeEqual -ExcludeDifferent | Measure-Object).Count -eq 0}
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
       
        $Miner_CommonCommands = @($Miner.BaseName) + @($Miner.Name -split '-' | Select-Object -Skip 1) + @($Miner.HashRates.PSObject.Properties.Name) -join '-'
        if ($Config.Miners -and (Get-Member -InputObject $Config.Miners -Name $Miner_CommonCommands -MemberType NoteProperty)) {
            if ($Config.Miners.$Miner_CommonCommands.Params) {
                $Miner | Add-Member -Name Arguments -Value (@($Miner.Arguments,$Config.Miners.$Miner_CommonCommands.Params) -join ' ') -MemberType NoteProperty -Force
            }
            if ($Config.Miners.$Miner_CommonCommands.Profile) {
                $Miner | Add-Member -Name MSIAprofile -Value $Config.Miners.$Miner_CommonCommands.Profile -MemberType NoteProperty -Force
            }
        }

        $Miner.HashRates.PSObject.Properties.Name | ForEach-Object { #temp fix, must use 'PSObject.Properties' to preserve order
            $Miner_DevFees | Add-Member $_ ([Double]$(if ( -not $Config.IgnoreFees -and $Miner.DevFee ) {[Double]$(if (Get-Member -inputobject $Miner.DevFee -name $_ -Membertype Properties) {$Miner.DevFee.$_} else {$Miner.DevFee})} else {0})) -Force
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

        if ($Miner.Arguments -isnot [String]) {$Miner.Arguments = $Miner.Arguments | ConvertTo-Json -Compress}

        if (-not $Miner.API) {$Miner | Add-Member API "Miner" -Force}
    }
    $Miners = $AllMiners | Where-Object {(Test-Path $_.Path) -and ((-not $_.PrerequisitePath) -or (Test-Path $_.PrerequisitePath))}
    if ( ($StartDownloader -or $Miners.Count -ne $AllMiners.Count) -and $Downloader.State -ne "Running") {
        if ( $StartDownloader ) {
            Write-Log -Level Warn "User requested to start downloader. "
        } else {
            Write-Log -Level Warn "Some miners binaries are missing, starting downloader. "
        }
        $Downloader = Start-Job -InitializationScript ([scriptblock]::Create("Set-Location('$(Get-Location)')")) -ArgumentList (@($AllMiners | Where-Object {$_.PrerequisitePath} | Select-Object @{name = "URI"; expression = {$_.PrerequisiteURI}}, @{name = "Path"; expression = {$_.PrerequisitePath}}, @{name = "Searchable"; expression = {$false}}) + @($AllMiners | Select-Object URI, Path, @{name = "Searchable"; expression = {$Miner = $_; ($AllMiners | Where-Object {(Split-Path $_.Path -Leaf) -eq (Split-Path $Miner.Path -Leaf) -and $_.URI -ne $Miner.URI}).Count -eq 0}}) | Select-Object * -Unique) -FilePath .\Downloader.ps1
        $StartDownloader = $false
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
            $_.Wrap -eq $Miner.Wrap -and 
            $_.API -eq $Miner.API -and 
            $_.Port -eq $Miner.Port -and 
            (Compare-Object $_.Algorithm ($Miner.HashRates | Get-Member -MemberType NoteProperty | Select-Object -ExpandProperty Name) | Measure-Object).Count -eq 0
        }
        if ($ActiveMiner) {
            $ActiveMiner.DeviceName = $Miner.DeviceName
            $ActiveMiner.DeviceModel = $Miner.DeviceModel
            $ActiveMiner.Profit = $Miner.Profit
            $ActiveMiner.Profit_Comparison = $Miner.Profit_Comparison
            $ActiveMiner.Profit_MarginOfError = $Miner.Profit_MarginOfError
            $ActiveMiner.Profit_Bias = $Miner.Profit_Bias
            $ActiveMiner.Profit_Unbias = $Miner.Profit_Unbias
            $ActiveMiner.Speed = $Miner.HashRates.PSObject.Properties.Value #temp fix, must use 'PSObject.Properties' to preserve order
        }
        else {
            $ActiveMiners += New-Object $Miner.API -Property @{
                Name                 = $Miner.Name
                Path                 = $Miner.Path
                Arguments            = $Miner.Arguments
                Wrap                 = $Miner.Wrap
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
                BenchmarkIntervals   = if ($Miner.BenchmarkIntervals -eq $null) {1} else {$Miner.BenchmarkIntervals}
                ShowMinerWindow      = ($Miner.ShowMinerWindow -or $Config.ShowMinerWindow)
                DevFee               = $Miner.DevFee
                ExecName             = if ($Miner.ExecName -eq $null) {([IO.FileInfo]($Miner.Path | Split-Path -Leaf -ErrorAction Ignore)).BaseName} else {$Miner.ExecName}
                FaultTolerance       = if ($Miner.FaultTolerance -eq $null) {0.1} else {$Miner.FaultTolerance}
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
    $BestMiners = $ActiveMiners | Select-Object DeviceName -Unique | ForEach-Object {$Miner_GPU = $_; ($ActiveMiners | Where-Object {(Compare-Object $Miner_GPU.DeviceName $_.DeviceName | Measure-Object).Count -eq 0} | Sort-Object -Descending {($_ | Where-Object Profit -EQ $null | Measure-Object).Count}, {($_ | Measure-Object Profit_Bias -Sum).Sum}, {($_ | Where-Object Profit -NE 0 | Measure-Object).Count} | Select-Object -First 1)}
    $BestMiners_Comparison = $ActiveMiners | Select-Object DeviceName -Unique | ForEach-Object {$Miner_GPU = $_; ($ActiveMiners | Where-Object {(Compare-Object $Miner_GPU.DeviceName $_.DeviceName | Measure-Object).Count -eq 0} | Sort-Object -Descending {($_ | Where-Object Profit -EQ $null | Measure-Object).Count}, {($_ | Measure-Object Profit_Comparison -Sum).Sum}, {($_ | Where-Object Profit -NE 0 | Measure-Object).Count} | Select-Object -First 1)}
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
            if ( $Config.MSIApath -and (Test-Path $Config.MSIApath) -and $Config.MSIAprofile ) {
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
                $_.Algorithm | ForEach-Object {
                    $Miner_Algorithm = $_
                    $WatchdogTimer = $WatchdogTimers | Where-Object {$_.MinerName -eq $Miner_Name -and $_.PoolName -eq $Pools.$Miner_Algorithm.Name -and $_.Algorithm -eq $Miner_Algorithm}
                    if (-not $WatchdogTimer) {
                        $WatchdogTimers += [PSCustomObject]@{
                            MinerName = $Miner_Name
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
        $Miner_DeviceModel = $_.DeviceModel
        Write-Host "$($_.DeviceModel): $($_.DeviceName -join ',')"
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
        @{Label = "Miner"; Expression = {$_.Name}},
        @{Label = "Command"; Expression = {"$($_.Path.TrimStart((Convert-Path ".\"))) $($_.Arguments)"}}
    ) | Out-Host

    if ( $Config.UIstyle -eq "full" -or $MinersNeedingBenchmark.Count -gt 0 ) {
        #Display watchdog timers
        $WatchdogTimers | Where-Object Kicked -gt $Timer.AddSeconds( - $WatchdogReset) | Format-Table -Wrap (
            @{Label = "Miner"; Expression = {$_.MinerName}}, 
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
        [PSCustomObject]@{"Miner" = $BestMiners_Combo_Comparison | ForEach-Object {"$($_.Name)-$($_.Algorithm -join '/')"}}

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

    #When benchmarking miners/algorithm in ExtendInterval... add 10x $Config.Interval to $StatEnd, extend StatSpan, extend watchdog times
    $BenchmarkingMiner_ExtendInterval = 1
    $RunningMiners | Where-Object {$_.Speed -eq $null -and ($Config.ExtendInterval -icontains $_.Name -or ($_.Algorithm | Where-Object {$Config.ExtendInterval -icontains $_}) -or $_.BenchmarkIntervals -gt 1)}  | Foreach-Object {
        if ($_.BenchmarkIntervals -gt 1 -and $_.BenchmarkIntervals -ge $BenchmarkingMiner_ExtendInterval) {
            $BenchmarkingMiner_ExtendInterval = $_.BenchmarkIntervals
        } else {
            $BenchmarkingMiner_ExtendInterval = 10
        }
    }
    if ($BenchmarkingMiner_ExtendInterval -gt 1) {
        $StatEnd = $StatEnd.AddSeconds($Config.Interval * $BenchmarkingMiner_ExtendInterval)
        $StatSpan = New-TimeSpan $StatStart $StatEnd
        $WatchdogInterval = ($WatchdogInterval / $Strikes * ($Strikes - 1)) + $StatSpan.TotalSeconds
        $WatchdogReset = ($WatchdogReset / ($Strikes * $Strikes * $Strikes) * (($Strikes * $Strikes * $Strikes) - 1)) + $StatSpan.TotalSeconds
        Write-Log "Benchmarking watchdog sensitive algorithm or miner. Increasing interval time temporarily to $($BenchmarkingMiner_ExtendInterval)x interval ($($Config.Interval * $BenchmarkingMiner_ExtendInterval) seconds). "
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
                $Miner_Speed = $Miner.GetHashRate($_, $Interval * $BenchmarkingMiner_ExtendInterval, $Miner.New)
                $Miner.Speed_Live += [Double]$Miner_Speed

                if ($Miner.New -and (-not $Miner_Speed)) {$Miner_Speed = $Miner.GetHashRate($_, ($Interval * $Miner.Benchmarked * $BenchmarkingMiner_ExtendInterval), ($Miner.Benchmarked -lt $Strikes))}

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
Write-Log "Gracefully halting MPM"
$ActiveMiners | Where-Object {$_.GetActivateCount() -gt 0} | ForEach-Object {
    $Miner = $_
    if ($Miner.GetStatus() -eq [MinerStatus]::Running) {
        Write-Log "Closing $($Miner.Type) miner $($Miner.Name)"
        $Miner.StopMining()            
    }
}
 
#Stop the log
Stop-Transcript
