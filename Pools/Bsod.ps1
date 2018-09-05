using module ..\Include.psm1

param(
    [alias("WorkerName")]
    [String]$Worker, 
    [TimeSpan]$StatSpan,
    [String]$DataWindow = "average-2",
    [Bool]$InfoOnly = $false
)

$Name = Get-Item $MyInvocation.MyCommand.Path | Select-Object -ExpandProperty BaseName

$Pool_Fee = 0.9

$Pool_Request = [PSCustomObject]@{}
$PoolCoins_Request = [PSCustomObject]@{}

try {
    $PoolCoins_Request = Invoke-RestMethodAsync "http://api.bsod.pw/api/currencies" -retry 5 -retrywait 750
    $Pool_Request = Invoke-RestMethodAsync "http://api.bsod.pw/api/status" -retry 5 -retrywait 750
}
catch {
    Write-Log -Level Warn "Pool API ($Name) has failed. "
    return
}

if (($PoolCoins_Request | Get-Member -MemberType NoteProperty -ErrorAction Ignore | Measure-Object Name).Count -le 1) {
    Write-Log -Level Warn "Pool API ($Name) returned nothing. "
    return
}

[hashtable]$Pool_Algorithms = @{}
[hashtable]$Pool_RegionsTable = @{}

$Pool_Regions = @("eu","us","asia")
$Pool_Regions | Foreach-Object {$Pool_RegionsTable.$_ = Get-Region $_}
$Pool_MiningCurrencies = @($PoolCoins_Request | Get-Member -MemberType NoteProperty -ErrorAction Ignore | Select-Object -ExpandProperty Name) | Select-Object -Unique | Where-Object {$PoolCoins_Request.$_.symbol -and ((Get-Variable $PoolCoins_Request.$_.symbol -ValueOnly -ErrorAction Ignore) -or $InfoOnly)}

foreach($Pool_Currency in $Pool_MiningCurrencies) {
    if (($PoolCoins_Request.$Pool_Currency.hashrate -le 0 -or [Double]$PoolCoins_Request.$Pool_Currency.estimate -le 0) -and -not $InfoOnly) {continue}

    $Pool_Host = "bsod.pw"
    $Pool_Port = $PoolCoins_Request.$Pool_Currency.port
    $Pool_Algorithm = $PoolCoins_Request.$Pool_Currency.algo
    if (-not $Pool_Algorithms.ContainsKey($Pool_Algorithm)) {$Pool_Algorithms.$Pool_Algorithm = Get-Algorithm $Pool_Algorithm}
    $Pool_Algorithm_Norm = $Pool_Algorithms.$Pool_Algorithm
    $Pool_Coin = $PoolCoins_Request.$Pool_Currency.name
    $Pool_Key = "$($Pool_Algorithm)_$($Pool_Currency)".ToLower()
    $Pool_PoolFee = if ($Pool_Request -and $Pool_Request.$Pool_Key) {$Pool_Request.$Pool_Key.fees} else {$Pool_Fee}
    $Pool_DataWindow = $DataWindow

    if ($Pool_Algorithm_Norm -ne "Equihash" -and $Pool_Algorithm_Norm -like "Equihash*") {$Pool_Algorithm_All = @($Pool_Algorithm_Norm,"$Pool_Algorithm_Norm-$Pool_Currency")} else {$Pool_Algorithm_All = @($Pool_Algorithm_Norm)}

    #$Divisor = 1e9 * [Double]$Pool_Request.$Pool_Algorithm.mbtc_mh_factor
    $Divisor = 1

    switch ($Pool_Algorithm) {
        "blake2s" {$Divisor *= 1000}
        "sha256d" {$Divisor *= 1000}
    }

    if (-not $InfoOnly) {
        if ($Pool_Request -and $Pool_Request.$Pool_Key) {
            $Divisor *= 1e6
            if (-not (Test-Path "Stats\Pools\$($Name)_$($Pool_Currency)_Profit.txt")) {$Stat = Set-Stat -Name "$($Name)_$($Pool_Currency)_Profit" -Value ([Double]$Pool_Request.$Pool_Key.estimate_last24h / $Divisor) -Duration (New-TimeSpan -Days 1)}
            else {$Stat = Set-Stat -Name "$($Name)_$($Pool_Currency)_Profit" -Value ((Get-YiiMPValue $Pool_Request.$Pool_Key $DataWindow) / $Divisor) -Duration $StatSpan -ChangeDetection $true}
        } else {
            $Divisor *= 1e9
            $Stat = Set-Stat -Name "$($Name)_$($Pool_Currency)_Profit" -Value ([Double]$PoolCoins_Request.$Pool_Currency.estimate / $Divisor) -Duration $StatSpan -ChangeDetection $true
            $Pool_DataWindow = $null
        }
    }

    #Bsod is different for some coins
    $Pool_Currency = $PoolCoins_Request.$Pool_Currency.symbol

    foreach($Pool_Region in $Pool_Regions) {
        foreach($Pool_Algorithm_Norm in $Pool_Algorithm_All) {
            [PSCustomObject]@{
                Algorithm     = $Pool_Algorithm_Norm
                CoinName      = $Pool_Coin
                CoinSymbol    = $Pool_Currency
                Currency      = $Pool_Currency
                Price         = $Stat.Hour #instead of .Live
                StablePrice   = $Stat.Week
                MarginOfError = $Stat.Week_Fluctuation
                Protocol      = "stratum+tcp"
                Host          = "$($Pool_Region).bsod.pw"
                Port          = $Pool_Port
                User          = "$(Get-Variable $Pool_Currency -ValueOnly -ErrorAction Ignore).$($Worker)"
                Pass          = "c=$Pool_Currency"
                Region        = $Pool_RegionsTable.$Pool_Region
                SSL           = $false
                Updated       = $Stat.Updated
                PoolFee       = $Pool_PoolFee
                DataWindow    = $Pool_DataWindow
            }
        }
    }
}
