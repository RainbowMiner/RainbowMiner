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

$HashRefinery_Request = [PSCustomObject]@{}

try {
    $HashRefinery_Request = Invoke-RestMethodAsync "http://pool.hashrefinery.com/api/status"
    $HashRefineryCoins_Request = Invoke-RestMethodAsync "http://pool.hashrefinery.com/api/currencies"
}
catch {
    Write-Log -Level Warn "Pool API ($Name) has failed. "
    return
}

if (($HashRefinery_Request | Get-Member -MemberType NoteProperty -ErrorAction Ignore | Measure-Object Name).Count -le 1) {
    Write-Log -Level Warn "Pool API ($Name) returned nothing. "
    return
}

$HashRefinery_Regions = "us"
$HashRefinery_Currencies = @("BTC") + ($HashRefineryCoins_Request | Get-Member -MemberType NoteProperty -ErrorAction Ignore | Select-Object -ExpandProperty Name) | Select-Object -Unique | Where-Object {Get-Variable $_ -ValueOnly -ErrorAction SilentlyContinue}

$HashRefinery_Coins = @($HashRefineryCoins_Request.PSObject.Properties.Value | Group-Object algo | Where-Object Count -eq 1 | Foreach-Object {[PSCustomObject]@{Name=$_.Group.name;Algorithm=$_.Group.algo}})

$HashRefinery_Request | Get-Member -MemberType NoteProperty -ErrorAction Ignore | Select-Object -ExpandProperty Name | Where-Object {$Hashrefinery_Request.$_.hashrate -gt 0} | ForEach-Object {
    $HashRefinery_Host = "hashrefinery.com"
    $HashRefinery_Port = $HashRefinery_Request.$_.port
    $HashRefinery_Algorithm = $HashRefinery_Request.$_.name
    $HashRefinery_Algorithm_Norm = Get-Algorithm $HashRefinery_Algorithm
    $HashRefinery_Coin = Get-CoinName ($HashRefinery_Coins | Where-Object Algorithm -eq $HashRefinery_Algorithm).Name
    $HashRefinery_PoolFee = [Double]$HashRefinery_Request.$_.fees

    $Divisor = 1000000 * [Double]$HashRefinery_Request.$HashRefinery_Algorithm.mbtc_mh_factor

    if ((Get-Stat -Name "$($Name)_$($HashRefinery_Algorithm_Norm)_Profit") -eq $null) {$Stat = Set-Stat -Name "$($Name)_$($HashRefinery_Algorithm_Norm)_Profit" -Value ([Double]$HashRefinery_Request.$_.estimate_last24h / $Divisor) -Duration (New-TimeSpan -Days 1)}
    else {$Stat = Set-Stat -Name "$($Name)_$($HashRefinery_Algorithm_Norm)_Profit" -Value ((Get-YiiMPValue $HashRefinery_Request.$_ $DataWindow) / $Divisor) -Duration $StatSpan -ChangeDetection $true}

    $HashRefinery_Regions | ForEach-Object {
        $HashRefinery_Region = $_
        $HashRefinery_Region_Norm = Get-Region $HashRefinery_Region

        $HashRefinery_Currencies | ForEach-Object {
            [PSCustomObject]@{
                Algorithm     = $HashRefinery_Algorithm_Norm
                CoinName      = $HashRefinery_Coin
                Price         = $Stat.Hour #instead of .Live
                StablePrice   = $Stat.Week
                MarginOfError = $Stat.Week_Fluctuation
                Protocol      = "stratum+tcp"
                Host          = "$HashRefinery_Algorithm.$HashRefinery_Region.$HashRefinery_Host"
                Port          = $HashRefinery_Port
                User          = Get-Variable $_ -ValueOnly
                Pass          = "$Worker,c=$_"
                Region        = $HashRefinery_Region_Norm
                SSL           = $false
                Updated       = $Stat.Updated
                PoolFee       = $HashRefinery_PoolFee
            }
        }
    }
}
