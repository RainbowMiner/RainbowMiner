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
    [String]$StatAverageStable = "Minute_10"
)

$Name = Get-Item $MyInvocation.MyCommand.Path | Select-Object -ExpandProperty BaseName

$Pool_Currency = "ETH"
$Pool_User     = $Wallets.$Pool_Currency

if (-not $Pool_User -and -not $InfoOnly) {return}

$Pool_Regions = @("us-east","us-west","de","sg","au","br","in")

[hashtable]$Pool_RegionsTable = @{}
$Pool_Regions | Foreach-Object {$Pool_RegionsTable.$_ = Get-Region $_}

$Pool_PoolFee = 1.0
$Pool_Divisor = 1e18
$Pool_Ports   = @(4444,5555)

$Pool_Coin = Get-Coin $Pool_Currency
$Pool_Algorithm_Norm = Get-Algorithm $Pool_Coin.Algo

if (-not $InfoOnly) {

    $Pool_HashRate = [PSCustomObject]@{}
    $Pool_Workers  = [PSCustomObject]@{}

    $ok = $false
    try {
        $Pool_HashRate = Invoke-RestMethodAsync "https://flexpool.io/api/v1/pool/hashrate" -tag $Name -cycletime 120
        $Pool_Workers = Invoke-RestMethodAsync "https://flexpool.io/api/v1/pool/workersOnline" -tag $Name -cycletime 120
        $ok = -not $Pool_HashRate.error -and -not $Pool_Workers.error
    }
    catch {
        if ($Error.Count){$Error.RemoveAt(0)}
        Write-Log -Level Warn "$($_.Exception.Message)"
    }

    if (-not $ok) {
        Write-Log -Level Warn "Pool API ($Name) has failed. "
        return
    }

    $blocks = @()

    $page   = 0
    $number = 0
    do {
        $ok = $false
        try {
            $Pool_BlocksResult  = [PSCustomObject]@{}
            $Pool_BlocksResult = Invoke-RestMethodAsync "https://flexpool.io/api/v1/pool/blocks?page=$($page)" -retry 3 -retrywait 1000 -tag $Name -cycletime 180 -fixbigint

            $timestamp    = Get-UnixTimestamp
            $timestamp24h = $timestamp - 24*3600

            $ok = -not $Pool_BlocksResult.error -and (++$page -lt $Pool_BlocksResult.result.total_pages)
            if (-not $Pool_BlocksResult.error) {
                $Pool_BlocksResult.result.data | Where-Object {$_.number -lt $number -or -not $number} | Foreach-Object {
                    if ($_.timestamp -gt $timestamp24h) {$blocks += $_.timestamp} else {$ok = $false}
                    $number = $_.number
                }
            }
        }
        catch {
            if ($Error.Count){$Error.RemoveAt(0)}
        }
    } until (-not $ok)

    $timestamp    = Get-UnixTimestamp

    $blocks_measure = $blocks | Measure-Object -Minimum -Maximum
    $avgTime        = if ($blocks_measure.Count -gt 1) {($blocks_measure.Maximum - $blocks_measure.Minimum) / ($blocks_measure.Count - 1)} else {$timestamp}
    $Pool_BLK       = [int]$(if ($avgTime) {86400/$avgTime})
    $Pool_TSL       = $timestamp - ($blocks | Measure-Object -Maximum).Maximum

    $Stat = Set-Stat -Name "$($Name)_$($Pool_Currency)_Profit" -Value 0 -Duration $StatSpan -ChangeDetection $false -HashRate $Pool_HashRate.result.total -BlockRate $Pool_BLK -Quiet
    if (-not $Stat.HashRate_Live -and -not $AllowZero) {return}
}

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
            Host          = "eth-$($Pool_Region).flexpool.io"
            Port          = $Pool_Port
            User          = "$($Pool_User).{workername:$Worker}"
            Pass          = "x"
            Region        = $Pool_RegionsTable.$Pool_Region
            SSL           = $Pool_SSL
            Updated       = $Stat.Updated
            PoolFee       = $Pool_PoolFee
            DataWindow    = $DataWindow
            Workers       = $Pool_Workers.result
            Hashrate      = $Stat.HashRate_Live
            BLK           = $Stat.BlockRate_Average
            TSL           = $Pool_TSL
            WTM           = $true
            ErrorRatio    = $Stat.ErrorRatio
            EthMode       = "ethproxy"
            Name          = $Name
            Penalty       = 0
            PenaltyFactor = 1
            Disabled      = $false
            HasMinerExclusions = $false
            Price_Bias    = 0.0
            Price_Unbias  = 0.0
            Wallet        = $Pool_User
            Worker        = "{workername:$Worker}"
            Email         = $Email
        }
        $Pool_SSL = $true
    }
}
