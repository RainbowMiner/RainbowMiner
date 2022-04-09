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

[hashtable]$Pool_RegionsTable = @{}
@("asia") | Foreach-Object {$Pool_RegionsTable.$_ = Get-Region $_}

$Pools_Data = @(
    [PSCustomObject]@{stratum = "mining.viabtc.io"; symbol = "ETC"; port = 3010}
    [PSCustomObject]@{stratum = "eth.viabtc.io";    symbol = "ETH"; port = 3333}
)

$Pools_Data | Where-Object {$Wallets."$($_.symbol)" -or $InfoOnly} | ForEach-Object {
    $Pool_Currency = $_.symbol
    $Pool_Coin = Get-Coin $Pool_Currency
    $Pool_Algorithm_Norm = Get-Algorithm $Pool_Coin.Algo
    $Pool_EthProxy = if ($Pool_Algorithm_Norm -match $Global:RegexAlgoHasEthproxy) {"ethstratumnh"} elseif ($Pool_Algorithm_Norm -match $Global:RegexAlgoIsProgPow) {"stratum"} else {$null}
    $Pool_SoloMining = $false

    $Pool_Fee = Switch ($("$($Pool_Currency)-PaymentMode")) {
        "pplns" {2}
        "solo"  {1;$Pool_SoloMining = $true}
        default {4}
    }

    $ok = $true

    if (-not $InfoOnly) {
        $Pool_StateRequest  = [PSCustomObject]@{}
        $Pool_BlocksRequest = [PSCustomObject]@{}

        if ($ok) {
            try {
                $Pool_StateRequest = Invoke-RestMethodAsync "https://www.viabtc.com/res/pool/$($Pool_Currency)/state" -tag $Name -retry 5 -retrywait 250 -cycletime 120 -delay 250 -fixbigint
                if ($Pool_StateRequest.message -ne "OK") {$ok=$false}
                $Pool_StateRequest = $Pool_StateRequest.data | Where-Object {$_.coin -eq $Pool_Currency}
            }
            catch {
                if ($Error.Count){$Error.RemoveAt(0)}
                $ok = $false
            }
        }

        if ($ok) {
            try {
                $Pool_BlocksRequest = Invoke-RestMethodAsync "https://www.viabtc.com/res/pool/$($Pool_Currency)/block?page=1&limit=50" -tag $Name -retry 5 -retrywait 250 -cycletime 120 -delay 250 -fixbigint
                if ($Pool_BlocksRequest.message -ne "OK") {$ok=$false}
            }
            catch {
                if ($Error.Count){$Error.RemoveAt(0)}
                $ok = $false
            }
        }

        if (-not $ok) {
            Write-Log -Level Warn "Pool API ($Name) for $($Pool_Currency) has failed. "
            return
        }

        $timestamp    = Get-UnixTimestamp
        $timestamp24h = $timestamp - 24*3600
            
        $blocks = @($Pool_BlocksRequest.data.data | Where-Object {$_.coin -eq $Pool_Currency -and -not $_.solo_block -and $_.time -gt $timestamp24h} | Select-Object time,reward,diff)

        $blocks_measure = $blocks | Measure-Object time -Minimum -Maximum
        $avgTime        = if ($blocks_measure.Count -gt 1) {($blocks_measure.Maximum - $blocks_measure.Minimum) / ($blocks_measure.Count - 1)} else {$timestamp}
        $Pool_BLK       = [int]$(if ($avgTime) {86400/$avgTime})
        $Pool_TSL       = $timestamp - $blocks_measure.Maximum
        $reward         = $(if ($blocks) {($blocks | Where-Object {$_.reward -gt 0} | Measure-Object reward -Average).Average} else {0})
        $btcPrice       = if ($Global:Rates.$Pool_Currency) {1/[double]$Global:Rates.$Pool_Currency} elseif ($Global:Rates.USD -and $Pool_StateRequest.pricing_currency -eq "USD") {[double]$Pool_StateRequest.coin_price / $Global:Rates.USD} else {0}
        $difficulty     = $Pool_StateRequest.curr_diff / [Math]::Pow(2,32)
        $Hashrate       = $Pool_StateRequest.pool_hashrate
        $btcRewardLive  = if ($Hashrate -gt 0) {$btcPrice * $reward * 86400 / $avgTime / $Hashrate} else {0}        

        $Stat = Set-Stat -Name "$($Name)_$($Pool_Currency)_Profit" -Value $btcRewardLive -Duration $StatSpan -ChangeDetection $false -HashRate $Hashrate -BlockRate $Pool_BLK -Difficulty $difficulty -Quiet
        if (-not $Stat.HashRate_Live -and -not $AllowZero) {return}
    }

    if ($ok) {
        [PSCustomObject]@{
            Algorithm     = $Pool_Algorithm_Norm
            Algorithm0    = $Pool_Algorithm_Norm
            CoinName      = $Pool_Coin.Name
            CoinSymbol    = $Pool_Currency
            Currency      = $Pool_Currency
            Price         = $Stat.$StatAverage #instead of .Live
            StablePrice   = $Stat.$StatAverageStable
            MarginOfError = $Stat.Week_Fluctuation
            Protocol      = "stratum+tcp"
            Host          = $_.stratum
            Port          = $_.port
            User          = "$($Wallets.$Pool_Currency).{workername:$Worker}"
            Pass          = "x"
            Region        = $Pool_RegionsTable["asia"]
            SSL           = $false
            Updated       = $Stat.Updated
            PoolFee       = $Pool_Fee
            DataWindow    = $DataWindow
            Workers       = if ($Pool_SoloMining) {$null} else {[int]$Pool_StateRequest.curr_connections}
            Hashrate      = if ($Pool_SoloMining) {$null} else {$Stat.HashRate_Live}
            TSL           = if ($Pool_SoloMining) {$null} else {$Pool_TSL}
            BLK           = if ($Pool_SoloMining) {$null} else {$Stat.BlockRate_Average}
            Difficulty    = $Stat.Diff_Average
            SoloMining    = $Pool_SoloMining
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
    }
}
