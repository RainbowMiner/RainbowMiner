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
    if ($Global:Error.Count){$Global:Error.RemoveAt(0)}
    Write-Log -Level Warn "Pool API ($Name) has failed. "
    return
}

[hashtable]$Pool_RegionsTable = @{}

$Pool_Regions = @("uk","us","us2","sg","uae","kaunda","xpone","rondy") #soon: "redpanda","xpone","rondy"
$Pool_Regions | Foreach-Object {
    $Region = Switch ($_) {
        "us"       {"uswest";break}
        "us2"      {"useast";break}
        "kaunda"   {"eunorth";break}
        "pasteyy"  {"fr";break}
        "redpanda" {"ca";break}
        "xpone"    {"eueast";break}
        "rondy"    {"us";break}
        default    {$_}
    }
    $Pool_RegionsTable.$_ = Get-Region $Region
}

$Pool_Host            = "pool.{region_with_dot}deepminerz.com"

$Pool_Coin           = Get-Coin $Pool_Currency
$Pool_Algorithm_Norm = $Pool_Coin.Algo
$Pool_Ports          = @(4444,9850)
$Pool_PoolFee        = [double]$Pool_Request.config.soloFee
$Pool_Factor         = $Pool_Request.config.coinUnits
$Pool_TSL             = if ($Pool_Request.lastblock.timestamp) {(Get-UnixTimestamp) - $Pool_Request.lastblock.timestamp} else {$null}

$Pool_User           = $Wallets.$Pool_Currency

if (-not $InfoOnly) {
    $Stat = Set-Stat -Name "$($Name)_$($Pool_Currency)_Profit" -Value 0 -Duration $StatSpan -ChangeDetection $false -HashRate $Pool_Request.pool.hashrateSolo -Difficulty $Pool_Request.network.difficulty -Quiet
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
                Price         = 0
                StablePrice   = 0
                MarginOfError = 0
                Protocol      = $Pool_Protocol
                Host          = $Pool_Host -replace "{region_with_dot}","$(if ($Pool_Region -ne "uk") {"$($Pool_Region)."})"
                Port          = $Pool_Port
                User          = "SOLO:$($Pool_User){diff:+`$difficulty}"
                Pass          = "{workername:$Worker}"
                Region        = $Pool_RegionsTable.$Pool_Region
                SSL           = $Pool_SSL
                Updated       = $Stat.Updated
                PoolFee       = $Pool_PoolFee
                PaysLive      = $false
                DataWindow    = $DataWindow
                Workers       = $null
                Hashrate      = $null
                TSL           = $null
                BLK           = $null
                Difficulty    = $Stat.Diff_Average
                SoloMining    = $true
                WTM           = $true
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
