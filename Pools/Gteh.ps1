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
    [String]$StatAverageStable = "Week",
    [String]$Account_Id = "",
    [String]$API_Key = "",
    [String]$EnableMiningSwitch = $false

)

$Name = Get-Item $MyInvocation.MyCommand.Path | Select-Object -ExpandProperty BaseName

if ($InfoOnly) {$API_Key = "XHJfbTPhG47UL1hFGU7orTR"}

$ok = $true
if (-not $API_Key) {
    Write-Log -Level Warn "Pool $($Name) API_Key not set"
    $ok = $false
}

if (-not $Account_Id -and -not $InfoOnly) {
    Write-Log -Level Warn "Pool $($Name) Account_Id not set"
    $ok = $false
}

if (-not $ok) {return}

$Pool_Fee = 1.0
$Pool_EthProxy = "stratum"

$Coins_Request = [PSCustomObject]@{}

try {
    $Coins_Request = Invoke-RestMethodAsync "https://api.gteh.org/?key=$($API_Key)" -body '{"method":"coins_list"}' -retry 3 -retrywait 1000 -tag $Name -cycletime 120
}
catch {
    if ($Error.Count){$Error.RemoveAt(0)}
    Write-Log -Level Warn "Pool Coins API ($Name) has failed. "
    return
}

if (-not $Coins_Request.result) {
    Write-Log -Level Warn "Pool Coins API ($Name) returned nothing. "
    return
}

$Mining_Request = [PSCustomObject]@{}

try {
    $Mining_Request = Invoke-RestMethodAsync "https://api.gteh.org/?key=$($API_Key)" -body '{"method":"mining_list"}' -retry 3 -retrywait 1000 -tag $Name -cycletime 3600
}
catch {
    if ($Error.Count){$Error.RemoveAt(0)}
    Write-Log -Level Warn "Pool Mining API ($Name) has failed. "
    return
}


if (-not $Mining_Request.result) {
    Write-Log -Level Warn "Pool Mining API ($Name) returned nothing. "
    return
}

[hashtable]$Pool_RegionsTable = @{}

$Pool_Regions = @("ru","eu","us","sg","hk")
$Pool_Regions | Foreach-Object {$Pool_RegionsTable.$_ = Get-Region $_}

