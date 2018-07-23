using module ..\Include.psm1

param(
    [alias("Wallet")]
    [String]$BTC, 
    [alias("WorkerName")]
    [String]$Worker, 
    [TimeSpan]$StatSpan,
    [String]$DataWindow = "estimate_current"
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
$ZergPool_Currencies = @("BTC", "LTC") | Select-Object -Unique | Where-Object {Get-Variable $_ -ValueOnly -ErrorAction SilentlyContinue}

$ZergPool_Coins = [PSCustomObject]@{}
$ZergPoolCoins_Request.PSObject.Properties.Value | Group-Object algo | Where-Object Count -eq 1 | Foreach-Object {$ZergPool_Coins | Add-Member $_.Group.algo (Get-CoinName $_.Group.name)}

$ZergPool_PoolFee = 0.5

$ZergPool_Request | Get-Member -MemberType NoteProperty -ErrorAction Ignore | Select-Object -ExpandProperty Name | Where-Object {$ZergPool_Request.$_.hashrate -gt 0 -and [Double]$ZergPool_Request.$_.estimate_current  -gt 0} |ForEach-Object {
    $ZergPool_Port = $ZergPool_Request.$_.port
    $ZergPool_Algorithm = $ZergPool_Request.$_.name
    $ZergPool_Algorithm_Norm = Get-Algorithm $ZergPool_Algorithm
    $ZergPool_Coin = $ZergPool_Coins.$ZergPool_Algorithm
    $ZergPool_Host = "$($ZergPool_Algorithm).mine.zergpool.com"
    $ZergPool_PoolFee = [Double]$ZergPool_Request.$_.fees

    $Divisor = 1000000 * [Double]$ZergPool_Request.$_.mbtc_mh_factor

    if (-not (Test-Path "Stats\$($Name)_$($ZergPool_Algorithm_Norm)_Profit.txt")) {$Stat = Set-Stat -Name "$($Name)_$($ZergPool_Algorithm_Norm)_Profit" -Value ([Double]$ZergPool_Request.$_.estimate_last24h / $Divisor) -Duration (New-TimeSpan -Days 1)}
    else {$Stat = Set-Stat -Name "$($Name)_$($ZergPool_Algorithm_Norm)_Profit" -Value ((Get-YiiMPValue $ZergPool_Request.$_ $DataWindow) / $Divisor) -Duration $StatSpan -ChangeDetection $true}

    $ZergPool_Regions | ForEach-Object {
        $ZergPool_Region = $_
        $ZergPool_Region_Norm = Get-Region $ZergPool_Region
        $ZergPool_Currencies | ForEach-Object {
            #Option 1
            [PSCustomObject]@{
                Algorithm     = $ZergPool_Algorithm_Norm
                CoinName      = $ZergPool_Coin
                Price         = $Stat.Hour #instead of .Live
                StablePrice   = $Stat.Week
                MarginOfError = $Stat.Week_Fluctuation
                Protocol      = "stratum+tcp"
                Host          = if ($ZergPool_Region -eq "us") {$ZergPool_Host}else {"$ZergPool_Region.$ZergPool_Host"}
                Port          = $ZergPool_Port
                User          = Get-Variable $_ -ValueOnly
                Pass          = "$Worker,c=$_"
                Region        = $ZergPool_Region_Norm
                SSL           = $false
                Updated       = $Stat.Updated
                PoolFee       = $ZergPool_PoolFee
            }
        }
    }
}
