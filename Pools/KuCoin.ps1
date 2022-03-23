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

$Pool_Request = [PSCustomObject]@{}
try {
    $Pool_Request = Invoke-RestMethodAsync "https://www.kucoin.com/_api/miningpool/algo/coin-info-list?lang=en_US" -tag $Name -cycletime 120
}
catch {
    if ($Error.Count){$Error.RemoveAt(0)}
}

if (-not $Pool_Request.success -or $Pool_Request.code -ne 200) {
    Write-Log -Level Warn "Pool API ($Name) has failed. "
    return
}

$Pool_Request = $Pool_Request.data | Where-Object {$_.algoName -eq "Ethash"}

$Pools_Data = @(
    [PSCustomObject]@{host = "ethash.kupool.com"; symbol = "ETH"; port = @(8888)}
)

$Pools_Data | Where-Object {$Pool_Currency = $_.symbol;$Pool_CoinInfo = $Pool_Request.coinInfoList | Where-Object {$_.coinName -eq $Pool_Currency};$Pool_CoinInfo -and ($Wallets.$Pool_Currency -or $InfoOnly)} | ForEach-Object {
    $Pool_Coin  = Get-Coin $_.symbol
    $Pool_Ports = $_.port
    $Pool_Algorithm_Norm = Get-Algorithm $Pool_Coin.Algo

    $Pool_EthProxy = if ($Pool_Algorithm_Norm -match $Global:RegexAlgoHasEthproxy) {"qtminer"} elseif ($Pool_Algorithm_Norm -match $Global:RegexAlgoIsProgPow) {"stratum"} else {$null}

    $PoolCoin_Request = [PSCustomObject]@{}

    $ok = $true
    if (-not $InfoOnly) {
        $ok = $false
        $Pool_Price = 0
        try {
            $PoolCoin_Request = Invoke-RestMethodAsync "https://www.kucoin.com/_api/miningpool/coin/coin-info?lang=en_US&coinId=$($Pool_CoinInfo.coinId)&algoId=$($Pool_Request.algoId)" -tag $Name -cycletime 120
            $ok = $PoolCoin_Request.success -and $PoolCoin_Request.code -eq 200
            if ($ok -and $Global:Rates.$Pool_Currency) {
                $Pool_Price = [double]$PoolCoin_Request.data.unitDailyEarn / (ConvertFrom-Hash "1$($PoolCoin_Request.data.unit -replace "^.+/")") / $Global:Rates.$Pool_Currency
            }
        }
        catch {
            if ($Error.Count){$Error.RemoveAt(0)}
        }
        if ($ok) {
            $Pool_BLK = if ($PoolCoin_Request.data.difficulty) {[double]$Pool_Request.poolHashRate * 86500 / $PoolCoin_Request.data.difficulty} else {0}
            $Stat = Set-Stat -Name "$($Name)_$($Pool_Currency)_Profit" -Value $Pool_Price -Duration $StatSpan -ChangeDetection $false -HashRate $Pool_Request.poolHashRate -BlockRate $Pool_BLK -Quiet
        } else {
            Write-Log -Level Warn "Pool Coin API ($Name) has failed for $($Pool_Currency) "
        }
        if (-not $Stat.HashRate_Live -and -not $AllowZero) {return}
    }
    

    if ($ok) {
        $Pool_Ssl = $false
        foreach($Pool_Port in $Pool_Ports) {
            [PSCustomObject]@{
                Algorithm     = $Pool_Algorithm_Norm
                Algorithm0    = $Pool_Algorithm_Norm
                CoinName      = $Pool_Coin.Name
                CoinSymbol    = $Pool_Currency
                Currency      = $Pool_Currency
                Price         = $Stat.$StatAverage #instead of .Live
                StablePrice   = $Stat.$StatAverageStable
                MarginOfError = $Stat.Week_Fluctuation
                Protocol      = "stratum+$(if ($Pool_Ssl) {"ssl"} else {"tcp"})"
                Host          = $_.host
                Port          = $Pool_Port
                User          = "$($Wallets.$Pool_Currency)"
                Pass          = "x"
                Region        = "US"
                SSL           = $Pool_Ssl
                Updated       = (Get-Date).ToUniversalTime()
                PoolFee       = $PoolCoin_Request.data.rate
                DataWindow    = $DataWindow
                Workers       = $null
                Hashrate      = $Stat.HashRate_Live
                TSL           = $null
                BLK           = $Stat.BlockRate_Average
                WTM           = -not $Pool_Price
                EthMode       = $Pool_EthProxy
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
            $Pool_Ssl = $true
        }
    }
}
