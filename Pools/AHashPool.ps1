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

$AHashPool_Request = [PSCustomObject]@{}
$AHashPoolCoins_Request = [PSCustomObject]@{}

try {
    $AHashPool_Request = Invoke-RestMethodAsync "http://www.ahashpool.com/api/status"
    $AHashPoolCoins_Request = Invoke-RestMethodAsync "http://www.ahashpool.com/api/currencies"
}
catch {
    Write-Log -Level Warn "Pool API ($Name) has failed. "
    return
}

if (($AHashPool_Request | Get-Member -MemberType NoteProperty -ErrorAction Ignore | Measure-Object Name).Count -le 1) {
    Write-Log -Level Warn "Pool API ($Name) returned nothing. "
    return
}

$AHashPool_Regions = "us"
$AHashPool_Currencies = @("BTC") | Select-Object -Unique | Where-Object {Get-Variable $_ -ValueOnly -ErrorAction SilentlyContinue}

$AHashPool_Coins = [PSCustomObject]@{}
$AHashPoolCoins_Request.PSObject.Properties.Value | Group-Object algo | Where-Object Count -eq 1 | Foreach-Object {$AHashPool_Coins | Add-Member $_.Group.algo (Get-CoinName $_.Group.name)}

$AHashPool_Request | Get-Member -MemberType NoteProperty -ErrorAction Ignore | Select-Object -ExpandProperty Name | Where-Object {$AHashPool_Request.$_.hashrate -gt 0} | ForEach-Object {
    $AHashPool_Host = "mine.ahashpool.com"
    $AHashPool_Port = $AHashPool_Request.$_.port
    $AHashPool_Algorithm = $AHashPool_Request.$_.name
    $AHashPool_Algorithm_Norm = Get-Algorithm $AHashPool_Algorithm
    $AHashPool_Coin = $AHashPool_Coins.$AHashPool_Algorithm
    $AHashPool_PoolFee = [Double]$AHashPool_Request.$_.fees

    $Divisor = 1000000 * [Double]$AHashPool_Request.$_.mbtc_mh_factor

    if (-not (Test-Path "Stats\$($Name)_$($AHashPool_Algorithm_Norm)_Profit.txt")) {$Stat = Set-Stat -Name "$($Name)_$($AHashPool_Algorithm_Norm)_Profit" -Value ([Double]$AHashPool_Request.$_.estimate_last24h / $Divisor) -Duration (New-TimeSpan -Days 1)}
    else {$Stat = Set-Stat -Name "$($Name)_$($AHashPool_Algorithm_Norm)_Profit" -Value ((Get-YiiMPValue $AHashPool_Request.$_ $DataWindow) / $Divisor) -Duration $StatSpan -ChangeDetection $true}

    $AHashPool_Regions | ForEach-Object {
        $AHashPool_Region = $_
        $AHashPool_Region_Norm = Get-Region $AHashPool_Region

        $AHashPool_Currencies | ForEach-Object {
            [PSCustomObject]@{
                Algorithm     = $AHashPool_Algorithm_Norm
                CoinName      = $AHashPool_Coin
                Price         = $Stat.Hour #instead of .Live
                StablePrice   = $Stat.Week
                MarginOfError = $Stat.Week_Fluctuation
                Protocol      = "stratum+tcp"
                Host          = "$AHashPool_Algorithm.$AHashPool_Host"
                Port          = $AHashPool_Port
                User          = Get-Variable $_ -ValueOnly
                Pass          = "$Worker,c=$_"
                Region        = $AHashPool_Region_Norm
                SSL           = $false
                Updated       = $Stat.Updated
                PoolFee       = $AHashPool_PoolFee
            }
        }
    }
}
