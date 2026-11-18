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
    [String]$StatAverageStable = "Week"
)

# https://pooly.ca/api/pools
# https://pooly.ca/api/pools/{poolId}/blocks?page=0&pageSize=100

$Pool_Region_Default = "us"

[hashtable]$Pool_RegionsTable = @{}
@("us","eu") | Foreach-Object {$Pool_RegionsTable.$_ = Get-Region $_}

# Auto endpoint via Cloudflare LB (closest working node)
$Pool_AutoHost = "pooly.ca"

$Pools_Request = [PSCustomObject]@{}
try {
    $Pools_Request = Invoke-RestMethodAsync "https://pooly.ca/api/pools" -tag $Name -timeout 15 -cycletime 120 -delay 250
}
catch {
    Write-Log -Level Warn "Pool API ($Name) has failed. "
    return
}

if (-not $Pools_Request.pools) {
    Write-Log -Level Warn "Pool API ($Name) returned no pools. "
    return
}

$Pools_Data = @(
    [PSCustomObject]@{symbol = "BUCK";               port = 3034; poolId = "buck";                     region = "us"; host = "ca.pooly.ca"; divisor = 1e8}
    [PSCustomObject]@{symbol = "BUCK";               port = 3034; poolId = "buck";                     region = "eu"; host = "eu.pooly.ca"; divisor = 1e8}
    [PSCustomObject]@{symbol = "ZER";                port = 3050; poolId = "zero";                     region = "us"; host = "ca.pooly.ca"; divisor = 1e8}
    [PSCustomObject]@{symbol = "ZER";                port = 3050; poolId = "zero";                     region = "eu"; host = "eu.pooly.ca"; divisor = 1e8}
    [PSCustomObject]@{symbol = "YEC";                port = 3054; poolId = "ycash";                    region = "us"; host = "ca.pooly.ca"; divisor = 1e8}
    [PSCustomObject]@{symbol = "YEC";                port = 3054; poolId = "ycash";                    region = "eu"; host = "eu.pooly.ca"; divisor = 1e8}
    [PSCustomObject]@{symbol = "BTCZ";               port = 3072; poolId = "bitcoinz";                 region = "us"; host = "ca.pooly.ca"; divisor = 1e8}
    [PSCustomObject]@{symbol = "BTCZ";               port = 3072; poolId = "bitcoinz";                 region = "eu"; host = "eu.pooly.ca"; divisor = 1e8}
    [PSCustomObject]@{symbol = "GLINK";              port = 3074; poolId = "gemlink";                  region = "us"; host = "ca.pooly.ca"; divisor = 1e8}
    [PSCustomObject]@{symbol = "GLINK";              port = 3074; poolId = "gemlink";                  region = "eu"; host = "eu.pooly.ca"; divisor = 1e8}
    [PSCustomObject]@{symbol = "FIRO";               port = 3094; poolId = "firo";                     region = "us"; host = "ca.pooly.ca"; divisor = 1e8}
    [PSCustomObject]@{symbol = "FIRO";               port = 3094; poolId = "firo";                     region = "eu"; host = "eu.pooly.ca"; divisor = 1e8}
    [PSCustomObject]@{symbol = "RVN";                port = 3100; poolId = "ravencoin";                region = "us"; host = "ca.pooly.ca"; divisor = 1e8}
    [PSCustomObject]@{symbol = "RVN";                port = 3100; poolId = "ravencoin";                region = "eu"; host = "eu.pooly.ca"; divisor = 1e8}
    [PSCustomObject]@{symbol = "NEOX";               port = 3102; poolId = "neoxa";                    region = "us"; host = "ca.pooly.ca"; divisor = 1e8}
    [PSCustomObject]@{symbol = "NEOX";               port = 3102; poolId = "neoxa";                    region = "eu"; host = "eu.pooly.ca"; divisor = 1e8}
    [PSCustomObject]@{symbol = "KRGN-Equihash200_9"; port = 3200; poolId = "kerrigan-equihash-200-9";  region = "us"; host = "ca.pooly.ca"; divisor = 1e8}
    [PSCustomObject]@{symbol = "KRGN-Equihash200_9"; port = 3200; poolId = "kerrigan-equihash-200-9";  region = "eu"; host = "eu.pooly.ca"; divisor = 1e8}
    [PSCustomObject]@{symbol = "KRGN-Equihash192_7"; port = 3202; poolId = "kerrigan-equihash-192-7";  region = "us"; host = "ca.pooly.ca"; divisor = 1e8}
    [PSCustomObject]@{symbol = "KRGN-Equihash192_7"; port = 3202; poolId = "kerrigan-equihash-192-7";  region = "eu"; host = "eu.pooly.ca"; divisor = 1e8}
    [PSCustomObject]@{symbol = "KRGN-KawPow";        port = 3204; poolId = "kerrigan-kawpow";          region = "us"; host = "ca.pooly.ca"; divisor = 1e8}
    [PSCustomObject]@{symbol = "KRGN-KawPow";        port = 3204; poolId = "kerrigan-kawpow";          region = "eu"; host = "eu.pooly.ca"; divisor = 1e8}
    [PSCustomObject]@{symbol = "KRGN-X11";           port = 3206; poolId = "kerrigan-x11";             region = "us"; host = "ca.pooly.ca"; divisor = 1e8}
    [PSCustomObject]@{symbol = "KRGN-X11";           port = 3206; poolId = "kerrigan-x11";             region = "eu"; host = "eu.pooly.ca"; divisor = 1e8}
)

