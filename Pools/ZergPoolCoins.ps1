using module ..\Include.psm1

param(
    [alias("Wallet")]
    [String]$BTC, 
    [alias("WorkerName")]
    [String]$Worker, 
    [TimeSpan]$StatSpan,
    [Bool]$InfoOnly = $false
)

$Name = Get-Item $MyInvocation.MyCommand.Path | Select-Object -ExpandProperty BaseName

$Pool_Request = [PSCustomObject]@{}
$PoolCoins_Request = [PSCustomObject]@{}

try {
    $Pool_Request = Invoke-RestMethodAsync "http://api.zergpool.com:8080/api/status" -retry 5 -retrywait 500
    $PoolCoins_Request = Invoke-RestMethodAsync "http://api.zergpool.com:8080/api/currencies" -retry 5 -retrywait 750
}
catch {
    Write-Log -Level Warn "Pool API ($Name) has failed. "
    return
}

if (($PoolCoins_Request | Get-Member -MemberType NoteProperty -ErrorAction Ignore | Measure-Object Name).Count -le 1) {
    Write-Log -Level Warn "Pool API ($Name) returned nothing. "
    return
}

[hashtable]$Pool_Algorithms = @{}

$Pool_Regions = "us"#, "europe"
$Pool_Currencies = @("BTC", "DASH", "LTC") | Select-Object -Unique | Where-Object {(Get-Variable $_ -ValueOnly -ErrorAction SilentlyContinue) -or $InfoOnly}
$Pool_MiningCurrencies = @($PoolCoins_Request | Get-Member -MemberType NoteProperty -ErrorAction Ignore | Select-Object -ExpandProperty Name) | Foreach-Object {if ($PoolCoins_Request.$_.Symbol) {$PoolCoins_Request.$_.Symbol} else {$_}} | Select-Object -Unique
$Pool_PoolFee = 0.5

foreach($Pool_Currency in $Pool_MiningCurrencies) {
    if ($PoolCoins_Request.$Pool_Currency.hashrate -le 0 -and -not $InfoOnly) {continue}

    $Pool_Host = "$($PoolCoins_Request.$Pool_Currency.algo).mine.zergpool.com"
    $Pool_Port = $PoolCoins_Request.$Pool_Currency.port
    $Pool_Algorithm = $PoolCoins_Request.$Pool_Currency.algo
    if (-not $Pool_Algorithms.ContainsKey($Pool_Algorithm)) {$Pool_Algorithms[$Pool_Algorithm] = Get-Algorithm $Pool_Algorithm}
    $Pool_Algorithm_Norm = $Pool_Algorithms[$Pool_Algorithm]
    $Pool_Coin = $PoolCoins_Request.$Pool_Currency.name
    $Pool_PoolFee = $Pool_Request.$Pool_Algorithm.fees
    $Pool_User = Get-Variable $Pool_Currency -ValueOnly -ErrorAction SilentlyContinue

    if ($Pool_Algorithm_Norm -ne "Equihash" -and $Pool_Algorithm_Norm -like "Equihash*") {$Pool_Algorithm_All = @($Pool_Algorithm_Norm,"$Pool_Algorithm_Norm-$Pool_Currency")} else {$Pool_Algorithm_All = @($Pool_Algorithm_Norm)}

    $Divisor = 1000000000 * [Double]$Pool_Request.$Pool_Algorithm.mbtc_mh_factor
    if ($Divisor -eq 0) {
        Write-Log -Level Info "Unable to determine divisor for $Pool_Coin using $Pool_Algorithm_Norm algorithm"
        return
    }

    if (-not $InfoOnly) {
        $Stat = Set-Stat -Name "$($Name)_$($Pool_Currency)_Profit" -Value ([Double]$PoolCoins_Request.$Pool_Currency.estimate / $Divisor) -Duration $StatSpan -ChangeDetection $true
    }

    foreach($Pool_Region in @($Pool_Regions)) {
        $Pool_Region_Norm = Get-Region $Pool_Region

        foreach($Pool_Algorithm_Norm in $Pool_Algorithm_All) {            
            if ($Pool_User -or $InfoOnly) {
                #Option 2
                [PSCustomObject]@{
                    Algorithm     = $Pool_Algorithm_Norm
                    CoinName      = $Pool_Coin
                    CoinSymbol    = $Pool_Currency
                    Currency      = $Pool_Currency
                    Price         = $Stat.Hour #instead of .Live
                    StablePrice   = $Stat.Week
                    MarginOfError = $Stat.Week_Fluctuation
                    Protocol      = "stratum+tcp"
                    Host          = if ($Pool_Region -eq "us") {$Pool_Host} else {"$Pool_Region.$Pool_Host"}
                    Port          = $Pool_Port
                    User          = $Pool_User
                    Pass          = "$Worker,c=$Pool_Currency,mc=$Pool_Currency"
                    Region        = $Pool_Region_Norm
                    SSL           = $false
                    Updated       = $Stat.Updated
                    PoolFee       = $Pool_PoolFee
                }
            }
            if ($PoolCoins_Request.$Pool_Currency.noautotrade -eq 0 -and -not $Pool_User -and -not $InfoOnly) {
                $Pool_Currencies | ForEach-Object {
                    #Option 3
                    [PSCustomObject]@{
                        Algorithm     = $Pool_Algorithm_Norm
                        CoinName      = $Pool_Coin
                        CoinSymbol    = $Pool_Currency
                        Currency      = $_
                        Price         = $Stat.Hour #instead of .Live
                        StablePrice   = $Stat.Week
                        MarginOfError = $Stat.Week_Fluctuation
                        Protocol      = "stratum+tcp"
                        Host          = if ($Pool_Region -eq "us") {$Pool_Host}else {"$Pool_Region.$Pool_Host"}
                        Port          = $Pool_Port
                        User          = Get-Variable $_ -ValueOnly -ErrorAction SilentlyContinue
                        Pass          = "$Worker,c=$_,mc=$Pool_Currency"
                        Region        = $Pool_Region_Norm
                        SSL           = $false
                        Updated       = $Stat.Updated
                        PoolFee       = $Pool_PoolFee
                    }
                }
            }
        }
    }
}
