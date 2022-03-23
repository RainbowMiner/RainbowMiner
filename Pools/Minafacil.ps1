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
$PoolCoins_Request = [PSCustomObject]@{}

try {
    $PoolCoins_Request = Invoke-RestMethodAsync "https://pool.minafacil.com/api/currencies" -tag $Name -cycletime 120
}
catch {
    if ($Error.Count){$Error.RemoveAt(0)}
    Write-Log -Level Warn "Pool API ($Name) has failed. "
    return
}

if (-not ($PoolCoins_Request | Get-Member -MemberType NoteProperty -ErrorAction Ignore | Measure-Object Name).Count) {
    Write-Log -Level Warn "Pool API ($Name) returned nothing. "
    return
}

try {
    $Pool_Request = Invoke-RestMethodAsync "https://pool.minafacil.com/api/status" -tag $Name -cycletime 120
}
catch {
    if ($Error.Count){$Error.RemoveAt(0)}
    Write-Log -Level Warn "Pool status API ($Name) has failed. "
}

[hashtable]$Pool_RegionsTable = @{}

$Pool_Regions = @("us","eu")
$Pool_Regions | Foreach-Object {$Pool_RegionsTable.$_ = Get-Region $_}

$Pool_Host = "pool.minafacil.com"
$Pool_Ports = @(4000,5555)

$PoolCoins_Request.PSObject.Properties.Name | Where-Object {$Wallets.$_ -or $InfoOnly} | Foreach-Object {

    $Pool_CoinSymbol = $_
    $Pool_Coin = Get-Coin $Pool_CoinSymbol
    $Pool_PoolFee = [Double]$PoolCoins_Request.$Pool_CoinSymbol.fees
    $Price_BTC = 0

    if (-not $InfoOnly) {
        $Pool_Algo  = $PoolCoins_Request.$Pool_CoinSymbol.algo
        $Pool_TSL   = [Int64]$PoolCoins_Request.$Pool_CoinSymbol.timesincelast
        $Pool_BLK   = [Int64]$PoolCoins_Request.$Pool_CoinSymbol."24h_blocks"
        $Pool_HR    = [Double]$PoolCoins_Request.$Pool_CoinSymbol.hashrate
        $Pool_HR24h = [Double]$Pool_Request.$Pool_Algo.hashrate_last24h

        $reward     = [Double]$PoolCoins_Request.$Pool_CoinSymbol.reward
        $difficulty = [Double]$PoolCoins_Request.$Pool_CoinSymbol.difficulty
        $rate       = if ($Global:Rates.$Pool_CoinSymbol) {1/$Global:Rates.$Pool_CoinSymbol} else {0}

        $NewStat    = $false

        $Price_BTC  = if ($rate -and $reward) {
            if (-not (Test-Path "Stats\Pools\$($Name)_$($Pool_CoinSymbol)_Profit.txt") -and $Pool_HR24h) {
                $NewStat = $true
                $rate * $reward * $Pool_BLK / $Pool_HR24h
            } elseif ($difficulty) {
                $rate * $reward * 86400 / ($difficulty * [Math]::Pow(2,32))
            }
        }

        $Stat = Set-Stat -Name "$($Name)_$($Pool_CoinSymbol)_Profit" -Value $Price_BTC -Duration $(if ($NewStat) {New-TimeSpan -Days 1} else {$StatSpan}) -ChangeDetection $true -HashRate $Pool_HR -BlockRate $Pool_BLK -Quiet
        if (-not $Stat.HashRate_Live -and -not $AllowZero) {return}
    }

    foreach($Pool_Region in $Pool_Regions) {
        $Pool_SSL = $false
        $Pool_FailOver = @([PSCustomObject]@{
                                Protocol = "stratum+tcp"
                                Host     = "$(if ($Pool_Region -ne "us") {$Pool_Region})$Pool_Host"
                                Port     = 4001
                                User     = "$($Wallets.$Pool_CoinSymbol).{workername:$Worker}"
                                Pass     = "c=$($Pool_CoinSymbol)"
                            })
        foreach($Pool_Port in $Pool_Ports) {
            [PSCustomObject]@{
                Algorithm     = $Pool_Coin.Algo
                Algorithm0    = $Pool_Coin.Algo
                CoinName      = $Pool_Coin.Name
                CoinSymbol    = $Pool_CoinSymbol
                Currency      = $Pool_CoinSymbol
                Price         = $Stat.$StatAverage #instead of .Live
                StablePrice   = $Stat.$StatAverageStable
                MarginOfError = $Stat.Week_Fluctuation
                Protocol      = "stratum+$(if ($Pool_SSL) {"ssl"} else {"tcp"})"
                Host          = "$(if ($Pool_Region -ne "us") {$Pool_Region})$Pool_Host"
                Port          = $Pool_Port
                User          = "$($Wallets.$Pool_CoinSymbol).{workername:$Worker}"
                Pass          = "c=$($Pool_CoinSymbol)"
                Region        = $Pool_RegionsTable.$Pool_Region
                SSL           = $false
                Updated       = $Stat.Updated
                PoolFee       = $Pool_PoolFee
                Failover      = $Pool_FailOver
                DataWindow    = $DataWindow
                Workers       = $PoolCoins_Request.$Pool_CoinSymbol.workers_shared
                Hashrate      = $Stat.HashRate_Live
                BLK           = $Stat.BlockRate_Average
                TSL           = $Pool_TSL
                WTM           = $Price_BTC -eq 0
			    ErrorRatio    = $Stat.ErrorRatio
                Name          = $Name
                Penalty       = 0
                PenaltyFactor = 1
                Disabled      = $false
                HasMinerExclusions = $false
                Price_0       = 0.0
                Price_Bias    = 0.0
                Price_Unbias  = 0.0
                Wallet        = $Wallets.$Pool_CoinSymbol
                Worker        = "{workername:$Worker}"
                Email         = $Email
            }
            $Pool_SSL = $true
            $Pool_FailOver = $null
        }
    }
}
