using module ..\Include.psm1

param(
    [PSCustomObject]$Wallets,
    [alias("WorkerName")]
    [String]$Worker, 
    [TimeSpan]$StatSpan,
    [String]$DataWindow = "estimate_current",
    [Bool]$InfoOnly = $false
)

$Name = Get-Item $MyInvocation.MyCommand.Path | Select-Object -ExpandProperty BaseName

$Pool_Fee = 2

$Pool_Request = [PSCustomObject]@{}
$PoolCoins_Request = [PSCustomObject]@{}

try {
    $PoolCoins_Request = Invoke-RestMethodAsync "http://api.yiimp.eu/api/currencies" -tag $Name
}
catch {
    if ($Error.Count){$Error.RemoveAt(0)}
    Write-Log -Level Warn "Pool API ($Name) has failed. "
    return
}

if (($PoolCoins_Request | Get-Member -MemberType NoteProperty -ErrorAction Ignore | Measure-Object Name).Count -le 1) {
    Write-Log -Level Warn "Pool API ($Name) returned nothing. "
    return
}

try {
    $Pool_Request = Invoke-RestMethodAsync "http://api.yiimp.eu/api/status" -tag $Name
}
catch {
    if ($Error.Count){$Error.RemoveAt(0)}
    Write-Log -Level Warn "Pool status API ($Name) has failed. "
}

[hashtable]$Pool_Algorithms = @{}
[hashtable]$Pool_RegionsTable = @{}

$Pool_Regions = @("us")
$Pool_Regions | Foreach-Object {$Pool_RegionsTable.$_ = Get-Region $_}
$Pool_MiningCurrencies = @($Wallets.PSObject.Properties.Name | Select-Object) + @($PoolCoins_Request | Get-Member -MemberType NoteProperty -ErrorAction Ignore | Select-Object -ExpandProperty Name) | Select-Object -Unique | Where-Object {$Wallets.$_ -or $InfoOnly}
$Pool_PoolFee = 2.0

foreach($Pool_Currency in $Pool_MiningCurrencies) {
    if (($PoolCoins_Request.$Pool_Currency.hashrate -le 0 -or 
         $PoolCoins_Request.$Pool_Currency.workers  -le 0 -or
         $PoolCoins_Request.$Pool_Currency.'24h_blocks' -le 0) -and -not $InfoOnly) {continue}
    
    $Pool_CoinSymbol = $Pool_Currency
    $Pool_Host = "yiimp.eu"
    $Pool_Port = $PoolCoins_Request.$Pool_Currency.port
    $Pool_Algorithm = $PoolCoins_Request.$Pool_Currency.algo
    if (-not $Pool_Algorithms.ContainsKey($Pool_Algorithm)) {$Pool_Algorithms.$Pool_Algorithm = Get-Algorithm $Pool_Algorithm}
    $Pool_Algorithm_Norm = $Pool_Algorithms[$Pool_Algorithm]
    $Pool_Coin = $PoolCoins_Request.$Pool_Currency.name
    $Pool_PoolFee = if($Pool_Request.$Pool_Algorithm) {[Double]$Pool_Request.$Pool_Algorithm.fees} else {$Pool_Fee}
    $Pool_User = $Wallets.$Pool_Currency

    if ($Pool_Algorithm_Norm -ne "Equihash" -and $Pool_Algorithm_Norm -like "Equihash*") {$Pool_Algorithm_All = @($Pool_Algorithm_Norm,"$Pool_Algorithm_Norm-$Pool_Currency")} else {$Pool_Algorithm_All = @($Pool_Algorithm_Norm)}

    if ($Pool_Request.$Pool_Algorithm.mbtc_mh_factor) {
        $Pool_Factor = [Double]$Pool_Request.$Pool_Algorithm.mbtc_mh_factor
    } else {
        $Pool_Factor = [Double]$(Switch($Pool_Algorithm_Norm) {
            "Blake2s"   {1000}
            "Blakecoin" {1000}
            "Equihash"  {1/1000}
            "KeccakC"   {1000}
            "Scrypt"    {1000}
            "Sha256"    {1000}
            default     {1}
        })
    }
    $Divisor = $Pool_Factor * 1e9

    $Pool_TSL = $PoolCoins_Request.$Pool_CoinSymbol.timesincelast

    if (-not $InfoOnly) {
        $Stat = Set-Stat -Name "$($Name)_$($Pool_Currency)_Profit" -Value ([Double]$PoolCoins_Request.$Pool_Currency.estimate / $Divisor) -Duration $StatSpan -ChangeDetection $true
        $StatHSR = Set-Stat -Name "$($Name)_$($Pool_CoinSymbol)_HSR" -Value ([Int64]$PoolCoins_Request.$Pool_CoinSymbol.hashrate) -Duration $StatSpan -ChangeDetection $false
        $StatBLK = Set-Stat -Name "$($Name)_$($Pool_CoinSymbol)_BLK" -Value ([Int64]$PoolCoins_Request.$Pool_CoinSymbol."24h_blocks") -Duration $StatSpan -ChangeDetection $false
    }

    foreach($Pool_Region in $Pool_Regions) {
        foreach($Pool_Algorithm_Norm in $Pool_Algorithm_All) {
            if ($Pool_User -or $InfoOnly) {
                [PSCustomObject]@{
                    Algorithm     = $Pool_Algorithm_Norm
                    CoinName      = $Pool_Coin
                    CoinSymbol    = $Pool_Currency
                    Currency      = $Pool_Currency
                    Price         = $Stat.Hour #instead of .Live
                    StablePrice   = $Stat.Week
                    MarginOfError = $Stat.Week_Fluctuation
                    Protocol      = "stratum+tcp"
                    Host          = $Pool_Host
                    Port          = $Pool_Port
                    User          = $Pool_User
                    Pass          = "$Worker,c=$Pool_Currency"
                    Region        = $Pool_RegionsTable.$Pool_Region
                    SSL           = $false
                    Updated       = $Stat.Updated
                    PoolFee       = $Pool_PoolFee
                    Hashrate      = $StatHSR.Hour
                    BLK           = $StatBLK.Hour
                    TSL           = $Pool_TSL
                }
            }
        }
    }
}
