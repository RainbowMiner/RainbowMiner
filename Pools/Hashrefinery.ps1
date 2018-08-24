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

$Pool_Request = [PSCustomObject]@{}
$PoolCoins_Request = [PSCustomObject]@{}

try {
    $Pool_Request = Invoke-RestMethodAsync "http://pool.hashrefinery.com/api/status"
    $PoolCoins_Request = Invoke-RestMethodAsync "http://pool.hashrefinery.com/api/currencies"
}
catch {
    Write-Log -Level Warn "Pool API ($Name) has failed. "
    return
}

if (($Pool_Request | Get-Member -MemberType NoteProperty -ErrorAction Ignore | Measure-Object Name).Count -le 1) {
    Write-Log -Level Warn "Pool API ($Name) returned nothing. "
    return
}

[hashtable]$Pool_Algorithms = @{}
[hashtable]$Pool_Coins = @{}
[hashtable]$Pool_RegionsTable = @{}

$Pool_Regions = @("us")
$Pool_Regions | Foreach-Object {$Pool_RegionsTable.$_ = Get-Region $_}
$Pool_Currencies = @("BTC") + @($PoolCoins_Request | Get-Member -MemberType NoteProperty -ErrorAction Ignore | Select-Object -ExpandProperty Name) | Select-Object -Unique | Where-Object {(Get-Variable $_ -ValueOnly -ErrorAction SilentlyContinue) -or $InfoOnly}
if ($PoolCoins_Request) {
    $PoolCoins_Request.PSObject.Properties.Value | Group-Object algo | Where-Object Count -eq 1 | Foreach-Object {$Pool_Coins[$_.Group.algo] = @{Name=(Get-CoinName $_.Group.name);Symbol=$_.Group.symbol}}
}

$Pool_Request | Get-Member -MemberType NoteProperty -ErrorAction Ignore | Select-Object -ExpandProperty Name | Where-Object {$Pool_Request.$_.hashrate -gt 0} | ForEach-Object {
    $Pool_Host = "hashrefinery.com"
    $Pool_Port = $Pool_Request.$_.port
    $Pool_Algorithm = $Pool_Request.$_.name
    if (-not $Pool_Algorithms.ContainsKey($Pool_Algorithm)) {$Pool_Algorithms.$Pool_Algorithm = Get-Algorithm $Pool_Algorithm}
    $Pool_Algorithm_Norm = $Pool_Algorithms.$Pool_Algorithm
    $Pool_Coin = $Pool_Coins.$Pool_Algorithm.Name
    $Pool_Symbol = $Pool_Coins.$Pool_Algorithm.Symbol
    $Pool_PoolFee = [Double]$Pool_Request.$_.fees
    if ($Pool_Coin -and -not $Pool_Symbol) {$Pool_Symbol = Get-CoinSymbol $Pool_Coin}

    $Divisor = 1e6 * [Double]$Pool_Request.$Pool_Algorithm.mbtc_mh_factor

    if (-not $InfoOnly) {
        if (-not (Test-Path "Stats\$($Name)_$($Pool_Algorithm_Norm)_Profit.txt")) {$Stat = Set-Stat -Name "$($Name)_$($Pool_Algorithm_Norm)_Profit" -Value ([Double]$Pool_Request.$_.estimate_last24h / $Divisor) -Duration (New-TimeSpan -Days 1)}
        else {$Stat = Set-Stat -Name "$($Name)_$($Pool_Algorithm_Norm)_Profit" -Value ((Get-YiiMPValue $Pool_Request.$_ $DataWindow) / $Divisor) -Duration $StatSpan -ChangeDetection $true}
    }

    foreach($Pool_Region in $Pool_Regions) {
        foreach($Pool_Currency in $Pool_Currencies) {
            [PSCustomObject]@{
                Algorithm     = $Pool_Algorithm_Norm
                CoinName      = $Pool_Coin
                CoinSymbol    = $Pool_Symbol
                Currency      = $Pool_Currency
                Price         = $Stat.Hour #instead of .Live
                StablePrice   = $Stat.Week
                MarginOfError = $Stat.Week_Fluctuation
                Protocol      = "stratum+tcp"
                Host          = "$Pool_Algorithm.$Pool_Region.$Pool_Host"
                Port          = $Pool_Port
                User          = Get-Variable $Pool_Currency -ValueOnly -ErrorAction SilentlyContinue
                Pass          = "$Worker,c=$Pool_Currency"
                Region        = $Pool_RegionsTable.$Pool_Region
                SSL           = $false
                Updated       = $Stat.Updated
                PoolFee       = $Pool_PoolFee
                DataWindow    = $DataWindow
            }
        }
    }
}
