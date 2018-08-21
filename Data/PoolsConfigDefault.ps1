[PSCustomObject]@{
        "AHashPool" = [PSCustomObject]@{
            Currencies=@("BTC")
        }
        "BlazePool" = [PSCustomObject]@{
            Fields=[PSCustomObject]@{DataWindow="average";ExcludeAlgorithm="keccak"}
            Currencies=@("BTC")
        }
        "Blockcruncher" = [PSCustomObject]@{
            Currencies=@("PGN")            
        }
        "Blockmasters" = [PSCustomObject]@{
            Currencies=@("BTC")
        }
        "BlockmastersCoins" = [PSCustomObject]@{
            Currencies=@("BTC")
        }
        "Bsod" = [PSCustomObject]@{
            Fields=[PSCustomObject]@{DataWindow="actual_last24h"}
            Currencies=@("RVN","PGN")
        }
        "Hashrefinery" = [PSCustomObject]@{
            Currencies=@("BTC")
        }
        "MiningPoolHub" = [PSCustomObject]@{
            Fields=[PSCustomObject]@{User="`$UserName";API_ID="`$API_ID";API_Key="`$API_Key"}
            Currencies=@()
        }
        "MiningPoolHubCoins" = [PSCustomObject]@{
            Fields=[PSCustomObject]@{User="`$UserName";API_ID="`$API_ID";API_Key="`$API_Key"}
            Currencies=@()
        }
        "NiceHash" = [PSCustomObject]@{
            Currencies=@("BTC")
        }
        "PhiPhiPool" = [PSCustomObject]@{
            Currencies=@("BTC")
        }
        "Ravenminer" = [PSCustomObject]@{
            Fields=[PSCustomObject]@{DataWindow="actual_last24h"}
            Currencies=@("RVN")
        }
        "YiiMP" = [PSCustomObject]@{
            Currencies=@()
        }
        "ZergPool" = [PSCustomObject]@{
            Fields=[PSCustomObject]@{DataWindow="minimum"}
            Currencies=@("BTC")
        }
        "ZergPoolCoins" = [PSCustomObject]@{
            Fields=[PSCustomObject]@{DataWindow="minimum"}
            Currencies=@("BTC")
        }
        "Zpool" = [PSCustomObject]@{
            Currencies=@("BTC")
        }
}
