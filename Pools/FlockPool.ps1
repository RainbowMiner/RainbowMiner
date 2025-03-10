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
    [String]$StatAverageStable = "Week"
)

# $Name = Get-Item $MyInvocation.MyCommand.Path | Select-Object -ExpandProperty BaseName

$Pool_Request = [PSCustomObject]@{}
try {
    $Pool_Request = Invoke-RestMethodAsync "https://flockpool.com/api/v1/pool-stats" -tag $Name -cycletime 120
}
catch {
    Write-Log -Level Warn "Pool API ($Name) has failed. "
    return
}

try {
    $Timestamp24h = (Get-Date).AddHours(-24).ToUniversalTime()
    $PoolBlocks_Request = (Invoke-RestMethodAsync "https://explorer.raptoreum.com/api/getblocks?start=0&length=100&search[value]=&search[regex]=false" -tag $Name -cycletime 120).data | Where-Object {$_.Miner.name -eq "flockpool"} | Foreach-Object {Get-Date $_.Timestamp} | Where-Object {$_ -ge $Timestamp24h}
} catch {
    Write-Log -Level Info "Pool Blocks API ($Name) has failed. "
}

[hashtable]$Pool_RegionsTable = @{}

$Pool_Regions = @("eu","us","us-west","asia")
$Pool_Regions | Foreach-Object {$Pool_RegionsTable.$_ = Get-Region "$(if ($_ -eq "us") {"us-central"} else {$_})"}

$Pool_Currency       = "RTM"
$Pool_Host           = "flockpool.com"

$Pool_Coin           = Get-Coin $Pool_Currency
$Pool_Algorithm_Norm = $Pool_Coin.Algo
$Pool_Ports          = @(4444,5555)
$Pool_PoolFee        = 1
$Pool_Factor         = 1
$Pool_EthProxy       = $null

$Pool_User           = $Wallets.$Pool_Currency

if (-not $InfoOnly) {

    if ($PoolBlocks_Request) {
        $blocks_measure = $PoolBlocks_Request | Measure-Object -Minimum -Maximum
        $Pool_BLK       = [int]$($(if ($blocks_measure.Count -gt 1 -and ($blocks_measure.Maximum - $blocks_measure.Minimum).TotalDays) {1/($blocks_measure.Maximum - $blocks_measure.Minimum).TotalDays} else {1})*$blocks_measure.Count)
        $Pool_TSL       = ((Get-Date).ToUniversalTime() - $blocks_measure.Maximum).TotalSeconds
    } else {
        $Pool_BLK = $Pool_TSL = $null
    }

    $Pool_Hashrate = $null
    $Pool_Request.regions | Foreach-Object {
        $region_hr = [int64]($_.hashrate_graph.hashrate | Foreach-Object {[int64]($_ -replace ".\d+$")} | select-object -last 15 | Select-Object -SkipLast 1 | Measure-Object -Average).Average
        if ($region_hr -gt 0) {
            if ($Pool_Hashrate -eq $null) {$Pool_Hashrate = 0}
            $Pool_Hashrate += $region_hr
        }
    }

    $Stat = Set-Stat -Name "$($Name)_$($Pool_Currency)_Profit" -Value 0 -Duration $StatSpan -ChangeDetection $false -HashRate $Pool_Hashrate -BlockRate $Pool_BLK -Quiet

    $hashrates_results = $null
    if (-not $Stat.HashRate_Live -and -not $AllowZero) {return}
}

if ($Pool_User -or $InfoOnly) {
    $Pool_SSL = $false
    foreach($Pool_Port in $Pool_Ports) {
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
                Protocol      = if ($Pool_SSL) {"stratum+ssl"} else {"stratum+tcp"}
                Host          = "$($Pool_Region).$($Pool_Host)"
                Port          = $Pool_Port
                User          = "$($Wallets.$Pool_Currency).{workername:$Worker}"
                Pass          = "x"
                Region        = $Pool_RegionsTable.$Pool_Region
                SSL           = $Pool_SSL
                Updated       = $Stat.Updated
                PoolFee       = $Pool_PoolFee
                DataWindow    = $DataWindow
                Workers       = $Pool_Request.active_workers
                Hashrate      = $Stat.Hashrate_Live
                TSL           = $Pool_TSL
                BLK           = if ($Pool_BLK -ne $null) {$Stat.BlockRate_Average} else {$null}
                WTM           = $true
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
            }
        }
        $Pool_SSL = $true
    }
}
