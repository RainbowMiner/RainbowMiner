using module ..\Modules\Include.psm1

param(
    [PSCustomObject]$Wallets,
    [PSCustomObject]$Params,
    [alias("WorkerName")]
    [String]$Worker,
    [TimeSpan]$StatSpan,
    [String]$DataWindow = "estimate_current",
    [Bool]$InfoOnly = $false,
    [Bool]$AllowZero = $false,
    [String]$StatAverage = "Minute_10",
    [String]$StatAverageStable = "Week"
)

$Name = Get-Item $MyInvocation.MyCommand.Path | Select-Object -ExpandProperty BaseName

$Pools_Data = @(
    [PSCustomObject]@{symbol="KAS";  region=@("eu","ca","us","ru","hk","arg"); host="acc-pool.pw"; web="kaspa.acc-pool.pw"; port=@(16061,16062); fee=0.8}
    [PSCustomObject]@{symbol="NEXA"; region=@("eu","ca","us","ru","hk","arg"); host="acc-pool.pw"; web="nexa.acc-pool.pw";  port=@(16011,16012); fee=1}
)

[hashtable]$Pool_RegionsTable = @{}
$Pools_Data.region | Select-Object -Unique | Foreach-Object {$Pool_RegionsTable.$_ = Get-Region $_}

$Pools_Data | Where-Object {$Pool_Currency = $_.symbol;$Wallets.$Pool_Currency -or $InfoOnly} | ForEach-Object {
    $Pool_Coin           = Get-Coin $_.symbol

    if ($Pool_Coin) {
        $Pool_Algorithm_Norm  = $Pool_Coin.Algo
        $Pool_CoinName   = $Pool_Coin.Name
    } else {
        $Pool_Algorithm_Norm  = Get-Algorithm $PoolCoins_Request.$Pool_Currency.algo -CoinSymbol $_.symbol
        $Pool_CoinName   = $PoolCoins_Request.$Pool_Currency.name
    }

    $Pool_HR = $null

    try {
        $Pool_Request = (Invoke-WebRequestAsync "https://$($_.web)/poolstatistics/" -tag $Name -timeout 15 -cycletime 120) -split "<script>" | Where-Object {$_ -match "hashrate"} | Where-Object {$_ -match "(?ms)series:[^\[]+\[(\{.+\})\]"} | Foreach-Object {ConvertFrom-Json $Matches[1] -ErrorAction Stop}
        if ($Pool_Request.name -and $Pool_Request.data.Count) {
            $Pool_HR = ConvertFrom-Hash "$(($Pool_Request.data | Select-Object -Last 1) | Select-Object -Last 1)$($Pool_Request.name)"
            $Pool_Request = $null
        }
    } catch {
        if ($Error.Count){$Error.RemoveAt(0)}
    }

    if (-not $InfoOnly) {
        $Stat = Set-Stat -Name "$($Name)_$($_.symbol)_Profit" -Value 0 -Duration $StatSpan -ChangeDetection $false -HashRate $Pool_HR -Quiet
        if (-not $Stat.HashRate_Live -and -not $AllowZero) {return}
    }

    $Pool_User     = "$($Wallets.$Pool_Currency).{workername:$Worker}"

    $Pool_SSL = $false
    foreach($Pool_Port in $_.port) {
        $Pool_Protocol = "stratum+$(if ($Pool_SSL) {"ssl"} else {"tcp"})"
        foreach($Pool_Region in $_.region) {
            [PSCustomObject]@{
                Algorithm     = $Pool_Algorithm_Norm
			    Algorithm0    = $Pool_Algorithm_Norm
                CoinName      = $Pool_CoinName
                CoinSymbol    = $Pool_Currency
                Currency      = $Pool_Currency
                Price         = 0
                StablePrice   = 0
                MarginOfError = 0
                Protocol      = $Pool_Protocol
                Host          = "$(if ($Pool_Region -ne "eu") {"$($Pool_Region)."})$($_.host)"
                Port          = $Pool_Port
                User          = $Pool_User
                Pass          = "x"
                Region        = $Pool_RegionsTable.$Pool_Region
                SSL           = $Pool_SSL
                Updated       = $Stat.Updated
                PoolFee       = $_.fee
                Workers       = $null
                Hashrate      = $Stat.HashRate_Live
                BLK           = $null
                TSL           = $null
                WTM           = $true
                EthMode       = $null
                Name          = $Name
                Penalty       = 0
                PenaltyFactor = 1
                Disabled      = $false
                HasMinerExclusions = $false
                Price_0       = 0.0
                Price_Bias    = 0.0
                Price_Unbias  = 0.0
                Wallet        = $Wallets.$Pool_Currency
                Worker        = "{workername:$Worker}"
                Email         = $Email
            }
        }
        $Pool_SSL = $true
    }
}
