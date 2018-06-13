using module ..\Include.psm1

param(
    [alias("WorkerName")]
    [String]$Worker, 
    [TimeSpan]$StatSpan
)

$Name = Get-Item $MyInvocation.MyCommand.Path | Select-Object -ExpandProperty BaseName

$BlockcruncherCoins_Request = [PSCustomObject]@{}

try {
    $Blockcruncher_Request = Invoke-RestMethod "https://blockcruncher.com/api/status" -UseBasicParsing -TimeoutSec 10 -ErrorAction Stop
    $BlockcruncherCoins_Request = Invoke-RestMethod "https://blockcruncher.com/api/currencies" -UseBasicParsing -TimeoutSec 10 -ErrorAction Stop
}
catch {
    Write-Log -Level Warn "Pool API ($Name) has failed. "
    return
}

if (($BlockcruncherCoins_Request | Get-Member -MemberType NoteProperty -ErrorAction Ignore | Measure-Object Name).Count -le 1) {
    Write-Log -Level Warn "Pool API ($Name) returned nothing. "
    return
}

$Blockcruncher_Regions = "us"
$Blockcruncher_Currencies = ($BlockcruncherCoins_Request | Get-Member -MemberType NoteProperty -ErrorAction Ignore | Select-Object -ExpandProperty Name) | Select-Object -Unique | Where-Object {Get-Variable $_ -ValueOnly -ErrorAction SilentlyContinue}

$Blockcruncher_Currencies | Where-Object {$BlockcruncherCoins_Request.$_.hashrate -gt 0} | ForEach-Object {
    $Blockcruncher_Host = "blockcruncher.com"
    $Blockcruncher_Port = $BlockcruncherCoins_Request.$_.port
    $Blockcruncher_Algorithm = $BlockcruncherCoins_Request.$_.algo
    $Blockcruncher_Algorithm_Norm = Get-Algorithm $Blockcruncher_Algorithm
    $Blockcruncher_Coin = $BlockcruncherCoins_Request.$_.name
    $Blockcruncher_Currency = $_
    $Blockcruncher_PoolFee = [Double]$Blockcruncher_Request.$Blockcruncher_Algorithm.fees

    #$Divisor = 1000000000 * [Double]$Blockcruncher_Request.$Blockcruncher_Algorithm.mbtc_mh_factor

    $Divisor = 1000000000

    switch ($Blockcruncher_Algorithm_Norm) {
        "x16r" {$Divisor *= 1}
    }

    $Stat = Set-Stat -Name "$($Name)_$($_)_Profit" -Value ([Double]$Blockcruncher_Request.$Blockcruncher_Algorithm.actual_last24h / $Divisor) -Duration $StatSpan -ChangeDetection $false

    $Blockcruncher_Regions | ForEach-Object {
        $Blockcruncher_Region = $_
        $Blockcruncher_Region_Norm = Get-Region $Blockcruncher_Region

        [PSCustomObject]@{
            Algorithm     = $Blockcruncher_Algorithm_Norm
            Info          = $Blockcruncher_Coin
            Price         = $Stat.Live
            StablePrice   = $Stat.Week
            MarginOfError = $Stat.Week_Fluctuation
            Protocol      = "stratum+tcp"
            Host          = $Blockcruncher_Host
            Port          = $Blockcruncher_Port
            User          = Get-Variable $Blockcruncher_Currency -ValueOnly
            Pass          = "$Worker,c=$Blockcruncher_Currency"
            Region        = $Blockcruncher_Region_Norm
            SSL           = $false
            Updated       = $Stat.Updated
            PoolFee       = $Blockcruncher_PoolFee
        }
    }
}
