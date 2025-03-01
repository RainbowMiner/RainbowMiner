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
    [String]$StatAverageStable = "Week",
    [String]$Username,
    [String]$Password
)

$Name = Get-Item $MyInvocation.MyCommand.Path | Select-Object -ExpandProperty BaseName

$Pool_Currency = "EPIC"
$Pool_Protocol = "stratum+tcp"
$Pool_Host     = "51pool.online"
$Pool_Port     = 3416
$Pool_User     = if ($Username -ne "") {$Username} else {$Wallets.$Pool_Currency}

if (-not $InfoOnly -and -not $Pool_User) {return}

$Pool_Request = [PSCustomObject]@{}
try {
    $Pool_Request = Invoke-RestMethodAsync "https://51pool.online/api" -tag $Name -cycletime 120 -retry 5 -retrywait 250
}
catch {
}

if (-not $Pool_Request.status) {
    Write-Log -Level Warn "Pool API ($Name) has failed. "
    return
}

$Pool_PoolFee   = [double]$Pool_Request.data.poolInfo.fee

$PoolBlocks_Request = $null
try {
    $PoolBlocks_Request = Invoke-RestMethodAsync "https://51pool.online/api/blocks" -tag $Name -cycletime 120 -retry 5 -retrywait 250
}
catch {
}

if (-not $PoolBlocks_Request -or $PoolBlocks_Request -isnot [array]) {
    Write-Log -Level Info "Pool Block API ($Name) has failed. "
    return
}

$NetPer_Request   = $null
$NetBlock_Request = $null
if (-not $InfoOnly) {
    try {
        $NetPer_Request = Invoke-RestMethodAsync "https://explorer.epiccash.com/epic_explorer/v1/blockchain_block/blockminedchart?Interval=1%20week&FromDate=&ToDate=" -tag $Name -cycletime 3600 -retry 5 -retrywait 250
    }
    catch {
    }

    try {
        $NetBlock_Request = Invoke-RestMethodAsync "https://explorer.epiccash.com/epic_explorer/v1/blockchain_block/latesblockdetails" -tag $Name -cycletime 120 -retry 5 -retrywait 250
    }
    catch {
    }
}

[hashtable]$Pool_RegionsTable = @{}

$Pool_Regions  = @("eu")
$Pool_Regions | Foreach-Object {$Pool_RegionsTable.$_ = Get-Region $_}

$timestamp      = Get-UnixTimestamp
$timestamp24h   = $timestamp - 24*3600

foreach ($Pool_Algorithm in @("randomx", "progpow", "cuckoo")) {

    $Pool_Coin = Get-Coin $Pool_Currency -Algorithm $Pool_Algorithm
    if (-not $InfoOnly) {
        $blocks         = @($PoolBlocks_Request | Where-Object {$_.sym -eq "EPIC" -and $_.algo -eq $Pool_Algorithm} | Select-Object -ExpandProperty t | Where-Object {$_ -ge $timestamp24h} | Sort-Object -Descending)
        $blocks_measure = $blocks | Measure-Object -Minimum -Maximum

        $Pool_BLK       = [int]$($(if ($blocks_measure.Count -gt 1 -and ($blocks_measure.Maximum - $blocks_measure.Minimum)) {24*3600/($blocks_measure.Maximum - $blocks_measure.Minimum)} else {1})*$blocks_measure.Count)
        $Pool_TSL       = $timestamp - [int64]($blocks | Select-Object -First 1)
        
        if ($NetPer_Request.status -eq 200 -and $NetBlock_Request.status -eq 200) {
            #current_diff = last_block_total_diff - previous_block_total_diff 
            #network_hashrate = current_diff / block_target_time 
            #blocks_per_day = 1440 * algorithm_percentage
            #rig_income = (rig_hashrate / network_hashrate) * (block_reward * blocks_per_day)

            $btcPrice       = if ($Global:VarCache.Rates."$($Pool_Currency)") {1/[double]$Global:VarCache.Rates."$($Pool_Currency)"} else {0}
            $btcRewardLive  = $btcPrice * [double]($Pool_Request.data.poolBlocks.latest | Select-Object -Last 1).reward * 1440 * ($NetPer_Request.response."$($Pool_Algorithm)per" | Select-Object -Last 3 | Measure-Object -Average).Average / 100 / $NetBlock_Request.response."$($Pool_Algorithm)hashrate"
        } else {
            $btcRewardLive = 0
        }

        $Stat = Set-Stat -Name "$($Name)_$($Pool_Coin.Algo)_Profit" -Value $btcRewardLive -Duration $StatSpan -ChangeDetection $false -HashRate ([decimal]$Pool_Request.data.poolStats."hashrate$($Pool_Algorithm)") -BlockRate $Pool_BLK -Quiet
        if (-not $Stat.HashRate_Live -and -not $AllowZero) {return}
    }

    if ($Pool_User -or $InfoOnly) {
        foreach($Pool_Region in $Pool_Regions) {    
            [PSCustomObject]@{
                Algorithm     = $Pool_Coin.Algo
                Algorithm0    = $Pool_Coin.Algo
                CoinName      = $Pool_Coin.Name
                CoinSymbol    = $Pool_Currency
                Currency      = $Pool_Currency
                Price         = $Stat.$StatAverage #instead of .Live
                StablePrice   = $Stat.$StatAverageStable
                MarginOfError = $Stat.Week_Fluctuation
                Protocol      = $Pool_Protocol
                Host          = $Pool_Host -replace "{region}",$Pool_Region
                Port          = $Pool_Port
                User          = "$($Pool_User)#{workername:$Worker}"
                Pass          = $Password
                Region        = $Pool_RegionsTable.$Pool_Region
                SSL           = $false
                Updated       = $Stat.Updated
                PoolFee       = $Pool_PoolFee
                PaysLive      = $false
                DataWindow    = $DataWindow
                Workers       = $Pool_Request.data.poolStats."online$($Pool_Algorithm)"
                Hashrate      = $Stat.Hashrate_Live
                TSL           = $Pool_TSL
                BLK           = $Stat.BlockRate_Average
                WTM           = -not $btcRewardLive
                EthMode       = $null
                ErrorRatio    = $Stat.ErrorRatio
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
        }
    }
}


