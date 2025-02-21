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
    [String]$AECurrency = "",
    [String]$Region = ""
)

$Name = Get-Item $MyInvocation.MyCommand.Path | Select-Object -ExpandProperty BaseName

$Pool_Request = [PSCustomObject]@{}
$PoolCoins_Request = [PSCustomObject]@{}

try {
    $PoolCoins_Request = Invoke-RestMethodAsync "https://zergpool.com/api/currencies" -tag $Name -cycletime 120 -timeout 20
}
catch {
    Write-Log -Level Warn "Pool API ($Name) has failed. "
    return
}

if (($PoolCoins_Request | Get-Member -MemberType NoteProperty -ErrorAction Ignore | Measure-Object Name).Count -le 1) {
    Write-Log -Level Warn "Pool API ($Name) returned nothing. "
    return
}

try {
    $Pool_Request = Invoke-RestMethodAsync "https://zergpool.com/api/status" -retry 3 -retrywait 1000 -delay 1000 -tag $Name -cycletime 120
}
catch {
    Write-Log -Level Warn "Pool status API ($Name) has failed. "
}

[hashtable]$Pool_Algorithms = @{}
[hashtable]$Pool_RegionsTable = @{}

$Pool_Fee = 0.5
$Pool_Regions = $null
if ($Region -ne "") {
    foreach($Region_0 in @("na","eu","asia")) {
        $Pool_Region = Get-Region $Region_0
        if ($Pool_Region -eq $Region) {
            $Pool_Regions = @($Region_0)
            $Pool_RegionsTable.$Region_0 = $Region
            break
        }
    }
}
if (-not $Pool_Regions) {
    $Pool_Regions = @("us")
    $Pool_Regions | Foreach-Object {$Pool_RegionsTable.$_ = Get-Region $_}
}

$Pool_Currencies = @("BTC","DOGE","LTC") + @($Wallets.PSObject.Properties.Name | Sort-Object | Select-Object) | Select-Object -Unique | Where-Object {$Wallets.$_ -or $InfoOnly}

if ($AECurrency -eq "") {$AECurrency = $Pool_Currencies | Select-Object -First 1}

