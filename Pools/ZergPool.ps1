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
    $Pool_Request = Invoke-RestMethodAsync "http://api.zergpool.com:8080/api/status" -retry 5 -retrywait 500
    $PoolCoins_Request = Invoke-RestMethodAsync "http://api.zergpool.com:8080/api/currencies" -retry 5 -retrywait 750
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

$Pool_Regions = "us"#, "europe"
$Pool_Currencies = @("BTC", "DASH", "LTC") | Select-Object -Unique | Where-Object {(Get-Variable $_ -ValueOnly -ErrorAction SilentlyContinue) -or $InfoOnly}
$PoolCoins_Request.PSObject.Properties.Value | Group-Object algo | Where-Object Count -eq 1 | Foreach-Object {$Pool_Coins[$_.Group.algo] = @{Name=$_.Group.name;Symbol=$_.Group.symbol}}
$Pool_PoolFee = 0.5

$Pool_Request | Get-Member -MemberType NoteProperty -ErrorAction Ignore | Select-Object -ExpandProperty Name | Where-Object {($Pool_Request.$_.hashrate -gt 0 -and [Double]$Pool_Request.$_.estimate_current  -gt 0) -or $InfoOnly} |ForEach-Object {
    $Pool_Host = "$($Pool_Request.$_.name).mine.zergpool.com"
    $Pool_Port = $Pool_Request.$_.port
    $Pool_Algorithm = $Pool_Request.$_.name
    if (-not $Pool_Algorithms.ContainsKey($Pool_Algorithm)) {$Pool_Algorithms[$Pool_Algorithm] = Get-Algorithm $Pool_Algorithm}
    $Pool_Algorithm_Norm = $Pool_Algorithms[$Pool_Algorithm]
    $Pool_Coin = $Pool_Coins.$Pool_Algorithm.Name
    $Pool_Symbol = $Pool_Coins.$Pool_Algorithm.Symbol
    $Pool_PoolFee = [Double]$Pool_Request.$_.fees
    if ($Pool_Coin -and -not $Pool_Symbol) {$Pool_Symbol = Get-CoinSymbol $Pool_Coin}

    $Divisor = 1000000 * [Double]$Pool_Request.$_.mbtc_mh_factor
    if ($Divisor -eq 0) {
        Write-Log -Level Info "$($Name): Unable to determine divisor for algorithm $Pool_Algorithm. "
        return
    }

    if (-not $InfoOnly) {
        if (-not (Test-Path "Stats\$($Name)_$($Pool_Algorithm_Norm)_Profit.txt")) {$Stat = Set-Stat -Name "$($Name)_$($Pool_Algorithm_Norm)_Profit" -Value ([Double]$Pool_Request.$_.estimate_last24h / $Divisor) -Duration (New-TimeSpan -Days 1)}
        else {$Stat = Set-Stat -Name "$($Name)_$($Pool_Algorithm_Norm)_Profit" -Value ((Get-YiiMPValue $Pool_Request.$_ $DataWindow) / $Divisor) -Duration $StatSpan -ChangeDetection $true}
    }

    $Pool_Regions | ForEach-Object {
        $Pool_Region = $_
        $Pool_Region_Norm = Get-Region $Pool_Region
        $Pool_Currencies | ForEach-Object {
            #Option 1
            [PSCustomObject]@{
                Algorithm     = $Pool_Algorithm_Norm
                CoinName      = $Pool_Coin
                CoinSymbol    = $Pool_Symbol
                Currency      = $_
                Price         = $Stat.Hour #instead of .Live
                StablePrice   = $Stat.Week
                MarginOfError = $Stat.Week_Fluctuation
                Protocol      = "stratum+tcp"
                Host          = if ($Pool_Region -eq "us") {$Pool_Host}else {"$Pool_Region.$Pool_Host"}
                Port          = $Pool_Port
                User          = Get-Variable $_ -ValueOnly -ErrorAction SilentlyContinue
                Pass          = "$Worker,c=$_"
                Region        = $Pool_Region_Norm
                SSL           = $false
                Updated       = $Stat.Updated
                PoolFee       = $Pool_PoolFee
                UsesDataWindow = $True
            }
        }
    }
}
