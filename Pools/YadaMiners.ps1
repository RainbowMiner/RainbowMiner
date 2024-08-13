using module ..\Modules\Include.psm1

param(
    [PSCustomObject]$Wallets,
    [PSCustomObject]$Params,
    [alias("WorkerName")]
    [String]$Worker,
    [String]$Password,
    [TimeSpan]$StatSpan,
    [String]$DataWindow = "estimate_current",
    [Bool]$InfoOnly = $false,
    [Bool]$AllowZero = $false,
    [String]$StatAverage = "Minute_10",
    [String]$StatAverageStable = "Week"
)

$Name = Get-Item $MyInvocation.MyCommand.Path | Select-Object -ExpandProperty BaseName

$Pool_Currency = "YDA"

if (-not $Wallets.$Pool_Currency -and -not $InfoOnly) {return}

[hashtable]$Pool_RegionsTable = @{}

$Pool_Regions = @("eu")
$Pool_Regions | Foreach-Object {$Pool_RegionsTable.$_ = Get-Region $_}

$Pool_Coin = Get-Coin $Pool_Currency
$Pool_Algorithm_Norm = $Pool_Coin.Algo

$Pool_BLK = $Pool_TSL = $null

if (-not $InfoOnly) {

    $Pool_Request = @()

    try {
        $Pool_Request = Invoke-RestMethodAsync "http://yadaminers.pl/pool-info" -tag $Name -retry 3 -retrywait 1000 -timeout 15 -cycletime 120
    }
    catch {
        if ($Error.Count){$Error.RemoveAt(0)}
    }

    if ($Pool_Request.pool) {
        $Pool_BLK = 0
        $Pool_Request.pool.avg_block_time -replace "(\d)\s+(\w)","`$1-`$2" -split "\s+" | Foreach-Object {
            $blk = $_ -split "-"
            $Pool_BLK += [int]$blk[0] * $(switch -regex ($blk[1]) {
                "^m" {60}
                "^h" {3600}
                "^d" {86400}
                "^y" {31536000}
            })
        }

        $Pool_BLK = if ($Pool_BLK -gt 0) {[int](86400 / $Pool_BLK)} else {$null}
        $Pool_TSL = [int]((Get-UnixTimestamp) - ($Pool_Request.pool.last_five_blocks.timestamp | Measure-Object -Maximum).Maximum)
    }

    $Stat = Set-Stat -Name "$($Name)_$($Pool_Currency)_Profit" -Value 0 -Duration $StatSpan -ChangeDetection $false -HashRate $Pool_Request.pool.hashes_per_second -BlockRate $Pool_BLK
    if (-not $Stat.HashRate_Live -and -not $AllowZero) {return}
}

foreach ($Pool_Region in $Pool_Regions) {
    [PSCustomObject]@{
        Algorithm     = $Pool_Algorithm_Norm
		Algorithm0    = $Pool_Algorithm_Norm
        CoinName      = $Pool_Coin.Name
        CoinSymbol    = $Pool_Currency
        Currency      = $Pool_Currency
        Price         = 0
        StablePrice   = 0
        MarginOfError = 0
        Protocol      = "stratum+tcp"
        Host          = "yadaminers.pl"
        Port          = 3333
        User          = $Wallets.$Pool_Currency
        Pass          = "x"
        Region        = $Pool_RegionsTable.$Pool_Region
        SSL           = $false
        Updated       = $Stat.Updated
        PoolFee       = [double]$Pool_Request.pool.pool_fee*100
        DataWindow    = $DataWindow
        Workers       = [int]$Pool_Request.pool.worker_count
        Hashrate      = $Stat.HashRate_Live
        BLK           = if ($Pool_BLK -ne $null) {$Stat.BlockRate_Average} else {$null}
        TSL           = $Pool_TSL
        WTM           = $true
        Name          = $Name
        Penalty       = 0
        PenaltyFactor = 1
        Disabled      = $false
        HasMinerExclusions = $false
        Price_0       = 0.0
        Price_Bias    = 0.0
        Price_Unbias  = 0.0
        Wallet        = $Pool_User
        Worker        = "{workername:$Worker}"
        Email         = $Email
    }
}
