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
    $Pool_Request = Invoke-RestMethodAsync "https://pool.sero.cash/api/stats" -tag $Name -cycletime 120
}
catch {
    if ($Error.Count){$Error.RemoveAt(0)}
    Write-Log -Level Warn "Pool API ($Name) has failed. "
    return
}

$PoolBlocks_Request = [PSCustomObject]@{}
try {
    $PoolBlocks_Request = Invoke-RestMethodAsync "https://pool.sero.cash/api/blocks" -tag $Name -cycletime 120
}
catch {
    if ($Error.Count){$Error.RemoveAt(0)}
    Write-Log -Level Warn "Pool blocks API ($Name) has failed. "
    return
}

[hashtable]$Pool_RegionsTable = @{}

$Pool_Regions = @("asia")
$Pool_Regions | Foreach-Object {$Pool_RegionsTable.$_ = Get-Region $_}

$Pool_Currency       = "SERO"
$Pool_Host           = "pool2.sero.cash" #"pool4.sero.cash" is secondary

$Pool_Coin           = Get-Coin $Pool_Currency
$Pool_Algorithm_Norm = Get-Algorithm $Pool_Coin.Algo
$Pool_Port           = 8808
$Pool_PoolFee        = 0
$Pool_Factor         = 1e18

$Pool_User           = $Wallets.$Pool_Currency

if (-not $InfoOnly) {
    $timestamp = Get-UnixTimestamp
    $timestamp24h = $timestamp - 86400

    $blocks         =  @($PoolBlocks_Request.candidates | Select-Object timestamp,reward,orphan) + @($PoolBlocks_Request.immature | Select-Object timestamp,reward,orphan) + @($PoolBlocks_Request.matured | Select-Object timestamp,reward,orphan) | Where-Object {$_.timestamp -gt $timestamp24h}
    $blocks_measure = $blocks.timestamp | Measure-Object -Minimum -Maximum
    $Pool_BLK       = [int]$($(if ($blocks_measure.Count -gt 1 -and ($blocks_measure.Maximum - $blocks_measure.Minimum)) {86400/($blocks_measure.Maximum - $blocks_measure.Minimum)} else {1})*$blocks_measure.Count)
    $Pool_TSL       = $timestamp - ($blocks.timestamp | Measure-Object -Maximum).Maximum
        
    $blocks         = $blocks | Where-Object {$_.reward -gt 0 -and -not $_.orphan}
    $blocks_measure = $blocks.timestamp | Measure-Object -Minimum -Maximum
    $avgTime        = if ($blocks_measure.Count -gt 1) {($blocks_measure.Maximum - $blocks_measure.Minimum) / ($blocks_measure.Count - 1)} else {$timestamp}
    $reward         = $(if ($blocks) {($blocks | Measure-Object reward -Average).Average} else {0})/$Pool_Factor
    $btcPrice       = if ($Global:Rates."$($Pool_Coin.Symbol)") {1/[double]$Global:Rates."$($Pool_Coin.Symbol)"} elseif ($Global:Rates.USD) {[double]$Pool_Request.qprice/[double]$Global:Rates.USD} else {0}
    $btcRewardLive  = if ($Pool_Request.hashrate -gt 0) {$btcPrice * $reward * 86400 / $avgTime / $Pool_Request.hashrate} else {0}

    $Stat = Set-Stat -Name "$($Name)_$($Pool_Algorithm_Norm)_Profit" -Value $btcRewardLive -Duration $StatSpan -ChangeDetection $false -HashRate $Pool_Request.hashrate -BlockRate $Pool_BLK -Quiet
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
            Protocol      = "stratum+tcp"
            Host          = $Pool_Host
            Port          = $Pool_Port
            User          = "$($Wallets.$Pool_Currency)"
            Pass          = "x"
            Region        = $Pool_Regions.$Pool_Region
            SSL           = $false
            Updated       = $Stat.Updated
            PoolFee       = $Pool_PoolFee
            DataWindow    = $DataWindow
            Workers       = $Pool_Request.minersTotal
            Hashrate      = $Stat.Hashrate_Live
            BLK           = $Stat.BlockRate_Average
            TSL           = $Pool_TSL
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
