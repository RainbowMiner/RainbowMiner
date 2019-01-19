using module ..\Include.psm1

param(
    [PSCustomObject]$Wallets,
    [alias("WorkerName")]
    [String]$Worker,
    [String]$Password,
    [TimeSpan]$StatSpan,
    [String]$DataWindow = "estimate_current",
    [Bool]$InfoOnly = $false,
    [Bool]$AllowZero = $false,
    [String]$StatAverage = "Minute_10"
)

$Name = Get-Item $MyInvocation.MyCommand.Path | Select-Object -ExpandProperty BaseName
$Pool_Currency = "GRIN"
$Pool_Fee = 0.0

if (-not $Wallets.$Pool_Currency -and -not $InfoOnly) {return}

$Pool_Algorithm_Norm = Get-Algorithm "Cuckaroo29"

$Pool_Request = [PSCustomObject]@{}
$Pool_NetworkRequest = [PSCustomObject]@{}

try {
    $Pool_Request = Invoke-RestMethodAsync "https://api.grinmint.com/v1/poolStats" -cycletime ([Math]::Max(120,$Session.Config.Interval)) -tag $Name -retry 3 -retrywait 1000
    if (-not $Pool_Request.status) {throw}
    #$Pool_NetworkRequest = Invoke-RestMethodAsync "https://api.grinmint.com/v1/networkStats" -cycletime ([Math]::Max(120,$Session.Config.Interval)) -tag $Name -retry 3 -retrywait 1000 -delay 500
    #if (-not $Pool_NetworkRequest.status) {throw}
}
catch {
    if ($Error.Count){$Error.RemoveAt(0)}
    Write-Log -Level Warn "Pool API ($Name) for $($Pool_Currency) has failed. "
    return
}

$Pools_Data = @(
    [PSCustomObject]@{port = 3416; region = "eu"; host = "eu-west-stratum.grinmint.com"; ssl = $false}
    [PSCustomObject]@{port = 4416; region = "eu"; host = "eu-west-stratum.grinmint.com"; ssl = $true}
    [PSCustomObject]@{port = 3416; region = "us"; host = "us-east-stratum.grinmint.com"; ssl = $false}
    [PSCustomObject]@{port = 4416; region = "us"; host = "us-east-stratum.grinmint.com"; ssl = $true}
)

#$diffLive     = $Pool_NetworkRequest.total_difficulty
$reward       = 60
#$profitLive   = 86400/$diffLive*$reward
#$coinUnits    = 1
#$amountLive   = $profitLive / $coinUnits
$btcPrice     = if ($Session.Rates.GRIN) {1/[double]$Session.Rates.GRIN} else {0}
#$btcRewardLive= $amountLive*$btcPrice

$btcRewardLive = $btcPrice * $reward * $Pool_Request.pool_stats.blocks_found_last_24_hours / ($Pool_Request.pool_stats.primary_hashrate + $Pool_Request.pool_stats.secondary_hashrate)

$Divisor      = 1

$lastBlock = $Pool_Request.mined_blocks | select-object -first 1
$Pool_BLK = $Pool_Request.pool_stats.blocks_found_last_24_hours
$Pool_TSL = if ($lastBlock) {((Get-Date).ToUniversalTime() - (Get-Date $lastBlock.time).ToUniversalTime()).TotalSeconds}
    
if (-not $InfoOnly) {
    $Stat = Set-Stat -Name "$($Name)_$($Pool_Currency)_Profit" -Value ($btcRewardLive/$Divisor) -Duration $StatSpan -ChangeDetection $true -HashRate $Pool_Request.pool_stats.primary_hashrate -BlockRate $Pool_BLK
}

$Pools_Data | ForEach-Object {
    [PSCustomObject]@{
        Algorithm     = $Pool_Algorithm_Norm
        CoinName      = $Pool_Currency
        CoinSymbol    = $Pool_Currency
        Currency      = $Pool_Currency
        Price         = $Stat.$StatAverage #instead of .Live
        StablePrice   = $Stat.Week
        MarginOfError = $Stat.Week_Fluctuation
        Protocol      = "stratum+tcp"
        Host          = $_.host
        Port          = $_.port
        User          = "$($Wallets.GRIN)/{workername:$Worker}"
        Pass          = $Password
        Region        = $_.region
        SSL           = $_.ssl
        Updated       = $Stat.Updated
        PoolFee       = $Pool_Fee
        DataWindow    = $DataWindow
        Workers       = $Pool_Request.pool_stats.workers
        Hashrate      = $Stat.HashRate_Live
        BLK           = $Stat.BlockRate_Average
        TSL           = $Pool_TSL
        ErrorRatio    = $Stat.ErrorRatio_Average
    }
}
