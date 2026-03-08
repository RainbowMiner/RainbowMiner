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
    [String]$StatAverageStable = "Week",
    [String]$MiningAlias,
    [String]$API_Key,
    [String]$API_Secret
)

# $Name = Get-Item $MyInvocation.MyCommand.Path | Select-Object -ExpandProperty BaseName

$Pool_Currency = "EPIC"
$Pool_Ports    = @(3333,3334)
$Pool_User     = if ($MiningAlias -ne "") {$MiningAlias} else {$Wallets.$Pool_Currency}

if (-not $InfoOnly -and -not $Pool_User) {return}

$Pool_Request = [PSCustomObject]@{}
try {
    $Pool_Request = Invoke-RestMethodAsync "https://api.epicmine.io/pool/getstats" -tag $Name -cycletime 120 -retry 5 -retrywait 250
}
catch {
}

if (-not $Pool_Request.poolInfo -or -not $Pool_Request.poolStats) {
    Write-Log -Level Warn "Pool API ($Name) has failed. "
    return
}

try {
    $Pool_Locations   = Invoke-RestMethodAsync "https://api.epicmine.io/pool/getlocations" -tag $Name -cycletime 86400 -retry 5 -retrywait 250
}
catch {
}

if (-not $Pool_Locations -or -not ($Pool_Locations | Select-Object -First 1).region) {
    $Pool_Locations = @(
        [PSCustomObject]@{region="Europe";location="Germany, Europe";host="de.epicmine.io"}
        [PSCustomObject]@{region="America";location="United States, America";host="us.epicmine.io"}
        [PSCustomObject]@{region="Asia";location="Singapore, Asia";host="sg.epicmine.io"}
    )
}

$AlgoWeight = @{
    RandomX = 0.48
    ProgPow  = 0.48
    Cuckoo   = 0.04
}

$Pool_WTM = $false

if (-not $InfoOnly) {
    try {
        $NetworkHashrates = Invoke-RestMethodAsync "https://api.epicmine.io/explorer/getnetworkhashrate" -tag $Name -cycletime 120 -retry 5 -retrywait 250
        $BlockReward      = Invoke-RestMethodAsync "https://api.epicmine.io/explorer/getblockreward" -tag $Name -cycletime 7200 -retry 5 -retrywait 250
        $NetPer_Request   = Invoke-RestMethodAsync "https://explorer.epiccash.com/epic_explorer/v1/blockchain_block/blockminedchart?Interval=1%20week&FromDate=&ToDate=" -tag $Name -cycletime 7200 -retry 5 -retrywait 250
    } catch {
        $Pool_WTM = $true
    }
    if (-not $NetworkHashrates -or -not $BlockReward -or -not $NetPer_Request) {
        $Pool_WTM = $true
    }

    if (-not $Pool_WTM) {
        if ($NetPer_Request.status -eq 200) {
            $BlocksPerDay = $AlgoWeight.RandomX = $AlgoWeight.ProgPow = $AlgoWeight.Cuckoo = 0
            $Days = $NetPer_Request.response.date.Count-1
            for($i=0; $i -lt $Days; $i+=1) {
                $BlocksPerDay += $NetPer_Request.response.RandomX[$i] + $NetPer_Request.response.ProgPow[$i] + $NetPer_Request.response.Cuckoo[$i]
                $AlgoWeight.RandomX += $NetPer_Request.response.RandomXper[$i]
                $AlgoWeight.ProgPow += $NetPer_Request.response.ProgPowper[$i]
                $AlgoWeight.Cuckoo  += $NetPer_Request.response.Cuckooper[$i]
            }
            $BlocksPerDayAvg = $BlocksPerDay / $Days
            $AlgoWeight.RandomX = [Math]::Round($AlgoWeight.RandomX/$Days)/100
            $AlgoWeight.ProgPow = [Math]::Round($AlgoWeight.ProgPow/$Days)/100
            $AlgoWeight.Cuckoo = [Math]::Round($AlgoWeight.Cuckoo/$Days)/100
        }
    }
}

$Pool_PoolFee   = [double]$Pool_Request.poolInfo.fee

$timestamp      = Get-UnixTimestamp
$timestamp24h   = $timestamp - 24*3600

foreach ($Pool_Algorithm in @("RandomX", "ProgPow", "Cuckoo")) {

    $Pool_Coin = Get-Coin $Pool_Currency -Algorithm $Pool_Algorithm
    if (-not $InfoOnly) {
        $blocks         = @($Pool_Request.poolBlocks.latest | Where-Object {$_.algo -eq $Pool_Algorithm -and $_.time -ge $timestamp24h} | Sort-Object -Descending -Property time | Select-Object -ExpandProperty time)
        $blocks_measure = $blocks | Measure-Object -Minimum -Maximum

        $Pool_BLK       = [int]$($(if ($blocks_measure.Count -gt 1 -and ($blocks_measure.Maximum - $blocks_measure.Minimum)) {86400/($blocks_measure.Maximum - $blocks_measure.Minimum)} else {1})*$blocks_measure.Count)
        $Pool_TSL       = $timestamp - [int64]($blocks | Select-Object -First 1)

        if (-not $Pool_WTM) {
            $btcPrice      = if ($Global:Rates."$($Pool_Currency)") {1/[double]$Global:Rates."$($Pool_Currency)"} else {0}
            $btcRewardLive = if ($NetworkHashrates.$Pool_Algorithm -gt 0) {$BlocksPerDayAvg * $AlgoWeight.$Pool_Algorithm * $BlockReward.miners * $btcPrice / $NetworkHashrates.$Pool_Algorithm} else {0}
        } else {
            $btcRewardLive = 0
        }

        $Stat = Set-Stat -Name "$($Name)_$($Pool_Coin.Algo)_Profit" -Value $btcRewardLive -Duration $StatSpan -ChangeDetection $false -HashRate ([decimal]$Pool_Request.poolStats."hashrate$($Pool_Algorithm)") -BlockRate $Pool_BLK -Quiet
        if (-not $Stat.HashRate_Live -and -not $AllowZero) {return}
    }

    $Pool_SSL = "tsl"
    foreach($Pool_Port in $Pool_Ports) {
        foreach($Pool_Location in $Pool_Locations) {
            [PSCustomObject]@{
                Algorithm     = $Pool_Coin.Algo
                Algorithm0    = $Pool_Coin.Algo
                CoinName      = $Pool_Coin.Name
                CoinSymbol    = $Pool_Currency
                Currency      = $Pool_Currency
                Price         = $Stat.$StatAverage #instead of .Live
                StablePrice   = $Stat.$StatAverageStable
                MarginOfError = $Stat.Week_Fluctuation
                Protocol      = "stratum+$($Pool_SSL)"
                Host          = $Pool_Location.host
                Port          = $Pool_Port
                User          = "$($Pool_User).{workername:$Worker}"
                Region        = Get-Region $Pool_Location.location
                SSL           = $Pool_SSL -eq "ssl"
                Updated       = $Stat.Updated
                PoolFee       = $Pool_PoolFee
                PaysLive      = $false
                DataWindow    = $DataWindow
                Workers       = $Pool_Request.poolStats."online$($Pool_Algorithm)"
                Hashrate      = $Stat.Hashrate_Live
                TSL           = $Pool_TSL
                BLK           = $Stat.BlockRate_Average
                WTM           = $Pool_WTM
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
        $Pool_SSL = "ssl"
    }
}
