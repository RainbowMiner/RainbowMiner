using module ..\Modules\Include.psm1

param(
    [String]$Name,
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
    [String]$UseWorkerName = "",
    [String]$ExcludeWorkerName = "",
    [String]$EnableMiningSwitch = $false
)

$CoinSymbol = $Session.Config.Pools.$Name.CoinSymbol
$ExcludeCoinSymbol = $Session.Config.Pools.$Name.ExcludeCoinSymbol

# $Name = Get-Item $MyInvocation.MyCommand.Path | Select-Object -ExpandProperty BaseName

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
$Pool_EthProxy = "ethstratumnh"

$Coins_Request = [PSCustomObject]@{}

try {
    $Coins_Request = Invoke-RestMethodAsync "https://api.gtpool.io/v2/coin/list?key=$($API_Key)" -requestmethod "POST" -retry 3 -retrywait 1000 -tag $Name -cycletime 120
}
catch {
    Write-Log -Level Warn "Pool Coins API ($Name) has failed. "
    return
}

if (-not $Coins_Request.result) {
    Write-Log -Level Warn "Pool Coins API ($Name) returned nothing. "
    return
}

$Mining_Request = [PSCustomObject]@{}

try {
    $Mining_Request = Invoke-RestMethodAsync "https://api.gtpool.io/v2/mining/list?key=$($API_Key)" -requestmethod "POST" -retry 3 -retrywait 1000 -tag $Name -cycletime 3600
}
catch {
    Write-Log -Level Warn "Pool Mining API ($Name) has failed. "
    return
}


if (-not $Mining_Request.result) {
    Write-Log -Level Warn "Pool Mining API ($Name) returned nothing. "
    return
}

[hashtable]$Pool_RegionsTable = @{}

$Pool_Regions = @("ru","eu-de","eu-fr","eu-fi","us-west","us-east","sg","hk")
$Pool_Regions | Foreach-Object {$Pool_RegionsTable.$_ = Get-Region $_}

