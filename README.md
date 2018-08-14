# RainbowMiner
###### **RELEASES: [https://github.com/RainbowMiner/RainbowMiner/releases](https://github.com/RainbowMiner/RainbowMiner/releases)**

###### **Actual master.zip: [Developer Version master.zip](https://github.com/RainbowMiner/RainbowMiner/archive/master.zip)**


## INTRODUCTION

GPU/CPU Mining script with intelligent auto-switching between different miningpools, algorithm, miner programs using all possible combinations of devices (NVIDIA, AMD and CPU), optionally including cost of electricity into profit calculations and  stop mining, if no longer profitable.
Features: easy setup wizard with adhoc working default (no editing of files needed), GUI-webinterface, selection of devices to be used, very low CPU usage.


![alt text](https://raw.githubusercontent.com/RainbowMiner/miner-binaries/master/rainbowminerhome.png "RainbowMiner Web GUI")


## FEATURE SUMMARY

- **Multi-Platform (AMD, NVIDIA, CPU)**
- **Profit auto-switch between mining programs and algorithm for GPUs & CPUs (optimized one for each vendor vs. one for each possible device combination)**
- **Profit auto-switch between pools (AHashPool, BlazePool, BlockMasters, Bsod, HashRefinery, MiningPoolHub, Nicehash, PhiPhiPool, Ravenminer, YiiMP, ZergPool and Zpool)**
- **Profit calculation, including real cost of electricity per miner**
- **Uses the top actual available miner programs (Bminer, Ccminer, Claymore, Dstm, EnemyZ, Ewbf, Sgminer and many more)**
- **Easy setup wizard with adhoc working default - click Start.bat and off you go (RainbowMiner will ask for your credentials, no hassle with editing configuration files)**
- **Mining devices freely selectable**
- **Finetune miner- and pool-configuration during runtime**
- **Bind/exclude devices to/from specific algorithm and miners**
- **Define pool's algorithms and coins**
- **Switch MSI Afterburner profiles per miner**
- **Very low CPU usage to increase CPU mining profit**
- **Pause mining without exiting the RainbowMiner**
- **Live monitoring web-interface at [localhost:4000](http://localhost:4000)**


## INSTALLATION

1. Download and extract to your desktop (find the latest release here https://github.com/RainbowMiner/RainbowMiner/releases)
2. Check powershell version and pre-requesites (see below, **very important!**)
3. Right-click "Start.bat", choose "Run as administrator": there will start two windows, one contains RainbowMiner and the other will show the output of the running miners.
4. Enter your credentials:
   - your btc-wallet address (one for general use, and one for NiceHash)
   - your desired workername (or accept the default)
   - your MiningPoolHub username, if you plan to use this pool
   - your region. Valid names are: US, Europe, Asia
   - your currencies. Valid currencies are: BTC, USD, EUR, GBP, ETH, ..
   - the pools, you want to mine as comma separated list. Valid poolnames are: ahashpool, ahashpoolcoins, blazepool, blockcruncher, blockmasters, blockmasterscoins, bsod, hashrefinery, miningpoolhub, miningpoolhubcoins, miningpoolhubmini, nicehash, phiphipool, ravenminer, yiimp, zergpool, zergpoolcoins, zpool, zpoolcoins
   - the algorithm, you want to mine as comma separated list. Valid names are: Bitcore, Blakecoin, Blake2s, BlakeVanilla, C11, CryptoNightV7, Ethash, X11, Decred, Equihash, Equihash-BTG, Groestl, HMQ1725, HSR, JHA, Keccak, Lbry, Lyra2RE2, Lyra2z, MyriadGroestl, NeoScrypt, Pascal, Phi, Polytimos, Quark, Qubit, Scrypt, SHA256, Sib, Skunk, Skein, Tensority, Timetravel, Tribus, Veltor, X11, X12, X11evo, X16R, X16S, X17, Yescrypt and many more
   - the devices, you want to use for mining. Valid descriptors are: gpu, cpu, nvidia, amd (RainbowMiner will show you, which devices are available on your machine)
     or use your device names (without spaces, without leading geforce): gtx1070, gtx1080ti ..
5. Let the downloads and benchmarking finish (it will already mine to your wallets)

Done!


## REQUIRED PRE-REQUESITES

**Make sure, that there is no other PowerShell version installed, before you start the installation of the version 6.0.2. If there is any old version, uninstall it and reboot your pc.**

- PowerShell 6 is required: [Windows 64bit](https://github.com/PowerShell/PowerShell/releases/download/v6.0.2/PowerShell-6.0.2-win-x64.msi)
- Microsoft .NET Framework 4.5.1 or later is required: [Web Installer](https://www.microsoft.com/en-us/download/details.aspx?id=40773)
- Add the directory of RainbowMiner to the exceptions of your antivirus program. Some miner cause false virus alerts.


## HOTKEYS

You can press the follwing keys, while RainbowMiner is waiting for the next run.

- E[**x**]it Miningscript = stop all running miner and exit RainbowMiner
- [**S**]kip switching prevention = immediately start the most profitable miner, without waiting for the switching prevention
- start [**D**]ownloader = start the downloader manually (only needed, if you manually updated a miner)
- [**C**]onfiguration = goto the configuration setup (after setup all miner will be restarted)
- [**V**]erbose off/on = switch the user interface from lite(=off) to full(=on)
- [**P**]ause = stop all running miner and wait until user presses P again


## RECOMMENDATIONS & HELPERS

- Set your Windows virtual memory size to a fixed size of at least 16GB, or better to the sum of your GPU memories x 1.5, e.g. if you have 6x GTX1070 8GB installed, use at least 72GB (Computer Properties->Advanced System Settings->Performance->Advanced->Virtual Memory)
- Submit bugs and feature requests here: https://github.com/RainbowMiner/RainbowMiner/issues 
- the root directory of RainbowMiner contains the follwing, additional batch files:
  - ListGPUs.bat: if clicked, a window will popup and list all available GPUs
  - MinerLog.bat: it reopens the window to show the output of the miners. Useful, if you unintentionally closed this log window.
  - RemoveLogs.bat: delete all log files to save some disk space
  - ResetBenchmark.bat: reset all benchmarks
  - ResetProfit.bat: reset RainbowMiner's profit calculation
  - Stopp.bat: halt RainbowMiner at once
	

## POOLS

- AHashPool / AHashPoolCoins https://www.ahashpool.com/ (auto-exchange and payout in BTC)
- BlazePool https://www.blazepool.com/ (auto-exchange and payout in BTC)
- BlockCruncher https://www.blockcruncher.com/ (pigeoncoin-pool, pays in PGN, set your PGN-address in ["Config\pools.config.txt"](#config-pools-config-txt))
- BlockMasters / BlockMastersCoins https://www.blockmasters.co/ (auto-exchange and payout in BTC)
- Bsod https://bsod.pw/ (no auto-exchange, a seperate wallet address is needed for each coin, you want to mine, set in ["Config\pools.config.txt"](#config-pools-config-txt))
- HashRefinery https://pool.hashrefinery.com (auto-exchange and payout in BTC)
- MiningPoolHub / MiningPooHubCoins / MiningPoolHubMini https://miningpoolhub.com/ (auto-exchange and paymout in BTC, username required)
  - 'miningpoolhub' and 'miningpoolhubmini' parameter uses the 17xxx ports therefore allows the pool to decide on which coin is mined of a specific algorithm
  - 'miningpoolhubmini' is setup to mine lyra2z, skein, myriadgroestl, groestl, neoscrypt and equihash-btg, only.
  - 'miningpoolhubcoins' allows for RainbowMiner to calculate and determine what is mined from all of the available coins (20xxx ports). 
- Nicehash https://www.nicehash.com/ (auto-exchange and payout in BTC, use of Nicehash wallet is recommended, see note below)
- Ravenminer https://www.ravenminer.com/ (ravencoin-pool, pays in RVN, set your RVN-address in ["Config\pools.config.txt"](#config-pools-config-txt))
- YiiMP https://yiimp.eu/ (no auto-exchange, a seperate wallet address is needed for each coin, you want to mine, set in ["Config\pools.config.txt"](#config-pools-config-txt))
- ZergPool / ZergPoolCoins https://zergpool.eu/ (auto-exchange and payout in BTC)
  - 'zergpool' mine most profitable algorithm. Pool chooses coin or merged mining benefits
  - 'zergpoolcoins' mine most profitable coin. If you setup RainbowMiner with many algorithm, expect a lot of switching.
- Zpool https://www.zpool.ca/ (auto-exchange and payout in BTC)
	
**Note for Nicehash:**  
If you plan to mine through Nicehash, I strongly recommend, that you register an account with them (https://www.nicehash.com/register). In this case, Nicehash will provide you with an extra NiceHash wallet/bitcoin address (RainbowMiner will ask for this address during the setup or configuration process).
This lowers the minimum payout sum from 0.1BTC (for external wallet) to a very low 0.001BTC (for Nicehash wallet). An additional benefit for Coinbase users: sending BTC from the Nicehash wallet to your Coinbase account is free of charge.

**Note for the pools BlockMasters, HashRefinery, YiiMP, ZergPool, ZergPoolCoins and Zpool:**  
The miner can be setup to mine any coin or currency, that is listed at the respective pool. The pool will then payout to the given non-BTC wallet address. Take into account, that non-BTC payouts depend heavily on that coin being mined. If the pool has not or is not mining that currency, the payouts will be delayed until the pool has mined the blocks. Read the pools websites, about the mineability and reliability of a currency. It's recommended to use BTC as any other coin could be removed at anytime and payouts will not occur. The YiiMP pool is an exception, as it does not have auto-exchange to BTC. Please be careful, what you choose to mine.


## MINERS

- The RainbowMiner contains a list of well approved miners in the directory "Miners"
- In the directory "OptionalMiners" we put miners, that we consider as potential instable or possibly the cause of other problems (eg. T-Rex, CuBalloon). If you want to absolutely try these miners, simply copy them over into the "Miners" directory.
- The miner Excavator mines on NiceHash pool, only
- Miners Excavator & Excavator1.4.4 run in their own miner window. Since these two miners are each being controlled through an own API, the miner windows will stay open idle, even after the mining has stopped. This does no harm nor does it cost CPU - the miner will wait until it is being called again. You may close these windows, if you want. RainbowMiner will restart them, if Excavator is needed again.
- Each miner's algorithm can be fine tuned for each device in your mining rig (see section [ADVANCED CONFIGURATION->Config\miners.config.txt](#config-miners-config-txt))

## MSI AFTERBURNER CONFIGURATION

The MSI Afterburner allows to configure up to five profiles. Each of which defines the exact overclocking parameters for any number of GPU.
RainbowMiner includes automatic switching those profiles, if you wish. To enable MSI Afterburner handling, check or set the path to MSIA and set the MSI default profile to a number from 1 to 5 
I recommend you stick to the following profile setup. The overclocking values in brackets (core clock/memory clock) are those I use on my GTX 1070 and are only for illustration. The precise setting per GPU can be done by editing the miners.config.txt

- Profile 1: no overclocking (+0/+0)
- Profile 2: max. core / max. memory oc (+100/+400), recm. as default
- Profile 3: max. core / half memory oc (+100/+200), recm. for claymore ethash-keccak, neoscrypt
- Profile 4: max. core / no memory oc (+100/0), recm. for lyra2re2, lyra2z, x16r, x16s
- Profile 5: max. core / reduced memory oc (+100/+350), recm. for claymore ethash-blake2s, claymore ethash-pascal

Be careful when playing with OC, since this can damage your devices. RainbowMiner will not be responsible, if you kill your devices.
The profile will only be set to a value other than the defined default, if all GPU selected by RainbowMiner have the same profile configured (in legacy mode, always the case)


## ALGORITHMS

RainbowMiner uses a build-in hash table to convert different algorithmnames to unique and beautified, internal representations. Because of this, you do not have to care too much about how to write an algorithm, when directly editing the "Config\config.txt" or using command line parameters. E.g. cryptonight-v7, cryptonight/1, cryptonightv7 would all be converted to CryptonightV7.

## Special notes for Equihash

The different Equihash algorithms are distinguished using the following Parameters: (n, k). For example, the classic Equihash first used by Zcash used n = 200 and k = 9, so it became Equihash (200, 9).

The n and k values create enormous differences in the minimum memory requirement, and create enormous differences in how the actual mining software is coded in order to do the mining.

RainbowMiner uses the following nameing convention:
- Equihash16x5 = Equihash (96, 5)	
- Equihash20x9 = Equihash (200, 9)
- Equihash21x9 = Equihash (210, 9)	
- Equihash24x5 = Equihash (144,5)	
- Equihash24x7 = Equihash (192,7)

The new numbers (16x5, 20x9, ..) describe the number of bits matched in each round for the algorithm, and provide a relative measure of the “hardness” of the algorithm (the numbers can be calculated, using n and k: n/(k+1) )

RainbowMiner's build-in hash table makes it possible for you, to use many different algorithmnames. E.g. equihash-144_5, equihash1445, equihash-btg, equihash144btg will all be represented by Equihash24x5


## ADVANCED CONFIGURATION

Config files are found in directory "Config\"
- config.txt = general settings, wallet, etc.
- pools.config.txt = pool setup, set a different wallet, workername for each pool and coin
- miners.config.txt = individually add arguments to miner (selected by name and device names and algorithm)

**Note: if you have not started the Start.bat yet, there will be no config files! Start it first!**
**Config files are in JSON format. Look here for to get an idea, how they work: https://www.tutorialspoint.com/json/index.htm**
**Be careful, when editing these files. Every comma counts!**


### Config\config.txt

- Wallet = your general BTC wallet address
- WorkerName = your desired worker name
- UserName = your MiningPoolHub user name
- Interval = timing interval in seconds of RainbowMiner [default=60]
- Region = your region, [default=US]
- SSL = set to 1, if only ssl connections wanted
- DeviceName = list of device descriptors, with which you want to mine [default=nvidia,amd]
- Algorithm = list of algorithms, you want to mine [default=bitcore,blake2s,c11,cryptonightheavy,cryptonightv7,ethash,equihash,hmq1725,hsr,keccak,keccakc,lyra2re2,lyra2z,neoscrypt,pascal,phi,skein,skunk,timetravel,tribus,x16r,x16s,x17,vit,xevan,yescrypt,yescryptr16]
- MinerName = list of miner, you want to use for mining (see directory Miners, without .ps1, e.g. CcminerAlexis78.ps1 -> CcminerAlexis78)
- PoolName = list of pool names, you want to use for mining [default=nicehash,blazepool,miningpoolhubmini]
- ExcludeAlgorithm = list of algorithms, you want to exclude from mining
- ExcludeFromWatchdog = list of algorithms or miner, you want to exclude from the watchdog
- ExcludeMinerName = list of miner names, you want to exclude from mining
- ExcludePoolName = list of pool names, you want to exclude from mining
- ExcludeCoin = list of coins, you want to exclude from mining
- Currency = currencies, you want to be shown [default=BTC,USD,EUR]
- PowerPrice = price of 1kW/h (kilowatt per hour) that your electricity supplier charges [default=0]
- PowerPriceCurrency = currency of your PowerPrice [default=USD]
- UsePowerPrice = set to (1), if electricity cost should be substracted from profits [default=0]
- CheckProfitability = if no more miners are profitable and this is set to (1), RainbowMiner will idle, until profitability returns. UsePowerPrice needs to be (1) and a PowerPrice greater than zero must be set for this function to work. [default=0]
- Donate = set the minutes, you want RainbowMiner to work for the developer (min. is 10 minutes, equals to 0.7%) [default=24]
- Proxy = set your proxy address here, if you are using one
- Delay = extra delay in secondes, between switching to avoid blue screen [default=2]
- Watchdog = use (1) or do not use (0) watchdog [default=1]
- SwitchingPrevention = finetune the switching prevention algorithm. Set to zero to disable [default=2]
- ShowMinerWindow = show (1) or do not show (0) miner windows. Note: excavator will always run in an extra window [default=0]
- FastestMinerOnly = set to 1 to reduce list by only showing the fastest miner [default=1]
- IgnoreFees = set to 1, if you do not want RainbowMiner to account the pool- and miner fees [default=0]
- ExcludeMinersWithFee = exclude all miners, that have a developer fee build-in [default=0]
- DisableDualMining = set to 1, if you want to disable all dual mining [default=0]
- ShowPoolBalances = set to 1 to let RainbowMiner show your current pool balances [default=1]
- RebootOnGPUFailure = (currently disabled)
- MSIApath = absolute windows path to MSI Afterburner [default=c:\Program Files (x86)\MSI Afterburner\MSIAfterburner.exe]
- MSIAprofile = default MSI Afterburner profile (1-5) [default=2]
- UIstyle = set to "full" for complete listing, set to "lite" for reduced listing [default=full]
- MiningMode = possible values are "legacy", "device" and "combo", see explanation below
  - "legacy": one miner will handle all devices of one vendor together. Only NVIDIA, AMD, CPU are possible to select.
  - "device" (default): each device group (e.g. GTX1070, RX570, CPU..) will get the most profitable miner to work on the different algorithm. If you have three different device groups, there will be three miners launched.
  - "combo": in addition to "device" mode, all possible combinations of device groups are taken into account. E.g. if all device types are considered most profitable for one specific miner, only one instance of the miner will be launched. Device types will only be combined for specific algorithm, if they have exactly equal params configured in miners.config.txt (the strings have to match). The combination of devices will be monitored seperatly: if the combo is less efficient than single miners, it will be deactivated automatically.


### Config\pools.config.txt

Each pool has it's own section, in the pools.config.txt

#### Change payout currency of a pool (e.g. Ravenminer uses RVN)

The default pool config look like this:

    "Zpool": {
        "BTC": "$Wallet",
        "Worker": "$WorkerName",
        "Penalty": 0
    }

The line "BTC": "$Wallet" defines the payout wallet address. $Wallet uses the value in your config.txt
If you want to change it to LTC, for example, you have to change this line like this:

    "Zpool": {
        "LTC": "<YOUR_LITECOIN_ADDRESS>",
        "Worker": "$WorkerName",
        "Penalty": 0
    }

#### Change a pool's penalty
    
If you feel like a pool tends to exagerate it's results, you can set a penalty in % through the field "Penalty":

    "Ravenminer": {
        "RVN": "<YOUR_RAVENCOIN_ADDRESS>",
        "Worker": "$WorkerName",
        "Penalty": 5
    }

This would reduce the hashrate-results from the pool Ravenminer by 5%

#### Change a pool's time frame (data window)

To override the default data window of the YiiMP based pools (AHashPool,BlazePool,BlockMasters,Hashrefinery,ZergPool,Zpool) the parameter "DataWindow" can be added to the pool's configuration record. 
Possible values are:
- estimate_current (=default): the pool's current calculated profitability-estimation (more switching, relies on the honesty of the pool)
- estimate_last24h: the pool's calculated profitability-estimation for the past 24 hours (less switching, relies on the honesty of the pool)
- actual_last24h: the actual profitability over the past 24 hours (less switching)
- mininum: the minimum value of estimate_current and actual_last24h will be used
- maximum: the maximum value of estimate_current and actual_last24h will be used
- average: the calculated average of estimate_current and actual_last24h will be used
- mininumall: the minimum value of the above three values will be used
- maximumall: the maximum value of the above three values will be used
- averageall: the calculated average of the above three values will be used

Example:

    "Zpool": {
        "LTC": "<YOUR_LITECOIN_ADDRESS>",
        "Worker": "$WorkerName",
        "Penalty": 0
        "DataWindow": "minimum"
    }


#### Define the algorithms and coins of a pool
    
Per default all algorithms of a pool will be used. To define your own set of algorithm, there are two additional fields:
- Algorithm: a comma separated list of all pool's algorithm, you want RainbowMiner to use (leave empty for all)
- ExcludeAlgorithm: a comma separated list of all pool's algorithm, you explicitly do not want RainbowMiner to use (leave empty for no exception)
- ExcludeCoin: a comma separated list of coins, you explicitly do not want RainbowMiner to use (leave empty for all coins). The coin's name must be spelled exactly like it is used at the corresponding pool. It applies to the pools, that transmit the coin names, only.

Example:

    "MiningPoolHub": {
        "User": "$UserName",
        "Worker": "$WorkerName",
        "API_ID": "$API_ID",
        "API_Key": "$API_Key",
        "Algorithm": "lyra2z,skein,myriadgroestl,groestl,neoscrypt,equihash-btg",
        "ExcludeAlgorithm": "",
        "ExcludeCoin": "BitcoinGold,MaxCoin"
    }


### Config\miners.config.txt

Each miner can be configured by it's own section, in the miners.config.txt

Example:

    {
        "CcminerAlexis78-NVIDIA":  [
                                {
                                    "MainAlgorithm":  "c11",
                                    "SecondaryAlgorithm":  "",
                                    "Params":  "-i 21",
                                    "Profile":  ""
                                },
                                {
                                    "MainAlgorithm":  "keccak",
                                    "SecondaryAlgorithm":  "",
                                    "Params":  "-m 2 -i 19,29",
                                    "Profile":  ""
                                }
                            ],
       "CcminerAlexis78-GTX1070":  [
                                {
                                    "MainAlgorithm":  "c11",
                                    "SecondaryAlgorithm":  "",
                                    "Params":  "-i 21",
                                    "Profile":  ""
                                },
                                {
                                    "MainAlgorithm":  "keccak",
                                    "SecondaryAlgorithm":  "",
                                    "Params":  "-m 2 -i 19,29",
                                    "Profile":  ""
                                }
                            ],
        "Sgminer-AMD":  [
                                {
                                    "MainAlgorithm":  "lyra2rev2",
                                    "SecondaryAlgorithm":  "",
                                    "Params":  "--gpu-threads 2 --worksize 128 --intensity d",
                                    "Profile":  ""
                                },
                                {
                                    "MainAlgorithm":  "neoscrypt",
                                    "SecondaryAlgorithm":  "",
                                    "Params":  "--gpu-threads 1 --worksize 64 --intensity 15",
                                    "Profile":  ""
                                }
                            ],
        "Trex":  [
                                {
                                    "MainAlgorithm":  "\*",
                                    "SecondaryAlgorithm":  "",
                                    "Params":  "",
                                    "Profile":  "",
                                    "Penalty": "12.5"
                                }
                            ]                                                                
    }

.. this adds extra command line parameters "-i 21" and "-m 2 -i 19,29" to
- "CcminerAlexis78-NVIDIA": miner CcminerAlexis78 in LegacyMining mode, mine on all selected nvidia GPU, Algorithms c11 and keccak
- "CcminerAlexis78-GTX1070": miner CcminerAlexis78 in non-LegacyMining mode on selected GPU devices with model name GTX1070, Algorithms c11 and keccak
- "Sgminer-AMD": miner Sgminer in LegacyMining mode, mine on all selected amd GPU, Algorithms c11 and keccak
- "MainAlgorithm": alogrithm, for which the extra configuration will be used
- "SecondaryAlgorithm": secondary alogrithm, for which the extra configuration will be used (used for dual-mining Claymore, Excavator)
- "Params": these are the extra parameters, that will be added to the miner call
- "Profile": desired MSI Afterburner profile

.. this adds a Penalty of 12.5% to all algorithms used by Trex


### Config\devices.config.txt

Each device group can be bound to/excluded from specific algorithm and miners by editing this config file.

Example:

    {
      "GTX1050Ti": [
        {
          "Algorithm": "Ethash,x16r",
          "ExcludeAlgorithm": "",
          "MinerName": "",
          "ExcludeMinerName": "ClaymoreEthash",
          "DisableDualMining": "1"
        }
      ]
    }

This configuration would bind all GTX1050Ti in the system to Ethash and X16R mining, only, excluding the ClaymoreEthash miner. Setting the flag "DisableDualMining" to "1", all dual-algorithm miners will be removed from this device's list.


## WEB-INTERFACE

For your convenience, you can monitor and setup RainbowMiner using your web browser. The web interface very prominently shows RainbowMiner's live profitability and the current BTC exchange rates. To start the web interface, simply open the URL [localhost:4000](http://localhost:4000) in a new browser tab.
- Dashboard: shows the live running miners & pool balances, click the Pause/Restart button to halt and restart RainbowMiner. It will take up to 20 seconds, until the miner script finalize the pause/restart procedure, so give it some time.
- Selected Devices: lists the preselected devices (through command line parameter or configuration)
- All Devices: lists all available devices in your rig
- Best Pools: lists the best possible pool for every algorithm
- All Pools: lists all pools available vs. all algorithm
- Miners: lists all miners vs. all algorithm
- Active Miners: lists the best possible miners for each algorithm
- Manage Stats: reset stats of failed miners & reset all benchmarks
- Restart benchmarks for updated miners


## CREDITS

The miner script has initially been forked from https://github.com/MultipoolMiner/MultipoolMiner for my private use, only.
Since I changed and optimized the script a lot to suit my needs, I decided to make the source code public, so that others can profit from my optimizations.

**
If you are happy with the script, bitcoin donations are greatly appreciated:
- The MultipoolMiner author: 1MsrCoAt8qM53HUMsUxvy9gMj3QVbHLazH
- The RainbowMiner author: 3DxRETpBoXKrEBQxFb2HsPmG6apxHmKmUx
**

