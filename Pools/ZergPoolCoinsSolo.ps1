using module ..\Include.psm1

param(
    [PSCustomObject]$Wallets,
    [PSCustomObject]$Params,
    [alias("WorkerName")]
    [String]$Worker, 
    [TimeSpan]$StatSpan,
    [String]$DataWindow = "estimate_current",
    [Bool]$InfoOnly = $false,
    [Bool]$AllowZero = $false,
    [String]$StatAverage = "Minute_10",
    [String]$AECurrency = ""
)

$Name = Get-Item $MyInvocation.MyCommand.Path | Select-Object -ExpandProperty BaseName

$Pool_Fee = 0.5

$Pool_Request = [PSCustomObject]@{}
$PoolCoins_Request = [PSCustomObject]@{}

try {
    $PoolCoins_Request = Invoke-RestMethodAsync "http://api.zergpool.com:8080/api/currencies" -tag $Name -cycletime 120
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
    $Pool_Request = Invoke-RestMethodAsync "http://api.zergpool.com:8080/api/status" -retry 3 -retrywait 1000 -delay 1000 -tag $Name -cycletime 120
}
catch {
    if ($Error.Count){$Error.RemoveAt(0)}
    Write-Log -Level Warn "Pool status API ($Name) has failed. "
}

[hashtable]$Pool_Algorithms = @{}
[hashtable]$Pool_RegionsTable = @{}

@("us") | Foreach-Object {$Pool_RegionsTable.$_ = Get-Region $_}

$Pool_Currencies = @("BTC", "DASH", "LTC") + @($Wallets.PSObject.Properties.Name | Sort-Object | Select-Object) | Select-Object -Unique | Where-Object {$Wallets.$_ -or $InfoOnly}

if ($AECurrency -eq "") {$AECurrency = $Pool_Currencies | Select-Object -First 1}