if (-not $InfoOnly) {

    $Workers     = @($Session.Config.DeviceModel | Where-Object {$Session.Config.Devices.$_.Worker} | Foreach-Object {$Session.Config.Devices.$_.Worker} | Select-Object -Unique) + $Worker | Select-Object -Unique

    $UseWorkerName_Array     = @($UseWorkerName   -split "[,; ]+" | Where-Object {$_} | Select-Object -Unique)
    $ExcludeWorkerName_Array = @($ExcludeWorkerName -split "[,; ]+" | Where-Object {$_} | Select-Object -Unique)

    if ($UseWorkerName_Array.Count -or $ExcludeWorkerName_Array.Count) {
        $Workers = @($Workers | Where-Object {($UseWorkerName_Array.Count -eq 0 -or $UseWorkerName_Array -contains $_) -and ($ExcludeWorkerName_Array.Count -eq 0 -or $ExcludeWorkerName_Array -notcontains $_)})
    }

    if (-not $Workers.Count) {return}

    $AllCoins_Request   = $Coins_Request.payload | Where-Object {$_.status -and (-not $CoinSymbol -or $CoinSymbol -contains $_.coin) -and (-not $ExcludeCoinSymbol -or $ExcludeCoinSymbol -notcontains $_.coin)} | Sort-Object -Descending {$_.profit.forecast/$_.profit.hashrate}

    if ($AllCoins_Request) {

        $Workers_Request = [PSCustomObject]@{}

        try {
            $Workers_Request = Invoke-RestMethodAsync "https://api.gtpool.io/v2/worker/list?key=$($API_Key)" -requestmethod "POST" -retry 3 -retrywait 1000 -tag $Name -cycletime 120
        }
        catch {
            Write-Log -Level Warn "Pool Workers API ($Name) has failed. "
            return
        }


        if (-not $Workers_Request.result) {
            Write-Log -Level Warn "Pool Workers API ($Name) returned nothing. "
            return
        }

        $Worker_Count = 0

        $EnableMiningSwitch_bool = Get-Yes $EnableMiningSwitch

        foreach($Worker1 in $Workers) {

            $Current_Worker = $Workers_Request.payload | Where-Object {$_.name -eq $Worker1} | Select-Object -First 1

            if ($Current_Worker) {

                $Pool_Model = if ($Worker1 -ne $Worker) {"$(($Session.Config.DeviceModel | Where-Object {$Session.Config.Devices.$_.Worker -eq $Worker1} | Sort-Object -Unique) -join '-')"} elseif ($Global:DeviceCache.DeviceNames.CPU -ne $null) {"GPU"}

                $Pool_Coin = Get-Coin $Current_Worker.coin.ticker

                $Pool_CoinSymbol = $Pool_Coin.symbol
                $Pool_CoinName   = $Pool_Coin.name
                $Pool_Algorithm_Norm  = $Pool_Coin.algo

                $Current_Coin = $AllCoins_Request | Where-Object {$_.ticker -eq $Pool_CoinSymbol}

                $BestCoin_Request = $AllCoins_Request | Select-Object -First 1

                if (-not $Current_Coin -or ($EnableMiningSwitch_bool -and $BestCoin_Request.ticker -ne $Pool_CoinSymbol)) {
                    $BestCoin_Mining = $Mining_Request.payload | Where-Object {$_.coin.ticker -eq $BestCoin_Request.ticker -and $_.config -match "PPLN"} | Select-Object -First 1
                    $Switch_Request = [PSCustomObject]@{}
                    try {
                        $Switch_Request = Invoke-GetUrl "https://api.gtpool.io/v2/mining/change?key=$($API_Key)" -body "{`"method`":`"change_mining`",`"workers`":[`"$($Current_Worker.uniq)`"],`"mining`":`"$($BestCoin_Mining.uniq)`"}"
                    }
                    catch {
                        Write-Log -Level Warn "Pool Change Mining API ($Name) has failed. "
                        return
                    }

                    if (-not $Switch_Request.result) {
                        Write-Log -Level Warn "Pool Change Mining API ($Name) returned nothing. "
                    } else {
                        $Current_Coin = $BestCoin_Request

                        $Pool_Coin = Get-Coin $Current_Coin.ticker

                        $Pool_CoinSymbol = $Pool_Coin.symbol
                        $Pool_CoinName   = $Pool_Coin.name
                        $Pool_Algorithm_Norm  = $Pool_Coin.algo
                    }
                }

                if (-not $Current_Coin) {return}

                $Pool_Algorithm_Norm_With_Model = "$Pool_Algorithm_Norm$(if ($Pool_Model) {"-$Pool_Model"})"
                $Pool_TSL = (Get-UnixTimestamp) - [int]$Current_Coin.pool.lastBlockTime

                $Stat = [PSCustomObject]@{}

                if (-not $Worker_Count) {
                    foreach ($Coin_Request in $AllCoins_Request) {
                        $Pool_HR = [int64]$Coin_Request.pool.workersHashrate
                        $Pool_BLK = if ($Coin_Request.chain.hashrate -and $Coin_Request.chain.blockTime) {$Coin_Request.pool.workersHashrate/$Coin_Request.chain.hashrate * 86400 / $Coin_Request.chain.blockTime} else {0}
                        $Pool_PriceUsd = $Coin_Request.profit.forecast / 1e8 / $Coin_Request.profit.hashrate * 86400 / $Coin_Request.profit.interval * $Coin_Request.priceUsd
                        $Pool_PriceBtc = if ($Global:Rates["USD"]) {$Pool_PriceUsd / $Global:Rates["USD"]} else {0}
                        $Stat0 = Set-Stat -Name "$($Name)_$($Coin_Request.ticker)_Profit" -Value $Pool_PriceBtc -Duration $StatSpan -ChangeDetection $false -HashRate $Pool_HR -BlockRate $Pool_BLK -Quiet
                        if ($Coin_Request.ticker -eq $Current_Coin.ticker) {
                            $Stat = $Stat0
                        }
                    }
                } else {
                    $Pool_HR = [int64]$Current_Coin.pool.workersHashrate
                    $Pool_BLK = if ($Current_Coin.chain.hashrate -and $Current_Coin.chain.blockTime) {$Current_Coin.pool.workersHashrate/$Current_Coin.chain.hashrate * 86400 / $Current_Coin.chain.blockTime} else {0}
                    $Pool_PriceUsd = $Current_Coin.profit.forecast / 1e8 / $Current_Coin.profit.hashrate * 86400 / $Current_Coin.profit.interval * $Current_Coin.priceUsd
                    $Pool_PriceBtc = if ($Global:Rates["USD"]) {$Pool_PriceUsd / $Global:Rates["USD"]} else {0}
                    $Stat = Set-Stat -Name "$($Name)_$($Current_Coin.ticker)_Profit" -Value $Pool_PriceBtc -Duration $StatSpan -ChangeDetection $false -HashRate $Pool_HR -BlockRate $Pool_BLK -Quiet
                }

                $Worker_Count++

                if (-not $Stat.HashRate_Live -and -not $AllowZero) {return}

                foreach ($Pool_SSL in @($false,$true)) {
                    $Pool_Stratum = "stratum+$(if ($Pool_SSL) {"ssl"} else {"tcp"})"
                    $Pool_Port    = if ($Pool_SSL) {9009} else {9999}
                    foreach($Pool_Region in $Pool_Regions) {
                        [PSCustomObject]@{
                            Algorithm     = $Pool_Algorithm_Norm_With_Model
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
                            User          = "$($Account_Id).{workername:$Worker1}"
                            Pass          = "x$Pool_Params"
                            Region        = $Pool_RegionsTable.$Pool_Region
                            SSL           = $Pool_SSL
                            Updated       = $Stat.Updated
                            PoolFee       = $Pool_Fee
                            DataWindow    = $DataWindow
                            Workers       = [int]$Current_Coin.pool.workersCount
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
                            Worker        = "{workername:$Worker1}"
                            Email         = $Email
                        }
                    }
                }
            }
        }
    }
} else {
    $AllCoins_Request   = $Coins_Request.payload | Where-Object {$_.status}

    foreach ($Current_Coin in $AllCoins_Request) {

        $Pool_Coin = Get-Coin $Current_Coin.ticker

        $Pool_CoinSymbol = $Current_Coin.ticker
        $Pool_CoinName   = $Pool_Coin.name
        $Pool_Algorithm_Norm  = $Pool_Coin.algo

        $Pool_TSL            = (Get-UnixTimestamp) - [int]$Current_Coin.pool.lastBlockTime

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
                    Workers       = [int]$Current_Coin.pool.workersCount
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
