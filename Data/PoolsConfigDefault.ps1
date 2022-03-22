[PSCustomObject]@{
        "2Miners" = [PSCustomObject]@{
            Currencies=@("FIRO")
        }
        "2MinersAE" = [PSCustomObject]@{
            Fields=[PSCustomObject]@{AECurrency=""}
            SetupFields=[PSCustomObject]@{AECurrency = "Enter your 2MinersAE autoexchange currency"}
            Autoexchange=$true
            Currencies=@("BTC","ETH","NANO")
        }
        "2MinersSolo" = [PSCustomObject]@{
            Currencies=@("FIRO")
        }
        "572133Club" = [PSCustomObject]@{
            Currencies=@("KYAN")
            Yiimp=$true
        }
        "666Pool" = [PSCustomObject]@{
            Currencies=@("PMEER")
        }
        "6Block" = [PSCustomObject]@{
            Currencies=@("HNS")
        }
        "Acepool" = [PSCustomObject]@{
            Currencies=@("BEAM","XGM")
        }
        "Aionmine" = [PSCustomObject]@{
            Currencies=@("AION")
        }
        "Aionpool" = [PSCustomObject]@{
            Currencies=@("AION")
        }
        "BaikalMine" = [PSCustomObject]@{
            Currencies=@("REOSC")
        }
        "BaikalMinePPS" = [PSCustomObject]@{
            Currencies=@("ETH","ETC")
        }
        "BaikalMineSolo" = [PSCustomObject]@{
            Currencies=@("REOSC")
        }
        "BeePool" = [PSCustomObject]@{
            Currencies=@("ETH","RVN")
        }
        "Binance" = [PSCustomObject]@{
            Fields=[PSCustomObject]@{API_Key="";API_Secret="";EnableShowWallets="0"}
            SetupFields=[PSCustomObject]@{API_Key = "Enter your Binance API key (adds balance)";API_Secret = "Enter your Binance API secret (pulls balance)";EnableShowWallets="List your Binance wallets (0=no, 1=yes)"}
            Currencies=@("ETH")
        }
        "BlazePool" = [PSCustomObject]@{
            Fields=[PSCustomObject]@{ExcludeAlgorithm="keccak";Penalty=22}
            Currencies=@("BTC")
            Autoexchange=$true
            Yiimp=$true
        }
        "Blockmasters" = [PSCustomObject]@{
            Fields=[PSCustomObject]@{Penalty=50}
            Currencies=@("BTC")
            Autoexchange=$true
            Yiimp=$true
            BalancesKeepAlive="90d"
        }
        "BlockmastersCoins" = [PSCustomObject]@{
            Fields=[PSCustomObject]@{Penalty=50}
            Currencies=@("BTC")
            Yiimp=$true
            BalancesKeepAlive="90d"
        }
        "Bsod" = [PSCustomObject]@{
            Currencies=@("RVN","SIN")
            Yiimp=$true
        }
        "BsodParty" = [PSCustomObject]@{
            Fields=[PSCustomObject]@{AllowZero="1";PartyPassword=""}
            SetupFields=[PSCustomObject]@{PartyPassword="Enter your Party password"}
            Currencies=@("RVN","SIN")
            Yiimp=$true
        }
        "BsodSolo" = [PSCustomObject]@{
            Fields=[PSCustomObject]@{AllowZero="1"}
            Currencies=@("RVN","SIN")
            Yiimp=$true
        }
        "BtcPrivate" = [PSCustomObject]@{
            Currencies=@("BTCP")
        }
        "C3pool" = [PSCustomObject]@{
            Fields=[PSCustomObject]@{Password="x"}
            SetupFields=[PSCustomObject]@{Password="Enter your C3pool password (eMail or Password)"}
            Currencies=@("XMR")
        }
        "CpuPool" = [PSCustomObject]@{
            Currencies=@("CPU","MBC")
        }
        "Crazypool" = [PSCustomObject]@{
            Currencies=@("ETH","ETC","UBQ")
        }
        "CryptoKnight" = [PSCustomObject]@{
            Currencies=@("XWP")
        }
        "EthashPool" = [PSCustomObject]@{
            Currencies=@("ETC","ETH","ETP")
        }
        "Ethermine" = [PSCustomObject]@{
            Currencies=@("ETH")
        }
        "Ezil" = [PSCustomObject]@{
            Fields=[PSCustomObject]@{EnableLolminerDual="1";EnableNanominerDual="1";EnableTrexDual="1"}
            SetupFields=[PSCustomObject]@{EnableLolminerDual="If you set this to 1, Lolminer will dual mine ZIL on Ezil for various algorithms";EnableNanominerDual="If you set this to 1, Nanominer will dual mine ZIL on Ezil for various algorithms";EnableTrexDual="If you set this to 1, Trex will dual mine ZIL on Ezil for Ethash"}
            Currencies=@("ETH","ETC","ZIL")
        }
        "F2pool" = [PSCustomObject]@{
            Fields=[PSCustomObject]@{UserName=""}
            SetupFields=[PSCustomObject]@{UserName="Enter your f2pool username, if you want to see balances"}
            Currencies=@("ETH","GRIN","BEAM","XMR","FIRO")
        }
        "FairPool" = [PSCustomObject]@{
            Currencies=@("XWP")
        }
        "FlexPool" = [PSCustomObject]@{
            Currencies=@("ETH")
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
        "GosCx" = [PSCustomObject]@{
            Currencies=@("GIN")
            Yiimp=$true
        }
        "GosCxParty" = [PSCustomObject]@{
            Fields=[PSCustomObject]@{AllowZero="1";PartyPassword=""}
            SetupFields=[PSCustomObject]@{PartyPassword="Enter your Party password"}
            Currencies=@("GIN")
            Yiimp=$true
        }
        "GosCxSolo" = [PSCustomObject]@{
            Fields=[PSCustomObject]@{AllowZero="1"}
            Currencies=@("GIN")
            Yiimp=$true
        }
        "Grinmint" = [PSCustomObject]@{
            Fields=[PSCustomObject]@{Password="x"}
            SetupFields=[PSCustomObject]@{Password="Enter your Grinmint password"}
            Currencies=@("GRIN")
        }
        "HashCity" = [PSCustomObject]@{
            Currencies=@("XMR")
        }
        "Hashcryptos" = [PSCustomObject]@{
            Currencies=@("BTC")
            Autoexchange=$true
            Yiimp=$true
        }
        "Hashpool" = [PSCustomObject]@{
            Currencies=@("TRB","HNS","CKB")
        }
        "Hashrefinery" = [PSCustomObject]@{
            Currencies=@("BTC")
            Autoexchange=$true
            Yiimp=$true
        }
        "HashVault" = [PSCustomObject]@{
            Currencies=@("XMR")
        }
        "Hellominer" = [PSCustomObject]@{
            Currencies=@("RVN","XWP")
        }
        "HeroMiners" = [PSCustomObject]@{
            Currencies=@("ERG","XWP")
        }
        "Hiveon" = [PSCustomObject]@{
            Currencies=@("ETH","ETC")
        }
        "Icemining" = [PSCustomObject]@{
            Currencies=@("SIN","MWC")
        }
        "KuCoin" = [PSCustomObject]@{
            Currencies=@("ETH")
        }
        "LeafPool" = [PSCustomObject]@{
            Currencies=@("BEAM")
        }
        "LuckyPool" = [PSCustomObject]@{
            Currencies=@("XWP")
        }
        "LuckPool" = [PSCustomObject]@{
            Currencies=@("VRSC","YEC")
        }
        "Luxor" = [PSCustomObject]@{
            Fields=[PSCustomObject]@{User=""}
            SetupFields=[PSCustomObject]@{User="Enter your Luxor username to enable automatic Catalyst mining"}
            Currencies=@("ARRR")
        }
        "Minafacil" = [PSCustomObject]@{
            Currencies=@("RTM")
        }
        "MinafacilSolo" = [PSCustomObject]@{
            Currencies=@("RTM")
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
            Currencies=@("XMR")
        }
        "Minexmr" = [PSCustomObject]@{
            Currencies=@("XMR")
        }
        "MiningDutch" = [PSCustomObject]@{
            Fields=[PSCustomObject]@{User="";API_ID="";API_Key="";AECurrency="BTC";Penalty=3}
            SetupFields=[PSCustomObject]@{User="Enter your MiningDutch username";API_ID="Enter your MiningDutch account ID";API_Key = "Enter your MiningDutch API key";AECurrency = "Enter your MiningDutch autoexchange currency"}
            Currencies=@()
            Autoexchange=$true
        }
        "MiningDutchCoins" = [PSCustomObject]@{
            Fields=[PSCustomObject]@{User="";API_ID="";API_Key="";AECurrency="BTC";Penalty=3}
            SetupFields=[PSCustomObject]@{User="Enter your MiningDutch username";API_ID="Enter your MiningDutch account ID";API_Key = "Enter your MiningDutch API key";AECurrency = "Enter your MiningDutch autoexchange currency"}
            Currencies=@("GLT")
        }
        "MiningPoolHub" = [PSCustomObject]@{
            Fields=[PSCustomObject]@{User="";API_ID="";API_Key="";AECurrency="BTC";Penalty=12}
            SetupFields=[PSCustomObject]@{User="Enter your MiningPoolHub username";API_ID="Enter your MiningPoolHub user ID";API_Key = "Enter your MiningPoolHub API key";AECurrency = "Enter your MiningPoolHub autoexchange currency"}
            Currencies=@()
            Autoexchange=$true
        }
        "MiningPoolHubCoins" = [PSCustomObject]@{
            Fields=[PSCustomObject]@{User="";API_ID="";API_Key="";AECurrency="BTC"}
            SetupFields=[PSCustomObject]@{User="Enter your MiningPoolHub username";API_ID="Enter your MiningPoolHub user ID";API_Key = "Enter your MiningPoolHub API key";AECurrency = "Enter your MiningPoolHub autoexchange currency"}
            Currencies=@()
        }
        "MiningPoolOvh" = [PSCustomObject]@{
            Fields=[PSCustomObject]@{API_Key="";Password="x"}
            SetupFields=[PSCustomObject]@{API_Key="Enter your mining-pool.ovh API-Key";Password="Enter your mining-pool.ovh password"}
            Currencies=@("VRM")
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
                        AutoCreateMinCPUProfitBTC="0.00001"
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
                        EnablePowerDrawAddOnly="0"
                        AutoPriceModifierPercent="0"
                        EnableUpdatePriceModifier="0"
                        UpdateInterval="1h"
                        PriceBTC="0"
                        PriceFactor="1.8"
                        PriceFactorMin="1.2"
                        PriceFactorDecayPercent="0"
                        PriceFactorDecayTime="4h"
                        PriceRiseExtensionPercent="0"
                        PowerDrawFactor="1.0"
                        MinHours="3"
                        MaxHours="48"
                        AllowExtensions="1"
                        AllowRentalDuringPause="0"
                        PriceCurrencies="BTC"
                        Title = "%algorithmex% mining with RainbowMiner rig %rigid%"
                        Description = "Autostart mining with RainbowMiner (https://rbminer.net) on $(if ($IsWindows) {"Windows"} else {"Linux"}). This rig is idle and will activate itself, as soon, as you rent it. %workername%"
                        StartMessage="Dear renter, thank you for renting my rig. It will be up-and-running in no time: offline pool or zero hashrate is normal in the first 5-10 minutes. Please allow at least 10 minutes to pass before raising an issue. Happy mining! (Automated message, do not respond)"
                        ExtensionMessageTime="2h"
                        ExtensionMessage="Dear renter, your rental will end soon. Now would be a good time to extend the rental, if you are happy with the result."
                        ProfitAverageTime="Day"
                        PauseBetweenRentals="10m"
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
                        PriceCurrencies="List of accepted currencies (must contain BTC)"
                        MinHours="Minimum rental time in hours (min. 3)"
                        MaxHours="Maximum rental time in hours (min. 3)"
                        AllowExtensions="Allow renters to buy extensions for a rental"
                        AllowRentalDuringPause="Allow rentals, even if the mining rig is in pause mode."
                        EnableMining="Enable switching to MiningRigRentals, even it is not rentend (not recommended)"
                        Title="Title for autocreate, make sure it contains %algorithm% or %algorithmex% or %display, and %rigid% (values will be substituted like that: %algorithm% with algorithm, %algorithmex% with algorithm plus coin info if needed, %coininfo% with eventual coin info, %display% with MRR specific display title, %rigid% with an unique rigid, %workername% with the workername, %type% with either CPU or GPU, %typecpu% with CPU or empty, %typegpu% with GPU or empty)"
                        Description="Description for autocreate, %workername% will be substituted with rig's workername. Make sure you add [%workername%] (including the square brackets!)"
                        StartMessage="Message, that will be sent to the renter at the start of the rental"
                        ExtensionMessageTime="Send the ExtensionMessage to the renter, when the remaining rental time drops below this value (in seconds, verbose allowed, e.g. 1.5h = 1.5 hours, 30m = 30 minutes, set to 0 or empty to disable)"
                        ExtensionMessage="Message, that will be sent to the renter, when remaining rental time drops below ExtensionMessageTime"
                        ProfitAverageTime="Enter the device profit moving average time period (Minute,Minute_5,Minute_10,Hour,Day,ThreeDay,Week), Day is default"
                        PauseBetweenRentals="Disable rigs on MRR after a rental for some time (in seconds, verbose allowed, e.g. 1.5h = 1.5 hours, 30m = 30 minutes)"
                        UseHost="Force use of a specific host (use eu-de01, eu-ru01, us-central01 ...)"
            }
            Currencies=@()
            Autoexchange=$true
        }
        "MintPond" = [PSCustomObject]@{
            Currencies=@("FIRO")
        }
        "MoneroOcean" = [PSCustomObject]@{
            Fields=[PSCustomObject]@{Password="x"}
            SetupFields=[PSCustomObject]@{Password="Enter your MoneroOcean password (eMail or Password)"}
            Currencies=@("XMR")
        }
        "Nanopool" = [PSCustomObject]@{
            Fields=[PSCustomObject]@{Email=""}
            SetupFields=[PSCustomObject]@{Email="Enter your eMail-Address"}
            Currencies=@("ETH")
        }
        "NiceHash" = [PSCustomObject]@{
            Fields=[PSCustomObject]@{OrganizationID="";API_Key="";API_Secret="";StatAverage="Minute_5";MaxMarginOfError="0";EnableShowWallets="0"}
            SetupFields=[PSCustomObject]@{OrganizationID="Enter your Nicehash Organization ID (pulls and adds NH balance)";API_Key = "Enter your Nicehash API key (pulls and adds NH balance)";API_Secret = "Enter your Nicehash API secret (pulls and adds NH balance)";EnableShowWallets="List your Nicehash wallets (0=no, 1=yes)"}
            Currencies=@("BTC")
            Autoexchange=$true
            BalancesKeepAlive="180d"
        }
        "NLPool" = [PSCustomObject]@{
            Fields=[PSCustomObject]@{Penalty=16}
            Currencies=@("BTC")
            Autoexchange=$true
            Yiimp=$true
            BalancesKeepAlive="30d"
        }
        "NLPoolCoins" = [PSCustomObject]@{
            Currencies=@("BTC")
            Yiimp=$true
            BalancesKeepAlive="30d"
        }
        "Poolin" = [PSCustomObject]@{
            Fields=[PSCustomObject]@{API_ETH_PUID="";API_ETH_ReadToken=""}
            SetupFields=[PSCustomObject]@{API_ETH_PUID="For ETH balance, enter your miner subaccount puid (https://github.com/iblockin/pool_web_api_doc/blob/master/api_en.md)";API_ETH_ReadToken="For ETH balance, enter your miner subaccount read-token (starts with wow; https://github.com/iblockin/pool_web_api_doc/blob/master/api_en.md)"}
            Currencies=@("ETH")
        }
        "Poolium" = [PSCustomObject]@{
            Fields=[PSCustomObject]@{API_Key="";Password="x"}
            SetupFields=[PSCustomObject]@{API_Key="Enter your poolium.win API-Key";Password="Enter your poolium.win password"}
            Currencies=@("VRM")
        }
        "ProHashing" = [PSCustomObject]@{
            Fields=[PSCustomObject]@{User="";API_Key="";AECurrency="BTC";EnableAPIKeyForMiners="0"}
            SetupFields=[PSCustomObject]@{User="Enter your ProHashing username";API_Key="Enter your ProHashing API-Key for balance";AECurrency = "Enter your ProHashing autoexchange currency";EnableAPIKeyForMiners="Add API key to miners in case `"Require API key for miners`" has been enabled at the ProHashing account settings"}
            Currencies=@()
            Autoexchange=$true
            BalancesKeepAlive="90d"
        }
        "Ravenminer" = [PSCustomObject]@{
            Currencies=@("RVN")
        }
        "Ravepool" = [PSCustomObject]@{
            Currencies=@("GRIMM")
        }
        "RPlant" = [PSCustomObject]@{
            Currencies=@("BIN","CPU","MBC")
        }
        "SeroPool" = [PSCustomObject]@{
            Currencies=@("SERO")
        }
        "SoloPool" = [PSCustomObject]@{
            Currencies=@("ETC","ETH","SAFE","SEL","XMR","XWP","ZERO")
        }
        "SparkPool" = [PSCustomObject]@{
            Currencies=@("ETH","CKB","BEAM")
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
        "Tecracoin" = [PSCustomObject]@{
            Currencies=@("TCR")
        }
        "ToncoinPool" = [PSCustomObject]@{
            Currencies=@("TON")
        }
        "TonPool" = [PSCustomObject]@{
            Currencies=@("TON")
        }
        "TONWhales" = [PSCustomObject]@{
            Currencies=@("TON")
        }
        "unMineable" = [PSCustomObject]@{
            Currencies=@("BTC","BTT","ETH","TRX","UNI","XTZ","YFI")
        }
        "UUpool" = [PSCustomObject]@{
            Currencies=@("VOLLAR")
        }
        "WoolyPooly" = [PSCustomObject]@{
            Currencies=@("CFX","ETH","VEIL")
        }
        "WoolyPoolySolo" = [PSCustomObject]@{
            Currencies=@("CFX","ETH","VEIL")
        }
        "ZergPool" = [PSCustomObject]@{
            Fields=[PSCustomObject]@{AECurrency="";Penalty=12}
            SetupFields=[PSCustomObject]@{AECurrency="Optionally define your autoexchange currency symbol"}
            Currencies=@("BTC")
            Autoexchange=$true
            Yiimp=$true
            BalancesKeepAlive="90d"
        }
        "ZergPoolCoins" = [PSCustomObject]@{
            Fields=[PSCustomObject]@{AECurrency="";Penalty=12}
            SetupFields=[PSCustomObject]@{AECurrency="Optionally define your autoexchange currency symbol"}
            Currencies=@("BTC")
            Yiimp=$true
            BalancesKeepAlive="90d"
        }
        "ZergPoolCoinsParty" = [PSCustomObject]@{
            Fields=[PSCustomObject]@{AllowZero="1";PartyPassword="";AECurrency="";Penalty=12}
            SetupFields=[PSCustomObject]@{AECurrency="Optionally define your autoexchange currency symbol";PartyPassword="Enter your Party password"}
            Currencies=@("BTC")
            Yiimp=$true
            BalancesKeepAlive="90d"
        }
        "ZergPoolCoinsSolo" = [PSCustomObject]@{
            Fields=[PSCustomObject]@{AllowZero="1";AECurrency="";Penalty=12}
            SetupFields=[PSCustomObject]@{AECurrency="Optionally define your autoexchange currency symbol"}
            Currencies=@("BTC")
            Yiimp=$true
            BalancesKeepAlive="90d"
        }
        "ZergPoolParty" = [PSCustomObject]@{
            Fields=[PSCustomObject]@{AllowZero="1";PartyPassword="";AECurrency="";Penalty=12}
            SetupFields=[PSCustomObject]@{AECurrency="Optionally define your autoexchange currency symbol";PartyPassword="Enter your Party password"}
            Currencies=@("BTC")
            Autoexchange=$true
            Yiimp=$true
            BalancesKeepAlive="90d"
        }
        "ZergPoolSolo" = [PSCustomObject]@{
            Fields=[PSCustomObject]@{AllowZero="1";Penalty=12}
            SetupFields=[PSCustomObject]@{AECurrency="Optionally define your autoexchange currency symbol"}
            Currencies=@("BTC")
            Autoexchange=$true
            Yiimp=$true
            BalancesKeepAlive="90d"
        }
        "Zpool" = [PSCustomObject]@{
            Fields=[PSCustomObject]@{AECurrency="";Penalty=16}
            SetupFields=[PSCustomObject]@{AECurrency="Optionally define your autoexchange currency symbol"}
            Currencies=@("BTC")
            Autoexchange=$true
            Yiimp=$true
            BalancesKeepAlive="90d"
        }
        "ZpoolCoins" = [PSCustomObject]@{
            Fields=[PSCustomObject]@{AECurrency="";Penalty=16}
            SetupFields=[PSCustomObject]@{AECurrency="Optionally define your autoexchange currency symbol"}
            Currencies=@("BTC")
            Yiimp=$true
            BalancesKeepAlive="90d"
        }
}