$PoolCoins_Request.PSObject.Properties.Name | Where-Object {$PoolCoins_Request.$_.algo -ne "token" -and ((-not $CoinSymbol -or $_ -in $CoinSymbol) -and (-not $ExcludeCoinSymbol -or $_ -notin $ExcludeCoinSymbol) -or $InfoOnly)} | ForEach-Object {
    $Pool_CoinSymbol = $_
    $Pool_CoinName   = $PoolCoins_Request.$Pool_CoinSymbol.name
    $Pool_Algorithm  = $PoolCoins_Request.$Pool_CoinSymbol.algo
    $Pool_Host       = "$($Pool_Algorithm).mine.zergpool.com"
    $Pool_PoolFee    = if ($Pool_Request.$Pool_Algorithm) {[Math]::Min($Pool_Fee,$Pool_Request.$Pool_Algorithm.fees)} else {$Pool_Fee}
    $Pool_Currency   = if ($PoolCoins_Request.$Pool_CoinSymbol.symbol) {$PoolCoins_Request.$Pool_CoinSymbol.symbol} else {$Pool_CoinSymbol}

    if ($Pool_Algorithm -in @("ethash","kawpow")) {
        $Pool_Algorithm_Norm = Get-Algorithm $Pool_Algorithm -CoinSymbol $Pool_CoinSymbol
    } else {
        if ($Pool_Algorithm -eq "cryptonight_fast") {$Pool_Algorithm = "cryptonight_fast2"} #temp. fix since MSR is mined with CnFast2
        if (-not $Pool_Algorithms.ContainsKey($Pool_Algorithm)) {$Pool_Algorithms[$Pool_Algorithm] = Get-Algorithm $Pool_Algorithm}
        $Pool_Algorithm_Norm = $Pool_Algorithms[$Pool_Algorithm]
    }

    if (-not $InfoOnly -and (($Algorithm -and $Pool_Algorithm_Norm -notin $Algorithm) -or ($ExcludeAlgorithm -and $Pool_Algorithm_Norm -in $ExcludeAlgorithm))) {return}

    $Pool_EthProxy = if ($Pool_Algorithm_Norm -match $Global:RegexAlgoHasDAGSize) {if ($Pool_Algorithm_Norm -match $Global:RegexAlgoIsEthash) {"ethstratum2"} else {"stratum"}} else {$null}

    $Divisor = 1e9 * [Double]$PoolCoins_Request.$Pool_CoinSymbol.mbtc_mh_factor
    if ($Divisor -le 0) {
        Write-Log -Level Info "Unable to determine divisor for $Pool_CoinSymbol using $Pool_Algorithm_Norm algorithm"
        return
    }

    $Pool_TSL = if ($PoolCoins_Request.$Pool_CoinSymbol.timesincelast_shared -ne $null) {$PoolCoins_Request.$Pool_CoinSymbol.timesincelast_shared} else {$PoolCoins_Request.$Pool_CoinSymbol.timesincelast}

    if (-not $InfoOnly) {
        if ($Pool_Request.$Pool_Algorithm.coins -eq 1) {
            $Pool_Actual24h   = $Pool_Request.$Pool_Algorithm.actual_last24h_shared/1000
            $Pool_Estimate24h = $Pool_Request.$Pool_Algorithm.estimate_last24h
        } else {
            $Pool_Actual24h   = $PoolCoins_Request.$Pool_CoinSymbol.actual_last24h_shared/1000
            $Pool_Estimate24h = $PoolCoins_Request.$Pool_CoinSymbol.estimate_last24
        }
        $Stat = Set-Stat -Name "$($Name)_$($Pool_CoinSymbol)_Profit" -Value ([Double]$PoolCoins_Request.$Pool_CoinSymbol.estimate / $Divisor) -Duration $StatSpan -ChangeDetection $true -Actual24h $Pool_Actual24h -Estimate24h $Pool_Estimate24h -HashRate $PoolCoins_Request.$Pool_CoinSymbol.hashrate_shared -BlockRate $PoolCoins_Request.$Pool_CoinSymbol."24h_blocks_shared" -Difficulty $PoolCoins_Request.$Pool_CoinSymbol.difficulty -Quiet
        if (-not $Stat.HashRate_Live -and -not $AllowZero) {return}
    }

    $Pool_ExCurrency = if ($Wallets.$Pool_Currency -or $InfoOnly) {$Pool_Currency} elseif ($PoolCoins_Request.$Pool_CoinSymbol.noautotrade -eq 0) {$AECurrency}

    if (($Pool_ExCurrency -and $Wallets.$Pool_ExCurrency) -or $InfoOnly) {
        $Pool_Params = if ($Params."$($Pool_ExCurrency)-$($Pool_CoinSymbol)") {",$($Params."$($Pool_ExCurrency)-$($Pool_CoinSymbol)")"} elseif ($Params.$Pool_ExCurrency) {",$($Params.$Pool_ExCurrency)"}
        $Pool_ExCurrencySymbol = if ($InfoOnly) {$Pool_ExCurrency} else {$Pool_ExCurrency -replace "-(BEP|TRC)20"}

        foreach($Pool_SSL in ($false,$true)) {
            if ($Pool_SSL) {
                if (-not $PoolCoins_Request.$Pool_CoinSymbol.tls_port) {continue}
                $Pool_Port_SSL = [int]$PoolCoins_Request.$Pool_CoinSymbol.tls_port
                $Pool_Protocol = "stratum+ssl"
            } else {
                if ($Pool_Algorithm_Norm -match "^Ethash") {continue}
                $Pool_Port_SSL = [int]$PoolCoins_Request.$Pool_CoinSymbol.port
                $Pool_Protocol = "stratum+tcp"
            }
            foreach($Pool_Region in $Pool_Regions) {
                #Option 2/3
                [PSCustomObject]@{
                    Algorithm          = $Pool_Algorithm_Norm
                    Algorithm0         = $Pool_Algorithm_Norm
                    CoinName           = $Pool_CoinName
                    CoinSymbol         = $Pool_Currency
                    Currency           = $Pool_ExCurrencySymbol
                    Price              = $Stat.$StatAverage #instead of .Live
                    StablePrice        = $Stat.$StatAverageStable
                    MarginOfError      = $Stat.Week_Fluctuation
                    Protocol           = $Pool_Protocol
                    Host               = if ($Pool_Region -eq "us") {$Pool_Host} else {"$($Pool_Algorithm).$($Pool_Region).mine.zergpool.com"}
                    Port               = $Pool_Port_SSL
                    User               = $Wallets.$Pool_ExCurrency
                    Pass               = "c=$($Pool_ExCurrency),mc=$Pool_Currency,ID={workername:$Worker}{diff:,sd=`$difficulty}$Pool_Params"
                    Region             = $Pool_RegionsTable.$Pool_Region
                    SSL                = $Pool_SSL
                    SSLSelfSigned      = $Pool_SSL
                    Updated            = $Stat.Updated
                    PoolFee            = $Pool_PoolFee
                    Workers            = $PoolCoins_Request.$Pool_CoinSymbol.workers_shared
                    Hashrate           = $Stat.HashRate_Live
                    BLK                = $Stat.BlockRate_Average
                    TSL                = $Pool_TSL
                    EthMode            = $Pool_EthProxy
                    ErrorRatio         = $Stat.ErrorRatio
                    Name               = $Name
                    Penalty            = 0
                    PenaltyFactor      = 1
                    Disabled           = $false
                    HasMinerExclusions = $false
                    Price_0            = 0.0
                    Price_Bias         = 0.0
                    Price_Unbias       = 0.0
                    Wallet             = $Wallets.$Pool_ExCurrency
                    Worker             = "{workername:$Worker}"
                    Email              = $Email
                }
            }
        }
    }
}
