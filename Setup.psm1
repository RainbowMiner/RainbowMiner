
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
        [Bool]$IsInitialSetup = $false
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

        $CoinsDefault = [PSCustomObject]@{Penalty = "0";MinHashrate = "0";MinWorkers = "0";MaxTimeToFind="0";Wallet="";EnableAutoPool="0";PostBlockMining="0"}

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
            $TotalSwap = (Get-CimInstance Win32_PageFile | Select-Object -ExpandProperty FileSize | Measure-Object -Sum).Sum / 1GB
            if ($TotalSwap -and $TotalMem -gt $TotalSwap) {
                Write-Log -Level Warn "You should increase your windows pagefile to at least $TotalMem GB"
                Write-Host " "
            }
        } catch {}

        if ($IsInitialSetup) {
            $SetupType = "A" 
            $ConfigSetup = Get-ChildItemContent ".\Data\ConfigDefault.ps1" | Select-Object -ExpandProperty Content
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
            Write-Host " "
            if (-not $Config.Wallet -or -not $Config.WorkerName -or -not $Config.PoolName) {
                Write-Host " WARNING: without the following data, RainbowMiner is not able to start mining. " -BackgroundColor Yellow -ForegroundColor Black
                if (-not $Config.Wallet)     {Write-Host "- No BTC-wallet defined! Please go to [W]allets and input your wallet! " -ForegroundColor Yellow}
                if (-not $Config.WorkerName) {Write-Host "- No workername defined! Please go to [W]allets and input a workername! " -ForegroundColor Yellow}
                if (-not $Config.PoolName)   {Write-Host "- No pool selected! Please go to [S]elections and add some pools! " -ForegroundColor Yellow}            
                Write-Host " "
            }
            $SetupType = Read-HostString -Prompt "[W]allets, [C]ommon, [E]nergycosts, [S]elections, [A]ll, [M]iners, [P]ools, [D]evices, A[l]gorithms, Co[i]ns, [O]C-Profiles, [N]etwork, E[x]it configuration and start mining" -Default "X"  -Mandatory -Characters "WCESAMPDLIONX"
        }

        if ($SetupType -eq "X") {
            $RunSetup = $false
        }
        elseif (@("W","C","E","S","A","N") -contains $SetupType) {
                            
            $GlobalSetupDone = $false
            $GlobalSetupStep = 0
            [System.Collections.ArrayList]$GlobalSetupSteps = @()
            [System.Collections.ArrayList]$GlobalSetupStepBack = @()

            Switch ($SetupType) {
                "W" {$GlobalSetupName = "Wallet";$GlobalSetupSteps.AddRange(@("wallet","nicehash","workername","username","apiid","apikey")) > $null}
                "C" {$GlobalSetupName = "Common";$GlobalSetupSteps.AddRange(@("miningmode","devicename","devicenameend","cpuminingthreads","cpuminingaffinity","gpuminingaffinity","pooldatawindow","poolstataverage","hashrateweight","hashrateweightstrength","poolaccuracyweight","defaultpoolregion","region","currency","enableminerstatus","minerstatusurl","minerstatuskey","minerstatusemail","pushoveruserkey","uistyle","fastestmineronly","showpoolbalances","showpoolbalancesdetails","showpoolbalancesexcludedpools","showminerwindow","ignorefees","enableocprofiles","enableocvoltage","enableresetvega","msia","msiapath","nvsmipath","ethpillenable","enableautominerports","enableautoupdate","enableautoalgorithmadd","enableautobenchmark")) > $null}
                "E" {$GlobalSetupName = "Energycost";$GlobalSetupSteps.AddRange(@("powerpricecurrency","powerprice","poweroffset","usepowerprice","checkprofitability")) > $null}
                "S" {$GlobalSetupName = "Selection";$GlobalSetupSteps.AddRange(@("poolname","minername","excludeminername","excludeminerswithfee","disabledualmining","enablecheckminingconflict","algorithm","excludealgorithm","excludecoinsymbol","excludecoin")) > $null}
                "N" {$GlobalSetupName = "Network";$GlobalSetupSteps.AddRange(@("apiport","apiinit","apiauth","apiuser","apipassword","runmode","serverinit","serverinit2","servername","serverport","serveruser","serverpassword")) > $null}
                "A" {$GlobalSetupName = "All";$GlobalSetupSteps.AddRange(@("startsetup","wallet","nicehash","addcoins1","addcoins2","addcoins3","workername","username","apiid","apikey","region","currency","benchmarkintervalsetup","enableminerstatus","minerstatusurl","minerstatuskey","minerstatusemail","pushoveruserkey","apiport","apiinit","apiauth","apiuser","apipassword","enableautominerports","enableautoupdate","enableautoalgorithmadd","enableautobenchmark","poolname","autoaddcoins","minername","excludeminername","algorithm","excludealgorithm","excludecoinsymbol","excludecoin","disabledualmining","excludeminerswithfee","enablecheckminingconflict","devicenamebegin","miningmode","devicename","devicenamewizard","devicenamewizardgpu","devicenamewizardamd1","devicenamewizardamd2","devicenamewizardnvidia1","devicenamewizardnvidia2","devicenamewizardcpu1","devicenamewizardend","devicenameend","cpuminingthreads","cpuminingaffinity","gpuminingaffinity","pooldatawindow","poolstataverage","hashrateweight","hashrateweightstrength","poolaccuracyweight","defaultpoolregion","uistyle","fastestmineronly","showpoolbalances","showpoolbalancesdetails","showpoolbalancesexcludedpools","showminerwindow","ignorefees","watchdog","enableocprofiles","enableocvoltage","enableresetvega","msia","msiapath","nvsmipath","ethpillenable","proxy","delay","interval","benchmarkinterval","minimumminingintervals","disableextendinterval","switchingprevention","maxrejectedshareratio","enablefastswitching","disablemsiamonitor","disableapi","disableasyncloader","usetimesync","miningprioritycpu","miningprioritygpu","autoexecpriority","powerpricecurrency","powerprice","poweroffset","usepowerprice","checkprofitability","quickstart","startpaused","runmode","serverinit","serverinit2","servername","serverport","serveruser","serverpassword","donate")) > $null}
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
                                Write-Host "At first, please lookup your BTC wallet address. It is easy: copy it to your clipboard and then press the right mouse key in this window to paste" -ForegroundColor Cyan
                                Write-Host " "
                            }
                            $Config.Wallet = Read-HostString -Prompt "Enter your BTC wallet address" -Default $Config.Wallet -Length 34 -Mandatory -Characters "A-Z0-9" | Foreach-Object {if (@("cancel","exit","back","<") -icontains $_) {throw $_};$_}
                        }

                        "addcoins1" {
                            if ($IsInitialSetup) {
                                Write-Host " "
                                Write-Host "Now is your chance to add other currency wallets (e.g. enter XWP for Swap)" -ForegroundColor Cyan
                                Write-Host " "
                            }
                            $addcoins = Read-HostBool -Prompt "Do you want to add/edit $(if ($CoinsAdded.Count) {"another "})wallet addresses of non-BTC currencies?" -Default $false | Foreach-Object {if (@("cancel","exit","back","<") -icontains $_) {throw $_};$_}
                        }

                        "addcoins2" {
                            if ($addcoins) {
                                $CoinsActual = Get-Content $ConfigFiles["Coins"].Path | ConvertFrom-Json
                                $addcoin = Read-HostString -Prompt "Which currency do you want to add/edit (leave empty for none) " -Default "" -Valid (Get-PoolsInfo "Currency") | Foreach-Object {if (@("cancel","exit","back","<") -icontains $_) {throw $_};$_}
                                if (-not $CoinsActual.$addcoin) {
                                    $CoinsActual | Add-Member $addcoin ($CoinsDefault | ConvertTo-Json | ConvertFrom-Json) -Force
                                }
                            } else {
                                $GlobalSetupStepStore = $false
                            }
                        }

                        "addcoins3" {
                            if ($addcoins -and $addcoin) {
                                $CoinsActual.$addcoin.Wallet = Read-HostString -Prompt "Enter your $($addcoin) wallet address " -Default $CoinsActual.$addcoin.Wallet -Characters "A-Z0-9-\._~:/\?#\[\]@!\$&'\(\)\*\+,;=" | Foreach-Object {if (@("cancel","exit","back","<") -icontains $_) {throw $_};$_}
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
                                            
                            if ($Config.PoolName -isnot [array]) {
                                $Config.PoolName = if ($Config.PoolName -ne ''){[regex]::split($Config.PoolName.Trim(),"\s*[,;:]+\s*")}else{@()}
                            }
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

                            if ($Config.PoolName -isnot [array]) {
                                $Config.PoolName = if ($Config.PoolName -ne ''){[regex]::split($Config.PoolName.Trim(),"\s*[,;:]+\s*")}else{@()}
                            }
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
                        "enableminerstatus" {
                            if ($IsInitialSetup) {
                                Write-Host " "
                                Write-Host "RainbowMiner can track this and all of your rig's status at https://rbminer.net (or another compatible service) " -ForegroundColor Cyan
                                Write-Host "If you enable this feature, you may enter an existing miner status key or create a new one. " -ForegroundColor Cyan
                                Write-Host "It is possible to enter an email address or a https://pushover.net user key to be notified in case your rig is offline. " -ForegroundColor Cyan
                                Write-Host " "
                            }
                            $Config.EnableMinerStatus = Read-HostBool -Prompt "Do you want to enable central monitoring?" -Default $Config.EnableMinerStatus | Foreach-Object {if (@("cancel","exit","back","<") -icontains $_) {throw $_};$_}
                        }
                        "minerstatusurl" {
                            if (Get-Yes $Config.EnableMinerStatus) {
                                $Config.MinerStatusURL = Read-HostString -Prompt "Enter the miner monitoring url" -Default $Config.MinerStatusUrl -Characters "A-Z0-9-\._~:/\?#\[\]@!\$&'\(\)\*\+,;=" | Foreach-Object {if (@("cancel","exit","back","<") -icontains $_) {throw $_};$_}
                            } else {
                                $GlobalSetupStepStore = $false
                            }
                        }
                        "minerstatuskey" {
                            if (Get-Yes $Config.EnableMinerStatus) {
                                $Config.MinerStatusKey = Read-HostString -Prompt "Enter your miner monitoring status key (or enter `"new`" to create one)" -Default $Config.MinerStatusKey -Characters "nwA-F0-9\-" | Foreach-Object {if (@("cancel","exit","back","<") -icontains $_) {throw $_};$_}
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
                                $Config.MinerStatusEmail = Read-HostString -Prompt "Enter a offline notification eMail ($(if ($Config.MinerStatusEmail) {"clear"} else {"leave empty"}) to disable)" -Default $Config.MinerStatusEmail -Characters "A-Z0-9-\._~:/\?#\[\]@!\$&'\(\)\*\+,;=" | Foreach-Object {if (@("cancel","exit","back","<") -icontains $_) {throw $_};$_}
                            } else {
                                $GlobalSetupStepStore = $false
                            }
                        }
                        "pushoveruserkey" {
                            if (Get-Yes $Config.EnableMinerStatus) {
                                $Config.PushOverUserKey = Read-HostString -Prompt "Enter your https://pushover.net user key ($(if ($Config.PushOverUserKey) {"clear"} else {"leave empty"}) to disable)" -Default $Config.PushOverUserKey -Characters "A-Z0-9" -MinLength 30 -MaxLength 30 | Foreach-Object {if (@("cancel","exit","back","<") -icontains $_) {throw $_};$_}
                            } else {
                                $GlobalSetupStepStore = $false
                            }
                        }
                        "apiport" {
                            if ($IsInitialSetup) {
                                Write-Host " "
                                Write-Host "RainbowMiner can be monitored using your webbrowser via an API:" -Foreground Cyan
                                Write-Host "- on this machine: http://localhost:$($Config.APIPort)" -ForegroundColor Cyan
                                if ($IsWindows) {
                                    Write-Host "- on another windows device in the network: http://$($Session.MachineName):$($Config.APIPort)" -ForegroundColor Cyan
                                }
                                Write-Host "- on any other device in the network: http://$($Session.MyIP):$($Config.APIPort)" -ForegroundColor Cyan
                                Write-Host " "
                            }
                            $Config.APIport = Read-HostInt -Prompt "If needed, choose a different API port" -Default $Config.APIPort -Mandatory -Min 1000 -Max 9999 | Foreach-Object {if (@("cancel","exit","back","<") -icontains $_) {throw $_};$_}
                        }
                        "apiinit" {
                            if (-not (Test-APIServer -Port $Config.APIPort)) {
                                Write-Host " "
                                Write-Host "Warning: the API is currently visible locally on http://localhost:$($Config.APIport), only." -ForegroundColor Yellow
                                Write-Host " "
                                $InitAPIServer = Read-HostBool -Prompt "Do you want to enable the API in your network? " -Default $true | Foreach-Object {if (@("cancel","exit","back","<") -icontains $_) {throw $_};$_}
                                Write-Host " "
                                Write-Host "Ok, enable remote access to your API now.$(if (-not $Session.IsAdmin) {" Please click 'Yes' for all UACL prompts!"})"
                                Write-Host " " 
                                if ($InitAPIServer) {Initialize-APIServer -Port $Config.APIport}
                            } else {
                                $GlobalSetupStepStore = $false
                            }
                        }
                        "apiauth" {
                            $Config.APIauth = Read-HostBool -Prompt "Enable username/password to protect access to the API?" -Default $Config.APIAuth | Foreach-Object {if (@("cancel","exit","back","<") -icontains $_) {throw $_};$_}
                        }
                        "apiuser" {
                            if (Get-Yes $Config.APIauth) {
                                $Config.APIUser = Read-HostString -Prompt "Enter an API username ($(if ($Config.APIUser) {"clear"} else {"leave empty"}) to disable auth)" -Default $Config.APIUser -Characters "A-Z0-9" -MinLength 3 -MaxLength 30 | Foreach-Object {if (@("cancel","exit","back","<") -icontains $_) {throw $_};$_}
                            } else {
                                $GlobalSetupStepStore = $false
                            }
                        }
                        "apipassword" {
                            if (Get-Yes $Config.APIauth) {
                                $Config.APIPassword = Read-HostString -Prompt "Enter an API password ($(if ($Config.APIpassword) {"clear"} else {"leave empty"}) to disable auth)" -Default $Config.APIpassword -Characters "" -MinLength 3 -MaxLength 30 | Foreach-Object {if (@("cancel","exit","back","<") -icontains $_) {throw $_};$_}
                            } else {
                                $GlobalSetupStepStore = $false
                            }
                        }
                        "runmode" {
                            $Config.RunMode = Read-HostString -Prompt "Select the operation mode of this rig (standalone,server,client)" -Default $Config.RunMode -Valid @("standalone","server","client") | Foreach-Object {if (@("cancel","exit","back","<") -icontains $_) {throw $_};$_}
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
                                $InitAPIServer = Read-HostBool -Prompt "Do you want to add this rule to the firewall? " -Default $true | Foreach-Object {if (@("cancel","exit","back","<") -icontains $_) {throw $_};$_}
                                Write-Host " "
                                Write-Host "Ok, adding a rule to your firewall now.$(if (-not $Session.IsAdmin) {" Please click 'Yes' for all UACL prompts!"})"
                                Write-Host " " 
                                if ($InitAPIServer) {Initialize-APIServer -Port $Config.APIport}
                            } else {
                                $GlobalSetupStepStore = $false
                            }
                        }
                        "serverinit2" {
                            if ($Config.RunMode -eq "Server") {
                                $Config.StartPaused = Read-HostBool "Start the Server machine in pause/no-mining mode automatically? " -Default $Config.StartPaused | Foreach-Object {if (@("cancel","exit","back","<") -icontains $_) {throw $_};$_}
                            } elseif (Get-Yes $Config.StartPaused) {
                                $Config.StartPaused = -not (Read-HostBool -Prompt "RainbowMiner is currently configured to start in pause/no-mining mode. Do you want to disable that?" -Default $true)
                            } else {
                                $GlobalSetupStepStore = $false
                            }
                        }
                        "servername" {
                            if ($Config.RunMode -eq "client") {
                                $Config.ServerName = Read-HostString -Prompt "Enter the server's $(if ($IsWindows) {"name or "})IP-address ($(if ($Config.ServerName) {"clear"} else {"leave empty"}) for standalone operation)" -Default $Config.ServerName -Characters "A-Z0-9\-_\." | Foreach-Object {if (@("cancel","exit","back","<") -icontains $_) {throw $_};$_}
                            } else {
                                $GlobalSetupStepStore = $false
                            }
                        }
                        "serverport" {
                            if ($Config.RunMode -eq "client") {
                                $Config.ServerPort = Read-HostInt -Prompt "Enter the server's API port ($(if ($Config.ServerPort) {"clear"} else {"leave empty"}) for standalone operation)" -Default $Config.ServerPort -Min 0 -Max 9999 | Foreach-Object {if (@("cancel","exit","back","<") -icontains $_) {throw $_};$_}
                            } else {
                                $GlobalSetupStepStore = $false
                            }
                        }
                        "serveruser" {
                            if ($Config.RunMode -eq "client") {
                                $Config.ServerUser = Read-HostString -Prompt "If you have auth enabled on your server's API, enter the username ($(if ($Config.ServerUser) {"clear"} else {"leave empty"}) for no auth)" -Default $Config.ServerUser -Characters "A-Z0-9" | Foreach-Object {if (@("cancel","exit","back","<") -icontains $_) {throw $_};$_}
                            } else {
                                $GlobalSetupStepStore = $false
                            }
                        }
                        "serverpassword" {
                            if ($Config.RunMode -eq "client") {
                                $Config.ServerPassword = Read-HostString -Prompt "If you have auth enabled on your server's API, enter the password ($(if ($Config.ServerPassword) {"clear"} else {"leave empty"}) for no auth)" -Default $Config.ServerPassword -Characters "" | Foreach-Object {if (@("cancel","exit","back","<") -icontains $_) {throw $_};$_}
                            } else {
                                $GlobalSetupStepStore = $false
                            }
                        }
                        "enableautominerports" {
                            if (-not $IsInitialSetup) {
                                $Config.EnableAutoMinerPorts = Read-HostBool -Prompt "Enable automatic port switching, if miners try to run on used ports" -Default $Config.EnableAutoMinerPorts | Foreach-Object {if (@("cancel","exit","back","<") -icontains $_) {throw $_};$_}
                            } else {
                                $GlobalSetupStepStore = $false
                            }
                        }
                        "currency" {
                            $Config.Currency = Read-HostArray -Prompt "Enter all currencies to be displayed (e.g. EUR,USD,BTC)" -Default $Config.Currency -Mandatory -Characters "A-Z" | Foreach-Object {if (@("cancel","exit","back","<") -icontains $_) {throw $_};$_}
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
                                $BenchmarkAccuracy = Read-HostString -Prompt "Please select the benchmark accuracy (enter quick,normal or precise)" -Default $(if ($Config.BenchmarkInterval -le 60){"quick"} elseif ($Config.BenchmarkInterval -le 90) {"normal"} else {"precise"}) -Valid @("quick","normal","precise") -Mandatory -Characters "A-Z" | Foreach-Object {if (@("cancel","exit","back","<") -icontains $_) {throw $_};$_}
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

                            $Config.PoolName = Read-HostArray -Prompt "Enter the pools you want to mine" -Default $Config.PoolName -Mandatory -Characters "A-Z0-9" -Valid $Session.AvailPools | Foreach-Object {if (@("cancel","exit","back","<") -icontains $_) {throw $_};$_}
                        }
                        "autoaddcoins" {
                            if ($IsInitialSetup -and $CoinsWithWallets.Count) {
                                $AutoAddCoins = Read-HostBool -Prompt "Automatically add wallets for $($CoinsWithWallets -join ", ") to pools?" -Default $AutoAddCoins | Foreach-Object {if (@("cancel","exit","back","<") -icontains $_) {throw $_};$_}
                            } else {
                                $GlobalSetupStepStore = $false
                            }
                        }
                        "excludepoolname" {
                            $Config.ExcludePoolName = Read-HostArray -Prompt "Enter the pools you do want to exclude from mining" -Default $Config.ExcludePoolName -Characters "A-Z0-9" -Valid $Session.AvailPools | Foreach-Object {if (@("cancel","exit","back","<") -icontains $_) {throw $_};$_}
                        }
                        "minername" {
                            if ($IsInitialSetup) {
                                Write-Host " "
                                Write-Host "You are almost done :) Our defaults for miners and algorithms give you a good start. If you want, you can skip the settings for now " -ForegroundColor Cyan
                                Write-Host " "
                                $Skip = Read-HostBool -Prompt "Do you want to skip the miner and algorithm setup?" -Default $true | Foreach-Object {if (@("cancel","exit","back","<") -icontains $_) {throw $_};$_}
                                if ($Skip) {throw "Goto devicenamebegin"}
                            }
                            $Config.MinerName = Read-HostArray -Prompt "Enter the miners your want to use ($(if ($Config.MinerName) {"clear"} else {"leave empty"}) for all)" -Default $Config.MinerName -Characters "A-Z0-9.-_" -Valid $Session.AvailMiners | Foreach-Object {if (@("cancel","exit","back","<") -icontains $_) {throw $_};$_}
                        }
                        "excludeminername" {
                            $Config.ExcludeMinerName = Read-HostArray -Prompt "Enter the miners you do want to exclude" -Default $Config.ExcludeMinerName -Characters "A-Z0-9\.-_" -Valid $Session.AvailMiners | Foreach-Object {if (@("cancel","exit","back","<") -icontains $_) {throw $_};$_}
                        }
                        "algorithm" {
                            $Config.Algorithm = Read-HostArray -Prompt "Enter the algorithm you want to mine ($(if ($Config.Algorithm) {"clear"} else {"leave empty"}) for all)" -Default $Config.Algorithm -Characters "A-Z0-9" -Valid (Get-Algorithms) | Foreach-Object {if (@("cancel","exit","back","<") -icontains $_) {throw $_};$_}
                        }
                        "excludealgorithm" {
                            $Config.ExcludeAlgorithm = Read-HostArray -Prompt "Enter the algorithm you do want to exclude " -Default $Config.ExcludeAlgorithm -Characters "A-Z0-9" -Valid (Get-Algorithms) | Foreach-Object {if (@("cancel","exit","back","<") -icontains $_) {throw $_};$_}
                        }
                        "excludecoinsymbol" {
                            $Config.ExcludeCoinSymbol = Read-HostArray -Prompt "Enter the name of coins by currency symbol, you want to globaly exclude " -Default $Config.ExcludeCoinSymbol -Characters "\`$A-Z0-9" | Foreach-Object {if (@("cancel","exit","back","<") -icontains $_) {throw $_};$_}
                        }
                        "excludecoin" {
                            $Config.ExcludeCoin = Read-HostArray -Prompt "Enter the name of coins by name, you want to globaly exclude " -Default $Config.ExcludeCoin -Characters "`$A-Z0-9. " | Foreach-Object {if (@("cancel","exit","back","<") -icontains $_) {throw $_};$_}
                        }
                        "disabledualmining" {
                            $Config.DisableDualMining = Read-HostBool -Prompt "Disable all dual mining algorithm" -Default $Config.DisableDualMining | Foreach-Object {if (@("cancel","exit","back","<") -icontains $_) {throw $_};$_}
                        }
                        "excludeminerswithfee" {
                            $Config.ExcludeMinersWithFee = Read-HostBool -Prompt "Exclude all miners with developer fee" -Default $Config.ExcludeMinersWithFee | Foreach-Object {if (@("cancel","exit","back","<") -icontains $_) {throw $_};$_}
                        }
                        "enablecheckminingconflict" {
                            $Config.EnableCheckMiningConflict = Read-HostBool -Prompt "Enable conflict check if running CPU hungry GPU miners (for weak CPUs)" -Default $Config.EnableCheckMiningConflict | Foreach-Object {if (@("cancel","exit","back","<") -icontains $_) {throw $_};$_}
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
                            $Config.DeviceName = Read-HostArray -Prompt "Enter the devices you want to use for mining " -Default $Config.DeviceName -Characters "A-Z0-9#" -Valid @($SetupDevices | Foreach-Object {$_.Type.ToUpper();if ($Config.MiningMode -eq "legacy") {if (@("nvidia","amd") -icontains $_.Vendor) {$_.Vendor}} else {if (@("nvidia","amd") -icontains $_.Vendor) {$_.Vendor;$_.Model};$_.Name}} | Select-Object -Unique | Sort-Object) | Foreach-Object {if (@("cancel","exit","back","<") -icontains $_) {throw $_};$_}
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
                                if (Read-HostBool -Prompt "Mine on your $($SetupDevices | Where-Object {$_.Type -eq "gpu" -and $_.Vendor -eq $AvailDeviceGPUVendors[0]} | Select -ExpandProperty Model_Name -Unique)" -Default $true | Foreach-Object {if (@("cancel","exit","back","<") -icontains $_) {throw $_};$_}) {
                                    $NewDeviceName[$AvailDeviceGPUVendors[0]] = $AvailDeviceGPUVendors[0]
                                }
                                throw "Goto devicenamewizardcpu1"
                            }
                            if (Read-HostBool -Prompt "Mine on all available GPU ($($AvailDeviceGPUVendors -join ' and '), choose no to select devices)" -Default $true | Foreach-Object {if (@("cancel","exit","back","<") -icontains $_) {throw $_};$_}) {
                                foreach ($p in $AvailDeviceGPUVendors) {$NewDeviceName[$p] = @($p)}
                                throw "Goto devicenamewizardcpu1"
                            }
                        }
                        "devicenamewizardamd1" {
                            $NewDeviceName["AMD"] = @()
                            if ($AvailDeviceCounts["AMD"] -gt 0) {
                                if (Read-HostBool -Prompt "Do you want to mine on $(if ($AvailDeviceCounts["AMD"] -gt 1) {"all AMD GPUs"}else{"your AMD GPU"})" -Default $true | Foreach-Object {if (@("cancel","exit","back","<") -icontains $_) {throw $_};$_}) {
                                    $NewDeviceName["AMD"] = @("AMD")
                                }
                            } else {
                                $GlobalSetupStepStore = $false
                            }
                        }
                        "devicenamewizardamd2" {
                            if ($AvailDeviceCounts["AMD"] -gt 1 -and $NewDeviceName["AMD"].Count -eq 0) {
                                $NewDeviceName["AMD"] = Read-HostArray -Prompt "Enter the AMD devices you want to use for mining " -Characters "A-Z0-9#" -Valid @($SetupDevices | Where-Object {$_.Vendor -eq "AMD" -and $_.Type -eq "GPU"} | Foreach-Object {$_.Vendor;$_.Model;$_.Name} | Select-Object -Unique | Sort-Object) | Foreach-Object {if (@("cancel","exit","back","<") -icontains $_) {throw $_};$_}
                            } else {
                                $GlobalSetupStepStore = $false
                            }
                        }
                        "devicenamewizardnvidia1" {
                            $NewDeviceName["NVIDIA"] = @()
                            if ($AvailDeviceCounts["NVIDIA"] -gt 0) {
                                if (Read-HostBool -Prompt "Do you want to mine on $(if ($AvailDeviceCounts["NVIDIA"] -gt 1) {"all NVIDIA GPUs"}else{"your NVIDIA GPU"})" -Default $true | Foreach-Object {if (@("cancel","exit","back","<") -icontains $_) {throw $_};$_}) {
                                    $NewDeviceName["NVIDIA"] = @("NVIDIA")
                                }
                            } else {
                                $GlobalSetupStepStore = $false
                            }
                        }
                        "devicenamewizardnvidia2" {
                            if ($AvailDeviceCounts["NVIDIA"] -gt 1 -and $NewDeviceName["NVIDIA"].Count -eq 0) {
                                $NewDeviceName["NVIDIA"] = Read-HostArray -Prompt "Enter the NVIDIA devices you want to use for mining " -Characters "A-Z0-9#" -Valid @($SetupDevices | Where-Object {$_.Vendor -eq "NVIDIA" -and $_.Type -eq "GPU"} | Foreach-Object {$_.Vendor;$_.Model;$_.Name} | Select-Object -Unique | Sort-Object) | Foreach-Object {if (@("cancel","exit","back","<") -icontains $_) {throw $_};$_}
                            } else {
                                $GlobalSetupStepStore = $false
                            }
                        }
                        "devicenamewizardcpu1" {
                            $NewDeviceName["CPU"] = @()
                            if (Read-HostBool -Prompt "Do you want to mine on your CPU$(if ($AvailDeviceCounts["cpu"] -gt 1){"s"})" -Default $false | Foreach-Object {if (@("cancel","exit","back","<") -icontains $_) {throw $_};$_}) {
                                $NewDeviceName["CPU"] = @("CPU")
                            }
                        }
                        "devicenamewizardend" {
                            $GlobalSetupStepStore = $false
                            $Config.DeviceName = @($NewDeviceName.Values | Where-Object {$_} | Foreach-Object {$_} | Select-Object -Unique | Sort-Object)
                            if ($Config.DeviceName.Count -eq 0) {
                                Write-Host " "
                                if (Read-HostBool -Prompt "No devices selected. Do you want to restart the device setup?" -Default $true | Foreach-Object {if (@("cancel","exit","back","<") -icontains $_) {throw $_};$_}) {
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
                                $Config.CPUMiningThreads = Read-HostInt -Prompt "How many softwarethreads should be used for CPU mining? (0 or $(if ($Config.CPUMiningThreads) {"clear"} else {"leave empty"}) for auto)" -Default $Config.CPUMiningThreads -Min 0 | Foreach-Object {if (@("cancel","exit","back","<") -icontains $_) {throw $_};$_}
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
                                $NewAffinity = Read-HostArray -Prompt "Choose CPU threads (list of integer, $(if ($CurrentAffinity) {"clear"} else {"leave empty"}) for no assignment)" -Default $CurrentAffinity -Valid ([string[]]@(0..($Global:GlobalCPUInfo.Threads-1))) -Characters "0-9" | Foreach-Object {if (@("cancel","exit","back","<") -icontains $_) {throw $_};$_}
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
                            $NewAffinity = Read-HostArray -Prompt "Choose CPU threads (list of integer, $(if ($CurrentAffinity) {"clear"} else {"leave empty"}) for no assignment)" -Default $CurrentAffinity -Valid ([string[]]@(0..($Global:GlobalCPUInfo.Threads-1))) -Characters "0-9" | Foreach-Object {if (@("cancel","exit","back","<") -icontains $_) {throw $_};$_}
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

                            $Config.PoolDataWindow = Read-HostString -Prompt "Enter which default datawindow is to be used ($(if ($Config.PoolDataWindow) {"clear"} else {"leave empty"}) for automatic)" -Default $Config.PoolDataWindow -Characters "A-Z0-9_\-" | Foreach-Object {if (@("cancel","exit") -icontains $_) {throw $_};$_}
                        }
                        "poolstataverage" {
                            Write-Host " "
                            Write-Host "Choose the default pool moving average price trendline" -ForegroundColor Green

                            Write-HostSetupStatAverageHints

                            $Config.PoolStatAverage = Read-HostString -Prompt "Enter which default moving average is to be used ($(if ($Config.PoolStatAverage) {"clear"} else {"leave empty"}) for default)" -Default $Config.PoolStatAverage -Valid @("Live","Minute_5","Minute_10","Hour","Day","ThreeDay","Week") -Characters "A-Z0-9_" | Foreach-Object {if (@("cancel","exit") -icontains $_) {throw $_};$_}
                        }
                        "hashrateweight" {
                            Write-Host " "
                            Write-Host "Adjust hashrate weight"
                            Write-Host "Formula: price * (1-(hashrate weight/100)*(1-(rel. hashrate)^(hashrate weight strength/100))" -ForegroundColor Yellow
                            $Config.HashrateWeight = Read-HostInt -Prompt "Adjust weight of pool hashrates on the profit comparison in % (0..100, 0=disable)" -Default $Config.HashrateWeight -Min 0 -Max 100 | Foreach-Object {if (@("cancel","exit","back","<") -icontains $_) {throw $_};$_}
                        }
                        "hashrateweightstrength" {
                            $Config.HashrateWeightStrength = Read-HostInt -Prompt "Adjust the strength of the weight (integer, 0=no weight, 100=linear, 200=square)" -Default $Config.HashrateWeightStrength -Min 0 | Foreach-Object {if (@("cancel","exit","back","<") -icontains $_) {throw $_};$_}
                        }
                        "poolaccuracyweight" {
                            $Config.PoolAccuracyWeight = Read-HostInt -Prompt "Adjust weight of pools accuracy on the profit comparison in % (0..100, 0=disable)" -Default $Config.PoolAccuracyWeight -Min 0 -Max 100 | Foreach-Object {if (@("cancel","exit","back","<") -icontains $_) {throw $_};$_}
                        }
                        "defaultpoolregion" {
                            $Config.DefaultPoolRegion = Read-HostArray -Prompt "Enter the default region order, if pool does not offer a stratum in your region" -Default $Config.DefaultPoolRegion -Mandatory -Characters "A-Z" -Valid @(Get-Regions) | Foreach-Object {if (@("cancel","exit","back","<") -icontains $_) {throw $_};$_}
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
                        "showpoolbalancesdetails" {
                            if ($Config.ShowPoolBalances) {
                                $Config.ShowPoolBalancesDetails = Read-HostBool -Prompt "Show all at a pool mined coins as one extra row" -Default $Config.ShowPoolBalancesDetails | Foreach-Object {if (@("cancel","exit","back","<") -icontains $_) {throw $_};$_}
                            } else {
                                $GlobalSetupStepStore = $false
                            }
                        }
                        "showpoolbalancesexcludedpools" {
                            if ($Config.ShowPoolBalances -and $Config.ExcludePoolName) {
                                $Config.ShowPoolBalancesExcludedPools = Read-HostBool -Prompt "Show balances from excluded pools, too" -Default $Config.ShowPoolBalancesExcludedPools | Foreach-Object {if (@("cancel","exit","back","<") -icontains $_) {throw $_};$_}
                            } else {
                                $GlobalSetupStepStore = $false
                            }
                        }
                        "showminerwindow" {
                            $Config.ShowMinerWindow = Read-HostBool -Prompt "Show miner in own windows" -Default $Config.ShowMinerWindow | Foreach-Object {if (@("cancel","exit","back","<") -icontains $_) {throw $_};$_}
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
                        "nvsmipath" {
                            $GlobalSetupStepStore = $false
                            if ($Config.EnableOCProfiles -and ($Session.AllDevices | where-object vendor -eq "nvidia" | measure-object).count -gt 0) {
                                $Config.NVSMIpath = Read-HostString -Prompt "Enter path to Nvidia NVSMI" -Default $Config.NVSMIpath -Characters '' | Foreach-Object {if (@("cancel","exit","back","<") -icontains $_) {throw $_};$_}
                                if (-not (Test-Path $Config.NVSMIpath)) {Write-Host "Nvidia NVSMI not found at given path. RainbowMiner will use included nvsmi" -ForegroundColor Yellow}
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
                        "enableocvoltage" {
                            if ($Config.EnableOCProfiles) {
                                $Config.EnableOCVoltage = Read-HostBool -Prompt "Enable custom overclocking voltage setting" -Default $Config.EnableOCVoltage | Foreach-Object {if (@("cancel","exit","back","<") -icontains $_) {throw $_};$_}
                            } else {
                                $GlobalSetupStepStore = $false
                            }
                        }
                        "enableautoupdate" {
                            $Config.EnableAutoUpdate = Read-HostBool -Prompt "Enable automatic update, as soon as a new release is published" -Default $Config.EnableAutoUpdate | Foreach-Object {if (@("cancel","exit","back","<") -icontains $_) {throw $_};$_}
                        }
                        "enableautoalgorithmadd" {
                            $Config.EnableAutoAlgorithmAdd = Read-HostBool -Prompt "Automatically add new algorithms to config.txt during update" -Default $Config.EnableAutoAlgorithmAdd | Foreach-Object {if (@("cancel","exit","back","<") -icontains $_) {throw $_};$_}
                        }
                        "enableautobenchmark" {
                            $Config.EnableAutoBenchmark = Read-HostBool -Prompt "Automatically start benchmarks of updated miners" -Default $Config.EnableAutoBenchmark | Foreach-Object {if (@("cancel","exit","back","<") -icontains $_) {throw $_};$_}
                        }
                        "enableresetvega" {
                            if ($SetupDevices | Where-Object {$_.Vendor -eq "AMD" -and $_.Model -match "Vega"}) {
                                $Config.EnableResetVega = Read-HostBool -Prompt "Reset VEGA devices before miner (re-)start (needs admin privileges)" -Default $Config.EnableResetVega | Foreach-Object {if (@("cancel","exit","back","<") -icontains $_) {throw $_};$_}
                            } else {
                                $GlobalSetupStepStore = $false
                            }
                        }
                        "proxy" {
                            $Config.Proxy = Read-HostString -Prompt "Enter proxy address, if used" -Default $Config.Proxy -Characters "A-Z0-9-\._~:/\?#\[\]@!\$&'\(\)\*\+,;=" | Foreach-Object {if (@("cancel","exit","back","<") -icontains $_) {throw $_};$_}
                        }
                        "interval" {
                            $Config.Interval = Read-HostInt -Prompt "Enter the script's loop interval in seconds" -Default $Config.Interval -Mandatory -Min 30 | Foreach-Object {if (@("cancel","exit","back","<") -icontains $_) {throw $_};$_}
                        }
                        "benchmarkinterval" {
                            $Config.BenchmarkInterval = Read-HostInt -Prompt "Enter the script's loop interval in seconds, used for benchmarks" -Default $Config.BenchmarkInterval -Mandatory -Min 60 | Foreach-Object {if (@("cancel","exit","back","<") -icontains $_) {throw $_};$_}
                        }
                        "minimumminingintervals" {
                            $Config.MinimumMiningIntervals = Read-HostInt -Prompt "Minimum mining intervals, before the regular loop starts" -Default $Config.MinimumMiningIntervals -Mandatory -Min 1 | Foreach-Object {if (@("cancel","exit","back","<") -icontains $_) {throw $_};$_}
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
                        "maxrejectedshareratio" {
                            Write-Host " "
                            Write-Host "Adjust the maximum failure rate"
                            Write-Host "Miner will be disabled, if their % of rejected shares grows larger than this number" -ForegroundColor Yellow                            
                         
                            $Config.MaxRejectedShareRatio = Read-HostDouble -Prompt "Maximum rejected share rate in %" -Default ($Config.MaxRejectedShareRatio*100) -Min 0 -Max 100 | Foreach-Object {if (@("cancel","exit","back","<") -icontains $_) {throw $_};$_}
                            $Config.MaxRejectedShareRatio = $Config.MaxRejectedShareRatio / 100
                        }
                        "enablefastswitching" {
                            $Config.EnableFastSwitching = Read-HostBool -Prompt "Enable fast switching mode (expect frequent miner changes, not recommended)" -Default $Config.EnableFastSwitching | Foreach-Object {if (@("cancel","exit","back","<") -icontains $_) {throw $_};$_}
                        }
                        "usetimesync" {
                            $Config.UseTimeSync = Read-HostBool -Prompt "Enable automatic time/NTP synchronization (needs admin rights)" -Default $Config.UseTimeSync | Foreach-Object {if (@("cancel","exit","back","<") -icontains $_) {throw $_};$_}
                        }
                        "miningprioritycpu" {
                            $Config.MiningPriorityCPU = Read-HostInt -Prompt "Adjust CPU mining process priority (-2..3)" -Default $Config.MiningPriorityCPU -Min -2 -Max 3 | Foreach-Object {if (@("cancel","exit","back","<") -icontains $_) {throw $_};$_}
                        }
                        "miningprioritygpu" {
                            $Config.MiningPriorityGPU = Read-HostInt -Prompt "Adjust GPU mining process priority (-2..3)" -Default $Config.MiningPriorityGPU -Min -2 -Max 3 | Foreach-Object {if (@("cancel","exit","back","<") -icontains $_) {throw $_};$_}
                        }
                        "autoexecpriority" {
                            $Config.AutoexecPriority = Read-HostInt -Prompt "Adjust autoexec command's process priority (-2..3)" -Default $Config.AutoexecPriority -Min -2 -Max 3 | Foreach-Object {if (@("cancel","exit","back","<") -icontains $_) {throw $_};$_}
                        }
                        "disablemsiamonitor" {
                            $Config.DisableMSIAmonitor = Read-HostBool -Prompt "Disable MSI Afterburner monitor/control" -Default $Config.DisableMSIAmonitor | Foreach-Object {if (@("cancel","exit","back","<") -icontains $_) {throw $_};$_}
                        }
                        "disableapi" {
                            $Config.DisableAPI = Read-HostBool -Prompt "Disable localhost API" -Default $Config.DisableAPI | Foreach-Object {if (@("cancel","exit","back","<") -icontains $_) {throw $_};$_}
                        }
                        "disableasyncloader" {
                            $Config.DisableAsyncLoader = Read-HostBool -Prompt "Disable asynchronous loader" -Default $Config.DisableAsyncLoader | Foreach-Object {if (@("cancel","exit","back","<") -icontains $_) {throw $_};$_}
                        }
                        "powerpricecurrency" {
                            $Config.PowerPriceCurrency = Read-HostString -Prompt "Enter currency of power price (e.g. USD,EUR,CYN)" -Default $Config.PowerPriceCurrency -Characters "A-Z" | Foreach-Object {if (@("cancel","exit","back","<") -icontains $_) {throw $_};$_}
                        }
                        "powerprice" {
                            $Config.PowerPrice = Read-HostDouble -Prompt "Enter the power price per kW/h (kilowatt per hour), you pay to your electricity supplier" -Default $Config.PowerPrice | Foreach-Object {if (@("cancel","exit","back","<") -icontains $_) {throw $_};$_}
                        }
                        "poweroffset" {
                            $Config.PowerOffset = Read-HostDouble -Prompt "Optional: enter your rig's base power consumption (will be added during mining) " -Default $Config.PowerOffset | Foreach-Object {if (@("cancel","exit","back","<") -icontains $_) {throw $_};$_}
                        }
                        "usepowerprice" {
                            $Config.UsePowerPrice = Read-HostBool -Prompt "Include cost of electricity into profit calculations" -Default $Config.UsePowerPrice | Foreach-Object {if (@("cancel","exit","back","<") -icontains $_) {throw $_};$_}
                        }
                        "checkprofitability" {
                            $Config.CheckProfitability = Read-HostBool -Prompt "Check for profitability and stop mining, if no longer profitable." -Default $Config.CheckProfitability | Foreach-Object {if (@("cancel","exit","back","<") -icontains $_) {throw $_};$_}
                        }
                        "quickstart" {
                            $Config.Quickstart = Read-HostBool -Prompt "Read all pool data from cache, instead of live upon start of RainbowMiner (useful with many coins in setup)" -Default $Config.Quickstart | Foreach-Object {if (@("cancel","exit","back","<") -icontains $_) {throw $_};$_}
                        }
                        "startpaused" {
                            $Config.StartPaused = Read-HostBool -Prompt "Start RainbowMiner in pause mode (you will have to press P to start mining)" -Default $Config.StartPaused | Foreach-Object {if (@("cancel","exit","back","<") -icontains $_) {throw $_};$_}
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
                            $ConfigActual | Add-Member ShowPoolBalancesDetails $(if (Get-Yes $Config.ShowPoolBalancesDetails){"1"}else{"0"}) -Force
                            $ConfigActual | Add-Member ShowPoolBalancesExcludedPools $(if (Get-Yes $Config.ShowPoolBalancesExcludedPools){"1"}else{"0"}) -Force
                            $ConfigActual | Add-Member ShowMinerWindow $(if (Get-Yes $Config.ShowMinerWindow){"1"}else{"0"}) -Force
                            $ConfigActual | Add-Member FastestMinerOnly $(if (Get-Yes $Config.FastestMinerOnly){"1"}else{"0"}) -Force
                            $ConfigActual | Add-Member UIstyle $Config.UIstyle -Force
                            $ConfigActual | Add-Member DeviceName $($Config.DeviceName -join ",") -Force                      
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

                            if (Get-Member -InputObject $PoolsActual -Name NiceHash) {
                                $PoolsActual.NiceHash | Add-Member BTC $(if($NicehashWallet -eq $Config.Wallet -or $NicehashWallet -eq ''){"`$Wallet"}else{$NicehashWallet}) -Force
                                $PoolsActual.NiceHash | Add-Member Worker $(if($NicehashWorkerName -eq $Config.WorkerName -or $NicehashWorkerName -eq ''){"`$WorkerName"}else{$NicehashWorkerName}) -Force
                            } else {
                                $PoolsActual | Add-Member NiceHash ([PSCustomObject]@{
                                        BTC = if($NicehashWallet -eq $Config.Wallet -or $NicehashWallet -eq ''){"`$Wallet"}else{$NicehashWallet}
                                        Worker = if($NicehashWorkerName -eq $Config.WorkerName -or $NicehashWorkerName -eq ''){"`$WorkerName"}else{$NicehashWorkerName}
                                        Penalty = 0
                                        AllowZero = "0"
                                }) -Force
                                foreach($q in @("Algorithm","ExcludeAlgorithm","CoinName","ExcludeCoin","CoinSymbol","ExcludeCoinSymbol","FocusWallet")) {$PoolsActual.NiceHash | Add-Member $q "" -Force}
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

                            $ConfigActual | ConvertTo-Json | Out-File $ConfigFiles["Config"].Path -Encoding utf8                                             
                            $PoolsActual | ConvertTo-Json | Out-File $ConfigFiles["Pools"].Path -Encoding utf8

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
                    if ($Error.Count){$Error.RemoveAt(0)}
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
                        Read-Hostkey "Any key to continue">$null
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
                                $Miner_Name = Read-HostString -Prompt "Which miner do you want to configure? (leave empty to end miner config)" -Characters "A-Z0-9.-_" -Valid $Session.AvailMiners | Foreach-Object {if (@("cancel","exit","back","<") -icontains $_) {throw $_};$_}
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
                                            $EditDeviceName_Array = @($SetupDevices | Where-Object {$_.Vendor -eq $EditDevice0 -and $_.Type -eq "gpu" -or $_.Type -eq $EditDevice0} | Select-Object -ExpandProperty Model -Unique | Sort-Object)
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
                                    Difficulty = ""
                                    Disable = "0"
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
                                    $EditMinerConfig.OCprofile = Read-HostString -Prompt "Custom overclocking profile ($(if ($EditMinerConfig.OCprofile) {"clear"} else {"leave empty"}) for none)" -Default $EditMinerConfig.OCprofile -Valid @($ProfilesActual.PSObject.Properties.Name) | Foreach-Object {if (@("cancel","exit","back","<") -icontains $_) {throw $_};$_}
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
                            "difficulty" {
                                $EditMinerConfig.Difficulty = Read-HostDouble -Prompt "Set static difficulty ($(if ($EditMinerConfig.Difficulty) {"clear"} else {"leave empty"}) or set to 0 for automatic)" -Default $EditMinerConfig.Difficulty | Foreach-Object {if (@("cancel","exit","back","<") -icontains $_) {throw $_};$_}
                                $EditMinerConfig.Difficulty = $EditMinerConfig.Difficulty -replace ",","." -replace "[^\d\.]+"
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
                            "disable" {
                                $MinerSetupStepStore = $false
                                if ($EditAlgorithm -ne '*') {
                                    $EditMinerConfig.Disable = Read-HostBool -Prompt "Disable $EditAlgorithm$(if ($EditSecondaryAlgorithm) {"-$EditSecondaryAlgorithm"}) on $EditMinerName" -Default $EditMinerConfig.Disable | Foreach-Object {if (@("cancel","exit","back","<") -icontains $_) {throw $_};$_}
                                    $MinerSetupStepStore = $true
                                }
                                $EditMinerConfig.Disable = if (Get-Yes $EditMinerConfig.Disable) {"1"} else {"0"}
                            }
                            "save" {
                                Write-Host " "
                                if (-not (Read-HostBool "Really write entered values to $($ConfigFiles["Miners"].Path)?" | Foreach-Object {if (@("cancel","exit","back","<") -icontains $_) {throw $_};$_})) {throw "cancel"}
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

            Set-PoolsConfigDefault -PathToFile $ConfigFiles["Pools"].Path -Force

            $PoolDefault = [PSCustomObject]@{Worker = "`$WorkerName";Penalty = 0;Algorithm = "";ExcludeAlgorithm = "";CoinName = "";ExcludeCoin = "";CoinSymbol = "";ExcludeCoinSymbol = "";MinerName = "";ExcludeMinerName = "";FocusWallet = "";AllowZero = "0";EnableAutoCoin = "0";EnablePostBlockMining = "0";CoinSymbolPBM = "";StatAverage = "";DataWindow = ""}

            $PoolSetupDone = $false
            do {
                try {
                    $PoolsActual = Get-Content $ConfigFiles["Pools"].Path | ConvertFrom-Json
                    $CoinsActual = Get-Content $ConfigFiles["Coins"].Path | ConvertFrom-Json
                    $Pool_Name = Read-HostString -Prompt "Which pool do you want to configure? (leave empty to end pool config)" -Characters "A-Z0-9" -Valid $Session.AvailPools | Foreach-Object {if (@("cancel","exit","back","<") -icontains $_) {throw $_};$_}
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
                        foreach($SetupName in $PoolDefault.PSObject.Properties.Name) {if ($PoolConfig.$SetupName -eq $null){$PoolConfig | Add-Member $SetupName $PoolDefault.$SetupName -Force}}

                        if ($IsYiimpPool -and $PoolConfig.PSObject.Properties.Name -inotcontains "DataWindow") {$PoolConfig | Add-Member DataWindow "" -Force}  
                                        
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
                                        Write-Host "*** Edit pool's algorithms, coins and miners ***" -ForegroundColor Green
                                        Write-Host " "
                                    }
                                    "worker" {
                                        $PoolConfig.Worker = Read-HostString -Prompt "Enter the worker name ($(if ($PoolConfig.Worker) {"clear"} else {"leave empty"}) to use config.txt default)" -Default ($PoolConfig.Worker -replace "^\`$.+") -Characters "A-Z0-9" | Foreach-Object {if (@("cancel","exit","back","<") -icontains $_) {throw $_};$_} 
                                        if ($PoolConfig.Worker.Trim() -eq '') {$PoolConfig.Worker = "`$WorkerName"}
                                    }
                                    "user" {
                                        $PoolConfig.User = Read-HostString -Prompt $PoolsSetup.$Pool_Name.SetupFields.User -Default ($PoolConfig.User -replace "^\`$.+") -Characters "A-Z0-9" | Foreach-Object {if (@("cancel","exit","back","<") -icontains $_) {throw $_};$_} 
                                        if ($PoolConfig.User.Trim() -eq '') {$PoolConfig.User = $PoolsSetup.$Pool_Name.Fields.User}
                                    }
                                    "aecurrency" {
                                        $PoolConfig.AECurrency = Read-HostString -Prompt $PoolsSetup.$Pool_Name.SetupFields.AECurrency -Default $PoolConfig.AECurrency -Characters "A-Z0-9" | Foreach-Object {if (@("cancel","exit","back","<") -icontains $_) {throw $_};$_} 
                                        if ($PoolConfig.User.Trim() -eq '') {$PoolConfig.AECurrency = $PoolsSetup.$Pool_Name.Fields.AECurrency}
                                    }
                                    "apiid" {
                                        $PoolConfig.API_ID = Read-HostString -Prompt $PoolsSetup.$Pool_Name.SetupFields.API_ID -Default ($PoolConfig.API_ID -replace "^\`$.+") -Characters "A-Z0-9" | Foreach-Object {if (@("cancel","exit","back","<") -icontains $_) {throw $_};$_} 
                                        if ($PoolConfig.API_ID.Trim() -eq '') {$PoolConfig.API_ID = $PoolsSetup.$Pool_Name.Fields.API_ID}
                                    }
                                    "apikey" {
                                        $PoolConfig.API_Key = Read-HostString -Prompt $PoolsSetup.$Pool_Name.SetupFields.API_Key -Default ($PoolConfig.API_Key -replace "^\`$.+") -Characters "A-Z0-9" | Foreach-Object {if (@("cancel","exit","back","<") -icontains $_) {throw $_};$_} 
                                        if ($PoolConfig.API_Key.Trim() -eq '') {$PoolConfig.API_Key = $PoolsSetup.$Pool_Name.Fields.API_Key}
                                    }
                                    "apisecret" {
                                        $PoolConfig.API_Secret = Read-HostString -Prompt $PoolsSetup.$Pool_Name.SetupFields.API_Secret -Default ($PoolConfig.API_Secret -replace "^\`$.+") -Characters "A-Z0-9" | Foreach-Object {if (@("cancel","exit","back","<") -icontains $_) {throw $_};$_} 
                                        if ($PoolConfig.API_Secret.Trim() -eq '') {$PoolConfig.API_Secret = $PoolsSetup.$Pool_Name.Fields.API_Secret}
                                    }
                                    "enablemining" {
                                        $PoolConfig.EnableMining = Read-HostBool -Prompt $PoolsSetup.$Pool_Name.SetupFields.EnableMining -Default $PoolConfig.EnableMining | Foreach-Object {if (@("cancel","exit","back","<") -icontains $_) {throw $_};$_}
                                    }
                                    "algorithm" {
                                        $PoolConfig.Algorithm = Read-HostArray -Prompt "Enter algorithms you want to mine ($(if ($PoolConfig.Algorithm) {"clear"} else {"leave empty"}) for all)" -Default $PoolConfig.Algorithm -Characters "A-Z0-9" | Foreach-Object {if (@("cancel","exit","back","<") -icontains $_) {throw $_};$_}
                                    }
                                    "excludealgorithm" {
                                        $PoolConfig.ExcludeAlgorithm = Read-HostArray -Prompt "Enter algorithms you do want to exclude " -Default $PoolConfig.ExcludeAlgorithm -Characters "A-Z0-9" | Foreach-Object {if (@("cancel","exit","back","<") -icontains $_) {throw $_};$_}
                                    }
                                    "coinname" {
                                        $PoolConfig.CoinName = Read-HostArray -Prompt "Enter coins by name, you want to mine ($(if ($PoolConfig.CoinName) {"clear"} else {"leave empty"}) for all)" -Default $PoolConfig.CoinName -Characters "`$A-Z0-9. " -Valid $Pool_Avail_CoinName | Foreach-Object {if (@("cancel","exit","back","<") -icontains $_) {throw $_};$_}
                                    }
                                    "excludecoin" {
                                        $PoolConfig.ExcludeCoin = Read-HostArray -Prompt "Enter coins by name, you do want to exclude " -Default $PoolConfig.ExcludeCoin -Characters "`$A-Z0-9. " -Valid $Pool_Avail_CoinName | Foreach-Object {if (@("cancel","exit","back","<") -icontains $_) {throw $_};$_}
                                    }
                                    "coinsymbol" {
                                        $PoolConfig.CoinSymbol = Read-HostArray -Prompt "Enter coins by currency-symbol, you want to mine ($(if ($PoolConfig.CoinSymbol) {"clear"} else {"leave empty"}) for all)" -Default $PoolConfig.CoinSymbol -Characters "`$A-Z0-9" -Valid $Pool_Avail_CoinSymbol | Foreach-Object {if (@("cancel","exit","back","<") -icontains $_) {throw $_};$_}
                                    }
                                    "excludecoinsymbol" {
                                        $PoolConfig.ExcludeCoinSymbol = Read-HostArray -Prompt "Enter coins by currency-symbol, you do want to exclude " -Default $PoolConfig.ExcludeCoinSymbol -Characters "`$A-Z0-9" -Valid $Pool_Avail_CoinSymbol | Foreach-Object {if (@("cancel","exit","back","<") -icontains $_) {throw $_};$_}
                                    }
                                    "coinsymbolpbm" {
                                        $PoolConfig.CoinSymbolPBM = Read-HostArray -Prompt "Enter coins by currency-symbol, to be included if Postblockmining, only " -Default $PoolConfig.CoinSymbolPBM -Characters "`$A-Z0-9" -Valid $Pool_Avail_CoinSymbol | Foreach-Object {if (@("cancel","exit","back","<") -icontains $_) {throw $_};$_}
                                    }
                                    "minername" {
                                        $PoolConfig.MinerName = Read-HostArray -Prompt "Enter the miners your want to use ($(if ($PoolConfig.MinerName) {"clear"} else {"leave empty"}) for all)" -Default $PoolConfig.MinerName -Characters "A-Z0-9.-_" -Valid $Session.AvailMiners | Foreach-Object {if (@("cancel","exit","back","<") -icontains $_) {throw $_};$_}
                                    }
                                    "excludeminername" {
                                        $PoolConfig.ExcludeMinerName = Read-HostArray -Prompt "Enter the miners you do want to exclude" -Default $PoolConfig.ExcludeMinerName -Characters "A-Z0-9\.-_" -Valid $Session.AvailMiners | Foreach-Object {if (@("cancel","exit","back","<") -icontains $_) {throw $_};$_}
                                    }
                                    "enableautocoin" {
                                        $PoolConfig.EnableAutoCoin = Read-HostBool -Prompt "Automatically add currencies that are activated in coins.config.txt with EnableAutoPool=`"1`"" -Default $PoolConfig.EnableAutoCoin | Foreach-Object {if (@("cancel","exit","back","<") -icontains $_) {throw $_};$_}
                                    }
                                    "enablepostblockmining" {
                                        $PoolConfig.EnablePostBlockMining = Read-HostBool -Prompt "Enable forced mining a currency for a timespan after a block has been found (activate in coins.config.txt with PostBlockMining > 0)" -Default $PoolConfig.EnablePostBlockMining | Foreach-Object {if (@("cancel","exit","back","<") -icontains $_) {throw $_};$_}
                                    }
                                    "penalty" {                                                    
                                        $PoolConfig.Penalty = Read-HostDouble -Prompt "Enter penalty in percent. This value will decrease all reported values." -Default $PoolConfig.Penalty -Min 0 -Max 100 | Foreach-Object {if (@("cancel","exit","back","<") -icontains $_) {throw $_};$_}
                                    }
                                    "allowzero" {                                                    
                                        $PoolConfig.AllowZero = Read-HostBool -Prompt "Allow mining an alogorithm, even if the pool hashrate equals 0 (not recommended, except for solo or coin mining)" -Default $PoolConfig.AllowZero | Foreach-Object {if (@("cancel","exit","back","<") -icontains $_) {throw $_};$_}
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
                                            $PoolEditCurrency = Read-HostString -Prompt "Enter the currency you want to edit, add or remove (leave empty to end wallet configuration)" -Characters "A-Z0-9" -Valid $Pool_Avail_Currency | Foreach-Object {if (@("cancel","exit","back","<") -icontains $_) {throw $_};$_}
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
                                        $PoolConfig.DataWindow = Read-HostString -Prompt "Enter which datawindow is to be used for this pool ($(if ($PoolConfig.DataWindow) {"clear"} else {"leave empty"}) for default)" -Default $PoolConfig.DataWindow -Characters "A-Z0-9_\-" | Foreach-Object {if (@("cancel","exit") -icontains $_) {throw $_};$_}                                        
                                    }
                                    "stataverage" {
                                        Write-Host " "
                                        Write-Host "*** Define the pool's moving average price trendline" -ForegroundColor Green

                                        Write-HostSetupStatAverageHints
                                        $PoolConfig.StatAverage = Read-HostString -Prompt "Enter which moving average is to be used ($(if ($PoolConfig.StatAverage) {"clear"} else {"leave empty"}) for default)" -Default $PoolConfig.StatAverage -Valid @("Live","Minute_5","Minute_10","Hour","Day","ThreeDay","Week") -Characters "A-Z0-9_" | Foreach-Object {if (@("cancel","exit") -icontains $_) {throw $_};$_}
                                    }
                                    "focuswallet" {
                                        $Pool_Actual_Currency = @((Get-PoolPayoutCurrencies $PoolConfig).PSObject.Properties.Name | Sort-Object)
                                        $PoolConfig.FocusWallet = Read-HostArray -Prompt "Force mining for one or more of this pool's wallets" -Default $PoolConfig.FocusWallet -Characters "A-Z0-9" -Valid $Pool_Avail_Currency | Foreach-Object {if (@("cancel","exit","back","<") -icontains $_) {throw $_};$_}
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
                                        $PoolConfig | Add-Member CoinSymbolPBM $($PoolConfig.CoinSymbolPBM -join ",") -Force
                                        $PoolConfig | Add-Member MinerName $($PoolConfig.MinerName -join ",") -Force
                                        $PoolConfig | Add-Member ExcludeMinerName $($PoolConfig.ExcludeMinerName -join ",") -Force
                                        $PoolConfig | Add-Member EnableAutoCoin $(if (Get-Yes $PoolConfig.EnableAutoCoin){"1"}else{"0"}) -Force
                                        $PoolConfig | Add-Member EnablePostBlockMining $(if (Get-Yes $PoolConfig.EnablePostBlockMining){"1"}else{"0"}) -Force
                                        $PoolConfig | Add-Member FocusWallet $($PoolConfig.FocusWallet -join ",") -Force
                                        $PoolConfig | Add-Member AllowZero $(if (Get-Yes $PoolConfig.AllowZero){"1"}else{"0"}) -Force
                                        if ($PoolConfig.EnableMining -ne $null) {$PoolConfig.EnableMining = $(if (Get-Yes $PoolConfig.AllowZero){"1"}else{"0"})}

                                        $PoolsActual | Add-Member $Pool_Name $PoolConfig -Force
                                        $PoolsActualSave = [PSCustomObject]@{}
                                        $PoolsActual.PSObject.Properties.Name | Sort-Object | Foreach-Object {$PoolsActualSave | Add-Member $_ ($PoolsActual.$_) -Force}

                                        Set-ContentJson -PathToFile $ConfigFiles["Pools"].Path -Data $PoolsActualSave > $null

                                        Write-Host " "
                                        Write-Host "Changes written to pool configuration. " -ForegroundColor Cyan
                                                    
                                        $PoolSetupStepsDone = $true                                                  
                                    }
                                }
                                if ($PoolSetupSteps[$PoolSetupStep] -notmatch "title") {$PoolSetupStepBack.Add($PoolSetupStep) > $null}                                                
                                $PoolSetupStep++
                            }
                            catch {
                                if ($Error.Count){$Error.RemoveAt(0)}
                                if (@("back","<") -icontains $_.Exception.Message) {
                                    if ($PoolSetupStepBack.Count) {$PoolSetupStep = $PoolSetupStepBack[$PoolSetupStepBack.Count-1];$PoolSetupStepBack.RemoveAt($PoolSetupStepBack.Count-1)}
                                    else {$PoolSetupStepsDone = $true}
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
                    $OCprofilesActual = Get-Content $ConfigFiles["OCProfiles"].Path | ConvertFrom-Json
                    $Device_Name = Read-HostString -Prompt "Which device do you want to configure? (leave empty to end device config)" -Characters "A-Z0-9" -Valid @($SetupDevices.Model | Select-Object -Unique | Sort-Object) | Foreach-Object {if (@("cancel","exit","back","<") -icontains $_) {throw $_};$_}
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
                            try {
                                Switch ($DeviceSetupSteps[$DeviceSetupStep]) {
                                    "algorithm" {
                                        $DeviceConfig.Algorithm = Read-HostArray -Prompt "Enter algorithms you want to mine ($(if ($DeviceConfig.Algorithm) {"clear"} else {"leave empty"}) for all)" -Default $DeviceConfig.Algorithm -Characters "A-Z0-9" | Foreach-Object {if (@("cancel","exit","back","<") -icontains $_) {throw $_};$_}
                                    }
                                    "excludealgorithm" {
                                        $DeviceConfig.ExcludeAlgorithm = Read-HostArray -Prompt "Enter algorithms you do want to exclude " -Default $DeviceConfig.ExcludeAlgorithm -Characters "A-Z0-9" | Foreach-Object {if (@("cancel","exit","back","<") -icontains $_) {throw $_};$_}
                                    }
                                    "minername" {
                                        $DeviceConfig.MinerName = Read-HostArray -Prompt "Enter the miners your want to use ($(if ($DeviceConfig.MinerName) {"clear"} else {"leave empty"}) for all)" -Default $DeviceConfig.MinerName -Characters "A-Z0-9.-_" -Valid $Session.AvailMiners | Foreach-Object {if (@("cancel","exit","back","<") -icontains $_) {throw $_};$_}
                                    }
                                    "excludeminername" {
                                        $DeviceConfig.ExcludeMinerName = Read-HostArray -Prompt "Enter the miners you do want to exclude" -Default $DeviceConfig.ExcludeMinerName -Characters "A-Z0-9\.-_" -Valid $Session.AvailMiners | Foreach-Object {if (@("cancel","exit","back","<") -icontains $_) {throw $_};$_}
                                    }
                                    "disabledualmining" {
                                        $DeviceConfig.DisableDualMining = Read-HostBool -Prompt "Disable all dual mining algorithm" -Default $DeviceConfig.DisableDualMining | Foreach-Object {if (@("cancel","exit","back","<") -icontains $_) {throw $_};$_}
                                    }
                                    "defaultocprofile" {                                                        
                                        $DeviceConfig.DefaultOCprofile = Read-HostString -Prompt "Select the default overclocking profile for this device ($(if ($DeviceConfig.DefaultOCprofile) {"clear"} else {"leave empty"}) for none)" -Default $DeviceConfig.DefaultOCprofile -Characters "A-Z0-9" -Valid @($OCprofilesActual.PSObject.Properties.Name | Sort-Object) | Foreach-Object {if (@("cancel","exit","back","<") -icontains $_) {throw $_};$_}
                                    }
                                    "poweradjust" {                                                        
                                        $DeviceConfig.PowerAdjust = Read-HostDouble -Prompt "Adjust power consumption to this value in percent, e.g. 75 would result in Power x 0.75 (enter 100 for original value)" -Default $DeviceConfig.PowerAdjust -Min 0 | Foreach-Object {if (@("cancel","exit","back","<") -icontains $_) {throw $_};$_}
                                    }
                                    "save" {
                                        Write-Host " "
                                        if (-not (Read-HostBool -Prompt "Done! Do you want to save the changed values?" -Default $True | Foreach-Object {if (@("cancel","exit","back","<") -icontains $_) {throw $_};$_})) {throw "cancel"}
                                                        
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
                                $DeviceSetupStepBack.Add($DeviceSetupStep) > $null
                                $DeviceSetupStep++
                            }
                            catch {
                                if ($Error.Count){$Error.RemoveAt(0)}
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
                    $Algorithm_Name = Read-HostString -Prompt "Which algorithm do you want to configure? (leave empty to end algorithm config)" -Characters "A-Z0-9" -Valid $AllAlgorithms | Foreach-Object {if (@("cancel","exit","back","<") -icontains $_) {throw $_};$_}
                    if ($Algorithm_Name -eq '') {throw}

                    if (-not $AlgorithmsActual.$Algorithm_Name) {
                        $AlgorithmsActual | Add-Member $Algorithm_Name ([PSCustomObject]@{Penalty="0";MinHashrate="0";MinWorkers="0";MaxTimeToFind="0"}) -Force
                        Set-ContentJson -PathToFile $ConfigFiles["Algorithms"].Path -Data $AlgorithmsActual > $null
                    }

                    if ($Algorithm_Name) {
                        $AlgorithmSetupStepsDone = $false
                        $AlgorithmSetupStep = 0
                        [System.Collections.ArrayList]$AlgorithmSetupSteps = @()
                        [System.Collections.ArrayList]$AlgorithmSetupStepBack = @()

                        $AlgorithmConfig = $AlgorithmsActual.$Algorithm_Name.PSObject.Copy()

                        $AlgorithmSetupSteps.AddRange(@("penalty","minhashrate","minworkers","maxtimetofind")) > $null
                        $AlgorithmSetupSteps.Add("save") > $null
                                        
                        do { 
                            try {
                                Switch ($AlgorithmSetupSteps[$AlgorithmSetupStep]) {
                                    "penalty" {
                                        $AlgorithmConfig.Penalty = Read-HostInt -Prompt "Enter penalty in percent. This value will decrease all reported values." -Default $AlgorithmConfig.Penalty -Min 0 -Max 100 | Foreach-Object {if (@("cancel","exit","back","<") -icontains $_) {throw $_};$_}
                                    }
                                    "minhashrate" {
                                        $AlgorithmConfig.MinHashrate = Read-HostString -Prompt "Enter minimum hashrate at a pool (units allowed, e.g. 12GH)" -Default $AlgorithmConfig.MinHashrate -Characters "0-9kMGTPH`." | Foreach-Object {if (@("cancel","exit","back","<") -icontains $_) {throw $_};$_}
                                        $AlgorithmConfig.MinHashrate = $AlgorithmConfig.MinHashrate -replace "([A-Z]{2})[A-Z]+","`$1"
                                    }
                                    "minworkers" {
                                        $AlgorithmConfig.MinWorkers = Read-HostString -Prompt "Enter minimum amount of workers at a pool (units allowed, e.g. 5k)" -Default $AlgorithmConfig.MinWorkers -Characters "0-9kMGTPH`." | Foreach-Object {if (@("cancel","exit","back","<") -icontains $_) {throw $_};$_}
                                        $AlgorithmConfig.MinWorkers = $AlgorithmConfig.MinWorkers -replace "([A-Z])[A-Z]+","`$1"
                                    }
                                    "maxtimetofind" {
                                        $AlgorithmConfig.MaxTimeToFind = Read-HostString -Prompt "Enter maximum average time to find a block (units allowed, e.h. 1h=one hour, default unit is s=seconds)" -Default $AlgorithmConfig.MaxTimeToFind -Characters "0-9smhdw`." | Foreach-Object {if (@("cancel","exit","back","<") -icontains $_) {throw $_};$_}
                                        $AlgorithmConfig.MaxTimeToFind = $AlgorithmConfig.MaxTimeToFind -replace "([A-Z])[A-Z]+","`$1"
                                    }
                                    "save" {
                                        Write-Host " "
                                        if (-not (Read-HostBool -Prompt "Done! Do you want to save the changed values?" -Default $True | Foreach-Object {if (@("cancel","exit","back","<") -icontains $_) {throw $_};$_})) {throw "cancel"}
                                                        
                                        $AlgorithmConfig | Add-Member Penalty "$($AlgorithmConfig.Penalty)" -Force
                                        $AlgorithmConfig | Add-Member MinHashrate $AlgorithmConfig.MinHashrate -Force
                                        $AlgorithmConfig | Add-Member MinWorkers $AlgorithmConfig.MinWorkers -Force
                                        $AlgorithmConfig | Add-Member MaxTimeToFind $AlgorithmConfig.MaxTimeToFind -Force

                                        $AlgorithmsActual | Add-Member $Algorithm_Name $AlgorithmConfig -Force
                                        $AlgorithmsActualSave = [PSCustomObject]@{}
                                        $AlgorithmsActual.PSObject.Properties.Name | Sort-Object | Foreach-Object {$AlgorithmsActualSave | Add-Member $_ ($AlgorithmsActual.$_) -Force}
                                                        
                                        Set-ContentJson -PathToFile $ConfigFiles["Algorithms"].Path -Data $AlgorithmsActualSave > $null

                                        Write-Host " "
                                        Write-Host "Changes written to algorithm configuration. " -ForegroundColor Cyan
                                                    
                                        $AlgorithmSetupStepsDone = $true
                                    }
                                }
                                $AlgorithmSetupStepBack.Add($AlgorithmSetupStep) > $null
                                $AlgorithmSetupStep++
                            }
                            catch {
                                if ($Error.Count){$Error.RemoveAt(0)}
                                if (@("back","<") -icontains $_.Exception.Message) {
                                    if ($AlgorithmSetupStepBack.Count) {$AlgorithmSetupStep = $AlgorithmSetupStepBack[$AlgorithmSetupStepBack.Count-1];$AlgorithmSetupStepBack.RemoveAt($AlgorithmSetupStepBack.Count-1)}
                                }
                                elseif ($_.Exception.Message -like "Goto*") {
                                    $AlgorithmSetupStepBack.Add($AlgorithmSetupStep) > $null
                                    $AlgorithmSetupStep = $AlgorithmSetupSteps.IndexOf(($_.Exception.Message -split "\s+")[1])
                                    if ($AlgorithmSetupStep -lt 0) {
                                        Write-Log -Level Error "Unknown goto command `"$(($_.Exception.Message -split "\s+")[1])`". You should never reach here. Please open an issue on github.com"
                                        $AlgorithmSetupStep = $AlgorithmSetupStepBack[$AlgorithmSetupStepBack.Count-1];$AlgorithmSetupStepBack.RemoveAt($AlgorithmSetupStepBack.Count-1)
                                    }
                                }
                                elseif (@("exit","cancel") -icontains $_.Exception.Message) {
                                    Write-Host " "
                                    Write-Host "Cancelled without changing the configuration" -ForegroundColor Red
                                    Write-Host " "
                                    $AlgorithmSetupStepsDone = $true                                               
                                }
                                else {
                                    Write-Log -Level Warn "`"$($_.Exception.Message)`". You should never reach here. Please open an issue on github.com"
                                    $AlgorithmSetupStepsDone = $true
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
                            @{Label="EAP"; Expression={"$(if (Get-Yes $_.Value.EnableAutoPool) {"Y"} else {"N"})"}; Align="center"}
                            @{Label="Wallet"; Expression={"$($_.Value.Wallet)"}}
                        )
                        [console]::ForegroundColor = $p

                        $Coin_Symbol = Read-HostString -Prompt "Which coinsymbol do you want to edit/create/delete? (leave empty to end coin config)" -Characters "`$A-Z0-9" | Foreach-Object {if (@("cancel","exit","back","<") -icontains $_) {throw $_};$_}
                        if ($Coin_Symbol -eq '') {throw}

                        $Coin_Symbol = $Coin_Symbol.ToUpper()

                        if (-not $CoinsActual.$Coin_Symbol) {
                            if (Read-HostBool "Do you want to add a new coin `"$($Coin_Symbol)`"?" -Default $true) {
                                $CoinsActual | Add-Member $Coin_Symbol $CoinsDefault -Force
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
                        $CoinSetupStepsDone = $false
                        $CoinSetupStep = 0
                        [System.Collections.ArrayList]$CoinSetupSteps = @()
                        [System.Collections.ArrayList]$CoinSetupStepBack = @()

                        $CoinConfig = $CoinsActual.$Coin_Symbol.PSObject.Copy()
                        $CoinsDefault.PSObject.Properties.Name | Where {$CoinConfig.$_ -eq $null} | Foreach-Object {$CoinConfig | Add-Member $_ $CoinsDefault.$_ -Force}

                        $CoinSetupSteps.AddRange(@("penalty","minhashrate","minworkers","maxtimetofind","postblockmining","wallet","enableautopool")) > $null
                        $CoinSetupSteps.Add("save") > $null
                                        
                        do { 
                            try {
                                Switch ($CoinSetupSteps[$CoinSetupStep]) {
                                    "penalty" {
                                        $CoinConfig.Penalty = Read-HostInt -Prompt "Enter penalty in percent. This value will decrease all reported values." -Default $CoinConfig.Penalty -Min 0 -Max 100 | Foreach-Object {if (@("cancel","exit","back","<") -icontains $_) {throw $_};$_}
                                    }
                                    "minhashrate" {
                                        $CoinConfig.MinHashrate = Read-HostString -Prompt "Enter minimum hashrate at a pool (units allowed, e.g. 12GH)" -Default $CoinConfig.MinHashrate -Characters "0-9kMGTPH`." | Foreach-Object {if (@("cancel","exit","back","<") -icontains $_) {throw $_};$_}
                                        $CoinConfig.MinHashrate = $CoinConfig.MinHashrate -replace "([A-Z]{2})[A-Z]+","`$1"
                                    }
                                    "minworkers" {
                                        $CoinConfig.MinWorkers = Read-HostString -Prompt "Enter minimum amount of workers at a pool (units allowed, e.g. 5k)" -Default $CoinConfig.MinWorkers -Characters "0-9kMGTPH`." | Foreach-Object {if (@("cancel","exit","back","<") -icontains $_) {throw $_};$_}
                                        $CoinConfig.MinWorkers = $CoinConfig.MinWorkers -replace "([A-Z])[A-Z]+","`$1"
                                    }
                                    "maxtimetofind" {
                                        $CoinConfig.MaxTimeToFind = Read-HostString -Prompt "Enter maximum average time to find a block (units allowed, e.h. 1h=one hour, default unit is s=seconds)" -Default $CoinConfig.MaxTimeToFind -Characters "0-9smhdw`." | Foreach-Object {if (@("cancel","exit","back","<") -icontains $_) {throw $_};$_}
                                        $CoinConfig.MaxTimeToFind = $CoinConfig.MaxTimeToFind -replace "([A-Z])[A-Z]+","`$1"
                                    }
                                    "postblockmining" {
                                        $CoinConfig.PostBlockMining = Read-HostString -Prompt "Enter timespan to force mining, after a block has been found at enabled pools (units allowed, e.h. 1h=one hour, default unit is s=seconds)" -Default $CoinConfig.PostBlockMining -Characters "0-9smhdw`." | Foreach-Object {if (@("cancel","exit","back","<") -icontains $_) {throw $_};$_}
                                        $CoinConfig.PostBlockMining = $CoinConfig.PostBlockMining -replace "([A-Z])[A-Z]+","`$1"
                                    }
                                    "wallet" {
                                        $CoinConfig.Wallet = Read-HostString -Prompt "Enter global wallet address (optional, will substitute string `"`$$Coin_Symbol`" in pools.config.txt)" -Default $CoinConfig.Wallet -Characters "A-Z0-9-\._~:/\?#\[\]@!\$&'\(\)\*\+,;=" | Foreach-Object {if (@("cancel","exit","back","<") -icontains $_) {throw $_};$_}
                                        $CoinConfig.Wallet = $CoinConfig.Wallet -replace "\s+"
                                    }
                                    "enableautopool" {
                                        $CoinConfig.EnableAutoPool = Read-HostBool -Prompt "Automatically enable `"$Coin_Symbol`" for pools activated in pools.config.txt with EnableAutoCoin=`"1`"" -Default $CoinConfig.EnableAutoPool | Foreach-Object {if (@("cancel","exit","back","<") -icontains $_) {throw $_};$_}
                                    }
                                    "save" {
                                        Write-Host " "
                                        if (-not (Read-HostBool -Prompt "Done! Do you want to save the changed values?" -Default $True | Foreach-Object {if (@("cancel","exit","back","<") -icontains $_) {throw $_};$_})) {throw "cancel"}

                                        $CoinConfig | Add-Member EnableAutoPool $(if (Get-Yes $CoinConfig.EnableAutoPool){"1"}else{"0"}) -Force

                                        $CoinsActual | Add-Member $Coin_Symbol $CoinConfig -Force
                                        $CoinsActualSave = [PSCustomObject]@{}
                                        $CoinsActual.PSObject.Properties.Name | Sort-Object | Foreach-Object {$CoinsActualSave | Add-Member $_ ($CoinsActual.$_) -Force}

                                        Set-ContentJson -PathToFile $ConfigFiles["Coins"].Path -Data $CoinsActualSave > $null

                                        Write-Host " "
                                        Write-Host "Changes written to coins configuration. " -ForegroundColor Cyan
                                                    
                                        $CoinSetupStepsDone = $true
                                    }
                                }
                                $CoinSetupStepBack.Add($CoinSetupStep) > $null
                                $CoinSetupStep++
                            }
                            catch {
                                if ($Error.Count){$Error.RemoveAt(0)}
                                if (@("back","<") -icontains $_.Exception.Message) {
                                    if ($CoinSetupStepBack.Count) {$CoinSetupStep = $CoinSetupStepBack[$CoinSetupStepBack.Count-1];$CoinSetupStepBack.RemoveAt($CoinSetupStepBack.Count-1)}
                                }
                                elseif ($_.Exception.Message -like "Goto*") {
                                    $CoinSetupStepBack.Add($CoinSetupStep) > $null
                                    $CoinSetupStep = $CoinSetupSteps.IndexOf(($_.Exception.Message -split "\s+")[1])
                                    if ($CoinSetupStep -lt 0) {
                                        Write-Log -Level Error "Unknown goto command `"$(($_.Exception.Message -split "\s+")[1])`". You should never reach here. Please open an issue on github.com"
                                        $CoinSetupStep = $CoinSetupStepBack[$CoinSetupStepBack.Count-1];$CoinSetupStepBack.RemoveAt($CoinSetupStepBack.Count-1)
                                    }
                                }
                                elseif (@("exit","cancel") -icontains $_.Exception.Message) {
                                    Write-Host " "
                                    Write-Host "Cancelled without changing the configuration" -ForegroundColor Red
                                    Write-Host " "
                                    $CoinSetupStepsDone = $true                                               
                                }
                                else {
                                    Write-Log -Level Warn "`"$($_.Exception.Message)`". You should never reach here. Please open an issue on github.com"
                                    $CoinSetupStepsDone = $true
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
                        [console]::ForegroundColor = $p

                        $OCProfile_Name = $OCProfile_Device = ""
                        do {
                            $OCProfile_Name = Read-HostString -Prompt "Which profile do you want to edit/create/delete? (leave empty to end profile config)" -Characters "A-Z0-9" -Default $OCProfile_Name | Foreach-Object {if (@("cancel","exit","back","<") -icontains $_) {throw $_};$_}
                            if ($OCProfile_Name -eq '') {throw}
                            if (($SetupDevices | Where-Object Type -eq "gpu" | Measure-Object).Count) {
                                $OCProfile_Device = Read-HostString -Prompt "Assign this profile to a device? (leave empty for none)" -Characters "A-Z0-9" -Valid @($SetupDevices | Where-Object Type -eq "gpu" | Select-Object -Unique -ExpandProperty Model | Sort-Object)| Foreach-Object {if (@("cancel","exit") -icontains $_) {throw $_};$_}
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
                                    "lockvoltagepoint" {
                                        $p = Read-HostString -Prompt "Enter a value in µV to lock voltage or `"0`" to unlock, `"*`" to never set" -Default $OCProfileConfig.LockVoltagePoint -Characters "0-9*+-" -Mandatory | Foreach-Object {if (@("cancel","exit","back","<") -icontains $_) {throw $_};$_}
                                        if ($p -ne '*') {
                                            $p = $p -replace '[^0-9]+'
                                            if ($p -eq '') {Write-Host "This is not a correct number" -ForegroundColor Yellow; throw "goto lockvoltagepoint"}
                                        }
                                        $OCProfileConfig.LockVoltagePoint = $p                                                            
                                    }
                                    "save" {
                                        Write-Host " "
                                        if (-not (Read-HostBool -Prompt "Done! Do you want to save the changed values?" -Default $True | Foreach-Object {if (@("cancel","exit","back","<") -icontains $_) {throw $_};$_})) {throw "cancel"}
                                                        
                                        $OCProfilesActual | Add-Member $OCProfile_Name $OCProfileConfig -Force
                                        $OCProfilesActualSave = [PSCustomObject]@{}
                                        $OCProfilesActual.PSObject.Properties.Name | Sort-Object | Foreach-Object {$OCProfilesActualSave | Add-Member $_ ($OCProfilesActual.$_) -Force}

                                        Set-ContentJson -PathToFile $ConfigFiles["OCProfiles"].Path -Data $OCProfilesActualSave > $null

                                        Write-Host " "
                                        Write-Host "Changes written to profiles configuration. " -ForegroundColor Cyan
                                                    
                                        $OCProfileSetupStepsDone = $true
                                    }
                                }
                                $OCProfileSetupStepBack.Add($OCProfileSetupStep) > $null
                                $OCProfileSetupStep++
                            }
                            catch {
                                if ($Error.Count){$Error.RemoveAt(0)}
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
                    if (-not (Read-HostBool "Edit another profile?")){throw}
                        
                } catch {if ($Error.Count){$Error.RemoveAt(0)};$OCProfileSetupDone = $true}
            } until ($OCProfileSetupDone)
        }
    } until (-not $RunSetup)

    Write-Host " "
    Write-Host "Exiting configuration setup - all miners will be restarted. Please be patient!" -ForegroundColor Yellow
    Write-Host " "
}