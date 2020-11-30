using module ..\Modules\Include.psm1

param(
    [PSCustomObject]$Wallets,
    [PSCustomObject]$Params,
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
$Pool_Fee = 2.5

if (-not $Wallets.$Pool_Currency -and -not $InfoOnly) {return}

$Pool_Request = [PSCustomObject]@{}
$Pool_NetworkRequest = [PSCustomObject]@{}

try {
    $Pool_Request = Invoke-RestMethodAsync "https://api.grinmint.com/v1/poolStats" -tag $Name -retry 3 -retrywait 1000 -cycletime 120
    if (-not $Pool_Request.status) {throw}
    $Pool_NetworkRequest = Invoke-RestMethodAsync "https://api.grinmint.com/v1/networkStats" -tag $Name -retry 3 -retrywait 1000 -delay 500 -cycletime 120
    if (-not $Pool_NetworkRequest.status) {throw}
}
catch {
    if ($Error.Count){$Error.RemoveAt(0)}
    Write-Log -Level Warn "Pool API ($Name) for $($Pool_Currency) has failed. "
    return
}

[hashtable]$Pool_RegionsTable = @{}

$Pool_Regions = @("eu-west","us-east")
$Pool_Regions | Foreach-Object {$Pool_RegionsTable.$_ = Get-Region $_}

$Pools_Data = @(
    [PSCustomObject]@{symbol = "GRIN-SEC"; port = 3416; ssl = $false}
    [PSCustomObject]@{symbol = "GRIN-SEC"; port = 4416; ssl = $true}
    [PSCustomObject]@{symbol = "GRIN-PRI"; port = 3416; ssl = $false; primary = $true}
    [PSCustomObject]@{symbol = "GRIN-PRI"; port = 4416; ssl = $true;  primary = $true}
)

$block_time_sec = 60

$hour_height = 3600 / $block_time_sec
$day_height  = 24 * $hour_height
$week_height = 7 * $day_height
$year_height = 52 * $week_height

#$seconday_weight = 90 - $Pool_NetworkRequest.height / (2 * $year_height / 90)

$reward = 60

$diff   = $Pool_NetworkRequest.target_difficulty
$PBR29  = (86400 / 42) * ($Pool_NetworkRequest.secondary_scaling/$diff)
#$PBR31  = (86400 / 42) * (7936/$diff) #31*2^8
$PBR32  = (86400 / 42) * (16384/$diff) #32*2^9

$PBR_Secondary = $PBR29
$PBR_Primary   = $PBR32

$lastBlock     = $Pool_Request.mined_blocks | Sort-Object height | Select-Object -last 1
$Pool_BLK      = $Pool_Request.pool_stats.blocks_found_last_24_hours
$Pool_TSL      = if ($lastBlock) {((Get-Date).ToUniversalTime() - (Get-Date $lastBlock.time).ToUniversalTime()).TotalSeconds}
$btcPrice      = if ($Global:Rates.$Pool_Currency) {1/[double]$Global:Rates.$Pool_Currency} else {0}
    
if (-not $InfoOnly) {
    $Stat_Secondary = Set-Stat -Name "$($Name)_$($Pool_Currency)-SEC_Profit" -Value ($PBR_Secondary * $reward * $btcPrice) -Duration $StatSpan -ChangeDetection $true -HashRate $Pool_Request.pool_stats.secondary_hashrate -BlockRate $Pool_BLK
    $Stat_Primary   = Set-Stat -Name "$($Name)_$($Pool_Currency)-PRI_Profit" -Value ($PBR_Primary * $reward * $btcPrice)   -Duration $StatSpan -ChangeDetection $true -HashRate $Pool_Request.pool_stats.primary_hashrate   -BlockRate $Pool_BLK
}

$Pools_Data | ForEach-Object {
    $Pool_Coin = Get-Coin $_.symbol
    $Stat = if ($_.primary) {$Stat_Primary} else {$Stat_Secondary}
    $Pool_Algorithm_Norm = Get-Algorithm $Pool_Coin.Algo
    Foreach ($Pool_Region in $Pool_Regions) {
        [PSCustomObject]@{
            Algorithm     = $Pool_Algorithm_Norm
            Algorithm0    = $Pool_Algorithm_Norm
            CoinName      = $Pool_Currency
            CoinSymbol    = $Pool_Currency
            Currency      = $Pool_Currency
            Price         = $Stat.$StatAverage #instead of .Live
            StablePrice   = $Stat.Week
            MarginOfError = $Stat.Week_Fluctuation
            Protocol      = "stratum+$(if ($_.ssl) {"ssl"} else {"tcp"})"
            Host          = "$($Pool_Region)-stratum.grinmint.com"
            Port          = $_.port
            User          = "$($Wallets.$Pool_Currency)/{workername:$Worker}"
            Pass          = $Password
            Region        = $Pool_RegionsTable.$Pool_Region
            SSL           = $_.ssl
            Updated       = $Stat.Updated
            PoolFee       = $Pool_Fee
            DataWindow    = $DataWindow
            Workers       = $Pool_Request.pool_stats.workers
            Hashrate      = $Stat.HashRate_Live
            BLK           = $Stat.BlockRate_Average
            TSL           = $Pool_TSL
            Name          = $Name
            Penalty       = 0
            PenaltyFactor = 1
            Disabled      = $false
            HasMinerExclusions = $false
            Price_Bias    = 0.0
            Price_Unbias  = 0.0
            Wallet        = $Wallets.$Pool_Currency
            Worker        = "{workername:$Worker}"
            Email         = $Email
        }
    }
}
