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

# $Name = Get-Item $MyInvocation.MyCommand.Path | Select-Object -ExpandProperty BaseName

$Pool_Type = "pplns"
$Pool_Fee  = 0.5

[hashtable]$Pool_RegionsTable = @{}
@("Netherlands","Moscow") | Foreach-Object {$Pool_RegionsTable.$_ = Get-Region $_}

$Pool_Request = [PSCustomObject]@{}

try {
    $Pool_Request = Invoke-RestMethodAsync "https://baikalmine.com/api/Pool/GetEntities" -tag "BaikalMine" -body '{"props":["_id","api","active","maintenance","type._id","type.name","type.identifier","coin.symbol","coin.name","coin.identifier","engine.type","ports"]}' -cycletime 3600 -retry 5 -retrywait 250
}
catch {
    Write-Log -Level Warn "Pool API ($Name) has failed. "
    return
}

if (-not $Pool_Request.entities) {
    Write-Log -Level Warn "Pool API ($Name) returned nothing. "
    return
}

$Pool_Request.entities | Where-Object {$_.type.identifier -eq $Pool_Type -and $Wallets."$($_.coin.symbol)" -or $InfoOnly} | ForEach-Object {
    $Pool_Currency = $_.coin.symbol

    if ($Pool_Coin = Get-Coin $Pool_Currency) {
        $Pool_Algorithm_Norm = $Pool_Coin.Algo
    } else {
        Write-Log -Level Warn "Pool $($Name): missing coin $($Pool_Currency) in db"
        return
    }

    $Pool_EthProxy = if ($Pool_Algorithm_Norm -match $Global:RegexAlgoHasEthproxy) {"qtminer"} elseif ($Pool_Algorithm_Norm -match $Global:RegexAlgoIsProgPow) {"stratum"} else {$null}

    $PoolInfo_Request  = [PSCustomObject]@{}

    try {
        $PoolInfo_Request   = Invoke-RestMethodAsync "https://baikalmine.com/api/Engines/GetPoolStats"  -tag $Name -body "{`"type`":`"$Pool_Type`",`"coin`":`"$($_.coin.identifier)`",`"engine`":$($_.engine.type)}" -cycletime 120 -delay 250
    }
    catch {
        Write-Log -Level Warn "Pool $($Name): Info API for $($Pool_Currency) has failed. "
        return
    }

    if (-not $PoolInfo_Request.entity) {
        Write-Log -Level Warn "Pool $($Name): Info API for $($Pool_Currency) has failed. "
        return
    }

    $Pool_RPC      = ($_.ports | Where-Object {$_.location -match "Moscow"} | Select-Object -First 1).ip

    $Pool_Hashrate = $null
    $Pool_Workers  = $null
    $Pool_TSL      = $null
    $Pool_BLK      = $null

    $PoolStats_Request  = [PSCustomObject]@{}
    $PoolBlocks_Request = [PSCustomObject]@{}

    if (-not $InfoOnly) {
        try {
            $PoolStats_Request  = Invoke-RestMethodAsync "https://$($Pool_RPC)/api/stats"  -tag $Name -cycletime 120 -delay 250
        }
        catch {
            Write-Log -Level Warn "Pool $($Name): Stats API for $($Pool_Currency) has failed. "
        }

        try {
            $PoolBlocks_Request = Invoke-RestMethodAsync "https://$($Pool_RPC)/api/blocks" -tag $Name -cycletime 120 -delay 250
        }
        catch {
            Write-Log -Level Warn "Pool $($Name): Blocks API for $($Pool_Currency) has failed. "
        }

        $timestamp = Get-UnixTimestamp
        $timestamp24h = $timestamp - 86400

        if ($PoolStats_Request.mainStats) {
            $Pool_Hashrate = $PoolStats_Request.mainStats.hashrate
            $Pool_Workers  = [int]($PoolStats_Request.charts.workers | Select-Object -Last 1)
            $Pool_TSL      = $timestamp - $PoolStats_Request.mainStats.lastBlockFound
        } else {
            $Pool_Hashrate = $PoolStats_Request.hashrate
            $Pool_Workers  = $PoolStats_Request.minersTotal
            $Pool_TSL      = $timestamp - $PoolStats_Request.stats.lastBlockFound
        }
        $blocks = @($PoolBlocks_Request.candidates | Where-Object {$_.timestamp -ge $timestamp24h -and -not $_.orphan} | Select-Object -ExpandProperty timestamp) + @($PoolBlocks_Request.immature | Where-Object {$_.timestamp -ge $timestamp24h -and -not $_.orphan} | Select-Object -ExpandProperty timestamp) + @($PoolBlocks_Request.matured | Where-Object {$_.timestamp -ge $timestamp24h -and -not $_.orphan} | Select-Object -ExpandProperty timestamp)
        $blocks_measure  = $blocks | Measure-Object -Minimum -Maximum
        $Pool_BLK        = [int]$($(if ($blocks_measure.Count -gt 1 -and ($blocks_measure.Maximum - $blocks_measure.Minimum)) {86400/($blocks_measure.Maximum - $blocks_measure.Minimum)} else {1})*$blocks_measure.Count)

        $Stat = Set-Stat -Name "$($Name)_$($Pool_Currency)_Profit" -Value 0 -Duration $StatSpan -ChangeDetection $false -HashRate $Pool_Hashrate -BlockRate $Pool_BLK -Quiet
        if (-not $Stat.HashRate_Live -and -not $AllowZero) {return}
    }
    
    foreach($Pool_Info in $PoolInfo_Request.ports) {
        [PSCustomObject]@{
            Algorithm     = $Pool_Algorithm_Norm
            Algorithm0    = $Pool_Algorithm_Norm
            CoinName      = $Pool_Coin.Name
            CoinSymbol    = $Pool_Currency
            Currency      = $Pool_Currency
            Price         = 0
            StablePrice   = 0
            MarginOfError = 0
            Protocol      = "stratum+$(if ($Pool_Info.ssl) {"ssl"} else {"tcp"})"
            Host          = $Pool_Info.server
            Port          = $Pool_Info.port
            User          = "$($Wallets.$Pool_Currency).{workername:$Worker}"
            Pass          = "x"
            Region        = $Pool_RegionsTable."$($Pool_Info.location)"
            SSL           = $Pool_Info.ssl
            Updated       = (Get-Date).ToUniversalTime()
            PoolFee       = $Pool_Fee
            Workers       = $Pool_Workers
            Hashrate      = $Stat.HashRate_Live
            TSL           = $Pool_TSL
            BLK           = $Stat.BlockRate_Average
            WTM           = $true
            Mallob        = if ($Pool_Info.additionally -match "(http.+?)$") {$Matches[1]} else {$null}
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
