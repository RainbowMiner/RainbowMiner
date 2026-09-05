# MiningRigRentals

At [MiningRigRentals](https://www.miningrigrentals.com?ref=2598069) you rent your rig out to
other miners, who pay in BTC for a fixed amount of hashing time. RainbowMiner supports this
as a pool: it keeps your rigs online, detects a rental the moment it starts, runs the rented
algorithm exclusively for its duration and returns to normal profit switching afterwards.
Prices, minimum rental times, titles and descriptions can be maintained by RainbowMiner
automatically, and rigs can even be created on MiningRigRentals on their own.

Contents

1. [Signup and create a rig for rent](#1-signup-and-create-a-rig-for-rent)
2. [Setup RainbowMiner](#2-setup-rainbowminer)
3. [Substitution variables for StartMessage and DiffMessage](#substitution-variables-for-startmessage-and-diffmessage)
4. [Hints](#hints)
5. [Remark](#remark)

The parameters below live in the MiningRigRentals section of `Config\pools.config.txt`. Two
more files refine them: `Config\mrr.config.txt` overrides them per worker name and
`Config\mrralgorithms.config.txt` per algorithm - both are described in the
[README](../README.md#configmrrconfigtxt).

Every rig you offer at MiningRigRentals is one worker name, and RainbowMiner creates them for
you: your `WorkerName` from config.txt for the GPUs, the same name with `cpu` appended for the
CPU, plus one for every device group that has its own `"Worker"` in `devices.config.txt`. Each
of them gets a section in `mrr.config.txt`, and what is set there beats `pools.config.txt`.
Use `"UseWorkerName"` and `"ExcludeWorkerName"` to decide which of them are offered at all -
that is how you rent out the GPUs but keep the CPU on normal profit switching, or the other
way round.

Changes to the config files are picked up while RainbowMiner runs, so a rental in progress
follows a changed setting without a restart.

To stop renting without cutting a running rental short, remove `MiningRigRentals` from
`PoolName` in config.txt: the current rental finishes normally and no new one is offered. The
alternative is a very large `"PauseBetweenRentals"` (e.g. `"3650 day"`), which disables the
rigs after the rental instead of deleting them.

## 1. Signup and create a rig for rent

- signup at [https://www.miningrigrentals.com](https://www.miningrigrentals.com/register?ref=2598069)
- create API keys with permission "Balance/Withdraw" = "Read-Only" and "Manage Rigs" = "Yes" (Hint: if you have multiple RainbowMiner rigs, create new keys for each of them!)
- create a rig for at least one algorithm that you want to rent to an interested renter at the "MyRigs" section of the website
- optional: add pools on the "Pool Configuration" tab of the rig
- set your rig's rentable status to "available"
- edit your rig's description and add your RainbowMiner workername, enclosed with square brackets, somewhere into the text, e.g. ``[rbm]``. This is important, otherwise Rainbowminer will not find your rig, later.

## 2. Setup Rainbowminer

- add "MiningRigRentals" to the PoolName list and make sure it is not in the ExcludePoolName list (config.txt or [C]onfiguration->[S]elections)
- edit "Config\pools.config.txt", find the MiningRigRentals section and add (API_Secret, User) or edit the following data:

      "API_Key": "<put your MiningRigRentals API-key here>",
      "API_Secret": "<put your MiningRigRentals API-secret key here>",
      "User": "<put your MiningRigRentals username here>",
      "Worker": "<put your RainbowMiner workername here or leave $WorkerName>",
      "EnableMining": "0",


All rigs will be automatically set to status "online", at [MiningRigRentals](https://www.miningrigrentals.com?ref=2598069) and rest idle within RainbowMiner. If someone starts a rental, RainbowMiner will detect this and run the respective miner exclusively, until the rental ends. All other rigs on [MiningRigRentals](https://www.miningrigrentals.com?ref=2598069) will be deactivated, for that time.

If you want to include [MiningRigRentals](https://www.miningrigrentals.com?ref=2598069) into RainbowMiner's profitability checks and switching operation, so that it behaves just like a normal pool, set "EnableMining" to "1". Only do this, if [MiningRigRentals](https://www.miningrigrentals.com?ref=2598069) is your only pool, because the mining prices (these are the prices setup at [MiningRigRentals](https://www.miningrigrentals.com?ref=2598069)), will not reflect the real market prices.

RainbowMiner can create and update your MRR rigs fully automatic!

The following are the pool parameters:

- **User**: Enter your MiningRigRentals username [default=]
- **API_Key**: Enter your MiningRigRentals API key [default=]
- **API_Secret**: Enter your MiningRigRentals API secret key [default=]
- **UseWorkerName**: Enter list of workernames that should be explicitly used for MRR (leave empty for all) [default=]
- **ExcludeWorkerName**: Enter list of workernames that should be explicitly excluded from the use with MRR (leave empty for none) [default=]
- **EnableMining**: Enable switching to MiningRigRentals, even if it is not rented (not recommended) [default=0]
- **EnableMaintenanceMode**: Set to "1" if you are planning to shut down your rig for any reason (e.g. maintenance). RainbowMiner will then disable all unrented rigs, until you reset the parameter back to "0" [default=0]
- **EnableAutoCreate**: Automatically create MRR-rigs [default=0]
- **EnableAutoUpdate**: Automatically update MRR-rigs [default=0]
- **EnableAutoExtend**: Automatically extend MRR rentals, when low average hashrate [default=0]
- **EnableAutoExtendDifficultyCheck**: Enable check for renter pool difficulty. Only extend rental if difficulty is inside the set range [default=0]
- **EnableAutoBenchmark**: Enable automatic benchmark of updated miners (it will mine to your wallets only, during benchmark), select the mode with AutoBenchmarkMode [default=0]
- **AutoBenchmarkMode**: Select mode for auto-benchmark, "all" benchmarks all algorithms, "updated" benchmarks only updated algorithms of an updated miner [default=updated]
- **AutoExtendTargetPercent**: Extend rentals time, so that the total average hashrate is near this value in percent of advertised hashrate [default=100]
- **AutoExtendMaximumPercent**: Extend rentals maximum to this value in percent of the rental time [default=100]
- **AutoBonusExtendForHours**: Enter amount of hours, that you want to reward with an automatic bonus extension (e.g. 24) [default=0]
- **AutoBonusExtendByHours**: Enter bonus extension in hours per each fully rented AutoBonusExtendForHours (e.g. 1) [default=0]
- **AutoBonusExtendTimes**: Limit the maximum extensions by AutoBonusExtendByHours to a specific number of times (e.g. 1), 0=unlimited [default=0]
- **AutoCreateMinProfitPercent**: Enter minimum profitability in percent compared to current best profit, for full rigs to be autocreated on MRR [default=50]
- **AutoCreateMinCPUProfitBTC**: Enter minimum one-day revenue in BTC, for a CPU-only rig to be autocreated on MRR [default=0.00001]
- **AutoCreateMaxMinHours**: Enter the maximum hours for minimum rental time, for a rig to be autocreated on MRR [default=24]
- **AutoCreateAlgorithm**: Algorithms that should always be autocreated on MRR, even if below the other limits [default=]
- **AutoUpdateMinPriceChangePercent**: Enter minimum price change in percent, for a rig's price to be updated on MRR [default=3]
- **EnableAutoPrice**: Enable MRR automatic prices [default=1]
- **EnableMinimumPrice**: Set MRR automatic minimum price [default=1]
- **EnableAutoAdjustMinHours**: Automatically adjust minimum rental time (up to MaxMinHours), to satisfy the min. profit of 0.00001 BTC [default=1]
- **EnableUpdateTitle**: Enable automatic updating of rig titles (disable, if you prefer to edit your rig titles online at MRR) [default=1]
- **EnableUpdateDescription**: Enable automatic updating of rig descriptions (disable, if you prefer to edit your rig descriptions online at MRR) [default=1]
- **EnableUpdatePriceModifier**: Enable automatic update of price modifier (disable, if you prefer to edit your modifiers online at MRR). Can be set globally in pools.config.txt (parameter **AutoPriceModifierPercent**) and specific for each algorithm in algorithms.config.txt (parameter **MRRPriceModifierPercent**) [default=0]
- **AutoPriceModifierPercent**: Autoprice modifier in percent (e.g. +10 will increase all suggested prices by 10%, valid range is -30 .. 30) [default=0]
- **UpdateInterval"*: Enter the interval time for create and update rigs on MRR (in seconds, verbose allowed, e.g. 1.5h = 1.5 hours, 30m = 30 minutes) [default=1h]
- **PriceBTC**: Fixed price in BTC (used, if EnableAutoPrice=0 or if the value is greater than the PriceFactor x revenue) [default=0]
- **PriceFactor**: Enter profit multiplicator: minimum price = rig's average revenue x this multiplicator [default=1.8]
- **PriceFactorMin**: Minimum profit multiplicator (only of use, if PriceFactorDecayPercent is greater than 0) [default=1.2]
- **PriceFactorDecayPercent**: Enter percentage for decay of the profit multiplicator over time (0 = disable) [default=0]
- **PriceFactorDecayTime**: Enter the profit multiplicator decay interval (in seconds, verbose allowed, e.g. 1.5h = 1.5 hours, 30m = 30 minutes) [default=4h]
- **PriceRiseExtensionPercent**: Enter price rise for extensions of a rental (in percent, e.g. 10 means 10% price rise) [default=0]
- **PowerDrawFactor**: Enter powerdraw multiplicator (only if UsePowerPrice is enabled): minimum price = minimum price + (miner's power draw - rig's average power draw) x 24 / 1000 x powerdrawprice x this multiplicator [default=1.0]
- **EnablePowerDrawAddOnly**: Add the powerdraw cost difference only, if it is greater than 0 [default=0]
- **MinHours**: Minimum rental time in hours (min. 3) [default=3]
- **MaxHours**: Maximum rental time in hours (min. 3) [default=168]
- **MaxMinHours**: Upper limit for auto-adjust minimum rental time, if EnableAutoAdjustMinHours is set to 1 [default=24]
- **AllowExtensions**: Allow renters to buy extensions for their rentals [default=1]
- **AllowRentalDuringPause**: Allow rentals, even if the mining rig is in pause mode [default=0]
- **PriceCurrencies**: List of accepted currencies (must contain BTC) [default=BTC]
- **Title**: Title for autocreate, make sure it contains %algorithm% or %algorithmex% or %display%, and %rigid% (values will be substituted like that: %algorithm% with algorithm, %algorithmex% with algorithm plus coin info if needed, %coininfo% with eventual coin info, %display% with MRR specific display title, %rigid% with a unique rigid, %workername% with the workername, %type% with either CPU or GPU, %typecpu% with CPU or empty, %typegpu% with GPU or empty) [default=%algorithmex% mining with RainbowMiner rig %rigid%]
- **Description**: Description for autocreate, %workername% will be substituted with rig's workername. Make sure you add [%workername%] (including the square brackets!) [default=Autostart mining with RainbowMiner (https://rbminer.net) on Windows. This rig is idle and will activate itself, as soon, as you rent it. [%workername%]]
- **StartMessage**: Message, that will be sent to the renter at the start of the rental. See below for possible substitution variables.
- **ExtensionMessageTime**: Send the ExtensionMessage to the renter, when the remaining rental time drops below this value (in seconds, verbose allowed, e.g. 1.5h = 1.5 hours, 30m = 30 minutes, set to 0 or empty to disable) [default=2h]
- **ExtensionMessage**: Message, that will be sent to the renter, when remaining rental time drops below ExtensionMessageTime
- **DiffMessageTime**: Send the DiffMessage to the renter, when the current difficulty stays out of the optimum difficulty for this time (in seconds, verbose allowed, e.g. 1.5h = 1.5 hours, 30m = 30 minutes, set to 0 or empty to disable) [default=15m]
- **DiffMessageTolerancyPercent**: Allowed tolerance above the maximum and below the minimum of the optimum difficulty (in percent, e.g. 15 means 15%) [default=15]
- **DiffMessage**: Message, that will be sent to the renter, if the current difficulty stays out of the optimum difficulty for DiffMessageTime. See below for possible substitution variables.
- **PoolOfflineTime**: time a renter's pools has to be offline, until it is temporary disabled and the pool offline message is sent (in seconds, verbose allowed, e.g. 1.5h = 1.5 hours, 30m = 30 minutes) [default=3m]
- **PoolOfflineRetryTime**: time after which we will retry to connect to a disabled renter's pool (in seconds, verbose allowed, e.g. 1.5h = 1.5 hours, 30m = 30 minutes) [default=15m]
- **PoolOfflineMessage**: Message, that will be sent to the renter, after a renter's pool has been offline for PoolOfflineTime
- **ProfitAverageTime**: Enter the device profit moving average time period (Minute,Minute_5,Minute_10,Hour,Day,ThreeDay,Week), [default=Day]
- **PauseBetweenRentals**: Disable rigs on MRR after a rental for some time (in seconds, verbose allowed, e.g. 1.5h = 1.5 hours, 30m = 30 minutes) [default=10m]
- **EnableRecoveryMode**: if you have orphaned rigs due to empty description or if you have unintentionally removed the [%workername%] tag, set this to "1" and RainbowMiner will try to match all orphaned rigs to the unique rig titles and eventually recover the description. Since the recovery mode adds another pretty lengthy API call, make sure to disable (set "EnableRecoveryMode" to "0"), after all rigs have been recovered. [default=0]

### Substitution variables for StartMessage and DiffMessage
- %Algorithm%      = normalized algorithm name
- %Type%           = Miningrigrental's algorithm name
- %Coin%           = coin symbol, if applicable
- %MinDiff%        = optimum minimum difficulty
- %MaxDiff%        = optimum maximum difficulty
- %CurrentDiff%    = current difficulty (only DiffMessage)
- %MinDiffFmt%     = formatted* optimum minimum difficulty
- %MaxDiffFmt%     = formatted* optimum maximum difficulty
- %CurrentDiffFmt% = formatted* current difficulty (only DiffMessage)

* %...fmt% will format numbers like that: 0.035 -> 35m, 120,000 -> 120k, 53,100,000 -> 53.1M

### Hints

- set `"EnableAutoUpdate": "1",`, to enable automatic updates of price/hash and minhours
- set `"EnableAutoCreate": "1",`, to enable automatic creation of profitable rigs on MRR
- the MRR suggested prices will be enabled, if `"EnableAutoPrice": "1",`
- the MRR adjust % value is set by `"AutoPriceModifierPercent": "-10",`, (in this example it's -10%)
- extensions can be (dis-)allowed per algorithm in algorithms.config.txt `"MRRAllowExtensions": "0",` (leave empty for the default in pools.config.txt)
- the price adjust % can be set per algorithm in algorithms.config.txt `"MRRPriceModifierPercent": "-10",`
- the MRR minimum price will be automatically set, if `"EnableMinimumPrice": "1",` (recommended!)
- if MRR suggested prices are disabled (`"EnableAutoPrice": "0",`)
  - either the rig's price will set to your rig's average profit x `"PriceFactor"`
  - or the rig's price will be set to `"PriceBTC"`, if it is greater than 0
- if MRR suggested prices are enabled (`"EnableAutoPrice": "1",`)
  - either the rig's minimum price will be set to your rig's average profit x `"PriceFactor"`
  - or the rig's minimum price will be set to `"PriceBTC"`, if it is greater than your rig's average profit x `"PriceFactor"`

### Remark

- to (dis-)allow the CPU rigs: add `<yourrigworkername>cpu`, e.g. if your workername is "RainbowMiner", use "RainbowMinercpu"
- to (dis-)allow the all-GPU rig: add `<yourrigworkername>`, e.g. if your workername is "RainbowMiner", use it :)
- to (dis-)allow device groups: add the workername(s), that you have given your device groups in devices.config.txt (parameter `"Worker"`)
- to avoid miners crashing at the end of a rental, the MRR pools will be preset with my default donation pools. These will be used for some seconds at the end of the rentals, when the renter's pool finally goes offline, before the current RainbowMiner round is finished. You may change these to your likes, or leave them like they are and support my work with some seconds of your rig's time.
