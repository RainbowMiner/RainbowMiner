﻿[PSCustomObject]@{
        "2Miners" = [PSCustomObject]@{
            Currencies=@("FIRO")
        }
        "2MinersAE" = [PSCustomObject]@{
            Fields=[PSCustomObject]@{AECurrency=""}
            SetupFields=[PSCustomObject]@{AECurrency = "Enter your 2MinersAE autoexchange currency"}
            Autoexchange="BTC"
            Currencies=@("BTC","NANO")
        }
        "2MinersSolo" = [PSCustomObject]@{
            Currencies=@("FIRO")
        }
        "51pool" = [PSCustomObject]@{
            Fields=[PSCustomObject]@{Username="";Password="x"}
            SetupFields=[PSCustomObject]@{Username="Enter your 51pool username";Password="Enter your 51pool password"}
            Currencies=@("EPIC")
        }
        "6Block" = [PSCustomObject]@{
            Currencies=@("HNS")
        }
        "Abelpool" = [PSCustomObject]@{
            Fields=[PSCustomObject]@{ReadonlyPageCode=""}
            SetupFields=[PSCustomObject]@{ReadonlyPageCode = "To view your balance, create a readonly page on abelpool.io and input the string after code= here."}
            Currencies=@("ABEL")
        }
        "AccPool" = [PSCustomObject]@{
            Currencies=@("KAS","NEXA")
        }
        "Acepool" = [PSCustomObject]@{
            Currencies=@("BEAM","XGM")
        }
        "Aionpool" = [PSCustomObject]@{
            Currencies=@("AION")
        }
        "AlphPool" = [PSCustomObject]@{
            Currencies=@("ALPH")
        }
        "BaikalMine" = [PSCustomObject]@{
            Currencies=@("REOSC")
        }
        "BaikalMinePPS" = [PSCustomObject]@{
            Currencies=@("ETC")
        }
        "BaikalMineSolo" = [PSCustomObject]@{
            Currencies=@("REOSC")
        }
        "Binance" = [PSCustomObject]@{
            Fields=[PSCustomObject]@{API_Key="";API_Secret="";EnableShowWallets="0"}
            SetupFields=[PSCustomObject]@{API_Key = "Enter your Binance API key (adds balance)";API_Secret = "Enter your Binance API secret (pulls balance)";EnableShowWallets="List your Binance wallets (0=no, 1=yes)"}
            Currencies=@("ETC")
        }
        "BlocxZone" = [PSCustomObject]@{
            Currencies=@("BLOCX")
        }
        "C3pool" = [PSCustomObject]@{
            Fields=[PSCustomObject]@{Password="x"}
            SetupFields=[PSCustomObject]@{Password="Enter your C3pool password (eMail or Password)"}
            Currencies=@("XMR")
            Autoexchange="XMR"
        }
        "CpuPool" = [PSCustomObject]@{
            Currencies=@("CPU","MBC")
        }
        "Crazypool" = [PSCustomObject]@{
            Currencies=@("ETC")
        }
        "DeepMinerZ" = [PSCustomObject]@{
            Currencies=@("DNX")
        }
        "DeepMinerZSolo" = [PSCustomObject]@{
            Currencies=@("DNX")
        }
        "Ekapool" = [PSCustomObject]@{
            Currencies=@("AVS","FLR","DNX","ZANO")
        }
        "EthashPool" = [PSCustomObject]@{
            Currencies=@("ETC","ETP")
        }
        "Ethwmine" = [PSCustomObject]@{
            Currencies=@("ETHW")
        }
        "Evepool" = [PSCustomObject]@{
            Currencies=@("VKAX")
        }
        "F2pool" = [PSCustomObject]@{
            Fields=[PSCustomObject]@{UserName=""}
            SetupFields=[PSCustomObject]@{UserName="Enter your f2pool username, if you want to see balances"}
            Currencies=@("ETC","RVN","ERG","BEAM")
        }
        "FlockPool" = [PSCustomObject]@{
            Currencies=@("RTM")
        }
        "FluxPools" = [PSCustomObject]@{
            Fields=[PSCustomObject]@{Password="x"}
            SetupFields=[PSCustomObject]@{Password="Enter your Fluxpools password"}
            Currencies=@("FLUX","FIRO","TCR")
        }
        "FlyPool" = [PSCustomObject]@{
            Currencies=@("BEAM","YEC")
        }
        "Gtpool" = [PSCustomObject]@{
            Fields=[PSCustomObject]@{
                            Account_Id=""
                            API_Key=""
                            UseWorkerName=""
                            ExcludeWorkerName=""
                            EnableMiningSwitch="1"
            }
            SetupFields=[PSCustomObject]@{
                            Account_Id="Enter your Gtpool Account Id (add a worker on gtpool.io with your rig's workername before start mining!)"
                            API_Key="Enter your Gtpool API key (Settings, scroll down a bit)"
                            UseWorkerName="Enter workernames to explicitly use (leave empty for all=default)"
                            ExcludeWorkerName="Enter workernames to explicitly exclude (leave empty for none=default)"
                            EnableMiningSwitch="If set to 1, the module will change mining to the most profitable coin, as defined in CoinSymbol automatically"
            }
            Currencies=@()
        }
        "Grinmint" = [PSCustomObject]@{
            Fields=[PSCustomObject]@{Password="x"}
            SetupFields=[PSCustomObject]@{Password="Enter your Grinmint password"}
            Currencies=@("GRIN")
        }
        "Hashcryptos" = [PSCustomObject]@{
            Currencies=@("BTC")
            Autoexchange="BTC"
            Yiimp=$true
        }
        "Hashpool" = [PSCustomObject]@{
            Currencies=@("HNS","CKB")
        }
        "HashVault" = [PSCustomObject]@{
            Currencies=@("XMR")
        }
        "Hellominer" = [PSCustomObject]@{
            Currencies=@("ETC","RVN")
        }
        "HeroMiners" = [PSCustomObject]@{
            Currencies=@("DNX","ETC","QUAI","RVN","ERG")
        }
        "Hiveon" = [PSCustomObject]@{
            Currencies=@("ETC")
        }
        "Icemining" = [PSCustomObject]@{
            Currencies=@("NIM","GRAM")
        }
        "K1Pool" = [PSCustomObject]@{
            Currencies=@("NEXA","XEL","ZIL")
        }
        "K1PoolSolo" = [PSCustomObject]@{
            Currencies=@("NEXA","XEL")
        }
        "Kryptex" = [PSCustomObject]@{
            Fields=[PSCustomObject]@{Email=""}
            SetupFields=[PSCustomObject]@{Email="Enter your eMail-Address to enable all coins for autoexchange"}
            Currencies=@("KAS","XMR")
            Autoexchange="BTC"
        }
        "LeafPool" = [PSCustomObject]@{
            Currencies=@("BEAM")
        }
        "LuckyPool" = [PSCustomObject]@{
            Currencies=@("QUAI","ZANO")
        }
        "LuckPool" = [PSCustomObject]@{
            Fields=[PSCustomObject]@{EnableHybridSoloMining="0"}
            SetupFields=[PSCustomObject]@{EnableHybridSoloMining="Enable hybrid solo mining mode"}
            Currencies=@("VRSC")
        }
        "Luxor" = [PSCustomObject]@{
            Fields=[PSCustomObject]@{User="";API_Key=""}
            SetupFields=[PSCustomObject]@{User="Enter your Luxor username to enable all coins (or leavy it empty and set your username as wallet address in pools.config.txt)";API_Key="Enter your Luxor API key (Profile Settings > Api Keys > Generate New Key)"}
            Currencies=@("ARRR","DASH","ZEC","ZEN")
        }
        "Minerpool" = [PSCustomObject]@{
            Fields=[PSCustomObject]@{Password="xyz"}
            SetupFields=[PSCustomObject]@{Password="Enter your Minerpool password (must NOT be x)"}
            Currencies=@("FLUX","TENT","VDL")
        }
        "MinerpoolSolo" = [PSCustomObject]@{
            Fields=[PSCustomObject]@{Password="xyz"}
            SetupFields=[PSCustomObject]@{Password="Enter your Minerpool password (must NOT be x)"}
            Currencies=@("FLUX","TENT","VDL")
        }
        "MinerRocks" = [PSCustomObject]@{
            Currencies=@("TUBE")
        }
        "Mining4people" = [PSCustomObject]@{
            Currencies=@("PEPEW")
        }
        "Mining4peopleSolo" = [PSCustomObject]@{
            Currencies=@("PEPEW")
        }
        "MiningDutch" = [PSCustomObject]@{
            Fields=[PSCustomObject]@{User="";API_ID="";API_Key="";AECurrency="BTC";Penalty=3}
            SetupFields=[PSCustomObject]@{User="Enter your MiningDutch username";API_ID="Enter your MiningDutch account ID";API_Key = "Enter your MiningDutch API key";AECurrency = "Enter your MiningDutch autoexchange currency"}
            Currencies=@()
            Autoexchange="BTC"
        }
        "MiningDutchCoins" = [PSCustomObject]@{
            Fields=[PSCustomObject]@{User="";API_ID="";API_Key="";AECurrency="BTC";Penalty=3}
            SetupFields=[PSCustomObject]@{User="Enter your MiningDutch username";API_ID="Enter your MiningDutch account ID";API_Key = "Enter your MiningDutch API key";AECurrency = "Enter your MiningDutch autoexchange currency"}
            Currencies=@("GLT")
            Autoexchange="BTC"
        }
        "MiningRigRentals" = [PSCustomObject]@{
            Fields=[PSCustomObject]@{
                        User=""
                        API_Key=""
                        API_Secret=""
                        EnableMining="0"
                        EnableMaintenanceMode="0"
                        UseWorkerName=""
                        ExcludeWorkerName=""
                        ExcludeRentalId=""
                        EnableAutoCreate="0"
                        AutoCreateMinProfitPercent="50"
                        AutoCreateMinCPUProfitBTC="0.000001"
                        AutoCreateMaxMinHours="24"
                        AutoUpdateMinPriceChangePercent="3"
                        AutoCreateAlgorithm=""
                        EnableAutoUpdate="0"
                        EnableAutoBenchmark="0"
                        EnableAutoExtend="0"
                        AutoExtendTargetPercent="100"
                        AutoExtendMaximumPercent="30"
                        AutoBonusExtendForHours="0"
                        AutoBonusExtendByHours="0"
                        EnableUpdateTitle="1"
                        EnableUpdateDescription="1"
                        EnableAutoPrice="1"
                        EnableMinimumPrice="1"
                        EnableAutoAdjustMinHours="1"
                        EnablePowerDrawAddOnly="0"
                        EnableRecoveryMode="0"
                        AutoPriceModifierPercent="0"
                        EnableUpdatePriceModifier="0"
                        UpdateInterval="30m"
                        PriceBTC="0"
                        PriceFactor="1.8"
                        PriceFactorMin="1.2"
                        PriceFactorDecayPercent="0"
                        PriceFactorDecayTime="4h"
                        PriceRiseExtensionPercent="0"
                        PowerDrawFactor="1.0"
                        MinHours="3"
                        MaxHours="168"
                        MaxMinHours="24"
                        AllowExtensions="1"
                        AllowRentalDuringPause="0"
                        PriceCurrencies="BTC"
                        Title = "%algorithmex% mining with RainbowMiner rig %rigid%"
                        Description = "Autostart mining with RainbowMiner on $(if ($IsWindows) {"Windows"} else {"Linux"}). This rig is idle and will activate itself, as soon, as you rent it. %workername%"
                        StartMessage="Dear renter, thank you for renting my rig. It will be up-and-running in no time: offline pool or zero hashrate is normal in the first 5-10 minutes. Please allow at least 10 minutes to pass before raising an issue.<diff> Please make sure, that your pool's difficulty is between %mindifffmt% (%mindiff%) and %maxdifffmt% (%maxdiff%) to get the advertised hashrate.</diff> Happy mining! (Automated message, do not respond)"
                        ExtensionMessageTime="2h"
                        ExtensionMessage="Dear renter, your rental will end soon. Now would be a good time to extend the rental, if you are happy with the result."
                        DiffMessageTime="15m"
                        DiffMessageTolerancyPercent="15"
                        DiffMessage="Dear renter, your pool's share difficulty is %currentdifffmt% (%currentdiff%) and it should be between %mindifffmt% (%mindiff%) and %maxdifffmt% (%maxdiff%) to get the advertised hashrate. If the difficulty is too high, the result will be eratic but accurate for long rental times, if the difficulty is too low, the final hashrate will be too low as well." 
                        PoolOfflineTime="10m"
                        PoolOfflineRetryTime="15m"
                        PoolOfflineMessage="Dear renter, it looks like your pool is currently offline. Please check your settings."
                        ProfitAverageTime="Hour"
                        PauseBetweenRentals="2h"
                        UseHost=""
            }
            SetupFields=[PSCustomObject]@{
                        User="Enter your MiningRigRentals username"
                        API_Key="Enter your MiningRigRentals API key"
                        API_Secret = "Enter your MiningRigRentals API secret key"
                        UseWorkerName="Enter workernames to explicitly use (leave empty for all=default)"
                        ExcludeWorkerName="Enter workernames to explicitly exclude (leave empty for none=default)"
                        ExcludeRentalId="In case of a rental dispute (wrong renter pool etc.), exclude these rentals by rental id, until they are cancelled (leave empty for none=default)"
                        EnableMaintenanceMode="Enable maintenance mode - all unrented rigs will be disabled"
                        EnableAutoCreate="Automatically create MRR-rigs"
                        EnableAutoUpdate="Automatically update MRR-rigs"
                        EnableAutoBenchmark="Enable benchmark of missing algorithms (it will mine to RainbowMiner wallets during benchmark, only)"
                        EnableAutoExtend="Enable automatic extend when low average"
                        AutoExtendTargetPercent="Set auto extension target (in percent of rented hashrate)"
                        AutoExtendMaximumPercent="Set maximum extension (in percent of rented time)"
                        AutoBonusExtendForHours="Enter amount of hours, that you want to reward with an automatic bonus extension (e.g. 24)"
                        AutoBonusExtendByHours="Enter bonus extension in hours per rented AutoBonusExtendForHours (e.g. 1)"
                        AutoCreateMinProfitPercent="Enter minimum profitability in percent compared to current best profit, for full rigs to be autocreated on MRR"
                        AutoCreateMinCPUProfitBTC="Enter minimum one-day revenue in BTC, for a CPU-only rig to be autocreated on MRR"
                        AutoCreateMaxMinHours="Enter the maximum hours for minimum rental time, for a rig to be autocreated on MRR"
                        AutoUpdateMinPriceChangePercent="Enter the minimum price change in percent, for a rig to be updated on MRR"
                        AutoCreateAlgorithm="Algorithms that should always be autocreated on MRR, even if below the other limits"
                        EnableAutoPrice="Enable MRR automatic prices"
                        EnableMinimumPrice="Set MRR automatic minimum price"
                        EnableAutoAdjustMinHours="Automatically adjust minimum rental time (up to MaxMinHours), to satisfy the min. profit of 0.00001 BTC"
                        AutoPriceModifierPercent="Autoprice modifier in percent (e.g. +10 will increase all suggested prices by 10%, allowed range -30 .. 30)"
                        EnableUpdatePriceModifier="Enable automatic update of price modifier (can be set globally in pools.config.txt and for each algorithm in algorithms.config.txt parameter MRRPriceModifierPercent)"
                        UpdateInterval="Enter the interval time for create and update rigs on MRR (in seconds, verbose allowed, e.g. 1.5h = 1.5 hours, 30m = 30 minutes)"
                        PriceBTC="Fixed price in BTC (used, if EnableAutoPrice=0 or if the value is greater than the PriceFactor x revenue)"
                        PriceFactor="Enter profit multiplicator: price = rig's average revenue x this multiplicator"
                        PriceFactorMin="Minimum profit multiplicator (only of use, if PriceFactorDecayPercent is greater than 0)"
                        PriceFactorDecayPercent="Enter percentage for decay of the profit multiplicator over time (0 = disable)"
                        PriceFactorDecayTime="Enter the profit multiplicator decay interval (in seconds, verbose allowed, e.g. 1.5h = 1.5 hours, 30m = 30 minutes)"
                        PriceRiseExtensionPercent="Enter price rise for extensions of a rental (in percent, e.g. 10 means 10% price rise)"
                        PowerDrawFactor="Enter powerdraw multiplicator (only if UsePowerPrice is enabled): minimum price = minimum price + (miner's power draw - rig's average power draw) 24 / 1000 x powerdrawprice x this multiplicator"
                        EnablePowerDrawAddOnly="Add the powerdraw cost difference only, if it is greater than 0"
                        EnableUpdateTitle="Enable automatic updating of rig titles (disable, if you prefer to edit your rig titles online at MRR)"
                        EnableUpdateDescription="Enable automatic updating of rig descriptions (disable, if you prefer to edit your rig descriptions online at MRR)"
                        EnableRecoveryMode="Enable automatic recovery mode of orphaned rigs on MRR, that have no workername in their description"
                        PriceCurrencies="List of accepted currencies (must contain BTC)"
                        MinHours="Minimum rental time in hours (min. 3)"
                        MaxHours="Maximum rental time in hours (min. 3)"
                        MaxMinHours="Upper limit for auto-adjust minimum rental time, if EnableAutoAdjustMinHours is set to 1 (default=24)"
                        AllowExtensions="Allow renters to buy extensions for a rental"
                        AllowRentalDuringPause="Allow rentals, even if the mining rig is in pause mode."
                        EnableMining="Enable switching to MiningRigRentals, even it is not rentend (not recommended)"
                        Title="Title for autocreate, make sure it contains %algorithm% or %algorithmex% or %display, and %rigid% (values will be substituted like that: %algorithm% with algorithm, %algorithmex% with algorithm plus coin info if needed, %coininfo% with eventual coin info, %display% with MRR specific display title, %rigid% with an unique rigid, %workername% with the workername, %type% with either CPU or GPU, %typecpu% with CPU or empty, %typegpu% with GPU or empty)"
                        Description="Description for autocreate, %workername% will be substituted with rig's workername. Make sure you add [%workername%] (including the square brackets!)"
                        StartMessage="Message, that will be sent to the renter at the start of the rental"
                        ExtensionMessageTime="Send the ExtensionMessage to the renter, when the remaining rental time drops below this value (in seconds, verbose allowed, e.g. 1.5h = 1.5 hours, 30m = 30 minutes, set to 0 or empty to disable)"
                        ExtensionMessage="Message, that will be sent to the renter, when remaining rental time drops below ExtensionMessageTime"
                        DiffMessageTime="Send the DiffMessage to the renter, when the current difficulty stays out of the optimum difficulty for this time (in seconds, verbose allowed, e.g. 1.5h = 1.5 hours, 30m = 30 minutes, set to 0 or empty to disable)"
                        DiffMessageTolerancyPercent="Allowed tolerancy above the maximum and below the minimum of the optimum difficulty (in percent, e.g. 15 means 15%)"
                        DiffMessage="Message, that will be sent to the renter, if the current difficulty stays out of the optimum difficulty for DiffMessageTime (substitutions: %type% = algorithm, %mindiff% = min. optimum diffculty as integer, %maxdiff% = max. optimum difficulty as integer, %currentdiff% = current difficulty as integer, %mindifffmt% = min. optimum diffculty formatted, %maxdifffmt% = max. optimum difficulty formatted, %currentdifffmt% = current difficulty formatted)"
                        PoolOfflineTime="Enter the time a renter's pools has to be offline, until it is temporary disabled and the pool offline message is sent (in seconds, verbose allowed, e.g. 1.5h = 1.5 hours, 30m = 30 minutes)"
                        PoolOfflineRetryTime="Enter the time after which we will retry to connect to a disabled renter's pool (in seconds, verbose allowed, e.g. 1.5h = 1.5 hours, 30m = 30 minutes)"
                        PoolOfflineMessage="Message, that will be sent to the renter, after a renter's pool has been offline for PoolOfflineTime"
                        ProfitAverageTime="Enter the device profit moving average time period (Minute,Minute_5,Minute_10,Hour,Day,ThreeDay,Week), Day is default"
                        PauseBetweenRentals="Disable rigs on MRR after a rental for some time (in seconds, verbose allowed, e.g. 1.5h = 1.5 hours, 30m = 30 minutes)"
                        UseHost="Force use of a specific host (use eu-de01, eu-ru01, us-central01 ...)"
            }
            Currencies=@()
            Autoexchange="BTC"
        }
        "MintPond" = [PSCustomObject]@{
            Currencies=@("FIRO","RVN")
        }
        "Molepool" = [PSCustomObject]@{
            Currencies=@("ETHW")
        }
        "MoneroOcean" = [PSCustomObject]@{
            Fields=[PSCustomObject]@{Password="x"}
            SetupFields=[PSCustomObject]@{Password="Enter your MoneroOcean password (eMail or Password)"}
            Currencies=@("XMR")
            Autoexchange="XMR"
        }
        "Nanopool" = [PSCustomObject]@{
            Fields=[PSCustomObject]@{Email=""}
            SetupFields=[PSCustomObject]@{Email="Enter your eMail-Address"}
            Currencies=@("ETC","RVN","ERG")
        }
        "Neuropool" = [PSCustomObject]@{
            Currencies=@("DNX")
        }
        "NiceHash" = [PSCustomObject]@{
            Fields=[PSCustomObject]@{OrganizationID="";API_Key="";API_Secret="";StatAverage="Minute_5";MaxMarginOfError="0";EnableShowWallets="0"}
            SetupFields=[PSCustomObject]@{OrganizationID="Enter your Nicehash Organization ID (pulls and adds NH balance)";API_Key = "Enter your Nicehash API key (pulls and adds NH balance)";API_Secret = "Enter your Nicehash API secret (pulls and adds NH balance)";EnableShowWallets="List your Nicehash wallets (0=no, 1=yes)"}
            Currencies=@("BTC")
            Autoexchange="BTC"
            BalancesKeepAlive="180d"
        }
        "Pmpmining" = [PSCustomObject]@{
            Currencies=@("NOVO","RXD")
        }
        "PmpminingSolo" = [PSCustomObject]@{
            Currencies=@("NOVO","RXD")
        }
        "Poolin" = [PSCustomObject]@{
            Fields=[PSCustomObject]@{API_ETH_PUID="";API_ETH_ReadToken="";API_ETC_PUID="";API_ETC_ReadToken="";API_ETF_PUID="";API_ETF_ReadToken="";API_ETHW_PUID="";API_ETHW_ReadToken=""}
            SetupFields=[PSCustomObject]@{
                API_ETH_PUID="For ETH balance, enter your miner subaccount puid (https://github.com/iblockin/pool_web_api_doc/blob/master/api_en.md)"
                API_ETH_ReadToken="For ETH balance, enter your miner subaccount read-token (starts with wow; https://github.com/iblockin/pool_web_api_doc/blob/master/api_en.md)"
                API_ETC_PUID="For ETC balance, enter your miner subaccount puid (https://github.com/iblockin/pool_web_api_doc/blob/master/api_en.md)"
                API_ETC_ReadToken="For ETC balance, enter your miner subaccount read-token (starts with wow; https://github.com/iblockin/pool_web_api_doc/blob/master/api_en.md)"
                API_ETF_PUID="For ETF balance, enter your miner subaccount puid (https://github.com/iblockin/pool_web_api_doc/blob/master/api_en.md)"
                API_ETF_ReadToken="For ETF balance, enter your miner subaccount read-token (starts with wow; https://github.com/iblockin/pool_web_api_doc/blob/master/api_en.md)"
                API_ETHW_PUID="For ETHW balance, enter your miner subaccount puid (https://github.com/iblockin/pool_web_api_doc/blob/master/api_en.md)"
                API_ETHW_ReadToken="For ETHW balance, enter your miner subaccount read-token (starts with wow; https://github.com/iblockin/pool_web_api_doc/blob/master/api_en.md)"
            }
            Currencies=@("ETC")
        }
        "ProHashing" = [PSCustomObject]@{
            Fields=[PSCustomObject]@{User="";AECurrency="BTC";API_Key="";EnableAPIKeyForMiners="0"}
            SetupFields=[PSCustomObject]@{User="Enter your ProHashing username";API_Key="Enter your ProHashing API-Key for balance";AECurrency = "Enter your ProHashing autoexchange currency";EnableAPIKeyForMiners="Add API key to miners in case `"Require API key for miners`" has been enabled at the ProHashing account settings"}
            Currencies=@()
            Autoexchange="BTC"
            BalancesKeepAlive="90d"
        }
        "ProHashingCoins" = [PSCustomObject]@{
            Fields=[PSCustomObject]@{User="";PPMode="pps";API_Key="";AECurrency="BTC";EnableAPIKeyForMiners="0"}
            SetupFields=[PSCustomObject]@{User="Enter your ProHashing username and select payout coins with CoinSymbol (or use separate wallet symbols with username in it)";PPMode="Enter the payout/mining mode (pps,pplns or solo)";API_Key="Enter your ProHashing API-Key for balance";AECurrency = "Enter your ProHashing autoexchange currency";EnableAPIKeyForMiners="Add API key to miners in case `"Require API key for miners`" has been enabled at the ProHashing account settings"}
            Currencies=@()
            Autoexchange="BTC"
            BalancesKeepAlive="90d"
        }
        "ProHashingCoinsSolo" = [PSCustomObject]@{
            Fields=[PSCustomObject]@{User="";API_Key="";AECurrency="BTC";EnableAPIKeyForMiners="0"}
            SetupFields=[PSCustomObject]@{User="Enter your ProHashing username and select payout coins with CoinSymbol (or use separate wallet symbols with username in it)";API_Key="Enter your ProHashing API-Key for balance";AECurrency = "Enter your ProHashing autoexchange currency";EnableAPIKeyForMiners="Add API key to miners in case `"Require API key for miners`" has been enabled at the ProHashing account settings"}
            Currencies=@()
            Autoexchange="BTC"
            BalancesKeepAlive="90d"
        }
        "RaptoreumZone" = [PSCustomObject]@{
            Currencies=@("RTM")
        }
        "RaptorHash" = [PSCustomObject]@{
            Currencies=@("RTM")
        }
        "Ravenminer" = [PSCustomObject]@{
            Fields=[PSCustomObject]@{AECurrency=""}
            SetupFields=[PSCustomObject]@{AECurrency = "Enter your RavenMiner autoexchange currency or leave empty for first of RVN,BTC,ETH,LTC,BCH,ADA,DOGE,MATIC"}
            Currencies=@("RVN")
            Autoexchange="RVN"
        }
        "RavenminerSolo" = [PSCustomObject]@{
            Fields=[PSCustomObject]@{AECurrency=""}
            SetupFields=[PSCustomObject]@{AECurrency = "Enter your RavenMinerSolo autoexchange currency or leave empty for first of RVN,BTC,ETH,LTC,BCH,ADA,DOGE,MATIC"}
            Currencies=@("RVN")
            Autoexchange="RVN"
        }
        "RPlant" = [PSCustomObject]@{
            Currencies=@("BTX","NEXA","VKAX")
        }
        "RPlantSolo" = [PSCustomObject]@{
            Currencies=@("BTX","NEXA","VKAX")
        }
        "SeroPool" = [PSCustomObject]@{
            Currencies=@("SERO")
        }
        "SoloPool" = [PSCustomObject]@{
            Currencies=@("ERG","RVN","FIRO")
        }
        "Sunpool" = [PSCustomObject]@{
            Currencies=@("GRIMM","BEAM","ATOMI")
        }
        "SupportXmr" = [PSCustomObject]@{
            Currencies=@("XMR")
        }
        "SuprNova" = [PSCustomObject]@{
            Currencies=@("BTG")
        }
        "unMineable" = [PSCustomObject]@{
            Currencies=@("BTC","BTT","ETC","TRX","UNI","XTZ","YFI")
        }
        "UUpool" = [PSCustomObject]@{
            Currencies=@("VOLLAR")
        }
        "ViaBTC" = [PSCustomObject]@{
            Fields=[PSCustomObject]@{"ETC-PaymentMode"="pplns";API_Key=""}
            SetupFields=[PSCustomObject]@{"ETC-PaymentMode" = "Enter your ETC-setup payment mode (pps, pplns or solo) for proper fee calculation";API_Key = "Enter your ViaBTC API key (adds your balance)"}
            Currencies=@("ETC")
        }
        "Vipor" = [PSCustomObject]@{
            Currencies=@("RXD")
        }
        "ViporSolo" = [PSCustomObject]@{
            Currencies=@("RXD")
        }
        "WoolyPooly" = [PSCustomObject]@{
            Fields=[PSCustomObject]@{Penalty=30}
            Currencies=@("CFX","ETC","RVN","ERG","NEXA")
        }
        "WoolyPoolySolo" = [PSCustomObject]@{
            Currencies=@("CFX","ETC","RVN","ERG","NEXA")
        }
        "YadaMiners" = [PSCustomObject]@{
            Currencies=@("YDA")
        }
        "XdagOrg" = [PSCustomObject]@{
            Currencies=@("XDAG")
        }
        "XdagOrgSolo" = [PSCustomObject]@{
            Currencies=@("XDAG")
        }
        "ZergPool" = [PSCustomObject]@{
            Fields=[PSCustomObject]@{AECurrency="";Penalty=12}
            SetupFields=[PSCustomObject]@{AECurrency="Optionally define your autoexchange currency symbol"}
            Currencies=@("BTC")
            Autoexchange="BTC"
            Yiimp=$true
            BalancesKeepAlive="90d"
        }
        "ZergPoolCoins" = [PSCustomObject]@{
            Fields=[PSCustomObject]@{AECurrency="";Penalty=12}
            SetupFields=[PSCustomObject]@{AECurrency="Optionally define your autoexchange currency symbol"}
            Currencies=@("BTC")
            Autoexchange="BTC"
            Yiimp=$true
            BalancesKeepAlive="90d"
        }
        "ZergPoolCoinsParty" = [PSCustomObject]@{
            Fields=[PSCustomObject]@{PartyPassword="";AECurrency="";Penalty=12}
            SetupFields=[PSCustomObject]@{AECurrency="Optionally define your autoexchange currency symbol";PartyPassword="Enter your Party password"}
            Currencies=@("BTC")
            Autoexchange="BTC"
            Yiimp=$true
            BalancesKeepAlive="90d"
        }
        "ZergPoolCoinsSolo" = [PSCustomObject]@{
            Fields=[PSCustomObject]@{AllowZero="1";AECurrency="";Penalty=12}
            SetupFields=[PSCustomObject]@{AECurrency="Optionally define your autoexchange currency symbol"}
            Currencies=@("BTC")
            Autoexchange="BTC"
            Yiimp=$true
            BalancesKeepAlive="90d"
        }
        "ZergPoolParty" = [PSCustomObject]@{
            Fields=[PSCustomObject]@{PartyPassword="";AECurrency="";Penalty=12}
            SetupFields=[PSCustomObject]@{AECurrency="Optionally define your autoexchange currency symbol";PartyPassword="Enter your Party password"}
            Currencies=@("BTC")
            Autoexchange="BTC"
            Yiimp=$true
            BalancesKeepAlive="90d"
        }
        "ZergPoolSolo" = [PSCustomObject]@{
            Fields=[PSCustomObject]@{AllowZero="1";Penalty=12}
            SetupFields=[PSCustomObject]@{AECurrency="Optionally define your autoexchange currency symbol"}
            Currencies=@("BTC")
            Autoexchange="BTC"
            Yiimp=$true
            BalancesKeepAlive="90d"
        }
        "Zpool" = [PSCustomObject]@{
            Fields=[PSCustomObject]@{AECurrency="";Penalty=16}
            SetupFields=[PSCustomObject]@{AECurrency="Optionally define your autoexchange currency symbol"}
            Currencies=@("BTC")
            Autoexchange="BTC"
            Yiimp=$true
            BalancesKeepAlive="90d"
        }
        "ZpoolCoins" = [PSCustomObject]@{
            Fields=[PSCustomObject]@{AECurrency="";Penalty=16}
            SetupFields=[PSCustomObject]@{AECurrency="Optionally define your autoexchange currency symbol"}
            Currencies=@("BTC")
            Autoexchange="BTC"
            Yiimp=$true
            BalancesKeepAlive="90d"
        }
}
