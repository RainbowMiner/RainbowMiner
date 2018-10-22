[PSCustomObject]@{
        "AHashPool" = [PSCustomObject]@{
            Currencies=@("BTC")
        }
        "BlazePool" = [PSCustomObject]@{
            Fields=[PSCustomObject]@{ExcludeAlgorithm="keccak"}
            Currencies=@("BTC")
        }
        "Blockcruncher" = [PSCustomObject]@{
            Currencies=@("RVN","PGN")            
        }
        "Blockmasters" = [PSCustomObject]@{
            Currencies=@("BTC")
        }
        "BlockmastersCoins" = [PSCustomObject]@{
            Currencies=@("BTC")
        }
        "Bsod" = [PSCustomObject]@{
            Currencies=@("RVN","SUQA")
        }
        "BsodSolo" = [PSCustomObject]@{
            Fields=[PSCustomObject]@{AllowZero="1"}
            Currencies=@("RVN","SUQA")
        }
        "CrypoKnight" = [PSCustomObject]@{
            Currencies=@("WOW")
        }
        "Ethermine" = [PSCustomObject]@{
            Currencies=@("ETH")
        }
        "Hashrefinery" = [PSCustomObject]@{
            Currencies=@("BTC")
        }
        "Icemining" = [PSCustomObject]@{
            Currencies=@("BCD","RVN","SUQA")
        }
        "MinerRocks" = [PSCustomObject]@{
            Currencies=@("XMR")
        }
        "MiningPoolHub" = [PSCustomObject]@{
            Fields=[PSCustomObject]@{User="`$UserName";API_ID="`$API_ID";API_Key="`$API_Key";AECurrency="BTC"}
            SetupFields=[PSCustomObject]@{User="Enter your MiningPoolHub username (leave empty to use config.txt default)";API_ID="Enter your MiningPoolHub user ID (leave empty to use config.txt default)";API_Key = "Enter your MiningPoolHub API key (leave empty to use config.txt default)";AECurrency = "Enter your MiningPoolHub autoexchange currency"}
            Currencies=@()
        }
        "MiningPoolHubCoins" = [PSCustomObject]@{
            Fields=[PSCustomObject]@{User="`$UserName";API_ID="`$API_ID";API_Key="`$API_Key";AECurrency="BTC"}
            SetupFields=[PSCustomObject]@{User="Enter your MiningPoolHub username (leave empty to use config.txt default)";API_ID="Enter your MiningPoolHub user ID (leave empty to use config.txt default)";API_Key = "Enter your MiningPoolHub API key (leave empty to use config.txt default)";AECurrency = "Enter your MiningPoolHub autoexchange currency"}
            Currencies=@()
        }
        "MiningRigRentals" = [PSCustomObject]@{
            Fields=[PSCustomObject]@{User="";API_Key="";API_Secret=""}
            SetupFields=[PSCustomObject]@{User="Enter your MiningRigRentals username";API_Key="Enter your MiningRigRentals API key";API_Secret = "Enter your MiningPoolHub API secret key"}
            Currencies=@()
        }
        "Nanopool" = [PSCustomObject]@{
            Currencies=@("ETH")
        }
        "NiceHash" = [PSCustomObject]@{
            Currencies=@("BTC")
        }
        "NLPool" = [PSCustomObject]@{
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
        "Zpool" = [PSCustomObject]@{
            Currencies=@("BTC")
        }
}
