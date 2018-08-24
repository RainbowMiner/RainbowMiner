using module ..\Include.psm1

param(
    [alias("Wallet")]
    [String]$BTC, 
    [alias("WorkerName")]
    [String]$Worker, 
    [TimeSpan]$StatSpan,
    [Bool]$InfoOnly = $false
)

$Name = Get-Item $MyInvocation.MyCommand.Path | Select-Object -ExpandProperty BaseName

$Pool_Fee = 0.25

$Pool_Request = [PSCustomObject]@{}
$PoolCoins_Request = [PSCustomObject]@{}

try {    
    $PoolCoins_Request = Invoke-RestMethodAsync "http://blockmasters.co/api/currencies"
    $Pool_Request = Invoke-RestMethodAsync "http://blockmasters.co/api/status"
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

$Pool_Regions = @("us")
$Pool_Regions | Foreach-Object {$Pool_RegionsTable.$_ = Get-Region $_}
$Pool_Currencies = @($PoolCoins_Request | Get-Member -MemberType NoteProperty -ErrorAction Ignore | Select-Object -ExpandProperty Name) | Select-Object -Unique | Where-Object {(Get-Variable $_ -ValueOnly -ErrorAction SilentlyContinue)}
$Pool_MiningCurrencies = @($PoolCoins_Request | Get-Member -MemberType NoteProperty -ErrorAction Ignore | Select-Object -ExpandProperty Name) | Select-Object -Unique | Foreach-Object {if ($PoolCoins_Request.$_.Symbol) {$PoolCoins_Request.$_.Symbol} else {$_}} | Select-Object -Unique
$Pool_PoolFee = 0.5

foreach($Pool_Currency in $Pool_MiningCurrencies) {
    if ($PoolCoins_Request.$Pool_Currency.hashrate -le 0 -and -not $InfoOnly) {continue}

    $Pool_Host = "blockmasters.co"
    $Pool_Port = $PoolCoins_Request.$Pool_Currency.port
    $Pool_Algorithm = $PoolCoins_Request.$Pool_Currency.algo
    if (-not $Pool_Algorithms.ContainsKey($Pool_Algorithm)) {$Pool_Algorithms.$Pool_Algorithm = Get-Algorithm $Pool_Algorithm}
    $Pool_Algorithm_Norm = $Pool_Algorithms.$Pool_Algorithm
    $Pool_Coin = $PoolCoins_Request.$Pool_Currency.name
    $Pool_PoolFee = if ($Pool_Request.$Pool_Algorithm) {$Pool_Request.$Pool_Algorithm.fees} else {$Pool_Fee}
    $Pool_User = Get-Variable $Pool_Currency -ValueOnly -ErrorAction SilentlyContinue

    if ($Pool_Algorithm_Norm -ne "Equihash" -and $Pool_Algorithm_Norm -like "Equihash*") {$Pool_Algorithm_All = @($Pool_Algorithm_Norm,"$Pool_Algorithm_Norm-$Pool_Currency")} else {$Pool_Algorithm_All = @($Pool_Algorithm_Norm)}

    $Divisor = 1e9 * [Double]$Pool_Request.$Pool_Algorithm.mbtc_mh_factor
    if ($Divisor -eq 0) {
        Write-Log -Level Info "Unable to determine divisor for $Pool_Coin using $Pool_Algorithm_Norm algorithm"
        return
    }

    if (-not $InfoOnly) {
        $Stat = Set-Stat -Name "$($Name)_$($Pool_Currency)_Profit" -Value ([Double]$PoolCoins_Request.$Pool_Currency.estimate / $Divisor) -Duration $StatSpan -ChangeDetection $true
    }

    foreach($Pool_Region in $Pool_Regions) {
        foreach($Pool_Algorithm_Norm in $Pool_Algorithm_All) {
            if ($Pool_User -or $InfoOnly) {
                #Option 2
                [PSCustomObject]@{
                    Algorithm     = $Pool_Algorithm_Norm
                    CoinName      = $Pool_Coin
                    CoinSymbol    = $Pool_Currency
                    Currency      = $Pool_Currency
                    Price         = $Stat.Hour #instead of .Live
                    StablePrice   = $Stat.Week
                    MarginOfError = $Stat.Week_Fluctuation
                    Protocol      = "stratum+tcp"
                    Host          = if ($Pool_Region -eq "us") {$Pool_Host} else {"$Pool_Region.$Pool_Host"}
                    Port          = $Pool_Port
                    User          = $Pool_User
                    Pass          = "$Worker,c=$Pool_Currency,mc=$Pool_Currency"
                    Region        = $Pool_RegionsTable.$Pool_Region
                    SSL           = $false
                    Updated       = $Stat.Updated
                    PoolFee       = $Pool_PoolFee
                }
            }
            if (-not $Pool_User -or $InfoOnly) {
                foreach($Pool_ExCurrency in $Pool_Currencies) {
                    #Option 3
                    [PSCustomObject]@{
                        Algorithm     = $Pool_Algorithm_Norm
                        CoinName      = $Pool_Coin
                        CoinSymbol    = $Pool_Currency
                        Currency      = $Pool_ExCurrency
                        Price         = $Stat.Hour #instead of .Live
                        StablePrice   = $Stat.Week
                        MarginOfError = $Stat.Week_Fluctuation
                        Protocol      = "stratum+tcp"
                        Host          = if ($Pool_Region -eq "us") {$Pool_Host} else {"$Pool_Region.$Pool_Host"}
                        Port          = $Pool_Port
                        User          = Get-Variable $Pool_ExCurrency -ValueOnly -ErrorAction SilentlyContinue
                        Pass          = "$Worker,c=$Pool_ExCurrency,mc=$Pool_Currency"
                        Region        = $Pool_RegionsTable.$Pool_Region
                        SSL           = $false
                        Updated       = $Stat.Updated
                        PoolFee       = $Pool_PoolFee
                    }
                }
            }
        }
    }
}






