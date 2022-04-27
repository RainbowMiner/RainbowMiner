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
    [String]$StatAverageStable = "Week",
    [String]$AECurrency = ""
)

$Name = Get-Item $MyInvocation.MyCommand.Path | Select-Object -ExpandProperty BaseName

$Pool_Request = [PSCustomObject]@{}
$PoolCoins_Request = [PSCustomObject]@{}

try {
    $PoolCoins_Request = Invoke-RestMethodAsync "https://www.zpool.ca/api/currencies" -tag $Name -cycletime 120 -delay 750 -timeout 30
}
catch {
    if ($Error.Count){$Error.RemoveAt(0)}
    Write-Log -Level Warn "Pool currencies API ($Name) has failed. "
    return
}

if (($PoolCoins_Request | Get-Member -MemberType NoteProperty -ErrorAction Ignore | Measure-Object Name).Count -le 1) {
    Write-Log -Level Warn "Pool API ($Name) returned nothing. "
    return
}

try {
    $Pool_Request = Invoke-RestMethodAsync "https://www.zpool.ca/api/status" -tag $Name -cycletime 120 -delay 750 -timeout 30
}
catch {
    if ($Error.Count){$Error.RemoveAt(0)}
    Write-Log -Level Warn "Pool API ($Name) has failed. "
}

$Pool_Fee = 0.45

[hashtable]$Pool_Algorithms = @{}
[hashtable]$Pool_RegionsTable = @{}

$Pool_Regions = @("na","eu","sea","jp")
$Pool_Regions | Foreach-Object {$Pool_RegionsTable.$_ = Get-Region $_}

$Pool_Currencies = @("BTC","LTC","DASH","DGB","KMD","RVN","DOGE") + @($PoolCoins_Request.PSObject.Properties | Where-Object {$_.Value.conversion_disabled -ne "1" -and $_.Name -notmatch "HashTap" -and $_.Value.algo -notmatch "HashTap"} | Foreach-Object {if ($_.Value.symbol -eq $null){$_.Name} else {$_.Value.symbol}} | Select-Object -Unique) | Select-Object -Unique | Where-Object {$Wallets.$_ -or $InfoOnly}

if ($AECurrency -eq "") {$AECurrency = $Pool_Currencies | Select-Object -First 1}

$PoolCoins_Request.PSObject.Properties.Name | Where-Object {$_ -notmatch "HashTap" -and $PoolCoins_Request.$_.algo -notmatch "HashTap" -and $PoolCoins_Request.$_.name -notmatch "HashTap"} | ForEach-Object {

    $Pool_CoinSymbol = $_
    $Pool_Currency = if ($PoolCoins_Request.$Pool_CoinSymbol.symbol) {$PoolCoins_Request.$Pool_CoinSymbol.symbol} else {$Pool_CoinSymbol}

    $Pool_Host = "mine.zpool.ca"
    $Pool_Algorithm = $PoolCoins_Request.$Pool_CoinSymbol.algo
    if (-not $Pool_Algorithms.ContainsKey($Pool_Algorithm)) {$Pool_Algorithms.$Pool_Algorithm = Get-Algorithm $Pool_Algorithm}
    $Pool_Algorithm_Norm = $Pool_Algorithms.$Pool_Algorithm
    $Pool_Coin = $PoolCoins_Request.$Pool_CoinSymbol.name
    $Pool_PoolFee = if ($Pool_Request.$Pool_Algorithm) {[double]$Pool_Request.$Pool_Algorithm.fees} else {$Pool_Fee}

    $Pool_Factor = [double]$Pool_Request.$Pool_Algorithm.mbtc_mh_factor
    if ($Pool_Factor -le 0) {
        Write-Log -Level Info "$($Name): Unable to determine divisor for algorithm $Pool_Algorithm. "
        return
    }

    $Divisor = 1e6 * $Pool_Factor

    $Pool_TSL = $PoolCoins_Request.$Pool_CoinSymbol.timesincelast
    
    if (-not $InfoOnly) {
        $Stat = Set-Stat -Name "$($Name)_$($Pool_CoinSymbol)_Profit" -Value ([Double]$PoolCoins_Request.$Pool_CoinSymbol.estimate / $Divisor) -Duration $StatSpan -ChangeDetection $true -HashRate $PoolCoins_Request.$Pool_CoinSymbol.hashrate -BlockRate $PoolCoins_Request.$Pool_CoinSymbol."24h_blocks" -Quiet
        if (-not $Stat.HashRate_Live -and -not $AllowZero) {return}
    }

    $Pool_ExCurrency = if ($Wallets.$Pool_Currency -or $InfoOnly) {$Pool_Currency} else {$AECurrency}

    if (($Pool_ExCurrency -and $Wallets.$Pool_ExCurrency) -or $InfoOnly) {
        $Pool_Params = if ($Params."$($Pool_ExCurrency)-$($Pool_CoinSymbol)") {",$($Params."$($Pool_ExCurrency)-$($Pool_CoinSymbol)")"} elseif ($Params.$Pool_ExCurrency) {",$($Params.$Pool_ExCurrency)"}

        foreach($Pool_SSL in ($false,$true)) {
            if ($Pool_SSL) {
                if (-not $PoolCoins_Request.$Pool_CoinSymbol.ssl_port) {continue}
                $Pool_Port_SSL = [int]$PoolCoins_Request.$Pool_CoinSymbol.ssl_port
                $Pool_Protocol = "stratum+ssl"
            } else {
                $Pool_Port_SSL = [int]$PoolCoins_Request.$Pool_CoinSymbol.port
                $Pool_Protocol = "stratum+tcp"
            }

            foreach($Pool_Region in $Pool_Regions) {
                #Option 2/3
                [PSCustomObject]@{
                    Algorithm     = $Pool_Algorithm_Norm
                    Algorithm0    = $Pool_Algorithm_Norm
                    CoinName      = $Pool_Coin
                    CoinSymbol    = $Pool_CoinSymbol
                    Currency      = $Pool_ExCurrency
                    Price         = $Stat.$StatAverage #instead of .Live
                    StablePrice   = $Stat.$StatAverageStable
                    MarginOfError = $Stat.Week_Fluctuation
                    Protocol      = $Pool_Protocol
                    Host          = "$Pool_Algorithm.$Pool_Region.$Pool_Host"
                    Port          = $Pool_Port_SSL
                    User          = $Wallets.$Pool_ExCurrency
                    Pass          = "{workername:$Worker},c=$Pool_ExCurrency,zap=$Pool_CoinSymbol{diff:,sd=`$difficulty}$Pool_Params"
                    Region        = $Pool_RegionsTable.$Pool_Region
                    SSL           = $Pool_SSL
                    SSLSelfSigned = $Pool_SSL
                    Updated       = $Stat.Updated
                    PoolFee       = $Pool_PoolFee
                    Workers       = $PoolCoins_Request.$Pool_CoinSymbol.workers
                    Hashrate      = $Stat.HashRate_Live
                    BLK           = $Stat.BlockRate_Average
                    TSL           = $Pool_TSL
				    ErrorRatio    = $Stat.ErrorRatio
                    Name          = $Name
                    Penalty       = 0
                    PenaltyFactor = 1
                    Disabled      = $false
                    HasMinerExclusions = $false
                    Price_0       = 0.0
                    Price_Bias    = 0.0
                    Price_Unbias  = 0.0
                    Wallet        = $Wallets.$Pool_ExCurrency
                    Worker        = "{workername:$Worker}"
                    Email         = $Email
                }
            }
        }
    }
}
