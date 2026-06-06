using module ..\Modules\Include.psm1

param(
    [String]$Name,
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

# $Name = Get-Item $MyInvocation.MyCommand.Path | Select-Object -ExpandProperty BaseName

$Pool_Currency = "PRL"

$Pool_Host   = @{eu="84.32.220.219"; asia="129.226.55.135"}
$Pool_Ports  = @(9000)
$Pool_Wallet = $Wallets.$Pool_Currency
$Pool_Pass   = "x"
$Pool_Fee    = 0.00

$Pool_Coin  = Get-Coin $Pool_Currency
$Pool_Algorithm_Norm = $Pool_Coin.Algo

[hashtable]$Pool_RegionsTable = @{}

$Pool_Regions = @("eu","asia")
$Pool_Regions | Foreach-Object {$Pool_RegionsTable.$_ = Get-Region $_}

$Pool_TLS = $Pool_BLK  = $null
$Pool_PPS = $Pool_Solo = $false


if (-not $InfoOnly) {

    $Pool_Request    = [PSCustomObject]@{}
    $Network_Request = [PSCustomObject]@{}
    try {
        $Pool_Request    = Invoke-RestMethodAsync "https://pearlhash.xyz/api/stats" -tag $Name -cycletime 120
        $Network_Request = Invoke-RestMethodAsync "https://pearlhash.xyz/api/chain-info" -tag $Name -cycletime 120
    }
    catch {
        Write-Log -Level Warn "Pool API ($Name) has failed. "
        return
    }

    $PoolBlocks_Request = [PSCustomObject]@{}
    try {
        $PoolBlocks_Request = Invoke-RestMethodAsync "https://pearlhash.xyz/api/pool-wallet-txs?page=1" -tag $Name -cycletime 120
    }
    catch {
        Write-Log -Level Warn "Pool blocks API ($Name) has failed. "
    }

    $timestamp       = Get-UnixTimestamp
    $timestamp24h    = $timestamp - 86400

    $blocks          = $PoolBlocks_Request.transactions | Where-Object {-not $_.vin[0].isAddress -and $_.vin[0].coinbase} | Select-Object -ExpandProperty blockTime | Sort-Object -Descending
    $blocks_measure  = $blocks | Where-Object {$_ -gt $timestamp24h} | Measure-Object -Minimum -Maximum
    $Pool_BLK        = [int]$($(if ($blocks_measure.Count -gt 1 -and ($blocks_measure.Maximum - $blocks_measure.Minimum)) {86400/($blocks_measure.Maximum - $blocks_measure.Minimum)} else {1})*$blocks_measure.Count)
    $Pool_TSL        = [int]($timestamp - ($blocks | Select-Object -First 1))

    $Stat = Set-Stat -Name "$($Name)_$($Pool_Currency)_Profit" -Value 0 -Duration $StatSpan -HashRate $Pool_Request.hashrate -BlockRate $Pool_BLK -Difficulty $Network_Request.difficulty -ChangeDetection $false -Quiet
    if (-not $Stat.HashRate_Live -and -not $AllowZero) {return}
}

if ($Pool_Wallet -or $Info_Only) {
    foreach($Pool_Region in $Pool_Regions) {
        $Pool_SSL = $false
        foreach($Pool_Port in $Pool_Ports) {
            [PSCustomObject]@{
                Algorithm     = $Pool_Algorithm_Norm
                Algorithm0    = $Pool_Algorithm_Norm
                CoinName      = $Pool_Coin.Name
                CoinSymbol    = $Pool_Currency
                Currency      = $Pool_Currency
                Price         = 0
                StablePrice   = 0
                MarginOfError = 0
                Protocol      = "stratum+$(if ($Pool_SSL) {"ssl"} else {"tcp"})"
                Host          = "$($Pool_Host[$Pool_Region])"
                Port          = $Pool_Port
                User          = $Pool_Wallet
                Pass          = $Pool_Pass
                Region        = $Pool_Regions.$Pool_Region
                SSL           = $Pool_SSL
                Updated       = $Stat.Updated
                PoolFee       = $Pool_Fee
                DataWindow    = $DataWindow
                Workers       = if (-not $Pool_Solo) {$Pool_Request.total_workers} else {$null}
                Hashrate      = if (-not $Pool_Solo) {$Stat.HashRate_Live} else {$null}
                BLK           = if (-not $Pool_Solo) {$Stat.BlockRate_Average} else {$null}
                TSL           = if (-not $Pool_Solo) {$Pool_TSL} else {$null}
                WTM           = $true
                PaysLive      = $Pool_PPS
                Difficulty    = if ($Pool_Solo) {$Stat.Diff_Average} else {$null}
                SoloMining    = $Pool_Solo
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
                Wallet        = $Pool_Wallet
                Worker        = "{workername:$Worker}"
                Email         = $Email
            }
            $Pool_SSL = $true
        }
    }
}
