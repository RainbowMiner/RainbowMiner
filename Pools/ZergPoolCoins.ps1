using module ..\Include.psm1

param(
    [alias("Wallet")]
    [String]$BTC, 
    [alias("WorkerName")]
    [String]$Worker, 
    [TimeSpan]$StatSpan
)

$Name = Get-Item $MyInvocation.MyCommand.Path | Select-Object -ExpandProperty BaseName

$ZergPool_Request = [PSCustomObject]@{}
$ZergPoolCoins_Request = [PSCustomObject]@{}

try {
    $ZergPool_Request = Invoke-RestMethodAsync "http://api.zergpool.com:8080/api/status"
    $ZergPoolCoins_Request = Invoke-RestMethodAsync "http://api.zergpool.com:8080/api/currencies"
}
catch {
    Write-Log -Level Warn "Pool API ($Name) has failed. "
    return
}

if (($ZergPool_Request | Get-Member -MemberType NoteProperty -ErrorAction Ignore | Measure-Object Name).Count -le 1) {
    Write-Log -Level Warn "Pool API ($Name) returned nothing. "
    return
}

$ZergPool_Regions = "us"#, "europe"
$ZergPool_Currencies = @("BTC", "DASH", "LTC") | Select-Object -Unique | Where-Object {Get-Variable $_ -ValueOnly -ErrorAction SilentlyContinue}
$ZergPool_MiningCurrencies = ($ZergPoolCoins_Request | Get-Member -MemberType NoteProperty -ErrorAction Ignore | Select-Object -ExpandProperty Name) | Foreach-Object {if ($ZergPoolCoins_Request.$_.Symbol) {$ZergPoolCoins_Request.$_.Symbol} else {$_}} | Select-Object -Unique | Where-Object {(Get-Variable $_ -ValueOnly -ErrorAction SilentlyContinue) -or $InfoOnly}
$ZergPool_PoolFee = 0.5

$ZergPool_MiningCurrencies | Where-Object {$ZergPoolCoins_Request.$_.hashrate -gt 0} | ForEach-Object {
    $ZergPool_Port = $ZergPoolCoins_Request.$_.port
    $ZergPool_Algorithm = $ZergPoolCoins_Request.$_.algo
    $ZergPool_Algorithm_Norm = Get-Algorithm $ZergPool_Algorithm
    $ZergPool_Host = "$($ZergPool_Algorithm).mine.zergpool.com"
    $ZergPool_Coin = Get-CoinName $ZergPoolCoins_Request.$_.name
    $ZergPool_Currency = $_
    $ZergPool_PoolFee = $ZergPool_Request.$ZergPool_Algorithm.fees

    $Divisor = 1000000000 * [Double]$ZergPool_Request.$ZergPool_Algorithm.mbtc_mh_factor
    if ($Divisor -eq 0) {
        Write-Log -Level Info "Unable to determine divisor for $ZergPool_Coin using $ZergPool_Algorithm_Norm algorithm"
        return
    }

    if (-not $InfoOnly) {
        $Stat = Set-Stat -Name "$($Name)_$($_)_Profit" -Value ([Double]$ZergPoolCoins_Request.$_.estimate / $Divisor) -Duration $StatSpan -ChangeDetection $true
    }

    $ZergPool_Regions | ForEach-Object {
        $ZergPool_Region = $_
        $ZergPool_Region_Norm = Get-Region $ZergPool_Region

        if ((Get-Variable $ZergPool_Currency -ValueOnly -ErrorAction SilentlyContinue) -or $InfoOnly) {
            $ZergPool_Currency | ForEach-Object {
                #Option 2
                [PSCustomObject]@{
                    Algorithm     = $ZergPool_Algorithm_Norm
                    CoinName      = $ZergPool_Coin
                    Price         = $Stat.Hour #instead of .Live
                    StablePrice   = $Stat.Week
                    MarginOfError = $Stat.Week_Fluctuation
                    Protocol      = "stratum+tcp"
                    Host          = if ($ZergPool_Region -eq "us") {$ZergPool_Host} else {"$ZergPool_Region.$ZergPool_Host"}
                    Port          = $ZergPool_Port
                    User          = Get-Variable $_ -ValueOnly -ErrorAction SilentlyContinue
                    Pass          = "$Worker, c=$_, mc=$ZergPool_Currency"
                    Region        = $ZergPool_Region_Norm
                    SSL           = $false
                    Updated       = $Stat.Updated
                    PoolFee       = $ZergPool_PoolFee
                }
            }
        }
        if ($ZergPoolCoins_Request.$ZergPool_Currency.noautotrade -eq 0 -and (-not (Get-Variable $ZergPool_Currency -ValueOnly -ErrorAction SilentlyContinue) -or $InfoOnly)) {
            $ZergPool_Currencies | ForEach-Object {
                #Option 3
                [PSCustomObject]@{
                    Algorithm     = $ZergPool_Algorithm_Norm
                    CoinName      = $ZergPool_Coin
                    Price         = $Stat.Hour #instead of .Live
                    StablePrice   = $Stat.Week
                    MarginOfError = $Stat.Week_Fluctuation
                    Protocol      = "stratum+tcp"
                    Host          = if ($ZergPool_Region -eq "us") {$ZergPool_Host}else {"$ZergPool_Region.$ZergPool_Host"}
                    Port          = $ZergPool_Port
                    User          = Get-Variable $_ -ValueOnly -ErrorAction SilentlyContinue
                    Pass          = "$Worker,c=$_,mc=$ZergPool_Currency"
                    Region        = $ZergPool_Region_Norm
                    SSL           = $false
                    Updated       = $Stat.Updated
                    PoolFee       = $ZergPool_PoolFee
                }
            }
        }
    }
}
