using module ..\Include.psm1

param(
    [PSCustomObject]$Wallets,
    [PSCustomObject]$Params,
    [alias("WorkerName")]
    [String]$Worker,
    [TimeSpan]$StatSpan,
    [String]$DataWindow = "estimate_current",
    [Bool]$InfoOnly = $false,
    [Bool]$AllowZero = $false,
    [String]$StatAverage = "Minute_10"
)

if (-not $InfoOnly -and -not (Compare-Object @("ETH","ETC","ETP","GRIN") $Wallets.PSObject.Properties.Name -IncludeEqual -ExcludeDifferent)) {return}

$Name = Get-Item $MyInvocation.MyCommand.Path | Select-Object -ExpandProperty BaseName

$Pool_Region_Default = Get-Region "us"


$Pool_Request = [PSCustomObject]@{}
try {
    $Pool_Request = Invoke-RestMethodAsync "http://rbminer.net/api/data/ethashpool.json"  -tag $Name -cycletime 120
}
catch {
    if ($Error.Count){$Error.RemoveAt(0)}
    Write-Log -Level Warn "Pool API ($Name) has failed. "
}

$Pool_Request.PSObject.Properties.Name | Where-Object {$_ -ne "GRIN"} | Where-Object {$Wallets.$_ -or $InfoOnly} | ForEach-Object {
    $Pool_Currency  = $_
    $Pool_Request1  = $Pool_Request.$Pool_Currency
    $Pool_Algorithm = $Pool_Request1.algo

    $Pool_Divisor   = if ($Pool_Request1.divisor) {$Pool_Request1.divisor} else {1}

    $Pool_Algorithm_Norm = Get-Algorithm $Pool_Algorithm

    if (-not $InfoOnly) {
        $timestamp      = (Get-Date).ToUniversalTime()
        $timestamp24h   = (Get-Date).AddHours(-24).ToUniversalTime()

        $Pool_Blocks  = $Pool_Request1.blocks | Where-Object {[DateTime]$_.timestamp -gt $timestamp24h}
        if (-not ($Pool_Blocks | Measure-Object).Count) {
            $reward   = ($Pool_Request1.blocks | Where-Object reward | Measure-Object reward -Average).Average
            $Pool_BLK = 0
            $Pool_TSL = [int64]($timestamp - [DateTime]$Pool_Request1.stats.last_pool_block_found_at.date).TotalSeconds
        } else {
            $reward   = ($Pool_Blocks | Where-Object reward | Measure-Object reward -Average).Average
            $Pool_BLK = ($Pool_Blocks | Measure-Object).Count
            $Pool_TSL = [int64]($timestamp - [DateTime]$Pool_Blocks[0].timestamp).TotalSeconds
        }

        $lastSatPrice = if ($Session.Rates.$Pool_Currency) {1/[double]$Session.Rates.$Pool_Currency} else {0}
        $profitLive = $(if ($Pool_Currency -eq "GRIN") {$Pool_BLK/$Pool_Request1.stats.pool_hash_rate} else {86400/$Pool_Request1.stats.network_difficulty}) * $reward / $Pool_Divisor * $lastSatPrice

        $Stat = Set-Stat -Name "$($Name)_$($Pool_Currency)_Profit" -Value $profitLive -Duration $StatSpan -HashRate $Pool_Request1.stats.pool_hash_rate -BlockRate $Pool_BLK -ChangeDetection $true -Quiet
    }
    
    if (($AllowZero -or $Pool_Request1.stats.pool_hash_rate -gt 0) -or $InfoOnly) {
        [PSCustomObject]@{
            Algorithm     = $Pool_Algorithm_Norm
            CoinName      = $Pool_Request1.coin
            CoinSymbol    = $Pool_Currency
            Currency      = $Pool_Currency
            Price         = $Stat.$StatAverage #instead of .Live
            StablePrice   = $Stat.Week
            MarginOfError = $Stat.Week_Fluctuation
            Protocol      = "stratum+tcp"
            Host          = $Pool_Request1.host
            Port          = $Pool_Request1.port
            User          = "$($Wallets.$Pool_Currency)$(if ($Pool_Currency -eq "GRIN") {"/"} else {"."}){workername:$Worker}"
            Pass          = "x"
            Worker        = "{workername:$Worker}"
            Region        = $Pool_Region_Default
            SSL           = $false
            Updated       = $Stat.Updated
            PoolFee       = $Pool_Request1.fee
            Workers       = $Pool_Request1.stats.workers_online
            Hashrate      = $Stat.HashRate_Live
            TSL           = $Pool_TSL
            BLK           = $Stat.BlockRate_Average
            EthMode       = if ($Pool_Algorithm_Norm -match "^(Ethash|ProgPow)") {"ethproxy"} else {$null}
        }
    }
}
