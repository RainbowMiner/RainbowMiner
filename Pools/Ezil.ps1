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
    [Bool]$EnableLolminerDual = $false,
    [Bool]$EnableNanominerDual = $false,
    [String]$StatAverage = "Minute_10",
    [String]$StatAverageStable = "Week"
)

$Name = Get-Item $MyInvocation.MyCommand.Path | Select-Object -ExpandProperty BaseName

$Pool_RegionsTable = [ordered]@{}
@("eu","us-east","us-west","asia") | Foreach-Object {$Pool_RegionsTable.$_ = Get-Region $_}

$Pools_Data = @(
    [PSCustomObject]@{symbol = "ETC"; port = @(4444,24443)}
    [PSCustomObject]@{symbol = "ETH"; port = @(5555,25443)}
)

$Pool_Currencies = $Pools_Data.symbol | Select-Object -Unique | Where-Object {$Wallets.$_ -or $InfoOnly}
if (((-not $EnableNanominerDual -and -not $Pool_Currencies) -or -not $Wallets.ZIL) -and -not $InfoOnly) {return}

if ($Pool_Currencies) {
    $Pool_RequestCalc = [PSCustomObject]@{}
    $Pool_RequestStat = [PSCustomObject]@{}

    try {
        $Pool_RequestCalc = Invoke-RestMethodAsync "https://calculator.ezil.me/api/ezil_calculator?hashrate=100" -cycletime 120 -tag $Name
        $Pool_RequestStat = Invoke-RestMethodAsync "https://stats.ezil.me/current_stats/by_coin" -cycletime 120 -tag $Name
    } catch {
        if ($Error.Count){$Error.RemoveAt(0)}
        Write-Log -Level Warn "Pool API ($Name) has failed. "
        return
    }
}

$Pools_Data | Where-Object {$EnableNanominerDual -or $Wallets."$($_.symbol)" -or $InfoOnly} | ForEach-Object {
    $Pool_Coin  = Get-Coin $_.symbol
    $Pool_Ports = $_.port
    $Pool_Algorithm_Norm = Get-Algorithm $Pool_Coin.Algo
    $Pool_Currency = $_.symbol

    $Pool_EthProxy = "ethproxy"

    $Pool_Request = [PSCustomObject]@{}

    if (-not $InfoOnly -and $Pool_Currencies) {
        $timestamp      = Get-UnixTimestamp
        $timestamp24h   = $timestamp - 86400

        $Pool_Blocks = [PSCustomObject]@{}
        try {
            $Pool_Blocks = (Invoke-RestMethodAsync "https://billing.ezil.me/blocks?coin=$($Pool_Currency.ToLower())" -cycletime 120 -tag $Name).timestamp | Where-Object {$_ -ge $timestamp24h} | Measure-Object -Maximum -Minimum
        } catch {
            if ($Error.Count){$Error.RemoveAt(0)}
            Write-Log -Level Warn "Pool $($Pool_Currency)-blocks API ($Name) has failed. "
        }

        $Pool_BLK = [int]$($(if ($Pool_Blocks.Count -gt 1 -and ($Pool_Blocks.Maximum - $Pool_Blocks.Minimum)) {86400/($Pool_Blocks.Maximum - $Pool_Blocks.Minimum)} else {1})*$Pool_Blocks.Count)
        $Pool_TSL = $timestamp - $Pool_Blocks.Maximum

        $lastBTCPrice = if ($Global:Rates.$Pool_Currency) {1/[double]$Global:Rates.$Pool_Currency} else {0}
        $Pool_Price = $lastBTCPrice * ([Double]$Pool_RequestCalc.$Pool_Currency."$($Pool_Currency)_with_zil_in_$($Pool_Currency)") / 1e8
        $Stat = Set-Stat -Name "$($Name)_$($Pool_Currency)_Profit" -Value $Pool_Price -Duration $StatSpan -ChangeDetection $true -HashRate $Pool_RequestStat.$Pool_Currency.current_hashrate -BlockRate $Pool_BLK -Quiet
        if (-not $Stat.HashRate_Live -and -not $AllowZero) {return}
    }

    foreach($Pool_Region in $Pool_RegionsTable.Keys) {
        $Pool_Ssl = $false
        foreach($Pool_Port in $Pool_Ports) {
            if ($Pool_Currencies) {
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
                    Host          = "$($Pool_Region).ezil.me"
                    Port          = $Pool_Port
                    User          = "$($Wallets.$Pool_Currency).$($Wallets.ZIL)"
                    Pass          = "x"
                    Region        = $Pool_RegionsTable.$Pool_Region
                    SSL           = $Pool_Ssl
                    Updated       = $Stat.Updated
                    PoolFee       = 1.0
                    DataWindow    = $DataWindow
                    Workers       = $Pool_RequestStat.$Pool_Currency.workers_count
                    Hashrate      = $Stat.HashRate_Live
                    TSL           = $Pool_TSL
                    BLK           = $Stat.BlockRate_Average
                    EthMode       = $Pool_EthProxy
                    Name          = $Name
                    Penalty       = 0
                    PenaltyFactor = 1
                    Disabled      = $false
                    HasMinerExclusions = $false
                    Price_Bias    = 0.0
                    Price_Unbias  = 0.0
                    Wallet        = "$($Wallets.$Pool_Currency).$($Wallets.ZIL)"
                    Worker        = "{workername:$Worker}"
                    Email         = $Email
                }
            }
            if ($EnableNanominerDual -or $EnableLolminerDual) {
                [PSCustomObject]@{
                    Algorithm     = "Zilliqa$($Pool_Currency)"
                    Algorithm0    = "Zilliqa$($Pool_Currency)"
                    CoinName      = "Zilliqa"
                    CoinSymbol    = "ZIL"
                    Currency      = "ZIL"
                    Price         = 1e-15
                    StablePrice   = 1e-15
                    MarginOfError = 0
                    Protocol      = "stratum+$(if ($Pool_Ssl) {"ssl"} else {"tcp"})"
                    Host          = "$($Pool_Region).ezil.me"
                    Port          = $Pool_Port
                    User          = "$($Wallets.ZIL).{workername:$Worker}"
                    Pass          = "x"
                    Region        = $Pool_RegionsTable.$Pool_Region
                    SSL           = $Pool_Ssl
                    Updated       = (Get-Date).ToUniversalTime()
                    PoolFee       = 1.0
                    DataWindow    = $DataWindow
                    Workers       = $null
                    EthMode       = $Pool_EthProxy
                    Name          = $Name
                    Penalty       = 0
                    PenaltyFactor = 1
                    Disabled      = $false
                    HasMinerExclusions = $false
                    Price_Bias    = 0.0
                    Price_Unbias  = 0.0
                    Wallet        = $Wallets.ZIL
                    Worker        = "{workername:$Worker}"
                    Email         = $Email
                }
            }
            $Pool_Ssl = $true
        }
    }
}
