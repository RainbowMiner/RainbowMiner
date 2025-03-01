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
    $Pool_Request = Invoke-RestMethodAsync "https://ekapool.com/api/pools" -tag $Name -cycletime 120
}
catch {
    Write-Log -Level Warn "Pool API ($Name) has failed. "
    return
}

if (($Pool_Request.pools | Measure-Object).Count -le 1) {
    Write-Log -Level Warn "Pool API ($Name) returned nothing. "
    return
}

[hashtable]$Pool_RegionsTable = @{}

$Pool_Regions = @("us","eu","ca","sg")
$Pool_Regions | Foreach-Object {$Pool_RegionsTable.$_ = Get-Region $_}

$Pool_Request.pools | Where-Object {$Pool_Currency = $_.coin.symbol;$_.paymentProcessing.payoutScheme -eq "PPLNS" -and ($Wallets.$Pool_Currency -or $InfoOnly)} | Foreach-Object {

    if ($Pool_Coin = Get-Coin $Pool_Currency) {
        $Pool_CoinName = $Pool_Coin.Name
        $Pool_Algorithm_Norm = $Pool_Coin.Algo
    } else {
        $Pool_CoinName = $_.coin.name
        $Pool_Algorithm_Norm = Get-Algorithm $_.coin.algorithm -CoinSymbol $Pool_Currency
    }

    $Pool_EthProxy = if ($Pool_Algorithm_Norm -match $Global:RegexAlgoHasEthproxy) {"ethstratum"} elseif ($Pool_Algorithm_Norm -match $Global:RegexAlgoIsProgPow) {"stratum"} else {$null}

    $Pool_PoolFee = [Double]$_.poolFeePercent

    $Pool_Workers = [int]$_.poolStats.connectedMiners

    $Pool_Port = [int]($_.ports.PSObject.Properties | Sort-Object {[int]$_.Name} | Where-Object {-not $_.Value.tls} | Foreach-Object {$_.Name} | Select-Object -First 1)

    if (-not $InfoOnly) {

        if (-not $_.poolStats.poolHashrate -and -not $AllowZero) {return}

        $Pool_LiveStats = $null
        $Pool_BlocksRequest = $null
        try {
            $Pool_BlocksRequest = Invoke-RestMethodAsync "https://ekapool.com/api/pools/$($_.id)/blocks?page=0&pageSize=100" -tag $Name -timeout 15 -cycletime 120
        }
        catch {
            Write-Log -Level Warn "Pool blocks API ($Name) for $Pool_Currency has failed. "
        }
    
        if ($Pool_BlocksRequest) {
            $now             = [datetime]::UtcNow
            $blocks          = $Pool_BlocksRequest | Foreach-Object {[int]($now - ([datetime]$_.created).ToUniversalTime()).TotalSeconds} | Where-Object {$_ -lt 86400}
            $blocks_measure  = $blocks | Measure-Object -Minimum -Maximum
            $Pool_BLK        = [int]$($(if ($blocks_measure.Count -gt 1 -and ($blocks_measure.Maximum - $blocks_measure.Minimum)) {86400/($blocks_measure.Maximum - $blocks_measure.Minimum)} else {1})*$blocks_measure.Count)
            $Stat = Set-Stat -Name "$($Name)_$($Pool_Currency)_Profit" -Value 0 -Duration $StatSpan -ChangeDetection $false -HashRate $_.poolStats.poolHashrate -BlockRate $Pool_BLK -Quiet
        }
    }

    $Pool_TSL = if ($_.lastPoolBlockTime) {[int]([datetime]::UtcNow - ([datetime]$_.lastPoolBlockTime).ToUniversalTime()).TotalSeconds} else {$null}

    $Pool_Stratum = $Pool_Currency.ToLower()

    foreach($Pool_Region in $Pool_Regions) {
        foreach($Pool_SSL in @($false)) {
            [PSCustomObject]@{
                Algorithm     = $Pool_Algorithm_Norm
                Algorithm0    = $Pool_Algorithm_Norm
                CoinName      = $Pool_Coin.Name
                CoinSymbol    = $Pool_Coin.Symbol
                Currency      = $Pool_Currency
                Price         = $Stat.$StatAverage #instead of .Live
                StablePrice   = $Stat.$StatAverageStable
                MarginOfError = $Stat.Week_Fluctuation
                Protocol      = "stratum+$(if ($Pool_SSL) {"ssl"} else {"tcp"})"
                Host          = "$($Pool_Stratum).$($Pool_Region).ekapool.com"
                Port          = if ($Pool_SSL) {$Pool_Port + 100} else {$Pool_Port}
                User          = "$($Wallets.$Pool_Currency).{workername:$Worker}"
                Pass          = "x"
                Region        = $Pool_RegionsTable.$Pool_Region
                SSL           = $Pool_SSL
                Updated       = $Stat.Updated
                PoolFee       = $Pool_PoolFee
                DataWindow    = $DataWindow
                Workers       = $Pool_Workers
                BLK           = $Stat.BlockRate_Average
                TSL           = $Pool_TSL
                WTM           = $true
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
                Wallet        = $Wallets.$Pool_Currency
                Worker        = "{workername:$Worker}"
                Email         = $Email
            }
        }
    }
}

$OtherCoins = @(
    [PSCustomObject]@{coin = "CHN";  stratum = "chn";  rpc = "chn-api"}
    [PSCustomObject]@{coin = "DNX";  stratum = "dnx";  rpc = "dnx-api"}
    [PSCustomObject]@{coin = "ZEPH"; stratum = "zeph"; rpc = "zeph-api"}

)