$PoolCoins_Request | Get-Member -MemberType NoteProperty -ErrorAction Ignore | Select-Object -ExpandProperty Name | Where-Object {$Pool_CoinSymbol = $_;$Pool_Currency = if ($PoolCoins_Request.$Pool_CoinSymbol.symbol) {$PoolCoins_Request.$Pool_CoinSymbol.symbol} else {$Pool_CoinSymbol};($PoolCoins_Request.$_.hashrate_solo -gt 0 -or $AllowZero) -or $InfoOnly} | ForEach-Object {
    $Pool_Host = "$($PoolCoins_Request.$Pool_CoinSymbol.algo).mine.zergpool.com"
    $Pool_Port = $PoolCoins_Request.$Pool_CoinSymbol.port
    $Pool_Algorithm = $PoolCoins_Request.$Pool_CoinSymbol.algo
    if (-not $Pool_Algorithms.ContainsKey($Pool_Algorithm)) {$Pool_Algorithms[$Pool_Algorithm] = Get-Algorithm $Pool_Algorithm}
    $Pool_Algorithm_Norm = $Pool_Algorithms[$Pool_Algorithm]
    $Pool_Coin = $PoolCoins_Request.$Pool_CoinSymbol.name
    $Pool_PoolFee = if ($Pool_Request.$Pool_Algorithm) {$Pool_Request.$Pool_Algorithm.fees} else {$Pool_Fee}

    if ($Pool_Algorithm_Norm -ne "Equihash" -and $Pool_Algorithm_Norm -like "Equihash*") {$Pool_Algorithm_All = @($Pool_Algorithm_Norm,"$Pool_Algorithm_Norm-$Pool_Currency")} else {$Pool_Algorithm_All = @($Pool_Algorithm_Norm)}

    if ($PoolCoins_Request.$Pool_CoinSymbol.mbtc_mh_factor) {
        $Pool_Factor = [Double]$PoolCoins_Request.$Pool_CoinSymbol.mbtc_mh_factor
    } else {
        $Pool_Factor = [Double]$(Switch ($_) {
            "aergo" {1}
            "allium" {1}
            "argon2d-dyn" {1}
            "balloon" {0.001}
            "bitcore" {1}
            "blake2s" {1000}
            "c11" {1}
            "equihash" {0.001}
            "equihash125" {0.001}
            "equihash144" {0.001}
            "equihash192" {0.001}
            "equihash96" {1}
            "hex" {1000}
            "hmq1725" {1}
            "keccak" {1000}
            "keccakc" {1000}
            "lbry" {1000}
            "lyra2v2" {1}
            "lyra2z" {1}
            "m7m" {1}
            "myr-gr" {1000}
            "neoscrypt" {1}
            "nist5" {1000}
            "phi" {1}
            "phi2" {1}
            "polytimos" {1}
            "quark" {1000}
            "qubit" {1000}
            "scrypt" {1000}
            "sha256" {1000000000}
            "skein" {1000}
            "skunk" {1}
            "sonoa" {1}
            "tribus" {1}
            "x11" {1000}
            "x11evo" {1}
            "x13" {1000}
            "x16r" {1}
            "x16s" {1}
            "x17" {1}
            "xevan" {1}
            "yescrypt" {0.001}
            "yescryptR16" {0.001}
            "yespower" {0.001}
        })
    }
    if ($Pool_Factor -le 0) {
        Write-Log -Level Info "Unable to determine divisor for $Pool_Coin using $Pool_Algorithm_Norm algorithm"
        return
    }

    $Divisor = 1e9 * $Pool_Factor

    $Pool_TSL = if ($PoolCoins_Request.$Pool_CoinSymbol.timesincelast_solo -ne $null) {$PoolCoins_Request.$Pool_CoinSymbol.timesincelast_solo} else {$PoolCoins_Request.$Pool_CoinSymbol.timesincelast}

    if (-not $InfoOnly) {
        $Stat = Set-Stat -Name "$($Name)_$($Pool_CoinSymbol)_Profit" -Value ([Double]$PoolCoins_Request.$Pool_CoinSymbol.estimate / $Divisor) -Duration $StatSpan -ChangeDetection $true -Actual24h $($PoolCoins_Request.$Pool_CoinSymbol.actual_last24h_solo/1000) -Estimate24h $($PoolCoins_Request.$Pool_CoinSymbol.estimate_last24) -HashRate $PoolCoins_Request.$Pool_CoinSymbol.hashrate_solo -BlockRate $PoolCoins_Request.$Pool_CoinSymbol."24h_blocks_solo" -Quiet
    }

    $Pool_ExCurrency = if ($Wallets.$Pool_Currency -or $InfoOnly) {$Pool_Currency} elseif ($PoolCoins_Request.$Pool_Currency.noautotrade -eq 0) {$AECurrency}

    if (($Pool_ExCurrency -and $Wallets.$Pool_ExCurrency) -or $InfoOnly) {
        $Pool_Params = if ($Params.$Pool_ExCurrency) {",$($Params.$Pool_ExCurrency)"}
        foreach($Pool_Region in $Pool_RegionsTable.Keys) {
            foreach($Pool_Algorithm_Norm in $Pool_Algorithm_All) {
                #Option 2/3
                [PSCustomObject]@{
                    Algorithm     = $Pool_Algorithm_Norm
                    CoinName      = $Pool_Coin
                    CoinSymbol    = $Pool_CoinSymbol
                    Currency      = $Pool_ExCurrency
                    Price         = $Stat.$StatAverage #instead of .Live
                    StablePrice   = $Stat.Week
                    MarginOfError = $Stat.Week_Fluctuation
                    Protocol      = "stratum+tcp"
                    Host          = if ($Pool_Region -eq "us") {$Pool_Host} else {"$Pool_Region.$Pool_Host"}
                    Port          = $Pool_Port
                    User          = $Wallets.$Pool_ExCurrency
                    Pass          = "{workername:$Worker},c=$Pool_ExCurrency,mc=$Pool_Currency,m=solo{diff:,d=`$difficulty}$Pool_Params"
                    Region        = $Pool_RegionsTable.$Pool_Region
                    SSL           = $false
                    Updated       = $Stat.Updated
                    PoolFee       = $Pool_PoolFee
                    Workers       = $PoolCoins_Request.$Pool_CoinSymbol.workers_solo
                    Hashrate      = $Stat.HashRate_Live
                    BLK           = $Stat.BlockRate_Average
                    TSL           = $Pool_TSL
                    ErrorRatio    = $Stat.ErrorRatio
                    AlgorithmList = if ($Pool_Algorithm_Norm -match "-") {@($Pool_Algorithm_Norm, ($Pool_Algorithm_Norm -replace '\-.*$'))}else{@($Pool_Algorithm_Norm)}
                    Name          = $Name
                    Penalty       = 0
                    PenaltyFactor = 1
                    Wallet        = $Wallets.$Pool_Currency
                    Worker        = "{workername:$Worker}"
                    Email         = $Email
                }
            }
        }
    }
}
