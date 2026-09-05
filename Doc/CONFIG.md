# Configuration

RainbowMiner is configured from the running script (press [C] for the configuration setup)
and from the web interface (Config > Setup). Both write the same files, so there is normally
no need to edit anything by hand. This document is the complete reference of
`Config\config.txt`, the file that holds the general settings of a rig: wallet, worker name,
devices, algorithms, miners, pools, mining mode, networking, power price and all technical
switches.

Config files are in JSON format, so be careful when editing them by hand: every comma
counts. If you have not started RainbowMiner yet, there are no config files - start it once,
first.

The other configuration files are described in the [README](../README.md#advanced-configuration),
user pools in [USERPOOLS.md](USERPOOLS.md), custom miners in [CUSTOMMINERS.md](CUSTOMMINERS.md)
and the MiningRigRentals parameters in [MININGRIGRENTALS.md](MININGRIGRENTALS.md).

Contents

1. [Basic setup](#basic-setup)
2. [Select devices](#select-devices)
3. [Select algorithms](#select-algorithms)
4. [Select miners](#select-miners)
5. [Select pools](#select-pools)
6. [Select mining mode](#select-mining-mode)
7. [Setup network operations](#setup-network-operations)
8. [Set electricity cost handling](#set-electricity-cost-handling)
9. [Technical/Other](#technicalother)
   - [Timing and automatic restarts](#timing-and-automatic-restarts)
   - [Benchmarking](#benchmarking)
   - [Miner crashes and fault tolerance](#miner-crashes-and-fault-tolerance)
   - [Switching behaviour](#switching-behaviour)
   - [Internet and network](#internet-and-network)
   - [Overclocking](#overclocking)
   - [Linux](#linux)
   - [Processes, priorities and ports](#processes-priorities-and-ports)
   - [Start and pause behaviour](#start-and-pause-behaviour)
   - [Developer fee](#developer-fee)
10. [Maintenance](#maintenance)

The config file will contain variables to reflect default values. You can safely replace those variables with values.

An example:

    "StartPaused": "$StartPaused",
    "Interval": "$Interval",


## Basic setup

- **Wallet** = your general BTC wallet address
- **WorkerName** = your desired worker name
- **Currency** = currencies you want to be shown [default=BTC,USD,EUR]
- **Region** = your region, [default=US]
- **UIstyle** = set to "full" for complete listing, set to "lite" for reduced listing [default=full]
- **UIsorting** = set to "profit" in order to force UI sorting by profit, set to "biased" for internal biased profits [default=biased]
- **UIProfitColumns** = configure columns of miner profit tables in UI [default=Miner,Fee,Algorithm,Speed,Diff,Power,Profit,TTF,Accuracy,Pool,PoolFee,Wallet]
- **UIFullBenchmarkList** = Show non-extended benchmarks in minerlist [default=0]
- **APIPort** = enter a free web-interface port localhost:<port> [default=4000]
- **APIThreads** = Enter number of possible, parallel API threads (0=automatic, see notes) [default=0]
- **APIauth** = set to "1" for username/password auth on localhost [default=0]
- **APIuser** = enter a username for localhost accessibility
- **APIpassword** = enter a password for localhost accessibility
- **APIlockConfig** = set to "1" to lock config and disable save via API/localhost [default=0]
- **APImaxLoginAttemps** = Maximum number of failed login attempts, until IP gets blocked (0=turn off) [default=3]
- **APIblockLoginAttemptsTime** = Enter timespan, that an IP gets blocked, after the defined failed login attempts (units allowed, e.g. 1h=one hour, default unit is s=seconds) [default=30m]
- **APIallowIPs** = Restrict access to the API to specific IP addresses. Comma separated list of IPv4 or IPv6, wildcards (10.0.0.*) and CIDR (192.168.1.0/28, fe80::/10) allowed [default=]
- **EnableAutoUpdate** = set to 1 if you want RainbowMiner to be updated automatically [default=1]
- **EnableUpdateDuringPause** = set to 1 if you want RainbowMiner to be updated automatically, even if it is paused [default=1]
- **EnableUpdateWhenScheduled** = set to 1 if the automatic updates should be scheduled: set EnableUpdate to 1 for a schedule in scheduler.config.txt (also, EnableAutoUpdate must be set to 1) [default=0]
- **EnableAutoAlgorithmAdd** = set to 1 if Rainbowminer should add all newly added algorithms to your config.txt, during (automatic) update
- **EnableMinerStatus** = set to 1 to enable central monitoring
- **MinerStatusURL** = url to central monitoring server. It can also point at a monitoring of your own - the report format is documented in [REPORTAPI.md](REPORTAPI.md) [default=https://rbminer.net]
- **MinerStatusKey** = your unique miner status key (get one at https://rbminer.net, you can reuse MPM keys)
- **ShowRemoteMachines** = set to 1 to show other machines with the same Miner Status Key (may increase traffic if enabled on many machines). Set to 0 to disable, leave empty for show if is server only. [default=]
- **MinerStatusEmail** = if your miningrig goes offline at https://rbminer.net/monitoring, a warning will be sent to this email-address. Leave empty, if you do not want notifications.
- **PushOverUserKey** = if your miningrig goes offline at https://rbminer.net/monitoring, a notification will be sent via https://pushover.net, using your pushover user key. Leave empty, if you do not want this.
- **MinerStatusMaxTemp** = maximum allowed GPU temperature, triggers push message, if above [default=90]
- **MinerStatusMaxCrashesPerHour** = maximum allowed crashes per hour, triggers push message, if above [default=5]
- **DiskMinGB** = minimum free disk space in GB, triggers push message, if below [default=5]
- **MinFreeMemoryGB** = RAM in GB to keep free for the system and RainbowMiner. Algorithms with a known large memory footprint (the RandomX family needs a ~2GB dataset) are skipped on machines that cannot hold them in physical RAM, since the miner would otherwise allocate into the page file and stall. Set to 0 to disable the check [default=1.5]
- **GPUReservedVRAMGB** = VRAM in GB that the OS/driver reserves per GPU. This is subtracted from each GPU's memory before miners are matched against their minimum VRAM requirements. Leave empty for auto-detection: at every start, RainbowMiner reads the actual per-GPU usage via nvidia-smi (Windows/NVIDIA). Set to 0 to use the full VRAM, or enter a flat per-GPU reservation in GB [default=]

Notes for the automatic values for **APIThreads**:
- if the **RunMode** is set to "Server", the thread count will be set to the number of CPU threads (with a maximum of 8)
- otherwise, the thread count will be set to the number of CPU cores (with a maximum of 2)

## Select devices

- **DeviceName** = list of device descriptors, with which you want to mine [default=gpu]
  - click ListDevices.bat to find out which devices are available
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
- **ExcludeDeviceName** = list of device descriptors to exclude from mining (see DeviceName for explanation)
- **CPUMiningThreads** = enter the number of softwarethreads being used by CPU miners. Adds "-t [threads]" to commandline of cpuminer forks
- **CPUMiningAffinity** = enter a hex number to define CPU mining core affinity (e.g. 0xAAAA). Adds "--cpu-affinity [affinity]" to commandline of cpuminer forks
- **GPUMiningAffinity** = enter a hex number to define GPU miner's CPU core affinity for validating results (e.g. 0xAAAA). Especially useful, when mining CPU and GPU in parallel.
- **EnableAutoAdjustAffinity** = set to 1 to keep 1-2 threads free for the system, if *all* threads have been selected for CPU mining. It only acts on an affinity that covers every thread, so a hand-picked affinity is never touched [default=1]

If you defined CPUMiningThreads or CPUMiningAffinity, you may override the values for single miner, by adding your own "-t" and "--cpu-affinity" to the field Params in miners.config.txt. 
ClaymoreCPU, FireIce and JceminerCpu are not affected by these settings. They can be finetuned by editing config files (see section MINERS)

The affinity values define bitmasks, bit 0 = Core 0, bit 1 = Core 1, etc. The bitmasks are built from right to left.

Some examples:

    0 or 1 - 1 CPU/Core on or off.
    10 - Core/CPU 2 On, 1 Off.
    100 - Core/CPU 3 On, 1 and 2 off.
    101010 - Odd cores on, even off, 6 core.
    10101010 - Odd cores on, even off, 8 core.
    10101010101 - Even cores on, Odds off, 12 core.


To convert those binary 0/1 values into a hex number, you may use this [Bin/Hex Converter](https://www.rapidtables.com/convert/number/binary-to-hex.html).

On a CPU with hyperthreading/SMT the bits alternate: bit 0 is core 0 / thread 0, bit 1 is
core 0 / thread 1, bit 2 is core 1 / thread 0, and so on. So `0xFFFFF5` on a 12-core / 24-
thread CPU means `1111 1111 1111 1111 1111 0101` - everything on, except the second thread
of core 0 and of core 1.

Two practical rules:

- **leave one or two threads to the system.** With every thread mining, RainbowMiner can no
  longer read the miners' hashrates in time and starts reporting zero hashrates. Freeing the
  *second* thread of two cores usually costs less hashrate than freeing a whole core.
- **CPUMiningThreads follows the affinity.** RainbowMiner counts the bits of
  CPUMiningAffinity and uses that as the thread count, so the two can never contradict each
  other. Leave the affinity empty to let RainbowMiner build one from CPUMiningThreads.

## Select algorithms

- **Algorithm** = list of algorithms you want to mine [default=bitcore,blake2s,c11,cryptonightheavy,cryptonightv7,ethash,equihash,hmq1725,hsr,keccak,keccakc,lyra2re2,lyra2z,neoscrypt,pascal,phi,skein,skunk,timetravel,tribus,x16r,x16s,x17,vit,xevan,yescrypt,yescryptr16]
- **ExcludeAlgorithm** = list of algorithms you want to exclude from mining
- **ExcludeCoin** = list of coins you want to exclude from mining (by coin *name*)
- **ExcludeFromWatchdog** = list of algorithms or miner you want to exclude from the watchdog
- **DisableUnprofitableAlgolist** = set to "1" if you do not want to use the list of unprofitable algorithms, provided live by RainbowMiner. [default=0]
- **DisableUnprofitableCpuAlgolist** = set to "1" if you do not want to use the list of unprofitable CPU algorithms, provided live by RainbowMiner (if you want to mine some GPU algorithms on your CPU). [default=0]
- **EnableNeverProfitableAlgos** = set to "1" if you want to mine all possible algorithms, even those that are considered never profitable. This setting overrides DisableUnprofitableCpuAlgolist [default=0]

Hint: to switch a single coin off, prefer **ExcludeCoinSymbol** over **ExcludeCoin**. The
symbol is unambiguous, while the coin *name* is not spelled consistently across the pools.

Note: RainbowMiner uses two lists of unprofitable algorithms. The lists are both maintained actively online and updated every hour. Both lists are active, by default. This avoids running benchmarks for algorithms, that normally don't turn into good profit.

- **unprofitable.json** = contains mostly ASIC algorithms with very low GPU mining profitability. This list is also in use as emergency switch-off for coins/algorithms, for which the pools fail to provide valid numbers. This avoids mining to rogue coins/algorithms.
- **unprofitable-cpu.json** = contains mostly GPU algorithms, with very low CPU mining profitability. If you like and want to mine one of these algorithms on your CPU, set `"DisableUnprofitableCpuAlgolist": "1",` in config.txt. There is no drawback, just low profits :)


## Select miners

- **MinerName** = list of miner you want to use for mining (see directory Miners, without .ps1, e.g. CcminerAlexis78.ps1 -> CcminerAlexis78)
- **ExcludeMinerName** = list of miner names you want to exclude from mining
- **ExcludeMinersWithFee** = exclude all miners, that have a developer fee built-in [default=0]
- **PreferMinerName** = list of miner names that you prefer (see PreferMinerMargin)
- **PreferMinerMargin** = Choose one of your preferred miners, if it's hashrate is not lower than xx% of the top miner's (in percent) [default=5]
- **EnableCheckMiningConflict** = Enable conflict check if running CPU hungry GPU miners (for weak CPUs) [default=0]
- **EnableEthashZombieMode** = Enable Ethash mining with slower hashrate, even if the current DAG size doesn't fit into the GPU memory [default=0]
- **EnableMinersToSaveDAG** = Allow miners to save DAGs to disk (currently TTminer only), costs a lot of space but speeds up the startup [default=0]
- **DisableDualMining** = set to 1, if you want to disable all dual mining [default=0]
- **EnableDualMiningDuringRentals** = set to 1, if dual mining during rentals should be allowed [default=0]
- **DisableZeroWattMiners** = set to 1 to disable all miners that report 0-Watt [default=0]
- **IgnoreFees** = set to 1, if you do not want RainbowMiner to account the pool- and miner fees [default=0]
- **ShowMinerWindow** = show (1) or do not show (0) miner windows. Note: excavator will always run in an extra window [default=0]
- **FastestMinerOnly** = set to 1 to reduce list by only showing the fastest miner [default=1]
- **DisableExtendInterval** = during benchmark, some miners will run longer to find an accurate hashrate. Set to 1 to disable the extended times (this is not recommended, as it may result in inaccurate hashrates or cause some miners to fail) [default=0]

## Select pools

- **PoolName** = list of pool names you want to use for mining [default=nicehash,zpool]
- **ExcludePoolName** = list of pool names you want to exclude from mining
- **ShowPoolBalances** = set to 1 to let RainbowMiner show your current pool balances [default=1]
- **ShowPoolBalancesDetails** = set to 0 if coin balances at a pool should be added up to BTC [default=1]
- **ShowPoolBalancesExcludedPools** = set to 1 to let RainbowMiner try to fetch balances from not used pools in addition to the currently activated pools [default=0]
- **ExcludeCoinsymbolBalances** = Exclude coinsymbols from balances. Leave empty for none [default=MAX,MUSIC]
- **ShowWalletBalances** = set to 1 to let RainbowMiner fetch and show available wallet balances [default=1]
- **WalletBalances** = enter list of which coin's wallets should be listed. Leave empty for all [default=]
- **PoolDataWindow** = set global default for all pool data windows [default=estimate_current]
- **PoolStatAverage** = set global default for all pool moving average live price trend [default=Minute_10]
- **PoolStatAverageStable** = set global default for all pool moving average stable price trend [default=Week]
- **EnableErrorRatio** = Enable yiimp pool price auto-correction [default=1]
- **MaxErrorRatio** = Maximum error ratio for yiimp pool price auto-correction [default=1.5]

## Select mining mode

- **MiningMode** = possible values are "legacy", "device" and "combo", see explanation below
  - "legacy": one miner will handle all devices of one vendor together. Only NVIDIA, INTEL, AMD, CPU are possible to select.
  - "device" (default): each device group (e.g. GTX1070, RX570, CPU..) will get the most profitable miner to work on the different algorithm. If you have three different device groups, there will be three miners launched.
  - "combo": in addition to "device" mode, all possible combinations of device groups are taken into account. E.g. if all device types are considered most profitable for one specific miner, only one instance of the miner will be launched. Device types will only be combined for specific algorithm, if they have exactly equal params configured in miners.config.txt (the strings have to match). The combination of devices will be monitored separately: if the combo is less efficient than single miners, it will be deactivated automatically.
- **EnableResetVega** = set to 1 to always reset Vega Gpus before mining

## Setup network operations

- **RunMode** = possible values are "standalone", "server", "client"
  - "standalone": this mining rig will handle everything on it's own
  - "server": this mining rig will act as server in a multiple rig setup
  - "client": this mining rig will not create network traffic but pull the data from the server rig
  
For Client (Runmode=client) setup:

- **ServerName** = enter the server's machinename or ip
- **ServerPort** = enter the server's ports
- **ServerUser** = enter the server's username (if auth)
- **ServerPassword** = enter the server's password
- **EnableServerConfig** = set to "1" to use the server's config files on this rig
- **EnableServerPools** = set to "1" to use the server's pool/coins/balance statistics and mine exactly to those pools (except for MiningRigRentals)
  Note: With this setting, it is possible to let the server rig control pools/coins/balance data of the client. This reduces network traffic significantly, but overrides the local pool setup. MiningRigRentals is excluded - this pool always runs locally.
- **ServerConfigName** = list of config files to be downloaded if "EnableServerConfig" is set to "1". Possible values are "algorithms","coins","config","miners","ocprofiles","pools"
- **ExcludeServerConfigVars** = list of parameter names in config.txt or pools.config.txt, that should -not- be overwritten with server values (best is to leave it as is).
  For pools.config.txt:
  - `pools:<poolname>` = protect all values of pool "poolname"
  - `pools:<poolname>:<variablename>` = protect "variablename" in pool "poolname"
- **EnableServerExcludeList** = set to "1" to always use the server's "ExcludeServerConfigVars", instead of the local one in config.txt

For Server (Runmode=server) setup:

- make sure to set **APIport**, **APIauth**, **APIuser**, **APIpassword**, **APIallowIPs**


## Set electricity cost handling

- **PowerPrice** = price of 1 kWh (kilowatt-hour) that your electricity supplier charges [default=0]
- **PowerOffset** = power offset to allow consideration for overhead power [default=0]
- **OctopusTariffCode** = if you live in the UK and are an Octopus customer, you can let RainbowMiner pull the variable energy prices. Just enter your current tariff code. It's in the format E-1R-{product_code}-{region_code}, where product code is something like SILVER-2017-1, AGILE-18-02-21, ... and region code is a capital letter, range A to P
- **PowerPriceApi** = Connect RainbowMiner to a power price API like NodeRed. The API needs to return either a plain number or a JSON formatted string
- **PowerPriceApiValue** = Define where to find the power price value inside the JSON formatted string that the Power Price API returns. Use dot notation e.g. prices[1].value - if the API returns a plain number, leave this value empty (or set it to #)
- **PowerPriceApiInterval** = set to call-interval for PowerPriceApi or set it to 0 to use RainbowMiner's base interval
- **PowerPriceCurrency** = currency of your PowerPrice [default=USD]
- **FixedCostPerDay** = cumulative fixed costs per day (in power price currency) [default=0]
- **UsePowerPrice** = set to (1), if electricity cost and/or fixed cost should be subtracted from profits [default=0]
- **CheckProfitability** = if no more miners are profitable and this is set to (1), RainbowMiner will idle, until profitability returns. UsePowerPrice needs to be (1) and a PowerPrice greater than zero must be set for this function to work. [default=0]
- **ProfitabilityLevel** = profitability level in BTC in case CheckProfitability is set to 1 (e.g. -0.00002) [default=0]
- **EnableMiningHeatControl** =  set to (1), if the mining heat control should be enabled [default=0]
- **MiningHeatControl** =  set to a value 0..5 in steps of 0.1, to control heat over profit (2=default, 0=max.profit, 5=max.heat). A "PowerPrice" must be set for this function to work. [default=2]

  If "EnableMiningHeatControl" is enabled, the following formula is being used to calculate:

  `Heat value=revenue-miner fee-powercost*(3 - MiningHeatControl)`

  - "0" = min. heat
  - "2" = max. profit
  - "3" = max. revenue, best heat efficiency
  - "5" = max. heat

  A good start is to try values in the range of 2 to 3


## Technical/Other

### Timing and automatic restarts

- **Interval** = timing interval in seconds of RainbowMiner [default=60]
- **BenchmarkInterval** = timing interval in seconds, used for benchmarks [default=60]
- **RestartRBMTimespan** = restart RainbowMiner after a timespan, units allowed: m=minutes, h=hours, d=days, w=weeks, default is s=seconds, leave empty or set to 0 to disable [default=0]
- **RestartRBMMemory** = restart RainbowMiner if memory usage exceeds this value, units allowed, e.g. 1.2G = 1.2 Gigabytes, default is bytes, set to 0 to disable [default=16G]
- **MaxActivityDays** = set max. days for localhost's Activity history [default=2]

### Benchmarking

- **EnableFastlaneBenchmark** = set to 1 if you want to skip all benchmarks and download (very inaccurate) hashrate and powerdraw values from rbminer.net instead [default=0]
- **FastlaneBenchmarkTypeCPU** = if EnableFastlaneBenchmark="1": choose the value-set for CPU miners (avg, min or max) [default=avg]
- **FastlaneBenchmarkTypeGPU** = if EnableFastlaneBenchmark="1": choose the value-set for GPU miners (avg, min or max) [default=avg]
- **EnableFastlaneBenchmarkMissing** = if EnableFastlaneBenchmark="1": set to 1 if you want to benchmark all device/miners/algos not found on rbminer.net [default=1]
- **MaxCrashesDuringBenchmark** = maximum number of crashes allowed, until a benchmark fails [default=2]

### Miner crashes and fault tolerance

A miner that crashes or delivers bad shares is put on hold by the watchdog. With
**EnableAutoDisableMiners** a repeat offender is disabled permanently instead - it can be
switched on again on the **Miners** page of the web interface, or it returns by itself
after **AutoDisableResetHours**.

- **Watchdog** = use (1) or do not use (0) watchdog [default=1]
- **EnableAutoDisableMiners** = set to 1 to automatically disable a miner/algorithm after crashing MaxCrashesBeforeDisable times within CrashTrackingWindowMinutes (re-enable it manually on the web Miners page or wait AutoDisableResetHours) [default=0]
- **MaxCrashesBeforeDisable** = if EnableAutoDisableMiners="1": number of crashes within the tracking window, until a miner/algorithm gets disabled [default=5]
- **CrashTrackingWindowMinutes** = if EnableAutoDisableMiners="1": sliding window in minutes for counting miner crashes [default=60]
- **AutoDisableResetHours** = if EnableAutoDisableMiners="1": re-enable an auto-disabled miner/algorithm after this many hours, set to 0 to never re-enable automatically [default=24]
- **MinerFaultToleranceGPU** = set the GPU miner fault tolerance in % (10..100) [default=10]
- **MinerFaultToleranceCPU** = set the CPU miner fault tolerance in % (10..100) [default=25]
- **MaxRejectedShareRatio** = set max. allowed ratio "bad shares/found shares" until a miner gets disabled [default=0.3]

### Switching behaviour

Three settings control how eagerly RainbowMiner switches, and they work on different
levels: **SwitchingPrevention** delays a switch in general, **PoolSwitchingHysteresis**
asks for a minimum advantage before hopping from pool to pool (and can be overridden per
pool with `SwitchingHysteresis` in pools.config.txt), and **MinerSwitchingHysteresis**
does the same for miner-to-miner hopping on one pool. **EnableFastSwitching** removes all
of it at once. How the comparison price is calculated in detail, is explained in the FAQ
[The Profit Switcher Beast](../README.md#the-profit-switcher-beast).

- **MinimumMiningIntervals** = minimum number of intervals a miner will run, before switching will be allowed [default=1]
- **SwitchingPrevention** = finetune the switching prevention algorithm. Set to zero to disable [default=2]
- **PoolSwitchingHysteresis** = prevention of pool-to-pool hopping: the higher, the less switching (in %, 0 to disable, can be overwritten per pool) [default=3]
- **MinerSwitchingHysteresis** = prevention of on-pool miner-to-miner hopping: the higher, the less switching (in %, 0 to disable) [default=3]
- **EnableFastSwitching** = set to 1 to remove switching prevention completely. Expect a lot of switching [default=0]
- **Delay** = extra delay in seconds, between switching to avoid blue screen [default=0]
- **HashrateWeight** = adjust weight of pool hashrates on the profit comparison in % (0..100, 0=disable) [default=20]
- **HashrateWeightStrength** = adjust the strength of the weight (integer, 0=no weight, 100=linear, 200=square) [default=50]
- **PoolAccuracyWeight** = adjust weight of pool accuracy on the profit comparison in % (0..100, 0=disable) [default=15]
- **EnablePoolAlternates** = set to 1 to let a miner, that cannot use the most profitable pool of an algorithm, fall back to the best pool it can actually use (some miners only support an algorithm on certain pools) [default=1]
- **MaxPoolAlternates** = if EnablePoolAlternates: maximum number of alternate pools offered per algorithm (0=disable) [default=2]
- **MaxAllowedLuck** = if luck (= time_since_last_block / time_to_find_one_block) is greater than that number, increase the penalty up to 100% (0=disable, inactive for solo pools) [default=3]
- **MaxTimeSinceLastBlock** = if time_since_last_block is greater than that number, increase the penalty up to 100% (0=disable, time-units allowed in input, inactive for solo pools) [default=12h]
- **ProfitSpikeProtection** = prevent profit files to be updated, if the actual value is greater than the avg. profit x this factor (0 to disable) [default=0]

### Internet and network

- **SSL** = configure ssl usage: 0=prefer non-SSL over SSL pools, 1=prefer SSL over non-SSL pools, 2=use SSL pools only [default=0]
- **Proxy** = set your proxy address here, if you are using one
- **EnableCurl** = set to 1 to use cURL instead of the build-in web requests (enable this, if you get frequent "Asyncloader is crashed" warnings) [default=0]
- **UseTimeSync** = set to 1, if RainbowMiner should adjust the windows clock by rtp [default=1]
- **WebsitesForOnlineCheck** = list of websites, that RainbowMiner pings for testing the internet connection [default=www.google.com,www.amazon.com,www.baidu.com,www.coinbase.com,rbminer.net]
- **ExcludeCurrencyRateFromCoinbase** = Coinbase is the main currency provider, only if a symbol is not delivered from this API it will get called from api.rbminer.net. Sometimes there are false values due to ident symbols. Please leave as-is, since the RainbowMiner will update the defaults asap in case of false rates.
- **DisableInternetCheck** = set to 1, in case you get "Internet is down" messages, even if the internet is available [default=0]
- **DisableAsyncLoader** = set to 1, if all net access should happen synchronous (used for debugging)
- **DisableAPI** = set to 1, if no localhost API is needed
- **RemoteAPI** = set to 1 to enable accessibility of API within your network [default=0]
- **CovalentAPIKey** = enter your covalenthq.com API key (from [covalenthq.com](https://www.covalenthq.com/)) [default=]

  With a Covalent key, RainbowMiner can show the balance of a wallet that no pool reports -
  a token you are paid out in, for example. Enter the key here, then add the coin to
  `coins.config.txt` with its address in the `"Wallet"` field, and the balance appears under
  **Pool Earnings**. Note that `coins.config.txt` does **not** substitute variables, so the
  address has to be written out - `"Wallet": "$ETH"` does not work. Coins on a chain that
  Covalent does not cover need a public explorer with an API; some privacy coins offer no
  way to read a balance publicly at all.

### Overclocking

The two overclocking options and how to choose between them are described in
[OVERCLOCKING.md](OVERCLOCKING.md).

- **EnableOCProfiles** = set to 1, if you plan to use custom overclocking profiles [default=0]
- **EnableOCVoltage** = set to 1, if you plan to set voltage for overclocking [default=0]
- **EnableOCFullReset** = set to 1, to reset all possible overclocking settings (instead of the prior set values, only), when a miner is closed. [default=1]
- **EnableOCLinuxForcePState** = set to 1, to force all GPU into their workload powerstate to avoid crashes due to P2-P0 switching [default=1]
- **EnableOCLinuxSetAllPStates** = set to 1, to set mem/core clock offsets to all PStates, instead to the highest, only [default=0]
- **OCResetInterval** = set the interval to reset the overclocking settings of running miners, in seconds (0 to disable) [default=0]
- **MSIApath** = absolute windows path to MSI Afterburner executable [default=c:\Program Files (x86)\MSI Afterburner\MSIAfterburner.exe]
- **MSIAprofile** = default MSI Afterburner profile (1-5), set to 0 to disable [default=2]
- **NVSMIpath** = absolute windows path to Nvidia smi tools [default=c:\Program Files\NVIDIA Corporation\NVSMI]
- **DisableMSIAmonitor** = set to 1, to fully disable MSI Afterburner monitoring (if more than six AMD GPU are used for mining)
- **EthPillEnable** = set to "revA" or "revB" (read [Wiki](https://github.com/OhGodACompany/OhGodAnETHlargementPill/wiki) for more information on revA/revB), or "disable" to stop using the EthPill for Ethereum mining [default=disable]

### Linux

- **EnableLinuxMinerNiceness** = set to 1 to enable nice command for miners
- **LinuxMinerNiceness** = enter the level for miner niceness from -20 = least nice to 19 = super nice [default=19]
- **EnableLinuxHeadless** = if set to 1, miner-startscripts and overclocking-scripts will include DISPLAY+XAUTHORITY settings
- **LinuxDisplay** = default Linux DISPLAY for headless operation [default=:0]
- **LinuxXAuthority** = default Linux XAUTHORITY for headless operation (needed for overclocking). [default=RainbowMiner will guess]
- **LinuxMinerTerminal** = select the session handler RainbowMiner will use to start the miners in the background, choose screen, tmux or auto [default=auto]
- **EnableMinersAsRoot** = set to 0, if you do not want to run miners as root, using the OCDaemon (linux only) [default=1]

### Processes, priorities and ports

- **MiningPriorityCPU** = process priority for CPU miners (-2..2) [default=-2]
- **MiningPriorityGPU** = process priority for GPU miners (-2..2) [default=-1]
- **AutoexecPriority** = process priority for commands started via autoexec.txt (-2..2) [default=0]
- **EnableAutoMinerPorts** = set to 1, if miners get into conflict with the ports in use
- **StaticCPUMinerPort** = enter a static API port number for all CPU miners (0=use default ports) [default=0]
- **StaticGPUMinerPort** = enter a static API port number for all GPU miners (0=use default ports) [default=0]
- **OpenCLPlatformSorting** = define sort order of the OpenCL platforms, comma separated list. Valid values are AMD,INTEL,NVIDIA. Leave empty for automatic detection (recommended) [default=]
- **EnableRandomX1GBPages** = set to "1" to allow miners to enable 1GB Pages for RandomX like algorithms (currently SrbMinerMulti only, see issue #3158)

### Start and pause behaviour

- **Quickstart** = set to 1 to read all pool data from cache during startup (speeds up first start, but balance data may be out of date)
- **StartPaused** = set to 1 to start RainbowMiner in pause mode (no mining, you will have to press "P" to enable mining)
- **EnablePauseOnActivity** = set to 1 to automatically send RainbowMiner into pause mode, if user input is detected (also see **ResumeOnInactivitySeconds**) [default=0]
- **EnablePauseOnBattery** = set to 1 to automatically send RainbowMiner into pause mode, if notebook runs on battery (Windows only) [default=0]
- **ResumeOnInactivitySeconds** = seconds of no user input, until RainbowMiner leaves pause-on-activity mode (0 = never) [default=300]

### Developer fee

- **Donate** = set the minutes, you want RainbowMiner to work for the developer (min. is 10 minutes, equals to 0.7%) [default=24]

This is the only fee RainbowMiner takes, and it is a share of *time*, not of your earnings:
for the configured number of minutes per 24 hours, the rig mines to the developer's pools.
The minimum of 10 minutes equals 0.7% of a day.

Two things keep it fair: a donation round never starts before all benchmarks have finished,
and the time already spent is stored, so a restart, an update or a crash cannot make a rig
donate more than the configured minutes per 24 hours.

## Maintenance

- **MaxLogfileDays** = max. days to keep logfiles in Logs folder [default=5]
- **MaxDownloadfileDays** = max. days to keep downloaded files in Downloads folder [default=14]
- **MaxCachefileDays** = max. days to keep cache files in Cache folder [default=14]
- **EnableMinerBackups** = keep backups of updated miners in Bin folder, set to 0, if you have limited space [default=1]
- **EnableKeepDownloads** = keep downloaded miners in Downloads folder, set to 0, if you have limited space [default=1]

**Notes for HashrateWeight**

The comparison prices of the pools will be scaled with the following formula:

    compare price = price x (1-(HashrateWeight/100)x(1-(rel. hashrate)^(HashrateWeightStrength/100))
