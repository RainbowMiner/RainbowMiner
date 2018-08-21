using module ..\Include.psm1

param(
    [alias("WorkerName")]
    [String]$Worker, 
    [TimeSpan]$StatSpan,
    [Bool]$InfoOnly = $false
)

$Name = Get-Item $MyInvocation.MyCommand.Path | Select-Object -ExpandProperty BaseName

$Pool_Request = [PSCustomObject]@{}
$PoolCoins_Request = [PSCustomObject]@{}

try {
    $Pool_Request = Invoke-RestMethodAsync "http://api.yiimp.eu/api/status"
    $PoolCoins_Request = Invoke-RestMethodAsync "http://api.yiimp.eu/api/currencies"
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

$Pool_Regions = "us"
$Pool_Currencies = ($PoolCoins_Request | Get-Member -MemberType NoteProperty -ErrorAction Ignore | Select-Object -ExpandProperty Name) | Select-Object -Unique | Where-Object {(Get-Variable $_ -ValueOnly -ErrorAction SilentlyContinue) -or $InfoOnly}
$Pool_PoolFee = 2.0

$Pool_Currencies | Where-Object {$PoolCoins_Request.$_.hashrate -gt 0 -or $InfoOnly} | ForEach-Object {
    $Pool_Host = "yiimp.eu"
    $Pool_Port = $PoolCoins_Request.$_.port
    $Pool_Algorithm = $PoolCoins_Request.$_.algo
    if (-not $Pool_Algorithms.ContainsKey($Pool_Algorithm)) {$Pool_Algorithms[$Pool_Algorithm] = Get-Algorithm $Pool_Algorithm}
    $Pool_Algorithm_Norm = $Pool_Algorithms[$Pool_Algorithm]
    $Pool_Coin = Get-CoinName $PoolCoins_Request.$_.name
    $Pool_Currency = $_
    $Pool_PoolFee = [Double]$Pool_Request.$Pool_Algorithm.fees

    $Divisor = 1000000000 * [Double]$Pool_Request.$Pool_Algorithm.mbtc_mh_factor

    if (-not $InfoOnly) {
        $Stat = Set-Stat -Name "$($Name)_$($_)_Profit" -Value ([Double]$PoolCoins_Request.$_.estimate / $Divisor) -Duration $StatSpan -ChangeDetection $true
    }

    $Pool_Regions | ForEach-Object {
        $Pool_Region = $_
        $Pool_Region_Norm = Get-Region $Pool_Region

        [PSCustomObject]@{
            Algorithm     = $Pool_Algorithm_Norm
            CoinName      = $Pool_Coin
            CoinSymbol    = $Pool_Currency
            Currency      = $Pool_Currency
            Price         = $Stat.Hour #instead of .Live
            StablePrice   = $Stat.Week
            MarginOfError = $Stat.Week_Fluctuation
            Protocol      = "stratum+tcp"
            Host          = $Pool_Host
            Port          = $Pool_Port
            User          = Get-Variable $Pool_Currency -ValueOnly -ErrorAction SilentlyContinue
            Pass          = "$Worker,c=$Pool_Currency"
            Region        = $Pool_Region_Norm
            SSL           = $false
            Updated       = $Stat.Updated
            PoolFee       = $Pool_PoolFee
        }
    }
}
