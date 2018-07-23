using module ..\Include.psm1

param(
    [alias("WorkerName")]
    [String]$Worker, 
    [TimeSpan]$StatSpan
)

$Name = Get-Item $MyInvocation.MyCommand.Path | Select-Object -ExpandProperty BaseName

$Bsod_Request = [PSCustomObject]@{}
$BsodCoins_Request = [PSCustomObject]@{}

try {
    $Bsod_Request = Invoke-RestMethodAsync "http://api.bsod.pw/api/status"
    $BsodCoins_Request = Invoke-RestMethodAsync "http://api.bsod.pw/api/currencies"
}
catch {
    Write-Log -Level Warn "Pool API ($Name) has failed. "
    return
}

if (($BsodCoins_Request | Get-Member -MemberType NoteProperty -ErrorAction Ignore | Measure-Object Name).Count -le 1) {
    Write-Log -Level Warn "Pool API ($Name) returned nothing. "
    return
}

$Bsod_Regions = "eu","us","asia"
$Bsod_Currencies = ($BsodCoins_Request | Get-Member -MemberType NoteProperty -ErrorAction Ignore | Select-Object -ExpandProperty Name) | Select-Object -Unique | Where-Object {Get-Variable $_ -ValueOnly -ErrorAction SilentlyContinue}

$Bsod_Currencies | Where-Object {$BsodCoins_Request.$_.hashrate -gt 0 -and [Double]$BsodCoins_Request.$_.estimate -gt 0} | ForEach-Object {
    $Bsod_Host = "bsod.pw"
    $Bsod_Port = $BsodCoins_Request.$_.port
    $Bsod_Algorithm = $BsodCoins_Request.$_.algo
    $Bsod_Algorithm_Norm = Get-Algorithm $Bsod_Algorithm
    $Bsod_Coin = Get-CoinName $BsodCoins_Request.$_.name
    $Bsod_Currency = $_
    $Bsod_PoolFee = if($Bsod_Request."$($Bsod_Algorithm)_$($_.tolower())"){$Bsod_Request."$($Bsod_Algorithm)_$($_.tolower())".fees}else{[Double]$Bsod_Request.$Bsod_Algorithm.fees}

    #$Divisor = 1000000000 * [Double]$Bsod_Request.$Bsod_Algorithm.mbtc_mh_factor
    $Divisor = 1000000000

    switch ($Bsod_Algorithm) {
        "blake2s" {$Divisor *= 1000}
        "sha256d" {$Divisor *= 1000}
    }

    $Stat = Set-Stat -Name "$($Name)_$($_)_Profit" -Value ([Double]$BsodCoins_Request.$_.estimate / $Divisor) -Duration $StatSpan -ChangeDetection $true

    $Bsod_Regions | ForEach-Object {
        $Bsod_Region = $_
        $Bsod_Region_Norm = Get-Region $Bsod_Region

        [PSCustomObject]@{
            Algorithm     = $Bsod_Algorithm_Norm
            CoinName      = $Bsod_Coin
            Price         = $Stat.Hour #instead of .Live
            StablePrice   = $Stat.Week
            MarginOfError = $Stat.Week_Fluctuation
            Protocol      = "stratum+tcp"
            Host          = "$($Bsod_Region).bsod.pw"
            Port          = $Bsod_Port
            User          = "$(Get-Variable $Bsod_Currency -ValueOnly).$($Worker)"
            Pass          = "c=$Bsod_Currency"
            Region        = $Bsod_Region_Norm
            SSL           = $false
            Updated       = $Stat.Updated
            PoolFee       = $Bsod_PoolFee
        }
    }
}
