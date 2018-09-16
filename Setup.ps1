Set-Location (Split-Path $MyInvocation.MyCommand.Path)

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
        if (-not $Config.Wallet -or -not $Config.WorkerName -or -not $Config.PoolName) {
            Write-Host " WARNING: without the following data, RainbowMiner is not able to start mining. " -BackgroundColor Yellow -ForegroundColor Black
            if (-not $Config.Wallet)     {Write-Host "- No BTC-wallet defined! Please go to [W]allets and input your wallet! " -ForegroundColor Yellow}
            if (-not $Config.WorkerName) {Write-Host "- No workername defined! Please go to [W]allets and input a workername! " -ForegroundColor Yellow}
            if (-not $Config.PoolName)   {Write-Host "- No pool selected! Please go to [S]elections and add some pools! " -ForegroundColor Yellow}            
            Write-Host " "
        }
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
            "C" {$GlobalSetupName = "Common";$GlobalSetupSteps.AddRange(@("miningmode","devicename","cpuminingthreads","enablecpuaffinity","devicenameend","region","currency","uistyle","fastestmineronly","showpoolbalances","showpoolbalancesdetails","showpoolbalancesexcludedpools","showminerwindow","ignorefees","enableocprofiles","enableocvoltage","msia","msiapath","ethpillenable","localapiport","enableautominerports","enableautoupdate")) > $null}
            "E" {$GlobalSetupName = "Energycost";$GlobalSetupSteps.AddRange(@("powerpricecurrency","powerprice","poweroffset","usepowerprice","checkprofitability")) > $null}
            "S" {$GlobalSetupName = "Selection";$GlobalSetupSteps.AddRange(@("poolname","minername","excludeminername","excludeminerswithfee","disabledualmining","algorithm","excludealgorithm","excludecoinsymbol","excludecoin")) > $null}
            "A" {$GlobalSetupName = "All";$GlobalSetupSteps.AddRange(@("wallet","nicehash","workername","username","apiid","apikey","region","currency","localapiport","enableautominerports","enableautoupdate","poolname","minername","excludeminername","algorithm","excludealgorithm","excludecoinsymbol","excludecoin","disabledualmining","excludeminerswithfee","devicenamebegin","miningmode","devicename","devicenamewizard","devicenamewizardgpu","devicenamewizardamd1","devicenamewizardamd2","devicenamewizardnvidia1","devicenamewizardnvidia2","devicenamewizardcpu1","devicenamewizardend","cpuminingthreads","enablecpuaffinity","devicenameend","uistyle","fastestmineronly","showpoolbalances","showpoolbalancesdetails","showpoolbalancesexcludedpools","showminerwindow","ignorefees","watchdog","enableocprofiles","enableocvoltage","msia","msiapath","ethpillenable","proxy","delay","interval","disableextendinterval","switchingprevention","disablemsiamonitor","usetimesync","powerpricecurrency","powerprice","poweroffset","usepowerprice","checkprofitability","donate")) > $null}
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

                    "localapiport" {
                        if ($IsInitialSetup) {
                            Write-Host " "
                            Write-Host "RainbowMiner can be monitored using your webbrowser at http://localhost:$($Config.LocalAPIPort)" -ForegroundColor Cyan
                            Write-Host " "
                        }
                        $Config.LocalAPIport = Read-HostInt -Prompt "Choose the web interface localhost port" -Default $Config.LocalAPIPort -Mandatory -Min 1000 -Max 9999 | Foreach-Object {if (@("cancel","exit","back","<") -icontains $_) {throw $_};$_}
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
                            $Skip = Read-HostBool -Prompt "Do you want to skip the miner and algorithm setup?" -Default $true | Foreach-Object {if (@("cancel","exit","back","<") -icontains $_) {throw $_};$_}
                            if ($Skip) {throw "Goto devicenamebegin"}
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
                            throw "Goto devicenamewizard$($AvailDeviceGPUVendors[0].ToLower())1"
                        }
                        if ($AvailDeviceCounts["GPU"] -eq 1) {
                            if (Read-HostBool -Prompt "Mine on your $($AllDevices | Where-Object {$_.Type -eq "gpu" -and $_.Vendor -eq $AvailDeviceGPUVendors[0]} | Select -ExpandProperty Model_Name -Unique)" -Default $true | Foreach-Object {if (@("cancel","exit","back","<") -icontains $_) {throw $_};$_}) {
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
                            $NewDeviceName["AMD"] = Read-HostArray -Prompt "Enter the AMD devices you want to use for mining (leave empty for none)" -Characters "A-Z0-9#" -Valid @($AllDevices | Where-Object {$_.Vendor -eq "AMD" -and $_.Type -eq "GPU"} | Foreach-Object {$_.Vendor;$_.Model;$_.Name} | Select-Object -Unique | Sort-Object) | Foreach-Object {if (@("cancel","exit","back","<") -icontains $_) {throw $_};$_}
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
                            $NewDeviceName["NVIDIA"] = Read-HostArray -Prompt "Enter the NVIDIA devices you want to use for mining (leave empty for none)" -Characters "A-Z0-9#" -Valid @($AllDevices | Where-Object {$_.Vendor -eq "NVIDIA" -and $_.Type -eq "GPU"} | Foreach-Object {$_.Vendor;$_.Model;$_.Name} | Select-Object -Unique | Sort-Object) | Foreach-Object {if (@("cancel","exit","back","<") -icontains $_) {throw $_};$_}
                        } else {
                            $GlobalSetupStepStore = $false
                        }
                    }
                    "devicenamewizardcpu1" {
                        $NewDeviceName["CPU"] = @()
                        if (Read-HostBool -Prompt "Do you want to mine on your $(if ($AvailDeviceCounts["cpu"] -gt 1){"s"})" -Default $false | Foreach-Object {if (@("cancel","exit","back","<") -icontains $_) {throw $_};$_}) {
                            $NewDeviceName["CPU"] = @("CPU")
                        }
                    }
                    "devicenamewizardend" {
                        $GlobalSetupStepStore = $false
                        $Config.DeviceName = @($NewDeviceName.Values | Where-Object {$_} | Foreach-Object {$_} | Select-Object -Unique | Sort-Object)
                        if ($Config.DeviceName.Count -eq 0) {
                            Write-Host " "
                            Write-Host "No devices selected. You cannot mine without devices. Restarting device input" -ForegroundColor Yellow
                            Write-Host " "
                            $GlobalSetupStepBack = $GlobalSetupStepBack.Where({$_ -notmatch "^devicenamewizard"})                                                
                            throw "Goto devicenamewizard"
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
                            $Config.CPUMiningThreads = Read-HostInt -Prompt "How many threads should be used for CPU mining? (leave empty for auto, max. $($Global:GlobalCPUInfo.Threads))" -Default $Config.CPUMiningThreads -Min 0 -Max $($Global:GlobalCPUInfo.Threads) | Foreach-Object {if (@("cancel","exit","back","<") -icontains $_) {throw $_};$_}
                        } else {
                            $GlobalSetupStepStore = $false
                        }
                    }
                    "enablecpuaffinity" {
                        if ($Config.DeviceName -icontains "CPU" -and $Config.CPUMiningThreads) {
                            $Config.EnableCPUAffinity = Read-HostBool -Prompt "Add `"--cpu-affinity $(Get-CPUAffinity $CPUMiningThreads -Hex)`" to cpu miner commandlines" -Default $Config.EnableCPUAffinity | Foreach-Object {if (@("cancel","exit","back","<") -icontains $_) {throw $_};$_}
                        } else {
                            $GlobalSetupStepStore = $false
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
                    "disablemsiamonitor" {
                        $Config.DisableMSIAmonitor = Read-HostBool -Prompt "Disable MSI Afterburner monitor/control" -Default $Config.DisableMSIAmonitor | Foreach-Object {if (@("cancel","exit","back","<") -icontains $_) {throw $_};$_}
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
                        $ConfigActual | Add-Member PowerOffset $Config.PowerOffset -Force
                        $ConfigActual | Add-Member PowerPriceCurrency $Config.PowerPriceCurrency -Force
                        $ConfigActual | Add-Member UsePowerPrice $(if (Get-Yes $Config.UsePowerPrice){"1"}else{"0"}) -Force
                        $ConfigActual | Add-Member CheckProfitability $(if (Get-Yes $Config.CheckProfitability){"1"}else{"0"}) -Force
                        $ConfigActual | Add-Member EthPillEnable $Config.EthPillEnable -Force
                        $ConfigActual | Add-Member EnableOCProfiles $(if (Get-Yes $Config.EnableOCProfiles){"1"}else{"0"}) -Force
                        $ConfigActual | Add-Member EnableOCVoltage $(if (Get-Yes $Config.EnableOCVoltage){"1"}else{"0"}) -Force
                        $ConfigActual | Add-Member EnableAutoupdate $(if (Get-Yes $Config.EnableAutoupdate){"1"}else{"0"}) -Force
                        $ConfigActual | Add-Member Delay $Config.Delay -Force
                        $ConfigActual | Add-Member LocalAPIport $Config.LocalAPIport -Force
                        $ConfigActual | Add-Member EnableAutoMinerPorts $(if (Get-Yes $Config.EnableAutoMinerPorts){"1"}else{"0"}) -Force
                        $ConfigActual | Add-Member DisableMSIAmonitor $(if (Get-Yes $Config.DisableMSIAmonitor){"1"}else{"0"}) -Force
                        $ConfigActual | Add-Member CPUMiningThreads $Config.CPUMiningThreads -Force
                        $ConfigActual | Add-Member EnableCPUAffinity $(if (Get-Yes $Config.EnableCPUAffinity){"1"}else{"0"}) -Force

                        if (Get-Member -InputObject $PoolsActual -Name NiceHash) {
                            $PoolsActual.NiceHash | Add-Member BTC $(if($NicehashWallet -eq $Config.Wallet -or $NicehashWallet -eq ''){"`$Wallet"}else{$NicehashWallet}) -Force
                            $PoolsActual.NiceHash | Add-Member Worker $(if($NicehashWorkerName -eq $Config.WorkerName -or $NicehashWorkerName -eq ''){"`$WorkerName"}else{$NicehashWorkerName}) -Force
                        } else {
                            $PoolsActual | Add-Member NiceHash ([PSCustomObject]@{
                                    BTC = if($NicehashWallet -eq $Config.Wallet -or $NicehashWallet -eq ''){"`$Wallet"}else{$NicehashWallet}
                                    Worker = if($NicehashWorkerName -eq $Config.WorkerName -or $NicehashWorkerName -eq ''){"`$WorkerName"}else{$NicehashWorkerName}
                                    Penalty = 0
                            }) -Force
                            foreach($q in @("Algorithm","ExcludeAlgorithm","CoinName","ExcludeCoin","CoinSymbol","ExcludeCoinSymbol")) {$PoolsActual.NiceHash | Add-Member $q "" -Force}
                        }

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
                $Error.Remove($Error[$Error.Count - 1])
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
                            Set-ContentJson -PathToFile $MinersConfigFile -Data $MinersActualSave > $null

                            Write-Host " "
                            Write-Host "Changes written to Miner configuration. " -ForegroundColor Cyan
                                                    
                            $MinerSetupStepsDone = $true                                                  
                        }
                    }
                    if ($MinerSetupStepStore) {$MinerSetupStepBack.Add($MinerSetupStep) > $null}                                                
                    $MinerSetupStep++
                }
                catch {
                    $Error.Remove($Error[$Error.Count - 1])
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
                    Set-ContentJson -PathToFile $PoolsConfigFile -Data $PoolsActual > $null
                }

                [hashtable]$Pool_Config = @{Name = $Pool_Name}
                [hashtable]$Pool_Parameters = @{StatSpan = [TimeSpan]::FromSeconds(0);InfoOnly = $true}
                foreach($p in @($Config.Pools.PSObject.Properties.Name)) {$Config.Pools.$p | Add-Member Wallets (Get-PoolPayoutCurrencies $Config.Pools.$p) -Force}
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

                                    Set-ContentJson -PathToFile $PoolsConfigFile -Data $PoolsActualSave > $null

                                    Write-Host " "
                                    Write-Host "Changes written to pool configuration. " -ForegroundColor Cyan
                                                    
                                    $PoolSetupStepsDone = $true                                                  
                                }
                            }
                            if ($PoolSetupSteps[$PoolSetupStep] -notmatch "title") {$PoolSetupStepBack.Add($PoolSetupStep) > $null}                                                
                            $PoolSetupStep++
                        }
                        catch {
                            $Error.Remove($Error[$Error.Count - 1])
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
                        
            } catch {$Error.Remove($Error[$Error.Count - 1]);$PoolSetupDone = $true}
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
                $OCprofilesActual = Get-Content $OCprofilesConfigFile | ConvertFrom-Json
                $Device_Name = Read-HostString -Prompt "Which device do you want to configure? (leave empty to end device config)" -Characters "A-Z0-9" -Valid @($SetupDevices.Model | Select-Object -Unique | Sort-Object) | Foreach-Object {if (@("cancel","exit","back","<") -icontains $_) {throw $_};$_}
                if ($Device_Name -eq '') {throw}

                if (-not $DevicesActual.$Device_Name) {
                    $DevicesActual | Add-Member $Device_Name ([PSCustomObject]@{Algorithm="";ExcludeAlgorithm="";MinerName="";ExcludeMinerName="";DisableDualMining=""}) -Force
                    Set-ContentJson -PathToFile $DevicesConfigFile -Data $DevicesActual > $null
                }

                if ($Device_Name) {
                    $DeviceSetupStepsDone = $false
                    $DeviceSetupStep = 0
                    [System.Collections.ArrayList]$DeviceSetupSteps = @()
                    [System.Collections.ArrayList]$DeviceSetupStepBack = @()

                    $DeviceConfig = $DevicesActual.$Device_Name.PSObject.Copy()

                    $DeviceSetupSteps.AddRange(@("algorithm","excludealgorithm","minername","excludeminername","disabledualmining","defaultocprofile")) > $null
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
                                "defaultocprofile" {                                                        
                                    $DeviceConfig.DefaultOCprofile = Read-HostString -Prompt "Select the default overclocking profile for this device (leave empty for none)" -Default $DeviceConfig.DefaultOCprofile -Characters "A-Z0-9" -Valid @($OCprofilesActual.PSObject.Properties.Name | Sort-Object) | Foreach-Object {if (@("cancel","exit","back","<") -icontains $_) {throw $_};$_}
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
                                                        
                                    Set-ContentJson -PathToFile $DevicesConfigFile -Data $DevicesActualSave > $null

                                    Write-Host " "
                                    Write-Host "Changes written to device configuration. " -ForegroundColor Cyan
                                                    
                                    $DeviceSetupStepsDone = $true
                                }
                            }
                            $DeviceSetupStepBack.Add($DeviceSetupStep) > $null
                            $DeviceSetupStep++
                        }
                        catch {
                            $Error.Remove($Error[$Error.Count - 1])
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
                        
            } catch {$Error.Remove($Error[$Error.Count - 1]);$DeviceSetupDone = $true}
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
        
                do {
                    $OCProfilesActual = Get-Content $OCProfilesConfigFile | ConvertFrom-Json
                    Write-Host " "
                    $p = [console]::ForegroundColor
                    [console]::ForegroundColor = "Cyan"
                    Write-Host "Current profiles:"
                    $OCProfilesActual.PSObject.Properties | Format-Table @(
                        @{Label="Name"; Expression={"$($_.Name)"}}
                        @{Label="Power Limit"; Expression={"$(if ($_.Value.PowerLimit -eq '0'){'*'}else{"$($_.Value.PowerLimit) %"})"}; Align="center"}
                        @{Label="Thermal Limit"; Expression={"$(if ($_.Value.ThermalLimit -eq '0'){'*'}else{"$($_.Value.ThermalLimit) %"})"}; Align="center"}
                        @{Label="Core Clock"; Expression={"$(if ($_.Value.CoreClockBoost -eq '*'){'*'}else{"$(if ([Convert]::ToInt32($_.Value.CoreClockBoost) -gt 0){'+'})$($_.Value.CoreClockBoost)"})"}; Align="center"}
                        @{Label="Memory Clock"; Expression={"$(if ($_.Value.MemoryClockBoost -eq '*'){'*'}else{"$(if ([Convert]::ToInt32($_.Value.MemoryClockBoost) -gt 0){'+'})$($_.Value.MemoryClockBoost)"})"}; Align="center"}                                        
                    )
                    [console]::ForegroundColor = $p

                    $OCProfile_Name = Read-HostString -Prompt "Which profile do you want to edit/create/delete? (leave empty to end profile config)" -Characters "A-Z0-9" | Foreach-Object {if (@("cancel","exit","back","<") -icontains $_) {throw $_};$_}
                    if ($OCProfile_Name -eq '') {throw}

                    if (-not $OCProfilesActual.$OCProfile_Name) {
                        if (Read-HostBool "Do you want to create new profile `"$($OCProfile_Name)`"?" -Default $true) {
                            $OCProfilesActual | Add-Member $OCProfile_Name ([PSCustomObject]@{PowerLimit = 0;ThermalLimit = 0;MemoryClockBoost = "*";CoreClockBoost = "*"}) -Force                                                
                            Set-ContentJson -PathToFile $OCProfilesConfigFile -Data $OCProfilesActual > $null
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
                                Set-ContentJson -PathToFile $OCProfilesConfigFile -Data $OCProfilesSave > $null
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

                                    Set-ContentJson -PathToFile $OCProfilesConfigFile -Data $OCProfilesActualSave > $null

                                    Write-Host " "
                                    Write-Host "Changes written to profiles configuration. " -ForegroundColor Cyan
                                                    
                                    $OCProfileSetupStepsDone = $true
                                }
                            }
                            $OCProfileSetupStepBack.Add($OCProfileSetupStep) > $null
                            $OCProfileSetupStep++
                        }
                        catch {
                            $Error.Remove($Error[$Error.Count - 1])
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
                        
            } catch {$Error.Remove($Error[$Error.Count - 1]);$OCProfileSetupDone = $true}
        } until ($OCProfileSetupDone)
    }
} until (-not $RunSetup)
$RestartMiners = $true
$ReReadConfig = $true
Write-Host " "
Write-Host "Exiting configuration setup - all miners will be restarted. Please be patient!" -ForegroundColor Yellow
Write-Host " "
