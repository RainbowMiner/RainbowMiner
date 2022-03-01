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

#https://ton-reports-24d2v.ondigitalocean.app/report/hashrate
#https://ton-reports-24d2v.ondigitalocean.app/report/mining
#https://ton-reports-24d2v.ondigitalocean.app/report/pool-daily
#https://ton-reports-24d2v.ondigitalocean.app/report/payouts
#https://ton-reports-24d2v.ondigitalocean.app/report/pool-profitability

$Pool_Request = [PSCustomObject]@{}
try {
    $Pool_Request = Invoke-RestMethodAsync "https://ton-reports-24d2v.ondigitalocean.app/report/pool-profitability" -tag $Name -cycletime 120
}
catch {
    if ($Error.Count){$Error.RemoveAt(0)}
    Write-Log -Level Warn "Pool API ($Name) has failed. "
    return
}

$PoolHashrate_Request = [PSCustomObject]@{}
try {
    $PoolHashrate_Request = Invoke-RestMethodAsync "https://ton-reports-24d2v.ondigitalocean.app/report/hashrate" -tag $Name -cycletime 120
}
catch {
    if ($Error.Count){$Error.RemoveAt(0)}
    Write-Log -Level Warn "Pool hashrate API ($Name) has failed. "
    return
}

$PoolDailyReport_Request = [PSCustomObject]@{}
try {
    $PoolDailyReport_Request = Invoke-RestMethodAsync "https://ton-reports-24d2v.ondigitalocean.app/report/pool-daily" -tag $Name -cycletime 120
}
catch {
    if ($Error.Count){$Error.RemoveAt(0)}
}

if ($PoolDailyReport_Request.type -ne "ok") {
    Write-Log -Level Warn "Pool dailyreport API ($Name) has failed. "
    return
}


[hashtable]$Pool_RegionsTable = @{}

$Pool_Regions = @("ru")
$Pool_Regions | Foreach-Object {$Pool_RegionsTable.$_ = Get-Region $_}

$Pool_Currency       = "TON"
$Pool_Host           = "tcp.whalestonpool.com"
$Pool_Protocol       = "stratum+tcp"
$Pool_Port           = 4001

$Pool_Coin           = Get-Coin $Pool_Currency
$Pool_Algorithm_Norm = Get-Algorithm $Pool_Coin.Algo
$Pool_PoolFee        = 0
#$Pool_Factor         = 1e9
$Pool_EthProxy       = "icemining"

$Pool_User           = $Wallets.$Pool_Currency

if (-not $InfoOnly) {
    $btcPrice       = if ($Global:Rates."$($Pool_Coin.Symbol)") {1/[double]$Global:Rates."$($Pool_Coin.Symbol)"} else {0}
    $btcRewardLive  = $btcPrice * $Pool_Request.profitabilityPerGh / 1e18
    $Pool_Hashrate  = $PoolHashrate_Request.hashrate * 0.75

    $Stat = Set-Stat -Name "$($Name)_$($Pool_Currency)_Profit" -Value $btcRewardLive -Duration $StatSpan -ChangeDetection $false -HashRate $Pool_Hashrate -Quiet
    if (-not $Stat.HashRate_Live -and -not $AllowZero) {return}
}

if ($Pool_User -or $InfoOnly) {
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
            Host          = $Pool_Host
            Port          = $Pool_Port
            User          = "$($Wallets.$Pool_Currency)"
            Pass          = "x"
            Region        = $Pool_RegionsTable.$Pool_Region
            SSL           = $false
            Updated       = $Stat.Updated
            PoolFee       = $Pool_PoolFee
            DataWindow    = $DataWindow
            Workers       = $PoolDailyReport_Request.data.Count
            Hashrate      = $Stat.Hashrate_Live
            TSL           = $null
            BLK           = $null
            EthMode       = $Pool_EthProxy
            ErrorRatio    = $Stat.ErrorRatio
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
