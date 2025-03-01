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
    [String]$StatAverage = "Minute_10",
    [String]$StatAverageStable = "Week"
)

$Name = Get-Item $MyInvocation.MyCommand.Path | Select-Object -ExpandProperty BaseName

$Pool_Currency = "BLOCX"

if (-not $Wallets.$Pool_Currency -and -not $InfoOnly) {return}

$Pool_Request = [PSCustomObject]@{}

$ok = $false
try {
    $Pool_Request = Invoke-RestMethodAsync "https://api.thepool.zone/v1/blocx/pool/stats" -tag $Name -retry 3 -retrywait 1000 -cycletime 120
    if (-not $Pool_Request.error -and $Pool_Request.result) {$ok = $true}
}
catch {
}

if (-not $ok) {
    Write-Log -Level Warn "Pool API ($Name) for $($Pool_Currency) has failed. "
    return
}

[hashtable]$Pool_RegionsTable = @{}

$Pool_Regions = @("europe","usa-east","usa-west","asia-east","asia-west")
$Pool_Regions | Foreach-Object {
    $reg = $_
    if ($reg -eq "asia-east") {$reg = "jp"}
    elseif ($reg -eq "asia-west") {$reg = "sg"}
    $Pool_RegionsTable.$_ = Get-Region $reg
}

$Pool_Fee      = 1
$Pool_Ports    = @(3368,4468)
$Pool_User     = $Wallets.$Pool_Currency

$Pool_Coin = Get-Coin $Pool_Currency
$Pool_Algorithm_Norm = $Pool_Coin.Algo

$Pool_BLK       = $null
$Pool_TSL       = $null
$btcRewardLive  = 0

if (-not $InfoOnly) {
    $blocks_reward = 0
    try {
        $Pool_LuckRequest = Invoke-RestMethodAsync "https://api.thepool.zone/v1/blocx/pool/blocks?page=1" -tag $Name -retry 3 -retrywait 1000 -cycletime 120
        if (-not $Pool_LuckRequest.error -and $Pool_LuckRequest.result) {
            $blocks_reward   = ($Pool_LuckRequest.result.data.reward | Measure-Object -Average).Average
            $blocks_measure  = $Pool_LuckRequest.result.data | Where-Object {-not $_.solo} | Measure-Object -Minimum -Maximum -Property timestamp

            $blocks_count    = $blocks_measure.Count
            $blocks_totalsec = $blocks_measure.Maximum - $blocks_measure.Minimum

            $Pool_BLK       = [int]$(if ($blocks_count -gt 1 -and $blocks_totalsec) {86400000/$blocks_totalsec} else {1})*$blocks_count
            $Pool_TSL       = [int]((Get-UnixTimestamp) - ($Pool_LuckRequest.result.data | Select-Object -First 1).timestamp/1000)
        }
    }
    catch {
    }

    #try {
    #    $Pool_NetRequest = Invoke-RestMethodAsync "https://api.thepool.zone/v1/blocx/network/stats" -tag $Name -retry 3 -retrywait 1000 -cycletime 120
    #    if (-not $Pool_NetRequest.error -and $Pool_NetRequest.result) {
    #        $btcPrice       = if ($Global:Rates.$Pool_Currency) {1/[double]$Global:Rates.$Pool_Currency} else {0}
    #        $btcRewardLive  = if ($Pool_NetRequest.result.networkHashrate) {$btcPrice * $blocks_reward * 1440 / $Pool_NetRequest.result.networkHashrate} else {0}
    #    }
    #}
    #catch {
    #    
    #}

    $Stat = Set-Stat -Name "$($Name)_$($Pool_Currency)_Profit" -Value $btcRewardLive -Duration $StatSpan -ChangeDetection $false -HashRate $Pool_Request.result.currentHashrate -BlockRate $Pool_BLK
    if (-not $Stat.HashRate_Live -and -not $AllowZero) {return}
}

foreach ($Pool_Region in $Pool_Regions) {
    $Pool_SSL = $false
    foreach ($Pool_Port in $Pool_Ports) {
        [PSCustomObject]@{
            Algorithm     = $Pool_Algorithm_Norm
		    Algorithm0    = $Pool_Algorithm_Norm
            CoinName      = $Pool_Coin.Name
            CoinSymbol    = $Pool_Currency
            Currency      = $Pool_Currency
            Price         = $Stat.$StatAverage #instead of .Live
            StablePrice   = $Stat.$StatAverageStable
            MarginOfError = $Stat.Week_Fluctuation
            Protocol      = "stratum+$(if ($Pool_SSL) {"ssl"} else {"tcp"})"
            Host          = "$($Pool_Region).thepool.zone"
            Port          = $Pool_Port
            User          = "$($Pool_User).{workername:$Worker}"
            Pass          = "x"
            Region        = $Pool_RegionsTable.$Pool_Region
            SSL           = $Pool_SSL
            Updated       = $Stat.Updated
            PoolFee       = $Pool_Fee
            DataWindow    = $DataWindow
            Workers       = $Pool_Request.result.activeWorkers
            Hashrate      = $Stat.HashRate_Live
            BLK           = $Stat.BlockRate_Average
            TSL           = $Pool_TSL
            WTM           = -not $btcRewardLive
            Name          = $Name
            Penalty       = 0
            PenaltyFactor = 1
            Disabled      = $false
            HasMinerExclusions = $false
            Price_0       = 0.0
            Price_Bias    = 0.0
            Price_Unbias  = 0.0
            Wallet        = $Pool_User
            Worker        = "{workername:$Worker}"
            Email         = $Email
        }
        $Pool_SSL = $true
    }
}
