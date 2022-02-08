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

$Pool_Request = [PSCustomObject]@{}
try {
    $Pool_Request = Invoke-RestMethodAsync "https://next.ton-pool.com/stats" -tag $Name -cycletime 120
}
catch {
    if ($Error.Count){$Error.RemoveAt(0)}
    Write-Log -Level Warn "Pool API ($Name) has failed. "
    return
}

[hashtable]$Pool_RegionsTable = @{}

$Pool_Regions = @("us")
$Pool_Regions | Foreach-Object {$Pool_RegionsTable.$_ = Get-Region $_}

$Pool_Currency       = "TON"
$Pool_Host           = "next.ton-pool.com"

$Pool_Coin           = Get-Coin $Pool_Currency
$Pool_Algorithm_Norm = Get-Algorithm $Pool_Coin.Algo
$Pool_Port           = $null
$Pool_PoolFee        = 5
#$Pool_Factor         = 1e9
#$Pool_EthProxy       = "ethproxy"

$Pool_User           = $Wallets.$Pool_Currency

if (-not $InfoOnly) {
    $btcPrice       = if ($Global:Rates."$($Pool_Coin.Symbol)") {1/[double]$Global:Rates."$($Pool_Coin.Symbol)"} else {0}
    $btcRewardLive  = $btcPrice * $Pool_Request.income.last_24h / 1e18

    $Stat = Set-Stat -Name "$($Name)_$($Pool_Currency)_Profit" -Value $btcRewardLive -Duration $StatSpan -ChangeDetection $false -HashRate $Pool_Request.total_hashrate_v2.last_10min -Quiet
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
            Protocol      = "https"
            Host          = $Pool_Host
            Port          = $Pool_Port
            User          = "$($Wallets.$Pool_Currency)"
            Pass          = "x"
            Region        = $Pool_RegionsTable.$Pool_Region
            SSL           = $true
            Updated       = $Stat.Updated
            PoolFee       = $Pool_PoolFee
            PaysLive      = $true
            DataWindow    = $DataWindow
            Workers       = $null
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
