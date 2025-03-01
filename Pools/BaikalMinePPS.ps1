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

$Pool_Type = "pps_plus"
$Pool_Fee  = 0.75

[hashtable]$Pool_RegionsTable = @{}
@("Netherlands","Moscow") | Foreach-Object {$Pool_RegionsTable.$_ = Get-Region $_}

$Pool_Request = [PSCustomObject]@{}

try {
    $Pool_Request = Invoke-RestMethodAsync "https://baikalmine.com/api/pool/menu/getTopMenu" -tag "BaikalMine" -cycletime 3600 -retry 5 -retrywait 250 | Where {$_.alias -eq $Pool_Type}
}
catch {
    Write-Log -Level Warn "Pool API ($Name) has failed. "
    return
}

if (-not $Pool_Request) {
    Write-Log -Level Warn "Pool API ($Name) returned nothing. "
    return
}

$Pool_Request.coins | Where-Object {$Wallets."$($_.name)" -or $InfoOnly} | ForEach-Object {
    $Pool_Currency = $_.name

    if ($Pool_Coin = Get-Coin $Pool_Currency) {
        $Pool_Algorithm_Norm = $Pool_Coin.Algo
    } else {
        Write-Log -Level Warn "Pool $($Name): missing coin $($Pool_Currency) in db"
        return
    }

    $Pool_EthProxy = if ($Pool_Algorithm_Norm -match $Global:RegexAlgoHasEthproxy) {"qtminer"} elseif ($Pool_Algorithm_Norm -match $Global:RegexAlgoIsProgPow) {"stratum"} else {$null}

    $PoolInfo_Request  = [PSCustomObject]@{}

    try {
        $PoolInfo_Request   = Invoke-RestMethodAsync "https://baikalmine.com/api/pool/info/getInfo"  -tag $Name -cycletime 120 -delay 250 -body @{type = $Pool_Type; coin = $_.alias}
    }
    catch {
        Write-Log -Level Warn "Pool $($Name): Info API for $($Pool_Currency) has failed. "
        return
    }

    $Pool_RPC      = ($PoolInfo_Request.ports | Where-Object {$_.location -eq "Moscow"} | Select-Object -First 1).server

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

        if ($PoolStats_Request.mainStats) {
            $Pool_Hashrate = $PoolStats_Request.mainStats.hashrate
            $Pool_Workers  = [int]($PoolStats_Request.charts.workers | Select-Object -Last 1)
            $Pool_TSL      = $timestamp - $PoolStats_Request.mainStats.lastBlockFound
        } else {
            $Pool_Hashrate = $PoolStats_Request.hashrate
            $Pool_Workers  = $PoolStats_Request.minersTotal
            $Pool_TSL      = $timestamp - $PoolStats_Request.stats.lastBlockFound
        }

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
            PaysLive      = $true
            PoolFee       = $Pool_Fee
            Workers       = $Pool_Workers
            Hashrate      = $Stat.HashRate_Live
            TSL           = $Pool_TSL
            BLK           = $null
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
