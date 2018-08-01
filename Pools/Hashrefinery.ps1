using module ..\Include.psm1

param(
    [alias("Wallet")]
    [String]$BTC, 
    [alias("WorkerName")]
    [String]$Worker, 
    [TimeSpan]$StatSpan,
    [String]$DataWindow = "estimate_current",
    [Bool]$InfoOnly = $false
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
$HashRefinery_Currencies = @("BTC") + ($HashRefineryCoins_Request | Get-Member -MemberType NoteProperty -ErrorAction Ignore | Select-Object -ExpandProperty Name) | Select-Object -Unique | Where-Object {(Get-Variable $_ -ValueOnly -ErrorAction SilentlyContinue) -or $InfoOnly}

$HashRefinery_Coins = [PSCustomObject]@{}
$HashRefineryCoins_Request.PSObject.Properties.Value | Group-Object algo | Where-Object Count -eq 1 | Foreach-Object {$HashRefinery_Coins | Add-Member $_.Group.algo (Get-CoinName $_.Group.name)}

$HashRefinery_Request | Get-Member -MemberType NoteProperty -ErrorAction Ignore | Select-Object -ExpandProperty Name | Where-Object {$Hashrefinery_Request.$_.hashrate -gt 0} | ForEach-Object {
    $HashRefinery_Host = "hashrefinery.com"
    $HashRefinery_Port = $HashRefinery_Request.$_.port
    $HashRefinery_Algorithm = $HashRefinery_Request.$_.name
    $HashRefinery_Algorithm_Norm = Get-Algorithm $HashRefinery_Algorithm
    $HashRefinery_Coin = $HashRefinery_Coins.$HashRefinery_Algorithm
    $HashRefinery_PoolFee = [Double]$HashRefinery_Request.$_.fees

    $Divisor = 1000000 * [Double]$HashRefinery_Request.$HashRefinery_Algorithm.mbtc_mh_factor

    if (-not $InfoOnly) {
        if (-not (Test-Path "Stats\$($Name)_$($HashRefinery_Algorithm_Norm)_Profit.txt")) {$Stat = Set-Stat -Name "$($Name)_$($HashRefinery_Algorithm_Norm)_Profit" -Value ([Double]$HashRefinery_Request.$_.estimate_last24h / $Divisor) -Duration (New-TimeSpan -Days 1)}
        else {$Stat = Set-Stat -Name "$($Name)_$($HashRefinery_Algorithm_Norm)_Profit" -Value ((Get-YiiMPValue $HashRefinery_Request.$_ $DataWindow) / $Divisor) -Duration $StatSpan -ChangeDetection $true}
    }

    $HashRefinery_Regions | ForEach-Object {
        $HashRefinery_Region = $_
        $HashRefinery_Region_Norm = Get-Region $HashRefinery_Region

        $HashRefinery_Currencies | ForEach-Object {
            [PSCustomObject]@{
                Algorithm     = $HashRefinery_Algorithm_Norm
                CoinName      = $HashRefinery_Coin
                Currency      = $_
                Price         = $Stat.Hour #instead of .Live
                StablePrice   = $Stat.Week
                MarginOfError = $Stat.Week_Fluctuation
                Protocol      = "stratum+tcp"
                Host          = "$HashRefinery_Algorithm.$HashRefinery_Region.$HashRefinery_Host"
                Port          = $HashRefinery_Port
                User          = Get-Variable $_ -ValueOnly -ErrorAction SilentlyContinue
                Pass          = "$Worker,c=$_"
                Region        = $HashRefinery_Region_Norm
                SSL           = $false
                Updated       = $Stat.Updated
                PoolFee       = $HashRefinery_PoolFee
            }
        }
    }
}
