
function Write-HostSetupHints {
[cmdletbinding()]
Param(
    [Parameter(Mandatory = $False)]
    [string]$Color = "Yellow"
)
    Write-Host " "
    Write-Host "Hints (read them all! It will make entering data much easier):" -ForegroundColor $Color
    Write-Host " "
    Write-Host "- press Return to accept the defaults" -ForegroundColor $Color
    Write-Host "- fields marked with * are mandatory" -ForegroundColor $Color
    Write-Host "- use comma `",`" to separate list entries" -ForegroundColor $Color
    Write-Host "- add new entries to a list, by adding a `"+`" in front of your input" -ForegroundColor $Color
    Write-Host "- remove entries from a list, by adding a `"-`" in front of your input" -ForegroundColor $Color
    Write-Host "- enter `"list`" or `"help`" to show a list of all valid entries" -ForegroundColor $Color
    Write-Host "- enter `"back`" or `"<`" to repeat the last input" -ForegroundColor $Color
    Write-Host "- enter `"delete`" to clear a non-mandatory entry" -ForegroundColor $Color
    Write-Host "- enter `"save`" or `"done`" to end config and save changes" -ForegroundColor $Color
    Write-Host "- enter `"exit`" or `"cancel`" to abort without any changes to the configuration" -ForegroundColor $Color
    Write-Host " "
}

function Write-HostSetupDataWindowHints {
[cmdletbinding()]
Param(
    [Parameter(Mandatory = $False)]
    [string]$Color = "Cyan"
)
    Write-Host " "
    Write-Host "- estimate_current: the pool's current calculated profitability-estimation (more switching, relies on the honesty of the pool)" -ForegroundColor $Color
    Write-Host "- estimate_last24h: the pool's calculated profitability-estimation for the past 24 hours (less switching, relies on the honesty of the pool)" -ForegroundColor $Color
    Write-Host "- actual_last24h: the actual profitability over the past 24 hours (less switching)" -ForegroundColor $Color
    Write-Host "- mininum (or minimum-2): the minimum value of estimate_current and actual_last24h will be used" -ForegroundColor $Color
    Write-Host "- maximum (or maximum-2): the maximum value of estimate_current and actual_last24h will be used" -ForegroundColor $Color
    Write-Host "- average (or average-2): the calculated average of estimate_current and actual_last24h will be used" -ForegroundColor $Color
    Write-Host "- mininume (or minimum-2e): the minimum value of estimate_current and estimate_last24h will be used" -ForegroundColor $Color
    Write-Host "- maximume (or maximum-2e): the maximum value of estimate_current and estimate_last24h will be used" -ForegroundColor $Color
    Write-Host "- averagee (or average-2e): the calculated average of estimate_current and estimate_last24h will be used" -ForegroundColor $Color
    Write-Host "- mininumh (or minimum-2h): the minimum value of estimate_last24h and actual_last24h will be used" -ForegroundColor $Color
    Write-Host "- maximumh (or maximum-2h): the maximum value of estimate_last24h and actual_last24h will be used" -ForegroundColor $Color
    Write-Host "- averageh (or average-2h): the calculated average of estimate_last24h and actual_last24h will be used" -ForegroundColor $Color
    Write-Host "- mininumall (or minimum-3): the minimum value of the above three values will be used" -ForegroundColor $Color
    Write-Host "- maximumall (or maximum-3): the maximum value of the above three values will be used" -ForegroundColor $Color
    Write-Host "- averageall (or average-3): the calculated average of the above three values will be used" -ForegroundColor $Color
    Write-Host " "
}

function Write-HostSetupStatAverageHints {
[cmdletbinding()]
Param(
    [Parameter(Mandatory = $False)]
    [string]$Color = "Cyan"
)
    Write-Host " "
    Write-Host "- Live: live pool price" -ForegroundColor $Color
    Write-Host "- Minute_5: five minutes moving average" -ForegroundColor $Color
    Write-Host "- Minute_10: ten minutes moving average" -ForegroundColor $Color
    Write-Host "- Hour: one hour moving average" -ForegroundColor $Color
    Write-Host "- Day: one day moving average" -ForegroundColor $Color
    Write-Host "- ThreeDay: three day moving average" -ForegroundColor $Color
    Write-Host "- Week: one week moving average" -ForegroundColor $Color
    Write-Host " "
}

