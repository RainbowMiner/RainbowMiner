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

$Pool_Currency       = "DNX"

if (-not $Wallets.$Pool_Currency -and -not $InfoOnly) {return}

$Pool_Request = [PSCustomObject]@{}
try {
    $Pool_Request = Invoke-RestMethodAsync "https://pool.deepminerz.com:8071/live_stats" -tag $Name -cycletime 120 -retry 5 -retrywait 250
}
catch {
    if ($Error.Count){$Error.RemoveAt(0)}
    Write-Log -Level Warn "Pool API ($Name) has failed. "
    return
}

[hashtable]$Pool_RegionsTable = @{}

$Pool_Regions = @("uk","us","sg")
$Pool_Regions | Foreach-Object {$Pool_RegionsTable.$_ = Get-Region $_}

$Pool_Host            = "pool.{region_with_dot}deepminerz.com"

$Pool_Coin           = Get-Coin $Pool_Currency
$Pool_Algorithm_Norm = Get-Algorithm $Pool_Coin.Algo
$Pool_Ports          = @(4444,9850)
$Pool_PoolFee        = [double]$Pool_Request.config.fee
$Pool_Factor         = $Pool_Request.config.coinUnits
$Pool_TSL             = if ($Pool_Request.lastblock.timestamp) {(Get-UnixTimestamp) - $Pool_Request.lastblock.timestamp} else {$null}

$Pool_User           = $Wallets.$Pool_Currency

if (-not $InfoOnly) {
    $timestamp24h = (Get-UnixTimestamp) - 24*3600

    $Pool_Blocks  = $Pool_Request.pool.blocks | Where-Object {$_ -match "^prop:.+?:.+?:(\d+)"} | Where-Object {$Matches[1] -ge $timestamp24h} | Foreach-Object {$Matches[1]}
    $Pool_Rewards = $Pool_Request.pool.blocks | Where-Object {$_ -match "^prop:.+?:.+?:\d+:.+?:.+?:.+?:([\d\.]+)"} | Where-Object {$Matches[1] -gt 0} | Foreach-Object {$Matches[1]}

    $blocks_measure = $Pool_Blocks | Measure-Object -Minimum -Maximum
    $blocks_reward  = ($Pool_Rewards | Measure-Object -Average).Average / $Pool_Factor

    $blocks_count   = $blocks_measure.Count

    $Pool_BLK       = $(if ($blocks_count -gt 1 -and ($blocks_measure.Maximum - $blocks_measure.Minimum) -gt 0) {86400/($blocks_measure.Maximum - $blocks_measure.Minimum)} else {1})*$blocks_count

    $Pool_Profit    = 0

    if ($Global:Rates.ContainsKey($Pool_Currency) -and $Global:Rates[$Pool_Currency]) {
        $Pool_Profit = (86400 / $Pool_Request.network.difficulty) * $blocks_reward / $Global:Rates[$Pool_Currency]
    }

    $Stat = Set-Stat -Name "$($Name)_$($Pool_Currency)_Profit" -Value $Pool_Profit -Duration $StatSpan -ChangeDetection $false -HashRate $Pool_Request.pool.hashrate -BlockRate $Pool_BLK -Quiet
    if (-not $Stat.HashRate_Live -and -not $AllowZero) {return}
}

if ($Pool_User -or $InfoOnly) {
    $Pool_SSL = $false
    foreach($Pool_Port in $Pool_Ports) {
        $Pool_Protocol = "stratum+$(if ($Pool_SSL) {"ssl"} else {"tcp"})"
        foreach($Pool_Region in $Pool_Regions) {    
            [PSCustomObject]@{
                Algorithm     = $Pool_Algorithm_Norm
                Algorithm0    = $Pool_Algorithm_Norm
                CoinName      = $Pool_Coin.Name
                CoinSymbol    = $Pool_Currency
                Currency      = $Pool_Currency
                Price         = $Stat.$StatAverage #instead of .Live
                StablePrice   = $Stat.$StatAverageStable
                MarginOfError = $Stat.Week_Fluctuation
                Protocol      = $Pool_Protocol
                Host          = $Pool_Host -replace "{region_with_dot}","$(if ($Pool_Region -ne "uk") {"$($Pool_Region)."})"
                Port          = $Pool_Port
                User          = "$($Pool_User){diff:+`$difficulty}"
                Pass          = "{workername:$Worker}"
                Region        = $Pool_RegionsTable.$Pool_Region
                SSL           = $Pool_SSL
                Updated       = $Stat.Updated
                PoolFee       = $Pool_PoolFee
                PaysLive      = $false
                DataWindow    = $DataWindow
                Workers       = $Pool_Request.pool.miners
                Hashrate      = $Stat.Hashrate_Live
                TSL           = $Pool_TSL
                BLK           = $Stat.BlockRate_Average
                EthMode       = $null
                ErrorRatio    = $Stat.ErrorRatio
                Mallob        = "mallob.deepminerz.com:9000,mallob.deepminerz.com:9001,http://mallob-ml.eu.neuropool.net/,http://mallob-ml.us.neuropool.net/,minenice.newpool.pw:1500"
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
        $Pool_SSL = $true
    }
}
