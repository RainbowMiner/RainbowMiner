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

$Pool_Request = [PSCustomObject]@{}
try {
    $Pool_Request = Invoke-RestMethodAsync "https://www.ravenminer.com/api/v1/dashboard" -tag $Name -cycletime 120
}
catch {
    if ($Error.Count){$Error.RemoveAt(0)}
    Write-Log -Level Warn "Pool API ($Name) has failed. "
    return
}

$PoolBlocks_Request = [PSCustomObject]@{}
try {
    $PoolBlocks_Request = Invoke-RestMethodAsync "https://www.ravenminer.com/api/v1/blocks" -tag $Name -cycletime 120
}
catch {
    if ($Error.Count){$Error.RemoveAt(0)}
    Write-Log -Level Warn "Pool blocks API ($Name) has failed. "
}

$Pool_Currency = "RVN"

$Pool_Coin = Get-Coin $Pool_Currency
$Pool_Host = "ravenminer.com"
$Pool_Algorithm_Norm = Get-Algorithm $Pool_Coin.Algo
$Pool_Ports = @(3838,13838)

[hashtable]$Pool_RegionsTable = @{}

$Pool_Regions = @("us","eu","asia")
$Pool_Regions | Foreach-Object {$Pool_RegionsTable.$_ = Get-Region $_}

$Pool_Fee_PPLNS = 0.5
$Pool_Fee_PPS   = 2.0 #add "pps" to "RVN-Params" in pools.config.txt

$Pool_User = $Wallets.$Pool_Currency

$Pool_TSL = if ($PoolBlocks_Request.blocks) {(Get-UnixTimestamp) - ($PoolBlocks_Request.blocks | Sort-Object -Property time -Descending | Select-Object -First 1).time} else {$null}
$Pool_BLK = ($Pool_Request.history | Where-Object day -eq 1).blocks

$Pool_WTM = $false

if (-not $InfoOnly) {
    $Pool_Price = if ($Pool_Request.hashrate -and $Pool_Request.poolTtfSec) {(86400/$Pool_Request.poolTtfSec)*$Pool_Request.coin.reward*$Pool_Request.coin.priceBTC/$Pool_Request.hashrate} else {0;$Pool_WTM = $true}
    $Stat = Set-Stat -Name "$($Name)_$($Pool_Algorithm_Norm)_Profit" -Value $Pool_Price -Duration $StatSpan -ChangeDetection $false -HashRate $Pool_Request.hashrate -BlockRate $Pool_BLK -Quiet
    if (-not $Stat.HashRate_Live -and -not $AllowZero) {return}
}

$Pool_Params = "$(if ($Params.$Pool_Currency) {",$($Params.$Pool_Currency)"})"

$Pool_PoolFee = if ($Pool_Params -match ",pps(,|$)") {$Pool_Fee_PPS} else {$Pool_Fee_PPLNS}

if ($Pool_User -or $InfoOnly) {
    foreach($Pool_Region in $Pool_Regions) {
        $Pool_SSL = $false
        foreach($Pool_Port in $Pool_Ports) {
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
                Host          = "$($Pool_Region).$($Pool_Host)"
                Port          = $Pool_Port
                User          = $Pool_User
                Pass          = "{workername:$Worker}$Pool_Params"
                Region        = $Pool_Regions.$Pool_Region
                SSL           = $Pool_SSL
                Updated       = $Stat.Updated
                PoolFee       = $Pool_PoolFee
                DataWindow    = $DataWindow
                Workers       = $Pool_Request.workersNum
                Hashrate      = $Stat.HashRate_Live
                BLK           = $Stat.BlockRate_Average
                TSL           = $Pool_TSL
                WTM           = $Pool_WTM
				ErrorRatio    = $Stat.ErrorRatio
                EthMode       = "stratum"
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
            $Pool_SSL = $true
        }
    }
}
