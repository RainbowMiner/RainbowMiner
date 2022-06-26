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
    $Pool_Request = Invoke-RestMethodAsync "https://alph-pool.com/api/pool/stats" -tag $Name -cycletime 120 -retry 5 -retrywait 250
}
catch {
    if ($Error.Count){$Error.RemoveAt(0)}
    Write-Log -Level Warn "Pool API ($Name) has failed. "
    return
}

try {
    $Pool_LastBlock = Invoke-GetUrl "https://mainnet-backend.alephium.org/blocks/$($Pool_Request.last_block_hash)" -timeout 20
}
catch {
    if ($Error.Count){$Error.RemoveAt(0)}
    Write-Log -Level Info "Pool Block API ($Name) has failed. "
}

[hashtable]$Pool_RegionsTable = @{}

$Pool_Regions = @("eu","us","as","ru")
$Pool_Regions | Foreach-Object {$Pool_RegionsTable.$_ = Get-Region $_}

$Pool_Currency       = "ALPH"
$Pool_Host            = "{region}.alph-pool.com"
$Pool_Protocol        = "wss"

$Pool_Coin           = Get-Coin $Pool_Currency
$Pool_Algorithm_Norm = Get-Algorithm $Pool_Coin.Algo
$Pool_Ports          = @(20032,20033)
$Pool_PoolFee        = 100 * $Pool_Request.pool_fee.pps
#$Pool_Factor         = 1e9
$Pool_TSL             = if ($Pool_LastBlock.timestamp) {(Get-UnixTimestamp) - $Pool_LastBlock.timestamp/1000} else {$null}

$Pool_User           = $Wallets.$Pool_Currency

if (-not $InfoOnly) {
    $btcPrice       = if ($Global:Rates."$($Pool_Coin.Symbol)") {1/[double]$Global:Rates."$($Pool_Coin.Symbol)"} else {0}
    $btcRewardLive  = $btcPrice * $Pool_Request.income.last_1h / 1e18

    $Stat = Set-Stat -Name "$($Name)_$($Pool_Currency)_Profit" -Value $btcRewardLive -Duration $StatSpan -ChangeDetection $false -HashRate $Pool_Request.hashrate_10m -BlockRate $Pool_Request.found_blocks_24h -Quiet
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
                Price         = 0
                StablePrice   = 0
                MarginOfError = 0
                Protocol      = $Pool_Protocol
                Host          = $Pool_Host -replace "{region}",$Pool_Region
                Port          = $Pool_Port
                User          = "$($Wallets.$Pool_Currency)"
                Pass          = "x"
                Region        = $Pool_RegionsTable.$Pool_Region
                SSL           = $true
                Updated       = $Stat.Updated
                PoolFee       = $Pool_PoolFee
                PaysLive      = $true
                DataWindow    = $DataWindow
                Workers       = $Pool_Request.miners
                Hashrate      = $Stat.Hashrate_Live
                TSL           = $Pool_TSL
                BLK           = $Stat.BlockRate_Average
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
                Wallet        = $Wallets.$Pool_Currency
                Worker        = "{workername:$Worker}"
                Email         = $Email
                WTM           = $true
            }
        }
    }
}
