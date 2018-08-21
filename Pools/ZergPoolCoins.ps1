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

if (($Pool_Request | Get-Member -MemberType NoteProperty -ErrorAction Ignore | Measure-Object Name).Count -le 1) {
    Write-Log -Level Warn "Pool API ($Name) returned nothing. "
    return
}

[hashtable]$Pool_Algorithms = @{}

$Pool_Regions = "us"#, "europe"
$Pool_Currencies = @("BTC", "DASH", "LTC") | Select-Object -Unique | Where-Object {(Get-Variable $_ -ValueOnly -ErrorAction SilentlyContinue) -or $InfoOnly}
$Pool_MiningCurrencies = ($PoolCoins_Request | Get-Member -MemberType NoteProperty -ErrorAction Ignore | Select-Object -ExpandProperty Name) | Foreach-Object {if ($PoolCoins_Request.$_.Symbol) {$PoolCoins_Request.$_.Symbol} else {$_}} | Select-Object -Unique
$Pool_PoolFee = 0.5

$Pool_MiningCurrencies | Where-Object {$PoolCoins_Request.$_.hashrate -gt 0 -or $InfoOnly} | ForEach-Object {
    $Pool_Host = "$($PoolCoins_Request.$_.algo).mine.zergpool.com"
    $Pool_Port = $PoolCoins_Request.$_.port
    $Pool_Algorithm = $PoolCoins_Request.$_.algo
    if (-not $Pool_Algorithms.ContainsKey($Pool_Algorithm)) {$Pool_Algorithms[$Pool_Algorithm] = Get-Algorithm $Pool_Algorithm}
    $Pool_Algorithm_Norm = $Pool_Algorithms[$Pool_Algorithm]
    $Pool_Coin = Get-CoinName $PoolCoins_Request.$_.name
    $Pool_Currency = $_
    $Pool_PoolFee = $Pool_Request.$Pool_Algorithm.fees

    if ($Pool_Algorithm_Norm -ne "Equihash" -and $Pool_Algorithm_Norm -like "Equihash*") {$Pool_Algorithm_All = @($Pool_Algorithm_Norm,"$Pool_Algorithm_Norm-$Pool_Currency")} else {$Pool_Algorithm_All = @($Pool_Algorithm_Norm)}

    $Divisor = 1000000000 * [Double]$Pool_Request.$Pool_Algorithm.mbtc_mh_factor
    if ($Divisor -eq 0) {
        Write-Log -Level Info "Unable to determine divisor for $Pool_Coin using $Pool_Algorithm_Norm algorithm"
        return
    }

    if (-not $InfoOnly) {
        $Stat = Set-Stat -Name "$($Name)_$($_)_Profit" -Value ([Double]$PoolCoins_Request.$_.estimate / $Divisor) -Duration $StatSpan -ChangeDetection $true
    }

    $Pool_Regions | ForEach-Object {
        $Pool_Region = $_
        $Pool_Region_Norm = Get-Region $Pool_Region

        $Pool_Algorithm_All | Foreach-Object {
            $Pool_Algorithm_Norm = $_
            if ((Get-Variable $Pool_Currency -ValueOnly -ErrorAction SilentlyContinue) -or $InfoOnly) {
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
                    User          = Get-Variable $_ -ValueOnly -ErrorAction SilentlyContinue
                    Pass          = "$Worker,c=$Pool_Currency,mc=$Pool_Currency"
                    Region        = $Pool_Region_Norm
                    SSL           = $false
                    Updated       = $Stat.Updated
                    PoolFee       = $Pool_PoolFee
                }
            }
            if ($PoolCoins_Request.$Pool_Currency.noautotrade -eq 0 -and (-not (Get-Variable $Pool_Currency -ValueOnly -ErrorAction SilentlyContinue) -or $InfoOnly)) {
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
