using module ..\Include.psm1

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
$Pool_Currency = "CTXC"
$Pool_Fee = 0.0

if (-not $Wallets.$Pool_Currency -and -not $InfoOnly) {return}

$Pool_Request = [PSCustomObject]@{}
$Pool_NetworkRequest = [PSCustomObject]@{}
$Pool_BlocksRequest = [PSCustomObject]@{}

$ok = $true
try {
    $Pool_Request = Invoke-RestMethodAsync "http://cortexmint.com/api/stats" -tag $Name -retry 3 -retrywait 1000 -cycletime 120
    if (-not $Pool_Request.now) {$ok = $false}
    else {
        $Pool_BlocksRequest = Invoke-RestMethodAsync "http://cortexmint.com/api/blocks" -tag $Name -retry 3 -retrywait 1000 -cycletime 120
        if (-not $Pool_BlocksRequest.matured) {$ok = $false}
        #$Pool_NetworkRequest = Invoke-RestMethodAsync "https://cerebro.cortexlabs.ai/mysql?type=basicInfo" -tag $Name -retry 3 -retrywait 1000 -cycletime 120
        #if ($Pool_NetworkRequest.status -ne "success") {$ok = $false}
    }
}
catch {
    if ($Error.Count){$Error.RemoveAt(0)}
    $ok = $false
}

if (-not $ok) {
    Write-Log -Level Warn "Pool API ($Name) for $($Pool_Currency) has failed. "
    return
}

[hashtable]$Pool_RegionsTable = @{}

@("us") | Foreach-Object {$Pool_RegionsTable.$_ = Get-Region $_}

$Pools_Data = @(
    [PSCustomObject]@{algo = "Cortex"; port = 8008; ssl = $false}
)

$timestamp     = [int]($Pool_Request.now /1000)
$timestamp24h  = $timestamp - 24*3600

$lastBlock     = $Pool_Request.stats.lastBlockFound

$blocks_measure= $Pool_BlocksRequest.matured | Where-Object {$_.timestamp -ge $timestamp24h} | Measure-Object timestamp -Minimum -Maximum

$Pool_BLK      = [int]$($(if ($blocks_measure.Count -gt 1 -and ($blocks_measure.Maximum - $blocks_measure.Minimum)) {24*3600/($blocks_measure.Maximum - $blocks_measure.Minimum)} else {1})*$blocks_measure.Count)
$Pool_TSL      = [Math]::Round($Pool_Request.now/1000 - $lastBlock,0)

$diffLive     = [decimal]$Pool_Request.nodes[0].difficulty
$reward       = [decimal]$Pool_BlocksRequest.matured[0].reward
$profitLive   = if ($diffLive) {86400/$diffLive*$reward/1e18} else {0}

$btcPrice      = if ($Global:Rates.$Pool_Currency) {1/[double]$Global:Rates.$Pool_Currency} else {0}
   
if (-not $InfoOnly) {
    $Stat = Set-Stat -Name "$($Name)_$($Pool_Currency)_Profit" -Value ($profitLive * $btcPrice) -Duration $StatSpan -ChangeDetection $true -HashRate $Pool_Request.hashrate -BlockRate $Pool_BLK
}

$Pools_Data | ForEach-Object {
    $Pool_Algorithm_Norm = Get-Algorithm $_.algo
    Foreach ($Pool_Region in $Pool_RegionsTable.Keys) {
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
            Host          = "cuckoo.cortexmint.com"
            Port          = $_.port
            User          = "$($Wallets.$Pool_Currency).{workername:$Worker}"
            Pass          = $Password
            Region        = $Pool_RegionsTable.$Pool_Region
            SSL           = $_.ssl
            Updated       = $Stat.Updated
            PoolFee       = $Pool_Fee
            DataWindow    = $DataWindow
            Workers       = $Pool_Request.minersTotal
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
