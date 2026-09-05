# Config\pools.config.txt

Every pool has its own section in `Config\pools.config.txt`. It holds the wallets, the
worker name and everything that should be handled differently for this one pool: which
coins and algorithms to take from it, a penalty for a pool that exaggerates its numbers, the
data window and the moving average of its prices, the switching hysteresis and the region of
its stratum.

The file is written by the configuration setup ([C]onfiguration->[P]ools) and by the **Setup
Pools** page of the web interface, so there is normally no need to edit it by hand. What the
individual pools expect as a wallet or as a username, is listed in [POOLS.md](POOLS.md).

Contents

1. [Change payout currency of a pool / add more wallets](#change-payout-currency-of-a-pool--add-more-wallets-eg-ravenminer-uses-rvn)
2. [Add additional password parameters for YiiMP based pools](#add-additional-password-parameters-for-yiimp-based-pools)
3. [Change a pool's penalty](#change-a-pools-penalty)
4. [Override default dynamic penalties](#override-default-dynamic-penalties)
5. [Change a pool's time frame (data window)](#change-a-pools-time-frame-data-window)
6. [Change a pool's moving average](#change-a-pools-moving-average-stat-average-for-live-and-stable-price)
7. [Define the Algorithms and Coins of a pool](#define-the-algorithms-and-coins-of-a-pool)
8. [Force mining to a pool's wallet](#force-mining-to-a-pools-wallet)
9. [Allow mining algorithm when pool hashrate equals to 0](#allow-mining-algorithm-when-pool-hashrate-equals-to-0)
10. [Change switching prevention](#change-switching-prevention)
11. [Force a specific region's stratum](#force-a-specific-regions-stratum)

Each pool has it's own section, in the pools.config.txt

## Change payout currency of a pool / add more wallets (e.g. Ravenminer uses RVN)

The default pool config look like this:

    "Zpool": {
        "BTC": "$Wallet",
        "Worker": "$WorkerName",
        "Penalty": "0"
    }


The line "BTC": "$Wallet" defines the payout wallet address. $Wallet uses the value in your config.txt, $<CURRENCY> uses the value, defined for the corresponding currency in coins.config.txt
If you want to change it to LTC, for example, you have to change this line like this:

    "Zpool": {
        "LTC": "<YOUR_LITECOIN_ADDRESS>",
        "Worker": "$WorkerName",
        "Penalty": "0"
    }


Or like this, if you setup a global wallet address in coins.config.txt

    "Zpool": {
        "LTC": "$LTC",
        "Worker": "$WorkerName",
        "Penalty": "0"
    }


For non-autoexchange pools, you may define multiple wallets. The wallets define, which coins may be mined at a pool. In the following example, Rainbowminer will mine RVN and SUQA on Icemining, hereby using the default RVN wallet in the coins.config.txt.

    "Icemining": {
        "RVN": "$RVN",
        "SUQA": "<YOUR_SUQA_ADDRESS>",
        "Worker": "$WorkerName",
        "Penalty": "0"
    }

Alternatively you may instruct RainbowMiner to automatically use every currency defined in coins.config.txt (which is enabled by adding a wallet address and setting parameter "EnableAutoPool" to "1") for a certain pool. To do so, set parameter "EnableAutoCoin" to "1".
Example:

    "Icemining": {
        "Worker": "$WorkerName",
        "Penalty": 0,
        "EnableAutoCoin": "1"
    }

## Choose the auto-exchange currency

At an auto-exchange pool, the currency you get paid in is the currency of the wallet entry.
There are two ways to change it:

- replace the wallet entry, e.g. change `"BTC": "$Wallet",` to `"ETH": "$ETH",`
- or keep several wallet entries and pick one with the `"AECurrency"` parameter. That way you
  can switch the payout currency without editing wallets:

```
    "Zpool": {
        "BTC": "$Wallet",
        "ETH": "$ETH",
        "LTC": "$LTC",
        "AECurrency": "ETH",
        "Worker": "$WorkerName"
    }
```

## Add additional password parameters for YiiMP based pools

Many of our pools are based on the open-source YiiMP pool (e.g. Hashcryptos,ZPool etc.). Some of these pools accept additional parameters. To add a password parameter, add one line to pools.config.txt in the form `"CURRENCY-Params": "parameters",`. In fact, all parameters will be added to the preset password contents, using a comma.

Example:

    "Zpool": {
        "LTC": "<YOUR_LTC_ADDRESS>",
        "LTC-Params": "m=solo",
        "Worker": "$WorkerName",
        "Penalty": "0"
    }

In this example, if mining Zpool, it will autoexchange everything into LTC. The parameter string "m=solo" will be added to the password, that is passed to the pool.

There are two forms of this field:

- `"<PAYOUTCOIN>-Params"` applies to every coin and algorithm mined at that pool
- `"<PAYOUTCOIN>-<MININGCOIN>-Params"` applies only while that one coin is being mined

So if your payout coin is LTC and you want a personal payout threshold for everything, use
`"LTC-Params": "pl=0.5",` - and if it should only apply while mining INN, use
`"LTC-INN-Params": "pl=0.5",`. Whatever you put in is comma-concatenated to the password
that RainbowMiner passes to the pool.

## Change a pool's penalty
    
If you feel like a pool tends to exaggerate it's results, you can set a penalty in % through the field "Penalty":

    "Ravenminer": {
        "RVN": "<YOUR_RAVENCOIN_ADDRESS>",
        "Worker": "$WorkerName",
        "Penalty": "5"
    }

This would reduce the hashrate-results from the pool Ravenminer by 5%

## Override default dynamic penalties

All pool's penalties will be adjusted upwards, if either the current luck is greater than "MaxAllowedLuck" or the actual time to find a block is greater than "MaxTimeSinceLastBlock". Both values are defined in the global config.txt.
If you want to override the defaults for a specific pool, give the corresponding parameters a value.

    "Zpool": {
        "BTC": "<YOUR_BTC_ADDRESS>",
        "Worker": "$WorkerName",
        "MaxAllowedLuck": "2",
        "MaxTimeSinceLastBlock": "2h"
    }

This would set the MaxAllowedLuck to 2 (=200% luck) and 2h (=7200 seconds).
Leaving the parameter(s) empty (as ""), will have this pool using the default values in config.txt
Set the parameter(s) to "0", to disable the feature(s) for that pool.

## Change a pool's time frame (data window)

To override the default data window "average2e" of the YiiMP based pools (Hashcryptos,Zpool) the parameter "DataWindow" can be added to the pool's configuration record. 
Possible values are:

- estimate_current (=default): the pool's current calculated profitability-estimation (more switching, relies on the honesty of the pool)
- estimate_last24h: the pool's calculated profitability-estimation for the past 24 hours (less switching, relies on the honesty of the pool)
- actual_last24h: the actual profitability over the past 24 hours (less switching)
- minimum2: the minimum value of estimate_current and actual_last24h will be used
- maximum2: the maximum value of estimate_current and actual_last24h will be used
- average2: the calculated average of estimate_current and actual_last24h will be used
- minimum2e: the minimum value of estimate_current and estimate_last24h will be used
- maximum2e: the maximum value of estimate_current and estimate_last24h will be used
- average2e: the calculated average of estimate_current and estimate_last24h will be used
- minimum2h: the minimum value of estimate_last24h and actual_last24h will be used
- maximum2h: the maximum value of estimate_last24h and actual_last24h will be used
- average2h: the calculated average of estimate_last24h and actual_last24h will be used
- minimum3: the minimum value of the above three values will be used
- maximum3: the maximum value of the above three values will be used
- average3: the calculated average of the above three values will be used
    
Example:

    "Zpool": {
        "LTC": "<YOUR_LITECOIN_ADDRESS>",
        "Worker": "$WorkerName",
        "Penalty": "0",
        "DataWindow": "minimum3"
    }


## Change a pool's moving average (stat average for live and stable price)

The price pulled from the pool's API is being averaged down with a defined moving average trend line.
The averaging time can be defined:

- for live price: using the parameter "StatAverage". It overrides the global default set by the config.txt parameter "PoolStatAverage" [default=Minute_10]
- for stable price: using the parameter "StatAverageStable". It overrides the global default set by the config.txt parameter "PoolStatAverageStable" [default=Week]

Possible values are:

- Live: the live price
- Minute_5: five minutes moving average
- Minute_10: ten minutes moving average
- Hour: one hour moving average
- Day: one day moving average
- ThreeDay: three day moving average
- Week: one week moving average

Example:

    "Zpool": {
        "LTC": "<YOUR_LITECOIN_ADDRESS>",
        "Worker": "$WorkerName",
        "Penalty": "0",
        "DataWindow": "minimum3",
        "StatAverage": "Hour",
        "StatAverageStable": "ThreeDay"
    }


## Define the Algorithms and Coins of a pool
    
Per default all algorithms of a pool will be used. To define your own set of algorithm, there are two additional fields:

- Algorithm: a comma separated list of all pool's algorithm you want RainbowMiner to use (leave empty for all)
- ExcludeAlgorithm: a comma separated list of all pool's algorithm you explicitly do not want RainbowMiner to use (leave empty for no exception)
- CoinName: a comma separated list of coin names you want RainbowMiner to use (leave empty for all). The coin's name must be spelled exactly like it is used at the corresponding pool. It applies to the pools, that transmit the coin names, only.
- ExcludeCoin: a comma separated list of coin names you explicitly do not want RainbowMiner to use (leave empty for all coins). The coin's name must be spelled exactly like it is used at the corresponding pool. It applies to the pools, that transmit the coin names, only.
- CoinSymbol: a comma separated list of coin symbols you want RainbowMiner to use (leave empty for all). Better alternative to "CoinName"
- ExcludeCoinSymbol: a comma separated list of coin symbols you explicitly do not want RainbowMiner to use (leave empty for no exception). Better alternative to "ExcludeCoin"
- EnablePostBlockMining: set to "1" to allow forced mining a specific currency for a timespan (defined in coins.config.txt), after a block has been found.
- CoinSymbolPBM: if EnablePostBlockMining is set to "1", specify which currency is taken into account for post block mining. Leave empty for all.

Example:

    "Zpool": {
        "User": "$UserName",
        "Worker": "$WorkerName",
        "Algorithm": "lyra2z,skein,myriadgroestl,groestl,neoscrypt,equihash-btg",
        "ExcludeAlgorithm": "",
        "CoinName": "",
        "ExcludeCoin": "",
        "CoinSymbol": "",
        "ExcludeCoinSymbol": "BTG,XTC",
        "FocusWallet": "",
        "EnablePostBlockMining": "0",
        "CoinSymbolPBM": ""
    }

## Force mining to a pool's wallet

To force mining to pool's wallets, you may add the wallet's currencies to field "FocusWallet". RainbowMiner will mine into the focused pool/wallets, only.

Example:

    "Nanopool": {
        "ETC": "0x012031012301230123012301230",
        "ERG": "$ERG",
        "User": "$UserName",
        "Worker": "$WorkerName",
        "Algorithm": "",
        "ExcludeAlgorithm": "",
        "CoinName": "",
        "ExcludeCoin": "",
        "CoinSymbol": "",
        "ExcludeCoinSymbol": "",
        "FocusWallet": "ETC,ERG"
    }

This example will focus mining operations to pool Nanopool, comparing this pool's profitability of ETC and ERG, only. No other pool will be mined.

## Allow mining algorithm when pool hashrate equals to 0

All pool modules contain a check for an algorithm hashrate to be greater than 0. If you want to mine a special currency, even if you are the only miner (e.g. solo mining on GosxSolo), set field "AllowZero" to "1":

Example:

    "GosxSolo": {
        "SUQA": "<YOUR_SUQA_ADDRESS>",
        "Worker": "$WorkerName",
        "FocusWallet": "SUQA",
        "AllowZero": "1"
    }

## Change switching prevention

To avoid rapid pool-to-pool hopping, the global config.txt parameter "PoolSwitchingHysteresis" can already be set.
If needed, the global value can be overwritten with the pools.config.txt parameter "SwitchingHysteresis".
Set it to a value of `"0"`-`"100"` or leave it empty `""` to use the global "PoolSwitchingHysteresis"

Example:

    "Zpool": {
        "BTC": "<YOUR_BTC_ADDRESS>",
        "Worker": "$WorkerName",
        "SwitchingHysteresis": "5"
    },
    "MiningDutch": {
        "BTC": "<YOUR_BTC_ADDRESS>",
        "Worker": "$WorkerName",
        "SwitchingHysteresis": "0"
    }


In this example, the switching hysteresis would be set to 5% (another pool with the same algorithm would need at least a 5% higher price to be accepted) and switched off completely for MiningDutch.

## Force a specific region's stratum

All region stratums are chosen automatically, depending on your "Region" setting in config.txt. For some cases, you might want to select a specific region stratum for a pool.

Example:

    "Nicehash": {
        "BTC": "<YOUR_BTC_ADDRESS>",
        "Worker": "$WorkerName",
        "Region": "US"
    },

In this example, only the US stratum will be used for Nicehash.

**This parameter is a strict selector.** Only a stratum in exactly that region is used, and
if the pool has none there, the pool disappears completely - it is not listed under "All
Pools" any more and nothing is benchmarked for it. That is the usual explanation when a pool
was configured correctly but never shows up.

Region names are not always the ones you would expect, because some pools name their servers
by country rather than by continent (HeroMiners' European server, for example, answers as
`Germany`). To find the name a pool actually uses, leave the parameter empty, open **All
Pools** in the web interface, click the "+" in front of the pool/algorithm row and read the
`Region` value - then put exactly that string into pools.config.txt.

The same parameter helps when a pool's nearest stratum is unreachable from your location: if
a miner logs nothing but connection timeouts against one host, force a different region here.