$Pool_PayoutScheme = "PPLNS"

$Pools_Data | Where-Object {$Pool_Currency = $_.symbol -replace "-.+$"; $Wallets.$Pool_Currency -or $InfoOnly} | ForEach-Object {
    $Pool_Coin      = Get-Coin $_.symbol
    $Pool_Port      = $_.port
    $Pool_Host      = $_.host
    $Pool_PoolId    = $_.poolId
    $Pool_Region    = $_.region
    $Pool_Divisor   = $_.divisor

    $Pool_Algorithm_Norm = $Pool_Coin.algo

    $Pool_EthProxy = if ($Pool_Algorithm_Norm -match $Global:RegexAlgoIsProgPow) {"stratum"} else {$null}

    $Pool_PoolData = $Pools_Request.pools | Where-Object {$_.id -eq $Pool_PoolId} | Select-Object -First 1

    if (-not $Pool_PoolData -and -not $InfoOnly) {return}

    $Pool_Fee = if ($Pool_PoolData.poolFeePercent) {$Pool_PoolData.poolFeePercent} else {1.0}

    if (-not $InfoOnly -and $Pool_Region -eq $Pool_Region_Default) {
        $Pool_Blocks = [PSCustomObject]@{}
        try {
            $Pool_Blocks = Invoke-RestMethodAsync "https://pooly.ca/api/pools/$($Pool_PoolId)/blocks?page=0&pageSize=100" -tag $Name -timeout 20 -cycletime 120 -delay 250
        }
        catch {
            Write-Log -Level Info "Pool blocks API ($Name) for $Pool_Currency has failed. "
        }

        $timestamp = Get-UnixTimestamp
        $timestamp24h = $timestamp - 86400

        $blocks = @($Pool_Blocks | Where-Object {$_.status -ne "orphaned" -and $_.created})
        $blocks_recent = @($blocks | Where-Object {
            $created = if ($_.created -match "^\d+$") {[int]$_.created} else {[int](Get-UnixTimestamp (Get-Date $_.created))}
            $created -gt $timestamp24h
        })

        $blocks_measure = $blocks_recent | ForEach-Object {
            $created = if ($_.created -match "^\d+$") {[int]$_.created} else {[int](Get-UnixTimestamp (Get-Date $_.created))}
            [PSCustomObject]@{timestamp = $created; reward = $_.reward}
        } | Measure-Object timestamp -Minimum -Maximum
        $blocks_reward = ($blocks_recent | Where-Object {$_.reward -gt 0} | Measure-Object -Average -Property reward).Average
        if (-not $blocks_reward) {$blocks_reward = 0}

        $blocks_count = $blocks_measure.Count

        $Pool_BLK = $(if ($blocks_count -gt 1 -and ($blocks_measure.Maximum - $blocks_measure.Minimum)) {86400/($blocks_measure.Maximum - $blocks_measure.Minimum)} else {1}) * $blocks_count
        $Pool_TSL = if ($Pool_PoolData.poolStats.lastPoolBlockTime) {$timestamp - [int](Get-UnixTimestamp (Get-Date $Pool_PoolData.poolStats.lastPoolBlockTime))} else {0}

        $Pool_HR = if ($Pool_PoolData.poolStats.poolHashrate) {$Pool_PoolData.poolStats.poolHashrate} else {0}
        $Pool_Workers = if ($Pool_PoolData.poolStats.connectedMiners) {$Pool_PoolData.poolStats.connectedMiners} else {0}

        $btcPrice       = if ($Global:Rates.$Pool_Currency) {1/[double]$Global:Rates.$Pool_Currency} else {0}
        $btcRewardLive  = if ($Pool_HR) {$btcPrice * $blocks_reward * $Pool_BLK / $Pool_HR} else {0}

        $Stat = Set-Stat -Name "$($Name)_$($_.symbol)_Profit" -Value $btcRewardLive -Duration $StatSpan -ChangeDetection $false -HashRate $Pool_HR -BlockRate $Pool_BLK -Quiet
        if (-not $Stat.HashRate_Live -and -not $AllowZero) {return}
    }

    foreach($Pool_SSL in @($false,$true)) {
        [PSCustomObject]@{
            Algorithm     = $Pool_Algorithm_Norm
            Algorithm0    = $Pool_Algorithm_Norm
            CoinName      = $Pool_Coin.Name
            CoinSymbol    = $Pool_Currency
            Currency      = $Pool_Currency
            Price         = $Stat.$StatAverage
            StablePrice   = $Stat.$StatAverageStable
            MarginOfError = $Stat.Week_Fluctuation
            Protocol      = "stratum+$(if ($Pool_SSL) {"ssl"} else {"tcp"})"
            Host          = $Pool_Host
            Port          = $Pool_Port
            User          = "$($Wallets.$Pool_Currency).{workername:$Worker}"
            Pass          = "x"
            Region        = $Pool_RegionsTable.$Pool_Region
            SSL           = $Pool_SSL
            WTM           = -not $btcRewardLive
            Updated       = $Stat.Updated
            Workers       = $Pool_Workers
            PoolFee       = $Pool_Fee
            Hashrate      = $Stat.HashRate_Live
            TSL           = $Pool_TSL
            BLK           = $Stat.BlockRate_Average
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
