using module ..\Modules\Include.psm1

param(
    [PSCustomObject]$Wallets,
    [PSCustomObject]$Params,
    [alias("WorkerName")]
    [String]$Worker, 
    [TimeSpan]$StatSpan,
    [Bool]$InfoOnly = $false,
    [Bool]$AllowZero = $false,
    [String]$StatAverage = "Minute_10",
    [String]$StatAverageStable = "Week",
    [String]$PartyPassword = "",
    [String]$AECurrency = ""
)

$Name = Get-Item $MyInvocation.MyCommand.Path | Select-Object -ExpandProperty BaseName

if (-not $PartyPassword -and -not $InfoOnly) {return}

$Pool_Request = [PSCustomObject]@{}
$PoolCoins_Request = [PSCustomObject]@{}

try {
    $PoolCoins_Request = Invoke-RestMethodAsync "http://api.zergpool.com:8080/api/currencies" -tag $Name -cycletime 120 -timeout 20
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

$Pool_Fee = if ($Session.Config.ReduceZergPoolFee) {0.3} else {0.5}
$Pool_AddRefcode = "$(if ($Session.Config.ReduceZergPoolFee -and -not $Session.IsDonationRun) {",refcode=78f6ec9427d56069f93709d7805a6a56"})"

$Pool_Regions = @("us")
$Pool_Regions | Foreach-Object {$Pool_RegionsTable.$_ = Get-Region $_}

$Pool_Currencies = @("BTC", "DASH", "LTC") + @($Wallets.PSObject.Properties.Name | Sort-Object | Select-Object) | Select-Object -Unique | Where-Object {$Wallets.$_ -or $InfoOnly}

if ($AECurrency -eq "") {$AECurrency = $Pool_Currencies | Select-Object -First 1}

$PoolCoins_Request | Get-Member -MemberType NoteProperty -ErrorAction Ignore | Select-Object -ExpandProperty Name | ForEach-Object {

    $Pool_CoinSymbol = $_
    $Pool_Currency = if ($PoolCoins_Request.$Pool_CoinSymbol.symbol) {$PoolCoins_Request.$Pool_CoinSymbol.symbol} else {$Pool_CoinSymbol}

    $Pool_Host = "$($PoolCoins_Request.$Pool_CoinSymbol.algo).mine.zergpool.com"
    $Pool_Port = $PoolCoins_Request.$Pool_CoinSymbol.port
    $Pool_Algorithm = $PoolCoins_Request.$Pool_CoinSymbol.algo
    if ($Pool_Algorithm -eq "cryptonight_fast") {$Pool_Algorithm = "cryptonight_fast2"} #temp. fix since MSR is mined with CnFast2
    if (-not $Pool_Algorithms.ContainsKey($Pool_Algorithm)) {$Pool_Algorithms[$Pool_Algorithm] = Get-Algorithm $Pool_Algorithm}
    $Pool_Algorithm_Norm = $Pool_Algorithms[$Pool_Algorithm]
    $Pool_Coin = $PoolCoins_Request.$Pool_CoinSymbol.name
    $Pool_PoolFee = if ($Pool_Request.$Pool_Algorithm) {[Math]::Min($Pool_Fee,$Pool_Request.$Pool_Algorithm.fees)} else {$Pool_Fee}
    $Pool_EthProxy = if ($Pool_Algorithm_Norm -match $Global:RegexAlgoHasDAGSize) {if ($Pool_Algorithm_Norm -match $Global:RegexAlgoIsEthash) {"ethproxy"} else {"stratum"}} else {$null}

    if ($Pool_CoinSymbol -eq "CURVE") {$Pool_Port = 3343}

    $Divisor = 1e9 * [Double]$PoolCoins_Request.$Pool_CoinSymbol.mbtc_mh_factor
    if ($Divisor -le 0) {
        Write-Log -Level Info "Unable to determine divisor for $Pool_Coin using $Pool_Algorithm_Norm algorithm"
        return
    }

    $Pool_Diff = if ([double]$PoolCoins_Request.$Pool_CoinSymbol.network_hashrate -gt [double]$PoolCoins_Request.$Pool_CoinSymbol.hashrate -or [int]$PoolCoins_Request.$Pool_CoinSymbol."24h_blocks" -eq 0) {
        [double]$PoolCoins_Request.$Pool_CoinSymbol.network_hashrate * $PoolCoins_Request.$Pool_CoinSymbol.blocktime / [Math]::Pow(2,32)
    } else {
        [double]$PoolCoins_Request.$Pool_CoinSymbol.hashrate * 86400 / $PoolCoins_Request.$Pool_CoinSymbol."24h_blocks" / [Math]::Pow(2,32)
    }

    if (-not $InfoOnly) {
        if ($Pool_Request.$Pool_Algorithm.coins -eq 1) {
            $Pool_Actual24h   = $Pool_Request.$Pool_Algorithm.actual_last24h/1000
            $Pool_Estimate24h = $Pool_Request.$Pool_Algorithm.estimate_last24h
        } else {
            $Pool_Actual24h   = $PoolCoins_Request.$Pool_CoinSymbol.actual_last24h/1000
            $Pool_Estimate24h = $PoolCoins_Request.$Pool_CoinSymbol.estimate_last24
        }
        $Stat = Set-Stat -Name "$($Name)_$($Pool_CoinSymbol)_Profit" -Value ([Double]$PoolCoins_Request.$Pool_CoinSymbol.estimate / $Divisor) -Duration $StatSpan -ChangeDetection $false -Actual24h $Pool_Actual24h -Estimate24h $Pool_Estimate24h -Difficulty $Pool_Diff -Quiet
    }

    $Pool_ExCurrency = if ($Wallets.$Pool_Currency -or $InfoOnly) {$Pool_Currency} elseif ($PoolCoins_Request.$Pool_CoinSymbol.noautotrade -eq 0) {$AECurrency}

    if (($Pool_ExCurrency -and $Wallets.$Pool_ExCurrency) -or $InfoOnly) {
        $Pool_Params = if ($Params."$($Pool_ExCurrency)-$($Pool_CoinSymbol)") {",$($Params."$($Pool_ExCurrency)-$($Pool_CoinSymbol)")"} elseif ($Params.$Pool_ExCurrency) {",$($Params.$Pool_ExCurrency)"} 
        foreach($Pool_Region in $Pool_Regions) {
            #Option 2/3
            [PSCustomObject]@{
                Algorithm     = $Pool_Algorithm_Norm
                Algorithm0    = $Pool_Algorithm_Norm
                CoinName      = $Pool_Coin
                CoinSymbol    = $Pool_CoinSymbol
                Currency      = $Pool_ExCurrency
                Price         = $Stat.$StatAverage #instead of .Live
                StablePrice   = $Stat.$StatAverageStable
                MarginOfError = $Stat.Week_Fluctuation
                Protocol      = "stratum+tcp"
                Host          = if ($Pool_Region -eq "us") {$Pool_Host} else {"$Pool_Region.$Pool_Host"}
                Port          = $Pool_Port
                User          = $Wallets.$Pool_ExCurrency
                Pass          = "ID={workername:$Worker},c=$Pool_ExCurrency,mc=$Pool_Currency,m=party.$($PartyPassword){diff:,sd=`$difficulty}$Pool_Params$Pool_AddRefcode"
                Region        = $Pool_RegionsTable.$Pool_Region
                SSL           = $false
                Updated       = $Stat.Updated
                PoolFee       = $Pool_PoolFee
                Workers       = $null
                Hashrate      = $null
                BLK           = $null
                TSL           = $null
                Difficulty    = $Stat.Diff_Average
                SoloMining    = $true
                EthMode       = $Pool_EthProxy
                ErrorRatio    = $Stat.ErrorRatio
                Name          = $Name
                Penalty       = 0
                PenaltyFactor = 1
                Disabled      = $false
                HasMinerExclusions = $false
                Price_Bias    = 0.0
                Price_Unbias  = 0.0
                Wallet        = $Wallets.$Pool_ExCurrency
                Worker        = "{workername:$Worker}"
                Email         = $Email
            }
        }
    }
}
