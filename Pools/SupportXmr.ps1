using module ..\Modules\Include.psm1

param(
    [PSCustomObject]$Wallets,
    [PSCustomObject]$Params,
    [alias("WorkerName")]
    [String]$Worker,
    [TimeSpan]$StatSpan,
    [String]$DataWindow = "avg",
    [Bool]$InfoOnly = $false,
    [Bool]$AllowZero = $false,
    [String]$StatAverage = "Minute_10",
    [String]$StatAverageStable = "Week"
)

$Name = Get-Item $MyInvocation.MyCommand.Path | Select-Object -ExpandProperty BaseName

$Pool_Currency = "XMR"

if (-not $Wallets.$Pool_Currency -and -not $InfoOnly) {return}

$Pool_Request = [PSCustomObject]@{}

try {
    $Pool_Request = Invoke-RestMethodAsync "https://supportxmr.com/api/pool/stats" -tag $Name -cycletime 120
}
catch {
    if ($Error.Count){$Error.RemoveAt(0)}
}

if (-not $Pool_Request.pool_statistics) {
    Write-Log -Level Warn "Pool API ($Name) has failed. "
    return
}

$Timestamp = Get-UnixTimestamp
$Timestamp24h = ($Timestamp - 86400)*1000

$Pool_BlocksRequest = @()

try {
    $Pool_BlocksRequest = Invoke-RestMethodAsync "https://supportxmr.com/api/pool/blocks?limit=100" -tag $Name -cycletime 120 | Where-Object {$_.ts -ge $Timestamp24} | Select-Object -ExpandProperty ts | Measure-Object -Minimum -Maximum
}
catch {
    if ($Error.Count){$Error.RemoveAt(0)}
    Write-Log -Level Info "Pool Currency API ($Name) has failed. "
}

$Pool_Coin = Get-Coin $Pool_Currency
$Pool_Port = 3333

$Pool_Algorithm = $Pool_Coin.Algo
$Pool_Algorithm_Norm = Get-Algorithm $Pool_Algorithm
$Pool_PoolFee = 0.6

$Pool_User = $Wallets.$Pool_Currency

$Pool_BLK = [int]$($(if ($Pool_BlocksRequest.Count -gt 1 -and ($Pool_BlocksRequest.Maximum - $Pool_BlocksRequest.Minimum)) {86400000/($Pool_BlocksRequest.Maximum - $Pool_BlocksRequest.Minimum)} else {1})*$Pool_BlocksRequest.Count)
$Pool_TSL = if ($Pool_BlocksRequest.Count) {$Timestamp - [int]($Pool_BlocksRequest.Maximum/1000)}

if (-not $InfoOnly) {
    $Stat = Set-Stat -Name "$($Name)_XMR_Profit" -Value 0 -Duration $StatSpan -ChangeDetection $false -HashRate $Pool_Request.pool_statistics.hashRate -BlockRate $Pool_BLK -Quiet
    if (-not $Stat.HashRate_Live -and -not $AllowZero) {return}
}

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
    Host          = "pool.supportxmr.com"
    Port          = $Pool_Port
    User          = "$($Pool_User){diff:+`$difficulty}"
    Pass          = "{workername:$Worker}"
    Region        = Get-Region "us"
    SSL           = $false
    Updated       = $Stat.Updated
    PoolFee       = $Pool_PoolFee
    DataWindow    = $DataWindow
    Workers       = $Pool_Request.pool_statistics.miners
    Hashrate      = $Stat.HashRate_Live
    BLK           = $Stat.BlockRate_Average
    TSL           = $Pool_TSL
    WTM           = $true
	ErrorRatio    = $Stat.ErrorRatio
    EthMode       = "stratum"
    Name          = $Name
    Penalty       = 0
    PenaltyFactor = 1
    Disabled      = $false
    HasMinerExclusions = $false
    Price_0       = 0.0
    Price_Bias    = 0.0
    Price_Unbias  = 0.0
    Wallet        = $Wallets.$Pool_Currency
    Worker        = "{workername:$Worker}"
    Email         = $Email
}
