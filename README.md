# RainbowMiner [![current release](https://img.shields.io/github/release/RainbowMiner/RainbowMiner.svg)](https://github.com/RainbowMiner/RainbowMiner/releases) [![current release date](https://img.shields.io/github/release-date/RainbowMiner/RainbowMiner.svg)](https://github.com/RainbowMiner/RainbowMiner/releases) [![open issues](https://img.shields.io/github/issues-raw/RainbowMiner/RainbowMiner.svg)](https://github.com/RainbowMiner/RainbowMiner/issues)
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
- **Uses the top actual available miner programs (Bminer, Ccminer, Claymore, Dstm, EnemyZ, Ewbf, Sgminer, T-Rex and many more)**
- **Easy setup wizard with adhoc working default - click Start.bat and off you go (RainbowMiner will ask for your credentials, no hassle with editing configuration files)**
- **Build-in automatic update**
- **Mining devices freely selectable**
- **Finetune miner- and pool-configuration during runtime**
- **Bind/exclude devices to/from specific algorithm and miners**
- **Define pool's algorithms and coins**
- **Switch MSI Afterburner profiles per miner/algorithm**
- **Use unlimited custom overclocking profiles per miner/algorithm**
- **Includes [OhGodAnETHlargementPill](https://bitcointalk.org/index.php?topic=3370685.0)**
- **Very low CPU usage to increase CPU mining profit**
- **Pause mining without exiting the RainbowMiner**
- **Full automatic update**
- **Live monitoring web-interface at [localhost:4000](http://localhost:4000)**

## REQUIRED PRE-REQUESITES

1. Install PowerShell 6: [Download Installer for version 6.0.4](https://github.com/PowerShell/PowerShell/releases/download/v6.0.4/PowerShell-6.0.4-win-x64.msi)
2. Install Microsoft .NET Framework 4.5.1 or later: [Web Installer](https://www.microsoft.com/net/download/dotnet-framework-runtime)
3. Update GPU drivers: [Nvidia 399.07](https://www.nvidia.com/Download/index.aspx) and [AMD Adrenaline 18.8.2](https://support.amd.com/en-us/download/desktop?os=Windows+10+-+64)
4. RainbowMiner's overclocking features rely on MSI Afterburner, you should install and run it: [Download](http://download.msi.com/uti_exe//vga/MSIAfterburnerSetup.zip)

Finally: check, if Powershell 6 is in your PATH, because RainbowMiner will not run correctly, if the path to powershell is missing. Sometimes "C:\Program Files\PowerShell\6.0.4" has to be added manually to the PATH environement variable after installing Powershell 6.0.4. Here is a nice tutorial, how to add to PATH environment variable https://www.howtogeek.com/118594/how-to-edit-your-system-path-for-easy-command-line-access/amp/


## INSTALLATION

1. Download and extract to your desktop: [![current release](https://img.shields.io/github/release/RainbowMiner/RainbowMiner.svg)](https://github.com/RainbowMiner/RainbowMiner/releases)

2. Add the directory of RainbowMiner to the exceptions of your antivirus program. Some miner cause false virus alerts.

3. Right-click "Start.bat", choose "Run as administrator".
<details>
<summary>If windows prompts with "Windows protected your PC", click on "More info", then "Run anyway"</summary>

![Picture](https://raw.githubusercontent.com/RainbowMiner/miner-binaries/master/windowsprotectedyourpc.jpg "Windows protected your PC")

</details>

4. Enter your credentials:
   - your btc-wallet address (one for general use, and one for NiceHash)
   - your desired workername (or accept the default)
   - your MiningPoolHub username, if you plan to use this pool
   - your region. Valid names are: US, Europe, Asia
   - your currencies. Valid currencies are: BTC, USD, EUR, GBP, ETH, ..
   - the pools, you want to mine as comma separated list. 
   - the algorithm, you want to mine as comma separated list.
   - the devices, you want to use for mining. Valid descriptors are: gpu, cpu, nvidia, amd (RainbowMiner will show you, which devices are available on your machine)
     or use your device names (without spaces, without leading geforce): gtx1070, gtx1080ti ..
     
5. Let the downloads and benchmarking finish (be patient! This might take a while. Anyway: it will already mine to your wallets)

Done!

<details><summary>Valid poolnames</summary>ahashpool, ahashpoolcoins, blazepool, blockcruncher, blockmasters, blockmasterscoins, bsod, hashrefinery, miningpoolhub, miningpoolhubcoins, miningpoolhubmini, nicehash, phiphipool, ravenminer, yiimp, zergpool, zergpoolcoins, zpool, zpoolcoins</details>
<details><summary>Valid algorithms</summary> Balloon, Bitcore, Blakecoin, Blake2s, BlakeVanilla, C11, CryptoNightV7, Ethash, X11, Decred, Equihash, Equihash144, Equihash192, Equihash-BTG, Groestl, Hex, HMQ1725, HSR, JHA, Keccak, Lbry, Lyra2RE2, Lyra2z, MyriadGroestl, NeoScrypt, Pascal, Phi, Phi2, Polytimos, Quark, Qubit, Scrypt, SHA256, Sib, Skunk, Skein, Tensority, Timetravel, Tribus, Veltor, X11, X12, X11evo, X16R, X16S, X17, Yescrypt and many more</details>


## HOTKEYS

You can press the follwing keys, while RainbowMiner is waiting for the next run.

- E[**x**]it Miningscript = stop all running miner and exit RainbowMiner
- [**S**]kip switching prevention = immediately start the most profitable miner, without waiting for the switching prevention
- start [**D**]ownloader = start the downloader manually (only needed, if you manually updated a miner)
- [**C**]onfiguration = goto the configuration setup (after setup all miner will be restarted)
- [**V**]erbose off/on = switch the user interface from lite(=off) to full(=on)
- [**P**]ause = stop all running miner and wait until user presses P again
- [**U**]pdate = if a new release of RainbowMiner is available, this option will show up. Pressing this key will start the automatic update.


## RECOMMENDATIONS & HELPERS

- Set your Windows virtual memory size to a fixed size of at least 16GB, or better to the sum of your GPU memories x 1.5, e.g. if you have 6x GTX1070 8GB installed, use at least 72GB (Computer Properties->Advanced System Settings->Performance->Advanced->Virtual Memory)
- Submit bugs and feature requests here: https://github.com/RainbowMiner/RainbowMiner/issues 
- if mining on GeForce GTX 1070/GTX 1070Ti/GTX 1080/GTX 1080Ti, it is recommended to disable "Force P2 State", so that the card will always operate in P0 state. [How to set P0 state for my GTX1070 and GTX1080](https://github.com/RainbowMiner/RainbowMiner/issues/36)
- the root directory of RainbowMiner contains the follwing, additional batch files:
  - ListDevices.bat: if clicked, a window will popup and list all available devices
  - MinerLog.bat: it reopens the window to show the output of the miners. Useful, if you unintentionally closed this log window.
  - RemoveLogs.bat: delete all log files to save some disk space
  - ResetBenchmark.bat: reset all benchmarks
  - ResetProfit.bat: reset RainbowMiner's profit calculation
  - Stopp.bat: halt RainbowMiner at once
  - Updater.bat: update to newest release of RainbowMiner manually. Make sure, you stop RainbowMiner before running this helper
	

## WEB-INTERFACE

For your convenience, you can monitor and setup RainbowMiner using your web browser. The web interface very prominently shows RainbowMiner's live profitability and the current BTC exchange rates. To start the web interface, simply open the URL [localhost:4000](http://localhost:4000) in a new browser tab.
- Dashboard: shows the live running miners & pool balances, click the Pause/Restart button to halt and restart RainbowMiner. It will take up to 20 seconds, until the miner script finalize the pause/restart procedure, so give it some time.
- Selected Devices: lists the preselected devices
- All Devices: lists all available devices in your rig
- Best Pools: lists the best possible pool for every algorithm
- All Pools: lists all pools available vs. all algorithm
- Miners: lists all miners vs. all algorithm
- Active Miners: lists the best possible miners for each algorithm
- Benchmarks: monitor and reset benchmarks of failed and updated miners, reset all benchmarks


## POOLS

<details><summary>AHashPool / AHashPoolCoins</summary>https://www.ahashpool.com/  auto-exchange and payout in BTC</details>
<details><summary>BlazePool</summary> https://www.blazepool.com/ auto-exchange and payout in BTC</details>
<details><summary>BlockCruncher</summary>https://www.blockcruncher.com/ (pigeoncoin-pool, pays in PGN, set your PGN-address in pools configuration or edit pools.config.txt</details>
<details><summary>BlockMasters / BlockMastersCoins</summary>

https://www.blockmasters.co/ auto-exchange and payout in BTC
  - 'blockmasters' mine most profitable algorithm. Pool chooses coin or merged mining benefits
  - 'blockmasterscoins' mine most profitable coin. Either with auto-exchange to a currency of wish, or mine directly to individual coin wallets. If you setup RainbowMiner with many algorithm, expect a lot of switching.
</details>
<details><summary>Bsod</summary> https://bsod.pw/ no auto-exchange, a seperate wallet address is needed for each coin, you want to mine, set in pools configuration or edit pools.config.txt</details>
<details><summary>HashRefinery</summary> https://pool.hashrefinery.com auto-exchange and payout in BTC</details>
<details><summary>MiningPoolHub / MiningPooHubCoins</summary>

https://miningpoolhub.com/ auto-exchange and paymout in BTC, username required
  - 'miningpoolhub' parameter uses the 17xxx ports therefore allows the pool to decide on which coin is mined of a specific algorithm
  - 'miningpoolhubcoins' allows for RainbowMiner to calculate and determine what is mined from all of the available coins (20xxx ports).
</details>
<details><summary>Nicehash</summary> https://www.nicehash.com/ auto-exchange and payout in BTC, use of Nicehash wallet is recommended, see note below</details>
<details><summary>PhiPhiPool</summary> https://www.phi-phi-pool.com no auto-exchange, a seperate wallet address is needed for each coin, you want to mine, set in pools configuration or edit pools.config.txt</details>
<details><summary>Ravenminer</summary> https://www.ravenminer.com/ ravencoin-pool, pays in RVN, set your RVN-address in pools configuration or edit pools.config.txt</details>
<details><summary>YiiMP</summary> https://yiimp.eu/ no auto-exchange, a seperate wallet address is needed for each coin, you want to mine, set in pools configuration or edit pools.config.txt</details>
<details><summary>ZergPool / ZergPoolCoins</summary>

https://zergpool.eu/ auto-exchange and payout in BTC
  - 'zergpool' mine most profitable algorithm. Pool chooses coin or merged mining benefits
  - 'zergpoolcoins' mine most profitable coin. Either with auto-exchange to BTC, LTC, DASH, or mine directly to individual coin wallets. If you setup RainbowMiner with many algorithm, expect a lot of switching.
</details>
<details><summary>Zpool</summary> https://www.zpool.ca/ auto-exchange and payout in BTC</details>
<br />	
  
<details><summary>Notes for NiceHash</summary>

If you plan to mine through Nicehash, I strongly recommend, that you register an account with them (https://www.nicehash.com/register). In this case, Nicehash will provide you with an extra NiceHash wallet/bitcoin address (RainbowMiner will ask for this address during the setup or configuration process).
This lowers the minimum payout sum from 0.1BTC (for external wallet) to a very low 0.001BTC (for Nicehash wallet). An additional benefit for Coinbase users: sending BTC from the Nicehash wallet to your Coinbase account is free of charge.</details>
<details><summary>Notes for the pools BlockMasters, HashRefinery, YiiMP, ZergPool, ZergPoolCoins and Zpool</summary>
  
The miner can be setup to mine any coin or currency, that is listed at the respective pool. The pool will then payout to the given non-BTC wallet address. Take into account, that non-BTC payouts depend heavily on that coin being mined. If the pool has not or is not mining that currency, the payouts will be delayed until the pool has mined the blocks. Read the pools websites, about the mineability and reliability of a currency. It's recommended to use BTC as any other coin could be removed at anytime and payouts will not occur. The YiiMP pool is an exception, as it does not have auto-exchange to BTC. Please be careful, what you choose to mine.
</details>


## MINERS

- The RainbowMiner contains a list of well approved miners in the directory "Miners"
- The miner Excavator mines on NiceHash pool, only
- Miners Excavator & Excavator1.4.4 run in their own miner window. Since these two miners are each being controlled through an own API, the miner windows will stay open idle, even after the mining has stopped. This does no harm nor does it cost CPU - the miner will wait until it is being called again. You may close these windows, if you want. RainbowMiner will restart them, if Excavator is needed again.
- Each miner's algorithm can be fine tuned for each device in your mining rig


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

## OVERCLOCKING

There are two ways to adjust overclocking values in RainbowMiner:
- using MSI Afterburner profiles: recommended for mining rigs with identical GPUs, only
- using custom overclocking profiles: recommended for mining rigs with mixed GPUs

The selection is simple:
- if you plan to use custom overclocking, set "**EnableOCProfiles**" to "**1**" in your config.txt (or use the [C]onfiguration->[C]ommon)
- if you want RainbowMiner to switch between your MSI Afterburner profiles automatically, set "**MSIAprofile**" to the number (1 to 5) of your default profile (or use the [C]onfiguration->[C]ommon)
- if you do not want anything of the above two, set both, "**EnableOCProfiles**" and "**MSIAprofile**" to "**0**"


## MSI AFTERBURNER PROFILES

Overclocking option, recommended for **unique GPU mining rigs with maximum 6 GPU**

### Introduction

MSI Afterburner allows to configure up to five profiles. Each of which defines the exact overclocking parameters for any number of GPU. RainbowMiner will never change these values, but it can be defined for miners/algorithms/devices, that another profile than the default should be used during minining (miners.config.txt, fields "MSIAprofile"). RainbowMiner comes with some miner/algorithm presets, already.

### Enable Profile Switching

By default, the profile switching is disabled. To enable MSI Afterburner profile switching:
- check or set the path to MSIA (config.txt, field "MSIApath")
- set the profile number, you want to be used as default (config.txt, field "MSIAprofile") 

### Explanation of operation

RainbowMiner's default setup has already preset some Profile fields for the following algorithms (miners.config.txt, fields "MSIAprofile"):
- ClaymoreEthash-Keccak, NeoScrypt => Profile 3
- Lyra2Re2, Lyra2z, X16r, X16s => Profile 4
- ClaymoreEthash-Blake2s, ClaymoreEthash-Pascal => Profile 5

Remember: __no overclocking values will be changed by RainbowMiner!__ It will switch your preset profiles, only.

I recommend you set the following profile setup in MSI Afterburner, so that you can use the default setup of RainbowMiner. The overclocking values in brackets (core clock/memory clock) are those I use for my GTX 1070 and are only for illustration.

- Profile 1: no oc (e.g. +0/+0)
- Profile 2: max. core / max. memory oc (e.g. +100/+400), good for most miners
- Profile 3: max. core / half memory oc (e.g. +100/+200), recm. for claymore ethash-keccak, neoscrypt
- Profile 4: max. core / low memory oc (e.g. +100/-500), recm. for lyra2re2, lyra2z, x16r, x16s
- Profile 5: max. core / reduced memory oc (e.g. +100/+350), recm. for claymore ethash-blake2s, claymore ethash-pascal

Be careful when playing with OC, since this can damage your devices. RainbowMiner will not be responsible, if you kill your devices.


## CUSTOM OVERCLOCKING PROFILES

Recommended for mining rigs with **more than 6 GPU** or **different GPU**

### Introduction

Each miner/device/algorithm combination can have it's own overclocking values set by RainbowMiner. To enable: set "**EnableOCProfiles**" to "**1**" in your config.txt or use the [C]onfiguration->[C]ommon.

**!! It is important, that you coose a default profile for each GPU device in your devices.config.txt !!**

You can edit the file directly: put the name of your custom default profile into field "**DefaultOCprofile**"
Alternatively, the devices can be changed using [C]onfiguration->[D]evices

### First setup overclocking profiles

Use [C]onfiguration->[O]C-Profiles to edit, create and delete overclocking profiles. Values for PowerLimit (%), ThermalLimit (°C), MemoryClockBoost (MHz), CoreClockBoost (MHz) and LockVoltagePoint (µV) (see hint below) can be defined. You may name the profiles like you want. Of course you may also edit the ocprofiles.config.txt file directly.

Hint: LockVoltagePoint can only be set, if EnableOCvoltage is set to 1 in your config.txt (or use [C]onfiguration->[C]ommon to change)

### Second, assign profiles to miner-device-algorithms

The assignment is done, using either [C]onfiguration->[M]iners or directly edited into the miners.config.txt file. Find your miner, the device it will use, plus the algorithm and put the profile's name into the field "**OCprofile**" 


## ADVANCED CONFIGURATION

RainbowMiner has a configuration function built-in: to change any parameter of the script, press key "**C**", while the script is running.
**There is no more need to edit the following config files directly.**

Config files are found in directory "Config\"
- config.txt = general settings, wallet, etc.
- pools.config.txt = pool setup, set a different wallet, workername for each pool and coin
- miners.config.txt = individually add arguments to miner (selected by name and device names and algorithm)
- devices.config.txt = control algorithms and miners to be used by specific devices

**Note: if you have not started the Start.bat yet, there will be no config files! Start it first!**
**Config files are in JSON format. Look here for to get an idea, how they work: https://www.tutorialspoint.com/json/index.htm**
**Be careful, when editing these files. Every comma counts!**


### Config\config.txt

The config file will contain variables to reflect default values. You can safely replace those variables with values.

An example:

    "API_ID": "$API_ID",
    "API_Key": "$API_Key",

You may replace $API_ID and $API_Key with your MiningPoolHub USER ID/API KEY

    "API_ID": "12345",
    "API_Key": "0123456789abcdef0123456789abcdef0123456789abcdef",

#### Basic setup ####

- **Wallet** = your general BTC wallet address
- **WorkerName** = your desired worker name
- **UserName** = your MiningPoolHub user name
- **Currency** = currencies, you want to be shown [default=BTC,USD,EUR]
- **Region** = your region, [default=US]
- **API_ID** = your MiningPoolHub USER ID (found at MPH on page "Edit account")
- **API_Key** = your MiningPoolHub API KEY (found at MPH on page "Edit account")
- **UIstyle** = set to "full" for complete listing, set to "lite" for reduced listing [default=full]
- **EnableAutoUpdate** = set to 1 if you want RainbowMiner to be updated automatically

#### Select devices ####

- **DeviceName** = list of device descriptors, with which you want to mine [default=gpu]
  - click ListDevices.bat to find out which devices are availabe
  - out of this table, models, vendors and names can be used to select
  - for mining on all GPUs, use "gpu"
  - for mining on all Nvidia GPUs use "nvidia"
  - for mining on all AMD GPUs use "amd"
  - for mining on CPU, use "cpu"
  - examples:
    - "nvidia"
    - "gtx1070,gtx1080,cpu"
    - "cpu,gpu"
    - "gpu#01,gpu#03"

#### Select algorithms ####

- **Algorithm** = list of algorithms, you want to mine [default=bitcore,blake2s,c11,cryptonightheavy,cryptonightv7,ethash,equihash,hmq1725,hsr,keccak,keccakc,lyra2re2,lyra2z,neoscrypt,pascal,phi,skein,skunk,timetravel,tribus,x16r,x16s,x17,vit,xevan,yescrypt,yescryptr16]
- **ExcludeAlgorithm** = list of algorithms, you want to exclude from mining
- **ExcludeCoin** = list of coins, you want to exclude from mining
- **ExcludeFromWatchdog** = list of algorithms or miner, you want to exclude from the watchdog

#### Select miners ####

- **MinerName** = list of miner, you want to use for mining (see directory Miners, without .ps1, e.g. CcminerAlexis78.ps1 -> CcminerAlexis78)
- **ExcludeMinerName** = list of miner names, you want to exclude from mining
- **ExcludeMinersWithFee** = exclude all miners, that have a developer fee build-in [default=0]
- **DisableDualMining** = set to 1, if you want to disable all dual mining [default=0]
- **IgnoreFees** = set to 1, if you do not want RainbowMiner to account the pool- and miner fees [default=0]
- **ShowMinerWindow** = show (1) or do not show (0) miner windows. Note: excavator will always run in an extra window [default=0]
- **FastestMinerOnly** = set to 1 to reduce list by only showing the fastest miner [default=1]
- **DisableExtendInterval** = during benchmark, some miners will run longer to find an accurate hashrate. Set to 1 to disable the extended times (this is not recommended, as it may result in inaccurate hashrates or failed some miners) [default=0]

#### Select pools ####

- **PoolName** = list of pool names, you want to use for mining [default=nicehash,blazepool,miningpoolhubmini]
- **ExcludePoolName** = list of pool names, you want to exclude from mining
- **ShowPoolBalances** = set to 1 to let RainbowMiner show your current pool balances [default=1]

#### Select mining mode ####

- **MiningMode** = possible values are "legacy", "device" and "combo", see explanation below
  - "legacy": one miner will handle all devices of one vendor together. Only NVIDIA, AMD, CPU are possible to select.
  - "device" (default): each device group (e.g. GTX1070, RX570, CPU..) will get the most profitable miner to work on the different algorithm. If you have three different device groups, there will be three miners launched.
  - "combo": in addition to "device" mode, all possible combinations of device groups are taken into account. E.g. if all device types are considered most profitable for one specific miner, only one instance of the miner will be launched. Device types will only be combined for specific algorithm, if they have exactly equal params configured in miners.config.txt (the strings have to match). The combination of devices will be monitored seperatly: if the combo is less efficient than single miners, it will be deactivated automatically.

#### Set electricity cost handling ####

- **PowerPrice** = price of 1kW/h (kilowatt per hour) that your electricity supplier charges [default=0]
- **PowerPriceCurrency** = currency of your PowerPrice [default=USD]
- **UsePowerPrice** = set to (1), if electricity cost should be substracted from profits [default=0]
- **CheckProfitability** = if no more miners are profitable and this is set to (1), RainbowMiner will idle, until profitability returns. UsePowerPrice needs to be (1) and a PowerPrice greater than zero must be set for this function to work. [default=0]

#### Set output preference ####

#### Technical/Other ####
- **Interval** = timing interval in seconds of RainbowMiner [default=60]
- **SSL** = set to 1, if only ssl connections wanted
- **Proxy** = set your proxy address here, if you are using one
- **Delay** = extra delay in secondes, between switching to avoid blue screen [default=0]
- **Watchdog** = use (1) or do not use (0) watchdog [default=1]
- **UseTimeSync** = set to 1, if RainbowMiner should adjust the windows clock by rtp [default=1]
- **SwitchingPrevention** = finetune the switching prevention algorithm. Set to zero to disable [default=2]
- **RebootOnGPUFailure** = (currently disabled)
- **EnableOCProfiles** = set to 1, if you plan to use custom overclocking profiles [default=0]
- **MSIApath** = absolute windows path to MSI Afterburner [default=c:\Program Files (x86)\MSI Afterburner\MSIAfterburner.exe]
- **MSIAprofile** = default MSI Afterburner profile (1-5), set to 0 to disable [default=2]
- **EthPillEnable** = set to "revA" or "revB" (read [Wiki](https://github.com/OhGodACompany/OhGodAnETHlargementPill/wiki) for more information on revA/revB), or "disable" to stop using the EthPill for Ethereum mining [default=disable]
- **RemoteAPI** = set to 1 to enable accessability of API within your network [default=0]
- **Donate** = set the minutes, you want RainbowMiner to work for the developer (min. is 10 minutes, equals to 0.7%) [default=24]

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

To override the default data window "average2e" of the YiiMP based pools (AHashPool,BlazePool,BlockMasters,Hashrefinery,ZergPool,Zpool) the parameter "DataWindow" can be added to the pool's configuration record. 
Possible values are:
- estimate_current (=default): the pool's current calculated profitability-estimation (more switching, relies on the honesty of the pool)
- estimate_last24h: the pool's calculated profitability-estimation for the past 24 hours (less switching, relies on the honesty of the pool)
- actual_last24h: the actual profitability over the past 24 hours (less switching)
- minimum2: the minimum value of estimate_current and actual_last24h will be used
- maximum2: the maximum value of estimate_current and actual_last24h will be used
- average2: the calculated average of estimate_current and actual_last24h will be used
- mininum2e: the minimum value of estimate_current and estimate_last24h will be used
- maximum2e: the maximum value of estimate_current and estimate_last24h will be used
- average2e: the calculated average of estimate_current and estimate_last24h will be used
- minimum2h: the minimum value of estimate_last24h and actual_last24h will be used
- maximum2h: the maximum value of estimate_last24h and actual_last24h will be used
- average2h: the calculated average of estimate_last24h and actual_last24h will be used
- mininum3: the minimum value of the above three values will be used
- maximum3: the maximum value of the above three values will be used
- average3: the calculated average of the above three values will be used

Example:

    "Zpool": {
        "LTC": "<YOUR_LITECOIN_ADDRESS>",
        "Worker": "$WorkerName",
        "Penalty": 0
        "DataWindow": "minimum3"
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
                                    "MSIAprofile":  "",
                                    "OCprofile": ""
                                },
                                {
                                    "MainAlgorithm":  "keccak",
                                    "SecondaryAlgorithm":  "",
                                    "Params":  "-m 2 -i 19,29",
                                    "MSIAprofile":  "",
                                    "OCprofile": ""
                                }
                            ],
       "CcminerAlexis78-GTX1070":  [
                                {
                                    "MainAlgorithm":  "c11",
                                    "SecondaryAlgorithm":  "",
                                    "Params":  "-i 21",
                                    "MSIAprofile":  "",
                                    "OCprofile": "Profile1"
                                },
                                {
                                    "MainAlgorithm":  "keccak",
                                    "SecondaryAlgorithm":  "",
                                    "Params":  "-m 2 -i 19,29",
                                    "MSIAprofile":  "",
                                    "OCprofile": ""
                                }
                            ],
        "Sgminer-AMD":  [
                                {
                                    "MainAlgorithm":  "lyra2rev2",
                                    "SecondaryAlgorithm":  "",
                                    "Params":  "--gpu-threads 2 --worksize 128 --intensity d",
                                    "MSIAprofile":  "",
                                    "OCprofile": ""
                                },
                                {
                                    "MainAlgorithm":  "neoscrypt",
                                    "SecondaryAlgorithm":  "",
                                    "Params":  "--gpu-threads 1 --worksize 64 --intensity 15",
                                    "MSIAprofile":  "",
                                    "OCprofile": ""
                                }
                            ],
        "Trex":  [
                                {
                                    "MainAlgorithm":  "\*",
                                    "SecondaryAlgorithm":  "",
                                    "Params":  "",
                                    "MSIAprofile":  "",
                                    "Penalty": "12.5"
                                }
                            ]                                                                
    }

.. this adds extra command line parameters "-i 21" and "-m 2 -i 19,29" to
- "CcminerAlexis78-NVIDIA": miner CcminerAlexis78 in LegacyMining mode, mine on all selected nvidia GPU, Algorithms c11 and keccak
- "CcminerAlexis78-GTX1070": miner CcminerAlexis78 in non-LegacyMining mode on selected GPU devices with model name GTX1070, Algorithms c11 and keccak
- "CcminerAlexis78-GTX1070": miner will use custom overclocking profile "Profile1"
- "Sgminer-AMD": miner Sgminer in LegacyMining mode, mine on all selected amd GPU, Algorithms c11 and keccak
- "MainAlgorithm": alogrithm, for which the extra configuration will be used
- "SecondaryAlgorithm": secondary alogrithm, for which the extra configuration will be used (used for dual-mining Claymore, Excavator)
- "Params": these are the extra parameters, that will be added to the miner call
- "MSIAprofile": desired MSI Afterburner profile

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
          "DisableDualMining": "1",
          "DefaultOCprofile": "Profile1"
        }
      ]
    }

This configuration would:
- bind all GTX1050Ti in the system to Ethash and X16R mining, only, excluding the ClaymoreEthash miner
- setting the flag "DisableDualMining" to "1", all dual-algorithm miners will be removed from this device's list.
- for custom overclocking Profile1 is used as default for this GPU type


### Config\ocprofiles.config.txt

This file contains all custom overclocking profiles. These profiles can be assigned by name to miners in file Config\miners.config.txt, field "OCprofile".

Example:

    {
      "Profile1": {
        "PowerLimit": 80,
        "ThermalLimit": 0,
        "MemoryClockBoost": "*",
        "CoreClockBoost": "*",
        "LockVoltagePoint": "*"
      },
      "Profile2": {
        "PowerLimit": 0,
        "ThermalLimit": 0,
        "MemoryClockBoost": "400",
        "CoreClockBoost": "100",
        "LockVoltagePoint": "*"
      },
      "Profile3": {
        "PowerLimit": 0,
        "ThermalLimit": 0,
        "MemoryClockBoost": "200",
        "CoreClockBoost": "100",
        "LockVoltagePoint": "1000000"
      }
    }

- PowerLimit: in percent, set to 0, if you do not want this to be changed
- ThermalLimit: in °C, set to 0, if you do not want this to be changed
- MemoryClockBoost: in MHz, set to "*", if you do not want this to be changed
- CoreClockBoost: in MHz, set to "*", if you do not want this to be changed
- LockVoltagePoint: in µV set to "*", if you do not want this to be changed or "0", if voltagePoint should be unlocked


## CREDITS

The miner script has initially been forked from MultiPoolMiner, for my private use, only.
Since I changed and optimized the script a lot to suit my needs, I decided to make the source code public, so that others can profit from my optimizations.

**If you are happy with the script, bitcoin donations are greatly appreciated:**

**The RainbowMiner author**
  - BTC: 3P7pVVNpExuuHL9wjWKAo7jzQsb9ZziUFC
  - BCH: 1MGRzyaLjQ67ZwwL9QTbXzwLxa8x1qSTBD
  - ETH: 0x3084A8657ccF9d21575e5dD8357A2DEAf1904ef6

**The MultiPoolMiner author**
  - BTC: 1Q24z7gHPDbedkaWDTFqhMF8g7iHMehsCb