if (-not $InfoOnly) {

    $Workers_Request = [PSCustomObject]@{}

    try {
        $Workers_Request = Invoke-RestMethodAsync "https://api.gteh.org/?key=$($API_Key)" -body '{"method":"workers_list"}' -retry 3 -retrywait 1000 -tag $Name -cycletime 120
    }
    catch {
        if ($Error.Count){$Error.RemoveAt(0)}
        Write-Log -Level Warn "Pool Workers API ($Name) has failed. "
        return
    }


    if (-not $Workers_Request.result) {
        Write-Log -Level Warn "Pool Workers API ($Name) returned nothing. "
        return
    }

    $Current_Worker     = $Workers_Request.data | Where-Object {$_.name -eq $Worker} | Select-Object -First 1

    if (-not $Current_Worker) {
        Write-Log -Level Warn "Pool ($Name): create a worker on gteh.org with the name `"$($Worker)`" first!"
        return
    }

    $AllCoins_Request   = $Coins_Request.data | Where-Object {$_.active -and (-not $CoinSymbol -or $CoinSymbol -contains $_.coin) -and (-not $ExcludeCoinSymbol -or $ExcludeCoinSymbol -notcontains $_.coin)} | Sort-Object -Descending {$_.profit.revenue_usd}

    if ($AllCoins_Request) {

        $Pool_Coin = Get-Coin $Current_Worker.coin

        $Pool_CoinSymbol = $Pool_Coin.symbol
        $Pool_CoinName   = $Pool_Coin.name
        $Pool_Algorithm  = $Pool_Coin.algo

        $Current_Coin = $AllCoins_Request | Where-Object {$_.coin -eq $Pool_CoinSymbol}

        $BestCoin_Request = $AllCoins_Request | Select-Object -First 1

        if (-not $CurrentCoin -or ($EnableMiningSwitch -and $BestCoin_Request.coin -ne $Pool_CoinSymbol)) {
            $BestCoin_Mining = $Mining_Request.data | Where-Object {$_.coin -eq $BestCoin_Request.coin -and $_.mining -match "PPLN"} | Select-Object -First 1
            $Switch_Request = [PSCustomObject]@{}
            try {
                $Switch_Request = Invoke-GetUrl "https://api.gteh.org/?key=$($API_Key)" -body "{`"method`":`"change_mining`",`"workers`":[`"$($Current_Worker.uniq)`"],`"mining`":`"$($BestCoin_Mining.uniq)`"}"
            }
            catch {
                if ($Error.Count){$Error.RemoveAt(0)}
                Write-Log -Level Warn "Pool Change Mining API ($Name) has failed. "
                return
            }

            if (-not $Switch_Request.result) {
                Write-Log -Level Warn "Pool Change Mining API ($Name) returned nothing. "
            } else {
                $Current_Coin = $BestCoin_Request

                $Pool_Coin = Get-Coin $Current_Coin.coin

                $Pool_CoinSymbol = $Pool_Coin.symbol
                $Pool_CoinName   = $Pool_Coin.name
                $Pool_Algorithm  = $Pool_Coin.algo
            }
        }

        if (-not $Current_Coin) {return}

        $Pool_Algorithm_Norm = Get-Algorithm $Pool_Algorithm
        $Pool_TSL            = (Get-UnixTimestamp) - [int]$Current_Coin.lastPoolBlockTimestamp

        if (-not $InfoOnly) {
            $Stat = [PSCustomObject]@{}

            foreach ($Coin_Request in $AllCoins_Request) {
                $Pool_HR = [int]$Coin_Request.profit.hashrate
                $Pool_PriceUsd = if ($Pool_HR) {$Coin_Request.profit.revenue_usd / $Pool_HR * $Coin_Request.profit.minutes / 1440} else {0}
                $Pool_PriceBtc = if ($Global:Rates["USD"]) {$Pool_PriceUsd / $Global:Rates["USD"]} else {0}
                $Stat0 = Set-Stat -Name "$($Name)_$($Coin_Request.coin)_Profit" -Value $Pool_PriceBtc -Duration $StatSpan -ChangeDetection $false -HashRate $Coin_Request.workers.hashrate_pplnt -BlockRate $([double]$Coin_Request.profit.coins) -Quiet
                if ($Coin_Request.coin -eq $Current_Coin.coin) {
                    $Stat = $Stat0
                }
            }
            if (-not $Stat.HashRate_Live -and -not $AllowZero) {return}
        }

        foreach ($Pool_SSL in @($false,$true)) {
            $Pool_Stratum = "stratum+$(if ($Pool_SSL) {"ssl"} else {"tcp"})"
            $Pool_Port    = if ($Pool_SSL) {9009} else {9999}
            foreach($Pool_Region in $Pool_Regions) {
                [PSCustomObject]@{
                    Algorithm     = $Pool_Algorithm_Norm
                    Algorithm0    = $Pool_Algorithm_Norm
                    CoinName      = $Pool_CoinName
                    CoinSymbol    = $Pool_CoinSymbol
                    Currency      = $Pool_CoinSymbol
                    Price         = $Stat.$StatAverage #instead of .Live
                    StablePrice   = $Stat.$StatAverageStable
                    MarginOfError = $Stat.Week_Fluctuation
                    Protocol      = $Pool_Stratum
                    Host          = "$($Pool_Region).gteh.org"
                    Port          = $Pool_Port
                    User          = "$($Account_Id).{workername:$Worker}"
                    Pass          = "x$Pool_Params"
                    Region        = $Pool_RegionsTable.$Pool_Region
                    SSL           = $Pool_SSL
                    Updated       = $Stat.Updated
                    PoolFee       = $Pool_Fee
                    DataWindow    = $DataWindow
                    Workers       = [int]$Current_Coin.workers.workers_pplnt
                    TSL           = $Pool_TSL
                    BLK           = $Stat.BlockRate_Average
                    EthMode       = $Pool_EthProxy
                    Hashrate      = $Stat.HashRate_Live
				    ErrorRatio    = $Stat.ErrorRatio
                    Name          = $Name
                    Penalty       = 0
                    PenaltyFactor = 1
                    Disabled      = $false
                    HasMinerExclusions = $false
                    Price_0       = 0.0
                    Price_Bias    = 0.0
                    Price_Unbias  = 0.0
                    Wallet        = $Account_Id
                    Worker        = "{workername:$Worker}"
                    Email         = $Email
                }
            }
        }
    }
} else {
    $AllCoins_Request   = $Coins_Request.data | Where-Object {$_.active}

    foreach ($Current_Coin in $AllCoins_Request) {

        $Pool_Coin = Get-Coin $Current_Coin.coin

        $Pool_CoinSymbol = $Current_Coin.coin
        $Pool_CoinName   = $Pool_Coin.name
        $Pool_Algorithm  = $Pool_Coin.algo

        $Pool_Algorithm_Norm = Get-Algorithm $Pool_Algorithm
        $Pool_TSL            = (Get-UnixTimestamp) - [int]$Current_Coin.lastPoolBlockTimestamp

        foreach ($Pool_SSL in @($false,$true)) {
            $Pool_Stratum = "stratum+$(if ($Pool_SSL) {"ssl"} else {"tcp"})"
            $Pool_Port    = if ($Pool_SSL) {9009} else {9999}
            foreach($Pool_Region in $Pool_Regions) {
                [PSCustomObject]@{
                    Algorithm     = $Pool_Algorithm_Norm
                    Algorithm0    = $Pool_Algorithm_Norm
                    CoinName      = $Pool_CoinName
                    CoinSymbol    = $Pool_CoinSymbol
                    Currency      = $Pool_CoinSymbol
                    Price         = $Stat.$StatAverage #instead of .Live
                    StablePrice   = $Stat.$StatAverageStable
                    MarginOfError = $Stat.Week_Fluctuation
                    Protocol      = $Pool_Stratum
                    Host          = "$($Pool_Region).gteh.org"
                    Port          = $Pool_Port
                    User          = "$($Account_Id).{workername:$Worker}"
                    Pass          = "x$Pool_Params"
                    Region        = $Pool_RegionsTable.$Pool_Region
                    SSL           = $Pool_SSL
                    Updated       = $Stat.Updated
                    PoolFee       = $Pool_Fee
                    DataWindow    = $DataWindow
                    Workers       = [int]$Current_Coin.workers.workers_pplnt
                    TSL           = $Pool_TSL
                    BLK           = $Stat.BlockRate_Average
                    EthMode       = $Pool_EthProxy
                    Hashrate      = $Stat.HashRate_Live
				    ErrorRatio    = $Stat.ErrorRatio
                    Name          = $Name
                    Penalty       = 0
                    PenaltyFactor = 1
                    Disabled      = $false
                    HasMinerExclusions = $false
                    Price_0       = 0.0
                    Price_Bias    = 0.0
                    Price_Unbias  = 0.0
                    Wallet        = $Account_Id
                    Worker        = "{workername:$Worker}"
                    Email         = $Email
                }
            }
        }
    }
}