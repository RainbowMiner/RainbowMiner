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
    [String]$StatAverage = "Minute_10"
)

$Name = Get-Item $MyInvocation.MyCommand.Path | Select-Object -ExpandProperty BaseName

$Pool_Request = [PSCustomObject]@{}

try {
    $Pool_Request = Invoke-RestMethodAsync "https://ravenminer.com/api/status" -tag $Name -cycletime 120
}
catch {
    if ($Error.Count){$Error.RemoveAt(0)}
    Write-Log -Level Warn "Pool API ($Name) has failed. "
    return
}

try {
    $PoolCoins_Request = Invoke-RestMethodAsync "https://ravenminer.com/api/currencies" -tag $Name -cycletime 120
}
catch {
    if ($Error.Count){$Error.RemoveAt(0)}
    Write-Log -Level Info "Pool Currency API ($Name) has failed. "
}

$Pool_Currency = "RVN"
$Pool_Algorithm = if ($PoolCoins_Request.$Pool_Currency) {$PoolCoins_Request.$Pool_Currency.algo} else {"kawpow"}

$Pool_Coin = Get-Coin $Pool_Currency
$Pool_Host = "ravenminer.com"
$Pool_Algorithm_Norm = Get-Algorithm $Pool_Coin.Algo
$Pool_Ports = @(3838,13838)

[hashtable]$Pool_RegionsTable = @{}

$Pool_Regions = @("us","eu","asia")
$Pool_Regions | Foreach-Object {$Pool_RegionsTable.$_ = Get-Region $_}

$Pool_Request.PSObject.Properties.Name | Where-Object {$_ -eq $Pool_Algorithm} | Foreach-Object {
    $Pool_PoolFee = [Double]$Pool_Request.$_.fees
    $Pool_User = $Wallets.$Pool_Currency

    $Pool_Factor = $Pool_Request.$_.mbtc_mh_factor

    $Pool_TSL = if ($PoolCoins_Request) {$PoolCoins_Request.$Pool_Currency.timesincelast}else{$null}
    $Pool_BLK = $PoolCoins_Request.$Pool_Currency."24h_blocks"

    if (-not $InfoOnly) {
        $NewStat = $false; if (-not (Test-Path "Stats\Pools\$($Name)_$($Pool_Algorithm_Norm)_Profit.txt")) {$NewStat = $true; $DataWindow = "actual_last24h"}
        $Pool_Price = Get-YiiMPValue $Pool_Request.$_ -DataWindow $DataWindow -Factor $Pool_Factor
        $Stat = Set-Stat -Name "$($Name)_$($Pool_Algorithm_Norm)_Profit" -Value $Pool_Price -Duration $(if ($NewStat) {New-TimeSpan -Days 1} else {$StatSpan}) -ChangeDetection $false -Actual24h $($Pool_Request.$_.actual_last24h/1000) -Estimate24h $($Pool_Request.$_.estimate_last24h) -HashRate $Pool_Request.$_.hashrate -BlockRate $Pool_BLK -Quiet
        if (-not $Stat.HashRate_Live -and -not $AllowZero) {return}
    }

    $Pool_Params = if ($Params.$Pool_Currency) {",$($Params.$Pool_Currency)"}

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
                    StablePrice   = $Stat.Week
                    MarginOfError = $Stat.Week_Fluctuation
                    Protocol      = "stratum+$(if ($Pool_SSL) {"ssl"} else {"tcp"})"
                    Host          = "$($Pool_Region).$($Pool_Host)"
                    Port          = $Pool_Port
                    User          = $Pool_User
                    Pass          = "{workername:$Worker},c=$Pool_Currency{diff:,d=`$difficulty}$Pool_Params"
                    Region        = $Pool_Regions.$Pool_Region
                    SSL           = $Pool_SSL
                    Updated       = $Stat.Updated
                    PoolFee       = $Pool_PoolFee
                    DataWindow    = $DataWindow
                    Workers       = $Pool_Request.$_.workers
                    Hashrate      = $Stat.HashRate_Live
                    BLK           = $Stat.BlockRate_Average
                    TSL           = $Pool_TSL
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
}
