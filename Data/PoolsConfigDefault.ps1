[PSCustomObject]@{
        "AHashPool" = [PSCustomObject]@{
            Fields=[PSCustomObject]@{DataWindow="average"}
            Currencies=@("BTC")
        }
        "BlazePool" = [PSCustomObject]@{
            Fields=[PSCustomObject]@{DataWindow="average";ExcludeAlgorithm="keccak"}
            Currencies=@("BTC")
        }
        "Blockcruncher" = [PSCustomObject]@{
            Fields=[PSCustomObject]@{DataWindow="average"}
            Currencies=@("PGN")            
        }
        "Blockmasters" = [PSCustomObject]@{
            Fields=[PSCustomObject]@{DataWindow="average"}
            Currencies=@("BTC")
        }
        "BlockmastersCoins" = [PSCustomObject]@{
            Fields=[PSCustomObject]@{DataWindow="average"}
            Currencies=@("BTC")
        }
        "Bsod" = [PSCustomObject]@{
            Fields=[PSCustomObject]@{DataWindow="average"}
            Currencies=@("RVN","PGN")
        }
        "Hashrefinery" = [PSCustomObject]@{
            Fields=[PSCustomObject]@{DataWindow="average"}
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
            Fields=[PSCustomObject]@{DataWindow="average"}
            Currencies=@("BTC")
        }
        "Ravenminer" = [PSCustomObject]@{
            Fields=[PSCustomObject]@{DataWindow="average"}
            Currencies=@("RVN")
        }
        "YiiMP" = [PSCustomObject]@{
            Fields=[PSCustomObject]@{DataWindow="average"}
            Currencies=@()
        }
        "ZergPool" = [PSCustomObject]@{
            Fields=[PSCustomObject]@{DataWindow="average"}
            Currencies=@("BTC")
        }
        "ZergPoolCoins" = [PSCustomObject]@{
            Fields=[PSCustomObject]@{DataWindow="average"}
            Currencies=@("BTC")
        }
        "Zpool" = [PSCustomObject]@{
            Fields=[PSCustomObject]@{DataWindow="average"}
            Currencies=@("BTC")
        }
}
