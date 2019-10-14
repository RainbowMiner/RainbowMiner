[PSCustomObject]@{
        "2Miners" = [PSCustomObject]@{
            Currencies=@("XZC")
        }
        "2MinersSolo" = [PSCustomObject]@{
            Currencies=@("XZC")
        }
        "AHashPool" = [PSCustomObject]@{
            Fields=[PSCustomObject]@{Penalty=22}
            Currencies=@("BTC")
            Autoexchange=$true
            Yiimp=$true
        }
        "Aionmine" = [PSCustomObject]@{
            Currencies=@("AION")
        }
        "BaikalMine" = [PSCustomObject]@{
            Currencies=@("REOSC")
        }
        "BaikalMineSolo" = [PSCustomObject]@{
            Currencies=@("REOSC")
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
        }
        "BlockmastersCoins" = [PSCustomObject]@{
            Fields=[PSCustomObject]@{Penalty=50}
            Currencies=@("BTC")
            Autoexchange=$true
            Yiimp=$true
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
        "CoinFoundry" = [PSCustomObject]@{
            Currencies=@("BCD")
        }
        "CryptoKnight" = [PSCustomObject]@{
            Currencies=@("XWP")
        }
        "EthashPool" = [PSCustomObject]@{
            Currencies=@("ETC","ETH","ETP","GRIN")
        }
        "Ethermine" = [PSCustomObject]@{
            Currencies=@("ETH")
        }
        "F2pool" = [PSCustomObject]@{
            Fields=[PSCustomObject]@{UserName=""}
            SetupFields=[PSCustomObject]@{UserName="Enter your f2pool username, if you want to see balances"}
            Currencies=@("ETH","GRIN","BEAM","XMR","XZC")
        }
        "FairPool" = [PSCustomObject]@{
            Currencies=@("XWP")
        }
        "FlyPool" = [PSCustomObject]@{
            Currencies=@("YEC")
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
        "Hashpool" = [PSCustomObject]@{
            Currencies=@("MBC")
        }
        "Hashrefinery" = [PSCustomObject]@{
            Currencies=@("BTC")
            Autoexchange=$true
            Yiimp=$true
        }
        "HashVault" = [PSCustomObject]@{
            Currencies=@("XMR")
        }
        "HeroMiners" = [PSCustomObject]@{
            Currencies=@("XWP")
        }
        "Icemining" = [PSCustomObject]@{
            Currencies=@("RVN","SIN","YEC")
        }
        "LuckyPool" = [PSCustomObject]@{
            Currencies=@("XWP")
        }
        "MinerMore" = [PSCustomObject]@{
            Currencies=@("RVN","SIN","YEC")
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
            Autoexchange=$true
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
            Autoexchange=$true
        }
        "MiningRigRentals" = [PSCustomObject]@{
            Fields=[PSCustomObject]@{User="";API_Key="";API_Secret="";EnableMining="0";EnableAutoCreate="1";EnablePriceUpdates="1";EnableAutoPrice="1";EnableMinimumPrice="1";PriceBTC="0";PriceFactor="1.3";PriceCurrencies="BTC";Title = "%algorithm% mining";Description = "Autostart mining with RainbowMiner (https://rbminer.net) on $(if ($IsWindows) {"Windows"} else {"Linux"}). This rig is idle and will activate itself, as soon, as you rent it. %workername%"}
            SetupFields=[PSCustomObject]@{User="Enter your MiningRigRentals username";API_Key="Enter your MiningRigRentals API key";API_Secret = "Enter your MiningRigRentals API secret key";EnableAutoCreate="Automatically create MRR-rigs";EnablePriceUpdates="Enable rental price updates";EnableAutoPrice="Enable automatic price changes to rig's profit";EnableMinimumPrice="Set minimum price, instead of using a fixed price";PriceBTC="Fixed price in BTC (used, if EnableAutoPrice=0)";PriceFactor="Enter profit multiplicator: price = rig's profit x this multiplicator";PriceCurrencies="List of accepted currencies (must contain BTC)";EnableMining="Enable switching to MiningRigRentals, even it is not rentend (not recommended)";Title="Title for autocreate, %algorithm% will be substituted with algorithm";Description="Description for autocreate, %workername% will be substituted with rig's workername"}
            Currencies=@()
            Autoexchange=$true
        }
        "MintPond" = [PSCustomObject]@{
            Currencies=@("XZC")
        }
        "Nanopool" = [PSCustomObject]@{
            Fields=[PSCustomObject]@{Email=""}
            SetupFields=[PSCustomObject]@{Email="Enter your eMail-Address"}
            Currencies=@("ETH")
        }
        "NiceHash" = [PSCustomObject]@{
            Fields=[PSCustomObject]@{OrganizationID="";API_ID="";API_Key="";API_Secret="";Platform="";StatAverage="Minute_5"}
            SetupFields=[PSCustomObject]@{Platform="Select Nicehash platform (v1=old or v2=new)";OrganizationID="Enter your Nicehash Organization ID (pulls and adds NH balance)";API_ID="Enter your Nicehash API ID (pulls and adds NH balance)";API_Key = "Enter your Nicehash API key (pulls and adds NH balance)";API_Secret = "Enter your Nicehash API secret (pulls and adds NH balance)"}
            Currencies=@("BTC")
            Autoexchange=$true
        }
        "NiceHashV2" = [PSCustomObject]@{
            Fields=[PSCustomObject]@{OrganizationID="";API_Key="";API_Secret="";StatAverage="Minute_5"}
            SetupFields=[PSCustomObject]@{OrganizationID="Enter your Nicehash Organization ID (pulls and adds NH balance)";API_Key = "Enter your Nicehash API key (pulls and adds NH balance)";API_Secret = "Enter your Nicehash API secret (pulls and adds NH balance)"}
            Currencies=@("BTC")
            Autoexchange=$true
        }
        "NLPool" = [PSCustomObject]@{
            Fields=[PSCustomObject]@{Penalty=16}
            Currencies=@("BTC")
            Autoexchange=$true
            Yiimp=$true
        }
        "NLPoolCoins" = [PSCustomObject]@{
            Currencies=@("BTC")
            Autoexchange=$true
            Yiimp=$true
        }
        "PocketWhale" = [PSCustomObject]@{
            Currencies=@("XWP")
        }
        "PoolSexy" = [PSCustomObject]@{
            Currencies=@("DBIX")
        }
        "Ravenminer" = [PSCustomObject]@{
            Currencies=@("RVN")
        }
        "RPlant" = [PSCustomObject]@{
            Currencies=@("BIN","CPU","MBC")
        }
        "SparkPool" = [PSCustomObject]@{
            Currencies=@("ETH","GRIN","BEAM","XMR")
        }
        "SuprNova" = [PSCustomObject]@{
            Currencies=@("BTG")
        }
        "UUpool" = [PSCustomObject]@{
            Currencies=@("VOLLAR")
        }
        "ZergPool" = [PSCustomObject]@{
            Fields=[PSCustomObject]@{Penalty=12}
            Currencies=@("BTC")
            Autoexchange=$true
            Yiimp=$true
        }
        "ZergPoolCoins" = [PSCustomObject]@{
            Fields=[PSCustomObject]@{AECurrency=""}
            SetupFields=[PSCustomObject]@{AECurrency="Optionally define your autoexchange currency symbol"}
            Currencies=@("BTC")
            Autoexchange=$true
            Yiimp=$true
        }
        "ZergPoolCoinsParty" = [PSCustomObject]@{
            Fields=[PSCustomObject]@{AllowZero="1";PartyPassword="";AECurrency=""}
            SetupFields=[PSCustomObject]@{AECurrency="Optionally define your autoexchange currency symbol";PartyPassword="Enter your Party password"}
            Currencies=@("BTC")
            Autoexchange=$true
            Yiimp=$true
        }
        "ZergPoolCoinsSolo" = [PSCustomObject]@{
            Fields=[PSCustomObject]@{AllowZero="1";AECurrency=""}
            SetupFields=[PSCustomObject]@{AECurrency="Optionally define your autoexchange currency symbol"}
            Currencies=@("BTC")
            Autoexchange=$true
            Yiimp=$true
        }
        "ZergPoolParty" = [PSCustomObject]@{
            Fields=[PSCustomObject]@{AllowZero="1";PartyPassword=""}
            SetupFields=[PSCustomObject]@{PartyPassword="Enter your Party password"}
            Currencies=@("BTC")
            Autoexchange=$true
            Yiimp=$true
        }
        "ZergPoolSolo" = [PSCustomObject]@{
            Fields=[PSCustomObject]@{AllowZero="1"}
            Currencies=@("BTC")
            Autoexchange=$true
            Yiimp=$true
        }
        "Zpool" = [PSCustomObject]@{
            Fields=[PSCustomObject]@{Penalty=16}
            Currencies=@("BTC")
            Autoexchange=$true
            Yiimp=$true
        }
}
