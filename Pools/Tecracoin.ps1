using module ..\Include.psm1

param(
    [PSCustomObject]$Wallets,
    [PSCustomObject]$Params,
    [alias("WorkerName")]
    [String]$Worker,
    [TimeSpan]$StatSpan,
    [String]$DataWindow = "avg",
    [Bool]$InfoOnly = $false,
    [Bool]$AllowZero = $false,
    [String]$StatAverage = "Minute_10"
)

$Name = Get-Item $MyInvocation.MyCommand.Path | Select-Object -ExpandProperty BaseName

$Pool_Request = [PSCustomObject]@{}
try {
    $Pool_Request = Invoke-RestMethodAsync "https://rbminer.net/api/data/tecracoin.json" -tag $Name -cycletime 120
}
catch {if ($Error.Count){$Error.RemoveAt(0)}}

if ($Pool_Request.TCR_MTP -eq $null) {
    Write-Log -Level Info "Pool API ($Name) has failed. "
    return
}

[hashtable]$Pool_RegionsTable = @{}

$Pool_Regions = @("us")
$Pool_Regions | Foreach-Object {$Pool_RegionsTable.$_ = Get-Region $_}

$Pool_Coin           = "Tecracoin"
$Pool_Currency       = "TCR"
$Pool_Host           = "pool.tecracoin.io"
$Pool_Algorithm_Norm = Get-Algorithm "MTPTcr"
$Pool_Port           = [int]$Pool_Request.TCR_MTP.port
$Pool_PoolFee        = [Double]$Pool_Request.TCR_MTP.fees
$Pool_Factor         = $Pool_Request.TCR_MTP.mbtc_mh_factor
$Pool_TSL            = $Pool_Request.TCR_MTP.timesincelast
$Pool_BLK            = $Pool_Request.TCR_MTP."24h_blocks"

$Pool_User           = $Wallets.$Pool_Currency

if (-not $InfoOnly) {
    $multiplicator = 32
    $blockreward   = 1.125 # only 1% of 112.5 goes to miners
    $rate          = if ($Global:Rates.TCR) {1/$Global:Rates.TCR} else {0}
    $difficulty = try {Invoke-RestMethodAsync "https://explorer.tecracoin.io/api/getdifficulty" -tag $Name -cycletime 120} catch {if ($Error.Count){$Error.RemoveAt(0)}}
    $Price_BTC = if ($difficulty -and $rate) {$rate * $blockreward * 86400 / ($difficulty * [Math]::Pow(2,$multiplicator))} else {0}
    $Stat = Set-Stat -Name "$($Name)_$($Pool_Algorithm_Norm)_Profit" -Value $Price_BTC -Duration $StatSpan -ChangeDetection $false -HashRate $Pool_Request.TCR_MTP.hashrate -BlockRate $Pool_BLK -Quiet
    if (-not $Stat.HashRate_Live -and -not $AllowZero) {return}
}

$Pool_Params = if ($Params.$Pool_Currency) {",$($Params.$Pool_Currency)"}
    
if ($Pool_User -or $InfoOnly) {
    foreach($Pool_Region in $Pool_Regions) {
        [PSCustomObject]@{
            Algorithm     = $Pool_Algorithm_Norm
            Algorithm0    = $Pool_Algorithm_Norm
            CoinName      = $Pool_Coin
            CoinSymbol    = $Pool_Currency
            Currency      = $Pool_Currency
            Price         = $Stat.$StatAverage #instead of .Live
            StablePrice   = $Stat.Week
            MarginOfError = $Stat.Week_Fluctuation
            Protocol      = "stratum+tcp"
            Host          = $Pool_Host
            Port          = $Pool_Port
            User          = $Pool_User
            Pass          = "{workername:$Worker}{diff:,d=`$difficulty}$Pool_Params"
            Region        = $Pool_Regions.$Pool_Region
            SSL           = $false
            Updated       = $Stat.Updated
            PoolFee       = $Pool_PoolFee
            DataWindow    = $DataWindow
            Workers       = $Pool_Request.TCR_MTP.workers
            Hashrate      = $Stat.HashRate_Live
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