$OtherCoins | Where-Object {$Pool_Currency = $_.coin;($Wallets.$Pool_Currency -and $Pool_Currency -notin $Pool_Request.pools.coin.symbol -or $InfoOnly)} | Foreach-Object {

    $Pool_Coin = Get-Coin $Pool_Currency

    $Pool_CoinName = $Pool_Coin.Name
    $Pool_Algorithm_Norm = Get-Algorithm $Pool_Coin.Algo -CoinSymbol $Pool_Currency

    $Pool_PoolFee = 1

    $Pool_Workers = $null

    $Pool_Ports = [int]($_.ports.PSObject.Properties | Sort-Object {[int]$_.Name} | Where-Object {-not $_.Value.tls} | Foreach-Object {$_.Name} | Select-Object -First 1)

    $Pool_LiveStats = $null
    try {
        $Pool_LiveStats     = Invoke-RestMethodAsync "https://ekapool.com/$($_.rpc)/stats?_={unixtimestamp_ms}" -tag $Name -timeout 15 -cycletime 120
    }
    catch {
        Write-Log -Level Warn "Pool blocks API ($Name) for $Pool_Currency has failed. "
    }

    $now           = Get-UnixTimestamp

    $Pool_PoolFee  = [double]$Pool_LiveStats.config.fee
    $Pool_Workers  = [int]$Pool_LiveStats.pool.workers
    $Pool_Hashrate = [decimal]$Pool_LiveStats.pool.hashrate
    $Pool_TSL      = [int]($now - ($Pool_LiveStats.pool.lastBlockFound/1000))
    $Pool_Profit   = 0

    $Pool_Ports = @(0,0)
    $Pool_LiveStats.config.ports | Sort-Object {$_.ssl},{[decimal]$_.difficulty} | Foreach-Object {$ix = [int]$_.ssl;if (-not $Pool_Ports[$ix]) {$Pool_Ports[$ix] = $_.port}}

    if ($Pool_LiveStats -and -not $InfoOnly) {
        if (-not $Pool_Hashrate -and -not $AllowZero) {return}
        $last24h         = $now - 86400
        $blocks          = $Pool_LiveStats.pool.blocks | Where-Object {$_ -match "^prop:[A-Za-z0-9\.]+:[0-9A-Fa-f]+:(\d+):"} | Foreach-Object {[int]$Matches[1]} | Where-Object {$_ -ge $last24h}
        $blocks_measure  = $blocks | Measure-Object -Minimum -Maximum
        $Pool_BLK        = [int]$($(if ($blocks_measure.Count -gt 1 -and ($blocks_measure.Maximum - $blocks_measure.Minimum)) {86400/($blocks_measure.Maximum - $blocks_measure.Minimum)} else {1})*$blocks_measure.Count)

        if ($Global:VarCache.Rates.ContainsKey($Pool_Currency) -and $Global:VarCache.Rates[$Pool_Currency]) {
            $Pool_Profit = (86400 / $Pool_LiveStats.network.difficulty) * $Pool_LiveStats.lastblock.reward / $Pool_LiveStats.config.coinUnits / $Global:VarCache.Rates[$Pool_Currency]
        }

        $Stat = Set-Stat -Name "$($Name)_$($Pool_Currency)_Profit" -Value $Pool_Profit -Duration $StatSpan -ChangeDetection $false -HashRate $Pool_Hashrate -BlockRate $Pool_BLK -Quiet
    }

    $Pool_Stratum = $Pool_Currency.ToLower()

    foreach($Pool_Region in $Pool_Regions) {
        $Pool_SSL = $false
        foreach($Pool_Port in $Pool_Ports) {
            if ($Pool_Port -gt 0) {
                [PSCustomObject]@{
                    Algorithm     = $Pool_Algorithm_Norm
                    Algorithm0    = $Pool_Algorithm_Norm
                    CoinName      = $Pool_Coin.Name
                    CoinSymbol    = $Pool_Coin.Symbol
                    Currency      = $Pool_Currency
                    Price         = $Stat.$StatAverage #instead of .Live
                    StablePrice   = $Stat.$StatAverageStable
                    MarginOfError = $Stat.Week_Fluctuation
                    Protocol      = "stratum+$(if ($Pool_SSL) {"ssl"} else {"tcp"})"
                    Host          = "$($_.stratum).$($Pool_Region).ekapool.com"
                    Port          = $Pool_Port
                    User          = $Wallets.$Pool_Currency
                    Pass          = "{workername:$Worker}"
                    Region        = $Pool_RegionsTable.$Pool_Region
                    SSL           = $Pool_SSL
                    Updated       = $Stat.Updated
                    PoolFee       = $Pool_PoolFee
                    DataWindow    = $DataWindow
                    Workers       = $Pool_Workers
                    BLK           = $Stat.BlockRate_Average
                    TSL           = $Pool_TSL
                    WTM           = $Pool_Profit -eq 0
                    EthMode       = $null
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
                    Wallet        = $Wallets.$Pool_Currency
                    Worker        = "{workername:$Worker}"
                    Email         = $Email
                    Mallob        = if ($Pool_Currency -eq "DNX") {"https://dnx.$($Pool_Region).ekapool.com"} else {$null}
                }
            }
            $Pool_SSL = $true
        }
    }
}
