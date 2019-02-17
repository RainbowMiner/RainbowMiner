[PSCustomObject]@{
        "2Miners" = [PSCustomObject]@{
            Currencies=@("XZC")
        }
        "2MinersSolo" = [PSCustomObject]@{
            Currencies=@("XZC")
        }
        "AHashPool" = [PSCustomObject]@{
            Fields=[PSCustomObject]@{Penalty=15}
            Currencies=@("BTC")
        }
        "BlazePool" = [PSCustomObject]@{
            Fields=[PSCustomObject]@{ExcludeAlgorithm="keccak";Penalty=15}
            Currencies=@("BTC")
        }
        "Blockcruncher" = [PSCustomObject]@{
            Currencies=@("RVN")            
        }
        "Blockmasters" = [PSCustomObject]@{
            Fields=[PSCustomObject]@{Penalty=15}
            Currencies=@("BTC")
        }
        "BlockmastersCoins" = [PSCustomObject]@{
            Currencies=@("BTC")
        }
        "Bsod" = [PSCustomObject]@{
            Currencies=@("RVN","SUQA")
        }
        "BsodParty" = [PSCustomObject]@{
            Fields=[PSCustomObject]@{AllowZero="1";PartyPassword=""}
            SetupFields=[PSCustomObject]@{PartyPassword="Enter your Party password"}
            Currencies=@("RVN","SUQA")
        }
        "BsodSolo" = [PSCustomObject]@{
            Fields=[PSCustomObject]@{AllowZero="1"}
            Currencies=@("RVN","SUQA")
        }
        "CryptoKnight" = [PSCustomObject]@{
            Currencies=@("XWP")
        }
        "Ethermine" = [PSCustomObject]@{
            Currencies=@("ETH")
        }
        "FairPool" = [PSCustomObject]@{
            Currencies=@("XWP")
        }
        "GosCx" = [PSCustomObject]@{
            Currencies=@("GIN")
        }
        "GosCxParty" = [PSCustomObject]@{
            Fields=[PSCustomObject]@{AllowZero="1";PartyPassword=""}
            SetupFields=[PSCustomObject]@{PartyPassword="Enter your Party password"}
            Currencies=@("GIN")
        }
        "GosCxSolo" = [PSCustomObject]@{
            Fields=[PSCustomObject]@{AllowZero="1"}
            Currencies=@("GIN")
        }
        "Grinmint" = [PSCustomObject]@{
            Fields=[PSCustomObject]@{Password="x"}
            SetupFields=[PSCustomObject]@{Password="Enter your Grinmint password"}
            Currencies=@("GRIN")
        }
        "Hashrefinery" = [PSCustomObject]@{
            Currencies=@("BTC")
        }
        "Icemining" = [PSCustomObject]@{
            Currencies=@("BCD","RVN","SUQA")
        }
        "MinerMore" = [PSCustomObject]@{
            Currencies=@("RVN","SUQA")
        }
        "MinerRocks" = [PSCustomObject]@{
            Currencies=@("XMR")
        }
        "MiningPoolHub" = [PSCustomObject]@{
            Fields=[PSCustomObject]@{User="`$UserName";API_ID="`$API_ID";API_Key="`$API_Key";AECurrency="BTC";Penalty=12}
            SetupFields=[PSCustomObject]@{User="Enter your MiningPoolHub username (leave empty to use config.txt default)";API_ID="Enter your MiningPoolHub user ID (leave empty to use config.txt default)";API_Key = "Enter your MiningPoolHub API key (leave empty to use config.txt default)";AECurrency = "Enter your MiningPoolHub autoexchange currency"}
            Currencies=@()
        }
        "MiningPoolHubCoins" = [PSCustomObject]@{
            Fields=[PSCustomObject]@{User="`$UserName";API_ID="`$API_ID";API_Key="`$API_Key";AECurrency="BTC"}
            SetupFields=[PSCustomObject]@{User="Enter your MiningPoolHub username (leave empty to use config.txt default)";API_ID="Enter your MiningPoolHub user ID (leave empty to use config.txt default)";API_Key = "Enter your MiningPoolHub API key (leave empty to use config.txt default)";AECurrency = "Enter your MiningPoolHub autoexchange currency"}
            Currencies=@()
        }
        "MiningRigRentals" = [PSCustomObject]@{
            Fields=[PSCustomObject]@{User="";API_Key="";API_Secret="";EnableMining="0"}
            SetupFields=[PSCustomObject]@{User="Enter your MiningRigRentals username";API_Key="Enter your MiningRigRentals API key";API_Secret = "Enter your MiningRigRentals API secret key";EnableMining="Enable switching to MiningRigRentals, even it is not rentend (not recommended)"}
            Currencies=@()
        }
        "MintPond" = [PSCustomObject]@{
            Currencies=@("XZC")
        }
        "Nanopool" = [PSCustomObject]@{
            Currencies=@("ETH")
        }
        "NiceHash" = [PSCustomObject]@{
            Fields=[PSCustomObject]@{API_ID="";API_Key="";StatAverage="Minute_5"}
            SetupFields=[PSCustomObject]@{API_ID="Enter your Nicehash API ID (pulls and adds NH balance)";API_Key = "Enter your Nicehash Readonly API key  (pulls and adds NH balance)"}
            Currencies=@("BTC")
        }
        "NLPool" = [PSCustomObject]@{
            Fields=[PSCustomObject]@{Penalty=12}
            Currencies=@("BTC")
        }
        "NLPoolCoins" = [PSCustomObject]@{
            Currencies=@("BTC")
        }
        "PhiPhiPool" = [PSCustomObject]@{
            Currencies=@("BTC")
        }
        "Ravenminer" = [PSCustomObject]@{
            Currencies=@("RVN")
        }
        "RavenminerEu" = [PSCustomObject]@{
            Currencies=@("RVN")
        }
        "StarPool" = [PSCustomObject]@{
            Currencies=@("BTC")
        }
        "YiiMP" = [PSCustomObject]@{
            Currencies=@("RVN","SUQA")
        }
        "ZergPool" = [PSCustomObject]@{
            Fields=[PSCustomObject]@{Penalty=12}
            Currencies=@("BTC")
        }
        "ZergPoolCoins" = [PSCustomObject]@{
            Currencies=@("BTC")
        }
        "ZergPoolParty" = [PSCustomObject]@{
            Fields=[PSCustomObject]@{AllowZero="1";PartyPassword=""}
            SetupFields=[PSCustomObject]@{PartyPassword="Enter your Party password"}
            Currencies=@("BTC")
        }
        "ZergPoolSolo" = [PSCustomObject]@{
            Fields=[PSCustomObject]@{AllowZero="1"}
            Currencies=@("BTC")
        }
        "Zpool" = [PSCustomObject]@{
            Fields=[PSCustomObject]@{Penalty=12}
            Currencies=@("BTC")
        }
}
