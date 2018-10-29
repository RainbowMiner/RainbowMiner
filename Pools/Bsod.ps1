using module ..\Include.psm1

param(
    [PSCustomObject]$Wallets,
    [alias("WorkerName")]
    [String]$Worker, 
    [TimeSpan]$StatSpan,
    [String]$DataWindow = "average-2",
    [Bool]$InfoOnly = $false,
    [Bool]$AllowZero = $false
)

$Name = Get-Item $MyInvocation.MyCommand.Path | Select-Object -ExpandProperty BaseName

$Pool_Fee = 0.9

$Pool_Request = [PSCustomObject]@{}
$PoolCoins_Request = [PSCustomObject]@{}

try {
    $PoolCoins_Request = Invoke-RestMethodAsync "http://api.bsod.pw/api/currencies" -tag $Name
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
    $Pool_Request = Invoke-RestMethodAsync "http://api.bsod.pw/api/status" -delay 1000 -tag $Name
}
catch {
    if ($Error.Count){$Error.RemoveAt(0)}
    Write-Log -Level Warn "Pool status API ($Name) has failed. "
}

[hashtable]$Pool_Algorithms = @{}
[hashtable]$Pool_RegionsTable = @{}

$Pool_Regions = @("eu","us","asia")
$Pool_Regions | Foreach-Object {$Pool_RegionsTable.$_ = Get-Region $_}

$PoolCoins_Request | Get-Member -MemberType NoteProperty -ErrorAction Ignore | Select-Object -ExpandProperty Name | Where-Object {(($PoolCoins_Request.$_.hashrate -gt 0 -or $AllowZero) -and $PoolCoins_Request.$_.symbol -and $Wallets."$($PoolCoins_Request.$_.symbol)") -or $InfoOnly} | ForEach-Object {
    $Pool_CoinSymbol = $_

    $Pool_Host = "bsod.pw"
    $Pool_Port = $PoolCoins_Request.$Pool_CoinSymbol.port
    $Pool_Algorithm = $PoolCoins_Request.$Pool_CoinSymbol.algo
    if (-not $Pool_Algorithms.ContainsKey($Pool_Algorithm)) {$Pool_Algorithms.$Pool_Algorithm = Get-Algorithm $Pool_Algorithm}
    $Pool_Algorithm_Norm = $Pool_Algorithms.$Pool_Algorithm
    $Pool_Coin = $PoolCoins_Request.$Pool_CoinSymbol.name
    $Pool_Key = "$($Pool_Algorithm)_$($Pool_CoinSymbol)".ToLower()
    $Pool_PoolFee = if ($PoolCoins_Request.$Pool_CoinSymbol.fees -ne $null) {$Pool_Request.$Pool_CoinSymbol.fees} else {$Pool_Fee}
    $Pool_DataWindow = $DataWindow
    $Pool_Currency = if ($PoolCoins_Request.$Pool_CoinSymbol.symbol) {$PoolCoins_Request.$Pool_CoinSymbol.symbol} else {$Pool_CoinSymbol}
    $Pool_User = $Wallets.$Pool_Currency

    if ($Pool_Algorithm_Norm -ne "Equihash" -and $Pool_Algorithm_Norm -like "Equihash*") {$Pool_Algorithm_All = @($Pool_Algorithm_Norm,"$Pool_Algorithm_Norm-$Pool_Currency")} else {$Pool_Algorithm_All = @($Pool_Algorithm_Norm)}

    #$Divisor = 1e9 * [Double]$Pool_Request.$Pool_Algorithm.mbtc_mh_factor

    $Pool_Factor = [Double]$(switch ($Pool_Algorithm) {
        "blake2s" {1000}
        "sha256d" {1000}
        default {1}
    })

    $Pool_TSL = $PoolCoins_Request.$Pool_CoinSymbol.timesincelast_shared

    if (-not $InfoOnly) {
        if ($Pool_Request -and $Pool_Request.$Pool_Key) {
            if (-not (Test-Path "Stats\Pools\$($Name)_$($Pool_CoinSymbol)_Profit.txt")) {$Stat = Set-Stat -Name "$($Name)_$($Pool_CoinSymbol)_Profit" -Value (Get-YiiMPValue $Pool_Request.$Pool_Key -DataWindow "estimate_last24h" -Factor $Pool_Factor) -Duration (New-TimeSpan -Days 1) -HashRate $PoolCoins_Request.$Pool_CoinSymbol.hashrate_shared -BlockRate $PoolCoins_Request.$Pool_CoinSymbol."24h_blocks_shared" -Quiet}
            else {$Stat = Set-Stat -Name "$($Name)_$($Pool_CoinSymbol)_Profit" -Value (Get-YiiMPValue $Pool_Request.$Pool_Key -DataWindow $DataWindow -Factor $Pool_Factor) -Duration $StatSpan -ChangeDetection $true -HashRate $PoolCoins_Request.$Pool_CoinSymbol.hashrate_shared -BlockRate $PoolCoins_Request.$Pool_CoinSymbol."24h_blocks_shared" -Quiet}
        } else {
            $Divisor = $Pool_Factor * 1e9
            $Stat = Set-Stat -Name "$($Name)_$($Pool_CoinSymbol)_Profit" -Value ([Double]$PoolCoins_Request.$Pool_CoinSymbol.estimate / $Divisor) -Duration $StatSpan -ChangeDetection $true -HashRate $PoolCoins_Request.$Pool_CoinSymbol.hashrate_shared -BlockRate $PoolCoins_Request.$Pool_CoinSymbol."24h_blocks_shared"
            $Pool_DataWindow = $null
        }
    }

    foreach($Pool_Region in $Pool_Regions) {
        foreach($Pool_Algorithm_Norm in $Pool_Algorithm_All) {
            [PSCustomObject]@{
                Algorithm     = $Pool_Algorithm_Norm
                CoinName      = $Pool_Coin
                CoinSymbol    = $Pool_CoinSymbol
                Currency      = $Pool_Currency
                Price         = $Stat.Minute_10 #instead of .Live
                StablePrice   = $Stat.Week
                MarginOfError = $Stat.Week_Fluctuation
                Protocol      = "stratum+tcp"
                Host          = "$($Pool_Region).bsod.pw"
                Port          = $Pool_Port
                User          = "$($Pool_User).$($Worker)"
                Pass          = "c=$Pool_Currency{diff:,d=`$difficulty}"
                Region        = $Pool_RegionsTable.$Pool_Region
                SSL           = $false
                Updated       = $Stat.Updated
                PoolFee       = $Pool_PoolFee
                DataWindow    = $Pool_DataWindow
                Workers       = $PoolCoins_Request.$Pool_CoinSymbol.workers_shared
                Hashrate      = $Stat.HashRate_Live
                BLK           = $Stat.BlockRate_Average
                TSL           = $Pool_TSL
            }
        }
    }
}
