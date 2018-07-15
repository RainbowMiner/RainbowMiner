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

$BlockMasters_Request = [PSCustomObject]@{}
$BlockMastersCoins_Request = [PSCustomObject]@{}

try {
    $BlockMasters_Request = Invoke-RestMethodAsync "http://blockmasters.co/api/status"
    $BlockMastersCoins_Request = Invoke-RestMethodAsync "http://blockmasters.co/api/currencies"
}
catch {
    Write-Log -Level Warn "Pool API ($Name) has failed. "
    return
}

if (($BlockMasters_Request | Get-Member -MemberType NoteProperty -ErrorAction Ignore | Measure-Object Name).Count -le 1) {
    Write-Log -Level Warn "Pool API ($Name) returned nothing. "
    return
}

$BlockMasters_Regions = "us"
$BlockMasters_Currencies = @("BTC") + ($BlockMastersCoins_Request | Get-Member -MemberType NoteProperty -ErrorAction Ignore | Select-Object -ExpandProperty Name) | Select-Object -Unique | Where-Object {Get-Variable $_ -ValueOnly -ErrorAction SilentlyContinue}

$BlockMasters_Coins = @($BlockMastersCoins_Request.PSObject.Properties.Value | Group-Object algo | Where-Object Count -eq 1 | Foreach-Object {[PSCustomObject]@{Name=$_.Group.name;Algorithm=$_.Group.algo}})

$BlockMasters_Request | Get-Member -MemberType NoteProperty -ErrorAction Ignore | Select-Object -ExpandProperty Name | Where-Object {$BlockMasters_Request.$_.hashrate -gt 0} | ForEach-Object {
    $BlockMasters_Host = "blockmasters.co"
    $BlockMasters_Port = $BlockMasters_Request.$_.port
    $BlockMasters_Algorithm = $BlockMasters_Request.$_.name
    $BlockMasters_Algorithm_Norm = Get-Algorithm $BlockMasters_Algorithm
    $BlockMasters_Coin = Get-CoinName ($BlockMasters_Coins | Where-Object Algorithm -eq $BlockMasters_Algorithm).Name
    $BlockMasters_PoolFee = [double]$BlockMasters_Request.$_.fees

    $Divisor = 1000000 * [Double]$BlockMasters_Request.$_.mbtc_mh_factor

    if ((Get-Stat -Name "$($Name)_$($BlockMasters_Algorithm_Norm)_Profit") -eq $null) {$Stat = Set-Stat -Name "$($Name)_$($BlockMasters_Algorithm_Norm)_Profit" -Value ([Double]$BlockMasters_Request.$_.estimate_last24h / $Divisor) -Duration (New-TimeSpan -Days 1)}
    else {$Stat = Set-Stat -Name "$($Name)_$($BlockMasters_Algorithm_Norm)_Profit" -Value ((Get-YiiMPValue $BlockMasters_Request.$_ $DataWindow) / $Divisor) -Duration $StatSpan -ChangeDetection $true}

    $BlockMasters_Regions | ForEach-Object {
        $BlockMasters_Region = $_
        $BlockMasters_Region_Norm = Get-Region $BlockMasters_Region

        $BlockMasters_Currencies | ForEach-Object {
            [PSCustomObject]@{
                Algorithm     = $BlockMasters_Algorithm_Norm
                CoinName      = $BlockMasters_Coin
                Price         = $Stat.Hour #instead of .Live
                StablePrice   = $Stat.Week
                MarginOfError = $Stat.Week_Fluctuation
                Protocol      = "stratum+tcp"
                Host          = $BlockMasters_Host
                Port          = $BlockMasters_Port
                User          = Get-Variable $_ -ValueOnly
                Pass          = "$Worker,c=$_"
                Region        = $BlockMasters_Region_Norm
                SSL           = $false
                Updated       = $Stat.Updated
                PoolFee       = $BlockMasters_PoolFee
            }
        }
    }
}

