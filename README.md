# RainbowMiner
###### **RELEASES: [https://github.com/RainbowMiner/RainbowMiner/releases](https://github.com/RainbowMiner/RainbowMiner/releases)**

###### **Actual master.zip: [Developer Version master.zip](https://github.com/RainbowMiner/RainbowMiner/archive/master.zip)**

## FEATURE SUMMARY

- **Multi-Platform (AMD, NVIDIA, CPU)**
- **Profit auto-switch per selected GPUs models or alternative GPU vendor**
- **Profit auto-switch between pools (AHashPool, BlazePool, BlockMasters, HashRefinery, MiningPoolHub, Nicehash, Ravenminer, YiiMP, ZergPool and Zpool)**
- **Web-Interface through http://localhost:3999 (in development)**
- **Switch MSI Afterburner profiles per miner**
- **Easy setup - simply click Start.bat (RainbowMiner will ask for your credentials)**
- **Change global, miner and pool-configuration during runtime**
- **Pause mining without exiting the RainbowMiner**
- **Easy control through command line parameters or config files**


## INSTALLATION

1. Download and extract to your desktop (find the latest release here https://github.com/RainbowMiner/RainbowMiner/releases)
2. Check powershell version and pre-requesites (see below, very important!)
3. Right-click "Start.bat", choose "Run as administrator"
4. Enter your credentials:
   - your btc-wallet address (one for general use, and one for NiceHash)
   - your desired workername (or accept the default)
   - your MiningPoolHub username, if you plan to use this pool
   - your region. Valid names are: US, Europe, Asia
   - your currencies. Valid currencies are: BTC, USD, EUR, GBP, ETH, ..
   - the pools, you want to mine as comma separated list. Valid poolnames are: ahashpool, ahashpoolcoins, blazepool, blockcruncher, blockmasters, blockmasterscoins, hashrefinery, miningpoolhub, miningpoolhubcoins, miningpoolhubmini, nicehash, ravenminer, yiimp, zergpool, zergpoolcoins, zpool, zpoolcoins
   - the algorithm, you want to mine as comma separated list. Valid names are: Bitcore, Blakecoin, Blake2s, BlakeVanilla, C11, CryptoNightV7, Ethash, X11, Decred, Equihash, Groestl, HMQ1725, HSR, JHA, Keccak, Lbry, Lyra2RE2, Lyra2z, MyriadGroestl, NeoScrypt, Pascal, Phi, Polytimos, Quark, Qubit, Scrypt, SHA256, Sib, Skunk, Skein, Timetravel, Tribus, Veltor, X11, X12, X11evo, X16R, X16S, X17, Yescrypt
   - the devices, you want to use for mining. Valid descriptors are: gpu, cpu, nvidia, amd (RainbowMiner will show you, which devices are available on your machine)
     or use your device names (without spaces, without leading geforce): gtx1070, gtx1080ti ..
5. Let the downloads and benchmarking finish (it will already mine to your wallets)

Done!


## REQUIRED PRE-REQUESITES

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


## RECOMMENDATIONS
- Set your Windows virtual memory size to a fixed size of at least 16GB, or better to the sum of your GPU memories x 1.5, e.g. if you have 6x GTX1070 8GB installed, use at least 72GB (Computer Properties->Advanced System Settings->Performance->Advanced->Virtual Memory)
- Submit bugs and feature requests here: https://github.com/RainbowMiner/RainbowMiner/issues 
	

## POOLS
- AHashPool / AHashPoolCoins https://www.ahashpool.com/ (auto-exchange and payout in BTC)
- BlazePool https://www.blazepool.com/ (auto-exchange and payout in BTC)
- BlockCruncher https://www.blockcruncher.com/ (pigeoncoin-pool, pays in PGN, set your PGN-address in "Config\pools.config.txt")
- BlockMasters / BlockMastersCoins https://www.blockmasters.co/ (auto-exchange and payout in BTC)
- HashRefinery https://pool.hashrefinery.com (auto-exchange and payout in BTC)
- MiningPoolHub / MiningPooHubCoins / MiningPoolHubMini https://miningpoolhub.com/ (auto-exchange and paymout in BTC, username required)
  - 'miningpoolhub' and 'miningpoolhubmini' parameter uses the 17xxx ports therefore allows the pool to decide on which coin is mined of a specific algorithm
  - 'miningpoolhubcoins' allows for RainbowMiner to calculate and determine what is mined from all of the available coins (20xxx ports). 
- Nicehash https://www.nicehash.com/ (auto-exchange and payout in BTC)
- Ravenminer https://www.ravenminer.com/ (ravencoin-pool, pays in RVN, set your RVN-address in "Config\pools.config.txt")
- YiiMP https://yiimp.eu/ (no auto-exchange, a seperate wallet address is needed for each coin, you want to mine, set in "Config\pools.config.txt")
- ZergPool https://zergpool.eu/ (auto-exchange and payout in BTC)
- Zpool https://www.zpool.ca/ (auto-exchange and payout in BTC)
	

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
- ExtendInterval = list of alogrithms and miner names, for benchmarking instable alogrithms (escpecially X16r) the Interval will be multiplied by 10 [default=X16r,Ravenminer]
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
- Currency = currencies, you want to be shown [default=BTC,USD,EUR]
- Donate = set the minutes, you want RainbowMiner to work for the developer (min. is 10 minutes, equals to 0.7%) [default=24]
- Proxy = set your proxy address here, if you are using one
- Delay = extra delay in secondes, between switching to avoid blue screen [default=2]
- Watchdog = use (1) or do not use (0) watchdog [default=1]
- SwitchingPrevention = finetune the switching prevention algorithm. Set to zero to disable [default=2]
- ShowMinerWindow = show (1) or do not show (0) miner windows. Note: excavator will always run in an extra window [default=0]
- FastestMinerOnly = set to 1 to reduce list by only showing the fastest miner [default=1]
- IgnoreFees = set to 1, if you do not want RainbowMiner to account the pool- and miner fees [default=0]
- ShowPoolBalances = set to 1 to let RainbowMiner show your current pool balances [default=1]
- RebootOnGPUFailure = (currently disabled)
- MSIApath = absolute windows path to MSI Afterburner [default=c:\Program Files (x86)\MSI Afterburner\MSIAfterburner.exe]
- MSIAprofile = default MSI Afterburner profile (1-5) [default=2]
- UIstyle = set to "full" for complete listing, set to "lite" for reduced listing [default=full]
- LegacyMining = set to 1, of you do not want RainbowMiner to differentiate between GPU models: it will break down your devices by NVIDIA, AMD and CPU, only.


### Config\pools.config.txt

Each pool has it's own section, in the pools.config.txt

#### To change payout currency of a pool (e.g. Ravenminer uses RVN)

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
    
If you feel like a pool tends to exagerate it's results, you can set a penalty in % through the field "Penalty":

    "Ravenminer": {
        "RVN": "<YOUR_RAVENCOIN_ADDRESS>",
        "Worker": "$WorkerName",
        "Penalty": 5
    }

This would reduce the hashrate-results from the pool Ravenminer by 5%


### Config\miners.config.txt

Each miner can be configured by it's own section, in the miners.config.txt

Example:

    {
        "CcminerAlexis78":  [
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
                            ]                        
    }

.. this adds extra command line parameters "-i 21" and "-m 2 -i 19,29" to
- "CcminerAlexis78": miner CcminerAlexis78 in LegacyMining mode (only mine on selected amd,nvidia,cpu together), Algorithms c11 and keccak
- "CcminerAlexis78-GTX1070": miner CcminerAlexis78 in non-LegacyMining mode on selected GPU devices with model name GTX1070, Algorithms c11 and keccak
- "MainAlgorithm": alogrithm, for which the extra configuration will be used
- "SecondaryAlgorithm": secondary alogrithm, for which the extra configuration will be used (used for dual-mining Claymore, Excavator)
- "Params": these are the extra parameters, that will be added to the miner call
- "Profile": desired MSI Afterburner profile


## WEB-INTERFACE

For your convenience, you can monitor and setup RainbowMiner using your web browser. Simply open the URL [localhost:3999](http://localhost:3999) in a new browser tab.
The web interface is split into three pages:

- Home: the actual running miners plus the fastest miners, sorted by the selected devices.
- Pools: a list of all available pools. You can change the pool parameters, like currencies and penalty (under development)
- Setup: general setup of the runtime parameters (under development)


## CREDITS

The miner script has initially been forked from https://github.com/MultipoolMiner/MultipoolMiner for my private use, only.
Since I changed and optimized the script a lot to suit my needs, I decided to make the source code public, so that others can profit from my optimizations.

**
If you are happy with the script, bitcoin donations are greatly appreciated:
- The MultipoolMiner author: 1MsrCoAt8qM53HUMsUxvy9gMj3QVbHLazH
- The RainbowMiner author: 3DxRETpBoXKrEBQxFb2HsPmG6apxHmKmUx
**

