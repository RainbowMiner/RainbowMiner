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

$Zpool_Request = [PSCustomObject]@{}
$ZpoolCoins_Request = [PSCustomObject]@{}

try {
    $Zpool_Request = Invoke-RestMethodAsync "http://www.zpool.ca/api/status"
    $ZpoolCoins_Request = Invoke-RestMethodAsync "http://www.zpool.ca/api/currencies"
}
catch {
    Write-Log -Level Warn "Pool API ($Name) has failed. "
    return
}

if (($Zpool_Request | Get-Member -MemberType NoteProperty -ErrorAction Ignore | Measure-Object Name).Count -le 1) {
    Write-Log -Level Warn "Pool API ($Name) returned nothing. "
    return
}

$Zpool_Regions = "us"
$Zpool_Currencies = @("BTC") + @($ZpoolCoins_Request | Get-Member -MemberType NoteProperty -ErrorAction Ignore | Select-Object -ExpandProperty Name) | Select-Object -Unique | Where-Object {(Get-Variable $_ -ValueOnly -ErrorAction SilentlyContinue) -or $InfoOnly}

$ZPool_Coins = [PSCustomObject]@{}
$ZPoolCoins_Request.PSObject.Properties.Value | Group-Object algo | Where-Object Count -eq 1 | Foreach-Object {$ZPool_Coins | Add-Member $_.Group.algo (Get-CoinName $_.Group.name)}

$Zpool_Request | Get-Member -MemberType NoteProperty -ErrorAction Ignore | Select-Object -ExpandProperty Name | Where-Object {$Zpool_Request.$_.hashrate -gt 0} |ForEach-Object {
    $Zpool_Host = "mine.zpool.ca"
    $Zpool_Port = $Zpool_Request.$_.port
    $Zpool_Algorithm = $Zpool_Request.$_.name
    $Zpool_Algorithm_Norm = Get-Algorithm $Zpool_Algorithm
    $ZPool_Coin = $ZPool_Coins.$ZPool_Algorithm
    $Zpool_PoolFee = [Double]$Zpool_Request.$_.fees

    $Divisor = 1000000 * [Double]$Zpool_Request.$_.mbtc_mh_factor
    
    if (-not $InfoOnly) {
        if (-not (Test-Path "Stats\$($Name)_$($ZPool_Algorithm_Norm)_Profit.txt")) {$Stat = Set-Stat -Name "$($Name)_$($Zpool_Algorithm_Norm)_Profit" -Value ([Double]$Zpool_Request.$_.estimate_last24h / $Divisor) -Duration (New-TimeSpan -Days 1)}
        else {$Stat = Set-Stat -Name "$($Name)_$($Zpool_Algorithm_Norm)_Profit" -Value ((Get-YiiMPValue $ZPool_Request.$_ $DataWindow) / $Divisor) -Duration $StatSpan -ChangeDetection $true}
    }

    $Zpool_Regions | ForEach-Object {
        $Zpool_Region = $_
        $Zpool_Region_Norm = Get-Region $Zpool_Region
        $Zpool_Currencies | ForEach-Object {
            [PSCustomObject]@{
                Algorithm     = $Zpool_Algorithm_Norm
                CoinName      = $Zpool_Coin
                Currency      = $_
                Price         = $Stat.Hour #instead of .Live
                StablePrice   = $Stat.Week
                MarginOfError = $Stat.Week_Fluctuation
                Protocol      = "stratum+tcp"
                Host          = "$Zpool_Algorithm.$Zpool_Host"
                Port          = $Zpool_Port
                User          = Get-Variable $_ -ValueOnly -ErrorAction SilentlyContinue
                Pass          = "$Worker,c=$_"
                Region        = $Zpool_Region_Norm
                SSL           = $false
                Updated       = $Stat.Updated
                PoolFee       = $Zpool_PoolFee
            }
        }
    }
}
