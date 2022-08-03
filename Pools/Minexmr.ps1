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

$Pool_Currency  = "XMR"
$Pool_CoinName  = "Monero"
$Pool_Algorithm_Norm = Get-Algorithm "Monero"
$Pool_Fee       = 1.0

if (-not $Wallets.$Pool_Currency -and -not $InfoOnly) {return}

$Name = Get-Item $MyInvocation.MyCommand.Path | Select-Object -ExpandProperty BaseName

[hashtable]$Pool_RegionsTable = @{}

$Pool_Regions = @("pool","fr","de","ca","sg","us-west")
$Pool_Regions | Foreach-Object {$Pool_RegionsTable.$_ = Get-Region $_}
$Pool_RegionsTable.pool = Get-Region "Eu"

$Pool_Ports = @(4444,443)

$Pool_Request = [PSCustomObject]@{}

if (-not $InfoOnly) {
    try {
        $Pool_Request = Invoke-RestMethodAsync "https://minexmr.com/api/main/pool/stats" -tag $Name -timeout 15 -cycletime 120
    }
    catch {
        if ($Error.Count){$Error.RemoveAt(0)}
        Write-Log -Level Warn "Pool API ($Name) for $Pool_Currency has failed. "
        return
    }
}

if (-not $InfoOnly) {
    $Pool_TSL   = [int]((Get-UnixTimestamp) - $Pool_Request.pool.lastBlockFound/1000)
    $Pool_Price = if ($Global:Rates.XMR) {$Pool_Request.network.reward/($Pool_Request.network.difficulty*1e12)*86400/$Global:Rates.XMR} else {0}
    $Stat = Set-Stat -Name "$($Name)_$($Pool_Currency)_Profit" -Value $Pool_Price -Duration $StatSpan -ChangeDetection $false -HashRate $Pool_Request.pool.hashrate -BlockRate $Pool_Request.pool.blocksDay -Quiet
    Write-Log -Level Warn "Pool $($Name) will shutdown on August 12th 2022"
}

if ($AllowZero -or $Pool_Request.pool.hashrate -gt 0 -or $InfoOnly) {
    $Pool_SSL = $false
    foreach ($Pool_Port in $Pool_Ports) {
        foreach($Pool_Region in $Pool_Regions) {
            [PSCustomObject]@{
                Algorithm     = $Pool_Algorithm_Norm
                Algorithm0    = $Pool_Algorithm_Norm
                CoinName      = $Pool_CoinName
                CoinSymbol    = $Pool_Currency
                Currency      = $Pool_Currency
                Price         = if ($Pool_Price -gt 0) {$Stat.$StatAverage} else {0}
                StablePrice   = if ($Pool_Price -gt 0) {$Stat.$StatAverageStable} else {0}
                MarginOfError = if ($Pool_Price -gt 0) {$Stat.Week_Fluctuation} else {0}
                Protocol      = "stratum+$(if ($Pool_SSL) {"ssl"} else {"tcp"})"
                Host          = "$($Pool_Region).minexmr.com"
                Port          = $Pool_Port
                User          = "$($Wallets.$Pool_Currency).{workername:$Worker}"
                Pass          = "x"
                Region        = $Pool_RegionsTable.$Pool_Region
                SSL           = $Pool_SSL
                Updated       = $Stat.Updated
                PoolFee       = $Pool_Fee
                Workers       = $Pool_Request.pool.activeMiners
                Hashrate      = $Stat.HashRate_Live
                TSL           = $Pool_TSL
                BLK           = $Stat.BlockRate_Average
                WTM           = $Pool_Price -eq 0
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