function Start-Setup {
    [CmdletBinding()]
    param(
        [Parameter(Mandatory = $true)]
        [PSCustomObject]$Config,
        [Parameter(Mandatory = $true)]
        [hashtable]$ConfigFiles,
        [Parameter(Mandatory = $false)]
        [Switch]$SetupOnly = $false
    )

    $RunSetup = $true

    [System.Collections.ArrayList]$SetupMessage = @()

    do {
        $ConfigActual = Get-Content $ConfigFiles["Config"].Path | ConvertFrom-Json
        $MinersActual = Get-Content $ConfigFiles["Miners"].Path | ConvertFrom-Json
        $PoolsActual = Get-Content $ConfigFiles["Pools"].Path | ConvertFrom-Json
        $DevicesActual = Get-Content $ConfigFiles["Devices"].Path | ConvertFrom-Json
        $OCProfilesActual = Get-Content $ConfigFiles["OCProfiles"].Path | ConvertFrom-Json
        $SetupDevices = Get-Device "nvidia","amd","cpu" -IgnoreOpenCL

        $PoolsSetup  = Get-ChildItemContent ".\Data\PoolsConfigDefault.ps1" | Select-Object -ExpandProperty Content

        $AlgorithmsDefault = [PSCustomObject]@{Penalty = "0";MinHashrate = "0";MinWorkers = "0";MaxTimeToFind = "0";MSIAprofile = "0";OCprofile = ""}
        $CoinsDefault      = [PSCustomObject]@{Penalty = "0";MinHashrate = "0";MinWorkers = "0";MaxTimeToFind="0";Wallet="";EnableAutoPool="0";PostBlockMining="0";MinProfitPercent="0";Comment=""}
        $MRRDefault        = [PSCustomObject]@{PriceBTC = "0";PriceFactor = "0";EnableAutoCreate = "1";EnablePriceUpdates = "1";EnableAutoPrice = "1";EnableMinimumPrice = "1";Title="";Description=""}
        $PoolsDefault      = [PSCustomObject]@{Worker = "`$WorkerName";Penalty = 0;Algorithm = "";ExcludeAlgorithm = "";CoinName = "";ExcludeCoin = "";CoinSymbol = "";ExcludeCoinSymbol = "";MinerName = "";ExcludeMinerName = "";FocusWallet = "";AllowZero = "0";EnableAutoCoin = "0";EnablePostBlockMining = "0";CoinSymbolPBM = "";DataWindow = "";StatAverage = ""}

        $Controls = @("cancel","exit","back","save","done","<")

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

        try {
            $TotalMem = (($Session.AllDevices | Where-Object {$_.Type -eq "Gpu" -and @("amd","nvidia") -icontains $_.Vendor}).OpenCl.GlobalMemSize | Measure-Object -Sum).Sum / 1GB
            if ($IsWindows) {$TotalSwap = (Get-CimInstance Win32_PageFile | Select-Object -ExpandProperty FileSize | Measure-Object -Sum).Sum / 1GB}
            if ($TotalSwap -and $TotalMem -gt $TotalSwap) {
                Write-Log -Level Warn "You should increase your windows pagefile to at least $TotalMem GB"
                Write-Host " "
            }
        } catch {}

        $IsInitialSetup = -not $Config.Wallet -or -not $Config.WorkerName

        $DefaultWorkerName = $Session.MachineName -replace "[^A-Z0-9]+"

        if ($IsInitialSetup) {
            $SetupType = "A" 

            $ConfigSetup = Get-ChildItemContent ".\Data\ConfigDefault.ps1" | Select-Object -ExpandProperty Content

            if ((Test-Path ".\setup.json") -and ($SetupJson = Get-Content ".\setup.json" -Raw -ErrorAction Ignore | ConvertFrom-Json -ErrorAction Ignore)) {

                Write-Host "The following data has been found in .\setup.json:" -ForegroundColor Yellow
                Write-Host " "
                $p = [console]::ForegroundColor
                [console]::ForegroundColor = "Cyan"
                $SetupJsonFields = @($SetupJson.PSObject.Properties.Name | Where-Object {$ConfigFiles[$_].Path} | Sort-Object)
                $SetupJsonFields | Foreach-Object {$_}
                [console]::ForegroundColor = $p
                Write-Host " "

                $DoSetupConfigs = @()

                if (Get-Yes $SetupJson.Autostart.Enable) {
                    if (-not $ConfigActual -or $ConfigActual -is [string]) {$ConfigActual = [PSCustomObject]@{}}
                    $DoSetupConfigs = if ($SetupJson.Autostart.ConfigName) {@(Get-ConfigArray $SetupJson.Autostart.ConfigName -Characters "A-Z")} else {@("All")}
                    $DoSetupDevices = if ($SetupJson.Autostart.DeviceName) {@(Get-ConfigArray $SetupJson.Autostart.DeviceName)} else {@()}
                    $ConfigActual | Add-Member WorkerName "$(if ($SetupJson.Autostart.WorkerName) {$SetupJson.Autostart.WorkerName} else {$DefaultWorkerName})" -Force
                    $ConfigActual | Add-Member DeviceName "$($DoSetupDevices -join ",")" -Force
                    Write-Host
                    Write-Host "Autostarting with the following values" -BackgroundColor Yellow -ForegroundColor Black
                    Write-Host " "
                    Write-Host "WorkerName = $($ConfigActual.WorkerName)" -ForegroundColor Yellow
                    Write-Host "DeviceName = $($ConfigActual.DeviceName)" -ForegroundColor Yellow
                    Write-Host "ConfigName = $($DoSetupConfigs -join ",")" -ForegroundColor Yellow
                    Write-Host " "
                }

                if (-not ($DoSetupConfigs | Measure-Object).Count) {
                    $DoSetupConfigs = Read-HostArray "Choose, which parts to import (enter `"All`" for complete, or leave empty to start normal setup) " -Valid (@("All")+$SetupJsonFields) -Characters "A-Z"
                }

                if (($DoSetupConfigs | Measure-Object).Count) {
                    $SetupJson.PSObject.Properties | Where-Object {$ConfigFiles[$_.Name].Path} | Where-Object {$DoSetupConfigs -icontains $_.Name -or $DoSetupConfigs -icontains "All"} | Foreach-Object {
                        if ($_.Name -eq "Config") {
                            if (-not $ConfigActual -or $ConfigActual -is [string]) {$ConfigActual = [PSCustomObject]@{}}
                            $_.Value.PSObject.Properties | Where-Object {$SetupJson.Exclude -inotcontains $_.Name} | Foreach-Object {
                                $ConfigActual | Add-Member $_.Name $_.Value -Force
                            }
                            $ConfigSetup.PSObject.Properties | Where-Object Membertype -eq NoteProperty | Select-Object Name,Value | Foreach-Object {
                                $ConfigSetup_Name = $_.Name
                                $val = $_.Value
                                if ($val -is [array]) {$val = $val -join ','}
                                if ($val -is [bool])  {$val = if ($val) {"1"} else {"0"}}
                                if (-not $ConfigActual.$ConfigSetup_Name -or $ConfigActual.$ConfigSetup_Name -eq "`$$ConfigSetup_Name") {$ConfigActual | Add-Member $ConfigSetup_Name $val -Force}
                            }
                            $WorkerName = $ConfigActual.WorkerName
                            if (-not $WorkerName -or $WorkerName -eq "`$WorkerName") {
                                do {
                                    $WorkerName = Read-HostString -Prompt "Enter your worker's name" -Default $DefaultWorkerName -Mandatory -Characters "A-Z0-9"
                                } until ($WorkerName)
                            }
                            if ($WorkerName -ne "exit") {
                                $ConfigActual | Add-Member WorkerName $WorkerName -Force
                                Set-ContentJson -PathToFile $ConfigFiles["Config"].Path -Data $ConfigActual > $null
                                if ($ConfigActual.Wallet -and $ConfigActual.WorkerName -and $ConfigActual.Wallet -ne "`$Wallet" -and $ConfigActual.WorkerName -ne "`$WorkerName") {
                                    $SetupType = "X"
                                }
                            }
                        } else {
                            Set-ContentJson -PathToFile $ConfigFiles[$_.Name].Path -Data $_.Value > $null
                            Set-Variable -Name "$($_.Name)Actual" -Value $_.Value
                        }
                    }
                }
            }

            $ConfigSetup.PSObject.Properties | Where-Object Membertype -eq NoteProperty | Select-Object Name,Value | Foreach-Object {
                $ConfigSetup_Name = $_.Name
                $val = $_.Value
                if ($val -is [array]) {$val = $val -join ','}
                if ($val -is [bool] -or -not $Config.$ConfigSetup_Name) {$Config | Add-Member $ConfigSetup_Name $val -Force}
            }
            if (($Session.AllDevices | Where-Object Vendor -eq "AMD" | Measure-Object).Count -eq 0) {
                $Config | Add-Member DisableMSIAmonitor $true -Force
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
            Write-Host "- Algorithms: finetune global settings for algorithms, penalty, minimum hasrate and more" -ForegroundColor Yellow
            Write-Host "- Coins: finetune global settings for dedicated coins, wallets, penalty, minimum hasrate and more" -ForegroundColor Yellow
            Write-Host "- OC-Profiles: create or edit overclocking profiles" -ForegroundColor Yellow
            Write-Host "- Network: API and client/server setup for multiple rigs within one network" -ForegroundColor Yellow
            Write-Host "- Scheduler: different power prices and selective pause for timespans" -ForegroundColor Yellow
            Write-Host " "
            if (-not $Config.Wallet -or -not $Config.WorkerName -or -not $Config.PoolName) {
                Write-Host " WARNING: without the following data, RainbowMiner is not able to start mining. " -BackgroundColor Yellow -ForegroundColor Black
                if (-not $Config.Wallet)     {Write-Host "- No BTC-wallet defined! Please go to [W]allets and input your wallet! " -ForegroundColor Yellow}
                if (-not $Config.WorkerName) {Write-Host "- No workername defined! Please go to [W]allets and input a workername! " -ForegroundColor Yellow}
                if (-not $Config.PoolName)   {Write-Host "- No pool selected! Please go to [S]elections and add some pools! " -ForegroundColor Yellow}            
                Write-Host " "
            }
            $SetupType = Read-HostString -Prompt "$(if ($SetupOnly) {"Wi[z]ard, "})[W]allets, [C]ommon, [E]nergycosts, [S]elections, [A]ll, [M]iners, [P]ools, [D]evices, A[l]gorithms, Co[i]ns, [O]C-Profiles, $(if ($Config.PoolName -icontains "MiningRigRentals") {"M[r]r, "})[N]etwork, Sc[h]eduler, E[x]it $(if ($SetupOnly) {"setup"} else {"configuration and start mining"})" -Default "X"  -Mandatory -Characters "ZWCESAMPDLIONRHX"
        }

        if ($SetupType -eq "Z") {$IsInitialSetup = $true;$SetupType = "A"}

        if ($SetupType -eq "X") {
            $RunSetup = $false
        }
        elseif (@("W","C","E","S","A","N") -contains $SetupType) {
                            
            $GlobalSetupDone = $false
            $GlobalSetupStep = 0
            [System.Collections.ArrayList]$GlobalSetupSteps = @()
            [System.Collections.ArrayList]$GlobalSetupStepBack = @()
            $DownloadServerNow = $false

            Switch ($SetupType) {
                "W" {$GlobalSetupName = "Wallet";$GlobalSetupSteps.AddRange(@("wallet","nicehash","nicehash2","nicehashorganizationid","nicehashapikey","nicehashapisecret","mph","mphapiid","mphapikey","mrr","mrrapikey","mrrapisecret")) > $null}
                "C" {$GlobalSetupName = "Common";$GlobalSetupSteps.AddRange(@("workername","miningmode","devicename","excludedevicename","devicenameend","cpuminingthreads","cpuminingaffinity","gpuminingaffinity","pooldatawindow","enableerrorratio","poolstataverage","hashrateweight","hashrateweightstrength","poolaccuracyweight","defaultpoolregion","region","currency","enableminerstatus","minerstatusurl","minerstatuskey","minerstatusemail","pushoveruserkey","minerstatusmaxtemp","uistyle","fastestmineronly","showpoolbalances","showpoolbalancesdetails","showpoolbalancesexcludedpools","enableheatmyflat","enablealgorithmmapping","showminerwindow","ignorefees","enableocprofiles","enableocvoltage","enableresetvega","msia","msiapath","nvsmipath","ethpillenable","ethpillenablemtp","enableautominerports","enableautoupdate","enableautoalgorithmadd","enableautobenchmark")) > $null}
                "E" {$GlobalSetupName = "Energycost";$GlobalSetupSteps.AddRange(@("powerpricecurrency","powerprice","poweroffset","usepowerprice","checkprofitability")) > $null}
                "S" {$GlobalSetupName = "Selection";$GlobalSetupSteps.AddRange(@("poolname","poolnamenh1","poolnamenh2","minername","excludeminername","excludeminerswithfee","disabledualmining","enablecheckminingconflict","algorithm","excludealgorithm","disableunprofitablealgolist","excludecoinsymbol","excludecoin")) > $null}
                "N" {$GlobalSetupName = "Network";$GlobalSetupSteps.AddRange(@("runmode","apiport","apiinit","apiauth","apiuser","apipassword","serverinit","serverinit2","servername","serverport","serveruser","serverpassword","clientconnect","enableserverconfig","groupname","serverconfigname","excludeserverconfigvars1","excludeserverconfigvars2","clientinit")) > $null}
                "A" {$GlobalSetupName = "All";$GlobalSetupSteps.AddRange(@("startsetup","workername","runmode","apiport","apiinit","apiauth","apiuser","apipassword","serverinit","serverinit2","servername","serverport","serveruser","serverpassword","clientconnect","enableserverconfig","groupname","serverconfigname","excludeserverconfigvars1","excludeserverconfigvars2","clientinit","wallet","nicehash","nicehash2","nicehashorganizationid","nicehashapikey","nicehashapisecret","addcoins1","addcoins2","addcoins3","mph","mphapiid","mphapikey","mrr","mrrapikey","mrrapisecret","region","currency","benchmarkintervalsetup","enableminerstatus","minerstatusurl","minerstatuskey","minerstatusemail","pushoveruserkey","minerstatusmaxtemp","enableautominerports","enableautoupdate","enableautoalgorithmadd","enableautobenchmark","poolname","poolnamenh1","poolnamenh2","autoaddcoins","minername","excludeminername","algorithm","excludealgorithm","disableunprofitablealgolist","excludecoinsymbol","excludecoin","disabledualmining","excludeminerswithfee","enablecheckminingconflict","devicenamebegin","miningmode","devicename","excludedevicename","devicenamewizard","devicenamewizardgpu","devicenamewizardamd1","devicenamewizardamd2","devicenamewizardnvidia1","devicenamewizardnvidia2","devicenamewizardcpu1","devicenamewizardend","devicenameend","cpuminingthreads","cpuminingaffinity","gpuminingaffinity","pooldatawindow","enableerrorratio","poolstataverage","hashrateweight","hashrateweightstrength","poolaccuracyweight","defaultpoolregion","uistyle","fastestmineronly","showpoolbalances","showpoolbalancesdetails","showpoolbalancesexcludedpools","enableheatmyflat","enablealgorithmmapping","showminerwindow","ignorefees","watchdog","enableocprofiles","enableocvoltage","enableresetvega","msia","msiapath","nvsmipath","ethpillenable","ethpillenablemtp","proxy","delay","interval","benchmarkinterval","minimumminingintervals","disableextendinterval","switchingprevention","maxrejectedshareratio","mincombooversingleratio","enablefastswitching","disablemsiamonitor","disableapi","disableasyncloader","usetimesync","miningprioritycpu","miningprioritygpu","autoexecpriority","powerpricecurrency","powerprice","poweroffset","usepowerprice","checkprofitability","quickstart","startpaused","loglevel","donate")) > $null}
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
                $NicehashPlatform = $PoolsActual.Nicehash.Platform
                $NicehashOrganizationID = $PoolsActual.Nicehash.OrganizationID
                $NicehashAPIKey = $PoolsActual.Nicehash.API_Key
                $NicehashAPISecret = $PoolsActual.Nicehash.API_Secret
            } else {
                $NicehashWallet = "`$Wallet"
                $NicehashPlatform = "v2"
                $NicehashOrganizationID = ""
                $NicehashAPIKey = ""
                $NicehashAPISecret = ""
            }

            if ($PoolsActual | Get-Member NicehashV2 -MemberType NoteProperty) {
                $NicehashV2Wallet = $PoolsActual.NicehashV2.BTC
                $NicehashV2OrganizationID = $PoolsActual.NicehashV2.OrganizationID
                $NicehashV2APIKey = $PoolsActual.NicehashV2.API_Key
                $NicehashV2APISecret = $PoolsActual.NicehashV2.API_Secret
            } else {
                $NicehashV2Wallet = "`$Wallet"
                $NicehashV2OrganizationID = ""
                $NicehashV2APIKey = ""
                $NicehashV2APISecret = ""
            }

            if ($PoolsActual | Get-Member MiningPoolHub -MemberType NoteProperty) {
                $MPHUser        = $PoolsActual.MiningPoolHub.User
                $MPHAPIID       = $PoolsActual.MiningPoolHub.API_ID
                $MPHAPIKey      = $PoolsActual.MiningPoolHub.API_Key
            } else {
                $MPHUser        = ""
                $MPHAPIID       = ""
                $MPHAPIKey      = ""
            }

            if ($PoolsActual | Get-Member MiningPoolHubCoins -MemberType NoteProperty) {
                if (-not $MPHUser)   {$MPHUser   = $PoolsActual.MiningPoolHubCoins.User}
                if (-not $MPHAPIID)  {$MPHAPIID  = $PoolsActual.MiningPoolHubCoins.API_ID}
                if (-not $MPHAPIKey) {$MPHAPIKey = $PoolsActual.MiningPoolHubCoins.API_Key}
            }

            if ($PoolsActual | Get-Member MiningRigRentals -MemberType NoteProperty) {
                $MRRUser        = $PoolsActual.MiningRigRentals.User
                $MRRAPIKey      = $PoolsActual.MiningRigRentals.API_Key
                $MRRAPISecret   = $PoolsActual.MiningRigRentals.API_Secret
            } else {
                $MRRUser        = ""
                $MRRAPIKey      = ""
                $MRRAPISecret   = ""
            }

            $CoinsAdded = @()
            $AutoAddCoins = $IsInitialSetup

            do {
                $GlobalSetupStepStore = $true
                try {
                    Switch ($GlobalSetupSteps[$GlobalSetupStep]) {
                        "startsetup" {
                            # Start setup procedure
                            Write-Host ' '
                            Write-Host '(1) Basic Setup' -ForegroundColor Green
                            Write-Host ' '

                            $GlobalSetupStepStore = $false
                        }

                        "wallet" {                                                                             
                            if ($IsInitialSetup) {
                                Write-Host " "
                                Write-Host "Please lookup your BTC wallet address. It is easy: copy it to your clipboard and then press the right mouse key in this window to paste" -ForegroundColor Cyan
                                Write-Host " "
                            }
                            $Config.Wallet = Read-HostString -Prompt "Enter your BTC wallet address" -Default $Config.Wallet -Length 34 -Mandatory -Characters "A-Z0-9" | Foreach-Object {if ($Controls -icontains $_) {throw $_};$_}
                        }

                        "addcoins1" {
                            if ($IsInitialSetup) {
                                Write-Host " "
                                Write-Host "Now is your chance to add other currency wallets (e.g. enter XWP for Swap)" -ForegroundColor Cyan
                                Write-Host " "
                            }
                            $addcoins = Read-HostBool -Prompt "Do you want to add/edit $(if ($CoinsAdded.Count) {"another "})wallet addresses of non-BTC currencies?" -Default $false | Foreach-Object {if ($Controls -icontains $_) {throw $_};$_}
                        }

                        "addcoins2" {
                            if ($addcoins) {
                                $CoinsActual = Get-Content $ConfigFiles["Coins"].Path | ConvertFrom-Json
                                $addcoin = Read-HostString -Prompt "Which currency do you want to add/edit (leave empty for none) " -Default "" -Valid (Get-PoolsInfo "Currency") | Foreach-Object {if ($Controls -icontains $_) {throw $_};$_}
                                if (-not $CoinsActual.$addcoin) {
                                    $CoinsActual | Add-Member $addcoin ($CoinsDefault | ConvertTo-Json | ConvertFrom-Json) -Force
                                }
                            } else {
                                $GlobalSetupStepStore = $false
                            }
                        }

                        "addcoins3" {
                            if ($addcoins -and $addcoin) {
                                $CoinsActual.$addcoin.Wallet = Read-HostString -Prompt "Enter your $($addcoin) wallet address " -Default $CoinsActual.$addcoin.Wallet -Characters "A-Z0-9-\._~:/\?#\[\]@!\$&'\(\)\*\+,;=" | Foreach-Object {if ($Controls -icontains $_) {throw $_};$_}
                                $CoinsActual.$addcoin.Wallet = $CoinsActual.$addcoin.Wallet.Trim()
                                $CoinsActual.$addcoin | Add-Member EnableAutoPool "1" -Force
                                $CoinsActualSave = [PSCustomObject]@{}
                                $CoinsActual.PSObject.Properties.Name | Sort-Object | Foreach-Object {$CoinsActualSave | Add-Member $_ ($CoinsActual.$_) -Force}
                                Set-ContentJson -PathToFile $ConfigFiles["Coins"].Path -Data $CoinsActualSave > $null
                                $CoinsAdded += $addcoin
                                $CoinsAdded = $CoinsAdded | Select-Object -Unique | Sort-Object
                                throw "Goto addcoins1"
                            } else {
                                $GlobalSetupStepStore = $false
                            }
                        }

                        "nicehash" {
                            if ($IsInitialSetup) {
                                Write-Host " "
                                Write-Host "If you plan to mine on Nicehash, you need to register an account with them, to get a NiceHash mining wallet address (please read the Pools section of our readme!). " -ForegroundColor Cyan
                                Write-Host "If you do not want to use Nicehash as a pool, leave this empty (or enter `"clear`" to make it empty) and press return " -ForegroundColor Cyan
                                Write-Host " "
                            }

                            if ($NicehashWallet -eq "`$Wallet"){$NicehashWallet=$Config.Wallet}
                            $NicehashWallet = Read-HostString -Prompt "Enter your NiceHash BTC mining wallet address" -Default $NicehashWallet -Length 34 -Characters "A-Z0-9" | Foreach-Object {if ($Controls -icontains $_) {throw $_};$_}
                        }
                        "nicehash2" {
                            if ($NiceHashWallet -eq "`$Wallet" -or $NiceHashWallet -eq $Config.Wallet) {
                                if (Read-HostBool "You have entered your default wallet as Nicehash wallet. Do you want to disable NiceHash mining for now? (Or enter `"<`" to return to the wallet query)" -Default $false | Foreach-Object {if ($Controls -icontains $_) {throw $_};$_}) {
                                    $NiceHashWallet = ''
                                }
                            } else {
                                $GlobalSetupStepStore = $false
                            }

                            $PoolNames = @(Get-ConfigArray $Config.PoolName)
                            if (-not $NicehashWallet) {
                                $PoolNames = $PoolNames | Where-Object {$_ -ne "NiceHash"}
                                $NicehashWallet = "`$Wallet"
                            } elseif ($PoolNames -inotcontains "NiceHash") {
                                $PoolNames += $PoolNames
                            }
                            $Config.PoolName = ($PoolNames | Select-Object -Unique | Sort-Object) -join ','
                        }

                        "nicehashorganizationid" {
                            $PoolNames = @(Get-ConfigArray $Config.PoolName)
                            if ($false -and $PoolNames -icontains "NiceHash" -and $NicehashPlatform -in @("2","v2","new")) {
                                if ($IsInitialSetup) {
                                    Write-Host " "
                                    Write-Host "You will mine on Nicehash. If you want to see your balance in RainbowMiner, you can now enter your API Key and the API Secret. Create a new key-pair on `"My Settings->API key`" page, `"Wallet permission`" needs to be set. " -ForegroundColor Cyan
                                    Write-Host " "
                                }
                                $NicehashOrganizationID = Read-HostString -Prompt "Enter your Nicehash Organization Id (found on `"My Settings->API key`", enter including all '-')" -Default $NicehashOrganizationID -Characters "0-9a-f-" | Foreach-Object {if ($Controls -icontains $_) {throw $_};$_}
                            } else {
                                $GlobalSetupStepStore = $false
                            }
                        }

                        "nicehashapikey" {
                            $PoolNames = @(Get-ConfigArray $Config.PoolName)
                            if ($PoolNames -icontains "NiceHash") {
                                if ($NicehashPlatform -notin @("2","v2","new")) {
                                    $NicehashAPIKey = Read-HostString -Prompt "Enter your Nicehash API Key (found on `"Settings`" page, enter including all '-')" -Default $NicehashAPIKey -Characters "0-9a-f-" | Foreach-Object {if ($Controls -icontains $_) {throw $_};$_}
                                } else {
                                    #$NicehashAPIKey = Read-HostString -Prompt "Enter your Nicehash API Key (create a key pair on `"My Settings->API key`", enter including all '-')" -Default $NicehashAPIKey -Characters "0-9a-f-" | Foreach-Object {if ($Controls -icontains $_) {throw $_};$_}
                                    $GlobalSetupStepStore = $false
                                }
                            } else {
                                $GlobalSetupStepStore = $false
                            }
                        }

                        "nicehashapisecret" {
                            $PoolNames = @(Get-ConfigArray $Config.PoolName)
                            if ($false -and $PoolNames -icontains "NiceHash" -and $NicehashPlatform -in @("2","v2","new")) {
                                $NicehashAPISecret = Read-HostString -Prompt "Enter your Nicehash API Secret (enter including all '-')" -Default $NicehashAPISecret -Characters "0-9a-f-" | Foreach-Object {if ($Controls -icontains $_) {throw $_};$_}
                            } else {
                                $GlobalSetupStepStore = $false
                            }
                        }

                        "workername" {
                            if ($IsInitialSetup) {
                                Write-Host " "
                                Write-Host "Every pool (except the MiningPoolHub) wants the miner to send a worker's name. You can change the name later. Please enter only letters and numbers. " -ForegroundColor Cyan
                                Write-Host " "
                            }
                            $Config.WorkerName = Read-HostString -Prompt "Enter your worker's name" -Default $Config.WorkerName -Mandatory -Characters "A-Z0-9" | Foreach-Object {if ($Controls -icontains $_) {throw $_};$_}
                        }

                        "mph" {
                            if ($IsInitialSetup) {
                                Write-Host " "
                                Write-Host "If you plan to use MiningPoolHub for mining, you will have to register an account with them and choose a username. Enter this username now, or leave empty to disable MiningPoolHub (can be activated, later) " -ForegroundColor Cyan
                                Write-Host " "
                            }
                            $MPHUser = Read-HostString -Prompt "Enter your Miningpoolhub user name" -Default $MPHUser -Characters "A-Z0-9" | Foreach-Object {if ($Controls -icontains $_) {throw $_};$_}

                            $PoolNames = @(Get-ConfigArray $Config.PoolName)
                            if (-not $MPHUser) {
                                $PoolNames = $PoolNames | Where-Object {$_ -notmatch "MiningPoolHub"}
                            } else {
                                if ($PoolNames -inotcontains "MiningPoolHub") {$PoolNames += "MiningPoolHub"}
                                if ($PoolNames -inotcontains "MiningPoolHubCoins") {$PoolNames += "MiningPoolHubCoins"}
                            }
                            $Config.PoolName = ($PoolNames | Select-Object -Unique | Sort-Object) -join ','
                        }

                        "mphapiid" {
                            $PoolNames = @(Get-ConfigArray $Config.PoolName)
                            if ($PoolNames -match "MiningPoolHub") {
                                if ($IsInitialSetup) {
                                    Write-Host " "
                                    Write-Host "You will mine on MiningPoolHub as $($MPHUser). If you want to see your balance in RainbowMiner, you can now enter your USER ID (a number) and the API KEY. You find these two values on MiningPoolHub's `"Edit account`" page. " -ForegroundColor Cyan
                                    Write-Host " "
                                }
                                $MPHApiID = Read-HostString -Prompt "Enter your Miningpoolhub USER ID (found on `"Edit account`" page)" -Default $MPHApiID -Characters "0-9" | Foreach-Object {if ($Controls -icontains $_) {throw $_};$_}
                            } else {
                                $GlobalSetupStepStore = $false
                            }
                        }

                        "mphapikey" {
                            $PoolNames = @(Get-ConfigArray $Config.PoolName)
                            if ($PoolNames -match "MiningPoolHub") {
                                $MPHApiKey = Read-HostString -Prompt "Enter your Miningpoolhub API KEY (found on `"Edit account`" page)" -Default $MPHApiKey -Characters "0-9a-f" | Foreach-Object {if ($Controls -icontains $_) {throw $_};$_}
                            } else {
                                $GlobalSetupStepStore = $false
                            }
                        }

                        "mrr" {
                            if ($IsInitialSetup) {
                                Write-Host " "
                                Write-Host "If you plan to offer your rig for rent at MiningRigRentals, you will have to register an account with them and choose a username. Enter this username now, or leave empty to disable MiningRigRentals (can be activated, later) " -ForegroundColor Cyan
                                Write-Host " "
                            }
                            $MRRUser = Read-HostString -Prompt "Enter your MiningRigRentals user name" -Default $MRRUser -Characters "A-Z0-9" | Foreach-Object {if ($Controls -icontains $_) {throw $_};$_}

                            $PoolNames = @(Get-ConfigArray $Config.PoolName)
                            if (-not $MRRUser) {
                                $PoolNames = $PoolNames | Where-Object {$_ -notmatch "MiningRigRentals"}
                            } elseif ($PoolNames -inotcontains "MiningRigRentals") {
                                $PoolNames += "MiningRigRentals"
                            }
                            $Config.PoolName = ($PoolNames | Select-Object -Unique | Sort-Object) -join ','
                        }

                        "mrrapikey" {
                            $PoolNames = @(Get-ConfigArray $Config.PoolName)
                            if ($PoolNames -match "MiningRigRentals") {
                                if ($IsInitialSetup) {
                                    Write-Host " "
                                    Write-Host "To offer your rig at MRR, you will need an API Key and Secret (each rig should have it's own). Create each pair on MiningRigRentals's `"</> API Keys`" page. " -ForegroundColor Cyan
                                    Write-Host " "
                                }
                                $MRRApiKey = Read-HostString -Prompt "Enter your MiningRigRentals API Key (create on MRR's `"</> API Keys`" page)" -Default $MRRApiKey -Characters "0-9a-f" | Foreach-Object {if ($Controls -icontains $_) {throw $_};$_}
                            } else {
                                $GlobalSetupStepStore = $false
                            }
                        }

                        "mrrapisecret" {
                            $PoolNames = @(Get-ConfigArray $Config.PoolName)
                            if ($PoolNames -match "MiningRigRentals") {
                                $MRRApiSecret = Read-HostString -Prompt "Enter your MiningRigRentals API Secret (create on MRR's `"</> API Keys`" page)" -Default $MRRApiSecret -Characters "0-9a-f" | Foreach-Object {if ($Controls -icontains $_) {throw $_};$_}
                            } else {
                                $GlobalSetupStepStore = $false
                            }
                        }

                        "region" {
                            $Regions = Get-Regions -AsHash
                            Write-Host " "
                            Write-Host "Choose the region, that is nearest to your rigs (remember: you can always simply accept the default by pressing return): " -ForegroundColor Cyan
                            $p = [console]::ForegroundColor
                            [console]::ForegroundColor = "Cyan"
                            $Regions.Keys | Foreach-Object {[PSCustomObject]@{Name=$Regions.$_;Value=$_}} | Group-Object -Property Name | Sort-Object Name | Format-Table @{Name="Region";Expression={$_.Name}},@{Name="Valid shortcuts/entries";Expression={"$(($_.Group.Value | Sort-Object) -join ", ")"}}
                            [console]::ForegroundColor = $p
                            Write-Host " "
                            $Config.Region = Read-HostString -Prompt "Enter your region" -Default $Config.Region -Mandatory -Characters "A-Z" -Valid ($Regions.Keys + $Regions.Values | Foreach-Object {$_.ToLower()} | Select-Object -Unique | Sort-Object) | Foreach-Object {if ($Controls -icontains $_) {throw $_};$_}
                        }
                        "enableminerstatus" {
                            if ($IsInitialSetup) {
                                Write-Host " "
                                Write-Host "RainbowMiner can track this and all of your rig's status at https://rbminer.net (or another compatible service) " -ForegroundColor Cyan
                                Write-Host "If you enable this feature, you may enter an existing miner status key or create a new one. " -ForegroundColor Cyan
                                Write-Host "It is possible to enter an email address or a https://pushover.net user key to be notified in case your rig is offline. " -ForegroundColor Cyan
                                Write-Host " "
                            }
                            $Config.EnableMinerStatus = Read-HostBool -Prompt "Do you want to enable central monitoring?" -Default $Config.EnableMinerStatus | Foreach-Object {if ($Controls -icontains $_) {throw $_};$_}
                        }
                        "minerstatusurl" {
                            if (Get-Yes $Config.EnableMinerStatus) {
                                $Config.MinerStatusURL = Read-HostString -Prompt "Enter the miner monitoring url" -Default $Config.MinerStatusUrl -Characters "A-Z0-9-\._~:/\?#\[\]@!\$&'\(\)\*\+,;=" | Foreach-Object {if ($Controls -icontains $_) {throw $_};$_}
                            } else {
                                $GlobalSetupStepStore = $false
                            }
                        }
                        "minerstatuskey" {
                            if (Get-Yes $Config.EnableMinerStatus) {
                                $Config.MinerStatusKey = Read-HostString -Prompt "Enter your miner monitoring status key (or enter `"new`" to create one)" -Default $Config.MinerStatusKey -Characters "nwA-F0-9-" | Foreach-Object {if ($Controls -icontains $_) {throw $_};$_}
                                $Config.MinerStatusKey = $Config.MinerStatusKey.Trim()
                                if ($Config.MinerStatusKey -eq "new" -or $Config.MinerStatusKey -eq "") {
                                    $Config.MinerStatusKey = Get-MinerStatusKey
                                    if ($Config.MinerStatusKey -ne "") {
                                        Write-Host "A new miner status key has been created: " -ForegroundColor Cyan                                        
                                        Write-Host $Config.MinerStatusKey -ForegroundColor Yellow
                                        Write-Host "Copy and save or write this down, to access your stats at $($Config.MinerStatusUrl)" -ForegroundColor Cyan
                                        Write-Host "Do not forget to save your changes, or the key will not be stored into your config." -ForegroundColor Cyan
                                        Write-Host " "
                                    }
                                }
                            } else {
                                $GlobalSetupStepStore = $false
                            }
                        }
                        "minerstatusemail" {
                            if (Get-Yes $Config.EnableMinerStatus) {
                                $Config.MinerStatusEmail = Read-HostString -Prompt "Enter a offline notification eMail ($(if ($Config.MinerStatusEmail) {"clear"} else {"leave empty"}) to disable)" -Default $Config.MinerStatusEmail -Characters "A-Z0-9-\._~:/\?#\[\]@!\$&'\(\)\*\+,;=" | Foreach-Object {if ($Controls -icontains $_) {throw $_};$_}
                            } else {
                                $GlobalSetupStepStore = $false
                            }
                        }
                        "pushoveruserkey" {
                            if (Get-Yes $Config.EnableMinerStatus) {
                                $Config.PushOverUserKey = Read-HostString -Prompt "Enter your https://pushover.net user key ($(if ($Config.PushOverUserKey) {"clear"} else {"leave empty"}) to disable)" -Default $Config.PushOverUserKey -Characters "A-Z0-9" -MinLength 30 -MaxLength 30 | Foreach-Object {if ($Controls -icontains $_) {throw $_};$_}
                            } else {
                                $GlobalSetupStepStore = $false
                            }
                        }
                        "minerstatusmaxtemp" {
                            if (Get-Yes $Config.EnableMinerStatus) {
                                $Config.MinerStatusMaxTemp = Read-HostDouble -Prompt "Enter max. GPU temperature. If temp. rises above that value, a notification is being triggered" -Default $Config.MinerStatusMaxTemp -Min 0 -Max 100 | Foreach-Object {if ($Controls -icontains $_) {throw $_};$_}
                            } else {
                                $GlobalSetupStepStore = $false
                            }
                        }
                        "apiport" {
                            if ($IsInitialSetup) {
                                Write-Host " "
                                if ($Config.RunMode -eq "server") {
                                    Write-Host "All clients will be connected to this machines API port. Please write it down!" -ForegroundColor Cyan
                                    Write-Host " "
                                } else {
                                    Write-Host "Let's start with the local setup of this machine's API." -ForegroundColor Cyan
                                    Write-Host " "
                                }
                                Write-Host "RainbowMiner can be monitored using your webbrowser via API:" -Foreground Cyan
                                Write-Host "- on this machine: http://localhost:$($Config.APIPort)" -ForegroundColor Cyan
                                Write-Host "- on most devices in the network: http://$($Session.MachineName):$($Config.APIPort)" -ForegroundColor Cyan
                                Write-Host "- on any other device in the network: http://$($Session.MyIP):$($Config.APIPort)" -ForegroundColor Cyan
                                Write-Host " "
                            }
                            $Config.APIport = Read-HostInt -Prompt "If needed, choose a different API port" -Default $Config.APIPort -Mandatory -Min 1000 -Max 9999 | Foreach-Object {if ($Controls -icontains $_) {throw $_};$_}
                        }
                        "apiinit" {
                            if (-not (Test-APIServer -Port $Config.APIPort)) {
                                Write-Host " "
                                Write-Host "Warning: the API is currently visible locally, on http://localhost:$($Config.APIport), only." -ForegroundColor Yellow
                                Write-Host " "
                                if ($InitAPIServer = Read-HostBool -Prompt "Do you want to enable the API in your network? " -Default $true | Foreach-Object {if ($Controls -icontains $_) {throw $_};$_}) {
                                    Write-Host " "
                                    Write-Host "Ok, enable remote access to your API now.$(if (-not $Session.IsAdmin) {" Please click 'Yes' for all UAC prompts!"})"
                                    Write-Host " "
                                    Initialize-APIServer -Port $Config.APIport
                                }
                            } else {
                                $GlobalSetupStepStore = $false
                            }
                        }
                        "apiauth" {
                            $Config.APIauth = Read-HostBool -Prompt "Enable username/password to protect access to the API?" -Default $Config.APIAuth | Foreach-Object {if ($Controls -icontains $_) {throw $_};$_}
                        }
                        "apiuser" {
                            if (Get-Yes $Config.APIauth) {
                                $Config.APIUser = Read-HostString -Prompt "Enter an API username ($(if ($Config.APIUser) {"clear"} else {"leave empty"}) to disable auth)" -Default $Config.APIUser -Characters "A-Z0-9" -MinLength 3 -MaxLength 30 | Foreach-Object {if ($Controls -icontains $_) {throw $_};$_}
                            } else {
                                $GlobalSetupStepStore = $false
                            }
                        }
                        "apipassword" {
                            if (Get-Yes $Config.APIauth) {
                                $Config.APIPassword = Read-HostString -Prompt "Enter an API password ($(if ($Config.APIpassword) {"clear"} else {"leave empty"}) to disable auth)" -Default $Config.APIpassword -Characters "" -MinLength 3 -MaxLength 30 | Foreach-Object {if ($Controls -icontains $_) {throw $_};$_}
                            } else {
                                $GlobalSetupStepStore = $false
                            }
                        }
                        "runmode" {
                            $Config.RunMode = Read-HostString -Prompt "Select the operation mode of this rig (standalone,server,client)" -Default $Config.RunMode -Valid @("standalone","server","client") | Foreach-Object {if ($Controls -icontains $_) {throw $_};$_}
                            if ($Config.RunMode -eq "") {$Config.RunMode = "standalone"}
                            if ($Config.RunMode -eq "server") {
                                Write-Host " "
                                Write-Host "Write down the following:" -ForegroundColor Yellow
                                Write-Host "- Servername: $($Session.MachineName)" -ForegroundColor Yellow
                                Write-Host "- IP-Address: $($Session.MyIP)" -Foreground Yellow
                                Write-Host " "
                            }
                        }
                        "serverinit" {
                            if ($Config.RunMode -eq "Server" -and -not (Test-APIServer -Port $Config.APIport)) {
                                Write-Host " "
                                Write-Host "Warning: For server operation, an additional firewall rule will be needed." -ForegroundColor Yellow
                                Write-Host " "
                                $InitAPIServer = Read-HostBool -Prompt "Do you want to add this rule to the firewall now? " -Default $true | Foreach-Object {if ($Controls -icontains $_) {throw $_};$_}
                                Write-Host " "
                                Write-Host "Ok, adding a rule to your firewall now.$(if (-not $Session.IsAdmin) {" Please click 'Yes' for all UAC prompts!"})"
                                Write-Host " " 
                                if ($InitAPIServer) {Initialize-APIServer -Port $Config.APIport}
                            } else {
                                $GlobalSetupStepStore = $false
                            }
                        }
                        "serverinit2" {
                            if ($Config.RunMode -eq "Server") {
                                $Config.StartPaused = Read-HostBool "Start the Server machine in pause/no-mining mode automatically? " -Default $Config.StartPaused | Foreach-Object {if ($Controls -icontains $_) {throw $_};$_}
                            } elseif (Get-Yes $Config.StartPaused) {
                                $Config.StartPaused = -not (Read-HostBool -Prompt "RainbowMiner is currently configured to start in pause/no-mining mode. Do you want to disable that?" -Default $true)
                            } else {
                                $GlobalSetupStepStore = $false
                            }
                        }
                        "servername" {
                            if ($Config.RunMode -eq "client") {
                                if ($IsInitialSetup) {
                                    Write-Host " "
                                    Write-Host "Now let us continue with your server's credentials" -ForegroundColor Cyan
                                    Write-Host " "
                                }
                                $Config.ServerName = Read-HostString -Prompt "Enter the server's $(if ($IsWindows) {"name or "})IP-address ($(if ($Config.ServerName) {"clear"} else {"leave empty"}) for standalone operation)" -Default $Config.ServerName -Characters "A-Z0-9-_\." | Foreach-Object {if ($Controls -icontains $_) {throw $_};$_}
                            } else {
                                $GlobalSetupStepStore = $false
                            }
                        }
                        "serverport" {
                            if ($Config.RunMode -eq "client") {
                                $Config.ServerPort = Read-HostInt -Prompt "Enter the server's API port ($(if ($Config.ServerPort) {"clear"} else {"leave empty"}) for standalone operation)" -Default $Config.ServerPort -Min 0 -Max 9999 | Foreach-Object {if ($Controls -icontains $_) {throw $_};$_}
                            } else {
                                $GlobalSetupStepStore = $false
                            }
                        }
                        "serveruser" {
                            if ($Config.RunMode -eq "client") {
                                $Config.ServerUser = Read-HostString -Prompt "If you have auth enabled on your server's API, enter the username ($(if ($Config.ServerUser) {"clear"} else {"leave empty"}) for no auth)" -Default $Config.ServerUser -Characters "A-Z0-9" | Foreach-Object {if ($Controls -icontains $_) {throw $_};$_}
                            } else {
                                $GlobalSetupStepStore = $false
                            }
                        }
                        "serverpassword" {
                            if ($Config.RunMode -eq "client") {
                                $Config.ServerPassword = Read-HostString -Prompt "If you have auth enabled on your server's API, enter the password ($(if ($Config.ServerPassword) {"clear"} else {"leave empty"}) for no auth)" -Default $Config.ServerPassword -Characters "" | Foreach-Object {if ($Controls -icontains $_) {throw $_};$_}
                            } else {
                                $GlobalSetupStepStore = $false
                            }
                        }

                        "clientconnect" {
                            if ($Config.RunMode -eq "client") {

                                if ($Config.ServerName -and $Config.ServerPort -and (Test-TcpServer -Server $Config.ServerName -Port $Config.ServerPort -Timeout 2)) {
                                    Write-Host " "
                                    Write-Host "Server connected successfully!" -ForegroundColor Green
                                    Write-Host " "
                                } else {
                                    Write-Host " "
                                    Write-Host "Server not found!" -ForegroundColor Red
                                    Write-Host " "
                                    if (Read-HostBool "Retry to connect?" -Default $true | Foreach-Object {if ($Controls -icontains $_) {throw $_};$_}) {
                                        $GlobalSetupStepStore = $false
                                        throw "Goto clientconnect"
                                    }
                                    if (Read-HostBool "Restart client/server queries?" -Default $false | Foreach-Object {if ($Controls -icontains $_) {throw $_};$_}) {
                                        $GlobalSetupStepStore = $false
                                        throw "Goto runmode"
                                    }
                                }
                            } else {
                                $GlobalSetupStepStore = $false
                            }
                        }
                        "enableserverconfig" {
                            if ($Config.RunMode -eq "client") {
                                if ($IsInitialSetup) {
                                    Write-Host " "
                                    Write-Host "RainbowMiner can use centralized configuration files:" -ForegroundColor Cyan
                                    Write-Host "selected config files will be downloaded automatically, if changed on the server rig" -ForegroundColor Cyan
                                    Write-Host " "
                                    Write-Host "HINT:" -Foreground Cyan
                                    Write-Host "If specific config files for this client are needed, put them into subdirectory `".\Config\$($Config.WorkerName.ToLower())`" on your server" -ForegroundColor Cyan
                                    Write-Host "Clients can be grouped together for shared config files. You will be asked for a group, if you enable now." -ForegroundColor Cyan
                                    Write-Host " "
                                }
                                $Config.EnableServerConfig = Read-HostBool "Enable automatic download of selected server config files? " -Default $Config.EnableServerConfig | Foreach-Object {if ($Controls -icontains $_) {throw $_};$_}
                            } else {
                                $GlobalSetupStepStore = $false
                            }
                        }
                        "groupname" {
                            if ($Config.RunMode -eq "client" -and (Get-Yes $Config.EnableServerConfig)) {
                                $Config.GroupName = Read-HostString -Prompt "Enter a group name, if clients should be grouped together for shared config (($(if ($Config.ServerUser) {"clear"} else {"leave empty"}) for no group)" -Default $Config.GroupName -Characters "A-Z0-9" | Foreach-Object {if ($Controls -icontains $_) {throw $_};$_}
                                if ($IsInitialSetup -and $Config.GroupName) {
                                    Write-Host " "
                                    Write-Host "HINT:" -Foreground Cyan
                                    Write-Host "If specific config files for this client's group are needed, put them into subdirectory `".\Config\$($Config.GroupName.ToLower())`" on your server" -ForegroundColor Cyan
                                    Write-Host " "
                                }
                            } else {
                                $GlobalSetupStepStore = $false
                            }
                        }
                        "serverconfigname" {
                            if ($Config.RunMode -eq "client" -and (Get-Yes $Config.EnableServerConfig)) {
                                $Config.ServerConfigName = Read-HostArray -Prompt "Enter the config files to be copied to this machine" -Default $Config.ServerConfigName -Characters "A-Z" -Valid @("algorithms","coins","config","miners","ocprofiles","pools","scheduler") | Foreach-Object {if ($Controls -icontains $_) {throw $_};$_}
                            } else {
                                $GlobalSetupStepStore = $false
                            }
                        }
                        "excludeserverconfigvars1" {
                            if ($Config.RunMode -eq "client" -and $Config.ServerConfigName -match "config" -and (Get-Yes $Config.EnableServerConfig)) {
                                Write-Host " "
                                Write-Host "Select all config parameters, that should not be overwritten with the server's config" -ForegroundColor Cyan
                                Write-Host " "
                                $Config.EnableServerExcludeList = Read-HostBool -Prompt "Use the server's exclusion list?" -Default $Config.EnableServerExcludeList | Foreach-Object {if ($Controls -icontains $_) {throw $_};$_}
                            } else {
                                $GlobalSetupStepStore = $false
                            }
                        }
                        "excludeserverconfigvars2" {
                            if (-not $Config.EnableServerExcludeList -and $Config.RunMode -eq "client" -and $Config.ServerConfigName -match "config" -and (Get-Yes $Config.EnableServerConfig)) {
                                Write-Host " "
                                Write-Host "- exclude in config.txt: use the parameter name" -ForegroundColor Cyan
                                Write-Host "- exclude in pools.config.txt:" -ForegroundColor Cyan
                                Write-Host "  `"pools:<poolname>`" to protect all parameters of a pool" -ForegroundColor Cyan
                                Write-Host "  `"pools:<poolname>:<parameter>`" to protect a specific parameter of a pool" -ForegroundColor Cyan
                                Write-Host "   e.g. `"pools:MiningRigRentals:API_Key`" will protect API_Key for MiningRigRentals" -ForegroundColor Cyan
                                Write-Host " "
                                $Config.ExcludeServerConfigVars = Read-HostArray -Prompt "Enter all config parameters, that should not be overwritten (if unclear, use default values!)" -Default $Config.ExcludeServerConfigVars -Characters "A-Z0-9:_" | Foreach-Object {if ($Controls -icontains $_) {throw $_};$_}
                            } else {
                                $GlobalSetupStepStore = $false
                            }
                        }
                        "clientinit" {
                            if ($Config.RunMode -eq "client" -and $Config.ServerConfigName -and (Get-Yes $Config.EnableServerConfig)) {

                                if ($DownloadServerNow) {
                                    if (Get-ServerConfig -ConfigFiles $ConfigFiles -ConfigName @(Get-ConfigArray $Config.ServerConfigName) -ExcludeConfigVars @(Get-ConfigArray $Config.ExcludeServerConfigVars) -Server $Config.ServerName -Port $Config.ServerPort -Workername $Config.WorkerName -Username $Config.ServerUser -Password $Config.ServerPassword -Force -EnableServerExcludeList:$Config.EnableServerExcludeList) {
                                        Write-Host "Configfiles downloaded successfully!" -ForegroundColor Green
                                        Write-Host " "
                                        Get-ConfigArray $Config.ServerConfigName | Foreach-Object {
                                            if ($Var = $ConfigFiles.Keys -match $_) {
                                                Set-Variable "$($Var)Actual" -Value $(Get-Content $ConfigFiles[$Var].Path -Raw | ConvertFrom-Json)
                                                if ($Var -eq "Config") {
                                                    $ConfigActual.PSObject.Properties | Foreach-Object {$Config | Add-Member $_.Name $_.Value -Force}
                                                } elseif ($Var -eq "Pools") {
                                                    if ($PoolsActual | Get-Member Nicehash -MemberType NoteProperty) {
                                                        $NicehashWallet = $PoolsActual.Nicehash.BTC
                                                        $NicehashPlatform = $PoolsActual.Nicehash.Platform
                                                        $NicehashOrganizationID = $PoolsActual.Nicehash.OrganizationID
                                                        $NicehashAPIKey = $PoolsActual.Nicehash.API_Key
                                                        $NicehashAPISecret = $PoolsActual.Nicehash.API_Secret
                                                    }

                                                    if ($PoolsActual | Get-Member MiningPoolHub -MemberType NoteProperty) {
                                                        $MPHUser        = $PoolsActual.MiningPoolHub.User
                                                        $MPHAPIID       = $PoolsActual.MiningPoolHub.API_ID
                                                        $MPHAPIKey      = $PoolsActual.MiningPoolHub.API_Key
                                                    }

                                                    if ($PoolsActual | Get-Member MiningPoolHubCoins -MemberType NoteProperty) {
                                                        if (-not $MPHUser)   {$MPHUser   = $PoolsActual.MiningPoolHubCoins.User}
                                                        if (-not $MPHAPIID)  {$MPHAPIID  = $PoolsActual.MiningPoolHubCoins.API_ID}
                                                        if (-not $MPHAPIKey) {$MPHAPIKey = $PoolsActual.MiningPoolHubCoins.API_Key}
                                                    }

                                                    if ($PoolsActual | Get-Member MiningRigRentals -MemberType NoteProperty) {
                                                        $MRRUser        = $PoolsActual.MiningRigRentals.User
                                                        $MRRAPIKey      = $PoolsActual.MiningRigRentals.API_Key
                                                        $MRRAPISecret   = $PoolsActual.MiningRigRentals.API_Secret
                                                    }
                                                }
                                            }
                                        }
                                        $GlobalSetupStepStore = $false
                                    } else {
                                        Write-Host "Error downloading configfiles!" -ForegroundColor Yellow
                                        Write-Host " "
                                    }
                                    $DownloadServerNow = $false
                                }

                                if ($GlobalSetupStepStore) {
                                    if (Test-TcpServer -Server $Config.ServerName -Port $Config.ServerPort -Timeout 2) {
                                        if (Read-HostBool "Download server configuration now? This will end the setup." -Default $true | Foreach-Object {if ($Controls -icontains $_) {throw $_};$_}) {
                                            $DownloadServerNow = $true
                                            throw "Goto save"
                                        }
                                    } else {
                                        Write-Host " "
                                        Write-Host "Server not found!" -ForegroundColor Red
                                        Write-Host " "
                                        if (Read-HostBool "Retry to connect?" -Default $true | Foreach-Object {if ($Controls -icontains $_) {throw $_};$_}) {
                                            $GlobalSetupStepStore = $false
                                            throw "Goto clientinit"
                                        }
                                        if (Read-HostBool "Restart client/server queries?" -Default $false | Foreach-Object {if ($Controls -icontains $_) {throw $_};$_}) {
                                            $GlobalSetupStepStore = $false
                                            throw "Goto runmode"
                                        }
                                    }
                                }
                            } else {
                                $GlobalSetupStepStore = $false
                            }
                        }
                        "enableautominerports" {
                            if (-not $IsInitialSetup) {
                                $Config.EnableAutoMinerPorts = Read-HostBool -Prompt "Enable automatic port switching, if miners try to run on used ports" -Default $Config.EnableAutoMinerPorts | Foreach-Object {if ($Controls -icontains $_) {throw $_};$_}
                            } else {
                                $GlobalSetupStepStore = $false
                            }
                        }
                        "currency" {
                            $Config.Currency = Read-HostArray -Prompt "Enter all currencies to be displayed (e.g. EUR,USD,BTC)" -Default $Config.Currency -Mandatory -Characters "A-Z" | Foreach-Object {if ($Controls -icontains $_) {throw $_};$_}
                        }
                        "benchmarkintervalsetup" {
                            if ($IsInitialSetup) {
                                Write-Host " "
                                Write-Host "RainbowMiner includes a lot of different miner programs. Before the regular profit switching operation may start," -ForegroundColor Cyan
                                Write-Host "all programs need to be benchmarked on your system, once. The benchmarks will already mine into your wallet," -ForegroundColor Cyan
                                Write-Host "but it may take a long time to finish. Please be patient. It is a one time thing." -ForegroundColor Cyan
                                Write-Host " "
                                Write-Host "Please select the benchmark-accuracy. This value will determine the runtime interval used for benchmarks" -ForegroundColor Cyan
                                Write-Host "(this value can be set to individual values by directly changing BenchmarkInterval in config.txt)." -ForegroundColor Cyan
                                Write-Host "- Quick   = 60 seconds (should be enough, for most cases)" -ForegroundColor Cyan
                                Write-Host "- Normal  = 90 seconds" -ForegroundColor Cyan
                                Write-Host "- Precise = 180 seconds" -ForegroundColor Cyan                                
                                $BenchmarkAccuracy = Read-HostString -Prompt "Please select the benchmark accuracy (enter quick,normal or precise)" -Default $(if ($Config.BenchmarkInterval -le 60){"quick"} elseif ($Config.BenchmarkInterval -le 90) {"normal"} else {"precise"}) -Valid @("quick","normal","precise") -Mandatory -Characters "A-Z" | Foreach-Object {if ($Controls -icontains $_) {throw $_};$_}
                                $Config.BenchmarkInterval = Switch($BenchmarkAccuracy) {"quick" {60};"normal" {90};"precise" {180}}
                            } else {
                                $GlobalSetupStepStore = $false 
                            }
                        }
                        "poolname" {
                            if ($SetupType -eq "A") {
                                Write-Host ' '
                                Write-Host '(2) Select your pools, miners and algorithm (be sure you read the notes in the README.md)' -ForegroundColor Green
                                Write-Host ' '
                            }

                            $CoinsActual = Get-Content $ConfigFiles["Coins"].Path | ConvertFrom-Json

                            if ($IsInitialSetup) {
                                Write-Host " "
                                Write-Host "Choose your mining pools from this list or accept the default for a head start (read the Pools section of our readme for more details): " -ForegroundColor Cyan
                                Write-Host "$($Session.AvailPools -join ", ")" -ForegroundColor Cyan
                                Write-Host " "
                            }

                            if ($CoinsWithWallets = $CoinsActual.PSObject.Properties | Where-Object {$_.Value.Wallet} | Foreach-Object {$_.Name} | Select-Object -Unique | Sort-Object) {
                                Write-Host "You have entered wallets for the following currencies. Consider adding some of the proposed pools:" -ForegroundColor Cyan
                                $p = [console]::ForegroundColor
                                [console]::ForegroundColor = "Cyan"
                                $CoinsPools = @(Get-PoolsInfo "Minable" $CoinsWithWallets -AsObjects | Select-Object)
                                $CoinsWithWallets | Foreach-Object {
                                    $Currency = $_
                                    [PSCustomObject]@{Currency=$_; "pools without autoexchange"=$(@($CoinsPools | Where-Object {$_.Currencies -icontains $Currency} | Where-Object {-not $PoolsSetup."$($_.Pool)".Autoexchange -or $_.Pool -match "ZergPool"} | Select-Object -ExpandProperty Pool | Sort-Object) -join ",")}
                                } | Format-Table -Wrap
                                [console]::ForegroundColor = $p
                            }

                            Write-Host "Hint: `"+entryname`" = add an entry to a list, `"-entryname`" = remove an entry from a list" -ForegroundColor Yellow
                            Write-Host " "

                            $Config.PoolName = Read-HostArray -Prompt "Enter the pools you want to mine" -Default $Config.PoolName -Mandatory -Characters "A-Z0-9" -Valid $Session.AvailPools | Foreach-Object {if ($Controls -icontains $_) {throw $_};$_}
                        }
                        "poolnamenh1" {
                            $PoolNames = @(Get-ConfigArray $Config.PoolName)
                            if ($PoolNames -icontains "NiceHashV2") {
                                if ($IsInitialSetup) {
                                    Write-Host " "
                                    Write-Host "You have enabled NicehashV2. Register an account with them, to get a NiceHash mining wallet address (please read the Pools section of our readme!). " -ForegroundColor Cyan
                                    Write-Host "If you do not want to use NicehashV2 as a pool, leave this empty (or enter `"clear`" to make it empty) and press return " -ForegroundColor Cyan
                                    Write-Host " "
                                }

                                if ($NicehashV2Wallet -eq "`$Wallet"){$NicehashV2Wallet=$Config.Wallet}
                                $NicehashV2Wallet = Read-HostString -Prompt "Enter your NiceHashV2 BTC mining wallet address" -Default $NicehashV2Wallet -Length 34 -Characters "A-Z0-9" | Foreach-Object {if ($Controls -icontains $_) {throw $_};$_}
                            } else {
                                $GlobalSetupStepStore = $false
                            }
                        }
                        "poolnamenh2" {
                            $PoolNames = @(Get-ConfigArray $Config.PoolName)
                            if ($PoolNames -icontains "NiceHashV2") {
                                if ($NiceHashV2Wallet -eq "`$Wallet" -or $NiceHashV2Wallet -eq $Config.Wallet) {
                                    if (Read-HostBool "You have entered your default wallet as NicehashV2 wallet. Do you want to disable NiceHashV2 mining for now? (Or enter `"<`" to return to the wallet query)" -Default $false | Foreach-Object {if ($Controls -icontains $_) {throw $_};$_}) {
                                        $NiceHashV2Wallet = ''
                                    }
                                }
                                if (-not $NicehashV2Wallet) {
                                    $PoolNames = $PoolNames | Where-Object {$_ -ne "NiceHashV2"}
                                }
                                $Config.PoolName = ($PoolNames | Select-Object -Unique | Sort-Object) -join ','
                            } else {
                                $GlobalSetupStepStore = $false
                            }
                        }
                        "autoaddcoins" {
                            if ($IsInitialSetup -and $CoinsWithWallets.Count) {
                                $AutoAddCoins = Read-HostBool -Prompt "Automatically add wallets for $($CoinsWithWallets -join ", ") to pools?" -Default $AutoAddCoins | Foreach-Object {if ($Controls -icontains $_) {throw $_};$_}
                            } else {
                                $GlobalSetupStepStore = $false
                            }
                        }
                        "excludepoolname" {
                            $Config.ExcludePoolName = Read-HostArray -Prompt "Enter the pools you do want to exclude from mining" -Default $Config.ExcludePoolName -Characters "A-Z0-9" -Valid $Session.AvailPools | Foreach-Object {if ($Controls -icontains $_) {throw $_};$_}
                        }
                        "minername" {
                            if ($IsInitialSetup) {
                                Write-Host " "
                                Write-Host "You are almost done :) Our defaults for miners and algorithms give you a good start. If you want, you can skip the settings for now " -ForegroundColor Cyan
                                Write-Host " "
                                $Skip = Read-HostBool -Prompt "Do you want to skip the miner and algorithm setup?" -Default $true | Foreach-Object {if ($Controls -icontains $_) {throw $_};$_}
                                if ($Skip) {throw "Goto devicenamebegin"}
                            }
                            $Config.MinerName = Read-HostArray -Prompt "Enter the miners your want to use ($(if ($Config.MinerName) {"clear"} else {"leave empty"}) for all)" -Default $Config.MinerName -Characters "A-Z0-9.-_" -Valid $Session.AvailMiners | Foreach-Object {if ($Controls -icontains $_) {throw $_};$_}
                        }
                        "excludeminername" {
                            $Config.ExcludeMinerName = Read-HostArray -Prompt "Enter the miners you do want to exclude" -Default $Config.ExcludeMinerName -Characters "A-Z0-9\.-_" -Valid $Session.AvailMiners | Foreach-Object {if ($Controls -icontains $_) {throw $_};$_}
                        }
                        "algorithm" {
                            $Config.Algorithm = Read-HostArray -Prompt "Enter the algorithm you want to mine ($(if ($Config.Algorithm) {"clear"} else {"leave empty"}) for all)" -Default $Config.Algorithm -Characters "A-Z0-9" -Valid (Get-Algorithms) | Foreach-Object {if ($Controls -icontains $_) {throw $_};$_}
                        }
                        "excludealgorithm" {
                            $Config.ExcludeAlgorithm = Read-HostArray -Prompt "Enter the algorithm you do want to exclude " -Default $Config.ExcludeAlgorithm -Characters "A-Z0-9" -Valid (Get-Algorithms) | Foreach-Object {if ($Controls -icontains $_) {throw $_};$_}
                        }
                        "disableunprofitablealgolist" {
                            $Config.DisableUnprofitableAlgolist = Read-HostBool -Prompt "Disable the build-in list of unprofitable algorithms " -Default $Config.DisableUnprofitableAlgolist | Foreach-Object {if ($Controls -icontains $_) {throw $_};$_}
                        }

                        "excludecoinsymbol" {
                            $Config.ExcludeCoinSymbol = Read-HostArray -Prompt "Enter the name of coins by currency symbol, you want to globaly exclude " -Default $Config.ExcludeCoinSymbol -Characters "\`$A-Z0-9" | Foreach-Object {if ($Controls -icontains $_) {throw $_};$_}
                        }
                        "excludecoin" {
                            $Config.ExcludeCoin = Read-HostArray -Prompt "Enter the name of coins by name, you want to globaly exclude " -Default $Config.ExcludeCoin -Characters "`$A-Z0-9. " | Foreach-Object {if ($Controls -icontains $_) {throw $_};$_}
                        }
                        "disabledualmining" {
                            $Config.DisableDualMining = Read-HostBool -Prompt "Disable all dual mining algorithm" -Default $Config.DisableDualMining | Foreach-Object {if ($Controls -icontains $_) {throw $_};$_}
                        }
                        "excludeminerswithfee" {
                            $Config.ExcludeMinersWithFee = Read-HostBool -Prompt "Exclude all miners with developer fee" -Default $Config.ExcludeMinersWithFee | Foreach-Object {if ($Controls -icontains $_) {throw $_};$_}
                        }
                        "enablecheckminingconflict" {
                            $Config.EnableCheckMiningConflict = Read-HostBool -Prompt "Enable conflict check if running CPU hungry GPU miners (for weak CPUs)" -Default $Config.EnableCheckMiningConflict | Foreach-Object {if ($Controls -icontains $_) {throw $_};$_}
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
                            $Config.MiningMode = Read-HostString "Select mining mode (legacy/device/combo)" -Default $Config.MiningMode -Mandatory -Characters "A-Z" | Foreach-Object {if ($Controls -icontains $_) {throw $_};$_}
                            if ($Config.MiningMode -like "l*") {$Config.MiningMode="legacy"}
                            elseif ($Config.MiningMode -like "c*") {$Config.MiningMode="combo"}
                            else {$Config.MiningMode="device"}
                        }
                        "mincombooversingleratio" {
                            if ($Config.MiningMode -like "c*") {
                                Write-Host " "
                                Write-Host "Adjust the minimum profit ratio for combo-miner over single-miners"
                                Write-Host "One miner will be used instead of many single-miners, if the profit is better than $("{0:f1}" -f ($Config.MinComboOverSingleRatio*100))% of the sum of profits of the single miners" -ForegroundColor Yellow                            
                         
                                $Config.MinComboOverSingleRatio = Read-HostDouble -Prompt "Min. combo over single profit rate in %" -Default ($Config.MinComboOverSingleRatio*100) -Min 0 -Max 100 | Foreach-Object {if ($Controls -icontains $_) {throw $_};$_}
                                $Config.MinComboOverSingleRatio = $Config.MinComboOverSingleRatio / 100
                            } else {
                                $GlobalSetupStepStore = $false
                            }
                        }
                        "devicename" {
                            $Config.DeviceName = Read-HostArray -Prompt "Enter the devices you want to use for mining " -Default $Config.DeviceName -Characters "A-Z0-9#\*" -Valid @($SetupDevices | Foreach-Object {$_.Type.ToUpper();if ($Config.MiningMode -eq "legacy") {if (@("nvidia","amd") -icontains $_.Vendor) {$_.Vendor}} else {if (@("nvidia","amd") -icontains $_.Vendor) {$_.Vendor;$_.Model};$_.Name}} | Select-Object -Unique | Sort-Object) | Foreach-Object {if ($Controls -icontains $_) {throw $_};$_}
                        }
                        "excludedevicename" {
                            $Config.ExcludeDeviceName = Read-HostArray -Prompt "Enter the devices to exclude from mining " -Default $Config.ExcludeDeviceName -Characters "A-Z0-9#\*" -Valid @($SetupDevices | Foreach-Object {$_.Type.ToUpper();$_.Vendor;$_.Model;$_.Name} | Select-Object -Unique | Sort-Object) | Foreach-Object {if ($Controls -icontains $_) {throw $_};$_}
                            if ($GlobalSetupSteps.Contains("devicenameend")) {throw "Goto devicenameend"}
                        }
                        "devicenamewizard" {
                            $GlobalSetupStepStore = $false
                            $Config.DeviceName = @("GPU")
                            [hashtable]$NewDeviceName = @{}
                            [hashtable]$AvailDeviceCounts = @{}
                            $AvailDeviceGPUVendors = @($SetupDevices | Where-Object {$_.Type -eq "gpu" -and @("nvidia","amd") -icontains $_.Vendor} | Select-Object -ExpandProperty Vendor -Unique | Sort-Object)
                            $AvailDevicecounts["CPU"] = @($SetupDevices | Where-Object {$_.Type -eq "cpu"} | Select-Object -ExpandProperty Name -Unique | Sort-Object).Count
                            $AvailDeviceCounts["GPU"] = 0

                            if ($AvailDeviceGPUVendors.Count -eq 0) {throw "Goto devicenamewizardcpu1"}  
                                                                                      
                            foreach ($p in $AvailDeviceGPUVendors) {
                                $NewDeviceName[$p] = @()
                                $AvailDevicecounts[$p] = @($SetupDevices | Where-Object {$_.Type -eq "gpu" -and $_.Vendor -eq $p} | Select-Object -ExpandProperty Name -Unique | Sort-Object).Count
                                $AvailDeviceCounts["GPU"] += $AvailDevicecounts[$p]
                            }
                        }
                        "devicenamewizardgpu" {
                            if ($AvailDeviceGPUVendors.Count -eq 1 -and $AvailDeviceCounts["GPU"] -gt 1) {
                                $GlobalSetupStepStore = $false
                                throw "Goto devicenamewizard$($AvailDeviceGPUVendors[0].ToLower())1"
                            }
                            if ($AvailDeviceCounts["GPU"] -eq 1) {
                                if (Read-HostBool -Prompt "Mine on your $($SetupDevices | Where-Object {$_.Type -eq "gpu" -and $_.Vendor -eq $AvailDeviceGPUVendors[0]} | Select -ExpandProperty Model_Name -Unique)" -Default $true | Foreach-Object {if ($Controls -icontains $_) {throw $_};$_}) {
                                    $NewDeviceName[$AvailDeviceGPUVendors[0]] = $AvailDeviceGPUVendors[0]
                                }
                                throw "Goto devicenamewizardcpu1"
                            }
                            if (Read-HostBool -Prompt "Mine on all available GPU ($($AvailDeviceGPUVendors -join ' and '), choose no to select devices)" -Default $true | Foreach-Object {if ($Controls -icontains $_) {throw $_};$_}) {
                                foreach ($p in $AvailDeviceGPUVendors) {$NewDeviceName[$p] = @($p)}
                                throw "Goto devicenamewizardcpu1"
                            }
                        }
                        "devicenamewizardamd1" {
                            $NewDeviceName["AMD"] = @()
                            if ($AvailDeviceCounts["AMD"] -gt 0) {
                                if (Read-HostBool -Prompt "Do you want to mine on $(if ($AvailDeviceCounts["AMD"] -gt 1) {"all AMD GPUs"}else{"your AMD GPU"})" -Default $true | Foreach-Object {if ($Controls -icontains $_) {throw $_};$_}) {
                                    $NewDeviceName["AMD"] = @("AMD")
                                }
                            } else {
                                $GlobalSetupStepStore = $false
                            }
                        }
                        "devicenamewizardamd2" {
                            if ($AvailDeviceCounts["AMD"] -gt 1 -and $NewDeviceName["AMD"].Count -eq 0) {
                                $NewDeviceName["AMD"] = Read-HostArray -Prompt "Enter the AMD devices you want to use for mining " -Characters "A-Z0-9#" -Valid @($SetupDevices | Where-Object {$_.Vendor -eq "AMD" -and $_.Type -eq "GPU"} | Foreach-Object {$_.Vendor;$_.Model;$_.Name} | Select-Object -Unique | Sort-Object) | Foreach-Object {if ($Controls -icontains $_) {throw $_};$_}
                            } else {
                                $GlobalSetupStepStore = $false
                            }
                        }
                        "devicenamewizardnvidia1" {
                            $NewDeviceName["NVIDIA"] = @()
                            if ($AvailDeviceCounts["NVIDIA"] -gt 0) {
                                if (Read-HostBool -Prompt "Do you want to mine on $(if ($AvailDeviceCounts["NVIDIA"] -gt 1) {"all NVIDIA GPUs"}else{"your NVIDIA GPU"})" -Default $true | Foreach-Object {if ($Controls -icontains $_) {throw $_};$_}) {
                                    $NewDeviceName["NVIDIA"] = @("NVIDIA")
                                }
                            } else {
                                $GlobalSetupStepStore = $false
                            }
                        }
                        "devicenamewizardnvidia2" {
                            if ($AvailDeviceCounts["NVIDIA"] -gt 1 -and $NewDeviceName["NVIDIA"].Count -eq 0) {
                                $NewDeviceName["NVIDIA"] = Read-HostArray -Prompt "Enter the NVIDIA devices you want to use for mining " -Characters "A-Z0-9#" -Valid @($SetupDevices | Where-Object {$_.Vendor -eq "NVIDIA" -and $_.Type -eq "GPU"} | Foreach-Object {$_.Vendor;$_.Model;$_.Name} | Select-Object -Unique | Sort-Object) | Foreach-Object {if ($Controls -icontains $_) {throw $_};$_}
                            } else {
                                $GlobalSetupStepStore = $false
                            }
                        }
                        "devicenamewizardcpu1" {
                            $NewDeviceName["CPU"] = @()
                            if (Read-HostBool -Prompt "Do you want to mine on your CPU$(if ($AvailDeviceCounts["cpu"] -gt 1){"s"})" -Default $false | Foreach-Object {if ($Controls -icontains $_) {throw $_};$_}) {
                                $NewDeviceName["CPU"] = @("CPU")
                            }
                        }
                        "devicenamewizardend" {
                            $GlobalSetupStepStore = $false
                            $Config.DeviceName = @($NewDeviceName.Values | Where-Object {$_} | Foreach-Object {$_} | Select-Object -Unique | Sort-Object)
                            if ($Config.DeviceName.Count -eq 0) {
                                Write-Host " "
                                if (Read-HostBool -Prompt "No devices selected. Do you want to restart the device setup?" -Default $true | Foreach-Object {if ($Controls -icontains $_) {throw $_};$_}) {
                                    $GlobalSetupStepBack = $GlobalSetupStepBack.Where({$_ -notmatch "^devicenamewizard"})                                                
                                    throw "Goto devicenamewizard"
                                }
                                Write-Host " "
                                Write-Host "No mining on this machine. RainbowMiner will start paused. " -ForegroundColor Yellow
                                Write-Host " "
                                $Config.StartPaused = $true
                            }
                            if ($NewDeviceName["AMD"]) {
                                Write-Host " "
                                Write-Host "Since you plan to mine on AMD, the minimum delay between miner change will be set to 2 seconds" -ForegroundColor Yellow
                                Write-Host " "
                                $Config.Delay = 2
                            }
                        }
                        "cpuminingthreads" {
                            if ($Config.DeviceName -icontains "CPU") {
                                $Config.CPUMiningThreads = Read-HostInt -Prompt "How many softwarethreads should be used for CPU mining? (0 or $(if ($Config.CPUMiningThreads) {"clear"} else {"leave empty"}) for auto)" -Default $Config.CPUMiningThreads -Min 0 | Foreach-Object {if ($Controls -icontains $_) {throw $_};$_}
                            } else {
                                $GlobalSetupStepStore = $false
                            }
                        }
                        "cpuminingaffinity" {
                            if ($Config.DeviceName -icontains "CPU") {
                                $CurrentAffinity = ConvertFrom-CPUAffinity $Config.CPUMiningAffinity
                                Write-Host " "
                                Write-Host "Your CPU features $($Global:GlobalCPUInfo.Threads) threads on $($Global:GlobalCPUInfo.Cores) cores. " -ForegroundColor Yellow
                                Write-Host "Currently mining on the green threads: " -ForegroundColor Yellow -NoNewline
                                for($thr=0;$thr -lt $Global:GlobalCPUInfo.Threads;$thr++) {
                                    Write-Host " $thr " -BackgroundColor $(if ($thr -in $CurrentAffinity){"Green"}else{"DarkGray"}) -ForegroundColor Black -NoNewline
                                }
                                if ($CurrentAffinity.Count) {
                                    Write-Host " = $($Config.CPUMiningAffinity)"
                                } else {
                                    Write-Host " (no affinity set)"
                                }
                                Write-Host " "
                                $NewAffinity = Read-HostArray -Prompt "Choose CPU threads (list of integer, $(if ($CurrentAffinity) {"clear"} else {"leave empty"}) for no assignment)" -Default $CurrentAffinity -Valid ([string[]]@(0..($Global:GlobalCPUInfo.Threads-1))) -Characters "0-9" | Foreach-Object {if ($Controls -icontains $_) {throw $_};$_}
                                $Config.CPUMiningAffinity = if ($NewAffinity.Count -gt 0) {ConvertTo-CPUAffinity $NewAffinity -ToHex} else {""}
                                if (Compare-Object @($NewAffinity|Select-Object) @($CurrentAffinity|Select-Object)) {
                                    Write-Host "Now mining on the green threads: " -ForegroundColor Yellow -NoNewline
                                    for($thr=0;$thr -lt $Global:GlobalCPUInfo.Threads;$thr++) {
                                        Write-Host " $thr " -BackgroundColor $(if ($thr -in $NewAffinity){"Green"}else{"DarkGray"}) -ForegroundColor Black -NoNewline
                                    }
                                    if ($NewAffinity.Count) {
                                        Write-Host " = $($Config.CPUMiningAffinity)"
                                    } else {
                                        Write-Host " (no affinity set)" 
                                    }
                                }
                            } else {
                                $GlobalSetupStepStore = $false
                            }
                        }
                        "gpuminingaffinity" {
                            $CurrentAffinity = ConvertFrom-CPUAffinity $Config.GPUMiningAffinity
                            Write-Host " "
                            Write-Host "Your CPU features $($Global:GlobalCPUInfo.Threads) threads on $($Global:GlobalCPUInfo.Cores) cores. " -ForegroundColor Yellow
                            Write-Host "GPU miners are currently using the green threads to validate their results: " -ForegroundColor Yellow -NoNewline
                            for($thr=0;$thr -lt $Global:GlobalCPUInfo.Threads;$thr++) {
                                Write-Host " $thr " -BackgroundColor $(if ($thr -in $CurrentAffinity){"Green"}else{"DarkGray"}) -ForegroundColor Black -NoNewline
                            }
                            if ($CurrentAffinity.Count) {
                                Write-Host " = $($Config.GPUMiningAffinity)"
                            } else {
                                Write-Host " (no affinity set)"
                            }
                            Write-Host " "
                            $NewAffinity = Read-HostArray -Prompt "Choose CPU threads (list of integer, $(if ($CurrentAffinity) {"clear"} else {"leave empty"}) for no assignment)" -Default $CurrentAffinity -Valid ([string[]]@(0..($Global:GlobalCPUInfo.Threads-1))) -Characters "0-9" | Foreach-Object {if ($Controls -icontains $_) {throw $_};$_}
                            $Config.GPUMiningAffinity = if ($NewAffinity.Count -gt 0) {ConvertTo-CPUAffinity $NewAffinity -ToHex} else {""}
                            if (Compare-Object @($NewAffinity|Select-Object) @($CurrentAffinity|Select-Object)) {
                                Write-Host "GPU miners now validating on the green threads: " -ForegroundColor Yellow -NoNewline
                                for($thr=0;$thr -lt $Global:GlobalCPUInfo.Threads;$thr++) {
                                    Write-Host " $thr " -BackgroundColor $(if ($thr -in $NewAffinity){"Green"}else{"DarkGray"}) -ForegroundColor Black -NoNewline
                                }
                                if ($NewAffinity.Count) {
                                    Write-Host " = $($Config.GPUMiningAffinity)"
                                } else {
                                    Write-Host " (no affinity set)" 
                                }
                            }
                        }
                        "devicenameend" {
                            $GlobalSetupStepStore = $false
                            if ($IsInitialSetup) {throw "Goto save"}
                        }
                        "pooldatawindow" {
                            Write-Host " "
                            Write-Host "Choose the default pool datawindow" -ForegroundColor Green

                            Write-HostSetupDataWindowHints

                            $Config.PoolDataWindow = Read-HostString -Prompt "Enter which default datawindow is to be used ($(if ($Config.PoolDataWindow) {"clear"} else {"leave empty"}) for automatic)" -Default $Config.PoolDataWindow -Characters "A-Z0-9_-" | Foreach-Object {if ($Controls -icontains $_) {throw $_};$_}
                        }
                        "enableerrorratio" {
                            $Config.EnableErrorRatio = Read-HostBool -Prompt "Enable pool price auto-correction" -Default $Config.EnableErrorRatio | Foreach-Object {if ($Controls -icontains $_) {throw $_};$_}
                        }
                        "poolstataverage" {
                            Write-Host " "
                            Write-Host "Choose the default pool moving average price trendline" -ForegroundColor Green

                            Write-HostSetupStatAverageHints

                            $Config.PoolStatAverage = Read-HostString -Prompt "Enter which default moving average is to be used ($(if ($Config.PoolStatAverage) {"clear"} else {"leave empty"}) for default)" -Default $Config.PoolStatAverage -Valid @("Live","Minute_5","Minute_10","Hour","Day","ThreeDay","Week") -Characters "A-Z0-9_" | Foreach-Object {if ($Controls -icontains $_) {throw $_};$_}
                        }
                        "hashrateweight" {
                            Write-Host " "
                            Write-Host "Adjust hashrate weight" -ForegroundColor Green
                            Write-Host " "
                            Write-Host "Formula: price * (1-(hashrate weight/100)*(1-(rel. hashrate)^(hashrate weight strength/100))" -ForegroundColor Cyan
                            Write-Host " "
                            $Config.HashrateWeight = Read-HostInt -Prompt "Adjust weight of pool hashrates on the profit comparison in % (0..100, 0=disable)" -Default $Config.HashrateWeight -Min 0 -Max 100 | Foreach-Object {if ($Controls -icontains $_) {throw $_};$_}
                        }
                        "hashrateweightstrength" {
                            $Config.HashrateWeightStrength = Read-HostInt -Prompt "Adjust the strength of the weight (integer, 0=no weight, 100=linear, 200=square)" -Default $Config.HashrateWeightStrength -Min 0 | Foreach-Object {if ($Controls -icontains $_) {throw $_};$_}
                        }
                        "poolaccuracyweight" {
                            $Config.PoolAccuracyWeight = Read-HostInt -Prompt "Adjust weight of pools accuracy on the profit comparison in % (0..100, 0=disable)" -Default $Config.PoolAccuracyWeight -Min 0 -Max 100 | Foreach-Object {if ($Controls -icontains $_) {throw $_};$_}
                        }
                        "defaultpoolregion" {
                            $Config.DefaultPoolRegion = Read-HostArray -Prompt "Enter the default region order, if pool does not offer a stratum in your region" -Default $Config.DefaultPoolRegion -Mandatory -Characters "A-Z" -Valid @(Get-Regions) | Foreach-Object {if ($Controls -icontains $_) {throw $_};$_}
                        }
                        "uistyle" {
                            if ($SetupType -eq "A") {
                                Write-Host ' '
                                Write-Host '(4) Select desired output' -ForegroundColor Green
                                Write-Host ' '
                            }

                            $Config.UIstyle = Read-HostString -Prompt "Select style of user interface (full/lite)" -Default $Config.UIstyle -Mandatory -Characters "A-Z" | Foreach-Object {if ($Controls -icontains $_) {throw $_};$_}
                            if ($Config.UIstyle -like "l*"){$Config.UIstyle="lite"}else{$Config.UIstyle="full"}   
                        }
                        "fastestmineronly" {
                            $Config.FastestMinerOnly = Read-HostBool -Prompt "Show fastest miner only" -Default $Config.FastestMinerOnly | Foreach-Object {if ($Controls -icontains $_) {throw $_};$_}
                        }
                        "enableheatmyflat" {
                            $Config.EnableHeatMyFlat = Read-HostInt -Prompt "Priorize heat over profit to heat my flat. Set intensity from 1 to 10, (0 to disable, 5 is a good point to start)" -Default $Config.EnableHeatMyFlat -Min 0 -Max 10 | Foreach-Object {if ($Controls -icontains $_) {throw $_};$_}
                        }
                        "enablealgorithmmapping" {
                            $Config.EnableAlgorithmMapping = Read-HostBool -Prompt "Show Equihash ','-numbers, instead of the RainbowMiner way" -Default $Config.EnableAlgorithmMapping | Foreach-Object {if ($Controls -icontains $_) {throw $_};$_}
                        }
                        "showpoolbalances" {
                            $Config.ShowPoolBalances = Read-HostBool -Prompt "Show all available pool balances" -Default $Config.ShowPoolBalances | Foreach-Object {if ($Controls -icontains $_) {throw $_};$_}
                        }
                        "showpoolbalancesdetails" {
                            if ($Config.ShowPoolBalances) {
                                $Config.ShowPoolBalancesDetails = Read-HostBool -Prompt "Show all at a pool mined coins as one extra row" -Default $Config.ShowPoolBalancesDetails | Foreach-Object {if ($Controls -icontains $_) {throw $_};$_}
                            } else {
                                $GlobalSetupStepStore = $false
                            }
                        }
                        "showpoolbalancesexcludedpools" {
                            if ($Config.ShowPoolBalances -and $Config.ExcludePoolName) {
                                $Config.ShowPoolBalancesExcludedPools = Read-HostBool -Prompt "Show balances from excluded pools, too" -Default $Config.ShowPoolBalancesExcludedPools | Foreach-Object {if ($Controls -icontains $_) {throw $_};$_}
                            } else {
                                $GlobalSetupStepStore = $false
                            }
                        }
                        "showminerwindow" {
                            $Config.ShowMinerWindow = Read-HostBool -Prompt "Show miner in own windows" -Default $Config.ShowMinerWindow | Foreach-Object {if ($Controls -icontains $_) {throw $_};$_}
                        }
                        "ignorefees" {
                            if ($SetupType -eq "A") {
                                Write-Host ' '
                                Write-Host '(5) Setup other / technical' -ForegroundColor Green
                                Write-Host ' '
                            }

                            $Config.IgnoreFees = Read-HostBool -Prompt "Ignore Pool/Miner developer fees" -Default $Config.IgnoreFees | Foreach-Object {if ($Controls -icontains $_) {throw $_};$_}
                        }
                        "watchdog" {
                            $Config.Watchdog = Read-HostBool -Prompt "Enable watchdog" -Default $Config.Watchdog | Foreach-Object {if ($Controls -icontains $_) {throw $_};$_}
                        }
                        "msia" {
                            $GlobalSetupStepStore = $false
                            if (-not $Config.EnableOCProfiles) {
                                $Config.MSIAprofile = Read-HostInt -Prompt "Enter default MSI Afterburner profile (0 to disable all MSI profile action)" -Default $Config.MSIAprofile -Min 0 -Max 5 | Foreach-Object {if ($Controls -icontains $_) {throw $_};$_}
                                $GlobalSetupStepStore = $true                                                
                            }
                        }
                        "msiapath" {
                            $GlobalSetupStepStore = $false
                            if (-not $Config.EnableOCProfiles -and $Config.MSIAprofile -gt 0) {
                                $Config.MSIApath = Read-HostString -Prompt "Enter path to MSI Afterburner" -Default $Config.MSIApath -Characters '' | Foreach-Object {if ($Controls -icontains $_) {throw $_};$_}
                                if (-not (Test-Path $Config.MSIApath)) {Write-Host "MSI Afterburner not found at given path. Please try again or disable.";throw "Goto msiapath"}
                                $GlobalSetupStepStore = $true
                            }
                        }
                        "nvsmipath" {
                            $GlobalSetupStepStore = $false
                            if ($Config.EnableOCProfiles -and ($Session.AllDevices | where-object vendor -eq "nvidia" | measure-object).count -gt 0) {
                                $Config.NVSMIpath = Read-HostString -Prompt "Enter path to Nvidia NVSMI" -Default $Config.NVSMIpath -Characters '' | Foreach-Object {if ($Controls -icontains $_) {throw $_};$_}
                                if (-not (Test-Path $Config.NVSMIpath)) {Write-Host "Nvidia NVSMI not found at given path. RainbowMiner will use included nvsmi" -ForegroundColor Yellow}
                                $GlobalSetupStepStore = $true
                            }
                        }
                        "ethpillenable" {
                            if ((Compare-Object @($SetupDevices.Model | Select-Object -Unique) @('GTX1080','GTX1080Ti','TITANXP') -ExcludeDifferent -IncludeEqual | Measure-Object).Count -gt 0) {
                                $Config.EthPillEnable = Read-HostString -Prompt "Enable OhGodAnETHlargementPill https://bitcointalk.org/index.php?topic=3370685.0 (when mining Ethash)" -Default $Config.EthPillEnable -Valid @('disable','RevA','RevB') | Foreach-Object {if ($Controls -icontains $_) {throw $_};$_}
                            } else {
                                $GlobalSetupStepStore = $false
                            }
                        }
                        "ethpillenablemtp" {
                            if ((Compare-Object @($SetupDevices.Model | Select-Object -Unique) @('GTX1080','GTX1080Ti','TITANXP') -ExcludeDifferent -IncludeEqual | Measure-Object).Count -gt 0) {
                                $Config.EthPillEnableMTP = Read-HostString -Prompt "Enable OhGodAnETHlargementPill https://bitcointalk.org/index.php?topic=3370685.0 (when mining MTP)" -Default $Config.EthPillEnableMTP -Valid @('disable','RevA','RevB') | Foreach-Object {if ($Controls -icontains $_) {throw $_};$_}
                            } else {
                                $GlobalSetupStepStore = $false
                            }
                        }
                        "enableocprofiles" {
                            $Config.EnableOCProfiles = Read-HostBool -Prompt "Enable custom overclocking profiles (MSI Afterburner profiles will be disabled)" -Default $Config.EnableOCProfiles | Foreach-Object {if ($Controls -icontains $_) {throw $_};$_}
                        }
                        "enableocvoltage" {
                            if ($Config.EnableOCProfiles) {
                                $Config.EnableOCVoltage = Read-HostBool -Prompt "Enable custom overclocking voltage setting" -Default $Config.EnableOCVoltage | Foreach-Object {if ($Controls -icontains $_) {throw $_};$_}
                            } else {
                                $GlobalSetupStepStore = $false
                            }
                        }
                        "enableautoupdate" {
                            $Config.EnableAutoUpdate = Read-HostBool -Prompt "Enable automatic update, as soon as a new release is published" -Default $Config.EnableAutoUpdate | Foreach-Object {if ($Controls -icontains $_) {throw $_};$_}
                        }
                        "enableautoalgorithmadd" {
                            $Config.EnableAutoAlgorithmAdd = Read-HostBool -Prompt "Automatically add new algorithms to config.txt during update" -Default $Config.EnableAutoAlgorithmAdd | Foreach-Object {if ($Controls -icontains $_) {throw $_};$_}
                        }
                        "enableautobenchmark" {
                            $Config.EnableAutoBenchmark = Read-HostBool -Prompt "Automatically start benchmarks of updated miners" -Default $Config.EnableAutoBenchmark | Foreach-Object {if ($Controls -icontains $_) {throw $_};$_}
                        }
                        "enableresetvega" {
                            if ($SetupDevices | Where-Object {$_.Vendor -eq "AMD" -and $_.Model -match "Vega"}) {
                                $Config.EnableResetVega = Read-HostBool -Prompt "Reset VEGA devices before miner (re-)start (needs admin privileges)" -Default $Config.EnableResetVega | Foreach-Object {if ($Controls -icontains $_) {throw $_};$_}
                            } else {
                                $GlobalSetupStepStore = $false
                            }
                        }
                        "proxy" {
                            $Config.Proxy = Read-HostString -Prompt "Enter proxy address, if used" -Default $Config.Proxy -Characters "A-Z0-9-\._~:/\?#\[\]@!\$&'\(\)\*\+,;=" | Foreach-Object {if ($Controls -icontains $_) {throw $_};$_}
                        }
                        "interval" {
                            $Config.Interval = Read-HostInt -Prompt "Enter the script's loop interval in seconds" -Default $Config.Interval -Mandatory -Min 30 | Foreach-Object {if ($Controls -icontains $_) {throw $_};$_}
                        }
                        "benchmarkinterval" {
                            $Config.BenchmarkInterval = Read-HostInt -Prompt "Enter the script's loop interval in seconds, used for benchmarks" -Default $Config.BenchmarkInterval -Mandatory -Min 60 | Foreach-Object {if ($Controls -icontains $_) {throw $_};$_}
                        }
                        "minimumminingintervals" {
                            $Config.MinimumMiningIntervals = Read-HostInt -Prompt "Minimum mining intervals, before the regular loop starts" -Default $Config.MinimumMiningIntervals -Mandatory -Min 1 | Foreach-Object {if ($Controls -icontains $_) {throw $_};$_}
                        }
                        "delay" {
                            $Config.Delay = Read-HostInt -Prompt "Enter the delay before each minerstart in seconds (set to a value > 0 if you experience BSOD)" -Default $Config.Delay -Min 0 -Max 10 | Foreach-Object {if ($Controls -icontains $_) {throw $_};$_}
                        }
                        "disableextendinterval" {
                            $Config.DisableExtendInterval = Read-HostBool -Prompt "Disable interval extension during benchmark (speeds benchmark up, but will be less accurate for some algorithm)" -Default $Config.DisableExtendInterval | Foreach-Object {if ($Controls -icontains $_) {throw $_};$_}
                        }
                        "switchingprevention" {
                            $Config.SwitchingPrevention = Read-HostInt -Prompt "Adjust switching prevention: the higher, the less switching of miners will happen (0 to disable)" -Default $Config.SwitchingPrevention -Min 0 -Max 10 | Foreach-Object {if ($Controls -icontains $_) {throw $_};$_}
                        }
                        "maxrejectedshareratio" {
                            Write-Host " "
                            Write-Host "Adjust the maximum failure rate"
                            Write-Host "Miner will be disabled, if their % of rejected shares grows larger than this number" -ForegroundColor Yellow                            
                         
                            $Config.MaxRejectedShareRatio = Read-HostDouble -Prompt "Maximum rejected share rate in %" -Default ($Config.MaxRejectedShareRatio*100) -Min 0 -Max 100 | Foreach-Object {if ($Controls -icontains $_) {throw $_};$_}
                            $Config.MaxRejectedShareRatio = $Config.MaxRejectedShareRatio / 100
                        }
                        "enablefastswitching" {
                            $Config.EnableFastSwitching = Read-HostBool -Prompt "Enable fast switching mode (expect frequent miner changes, not recommended)" -Default $Config.EnableFastSwitching | Foreach-Object {if ($Controls -icontains $_) {throw $_};$_}
                        }
                        "usetimesync" {
                            $Config.UseTimeSync = Read-HostBool -Prompt "Enable automatic time/NTP synchronization (needs admin rights)" -Default $Config.UseTimeSync | Foreach-Object {if ($Controls -icontains $_) {throw $_};$_}
                        }
                        "miningprioritycpu" {
                            $Config.MiningPriorityCPU = Read-HostInt -Prompt "Adjust CPU mining process priority (-2..3)" -Default $Config.MiningPriorityCPU -Min -2 -Max 3 | Foreach-Object {if ($Controls -icontains $_) {throw $_};$_}
                        }
                        "miningprioritygpu" {
                            $Config.MiningPriorityGPU = Read-HostInt -Prompt "Adjust GPU mining process priority (-2..3)" -Default $Config.MiningPriorityGPU -Min -2 -Max 3 | Foreach-Object {if ($Controls -icontains $_) {throw $_};$_}
                        }
                        "autoexecpriority" {
                            $Config.AutoexecPriority = Read-HostInt -Prompt "Adjust autoexec command's process priority (-2..3)" -Default $Config.AutoexecPriority -Min -2 -Max 3 | Foreach-Object {if ($Controls -icontains $_) {throw $_};$_}
                        }
                        "disablemsiamonitor" {
                            $Config.DisableMSIAmonitor = Read-HostBool -Prompt "Disable MSI Afterburner monitor/control" -Default $Config.DisableMSIAmonitor | Foreach-Object {if ($Controls -icontains $_) {throw $_};$_}
                        }
                        "disableapi" {
                            $Config.DisableAPI = Read-HostBool -Prompt "Disable localhost API" -Default $Config.DisableAPI | Foreach-Object {if ($Controls -icontains $_) {throw $_};$_}
                        }
                        "disableasyncloader" {
                            $Config.DisableAsyncLoader = Read-HostBool -Prompt "Disable asynchronous loader" -Default $Config.DisableAsyncLoader | Foreach-Object {if ($Controls -icontains $_) {throw $_};$_}
                        }
                        "powerpricecurrency" {
                            $Config.PowerPriceCurrency = Read-HostString -Prompt "Enter currency of power price (e.g. USD,EUR,CYN)" -Default $Config.PowerPriceCurrency -Characters "A-Z" | Foreach-Object {if ($Controls -icontains $_) {throw $_};$_}
                        }
                        "powerprice" {
                            $Config.PowerPrice = Read-HostDouble -Prompt "Enter the power price per kW/h (kilowatt per hour), you pay to your electricity supplier" -Default $Config.PowerPrice | Foreach-Object {if ($Controls -icontains $_) {throw $_};$_}
                        }
                        "poweroffset" {
                            $Config.PowerOffset = Read-HostDouble -Prompt "Optional: enter your rig's base power consumption (will be added during mining) " -Default $Config.PowerOffset | Foreach-Object {if ($Controls -icontains $_) {throw $_};$_}
                        }
                        "usepowerprice" {
                            $Config.UsePowerPrice = Read-HostBool -Prompt "Include cost of electricity into profit calculations" -Default $Config.UsePowerPrice | Foreach-Object {if ($Controls -icontains $_) {throw $_};$_}
                        }
                        "checkprofitability" {
                            $Config.CheckProfitability = Read-HostBool -Prompt "Check for profitability and stop mining, if no longer profitable." -Default $Config.CheckProfitability | Foreach-Object {if ($Controls -icontains $_) {throw $_};$_}
                        }
                        "quickstart" {
                            $Config.Quickstart = Read-HostBool -Prompt "Read all pool data from cache, instead of live upon start of RainbowMiner (useful with many coins in setup)" -Default $Config.Quickstart | Foreach-Object {if ($Controls -icontains $_) {throw $_};$_}
                        }
                        "startpaused" {
                            $Config.StartPaused = Read-HostBool -Prompt "Start RainbowMiner in pause mode (you will have to press P to start mining)" -Default $Config.StartPaused | Foreach-Object {if ($Controls -icontains $_) {throw $_};$_}
                        }
                        "loglevel" {
                            $Config.LogLevel = Read-HostString -Prompt "Enter logging level" -Default $Config.LogLevel -Valid @("Debug","Info","Warn","Error","Silent") | Foreach-Object {if ($Controls -icontains $_) {throw $_};$_}
                        }
                        "donate" {
                            $Config.Donate = [int]($(Read-HostDouble -Prompt "Enter the developer donation fee in %" -Default ([Math]::Round($Config.Donate/0.1440)/100) -Mandatory -Min 0.69 -Max 100)*14.40) | Foreach-Object {if ($Controls -icontains $_) {throw $_};$_}
                        }
                        "save" {
                            Write-Host " "
                            if (-not $DownloadServerNow) {
                                $ConfigSave = Read-HostBool -Prompt "Done! Do you want to save the changed values?" -Default $True | Foreach-Object {if ($Controls -icontains $_) {throw $_};$_}
                                if (-not $ConfigSave) {throw "cancel"}
                            }

                            $ConfigActual | Add-Member Wallet $Config.Wallet -Force
                            $ConfigActual | Add-Member WorkerName $Config.WorkerName -Force
                            $ConfigActual | Add-Member Proxy $Config.Proxy -Force
                            $ConfigActual | Add-Member Region $Config.Region -Force
                            $ConfigActual | Add-Member Currency $($Config.Currency -join ",") -Force
                            $ConfigActual | Add-Member PoolName $($Config.PoolName -join ",") -Force
                            $ConfigActual | Add-Member ExcludePoolName $($Config.ExcludePoolName -join ",") -Force
                            $ConfigActual | Add-Member MinerName $($Config.MinerName -join ",") -Force
                            $ConfigActual | Add-Member ExcludeMinerName $($Config.ExcludeMinerName -join ",") -Force
                            $ConfigActual | Add-Member Algorithm $($Config.Algorithm -join ",") -Force
                            $ConfigActual | Add-Member ExcludeAlgorithm $($Config.ExcludeAlgorithm -join ",") -Force
                            $ConfigActual | Add-Member DisableUnprofitableAlgolist $(if (Get-Yes $Config.DisableUnprofitableAlgolist){"1"}else{"0"}) -Force
                            $ConfigActual | Add-Member ExcludeCoin $($Config.ExcludeCoin -join ",") -Force
                            $ConfigActual | Add-Member ExcludeCoinSymbol $($Config.ExcludeCoinSymbol -join ",") -Force
                            $ConfigActual | Add-Member MiningMode $Config.MiningMode -Force
                            $ConfigActual | Add-Member MinComboOverSingleRatio $Config.MinComboOverSingleRatio -Force
                            $ConfigActual | Add-Member ShowPoolBalances $(if (Get-Yes $Config.ShowPoolBalances){"1"}else{"0"}) -Force
                            $ConfigActual | Add-Member ShowPoolBalancesDetails $(if (Get-Yes $Config.ShowPoolBalancesDetails){"1"}else{"0"}) -Force
                            $ConfigActual | Add-Member ShowPoolBalancesExcludedPools $(if (Get-Yes $Config.ShowPoolBalancesExcludedPools){"1"}else{"0"}) -Force
                            $ConfigActual | Add-Member ShowMinerWindow $(if (Get-Yes $Config.ShowMinerWindow){"1"}else{"0"}) -Force
                            $ConfigActual | Add-Member FastestMinerOnly $(if (Get-Yes $Config.FastestMinerOnly){"1"}else{"0"}) -Force
                            $ConfigActual | Add-Member EnableAlgorithmMapping $(if (Get-Yes $Config.EnableAlgorithmMapping){"1"}else{"0"}) -Force
                            $ConfigActual | Add-Member EnableHeatMyFlat $Config.EnableHeatMyFlat -Force
                            $ConfigActual | Add-Member UIstyle $Config.UIstyle -Force
                            $ConfigActual | Add-Member DeviceName $($Config.DeviceName -join ",") -Force
                            $ConfigActual | Add-Member ExcludeDeviceName $($Config.ExcludeDeviceName -join ",") -Force
                            $ConfigActual | Add-Member Interval $Config.Interval -Force
                            $ConfigActual | Add-Member BenchmarkInterval $Config.BenchmarkInterval -Force
                            $ConfigActual | Add-Member MinimumMiningIntervals $Config.MinimumMiningIntervals -Force
                            $ConfigActual | Add-Member DisableExtendInterval $(if (Get-Yes $Config.DisableExtendInterval){"1"}else{"0"}) -Force
                            $ConfigActual | Add-Member SwitchingPrevention $Config.SwitchingPrevention -Force
                            $ConfigActual | Add-Member MaxRejectedShareRatio $Config.MaxRejectedShareRatio -Force
                            $ConfigActual | Add-Member EnableFastSwitching $(if (Get-Yes $Config.EnableFastSwitching){"1"}else{"0"}) -Force
                            $ConfigActual | Add-Member Donate $Config.Donate -Force
                            $ConfigActual | Add-Member Watchdog $(if (Get-Yes $Config.Watchdog){"1"}else{"0"}) -Force
                            $ConfigActual | Add-Member IgnoreFees $(if (Get-Yes $Config.IgnoreFees){"1"}else{"0"}) -Force
                            $ConfigActual | Add-Member DisableDualMining $(if (Get-Yes $Config.DisableDualMining){"1"}else{"0"}) -Force
                            $ConfigActual | Add-Member EnableCheckMiningConflict $(if (Get-Yes $Config.EnableCheckMiningConflict){"1"}else{"0"}) -Force
                            $ConfigActual | Add-Member MSIAprofile $Config.MSIAprofile -Force
                            $ConfigActual | Add-Member MSIApath $Config.MSIApath -Force
                            $ConfigActual | Add-Member UseTimeSync $(if (Get-Yes $Config.UseTimeSync){"1"}else{"0"}) -Force
                            $ConfigActual | Add-Member MiningPriorityCPU $Config.MiningPriorityCPU -Force
                            $ConfigActual | Add-Member MiningPriorityGPU $Config.MiningPriorityGPU -Force
                            $ConfigActual | Add-Member AutoexecPriority $Config.AutoexecPriority -Force
                            $ConfigActual | Add-Member PowerPrice $Config.PowerPrice -Force
                            $ConfigActual | Add-Member PowerOffset $Config.PowerOffset -Force
                            $ConfigActual | Add-Member PowerPriceCurrency $Config.PowerPriceCurrency -Force
                            $ConfigActual | Add-Member UsePowerPrice $(if (Get-Yes $Config.UsePowerPrice){"1"}else{"0"}) -Force
                            $ConfigActual | Add-Member CheckProfitability $(if (Get-Yes $Config.CheckProfitability){"1"}else{"0"}) -Force
                            $ConfigActual | Add-Member EthPillEnable $Config.EthPillEnable -Force
                            $ConfigActual | Add-Member EthPillEnableMTP $Config.EthPillEnableMTP -Force
                            $ConfigActual | Add-Member EnableOCProfiles $(if (Get-Yes $Config.EnableOCProfiles){"1"}else{"0"}) -Force
                            $ConfigActual | Add-Member EnableOCVoltage $(if (Get-Yes $Config.EnableOCVoltage){"1"}else{"0"}) -Force
                            $ConfigActual | Add-Member EnableAutoupdate $(if (Get-Yes $Config.EnableAutoupdate){"1"}else{"0"}) -Force
                            $ConfigActual | Add-Member EnableAutoAlgorithmAdd $(if (Get-Yes $Config.EnableAutoAlgorithmAdd){"1"}else{"0"}) -Force
                            $ConfigActual | Add-Member EnableAutoBenchmark $(if (Get-Yes $Config.EnableAutoBenchmark){"1"}else{"0"}) -Force
                            $ConfigActual | Add-Member EnableResetVega $(if (Get-Yes $Config.EnableResetVega){"1"}else{"0"}) -Force
                            $ConfigActual | Add-Member Delay $Config.Delay -Force
                            $ConfigActual | Add-Member APIport $Config.APIport -Force
                            $ConfigActual | Add-Member APIauth $(if (Get-Yes $Config.APIauth){"1"}else{"0"}) -Force
                            $ConfigActual | Add-Member APIuser $Config.APIuser -Force
                            $ConfigActual | Add-Member APIpassword $Config.APIpassword -Force
                            $ConfigActual | Add-Member EnableAutoMinerPorts $(if (Get-Yes $Config.EnableAutoMinerPorts){"1"}else{"0"}) -Force
                            $ConfigActual | Add-Member DisableMSIAmonitor $(if (Get-Yes $Config.DisableMSIAmonitor){"1"}else{"0"}) -Force
                            $ConfigActual | Add-Member DisableAPI $(if (Get-Yes $Config.DisableAPI){"1"}else{"0"}) -Force
                            $ConfigActual | Add-Member DisableAsyncLoader $(if (Get-Yes $Config.DisableAsyncLoader){"1"}else{"0"}) -Force
                            $ConfigActual | Add-Member CPUMiningThreads $Config.CPUMiningThreads -Force
                            $ConfigActual | Add-Member CPUMiningAffinity $Config.CPUMiningAffinity -Force
                            $ConfigActual | Add-Member GPUMiningAffinity $Config.GPUMiningAffinity -Force
                            $ConfigActual | Add-Member PoolDataWindow $Config.PoolDataWindow -Force
                            $ConfigActual | Add-Member EnableErrorRatio $(if (Get-Yes $Config.EnableErrorRatio){"1"}else{"0"}) -Force
                            $ConfigActual | Add-Member PoolStatAverage $Config.PoolStatAverage -Force
                            $ConfigActual | Add-Member HashrateWeight $Config.HashrateWeight -Force
                            $ConfigActual | Add-Member HashrateWeightStrength $Config.HashrateWeightStrength -Force
                            $ConfigActual | Add-Member PoolAccuracyWeight $Config.PoolAccuracyWeight -Force
                            $ConfigActual | Add-Member DefaultPoolRegion $($Config.DefaultPoolRegion -join ",") -Force
                            $ConfigActual | Add-Member EnableMinerStatus $(if (Get-Yes $Config.EnableMinerStatus){"1"}else{"0"}) -Force
                            $ConfigActual | Add-Member MinerStatusUrl $Config.MinerStatusUrl -Force
                            $ConfigActual | Add-Member MinerStatusKey $Config.MinerStatusKey -Force
                            $ConfigActual | Add-Member MinerStatusEmail $Config.MinerStatusEmail -Force
                            $ConfigActual | Add-Member PushOverUserKey $Config.PushOverUserKey -Force
                            $ConfigActual | Add-Member NVSMIpath $Config.NVSMIpath -Force
                            $ConfigActual | Add-Member Quickstart $(if (Get-Yes $Config.Quickstart){"1"}else{"0"}) -Force
                            $ConfigActual | Add-Member StartPaused $(if (Get-Yes $Config.StartPaused){"1"}else{"0"}) -Force
                            $ConfigActual | Add-Member RunMode $Config.RunMode -Force
                            $ConfigActual | Add-Member ServerName $Config.ServerName -Force
                            $ConfigActual | Add-Member ServerPort $Config.ServerPort -Force
                            $ConfigActual | Add-Member ServerUser $Config.ServerUser -Force
                            $ConfigActual | Add-Member ServerPassword $Config.ServerPassword -Force
                            $ConfigActual | Add-Member EnableServerConfig $(if (Get-Yes $Config.EnableServerConfig){"1"}else{"0"}) -Force
                            $ConfigActual | Add-Member GroupName $Config.GroupName -Force
                            $ConfigActual | Add-Member ServerConfigName $($Config.ServerConfigName -join ",") -Force
                            $ConfigActual | Add-Member ExcludeServerConfigVars $($Config.ExcludeServerConfigVars -join ",") -Force
                            $ConfigActual | Add-Member EnableServerExcludeList $(if (Get-Yes $Config.EnableServerExcludeList){"1"}else{"0"}) -Force
                            $ConfigActual | Add-Member LogLevel $Config.LogLevel -Force

                            $ConfigActual | ConvertTo-Json | Out-File $ConfigFiles["Config"].Path -Encoding utf8

                            if ($DownloadServerNow) {
                                $GlobalSetupStepStore = $false
                                throw "Goto clientinit"
                            }

                            $CheckPools = @()
                            if (Get-Member -InputObject $PoolsActual -Name NiceHash) {
                                $PoolsActual.NiceHash | Add-Member BTC $(if($NicehashWallet -eq $Config.Wallet -or $NicehashWallet -eq ''){"`$Wallet"}else{$NicehashWallet}) -Force
                                $PoolsActual.NiceHash | Add-Member Platform $NicehashPlatform -Force
                                $PoolsActual.NiceHash | Add-Member OrganizationID $NicehashOrganizationID -Force
                                $PoolsActual.NiceHash | Add-Member API_Key $NicehashAPIKey -Force
                                $PoolsActual.NiceHash | Add-Member API_Secret $NicehashAPISecret -Force
                            } else {
                                $PoolsActual | Add-Member NiceHash ([PSCustomObject]@{
                                        BTC     = if($NicehashWallet -eq $Config.Wallet -or $NicehashWallet -eq ''){"`$Wallet"}else{$NicehashWallet}
                                        Platform = $NicehashPlatform
                                        OrganizationID = $NicehashOrganizationID
                                        API_Key = $NicehashAPIKey
                                        API_Secret = $NicehashAPISecret
                                }) -Force
                                $CheckPools += "NiceHash"
                            }

                            if (Get-Member -InputObject $PoolsActual -Name NiceHashV2) {
                                $PoolsActual.NiceHashV2 | Add-Member BTC $(if($NiceHashV2Wallet -eq $Config.Wallet){"`$Wallet"}else{$NiceHashV2Wallet}) -Force
                                $PoolsActual.NiceHashV2 | Add-Member OrganizationID $NiceHashV2OrganizationID -Force
                                $PoolsActual.NiceHashV2 | Add-Member API_Key $NiceHashV2APIKey -Force
                                $PoolsActual.NiceHashV2 | Add-Member API_Secret $NiceHashV2APISecret -Force
                            } else {
                                $PoolsActual | Add-Member NiceHashV2 ([PSCustomObject]@{
                                        BTC     = if($NiceHashV2Wallet -eq $Config.Wallet){"`$Wallet"}else{$NiceHashV2Wallet}
                                        OrganizationID = $NiceHashV2OrganizationID
                                        API_Key = $NiceHashV2APIKey
                                        API_Secret = $NiceHashV2APISecret
                                }) -Force
                                $CheckPools += "NiceHashV2"
                            }

                            if (Get-Member -InputObject $PoolsActual -Name MiningPoolHub) {
                                $PoolsActual.MiningPoolHub | Add-Member User $MPHUser -Force
                                $PoolsActual.MiningPoolHub | Add-Member API_ID $MPHAPIID -Force
                                $PoolsActual.MiningPoolHub | Add-Member API_Key $MPHAPIKey -Force
                            } else {
                                $PoolsActual | Add-Member MiningPoolHub ([PSCustomObject]@{
                                        User    = $MPHUser
                                        API_ID  = $MPHAPIID
                                        API_Key = $MPHAPIKey
                                }) -Force
                                $CheckPools += "MiningPoolHub"
                            }

                            if (Get-Member -InputObject $PoolsActual -Name MiningPoolHubCoins) {
                                $PoolsActual.MiningPoolHubCoins | Add-Member User $MPHUser -Force
                                $PoolsActual.MiningPoolHubCoins | Add-Member API_ID $MPHAPIID -Force
                                $PoolsActual.MiningPoolHubCoins | Add-Member API_Key $MPHAPIKey -Force
                            } else {
                                $PoolsActual | Add-Member MiningPoolHubCoins ([PSCustomObject]@{
                                        User    = $MPHUser
                                        API_ID  = $MPHAPIID
                                        API_Key = $MPHAPIKey
                                }) -Force
                                $CheckPools += "MiningPoolHubCoins"
                            }

                            if (Get-Member -InputObject $PoolsActual -Name MiningRigRentals) {
                                $PoolsActual.MiningRigRentals | Add-Member User $MRRUser -Force
                                $PoolsActual.MiningRigRentals | Add-Member API_Key $MRRAPIKey -Force
                                $PoolsActual.MiningRigRentals | Add-Member API_Secret $MRRAPISecret -Force
                            } else {
                                $PoolsActual | Add-Member MiningRigRentals ([PSCustomObject]@{
                                        User       = $MRRUser
                                        API_Key    = $MRRAPIKey
                                        API_Secret = $MRRAPISecret
                                }) -Force
                                $CheckPools += "MiningRigRentals"
                            }

                            $CheckPools | Foreach-Object {
                                $PoolName = $_
                                $PoolsSetup.$PoolName.Fields.PSObject.Properties | Where-Object {$PoolsActual.$PoolName.PSObject.Properties.Name -inotcontains $_.Name} | Foreach-Object {
                                    $PoolsActual.$PoolName | Add-Member $_.Name $_.Value  -Force
                                }
                                $PoolsDefault.PSObject.Properties | Where-Object {$PoolsActual.$PoolName.PSObject.Properties.Name -inotcontains $_.Name} | Foreach-Object {
                                    $PoolsActual.$PoolName | Add-Member $_.Name $_.Value  -Force
                                }
                            }

                            if ($IsInitialSetup -and $AutoAddCoins) {
                                $CoinsWithWallets | Foreach-Object {
                                    $Currency = $_
                                    $CoinsPools | Where-Object {($Config.PoolName -icontains $_.Pool) -and (-not $PoolsSetup."$($_.Pool)".Autoexchange -or $_.Pool -match "ZergPool") -and $_.Currencies -icontains $Currency} | Foreach-Object {
                                        if (-not $PoolsActual."$($_.Pool)".$Currency) {
                                            $PoolsActual."$($_.Pool)" | Add-Member $Currency "`$$Currency" -Force
                                        }
                                        if (-not $PoolsActual."$($_.Pool)"."$($Currency)-Params") {
                                            $PoolsActual."$($_.Pool)" | Add-Member "$($Currency)-Params" "" -Force
                                        }
                                    }
                                }
                            }

                            $PoolsActual  | ConvertTo-Json | Out-File $ConfigFiles["Pools"].Path -Encoding utf8

                            if ($IsInitialSetup) {
                                $SetupMessage.Add("Well done! You made it through the setup wizard - an initial configuration has been created ") > $null
                                if (-not $SetupOnly) {
                                    $SetupMessage.Add("If you want to start mining, please select to exit the configuration at the following prompt. After this, in the next minutes, RainbowMiner will download all miner programs. So please be patient and let it run. There will pop up some windows, from time to time. If you happen to click into one of those black popup windows, they will hang: press return in this window to resume operation") > $null
                                }
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
                    if ($Error.Count){$Error.RemoveAt(0)}
                    if (@("back","<") -icontains $_.Exception.Message) {
                        if ($GlobalSetupStepBack.Count) {$GlobalSetupStep = $GlobalSetupStepBack[$GlobalSetupStepBack.Count-1];$GlobalSetupStepBack.RemoveAt($GlobalSetupStepBack.Count-1)}
                    }
                    elseif (@("exit","cancel") -icontains $_.Exception.Message) {
                        Write-Host " "
                        Write-Host "Cancelled without changing the configuration" -ForegroundColor Red
                        Write-Host " "
                        $GlobalSetupDone = $true
                        $ReReadConfig = -not $SetupOnly -or -not $IsInitialSetup
                    }
                    else {
                        if ($GlobalSetupStepStore) {$GlobalSetupStepBack.Add($GlobalSetupStep) > $null}
                        $NextSetupStep = Switch -Regex ($_.Exception.Message) {
                                            "^Goto\s+(.+)$" {$Matches[1]}
                                            "^done$"  {"save"}
                                            default {$_}
                                        }
                        $GlobalSetupStep = $GlobalSetupSteps.IndexOf($NextSetupStep)
                        if ($GlobalSetupStep -lt 0) {
                            Write-Log -Level Error "Unknown goto command `"$($NextSetupStep)`". You should never reach here. Please open an issue on github.com"
                            $GlobalSetupStep = $GlobalSetupStepBack[$GlobalSetupStepBack.Count-1];$GlobalSetupStepBack.RemoveAt($GlobalSetupStepBack.Count-1)
                        }
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
            $AvailDeviceName.AddRange(@($SetupDevices | Foreach-Object {$_.Type.ToUpper();if ($Config.MiningMode -eq "legacy") {if (@("nvidia","amd") -icontains $_.Vendor) {$_.Vendor}} else {if (@("nvidia","amd") -icontains $_.Vendor) {$_.Vendor;$_.Model};$_.Name}} | Select-Object -Unique | Sort-Object))
                            
            $MinerSetupDone = $false
            do {             
                $MinersActual = Get-Content $ConfigFiles["Miners"].Path | ConvertFrom-Json                                                     
                $MinerSetupStepsDone = $false
                $MinerSetupStep = 0
                [System.Collections.ArrayList]$MinerSetupSteps = @()
                [System.Collections.ArrayList]$MinerSetupStepBack = @()
                                                                    
                $MinerSetupSteps.AddRange(@("minername","devices","algorithm","secondaryalgorithm","configure","params","ocprofile","msiaprofile","difficulty","extendinterval","faulttolerance","penalty","disable")) > $null                                    
                $MinerSetupSteps.Add("save") > $null                         

                do { 
                    try {
                        $MinerSetupStepStore = $true
                        Switch ($MinerSetupSteps[$MinerSetupStep]) {
                            "minername" {                                                    
                                $Miner_Name = Read-HostString -Prompt "Which miner do you want to configure? (leave empty to end miner config)" -Characters "A-Z0-9.-_" -Valid $Session.AvailMiners | Foreach-Object {if ($Controls -icontains $_) {throw $_};$_}
                                if ($Miner_Name -eq '') {throw "cancel"}
                            }
                            "devices" {
                                if ($Config.MiningMode -eq "Legacy") {
                                    $EditDeviceName = Read-HostString -Prompt ".. running on which devices (amd/nvidia/cpu)? (enter `"*`" for all or leave empty to end miner config)" -Characters "A-Z\*" -Valid $AvailDeviceName | Foreach-Object {if ($Controls -icontains $_) {throw $_};$_}
                                    if ($EditDeviceName -eq '') {throw "cancel"}
                                } else {
                                    [String[]]$EditDeviceName_Array = Read-HostArray -Prompt ".. running on which device(s)? (enter `"*`" for all or leave empty to end miner config)" -Characters "A-Z0-9#\*" -Valid $AvailDeviceName | Foreach-Object {if ($Controls -icontains $_) {throw $_};$_}
                                    ForEach ($EditDevice0 in @("nvidia","amd","cpu")) {
                                        if ($EditDeviceName_Array -icontains $EditDevice0) {
                                            $EditDeviceName_Array = @($SetupDevices | Where-Object {$_.Vendor -eq $EditDevice0 -and $_.Type -eq "gpu" -or $_.Type -eq $EditDevice0} | Select-Object -ExpandProperty Model -Unique | Sort-Object)
                                            break
                                        }
                                    }
                                    [String]$EditDeviceName = @($EditDeviceName_Array) -join '-'
                                    if ($EditDeviceName -eq '') {throw "cancel"}
                                }
                            }
                            "algorithm" {
                                $EditAlgorithm = Read-HostString -Prompt ".. calculating which main algorithm? (enter `"*`" for all or leave empty to end miner config)" -Characters "A-Z0-9\*" | Foreach-Object {if ($Controls -icontains $_) {throw $_};$_}
                                if ($EditAlgorithm -eq '') {throw "cancel"}
                                elseif ($EditAlgorithm -ne "*") {$EditAlgorithm = Get-Algorithm $EditAlgorithm}
                            }
                            "secondaryalgorithm" {
                                $EditSecondaryAlgorithm = Read-HostString -Prompt ".. calculating which secondary algorithm?" -Characters "A-Z0-9" | Foreach-Object {if ($Controls -icontains $_) {throw $_};$_}
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
                                    Difficulty = ""
                                    Disable = "0"
                                }
                        
                                if (Get-Member -InputObject $MinersActual -Name $EditMinerName -Membertype Properties) {$MinersActual.$EditMinerName | Where-Object {$_.MainAlgorithm -eq $EditAlgorithm -and $_.SecondaryAlgorithm -eq $EditSecondaryAlgorithm} | Foreach-Object {foreach ($p in @($_.PSObject.Properties.Name)) {$EditMinerConfig | Add-Member $p $_.$p -Force}}}
                                $MinerSetupStepStore = $false
                            }
                            "params" {
                                $EditMinerConfig.Params = Read-HostString -Prompt "Additional command line parameters" -Default $EditMinerConfig.Params -Characters " -~" | Foreach-Object {if ($Controls -icontains $_) {throw $_};$_}
                            }
                            "ocprofile" {
                                $MinerSetupStepStore = $false
                                if (Get-Yes $Config.EnableOCProfiles) {
                                    $EditMinerConfig.OCprofile = Read-HostString -Prompt "Custom overclocking profile ($(if ($EditMinerConfig.OCprofile) {"clear"} else {"leave empty"}) for none)" -Default $EditMinerConfig.OCprofile -Valid @($OCProfilesActual.PSObject.Properties.Name) | Foreach-Object {if ($Controls -icontains $_) {throw $_};$_}
                                    $MinerSetupStepStore = $true
                                }
                            }
                            "msiaprofile" {
                                $MinerSetupStepStore = $false
                                if (-not (Get-Yes $Config.EnableOCProfiles)) {
                                    $EditMinerConfig.MSIAprofile = Read-HostString -Prompt "MSI Afterburner Profile" -Default $EditMinerConfig.MSIAprofile -Characters "012345" -Length 1 | Foreach-Object {if ($Controls -icontains $_) {throw $_};$_}
                                    if ($EditMinerConfig.MSIAprofile -eq "0") {$EditMinerConfig.MSIAprofile = ""}
                                    $MinerSetupStepStore = $true
                                }
                            }
                            "difficulty" {
                                $EditMinerConfig.Difficulty = Read-HostDouble -Prompt "Set static difficulty ($(if ($EditMinerConfig.Difficulty) {"clear"} else {"leave empty"}) or set to 0 for automatic)" -Default $EditMinerConfig.Difficulty | Foreach-Object {if ($Controls -icontains $_) {throw $_};$_}
                                $EditMinerConfig.Difficulty = $EditMinerConfig.Difficulty -replace ",","." -replace "[^\d\.]+"
                            }
                            "extendinterval" {
                                $EditMinerConfig.ExtendInterval = Read-HostInt -Prompt "Extend interval for X times" -Default ([int]$EditMinerConfig.ExtendInterval) -Min 0 -Max 10 | Foreach-Object {if ($Controls -icontains $_) {throw $_};$_}
                            }
                            "faulttolerance" {
                                $EditMinerConfig.FaultTolerance = Read-HostDouble -Prompt "Use fault tolerance in %" -Default ([double]$EditMinerConfig.FaultTolerance) -Min 0 -Max 100 | Foreach-Object {if ($Controls -icontains $_) {throw $_};$_}
                            }
                            "penalty" {
                                $EditMinerConfig.Penalty = Read-HostDouble -Prompt "Use a penalty in % (enter -1 to not change penalty)" -Default $(if ($EditMinerConfig.Penalty -eq ''){-1}else{$EditMinerConfig.Penalty}) -Min -1 -Max 100 | Foreach-Object {if ($Controls -icontains $_) {throw $_};$_}
                                if ($EditMinerConfig.Penalty -lt 0) {$EditMinerConfig.Penalty=""}
                            }
                            "disable" {
                                $MinerSetupStepStore = $false
                                if ($EditAlgorithm -ne '*') {
                                    $EditMinerConfig.Disable = Read-HostBool -Prompt "Disable $EditAlgorithm$(if ($EditSecondaryAlgorithm) {"-$EditSecondaryAlgorithm"}) on $EditMinerName" -Default $EditMinerConfig.Disable | Foreach-Object {if ($Controls -icontains $_) {throw $_};$_}
                                    $MinerSetupStepStore = $true
                                }
                                $EditMinerConfig.Disable = if (Get-Yes $EditMinerConfig.Disable) {"1"} else {"0"}
                            }
                            "save" {
                                Write-Host " "
                                if (-not (Read-HostBool "Really write entered values to $($ConfigFiles["Miners"].Path)?" | Foreach-Object {if ($Controls -icontains $_) {throw $_};$_})) {throw "cancel"}
                                $MinersActual | Add-Member $EditMinerName -Force (@($MinersActual.$EditMinerName | Where-Object {$_.MainAlgorithm -ne $EditAlgorithm -or $_.SecondaryAlgorithm -ne $EditSecondaryAlgorithm} | Select-Object)+@($EditMinerConfig))

                                $MinersActualSave = [PSCustomObject]@{}
                                $MinersActual.PSObject.Properties.Name | Sort-Object | Foreach-Object {$MinersActualSave | Add-Member $_ @($MinersActual.$_ | Sort-Object MainAlgorithm,SecondaryAlgorithm)}
                                Set-ContentJson -PathToFile $ConfigFiles["Miners"].Path -Data $MinersActualSave > $null

                                Write-Host " "
                                Write-Host "Changes written to Miner configuration. " -ForegroundColor Cyan
                                                    
                                $MinerSetupStepsDone = $true                                                  
                            }
                        }
                        if ($MinerSetupStepStore) {$MinerSetupStepBack.Add($MinerSetupStep) > $null}                                                
                        $MinerSetupStep++
                    }
                    catch {
                        if ($Error.Count){$Error.RemoveAt(0)}
                        if (@("back","<") -icontains $_.Exception.Message) {
                            if ($MinerSetupStepBack.Count) {$MinerSetupStep = $MinerSetupStepBack[$MinerSetupStepBack.Count-1];$MinerSetupStepBack.RemoveAt($MinerSetupStepBack.Count-1)}
                        }
                        elseif (@("exit","cancel") -icontains $_.Exception.Message) {
                            Write-Host " "
                            Write-Host "Cancelled without changing the configuration" -ForegroundColor Red
                            Write-Host " "
                            $MinerSetupStepsDone = $true                                               
                        }
                        else {
                            if ($MinerSetupStepStore) {$MinerSetupStepBack.Add($MinerSetupStep) > $null}
                            $NextSetupStep = Switch -Regex ($_.Exception.Message) {
                                                "^Goto\s+(.+)$" {$Matches[1]}
                                                "^done$"  {"save"}
                                                default {$_}
                                            }
                            $MinerSetupStep = $MinerSetupSteps.IndexOf($NextSetupStep)
                            if ($MinerSetupStep -lt 0) {
                                Write-Log -Level Error "Unknown goto command `"$($NextSetupStep)`". You should never reach here. Please open an issue on github.com"
                                $MinerSetupStep = $MinerSetupStepBack[$MinerSetupStepBack.Count-1];$MinerSetupStepBack.RemoveAt($MinerSetupStepBack.Count-1)
                            }
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

            Set-ConfigDefault "Pools" -Force > $null

            $PoolSetupDone = $false
            do {
                try {
                    $PoolsActual = Get-Content $ConfigFiles["Pools"].Path | ConvertFrom-Json
                    $CoinsActual = Get-Content $ConfigFiles["Coins"].Path | ConvertFrom-Json
                    $Pool_Name = Read-HostString -Prompt "Which pool do you want to configure? (leave empty to end pool config)" -Characters "A-Z0-9" -Valid $Session.AvailPools | Foreach-Object {if ($Controls -icontains $_) {throw $_};$_}
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
                        if ($Pool_Name -eq "NiceHashV2") {$PoolsActual.$Pool_Name.BTC = ""}
                        Set-ContentJson -PathToFile $ConfigFiles["Pools"].Path -Data $PoolsActual > $null
                    }

                    $Pool = Get-PoolsInfo $Pool_Name

                    if ($Pool) {
                        $PoolSetupStepsDone = $false
                        $PoolSetupStep = 0
                        $PoolSetupFields = @{}
                        [System.Collections.ArrayList]$PoolSetupSteps = @()
                        [System.Collections.ArrayList]$PoolSetupStepBack = @()

                        $IsYiimpPool = $PoolsSetup.$Pool_Name.Yiimp

                        $PoolConfig = $PoolsActual.$Pool_Name.PSObject.Copy()

                        $Pool_Avail_Currency = @($Pool.Currency | Select-Object -Unique | Sort-Object)
                        $Pool_Avail_CoinName = @($Pool | Foreach-Object {@($_.CoinName | Select-Object) -join ' '} | Select-Object -Unique | Where-Object {$_} | Sort-Object)
                        $Pool_Avail_CoinSymbol = @($Pool | Where CoinSymbol | Foreach-Object {@($_.CoinSymbol | Select-Object) -join ' '} | Select-Object -Unique | Sort-Object)

                        if ($PoolsSetup.$Pool_Name.Currencies -and $PoolsSetup.$Pool_Name.Currencies.Count -gt 0) {$PoolSetupSteps.Add("currency") > $null}
                        $PoolSetupSteps.AddRange(@("basictitle","worker")) > $null
                        $PoolsSetup.$Pool_Name.SetupFields.PSObject.Properties.Name | Select-Object | Foreach-Object {$k=($_ -replace "[^A-Za-z0-1]+").ToLower();$PoolSetupFields[$k] = $_;$PoolSetupSteps.Add($k) > $null}
                        $PoolSetupSteps.AddRange(@("penalty","allowzero","enableautocoin","enablepostblockmining","algorithmtitle","algorithm","excludealgorithm","coinsymbol","excludecoinsymbol","coinsymbolpbm","coinname","excludecoin","minername","excludeminername","stataverage")) > $null
                        if ($IsYiimpPool) {$PoolSetupSteps.AddRange(@("datawindow")) > $null}
                        if ($PoolsSetup.$Pool_Name.Currencies -and $PoolsSetup.$Pool_Name.Currencies.Count -gt 0 -and $Pool_Avail_Currency.Count -gt 0 -and $Pool_Name -notmatch "miningpoolhub") {$PoolSetupSteps.Add("focuswallet") > $null}
                        $PoolSetupSteps.Add("save") > $null                                        

                        $PoolsSetup.$Pool_Name.Fields.PSObject.Properties.Name | Select-Object | Foreach-Object {                                                                                
                            if ($PoolConfig.PSObject.Properties.Name -inotcontains $_) {$PoolConfig | Add-Member $_ ($PoolsSetup.$Pool_Name.Fields.$_) -Force}
                        }
                        foreach($SetupName in $PoolsDefault.PSObject.Properties.Name) {if ($PoolConfig.$SetupName -eq $null){$PoolConfig | Add-Member $SetupName $PoolsDefault.$SetupName -Force}}

                        if ($IsYiimpPool -and $PoolConfig.PSObject.Properties.Name -inotcontains "DataWindow") {$PoolConfig | Add-Member DataWindow "" -Force}  
                                        
                        do {
                            $PoolSetupStepStore = $true
                            try {
                                Switch ($PoolSetupSteps[$PoolSetupStep]) {
                                    "basictitle" {
                                        Write-Host " "
                                        Write-Host "*** Edit pool's basic settings ***" -ForegroundColor Green
                                        Write-Host " "
                                        $PoolSetupStepStore = $false
                                    }
                                    "algorithmtitle" {
                                        Write-Host " "
                                        Write-Host "*** Edit pool's algorithms, coins and miners ***" -ForegroundColor Green
                                        Write-Host " "
                                        $PoolSetupStepStore = $false
                                    }
                                    "aecurrency" {
                                        $PoolConfig.AECurrency = Read-HostString -Prompt $PoolsSetup.$Pool_Name.SetupFields.AECurrency -Default $PoolConfig.AECurrency -Characters "A-Z0-9" | Foreach-Object {if ($Controls -icontains $_) {throw $_};$_} 
                                        if ($PoolConfig.AECurrency.Trim() -eq '') {$PoolConfig.AECurrency = $PoolsSetup.$Pool_Name.Fields.AECurrency}
                                    }
                                    "algorithm" {
                                        $PoolConfig.Algorithm = Read-HostArray -Prompt "Enter algorithms you want to mine ($(if ($PoolConfig.Algorithm) {"clear"} else {"leave empty"}) for all)" -Default $PoolConfig.Algorithm -Characters "A-Z0-9" | Foreach-Object {if ($Controls -icontains $_) {throw $_};$_}
                                    }
                                    "allowzero" {                                                    
                                        $PoolConfig.AllowZero = Read-HostBool -Prompt "Allow mining an alogorithm, even if the pool hashrate equals 0 (not recommended, except for solo or coin mining)" -Default $PoolConfig.AllowZero | Foreach-Object {if ($Controls -icontains $_) {throw $_};$_}
                                    }
                                    "apiid" {
                                        $PoolConfig.API_ID = Read-HostString -Prompt $PoolsSetup.$Pool_Name.SetupFields.API_ID -Default ($PoolConfig.API_ID -replace "^\`$.+") -Characters "A-Z0-9" | Foreach-Object {if ($Controls -icontains $_) {throw $_};$_} 
                                        if ($PoolConfig.API_ID.Trim() -eq '') {$PoolConfig.API_ID = $PoolsSetup.$Pool_Name.Fields.API_ID}
                                    }
                                    "apikey" {
                                        $PoolConfig.API_Key = Read-HostString -Prompt $PoolsSetup.$Pool_Name.SetupFields.API_Key -Default ($PoolConfig.API_Key -replace "^\`$.+") -Characters "A-Z0-9" | Foreach-Object {if ($Controls -icontains $_) {throw $_};$_} 
                                        if ($PoolConfig.API_Key.Trim() -eq '') {$PoolConfig.API_Key = $PoolsSetup.$Pool_Name.Fields.API_Key}
                                    }
                                    "apisecret" {
                                        $PoolConfig.API_Secret = Read-HostString -Prompt $PoolsSetup.$Pool_Name.SetupFields.API_Secret -Default ($PoolConfig.API_Secret -replace "^\`$.+") -Characters "A-Z0-9" | Foreach-Object {if ($Controls -icontains $_) {throw $_};$_} 
                                        if ($PoolConfig.API_Secret.Trim() -eq '') {$PoolConfig.API_Secret = $PoolsSetup.$Pool_Name.Fields.API_Secret}
                                    }
                                    "coinname" {
                                        if ($Pool_Avail_CoinName) {
                                            $PoolConfig.CoinName = Read-HostArray -Prompt "Enter coins by name, you want to mine ($(if ($PoolConfig.CoinName) {"clear"} else {"leave empty"}) for all)" -Default $PoolConfig.CoinName -Characters "`$A-Z0-9. " -Valid $Pool_Avail_CoinName | Foreach-Object {if ($Controls -icontains $_) {throw $_};$_}
                                        } else {
                                            $PoolSetupStepStore = $false
                                        }
                                    }
                                    "coinsymbol" {
                                        if ($Pool_Avail_CoinSymbol) {
                                            $PoolConfig.CoinSymbol = Read-HostArray -Prompt "Enter coins by currency-symbol, you want to mine ($(if ($PoolConfig.CoinSymbol) {"clear"} else {"leave empty"}) for all)" -Default $PoolConfig.CoinSymbol -Characters "`$A-Z0-9" -Valid $Pool_Avail_CoinSymbol | Foreach-Object {if ($Controls -icontains $_) {throw $_};$_}
                                        } else {
                                            $PoolSetupStepStore = $false
                                        }
                                    }
                                    "coinsymbolpbm" {
                                        if ($Pool_Avail_CoinSymbol) {
                                            $PoolConfig.CoinSymbolPBM = Read-HostArray -Prompt "Enter coins by currency-symbol, to be included if Postblockmining, only " -Default $PoolConfig.CoinSymbolPBM -Characters "`$A-Z0-9" -Valid $Pool_Avail_CoinSymbol | Foreach-Object {if ($Controls -icontains $_) {throw $_};$_}
                                        } else {
                                            $PoolSetupStepStore = $false
                                        }
                                    }
                                    "currency" {
                                        $PoolEditCurrencyDone = $false
                                        Write-Host " "
                                        Write-Host "*** Define your wallets and password params for this pool ***" -ForegroundColor Green
                                        do {
                                            $Pool_Actual_Currency = @((Get-PoolPayoutCurrencies $PoolConfig).PSObject.Properties.Name | Sort-Object)
                                            Write-Host " "
                                            if ($Pool_Actual_Currency.Count -gt 0) {
                                                Write-Host "Currently defined wallets:" -ForegroundColor Cyan
                                                foreach ($p in $Pool_Actual_Currency) {
                                                    $v = $PoolConfig.$p
                                                    if ($v -eq "`$Wallet") {$v = "default (wallet $($Config.Wallet) from your config.txt)"}
                                                    elseif ($v -eq "`$$p") {$v = "default (wallet $($CoinsActual.$p.Wallet) from your coins.config.txt)"}
                                                    Write-Host "$p = $v" -ForegroundColor Cyan
                                                }
                                            } else {
                                                Write-Host "No wallets defined!" -ForegroundColor Yellow
                                            }
                                            Write-Host " "
                                            $PoolEditCurrency = Read-HostString -Prompt "Enter the currency you want to edit, add or remove (leave empty to end wallet configuration)" -Characters "A-Z0-9" -Valid $Pool_Avail_Currency | Foreach-Object {if ($Controls -icontains $_) {throw $_};$_}
                                            $PoolEditCurrency = $PoolEditCurrency.Trim()
                                            if ($PoolEditCurrency -ne "") {
                                                do {
                                                    $CurrencyEntryDone = $true
                                                    $v = $PoolConfig.$PoolEditCurrency
                                                    $params = $PoolConfig."$($PoolEditCurrency)-Params"
                                                    if ($v -eq "`$Wallet" -or (-not $v -and $PoolEditCurrency -eq "BTC") -or $v -eq "`$$PoolEditCurrency") {$v = "default"}
                                                    elseif ($v -eq "`$$PoolEditCurrency") {$v = "default";$t = "coins.config.txt"}
                                                    $v = Read-HostString -Prompt "Enter your wallet address for $PoolEditCurrency (enter `"remove`" to remove this currency, `"default`" to always use current default wallet from your $(if ($PoolEditCurrency -ne "BTC") {"coins."})config.txt)" -Default $v -Characters "A-Z0-9-\._~:/\?#\[\]@!\$&'\(\)\*\+,;=" | Foreach-Object {if (@("cancel","exit") -icontains $_) {throw $_};$_}
                                                    $v = $v.Trim()
                                                    if (@("back","<") -inotcontains $v) {
                                                        if (@("del","delete","remove","clear","rem") -icontains $v) {
                                                            if (@($PoolConfig.PSObject.Properties.Name) -icontains $PoolEditCurrency) {$PoolConfig.PSObject.Properties.Remove($PoolEditCurrency)}
                                                            if (@($PoolConfig.PSObject.Properties.Name) -icontains "$($PoolEditCurrency)-Params") {$PoolConfig.PSObject.Properties.Remove("$($PoolEditCurrency)-Params")}
                                                        } else {
                                                            if (@("def","default","wallet","standard") -icontains $v) {$v = "`$$(if ($PoolEditCurrency -eq "BTC") {"Wallet"} else {$PoolEditCurrency})"}
                                                            $PoolConfig | Add-Member $PoolEditCurrency $v -Force
                                                            $params = Read-HostString -Prompt "Enter additional password parameters for $PoolEditCurrency" -Default $params -Characters $false | Foreach-Object {if (@("cancel","exit") -icontains $_) {throw $_};$_}
                                                            if (@("back","<") -inotcontains $params) {
                                                                $PoolConfig | Add-Member "$($PoolEditCurrency)-Params" "$($params)" -Force
                                                            } else {
                                                                $CurrencyEntryDone = $false
                                                            }
                                                        }
                                                    }
                                                } until ($CurrencyEntryDone)
                                            } else {
                                                $PoolEditCurrencyDone = $true
                                            }

                                        } until ($PoolEditCurrencyDone)                                                                                                          
                                    }
                                    "datawindow" {
                                        Write-Host " "
                                        Write-Host "*** Define the pool's datawindow ***" -ForegroundColor Green

                                        Write-HostSetupDataWindowHints
                                        $PoolConfig.DataWindow = Read-HostString -Prompt "Enter which datawindow is to be used for this pool ($(if ($PoolConfig.DataWindow) {"clear"} else {"leave empty"}) for default)" -Default $PoolConfig.DataWindow -Characters "A-Z0-9_-" | Foreach-Object {if ($Controls -icontains $_) {throw $_};$_}                                        
                                    }
                                    "description" {
                                        $PoolConfig.Description = Read-HostString -Prompt $PoolsSetup.$Pool_Name.SetupFields.Description -Default $PoolConfig.Description -Characters "" | Foreach-Object {if ($Controls -icontains $_) {throw $_};$_}
                                    }
                                    "email" {
                                        $PoolConfig.Email = Read-HostString -Prompt $PoolsSetup.$Pool_Name.SetupFields.Email -Default $PoolConfig.Email -Characters "A-Z0-9-\._~:/\?#\[\]@!\$&'\(\)\*\+,;=" | Foreach-Object {if ($Controls -icontains $_) {throw $_};$_}
                                    }
                                    "enableautocoin" {
                                        $PoolConfig.EnableAutoCoin = Read-HostBool -Prompt "Automatically add currencies that are activated in coins.config.txt with EnableAutoPool=`"1`"" -Default $PoolConfig.EnableAutoCoin | Foreach-Object {if ($Controls -icontains $_) {throw $_};$_}
                                    }
                                    "enableautocreate" {
                                        $PoolConfig.EnableAutoCreate = Read-HostBool -Prompt $PoolsSetup.$Pool_Name.SetupFields.EnableAutoCreate -Default $PoolConfig.EnableAutoCreate | Foreach-Object {if ($Controls -icontains $_) {throw $_};$_}
                                        $PoolConfig.EnableAutoCreate = if ($PoolConfig.EnableAutoCreate) {"1"} else {"0"}
                                    }
                                    "enableautoprice" {
                                        $PoolConfig.EnableAutoPrice = Read-HostBool -Prompt $PoolsSetup.$Pool_Name.SetupFields.EnableAutoPrice -Default $PoolConfig.EnableAutoPrice | Foreach-Object {if ($Controls -icontains $_) {throw $_};$_}
                                        $PoolConfig.EnableAutoPrice = if ($PoolConfig.EnableAutoPrice) {"1"} else {"0"}
                                    }
                                    "enableminimumprice" {
                                        $PoolConfig.EnableMinimumPrice = Read-HostBool -Prompt $PoolsSetup.$Pool_Name.SetupFields.EnableMinimumPrice -Default $PoolConfig.EnableMinimumPrice | Foreach-Object {if ($Controls -icontains $_) {throw $_};$_}
                                        $PoolConfig.EnableMinimumPrice = if ($PoolConfig.EnableMinimumPrice) {"1"} else {"0"}
                                    }
                                    "enablemining" {
                                        $PoolConfig.EnableMining = Read-HostBool -Prompt $PoolsSetup.$Pool_Name.SetupFields.EnableMining -Default $PoolConfig.EnableMining | Foreach-Object {if ($Controls -icontains $_) {throw $_};$_}
                                        $PoolConfig.EnableMining = if ($PoolConfig.EnableMining) {"1"} else {"0"}
                                    }
                                    "enablepostblockmining" {
                                        $PoolConfig.EnablePostBlockMining = Read-HostBool -Prompt "Enable forced mining a currency for a timespan after a block has been found (activate in coins.config.txt with PostBlockMining > 0)" -Default $PoolConfig.EnablePostBlockMining | Foreach-Object {if ($Controls -icontains $_) {throw $_};$_}
                                    }
                                    "enablepriceupdates" {
                                        $PoolConfig.EnablePriceUpdates = Read-HostBool -Prompt $PoolsSetup.$Pool_Name.SetupFields.EnablePriceUpdates -Default $PoolConfig.EnablePriceUpdates | Foreach-Object {if ($Controls -icontains $_) {throw $_};$_}
                                        $PoolConfig.EnablePriceUpdates = if ($PoolConfig.EnablePriceUpdates) {"1"} else {"0"}
                                    }
                                    "excludealgorithm" {
                                        $PoolConfig.ExcludeAlgorithm = Read-HostArray -Prompt "Enter algorithms you do want to exclude " -Default $PoolConfig.ExcludeAlgorithm -Characters "A-Z0-9" | Foreach-Object {if ($Controls -icontains $_) {throw $_};$_}
                                    }
                                    "excludecoin" {
                                        if ($Pool_Avail_CoinName) {
                                            $PoolConfig.ExcludeCoin = Read-HostArray -Prompt "Enter coins by name, you do want to exclude " -Default $PoolConfig.ExcludeCoin -Characters "`$A-Z0-9. " -Valid $Pool_Avail_CoinName | Foreach-Object {if ($Controls -icontains $_) {throw $_};$_}
                                        } else {
                                            $PoolSetupStepStore = $false
                                        }
                                    }
                                    "excludecoinsymbol" {
                                        if ($Pool_Avail_CoinSymbol) {
                                            $PoolConfig.ExcludeCoinSymbol = Read-HostArray -Prompt "Enter coins by currency-symbol, you do want to exclude " -Default $PoolConfig.ExcludeCoinSymbol -Characters "`$A-Z0-9" -Valid $Pool_Avail_CoinSymbol | Foreach-Object {if ($Controls -icontains $_) {throw $_};$_}
                                        } else {
                                            $PoolSetupStepStore = $false
                                        }
                                    }
                                    "excludeminername" {
                                        $PoolConfig.ExcludeMinerName = Read-HostArray -Prompt "Enter the miners you do want to exclude" -Default $PoolConfig.ExcludeMinerName -Characters "A-Z0-9\.-_" -Valid $Session.AvailMiners | Foreach-Object {if ($Controls -icontains $_) {throw $_};$_}
                                    }
                                    "focuswallet" {
                                        $Pool_Actual_Currency = @((Get-PoolPayoutCurrencies $PoolConfig).PSObject.Properties.Name | Sort-Object)
                                        $PoolConfig.FocusWallet = Read-HostArray -Prompt "Force mining for one or more of this pool's wallets" -Default $PoolConfig.FocusWallet -Characters "A-Z0-9" -Valid $Pool_Avail_Currency | Foreach-Object {if ($Controls -icontains $_) {throw $_};$_}
                                    }
                                    "minername" {
                                        $PoolConfig.MinerName = Read-HostArray -Prompt "Enter the miners your want to use ($(if ($PoolConfig.MinerName) {"clear"} else {"leave empty"}) for all)" -Default $PoolConfig.MinerName -Characters "A-Z0-9.-_" -Valid $Session.AvailMiners | Foreach-Object {if ($Controls -icontains $_) {throw $_};$_}
                                    }
                                    "organizationid" {
                                        $PoolConfig.OrganizationID = Read-HostString -Prompt $PoolsSetup.$Pool_Name.SetupFields.OrganizationID -Default ($PoolConfig.OrganizationID -replace "^\`$.+") -Characters "A-Z0-9-" | Foreach-Object {if ($Controls -icontains $_) {throw $_};$_} 
                                        if ($PoolConfig.OrganizationID.Trim() -eq '') {$PoolConfig.OrganizationID = $PoolsSetup.$Pool_Name.Fields.OrganizationID}
                                    }
                                    "partypassword" {
                                        $PoolConfig.PartyPassword = Read-HostString -Prompt $PoolsSetup.$Pool_Name.SetupFields.PartyPassword -Default $PoolConfig.PartyPassword -Characters $false | Foreach-Object {if ($Controls -icontains $_) {throw $_};$_}
                                    }
                                    "password" {
                                        $PoolConfig.Password = Read-HostString -Prompt $PoolsSetup.$Pool_Name.SetupFields.Password -Default $PoolConfig.Password -Characters $false | Foreach-Object {if ($Controls -icontains $_) {throw $_};$_}
                                    }
                                    "penalty" {                                                    
                                        $PoolConfig.Penalty = Read-HostDouble -Prompt "Enter penalty in percent. This value will decrease all reported values." -Default $PoolConfig.Penalty -Min 0 -Max 100 | Foreach-Object {if ($Controls -icontains $_) {throw $_};$_}
                                    }
                                    "platform" {
                                        $PoolConfig.Platform = Read-HostArray -Prompt $PoolsSetup.$Pool_Name.SetupFields.Platform -Default $PoolConfig.Platform -Valid @("1","v1","old","2","v2","new") | Foreach-Object {if ($Controls -icontains $_) {throw $_};$_}
                                    }
                                    "pricebtc" {
                                        $PoolConfig.PriceBTC = Read-HostDouble -Prompt $PoolsSetup.$Pool_Name.SetupFields.PriceBTC -Default $PoolConfig.PriceBTC -Min 0 | Foreach-Object {if ($Controls -icontains $_) {throw $_};$_}
                                        $PoolConfig.PriceBTC = "$($PoolConfig.PriceBTC)"
                                    }
                                    "pricecurrencies" {
                                        $PoolConfig.PriceCurrencies = Read-HostArray -Prompt $PoolsSetup.$Pool_Name.SetupFields.PriceCurrencies -Default $PoolConfig.PriceCurrencies -Characters "A-Z" -Valid @("BCH","BTC","DASH","ETH","LTC") -Mandatory | Foreach-Object {if ($Controls -icontains $_) {throw $_};$_}
                                        if ($PoolConfig.PriceCurrencies -inotcontains "BTC") {$PoolConfig.PriceCurrencies += "BTC"}
                                        $PoolConfig.PriceCurrencies = $PoolConfig.PriceCurrencies -join ","
                                    }
                                    "pricefactor" {
                                        $PoolConfig.PriceFactor = Read-HostDouble -Prompt $PoolsSetup.$Pool_Name.SetupFields.PriceFactor -Default $PoolConfig.PriceFactor -Min 0 | Foreach-Object {if ($Controls -icontains $_) {throw $_};$_}
                                        $PoolConfig.PriceFactor = "$($PoolConfig.PriceFactor)"
                                    }
                                    "stataverage" {
                                        Write-Host " "
                                        Write-Host "*** Define the pool's moving average price trendline" -ForegroundColor Green

                                        Write-HostSetupStatAverageHints
                                        $PoolConfig.StatAverage = Read-HostString -Prompt "Enter which moving average is to be used ($(if ($PoolConfig.StatAverage) {"clear"} else {"leave empty"}) for default)" -Default $PoolConfig.StatAverage -Valid @("Live","Minute_5","Minute_10","Hour","Day","ThreeDay","Week") -Characters "A-Z0-9_" | Foreach-Object {if ($Controls -icontains $_) {throw $_};$_}
                                    }
                                    "title" {
                                        $PoolConfig.Title = Read-HostString -Prompt $PoolsSetup.$Pool_Name.SetupFields.Title -Default $PoolConfig.Title -Characters "" | Foreach-Object {if ($Controls -icontains $_) {throw $_};$_}
                                    }
                                    "user" {
                                        $PoolConfig.User = Read-HostString -Prompt $PoolsSetup.$Pool_Name.SetupFields.User -Default ($PoolConfig.User -replace "^\`$.+") -Characters "A-Z0-9-\._~:/\?#\[\]@!\$&'\(\)\*\+,;=" | Foreach-Object {if ($Controls -icontains $_) {throw $_};$_} 
                                        if ($PoolConfig.User.Trim() -eq '') {$PoolConfig.User = $PoolsSetup.$Pool_Name.Fields.User}
                                    }
                                    "username" {
                                        $PoolConfig.UserName = Read-HostString -Prompt $PoolsSetup.$Pool_Name.SetupFields.UserName -Default ($PoolConfig.UserName -replace "^\`$.+") -Characters "A-Z0-9-\._~:/\?#\[\]@!\$&'\(\)\*\+,;=" | Foreach-Object {if ($Controls -icontains $_) {throw $_};$_} 
                                        if ($PoolConfig.UserName.Trim() -eq '') {$PoolConfig.UserName = $PoolsSetup.$Pool_Name.Fields.UserName}
                                    }
                                    "worker" {
                                        $PoolConfig.Worker = Read-HostString -Prompt "Enter the worker name ($(if ($PoolConfig.Worker) {"clear"} else {"leave empty"}) to use config.txt default)" -Default ($PoolConfig.Worker -replace "^\`$.+") -Characters "A-Z0-9" | Foreach-Object {if ($Controls -icontains $_) {throw $_};$_} 
                                        if ($PoolConfig.Worker.Trim() -eq '') {$PoolConfig.Worker = "`$WorkerName"}
                                    }
                                    "save" {
                                        Write-Host " "
                                        if (-not (Read-HostBool -Prompt "Done! Do you want to save the changed values?" -Default $True | Foreach-Object {if ($Controls -icontains $_) {throw $_};$_})) {throw "cancel"}
                                                        
                                        $PoolConfig | Add-Member Algorithm $($PoolConfig.Algorithm -join ",") -Force
                                        $PoolConfig | Add-Member ExcludeAlgorithm $($PoolConfig.ExcludeAlgorithm -join ",") -Force
                                        $PoolConfig | Add-Member CoinName $($PoolConfig.CoinName -join ",") -Force
                                        $PoolConfig | Add-Member ExcludeCoin $($PoolConfig.ExcludeCoin -join ",") -Force
                                        $PoolConfig | Add-Member CoinSymbol $($PoolConfig.CoinSymbol -join ",") -Force
                                        $PoolConfig | Add-Member ExcludeCoinSymbol $($PoolConfig.ExcludeCoinSymbol -join ",") -Force
                                        $PoolConfig | Add-Member CoinSymbolPBM $($PoolConfig.CoinSymbolPBM -join ",") -Force
                                        $PoolConfig | Add-Member MinerName $($PoolConfig.MinerName -join ",") -Force
                                        $PoolConfig | Add-Member ExcludeMinerName $($PoolConfig.ExcludeMinerName -join ",") -Force
                                        $PoolConfig | Add-Member EnableAutoCoin $(if (Get-Yes $PoolConfig.EnableAutoCoin){"1"}else{"0"}) -Force
                                        $PoolConfig | Add-Member EnablePostBlockMining $(if (Get-Yes $PoolConfig.EnablePostBlockMining){"1"}else{"0"}) -Force
                                        $PoolConfig | Add-Member FocusWallet $($PoolConfig.FocusWallet -join ",") -Force
                                        $PoolConfig | Add-Member AllowZero $(if (Get-Yes $PoolConfig.AllowZero){"1"}else{"0"}) -Force

                                        $PoolsActual | Add-Member $Pool_Name $PoolConfig -Force
                                        $PoolsActualSave = [PSCustomObject]@{}
                                        $PoolsActual.PSObject.Properties.Name | Sort-Object | Foreach-Object {$PoolsActualSave | Add-Member $_ ($PoolsActual.$_) -Force}

                                        Set-ContentJson -PathToFile $ConfigFiles["Pools"].Path -Data $PoolsActualSave > $null

                                        Write-Host " "
                                        Write-Host "Changes written to pool configuration. " -ForegroundColor Cyan
                                                    
                                        $PoolSetupStepsDone = $true                                                  
                                    }
                                }
                                if ($PoolSetupStepStore) {$PoolSetupStepBack.Add($PoolSetupStep) > $null}                                                
                                $PoolSetupStep++
                            }
                            catch {
                                if ($Error.Count){$Error.RemoveAt(0)}
                                if (@("back","<") -icontains $_.Exception.Message) {
                                    if ($PoolSetupStepBack.Count) {$PoolSetupStep = $PoolSetupStepBack[$PoolSetupStepBack.Count-1];$PoolSetupStepBack.RemoveAt($PoolSetupStepBack.Count-1)}
                                    else {$PoolSetupStepsDone = $true}
                                }
                                elseif (@("exit","cancel") -icontains $_.Exception.Message) {
                                    Write-Host " "
                                    Write-Host "Cancelled without changing the configuration" -ForegroundColor Red
                                    Write-Host " "
                                    $PoolSetupStepsDone = $true                                               
                                }
                                else {
                                    if ($PoolSetupStepStore) {$PoolSetupStepBack.Add($PoolSetupStep) > $null}
                                    $NextSetupStep = Switch -Regex ($_.Exception.Message) {
                                                        "^Goto\s+(.+)$" {$Matches[1]}
                                                        "^done$"  {"save"}
                                                        default {$_}
                                                    }
                                    $PoolSetupStep = $PoolSetupSteps.IndexOf($NextSetupStep)
                                    if ($PoolSetupStep -lt 0) {
                                        Write-Log -Level Error "Unknown goto command `"$($NextSetupStep)`". You should never reach here. Please open an issue on github.com"
                                        $PoolSetupStep = $PoolSetupStepBack[$PoolSetupStepBack.Count-1];$PoolSetupStepBack.RemoveAt($PoolSetupStepBack.Count-1)
                                    }
                                }
                            }
                        } until ($PoolSetupStepsDone)                                                                        

                    } else {
                        Write-Host "Please try again later" -ForegroundColor Yellow
                    }

                    Write-Host " "
                    if (-not (Read-HostBool "Edit another pool?")){throw}
                        
                } catch {if ($Error.Count){$Error.RemoveAt(0)};$PoolSetupDone = $true}
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
                    $DevicesActual = Get-Content $ConfigFiles["Devices"].Path | ConvertFrom-Json
                    $Device_Name = Read-HostString -Prompt "Which device do you want to configure? (leave empty to end device config)" -Characters "A-Z0-9" -Valid @($SetupDevices.Model | Select-Object -Unique | Sort-Object) | Foreach-Object {if ($Controls -icontains $_) {throw $_};$_}
                    if ($Device_Name -eq '') {throw}

                    if (-not $DevicesActual.$Device_Name) {
                        $DevicesActual | Add-Member $Device_Name ([PSCustomObject]@{Algorithm="";ExcludeAlgorithm="";MinerName="";ExcludeMinerName="";DisableDualMining="";PowerAdjust="100"}) -Force
                        Set-ContentJson -PathToFile $ConfigFiles["Devices"].Path -Data $DevicesActual > $null
                    }

                    if ($Device_Name) {
                        $DeviceSetupStepsDone = $false
                        $DeviceSetupStep = 0
                        [System.Collections.ArrayList]$DeviceSetupSteps = @()
                        [System.Collections.ArrayList]$DeviceSetupStepBack = @()

                        $DeviceConfig = $DevicesActual.$Device_Name.PSObject.Copy()

                        $DeviceSetupSteps.AddRange(@("algorithm","excludealgorithm","minername","excludeminername","disabledualmining","defaultocprofile","poweradjust")) > $null
                        $DeviceSetupSteps.Add("save") > $null
                                        
                        do {
                            $DeviceSetupStepStore = $true
                            try {
                                Switch ($DeviceSetupSteps[$DeviceSetupStep]) {
                                    "algorithm" {
                                        $DeviceConfig.Algorithm = Read-HostArray -Prompt "Enter algorithms you want to mine ($(if ($DeviceConfig.Algorithm) {"clear"} else {"leave empty"}) for all)" -Default $DeviceConfig.Algorithm -Characters "A-Z0-9" | Foreach-Object {if ($Controls -icontains $_) {throw $_};$_}
                                    }
                                    "excludealgorithm" {
                                        $DeviceConfig.ExcludeAlgorithm = Read-HostArray -Prompt "Enter algorithms you do want to exclude " -Default $DeviceConfig.ExcludeAlgorithm -Characters "A-Z0-9" | Foreach-Object {if ($Controls -icontains $_) {throw $_};$_}
                                    }
                                    "minername" {
                                        $DeviceConfig.MinerName = Read-HostArray -Prompt "Enter the miners your want to use ($(if ($DeviceConfig.MinerName) {"clear"} else {"leave empty"}) for all)" -Default $DeviceConfig.MinerName -Characters "A-Z0-9.-_" -Valid $Session.AvailMiners | Foreach-Object {if ($Controls -icontains $_) {throw $_};$_}
                                    }
                                    "excludeminername" {
                                        $DeviceConfig.ExcludeMinerName = Read-HostArray -Prompt "Enter the miners you do want to exclude" -Default $DeviceConfig.ExcludeMinerName -Characters "A-Z0-9\.-_" -Valid $Session.AvailMiners | Foreach-Object {if ($Controls -icontains $_) {throw $_};$_}
                                    }
                                    "disabledualmining" {
                                        $DeviceConfig.DisableDualMining = Read-HostBool -Prompt "Disable all dual mining algorithm" -Default $DeviceConfig.DisableDualMining | Foreach-Object {if ($Controls -icontains $_) {throw $_};$_}
                                    }
                                    "defaultocprofile" {                                                        
                                        $DeviceConfig.DefaultOCprofile = Read-HostString -Prompt "Select the default overclocking profile for this device ($(if ($DeviceConfig.DefaultOCprofile) {"clear"} else {"leave empty"}) for none)" -Default $DeviceConfig.DefaultOCprofile -Characters "A-Z0-9" -Valid @($OCprofilesActual.PSObject.Properties.Name | Sort-Object) | Foreach-Object {if ($Controls -icontains $_) {throw $_};$_}
                                    }
                                    "poweradjust" {                                                        
                                        $DeviceConfig.PowerAdjust = Read-HostDouble -Prompt "Adjust power consumption to this value in percent, e.g. 75 would result in Power x 0.75 (enter 100 for original value)" -Default $DeviceConfig.PowerAdjust -Min 0 | Foreach-Object {if ($Controls -icontains $_) {throw $_};$_}
                                    }
                                    "save" {
                                        Write-Host " "
                                        if (-not (Read-HostBool -Prompt "Done! Do you want to save the changed values?" -Default $True | Foreach-Object {if ($Controls -icontains $_) {throw $_};$_})) {throw "cancel"}
                                                        
                                        $DeviceConfig | Add-Member Algorithm $($DeviceConfig.Algorithm -join ",") -Force
                                        $DeviceConfig | Add-Member ExcludeAlgorithm $($DeviceConfig.ExcludeAlgorithm -join ",") -Force
                                        $DeviceConfig | Add-Member MinerName $($DeviceConfig.MinerName -join ",") -Force
                                        $DeviceConfig | Add-Member ExcludeMinerName $($DeviceConfig.ExcludeMinerName -join ",") -Force
                                        $DeviceConfig | Add-Member DisableDualMining $(if (Get-Yes $DeviceConfig.DisableDualMining){"1"}else{"0"}) -Force
                                        $DeviceConfig | Add-Member PowerAdjust "$($DeviceConfig.PowerAdjust)" -Force

                                        $DevicesActual | Add-Member $Device_Name $DeviceConfig -Force
                                        $DevicesActualSave = [PSCustomObject]@{}
                                        $DevicesActual.PSObject.Properties.Name | Sort-Object | Foreach-Object {$DevicesActualSave | Add-Member $_ ($DevicesActual.$_) -Force}
                                                        
                                        Set-ContentJson -PathToFile $ConfigFiles["Devices"].Path -Data $DevicesActualSave > $null

                                        Write-Host " "
                                        Write-Host "Changes written to device configuration. " -ForegroundColor Cyan
                                                    
                                        $DeviceSetupStepsDone = $true
                                    }
                                }
                                if ($DeviceSetupStepStore) {$DeviceSetupStepBack.Add($DeviceSetupStep) > $null}
                                $DeviceSetupStep++
                            }
                            catch {
                                if ($Error.Count){$Error.RemoveAt(0)}
                                if (@("back","<") -icontains $_.Exception.Message) {
                                    if ($DeviceSetupStepBack.Count) {$DeviceSetupStep = $DeviceSetupStepBack[$DeviceSetupStepBack.Count-1];$DeviceSetupStepBack.RemoveAt($DeviceSetupStepBack.Count-1)}
                                }
                                elseif (@("exit","cancel") -icontains $_.Exception.Message) {
                                    Write-Host " "
                                    Write-Host "Cancelled without changing the configuration" -ForegroundColor Red
                                    Write-Host " "
                                    $DeviceSetupStepsDone = $true                                               
                                }
                                else {
                                    if ($DeviceSetupStepStore) {$DeviceSetupStepBack.Add($DeviceSetupStep) > $null}
                                    $NextSetupStep = Switch -Regex ($_.Exception.Message) {
                                                        "^Goto\s+(.+)$" {$Matches[1]}
                                                        "^done$"  {"save"}
                                                        default {$_}
                                                    }
                                    $DeviceSetupStep = $DeviceSetupSteps.IndexOf($NextSetupStep)
                                    if ($DeviceSetupStep -lt 0) {
                                        Write-Log -Level Error "Unknown goto command `"$($NextSetupStep)`". You should never reach here. Please open an issue on github.com"
                                        $DeviceSetupStep = $DeviceSetupStepBack[$DeviceSetupStepBack.Count-1];$DeviceSetupStepBack.RemoveAt($DeviceSetupStepBack.Count-1)
                                    }
                                }
                            }
                        } until ($DeviceSetupStepsDone)                                                                        

                    } else {
                        Write-Host "Please try again later" -ForegroundColor Yellow
                    }

                    Write-Host " "
                    if (-not (Read-HostBool "Edit another device?")){throw}
                        
                } catch {if ($Error.Count){$Error.RemoveAt(0)};$DeviceSetupDone = $true}
            } until ($DeviceSetupDone)
        }
        elseif ($SetupType -eq "L") {

            Clear-Host

            Write-Host " "
            Write-Host "*** Algorithm Configuration ***" -BackgroundColor Green -ForegroundColor Black
            Write-HostSetupHints
            Write-Host " "

            $AlgorithmSetupDone = $false
            do {
                try {
                    $AllAlgorithms = Get-Algorithms -Values
                    $AlgorithmsActual = Get-Content $ConfigFiles["Algorithms"].Path | ConvertFrom-Json
                    $Algorithm_Name = Read-HostString -Prompt "Which algorithm do you want to configure? (leave empty to end algorithm config)" -Characters "A-Z0-9" -Valid $AllAlgorithms | Foreach-Object {if ($Controls -icontains $_) {throw $_};$_}
                    if ($Algorithm_Name -eq '') {throw}

                    if (-not $AlgorithmsActual.$Algorithm_Name) {
                        $AlgorithmsActual | Add-Member $Algorithm_Name ($AlgorithmsDefault | ConvertTo-Json | ConvertFrom-Json) -Force
                        Set-ContentJson -PathToFile $ConfigFiles["Algorithms"].Path -Data $AlgorithmsActual > $null
                    }

                    if ($Algorithm_Name) {
                        $AlgorithmSetupStepsDone = $false
                        $AlgorithmSetupStep = 0
                        [System.Collections.ArrayList]$AlgorithmSetupSteps = @()
                        [System.Collections.ArrayList]$AlgorithmSetupStepBack = @()

                        $AlgorithmConfig = $AlgorithmsActual.$Algorithm_Name.PSObject.Copy()
                        foreach($SetupName in $AlgorithmsDefault.PSObject.Properties.Name) {if ($AlgorithmConfig.$SetupName -eq $null){$AlgorithmConfig | Add-Member $SetupName $AlgorithmsDefault.$SetupName -Force}}

                        $AlgorithmSetupSteps.AddRange(@("penalty","minhashrate","minworkers","maxtimetofind","ocprofile","msiaprofile")) > $null
                        $AlgorithmSetupSteps.Add("save") > $null

                        do {
                            $AlgorithmSetupStepStore = $true
                            try {
                                Switch ($AlgorithmSetupSteps[$AlgorithmSetupStep]) {
                                    "penalty" {
                                        $AlgorithmConfig.Penalty = Read-HostDouble -Prompt "Enter penalty in percent. This value will decrease all reported values." -Default $AlgorithmConfig.Penalty -Min -100 -Max 100 | Foreach-Object {if ($Controls -icontains $_) {throw $_};$_}
                                    }
                                    "minhashrate" {
                                        $AlgorithmConfig.MinHashrate = Read-HostString -Prompt "Enter minimum hashrate at a pool (units allowed, e.g. 12GH)" -Default $AlgorithmConfig.MinHashrate -Characters "0-9kMGTPH`." | Foreach-Object {if ($Controls -icontains $_) {throw $_};$_}
                                        $AlgorithmConfig.MinHashrate = $AlgorithmConfig.MinHashrate -replace "([A-Z]{2})[A-Z]+","`$1"
                                    }
                                    "minworkers" {
                                        $AlgorithmConfig.MinWorkers = Read-HostString -Prompt "Enter minimum amount of workers at a pool (units allowed, e.g. 5k)" -Default $AlgorithmConfig.MinWorkers -Characters "0-9kMGTPH`." | Foreach-Object {if ($Controls -icontains $_) {throw $_};$_}
                                        $AlgorithmConfig.MinWorkers = $AlgorithmConfig.MinWorkers -replace "([A-Z])[A-Z]+","`$1"
                                    }
                                    "maxtimetofind" {
                                        $AlgorithmConfig.MaxTimeToFind = Read-HostString -Prompt "Enter maximum average time to find a block (units allowed, e.h. 1h=one hour, default unit is s=seconds)" -Default $AlgorithmConfig.MaxTimeToFind -Characters "0-9smhdw`." | Foreach-Object {if ($Controls -icontains $_) {throw $_};$_}
                                        $AlgorithmConfig.MaxTimeToFind = $AlgorithmConfig.MaxTimeToFind -replace "([A-Z])[A-Z]+","`$1"
                                    }
                                    "ocprofile" {
                                        $AlgorithmSetupStepStore = $false
                                        if (Get-Yes $Config.EnableOCProfiles) {
                                            $AlgorithmConfig.OCprofile = Read-HostString -Prompt "Custom overclocking profile ($(if ($AlgorithmConfig.OCprofile) {"clear"} else {"leave empty"}) for none)" -Default $AlgorithmConfig.OCprofile -Valid @($OCProfilesActual.PSObject.Properties.Name) | Foreach-Object {if ($Controls -icontains $_) {throw $_};$_}
                                            $AlgorithmSetupStepStore = $true
                                        }
                                    }
                                    "msiaprofile" {
                                        $AlgorithmSetupStepStore = $false
                                        if (-not (Get-Yes $Config.EnableOCProfiles)) {
                                            $AlgorithmConfig.MSIAprofile = Read-HostString -Prompt "MSI Afterburner Profile" -Default $AlgorithmConfig.MSIAprofile -Characters "012345" -Length 1 | Foreach-Object {if ($Controls -icontains $_) {throw $_};$_}
                                            $AlgorithmSetupStepStore = $true
                                        }
                                    }
                                    "save" {
                                        Write-Host " "
                                        if (-not (Read-HostBool -Prompt "Done! Do you want to save the changed values?" -Default $True | Foreach-Object {if ($Controls -icontains $_) {throw $_};$_})) {throw "cancel"}
                                                        
                                        $AlgorithmConfig | Add-Member Penalty "$($AlgorithmConfig.Penalty)" -Force
                                        $AlgorithmConfig | Add-Member MinHashrate $AlgorithmConfig.MinHashrate -Force
                                        $AlgorithmConfig | Add-Member MinWorkers $AlgorithmConfig.MinWorkers -Force
                                        $AlgorithmConfig | Add-Member OCprofile $AlgorithmConfig.OCprofile -Force
                                        $AlgorithmConfig | Add-Member MSIAprofile $AlgorithmConfig.MSIAprofile -Force

                                        $AlgorithmsActual | Add-Member $Algorithm_Name $AlgorithmConfig -Force
                                        $AlgorithmsActualSave = [PSCustomObject]@{}
                                        $AlgorithmsActual.PSObject.Properties.Name | Sort-Object | Foreach-Object {$AlgorithmsActualSave | Add-Member $_ ($AlgorithmsActual.$_) -Force}
                                                        
                                        Set-ContentJson -PathToFile $ConfigFiles["Algorithms"].Path -Data $AlgorithmsActualSave > $null

                                        Write-Host " "
                                        Write-Host "Changes written to algorithm configuration. " -ForegroundColor Cyan
                                                    
                                        $AlgorithmSetupStepsDone = $true
                                    }
                                }
                                if ($AlgorithmSetupStepStore) {$AlgorithmSetupStepBack.Add($AlgorithmSetupStep) > $null}
                                $AlgorithmSetupStep++
                            }
                            catch {
                                if ($Error.Count){$Error.RemoveAt(0)}
                                if (@("back","<") -icontains $_.Exception.Message) {
                                    if ($AlgorithmSetupStepBack.Count) {$AlgorithmSetupStep = $AlgorithmSetupStepBack[$AlgorithmSetupStepBack.Count-1];$AlgorithmSetupStepBack.RemoveAt($AlgorithmSetupStepBack.Count-1)}
                                }
                                elseif (@("exit","cancel") -icontains $_.Exception.Message) {
                                    Write-Host " "
                                    Write-Host "Cancelled without changing the configuration" -ForegroundColor Red
                                    Write-Host " "
                                    $AlgorithmSetupStepsDone = $true                                               
                                }
                                else {
                                    if ($AlgorithmSetupStepStore) {$AlgorithmSetupStepBack.Add($AlgorithmSetupStep) > $null}
                                    $NextSetupStep = Switch -Regex ($_.Exception.Message) {
                                                        "^Goto\s+(.+)$" {$Matches[1]}
                                                        "^done$"  {"save"}
                                                        default {$_}
                                                    }
                                    $AlgorithmSetupStep = $AlgorithmSetupSteps.IndexOf($NextSetupStep)
                                    if ($AlgorithmSetupStep -lt 0) {
                                        Write-Log -Level Error "Unknown goto command `"$($NextSetupStep)`". You should never reach here. Please open an issue on github.com"
                                        $AlgorithmSetupStep = $AlgorithmSetupStepBack[$AlgorithmSetupStepBack.Count-1];$AlgorithmSetupStepBack.RemoveAt($AlgorithmSetupStepBack.Count-1)
                                    }
                                }
                            }
                        } until ($AlgorithmSetupStepsDone)                                                                        

                    } else {
                        Write-Host "Please try again later" -ForegroundColor Yellow
                    }

                    Write-Host " "
                    if (-not (Read-HostBool "Edit another algorithm?")){throw}
                        
                } catch {if ($Error.Count){$Error.RemoveAt(0)};$AlgorithmSetupDone = $true}
            } until ($AlgorithmSetupDone)
        }
        elseif ($SetupType -eq "I") {

            Clear-Host

            Write-Host " "
            Write-Host "*** Coins Configuration ***" -BackgroundColor Green -ForegroundColor Black
            Write-HostSetupHints
            Write-Host " "

            $CoinSetupDone = $false
            do {
                try {
                    do {
                        $CoinsActual = Get-Content $ConfigFiles["Coins"].Path | ConvertFrom-Json
                        $PoolsActual = Get-Content $ConfigFiles["Pools"].Path | ConvertFrom-Json

                        $CoinsToPools = [PSCustomObject]@{}
                        $CoinsActual.PSObject.Properties.Name | Foreach-Object {
                            $Coin = $_
                            $CoinsToPools | Add-Member $Coin @($PoolsActual.PSObject.Properties | Where-Object {$_.Value.$Coin -eq "`$$Coin"} | Select-Object -ExpandProperty Name) -Force
                        }

                        Write-Host " "
                        $p = [console]::ForegroundColor
                        [console]::ForegroundColor = "Cyan"
                        Write-Host "Current Coins:"
                        $CoinsActual.PSObject.Properties | Format-Table @(
                            @{Label="Symbol"; Expression={"$($_.Name)"}}
                            @{Label="Penalty"; Expression={"$($_.Value.Penalty)"}; Align="center"}
                            @{Label="MinHashrate"; Expression={"$($_.Value.MinHashrate)"}; Align="center"}
                            @{Label="MinWorkers"; Expression={"$($_.Value.MinWorkers)"}; Align="center"}
                            @{Label="MaxTimeToFind"; Expression={"$($_.Value.MinWorkers)"}; Align="center"}
                            @{Label="PostBlockMining"; Expression={"$($_.Value.PostBlockMining)"}; Align="center"}
                            @{Label="MinProfit%"; Expression={"$($_.Value.MinProfitPercent)"}; Align="center"}
                            @{Label="EAP"; Expression={"$(if (Get-Yes $_.Value.EnableAutoPool) {"Y"} else {"N"})"}; Align="center"}
                            @{Label="Wallet"; Expression={if ($_.Value.Wallet.Length -gt 12) {"$($_.Value.Wallet.SubString(0,5))..$($_.Value.Wallet.SubString($_.Value.Wallet.Length-5,5))"} else {"$($_.Value.Wallet)"}}}
                            @{Label="Pools"; Expression={"$($CoinsToPools."$($_.Name)" -join ',')"}}
                        )
                        [console]::ForegroundColor = $p

                        $Coin_Symbol = Read-HostString -Prompt "Which coinsymbol do you want to edit/create/delete? (leave empty to end coin config)" -Characters "`$A-Z0-9_" | Foreach-Object {if ($Controls -icontains $_) {throw $_};$_}
                        if ($Coin_Symbol -eq '') {throw}

                        $Coin_Symbol = $Coin_Symbol.ToUpper()

                        if (-not $CoinsActual.$Coin_Symbol) {
                            if (Read-HostBool "Do you want to add a new coin `"$($Coin_Symbol)`"?" -Default $true) {
                                $CoinsActual | Add-Member $Coin_Symbol ($CoinsDefault | ConvertTo-Json | ConvertFrom-Json) -Force
                                Set-ContentJson -PathToFile $ConfigFiles["Coins"].Path -Data $CoinsActual > $null
                            } else {
                                $Coin_Symbol = ''
                            }
                        } else {
                            $Coin_Symbol = $CoinsActual.PSObject.Properties.Name | Where-Object {$_ -eq $Coin_Symbol}
                            $What = Read-HostString "Do you want to [e]dit or [d]elete `"$Coin_Symbol`"? (or enter [b]ack, to choose another)" -Characters "edb" -Mandatory -Default "e"                                            
                            if ($What -ne "e") {                                                
                                if ($What -eq "d") {
                                    $CoinsSave = [PSCustomObject]@{}
                                    $CoinsActual.PSObject.Properties | Where-Object {$_.Name -ne $Coin_Symbol} | Foreach-Object {$CoinsSave | Add-Member $_.Name $_.Value}                                                    
                                    Set-ContentJson -PathToFile $ConfigFiles["Coins"].Path -Data $CoinsSave > $null
                                }
                                $Coin_Symbol = ""
                            }
                        }
                        if ($Coin_Symbol -eq '') {Clear-Host}
                    } until ($Coin_Symbol -ne '')

                    if ($Coin_Symbol) {

                        $CoinsPools = @(Get-PoolsInfo "Minable" $Coin_Symbol -AsObjects | Where-Object {-not $PoolsSetup."$($_.Pool)".Autoexchange -or $_.Pool -match "ZergPool"} | Select-Object -ExpandProperty Pool | Sort-Object)
                        $CoinsPoolsInUse = @($CoinsPools | Where-Object {$CoinsToPools.$Coin_Symbol -icontains $_} | Select-Object)

                        $CoinSetupStepsDone = $false
                        $CoinSetupStep = 0
                        [System.Collections.ArrayList]$CoinSetupSteps = @()
                        [System.Collections.ArrayList]$CoinSetupStepBack = @()

                        $CoinConfig = $CoinsActual.$Coin_Symbol.PSObject.Copy()
                        $CoinsDefault.PSObject.Properties.Name | Where {$CoinConfig.$_ -eq $null} | Foreach-Object {$CoinConfig | Add-Member $_ $CoinsDefault.$_ -Force}

                        $CoinSetupSteps.AddRange(@("penalty","minhashrate","minworkers","maxtimetofind","postblockmining","minprofitpercent","wallet","enableautopool","comment","pools")) > $null
                        $CoinSetupSteps.Add("save") > $null
                                        
                        do {
                            $CoinSetupStepStore = $true
                            try {
                                Switch ($CoinSetupSteps[$CoinSetupStep]) {
                                    "penalty" {
                                        $CoinConfig.Penalty = Read-HostDouble -Prompt "Enter penalty in percent. This value will decrease all reported values." -Default $CoinConfig.Penalty -Min -100 -Max 100 | Foreach-Object {if ($Controls -icontains $_) {throw $_};$_}
                                    }
                                    "minhashrate" {
                                        $CoinConfig.MinHashrate = Read-HostString -Prompt "Enter minimum hashrate at a pool (units allowed, e.g. 12GH)" -Default $CoinConfig.MinHashrate -Characters "0-9kMGTPH`." | Foreach-Object {if ($Controls -icontains $_) {throw $_};$_}
                                        $CoinConfig.MinHashrate = $CoinConfig.MinHashrate -replace "([A-Z]{2})[A-Z]+","`$1"
                                    }
                                    "minworkers" {
                                        $CoinConfig.MinWorkers = Read-HostString -Prompt "Enter minimum amount of workers at a pool (units allowed, e.g. 5k)" -Default $CoinConfig.MinWorkers -Characters "0-9kMGTPH`." | Foreach-Object {if ($Controls -icontains $_) {throw $_};$_}
                                        $CoinConfig.MinWorkers = $CoinConfig.MinWorkers -replace "([A-Z])[A-Z]+","`$1"
                                    }
                                    "maxtimetofind" {
                                        $CoinConfig.MaxTimeToFind = Read-HostString -Prompt "Enter maximum average time to find a block (units allowed, e.h. 1h=one hour, default unit is s=seconds)" -Default $CoinConfig.MaxTimeToFind -Characters "0-9smhdw`." | Foreach-Object {if ($Controls -icontains $_) {throw $_};$_}
                                        $CoinConfig.MaxTimeToFind = $CoinConfig.MaxTimeToFind -replace "([A-Z])[A-Z]+","`$1"
                                    }
                                    "postblockmining" {
                                        $CoinConfig.PostBlockMining = Read-HostString -Prompt "Enter timespan to force mining, after a block has been found at enabled pools (units allowed, e.h. 1h=one hour, default unit is s=seconds)" -Default $CoinConfig.PostBlockMining -Characters "0-9smhdw`." | Foreach-Object {if ($Controls -icontains $_) {throw $_};$_}
                                        $CoinConfig.PostBlockMining = $CoinConfig.PostBlockMining -replace "([A-Z])[A-Z]+","`$1"
                                    }
                                    "minprofitpercent" {
                                        $CoinConfig.MinProfitPercent = Read-HostDouble -Prompt "Enter allowed minimum profit for post block mining (in percent of best miner's profit)" -Default $CoinConfig.MinProfitPercent -Min 0 -Max 100 | Foreach-Object {if ($Controls -icontains $_) {throw $_};$_}
                                    }
                                    "wallet" {
                                        $CoinConfig.Wallet = Read-HostString -Prompt "Enter global wallet address (optional, will substitute string `"`$$Coin_Symbol`" in pools.config.txt)" -Default $CoinConfig.Wallet -Characters "A-Z0-9-\._~:/\?#\[\]@!\$&'\(\)\*\+,;=" | Foreach-Object {if ($Controls -icontains $_) {throw $_};$_}
                                        $CoinConfig.Wallet = $CoinConfig.Wallet -replace "\s+"
                                    }
                                    "enableautopool" {
                                        $CoinConfig.EnableAutoPool = Read-HostBool -Prompt "Automatically enable `"$Coin_Symbol`" for pools activated in pools.config.txt with EnableAutoCoin=`"1`"" -Default $CoinConfig.EnableAutoPool | Foreach-Object {if ($Controls -icontains $_) {throw $_};$_}
                                    }
                                    "comment" {
                                        $CoinConfig.Comment = Read-HostString -Prompt "Optionally enter a comment (e.g. name of exchange)" -Default $CoinConfig.Comment -Characters "" | Foreach-Object {if ($Controls -icontains $_) {throw $_};$_}
                                    }
                                    "pools" {
                                        $CoinsPoolsNotInUse = @($CoinsPools | Where-Object {$CoinsPoolsInUse -inotcontains $_} | Select-Object)
                                        $p = [console]::ForegroundColor
                                        [console]::ForegroundColor = "Cyan"
                                        [PSCustomObject]@{"Pools using $Coin_Symbol"=$($CoinsPoolsInUse -join ', ');"Pools not using $Coin_Symbol"=$($CoinsPoolsNotInUse -join ', ')} | Format-Table -Wrap
                                        [console]::ForegroundColor = $p
                                        $CoinsPoolsInUse = Read-HostArray -Prompt "Select pools for $Coin_Symbol" -Default $CoinsPoolsInUse -Valid $CoinsPools | Foreach-Object {if ($Controls -icontains $_) {throw $_};$_} 
                                    }
                                    "save" {
                                        Write-Host " "
                                        if (-not (Read-HostBool -Prompt "Done! Do you want to save the changed values?" -Default $True | Foreach-Object {if ($Controls -icontains $_) {throw $_};$_})) {throw "cancel"}

                                        $CoinConfig | Add-Member EnableAutoPool $(if (Get-Yes $CoinConfig.EnableAutoPool){"1"}else{"0"}) -Force

                                        $CoinsActual | Add-Member $Coin_Symbol $CoinConfig -Force
                                        $CoinsActualSave = [PSCustomObject]@{}
                                        $CoinsActual.PSObject.Properties.Name | Sort-Object | Foreach-Object {$CoinsActualSave | Add-Member $_ ($CoinsActual.$_) -Force}

                                        Set-ContentJson -PathToFile $ConfigFiles["Coins"].Path -Data $CoinsActualSave > $null

                                        Write-Host " "
                                        Write-Host "Changes written to coins configuration. " -ForegroundColor Cyan

                                        $PoolsActualSave = [PSCustomObject]@{}
                                        $PoolsActual.PSObject.Properties.Name | Sort-Object | Foreach-Object {
                                            $Pool = $_
                                            $IsInUse = $CoinsPoolsInUse -icontains $Pool
                                            if ($IsInUse -or $PoolsActual.$Pool.$Coin_Symbol -eq "`$$Coin_Symbol") {
                                                $PoolsActualSave | Add-Member $Pool ([PSCustomObject]@{}) -Force
                                                if ($IsInUse) {
                                                    $PoolsActualSave.$Pool | Add-Member $Coin_Symbol "`$$Coin_Symbol" -Force
                                                    $PoolsActualSave.$Pool | Add-Member "$($Coin_Symbol)-Params" "$($PoolsActual.$Pool."$($Coin_Symbol)-Params")" -Force
                                                }
                                                $PoolsActual.$Pool.PSObject.Properties | Where-Object {$_.Name -ne $Coin_Symbol -and $_.Name -ne "$($Coin_Symbol)-Params"} | Foreach-Object {$PoolsActualSave.$Pool | Add-Member $_.Name $_.Value -Force}
                                            } else {
                                                $PoolsActualSave | Add-Member $Pool ($PoolsActual.$Pool) -Force
                                            }
                                        }
                                        Set-ContentJson -PathToFile $ConfigFiles["Pools"].Path -Data $PoolsActualSave > $null
                                        Write-Host "Changes written to pools configuration. " -ForegroundColor Cyan

                                        $CoinSetupStepsDone = $true
                                    }
                                }
                                if ($CoinSetupStepStore) {$CoinSetupStepBack.Add($CoinSetupStep) > $null}
                                $CoinSetupStep++
                            }
                            catch {
                                if ($Error.Count){$Error.RemoveAt(0)}
                                if (@("back","<") -icontains $_.Exception.Message) {
                                    if ($CoinSetupStepBack.Count) {$CoinSetupStep = $CoinSetupStepBack[$CoinSetupStepBack.Count-1];$CoinSetupStepBack.RemoveAt($CoinSetupStepBack.Count-1)}
                                }
                                elseif (@("exit","cancel") -icontains $_.Exception.Message) {
                                    Write-Host " "
                                    Write-Host "Cancelled without changing the configuration" -ForegroundColor Red
                                    Write-Host " "
                                    $CoinSetupStepsDone = $true                                               
                                }
                                else {
                                    if ($CoinSetupStepStore) {$CoinSetupStepBack.Add($CoinSetupStep) > $null}
                                    $NextSetupStep = Switch -Regex ($_.Exception.Message) {
                                                        "^Goto\s+(.+)$" {$Matches[1]}
                                                        "^done$"  {"save"}
                                                        default {$_}
                                                    }
                                    $CoinSetupStep = $CoinSetupSteps.IndexOf($NextSetupStep)
                                    if ($CoinSetupStep -lt 0) {
                                        Write-Log -Level Error "Unknown goto command `"$($NextSetupStep)`". You should never reach here. Please open an issue on github.com"
                                        $CoinSetupStep = $CoinSetupStepBack[$CoinSetupStepBack.Count-1];$CoinSetupStepBack.RemoveAt($CoinSetupStepBack.Count-1)
                                    }
                                }
                            }
                        } until ($CoinSetupStepsDone)                                                                        

                    } else {
                        Write-Host "Please try again later" -ForegroundColor Yellow
                    }

                    Write-Host " "
                    if (-not (Read-HostBool "Edit another coin?")){throw}
                        
                } catch {if ($Error.Count){$Error.RemoveAt(0)};$CoinSetupDone = $true}
            } until ($CoinSetupDone)
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
        
                    do {
                        $OCProfilesActual = Get-Content $ConfigFiles["OCProfiles"].Path | ConvertFrom-Json
                        Write-Host " "
                        $p = [console]::ForegroundColor
                        [console]::ForegroundColor = "Cyan"
                        Write-Host "Current profiles:"
                        $OCProfilesActual.PSObject.Properties | Format-Table @(
                            @{Label="Name"; Expression={"$($_.Name -replace '-.+$')"}}
                            @{Label="Device"; Expression={"$($_.Name -replace '^.+-')"}}
                            @{Label="Power Limit"; Expression={"$(if ($_.Value.PowerLimit -eq '0'){'*'}else{"$($_.Value.PowerLimit) %"})"}; Align="center"}
                            @{Label="Thermal Limit"; Expression={"$(if ($_.Value.ThermalLimit -eq '0'){'*'}else{"$($_.Value.ThermalLimit) °C"})"}; Align="center"}
                            @{Label="Core Clock"; Expression={"$(if ($_.Value.CoreClockBoost -eq '*'){'*'}else{"$(if ([Convert]::ToInt32($_.Value.CoreClockBoost) -gt 0){'+'})$($_.Value.CoreClockBoost)"})"}; Align="center"}
                            @{Label="Memory Clock"; Expression={"$(if ($_.Value.MemoryClockBoost -eq '*'){'*'}else{"$(if ([Convert]::ToInt32($_.Value.MemoryClockBoost) -gt 0){'+'})$($_.Value.MemoryClockBoost)"})"}; Align="center"}                                        
                        )

                        Write-Host "Available devices:"

                        $SetupDevices | Where-Object Type -eq "gpu" | Sort-Object Index | Format-Table @(
                            @{Label="Name"; Expression={$_.Name}}
                            @{Label="Model"; Expression={$_.Model}}
                            @{Label="PCIBusId"; Expression={$_.OpenCL.PCIBusId}}
                        )

                        [console]::ForegroundColor = $p

                        $ValidDeviceDescriptors = @($SetupDevices | Where-Object Type -eq "gpu" | Select-Object -Unique -ExpandProperty Model | Sort-Object) + @($SetupDevices | Where-Object Type -eq "gpu" | Select-Object -Unique -ExpandProperty Name | Sort-Object) + @($SetupDevices | Where-Object Type -eq "gpu" | Select-Object -ExpandProperty OpenCL | Where-Object PCIBusId -match "^\d+:\d+$" | Select-Object -Unique -ExpandProperty PCIBusId | Sort-Object) + @($SetupDevices | Where-Object Type -eq "gpu" | Select-Object -Unique -ExpandProperty Index | Sort-Object)

                        $OCProfile_Name = $OCProfile_Device = ""
                        do {
                            $OCProfile_Name = Read-HostString -Prompt "Which profile do you want to edit/create/delete? (leave empty to end profile config)" -Characters "A-Z0-9" -Default $OCProfile_Name | Foreach-Object {if ($Controls -icontains $_) {throw $_};$_}
                            if ($OCProfile_Name -eq '') {throw}
                            if (($SetupDevices | Where-Object Type -eq "gpu" | Measure-Object).Count) {
                                $OCProfile_Device = Read-HostString -Prompt "Assign this profile to a device? (choose Model, PCIBusId or Name - leave empty for none)" -Characters "A-Z0-9\:#" -Valid $ValidDeviceDescriptors | Foreach-Object {if (@("cancel","exit") -icontains $_) {throw $_};$_}
                                if ($OCProfile_Device -match "^\d+$") {$OCProfile_Device = "GPU#{0:d2}" -f [int]$OCProfile_Device}
                            }
                        } until (@("back","<") -inotcontains $OCProfile_Device)

                        if ($OCProfile_Device) {$OCProfile_Name += "-$OCProfile_Device"}

                        if (-not $OCProfilesActual.$OCProfile_Name) {
                            if (Read-HostBool "Do you want to create new profile `"$($OCProfile_Name)`"?" -Default $true) {
                                $OCProfilesActual | Add-Member $OCProfile_Name ([PSCustomObject]@{}) -Force
                                Set-ContentJson -PathToFile $ConfigFiles["OCProfiles"].Path -Data $OCProfilesActual > $null
                            } else {
                                $OCProfile_Name = ''
                            }
                        } else {
                            $OCProfile_Name = $OCProfilesActual.PSObject.Properties.Name | Where-Object {$_ -eq $OCProfile_Name}
                            $What = Read-HostString "Do you want to [e]dit or [d]elete `"$OCProfile_Name`"? (or enter [b]ack, to choose another)" -Characters "edb" -Mandatory -Default "e"                                            
                            if ($What -ne "e") {                                                
                                if ($What -eq "d") {
                                    $OCProfilesSave = [PSCustomObject]@{}
                                    $OCProfilesActual.PSObject.Properties | Where-Object {$_.Name -ne $OCProfile_Name} | Foreach-Object {$OCProfilesSave | Add-Member $_.Name $_.Value}                                                    
                                    Set-ContentJson -PathToFile $ConfigFiles["OCProfiles"].Path -Data $OCProfilesSave > $null
                                }
                                $OCProfile_Name = ""
                            }
                        }
                        if ($OCProfile_Name -eq '') {Clear-Host}
                    } until ($OCProfile_Name -ne '')

                    if ($OCProfile_Name) {
                        $OCProfileSetupStepsDone = $false
                        $OCProfileSetupStep = 0
                        [System.Collections.ArrayList]$OCProfileSetupSteps = @()
                        [System.Collections.ArrayList]$OCProfileSetupStepBack = @()

                        $OCProfileDefault = [PSCustomObject]@{
                            PowerLimit = 0
                            ThermalLimit = 0
                            MemoryClockBoost = "*"
                            CoreClockBoost = "*"
                            LockVoltagePoint = "*"
                        }
                        foreach($SetupName in $OCProfileDefault.PSObject.Properties.Name) {if ($OCProfilesActual.$OCProfile_Name.$SetupName -eq $null){$OCProfilesActual.$OCProfile_Name | Add-Member $SetupName $OCProfileDefault.$SetupName -Force}}

                        $OCProfileConfig = $OCProfilesActual.$OCProfile_Name.PSObject.Copy()

                        $OCProfileSetupSteps.AddRange(@("powerlimit","thermallimit","coreclockboost","memoryclockboost")) > $null
                        if (Get-Yes $ConfigActual.EnableOCVoltage) {$OCProfileSetupSteps.Add("lockvoltagepoint") >$null}
                        $OCProfileSetupSteps.Add("save") > $null
                                        
                        do {
                            $OCProfileSetupStepStore = $true
                            try {
                                Switch ($OCProfileSetupSteps[$OCProfileSetupStep]) {
                                    "powerlimit" {
                                        $OCProfileConfig.PowerLimit = Read-HostInt -Prompt "Enter the power limit in % (input 0 to never set)" -Default $OCProfileConfig.PowerLimit -Min 0 -Max 150 | Foreach-Object {if ($Controls -icontains $_) {throw $_};$_}
                                    }
                                    "thermallimit" {
                                        $OCProfileConfig.ThermalLimit = Read-HostInt -Prompt "Enter the thermal limit in °C (input 0 to never set)" -Default $OCProfileConfig.ThermalLimit -Min 0 -Max 100 | Foreach-Object {if ($Controls -icontains $_) {throw $_};$_}
                                    }
                                    "memoryclockboost" {
                                        $p = Read-HostString -Prompt "Enter a value for memory clock boost or `"*`" to never set" -Default $OCProfileConfig.MemoryClockBoost -Characters "0-9*+-" -Mandatory | Foreach-Object {if ($Controls -icontains $_) {throw $_};$_}
                                        if ($p -ne '*') {
                                            $p = $p -replace '\+'
                                            if ($p -match '^.+-' -or $p -eq '') {Write-Host "This is not a correct number" -ForegroundColor Yellow; throw "goto powerlimit"}
                                        }
                                        $OCProfileConfig.MemoryClockBoost = $p                                                            
                                    }
                                    "coreclockboost" {
                                        $p = Read-HostString -Prompt "Enter a value for core clock boost or `"*`" to never set" -Default $OCProfileConfig.CoreClockBoost -Characters "0-9*+-" -Mandatory | Foreach-Object {if ($Controls -icontains $_) {throw $_};$_}
                                        if ($p -ne '*') {
                                            $p = $p -replace '\+'
                                            if ($p -match '^.+-' -or $p -eq '') {Write-Host "This is not a correct number" -ForegroundColor Yellow; throw "goto coreclockboost"}
                                        }
                                        $OCProfileConfig.CoreClockBoost = $p                                                            
                                    }
                                    "lockvoltagepoint" {
                                        $p = Read-HostString -Prompt "Enter a value in µV to lock voltage or `"0`" to unlock, `"*`" to never set" -Default $OCProfileConfig.LockVoltagePoint -Characters "0-9*+-" -Mandatory | Foreach-Object {if ($Controls -icontains $_) {throw $_};$_}
                                        if ($p -ne '*') {
                                            $p = $p -replace '[^0-9]+'
                                            if ($p -eq '') {Write-Host "This is not a correct number" -ForegroundColor Yellow; throw "goto lockvoltagepoint"}
                                        }
                                        $OCProfileConfig.LockVoltagePoint = $p                                                            
                                    }
                                    "save" {
                                        Write-Host " "
                                        if (-not (Read-HostBool -Prompt "Done! Do you want to save the changed values?" -Default $True | Foreach-Object {if ($Controls -icontains $_) {throw $_};$_})) {throw "cancel"}
                                                        
                                        $OCProfilesActual | Add-Member $OCProfile_Name $OCProfileConfig -Force
                                        $OCProfilesActualSave = [PSCustomObject]@{}
                                        $OCProfilesActual.PSObject.Properties.Name | Sort-Object | Foreach-Object {$OCProfilesActualSave | Add-Member $_ ($OCProfilesActual.$_) -Force}

                                        Set-ContentJson -PathToFile $ConfigFiles["OCProfiles"].Path -Data $OCProfilesActualSave > $null

                                        Write-Host " "
                                        Write-Host "Changes written to profiles configuration. " -ForegroundColor Cyan
                                                    
                                        $OCProfileSetupStepsDone = $true
                                    }
                                }
                                if ($OCProfileSetupStepStore) {$OCProfileSetupStepBack.Add($OCProfileSetupStep) > $null}
                                $OCProfileSetupStep++
                            }
                            catch {
                                if ($Error.Count){$Error.RemoveAt(0)}
                                if (@("back","<") -icontains $_.Exception.Message) {
                                    if ($OCProfileSetupStepBack.Count) {$OCProfileSetupStep = $OCProfileSetupStepBack[$OCProfileSetupStepBack.Count-1];$OCProfileSetupStepBack.RemoveAt($OCProfileSetupStepBack.Count-1)}
                                }
                                elseif (@("exit","cancel") -icontains $_.Exception.Message) {
                                    Write-Host " "
                                    Write-Host "Cancelled without changing the configuration" -ForegroundColor Red
                                    Write-Host " "
                                    $OCProfileSetupStepsDone = $true                                               
                                }
                                else {
                                    if ($OCProfileSetupStepStore) {$OCProfileSetupStepBack.Add($OCProfileSetupStep) > $null}
                                    $NextSetupStep = Switch -Regex ($_.Exception.Message) {
                                                        "^Goto\s+(.+)$" {$Matches[1]}
                                                        "^done$"  {"save"}
                                                        default {$_}
                                                    }
                                    $OCProfileSetupStep = $OCProfileSetupSteps.IndexOf($NextSetupStep)
                                    if ($OCProfileSetupStep -lt 0) {
                                        Write-Log -Level Error "Unknown goto command `"$($NextSetupStep)`". You should never reach here. Please open an issue on github.com"
                                        $OCProfileSetupStep = $OCProfileSetupStepBack[$OCProfileSetupStepBack.Count-1];$OCProfileSetupStepBack.RemoveAt($OCProfileSetupStepBack.Count-1)
                                    }
                                }
                            }
                        } until ($OCProfileSetupStepsDone)                                                                        

                    } else {
                        Write-Host "Please try again later" -ForegroundColor Yellow
                    }

                    Write-Host " "
                    if (-not (Read-HostBool "Edit another profile?")){throw}
                        
                } catch {if ($Error.Count){$Error.RemoveAt(0)};$OCProfileSetupDone = $true}
            } until ($OCProfileSetupDone)
        }
        elseif ($SetupType -eq "H") {

            Clear-Host

            Write-Host " "
            Write-Host "*** Scheduler Configuration ***" -BackgroundColor Green -ForegroundColor Black
            Write-HostSetupHints
            Write-Host " "

            $SchedulerSetupDone = $false
            do {
                try {
                    $SchedulerActual = Get-Content $ConfigFiles["Scheduler"].Path | ConvertFrom-Json
                    $i = 0; $SchedulerActual | Foreach-Object {$_ | Add-Member Index $i -Force;$i++}
                    Write-Host " "
                    $p = [console]::ForegroundColor
                    [console]::ForegroundColor = "Cyan"
                    Write-Host "Current schedules:"

                    $SchedulerActual | Format-Table @(
                        @{Label="No"; Expression={$_.Index}}
                        @{Label="DayOfWeek"; Expression={"$(if ($_.DayOfWeek -eq "*") {"*"} else {$_.DayOfWeek})"};align="center"}
                        @{Label="From"; Expression={"$((Get-HourMinStr $_.From).SubString(0,5))"}}
                        @{Label="To"; Expression={"$((Get-HourMinStr $_.To -To).SubString(0,5))"}}
                        @{Label="Pause"; Expression={"$(if (Get-Yes $_.Pause) {"1"} else {"0"})"};align="center"}
                        @{Label="Enable"; Expression={"$(if (Get-Yes $_.Enable) {"1"} else {"0"})"};align="center"}
                    )
                    Write-Host "DayofWeek: *=all $(((0..6) | %{"$($_)=$([DayOfWeek]$_)"}) -join ' ')"
                    Write-Host " "
                    [console]::ForegroundColor = $p

                    $Index = -1                    
                    $Scheduler_Action = Read-HostString "Please choose: [a]dd, [e]dit, [d]elete (enter exit to end scheduler config)" -Valid @("a","e","d") | Foreach-Object {if ($Controls -icontains $_) {throw $_};$_}
                    if ($Scheduler_Action -eq "x") {throw "exit"}

                    $ScheduleDefault = [PSCustomObject]@{
                        DayOfWeek = ""
                        From = ""
                        To = ""
                        PowerPrice = ""
                        Enable = "0"
                        Pause = "0"                            
                    }

                    if ($Scheduler_Action -eq "a") {
                        $Schedule = $ScheduleDefault.PSObject.Copy()
                    } else {
                        $Index = Read-HostInt "Enter the schedule-number to $(if ($Scheduler_Action -eq "e") {"edit"} else {"delete"})" -Min 0 -Max (($SchedulerActual | Measure-Object).Count-1) | Foreach-Object {if ($Controls -icontains $_) {throw $_};$_}
                        $Schedule = ($SchedulerActual | Select-Object -Index $Index).PSObject.Copy()
                        foreach($SetupName in $ScheduleDefault.PSObject.Properties.Name) {if ($Schedule.$SetupName -eq $null){$Schedule | Add-Member $SetupName $ScheduleDefault.$SetupName -Force}}
                    }

                    [System.Collections.ArrayList]$SchedulerSetupSteps = @()
                    [System.Collections.ArrayList]$SchedulerSetupStepBack = @()
                    $SchedulerSetupStepsDone = $false
                    $SchedulerSetupStep = 0

                    if ($Scheduler_Action -ne "d") {
                        $SchedulerSetupSteps.AddRange(@("dayofweek","from","to","powerprice","pause","enable")) > $null
                    }
                    $SchedulerSetupSteps.Add("save") > $null

                    do {
                        $SchedulerSetupStepStore = $true
                        try {
                            Switch ($SchedulerSetupSteps[$SchedulerSetupStep]) {
                                "dayofweek" {
                                    $Schedule.DayOfWeek = Read-HostString -Prompt "Enter on which day of week this schedule activates" -Default $Schedule.DayOfWeek -Valid @("all","*","0","1","2","3","4","5","6") -Mandatory -Characters "0-9\*" | Foreach-Object {if ($Controls -icontains $_) {throw $_};$_}
                                    if ($Schedule.DayOfWeek -eq "all") {$Schedule.DayOfWeek = "*"}
                                }
                                "from" {
                                    $Schedule.From = Read-HostString -Prompt "Enter when this schedule starts" -Default $Schedule.From -Characters "0-9amp: " | Foreach-Object {if ($Controls -icontains $_) {throw $_};$_}
                                    $Schedule.From = Get-HourMinStr $Schedule.From
                                }
                                "to" {
                                    $Schedule.To = Read-HostString -Prompt "Enter when this schedule ends" -Default $Schedule.To -Characters "0-9amp: " | Foreach-Object {if ($Controls -icontains $_) {throw $_};$_}
                                    $Schedule.To = Get-HourMinStr $Schedule.To -To
                                }
                                "powerprice" {
                                    $Schedule.PowerPrice = Read-HostString -Prompt "Enter this schedule's powerprice (leave empty for global default)" -Default $Schedule.PowerPrice -Characters "0-9,\.-" | Foreach-Object {if ($Controls -icontains $_) {throw $_};$_}
                                    $Schedule.PowerPrice = $Schedule.PowerPrice -replace ",","." -replace "[^0-9\.-]+"
                                }
                                "pause" {
                                    $Schedule.Pause = Read-HostBool -Prompt "Pause miners during this schedule?" -Default $Schedule.Pause | Foreach-Object {if ($Controls -icontains $_) {throw $_};$_}
                                }
                                "enable" {
                                    $Schedule.Enable = Read-HostBool -Prompt "Enable this schedule?" -Default $Schedule.Enable | Foreach-Object {if ($Controls -icontains $_) {throw $_};$_}
                                }
                                "save" {
                                    Write-Host " "
                                    if ($Scheduler_Action -eq "d") {
                                        if (-not (Read-HostBool -Prompt "Do you really want to delete schedule number $($Index)?" -Default $True | Foreach-Object {if ($Controls -icontains $_) {throw $_};$_})) {throw "cancel"}
                                        $SchedulerActual = $SchedulerActual | Where Index -ne $Index
                                    } else {
                                        if (-not (Read-HostBool -Prompt "Done! Do you want to save the changed values?" -Default $True | Foreach-Object {if ($Controls -icontains $_) {throw $_};$_})) {throw "cancel"}
                                        if ($Index -eq -1) {$SchedulerActual += $Schedule} else {$SchedulerActual[$Index] = $Schedule}
                                    }

                                    $SchedulerSave = @()
                                    $SchedulerActual | Foreach-Object {
                                        $SchedulerSave += [PSCustomObject]@{
                                            DayOfWeek  = $_.DayOfWeek
                                            From       = $_.From
                                            To         = $_.To
                                            PowerPrice = $_.PowerPrice
                                            Pause      = if (Get-Yes $_.Pause) {"1"} else {"0"}
                                            Enable     = if (Get-Yes $_.Enable) {"1"} else {"0"}
                                        }
                                    }
                                    Set-ContentJson -PathToFile $ConfigFiles["Scheduler"].Path -Data $SchedulerSave > $null

                                    Write-Host " "
                                    Write-Host "Changes written to schedule configuration. " -ForegroundColor Cyan
                                                    
                                    $SchedulerSetupStepsDone = $true
                                }
                            }
                            if ($SchedulerSetupStepStore) {$SchedulerSetupStepBack.Add($SchedulerSetupStep) > $null}
                            $SchedulerSetupStep++
                        }
                        catch {
                            if ($Error.Count){$Error.RemoveAt(0)}
                            if (@("back","<") -icontains $_.Exception.Message) {
                                if ($SchedulerSetupStepBack.Count) {$SchedulerSetupStep = $SchedulerSetupStepBack[$SchedulerSetupStepBack.Count-1];$SchedulerSetupStepBack.RemoveAt($SchedulerSetupStepBack.Count-1)}
                            }
                            elseif (@("exit","cancel") -icontains $_.Exception.Message) {
                                Write-Host " "
                                Write-Host "Cancelled without changing the configuration" -ForegroundColor Red
                                Write-Host " "
                                $SchedulerSetupStepsDone = $true                                               
                            }
                            else {
                                if ($SchedulerSetupStepStore) {$SchedulerSetupStepBack.Add($SchedulerSetupStep) > $null}
                                $NextSetupStep = Switch -Regex ($_.Exception.Message) {
                                                    "^Goto\s+(.+)$" {$Matches[1]}
                                                    "^done$"  {"save"}
                                                    default {$_}
                                                }
                                $SchedulerSetupStep = $SchedulerSetupSteps.IndexOf($NextSetupStep)
                                if ($SchedulerSetupStep -lt 0) {
                                    Write-Log -Level Error "Unknown goto command `"$($NextSetupStep)`". You should never reach here. Please open an issue on github.com"
                                    $SchedulerSetupStep = $SchedulerSetupStepBack[$SchedulerSetupStepBack.Count-1];$SchedulerSetupStepBack.RemoveAt($SchedulerSetupStepBack.Count-1)
                                }
                            }
                        }
                    } until ($SchedulerSetupStepsDone)
                        
                } catch {
                    if ($Error.Count){$Error.RemoveAt(0)}
                    if ($Index -eq -1 -or @("back","<") -inotcontains $_.Exception.Message) {$SchedulerSetupDone = $true}
                }
            } until ($SchedulerSetupDone)
        }
        elseif ($SetupType -eq "R") {

            Import-Module ".\MiningRigRentals.psm1"

            Clear-Host

            $Pool_Name = "MiningRigRentals"

            Write-Host " "
            Write-Host "*** $($Pool_Name) Configuration ***" -BackgroundColor Green -ForegroundColor Black
            Write-HostSetupHints

            do {
                $PoolsActual = Get-Content $ConfigFiles["Pools"].Path | ConvertFrom-Json
                $Pool_Config = $PoolsActual.MiningRigRentals

                $Run_MRRConfig = $true
                if (-not $Pool_Config -or -not $Pool_Config.API_Key -or -not $Pool_Config.API_Secret) {
                    Write-Host "MiningRigRental pool is not configured yet." -ForegroundColor Red
                    Write-Host " "
                    Write-Host "Please go to pool configuration and make sure, that you enter your API-Key and API-Secret." -ForegroundColor Yellow
                    $Run_MRRConfig = $false
                } elseif (-not ($MinerData = Get-Content ".\Data\minerdata.json" -Raw -ErrorAction Ignore | ConvertFrom-Json -ErrorAction Ignore)) {
                    Write-Host "No benchmarked miners found." -ForegroundColor Red
                    Write-Host " "
                    Write-Host "Please let all benchmarks run first." -ForegroundColor Yellow
                    $Run_MRRConfig = $false
                }

                if (-not $Run_MRRConfig) {
                    Write-Host " "
                    Read-HostKey "Press any key to exit MRR config " > $null
                    break
                }
                
                $Pool_Workers = @($DevicesActual.PSObject.Properties.Value | Where-Object {$_.Worker} | Select-Object -ExpandProperty Worker) + $(if ($Pool_Config.Worker -eq "`$WorkerName") {$ConfigActual.WorkerName} else {$Pool_Config.Worker}) | Select-Object -Unique

                $Pool_Request = Get-MiningRigRentalAlgos
                $Pool_Rigs = Get-MiningRigRentalRigs -key $Pool_Config.API_Key -secret $Pool_Config.API_Secret -workers $Pool_Workers

                $Rig_Profitability = Get-Stat "ProfitNonMRR"

                Write-Host " "

                $p = [console]::ForegroundColor
                [console]::ForegroundColor = "Cyan"
                Write-Host "Rig's profitabiliy: $(ConvertTo-BTC $Rig_Profitability.Day)"
                Write-Host " "
                Write-Host "Created rigs:"
                $Pool_Rigs | Sort-Object {Get-MiningRigRentalAlgorithm $_.type} | Format-Table @(
                        @{Label="ID"; Expression={$_.id}}
                        @{Label="Algorithm";Expression={Get-MiningRigRentalAlgorithm $_.type}}
                        @{Label="Hashrate"; Expression={"$([Math]::Round([decimal]$_.hashrate.advertised.hash,4)) $($_.hashrate.advertised.type.ToUpper())"};align="right"}
                        @{Label="Price BTC"; Expression={if ($_.price.BTC.enabled) {"$($_.price.BTC.price)/$($_.price.type.ToUpper())"} else {"-"}}}
                        @{Label="min. BTC"; Expression={if ($_.price.BTC.enabled -and $_.price.BTC.minimum) {"$($_.price.BTC.minimum)/$($_.price.type.ToUpper())"} else {"-"}}}
                        @{Label="Hours"; Expression={"$($_.minhours)-$($_.maxhours)"}}
                        @{Label="Worker"; Expression={(([regex]'(?m)\[(.+)\]').Matches($_.description) | % Groups | ? name -eq 1 | Select-Object -ExpandProperty Value -Unique | Sort-Object) -join ','}}
                        @{Label="?"; Expression={$_.status.status.Substring(0,1).ToUpper()}}
                        @{Label="Rental"; Expression={if ($_.status.status -eq "rented") {$ts=[timespan]::fromhours($_.status.hours);"{0:00}h{1:00}m{2:00}s" -f [Math]::Floor($ts.TotalHours),$ts.Minutes,$ts.Seconds} else {"-"}};align="right"}
                        @{Label="Name"; Expression={$_.name}}
                    )
                Write-Host "? A=available, D=disabled, R=rented"
                Write-Host " "

                [console]::ForegroundColor = $p

                $MRRSetupType = Read-HostString -Prompt "ID to edit, [C]reate, [U]pdate prices, E[x]it MRR config" -Default "X"  -Mandatory -Characters "0123456789CUX"
                Write-Host " "

                if ($MRRSetupType -match "(\d+)") {
                    $Rig_ID = [int]$Matches[1]
                    $MRRSetupDone = $false
                    do {
                        try {
                            $MRRActual = $Pool_Rigs | Where-Object id -eq $Rig_ID | Foreach-Object {
                                [PSCustomObject]@{
                                    name = $_.name
                                    description = $_.description
                                    region = $_.region
                                    ndevices = $_.ndevices
                                    extensions = get-yes $_.extensions

                                }
                            }
                            if (-not $MRRActual) {throw "Rig-ID $Rig_ID not found!"}

                            $MRRSetupStepsDone = $false
                            $MRRSetupStep = 0
                            [System.Collections.ArrayList]$MRRSetupSteps = @()
                            [System.Collections.ArrayList]$MRRSetupStepBack = @()

                            $MRRSetupSteps.AddRange(@("name","workers","description","region","hashrate","pricebtc","minpricebtc","autopricebtc","currencies")) > $null
                            $MRRSetupSteps.Add("save") > $null

                            do {
                                $MRRSetupStepStore = $true
                                try {
                                    Switch ($MRRSetupSteps[$MRRSetupStep]) {
                                        "autopricebtc" {                                        
                                            if (Get-Yes $PoolsActual.$Pool_Name.EnableAutoCreate) {
                                                $MRRConfig.EnableAutoCreate = Read-HostBool -Prompt $PoolsSetup.$Pool_Name.SetupFields.EnableAutoCreate -Default $MRRConfig.EnableAutoCreate | Foreach-Object {if ($Controls -icontains $_) {throw $_};$_}
                                            } else {
                                                $MRRSetupStepStore = $false
                                            }
                                        }
                                        "pricebtc" {
                                            $MRRConfig.PriceBTC = Read-HostDouble -Prompt "$($PoolsSetup.$Pool_Name.SetupFields.PriceBTC) (enter 0 to use pool's default)" -Default $MRRConfig.PriceBTC -Min 0 | Foreach-Object {if ($Controls -icontains $_) {throw $_};$_}
                                        }
                                        "name" {
                                            $MRRConfig.name = Read-HostString -Prompt "" -Default $MRRConfig.name -Characters "" | Foreach-Object {if ($Controls -icontains $_) {throw $_};$_}
                                        }
                                        "description" {
                                            $MRRConfig.description = Read-HostString -Prompt "" -Default $MRRConfig.Description -Characters "" | Foreach-Object {if ($Controls -icontains $_) {throw $_};$_}
                                        }

                                        "save" {
                                            Write-Host " "
                                            if (-not (Read-HostBool -Prompt "Done! Do you want to save the changed values?" -Default $True | Foreach-Object {if ($Controls -icontains $_) {throw $_};$_})) {throw "cancel"}

                                            $MRRConfig | Add-Member EnableAutoCreate $(if (Get-Yes $MRRConfig.EnableAutoCreate) {"1"} else {"0"}) -Force
                                            $MRRConfig | Add-Member EnableAutoPrice $(if (Get-Yes $MRRConfig.EnableAutoPrice) {"1"} else {"0"}) -Force
                                            $MRRConfig | Add-Member EnablePriceUpdates $(if (Get-Yes $MRRConfig.EnablePriceUpdates) {"1"} else {"0"}) -Force
                                            $MRRConfig | Add-Member EnableMinimumPrice $(if (Get-Yes $MRRConfig.EnableMinimumPrice) {"1"} else {"0"}) -Force
                                            $MRRConfig | Add-Member PriceBTC "$($MRRConfig.PriceBTC)" -Force
                                            $MRRConfig | Add-Member PriceFactor "$($MRRConfig.PriceFactor)" -Force

                                            $MRRActual | Add-Member $MRR_Name $MRRConfig -Force
                                            $MRRActualSave = [PSCustomObject]@{}
                                            $MRRActual.PSObject.Properties.Name | Sort-Object | Foreach-Object {$MRRActualSave | Add-Member $_ ($MRRActual.$_) -Force}
                                                        
                                            Set-ContentJson -PathToFile $ConfigFiles["MRR"].Path -Data $MRRActualSave > $null

                                            Write-Host " "
                                            Write-Host "Changes written to $($Pool_Name) configuration. " -ForegroundColor Cyan
                                                    
                                            $MRRSetupStepsDone = $true
                                        }
                                    }
                                    if ($MRRSetupStepStore) {$MRRSetupStepBack.Add($MRRSetupStep) > $null}
                                    $MRRSetupStep++
                                }
                                catch {
                                    if ($Error.Count){$Error.RemoveAt(0)}
                                    if (@("back","<") -icontains $_.Exception.Message) {
                                        if ($MRRSetupStepBack.Count) {$MRRSetupStep = $MRRSetupStepBack[$MRRSetupStepBack.Count-1];$MRRSetupStepBack.RemoveAt($MRRSetupStepBack.Count-1)}
                                    }
                                    elseif (@("exit","cancel") -icontains $_.Exception.Message) {
                                        Write-Host " "
                                        Write-Host "Cancelled without changing the configuration" -ForegroundColor Red
                                        Write-Host " "
                                        $MRRSetupStepsDone = $true                                               
                                    }
                                    else {
                                        if ($MRRSetupStepStore) {$MRRSetupStepBack.Add($MRRSetupStep) > $null}
                                        $NextSetupStep = Switch -Regex ($_.Exception.Message) {
                                                            "^Goto\s+(.+)$" {$Matches[1]}
                                                            "^done$"  {"save"}
                                                            default {$_}
                                                        }
                                        $MRRSetupStep = $MRRSetupSteps.IndexOf($NextSetupStep)
                                        if ($MRRSetupStep -lt 0) {
                                            Write-Log -Level Error "Unknown goto command `"$($NextSetupStep)`". You should never reach here. Please open an issue on github.com"
                                            $MRRSetupStep = $MRRSetupStepBack[$MRRSetupStepBack.Count-1];$MRRSetupStepBack.RemoveAt($MRRSetupStepBack.Count-1)
                                        }
                                    }
                                }
                            } until ($MRRSetupStepsDone)
                            

                            Write-Host " "
                            if (-not (Read-HostBool "Edit another algorithm?")){throw}
                        
                        } catch {
                            if ($_.Exception.Message) {
                                Write-Host $_.Exception.Message -ForegroundColor Yellow
                            }
                            if ($Error.Count){$Error.RemoveAt(0)};
                            $MRRSetupDone = $true
                        }
                    } until ($MRRSetupDone)


                } elseif ($MRRSetupType -eq "C") {
                    Invoke-MiningRigRentalCreateRigs
                } elseif ($MRRSetupType -eq "U") {
                    Invoke-MiningRigRentalUpdatePrices
                } elseif ($MRRSetupType -eq "R") {
                    $MRRSetupDone = $false
                    do {
                        try {
                            $MRRActual = Get-Content $ConfigFiles["MRR"].Path | ConvertFrom-Json
                            $MRR_Name = Read-HostString -Prompt "Which algorithm do you want to configure? (leave empty to end algorithm config)" -Characters "A-Z0-9" -Valid $MRRActual.PSObject.Properties.Name | Foreach-Object {if ($Controls -icontains $_) {throw $_};$_}
                            if ($MRR_Name -eq '') {throw}

                            if ($MRR_Name) {
                                $MRRSetupStepsDone = $false
                                $MRRSetupStep = 0
                                [System.Collections.ArrayList]$MRRSetupSteps = @()
                                [System.Collections.ArrayList]$MRRSetupStepBack = @()

                                $MRRConfig = $MRRActual.$MRR_Name.PSObject.Copy()
                                foreach($SetupName in $MRRDefault.PSObject.Properties.Name) {if ($MRRConfig.$SetupName -eq $null){$MRRConfig | Add-Member $SetupName $MRRDefault.$SetupName -Force}}

                                $MRRSetupSteps.AddRange(@("enableautocreate","enablepriceupdates","enableautoprice","enableminimumprice","pricebtc","pricefactor","title","description")) > $null
                                $MRRSetupSteps.Add("save") > $null

                                do {
                                    $MRRSetupStepStore = $true
                                    try {
                                        Switch ($MRRSetupSteps[$MRRSetupStep]) {
                                            "enableautocreate" {                                        
                                                if (Get-Yes $PoolsActual.$Pool_Name.EnableAutoCreate) {
                                                    $MRRConfig.EnableAutoCreate = Read-HostBool -Prompt $PoolsSetup.$Pool_Name.SetupFields.EnableAutoCreate -Default $MRRConfig.EnableAutoCreate | Foreach-Object {if ($Controls -icontains $_) {throw $_};$_}
                                                } else {
                                                    $MRRSetupStepStore = $false
                                                }
                                            }
                                            "enableautoprice" {
                                                if (Get-Yes $PoolsActual.$Pool_Name.EnableAutoPrice) {
                                                    $MRRConfig.EnableAutoPrice = Read-HostBool -Prompt $PoolsSetup.$Pool_Name.SetupFields.EnableAutoPrice -Default $MRRConfig.EnableAutoPrice | Foreach-Object {if ($Controls -icontains $_) {throw $_};$_}
                                                } else {
                                                    $MRRSetupStepStore = $false
                                                }
                                            }
                                            "enablepriceupdates" {
                                                if (Get-Yes $PoolsActual.$Pool_Name.EnablePriceUpdates) {
                                                    $MRRConfig.EnablePriceUpdates = Read-HostBool -Prompt $PoolsSetup.$Pool_Name.SetupFields.EnablePriceUpdates -Default $MRRConfig.EnablePriceUpdates | Foreach-Object {if ($Controls -icontains $_) {throw $_};$_}
                                                } else {
                                                    $MRRSetupStepStore = $false
                                                }
                                            }
                                            "enableminimumprice" {
                                                if (Get-Yes $PoolsActual.$Pool_Name.EnableMinimumPrice) {
                                                    $MRRConfig.EnableMinimumPrice = Read-HostBool -Prompt $PoolsSetup.$Pool_Name.SetupFields.EnableMinimumPrice -Default $MRRConfig.EnableMinimumPrice | Foreach-Object {if ($Controls -icontains $_) {throw $_};$_}
                                                } else {
                                                    $MRRSetupStepStore = $false
                                                }
                                            }
                                            "pricebtc" {
                                                $MRRConfig.PriceBTC = Read-HostDouble -Prompt "$($PoolsSetup.$Pool_Name.SetupFields.PriceBTC) (enter 0 to use pool's default)" -Default $MRRConfig.PriceBTC -Min 0 | Foreach-Object {if ($Controls -icontains $_) {throw $_};$_}
                                            }
                                            "pricefactor" {
                                                $MRRConfig.PriceFactor = Read-HostDouble -Prompt "$($PoolsSetup.$Pool_Name.SetupFields.PriceFactor) (enter 0 to use pool's default)" -Default $MRRConfig.PriceFactor -Min 0 | Foreach-Object {if ($Controls -icontains $_) {throw $_};$_}
                                            }
                                            "title" {
                                                $MRRConfig.Title = Read-HostString -Prompt "$($PoolsSetup.$Pool_Name.SetupFields.Title) ($(if ($MRRConfig.Title) {"clear"} else {"leave empty"}) to use pool's default)" -Default $MRRConfig.Title -Characters "" | Foreach-Object {if ($Controls -icontains $_) {throw $_};$_}
                                            }
                                            "description" {
                                                $MRRConfig.Description = Read-HostString -Prompt "$($PoolsSetup.$Pool_Name.SetupFields.Description) ($(if ($MRRConfig.Description) {"clear"} else {"leave empty"}) to use pool's default)" -Default $MRRConfig.Description -Characters "" | Foreach-Object {if ($Controls -icontains $_) {throw $_};$_}
                                            }

                                            "save" {
                                                Write-Host " "
                                                if (-not (Read-HostBool -Prompt "Done! Do you want to save the changed values?" -Default $True | Foreach-Object {if ($Controls -icontains $_) {throw $_};$_})) {throw "cancel"}

                                                $MRRConfig | Add-Member EnableAutoCreate $(if (Get-Yes $MRRConfig.EnableAutoCreate) {"1"} else {"0"}) -Force
                                                $MRRConfig | Add-Member EnableAutoPrice $(if (Get-Yes $MRRConfig.EnableAutoPrice) {"1"} else {"0"}) -Force
                                                $MRRConfig | Add-Member EnablePriceUpdates $(if (Get-Yes $MRRConfig.EnablePriceUpdates) {"1"} else {"0"}) -Force
                                                $MRRConfig | Add-Member EnableMinimumPrice $(if (Get-Yes $MRRConfig.EnableMinimumPrice) {"1"} else {"0"}) -Force
                                                $MRRConfig | Add-Member PriceBTC "$($MRRConfig.PriceBTC)" -Force
                                                $MRRConfig | Add-Member PriceFactor "$($MRRConfig.PriceFactor)" -Force

                                                $MRRActual | Add-Member $MRR_Name $MRRConfig -Force
                                                $MRRActualSave = [PSCustomObject]@{}
                                                $MRRActual.PSObject.Properties.Name | Sort-Object | Foreach-Object {$MRRActualSave | Add-Member $_ ($MRRActual.$_) -Force}
                                                        
                                                Set-ContentJson -PathToFile $ConfigFiles["MRR"].Path -Data $MRRActualSave > $null

                                                Write-Host " "
                                                Write-Host "Changes written to $($Pool_Name) configuration. " -ForegroundColor Cyan
                                                    
                                                $MRRSetupStepsDone = $true
                                            }
                                        }
                                        if ($MRRSetupStepStore) {$MRRSetupStepBack.Add($MRRSetupStep) > $null}
                                        $MRRSetupStep++
                                    }
                                    catch {
                                        if ($Error.Count){$Error.RemoveAt(0)}
                                        if (@("back","<") -icontains $_.Exception.Message) {
                                            if ($MRRSetupStepBack.Count) {$MRRSetupStep = $MRRSetupStepBack[$MRRSetupStepBack.Count-1];$MRRSetupStepBack.RemoveAt($MRRSetupStepBack.Count-1)}
                                        }
                                        elseif (@("exit","cancel") -icontains $_.Exception.Message) {
                                            Write-Host " "
                                            Write-Host "Cancelled without changing the configuration" -ForegroundColor Red
                                            Write-Host " "
                                            $MRRSetupStepsDone = $true                                               
                                        }
                                        else {
                                            if ($MRRSetupStepStore) {$MRRSetupStepBack.Add($MRRSetupStep) > $null}
                                            $NextSetupStep = Switch -Regex ($_.Exception.Message) {
                                                                "^Goto\s+(.+)$" {$Matches[1]}
                                                                "^done$"  {"save"}
                                                                default {$_}
                                                            }
                                            $MRRSetupStep = $MRRSetupSteps.IndexOf($NextSetupStep)
                                            if ($MRRSetupStep -lt 0) {
                                                Write-Log -Level Error "Unknown goto command `"$($NextSetupStep)`". You should never reach here. Please open an issue on github.com"
                                                $MRRSetupStep = $MRRSetupStepBack[$MRRSetupStepBack.Count-1];$MRRSetupStepBack.RemoveAt($MRRSetupStepBack.Count-1)
                                            }
                                        }
                                    }
                                } until ($MRRSetupStepsDone)
                            } else {
                                Write-Host "Please try again later" -ForegroundColor Yellow
                            }

                            Write-Host " "
                            if (-not (Read-HostBool "Edit another algorithm?")){throw}
                        
                        } catch {if ($Error.Count){$Error.RemoveAt(0)};$MRRSetupDone = $true}
                    } until ($MRRSetupDone)
                }
            } until ($MRRSetupType -eq "X")
        }
    } until (-not $RunSetup)
}