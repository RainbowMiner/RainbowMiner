using module ..\Modules\Include.psm1

param(
    [String]$Name,
    [PSCustomObject]$Wallets,
    [PSCustomObject]$Params,
    [alias("WorkerName")]
    [String]$Worker, 
    [TimeSpan]$StatSpan,
    [String]$DataWindow = "estimate_current",
    [Bool]$InfoOnly = $false,
    [Bool]$AllowZero = $false,
    [String]$StatAverage = "Minute_10",
    [String]$StatAverageStable = "Week",
    [String]$AECurrency = "",
    [String]$Region = ""
)

$CoinSymbol = $Session.Config.Pools.$Name.CoinSymbol
$ExcludeCoinSymbol = $Session.Config.Pools.$Name.ExcludeCoinSymbol

# $Name = Get-Item $MyInvocation.MyCommand.Path | Select-Object -ExpandProperty BaseName

$Pool_Request = [PSCustomObject]@{}
$PoolCoins_Request = [PSCustomObject]@{}

try {
    $Pool_Request = Invoke-RestMethodAsync "https://zergpool.com/api/status" -retry 3 -retrywait 1000 -tag $Name -cycletime 120
}
catch {
    Write-Log -Level Warn "Pool API ($Name) has failed. "
    return
}

if (($Pool_Request | Get-Member -MemberType NoteProperty -ErrorAction Ignore | Measure-Object Name).Count -le 1) {
    Write-Log -Level Warn "Pool API ($Name) returned nothing. "
    return
}

try {
    $PoolCoins_Request = Invoke-RestMethodAsync "https://zergpool.com/api/currencies" -delay 1000 -tag $Name -cycletime 120 -timeout 20
}
catch {
    Write-Log -Level Warn "Pool currencies API ($Name) has failed. "
}

if ($DataWindow -eq "actual_last24h") {$DataWindow = "actual_last24h_shared"}

[hashtable]$Pool_Algorithms = @{}
[hashtable]$Pool_Coins = @{}
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

if ($InfoOnly) {
    $Pool_Currencies = @("BTC") + @($PoolCoins_Request.PSObject.Properties.Name | Foreach-Object {if ($PoolCoins_Request.$_.symbol -eq $null -or $_ -match "^USD(T|C)-"){$_} else {$PoolCoins_Request.$_.symbol}}) | Select-Object -Unique
} else {
    $Pool_Currencies = @("BTC","DOGE","LTC") + @($Wallets.PSObject.Properties.Name | Sort-Object | Select-Object) | Select-Object -Unique | Where-Object {$Wallets.$_}
}
if ($PoolCoins_Request) {
    $PoolCoins_Algorithms = @($Pool_Request.PSObject.Properties.Value | Where-Object coins -eq 1 | Select-Object -ExpandProperty name -Unique)
    if ($PoolCoins_Algorithms.Count) {foreach($p in $PoolCoins_Request.PSObject.Properties.Name) {if ($PoolCoins_Algorithms -contains $PoolCoins_Request.$p.algo) {$Pool_Coins[$PoolCoins_Request.$p.algo] = [hashtable]@{Name = $PoolCoins_Request.$p.name; Symbol = $p -replace '-.+$'}}}}
}

if (-not $InfoOnly) {
    if ($Pool_Currencies.Count -gt 1) {
        if ($AECurrency -eq "" -or $AECurrency -notin $Pool_Currencies) {$AECurrency = $Pool_Currencies | Select-Object -First 1}
        $Pool_Currencies = $Pool_Currencies | Where-Object {$_ -eq $AECurrency}
    }
}

$Pool_Request.PSObject.Properties.Name | ForEach-Object {
    $Pool_Algorithm  = $Pool_Request.$_.name
    $Pool_Host       = "$($Pool_Algorithm).mine.zergpool.com"
    $Pool_CoinName   = $Pool_Coins.$Pool_Algorithm.Name
    $Pool_CoinSymbol = $Pool_Coins.$Pool_Algorithm.Symbol
    if ($Pool_Fee -lt $Pool_PoolFee) {
        $Pool_PoolFee = $Pool_Fee
    }

    if ($Pool_CoinName -and -not $Pool_CoinSymbol) {$Pool_CoinSymbol = Get-CoinSymbol $Pool_CoinName}

    if ($Pool_Algorithm -in @("ethash","kawpow") -and $Pool_CoinSymbol) {
        $Pool_Algorithm_Norm = Get-Algorithm $Pool_Algorithm -CoinSymbol $Pool_CoinSymbol
    } else {
        if ($Pool_Algorithm -eq "cryptonight_fast") {$Pool_Algorithm = "cryptonight_fast2"} #temp. fix since MSR is mined with CnFast2
        if (-not $Pool_Algorithms.ContainsKey($Pool_Algorithm)) {$Pool_Algorithms[$Pool_Algorithm] = Get-Algorithm $Pool_Algorithm}
        $Pool_Algorithm_Norm = $Pool_Algorithms[$Pool_Algorithm]
    }

    if (-not $InfoOnly -and (($Algorithm -and $Pool_Algorithm_Norm -notin $Algorithm) -or ($ExcludeAlgorithm -and $Pool_Algorithm_Norm -in $ExcludeAlgorithm))) {return}
    if (-not $InfoOnly -and $Pool_CoinSymbol -and (($CoinSymbol -and $Pool_CoinSymbol -notin $CoinSymbol) -or ($ExcludeCoinSymbol -and $Pool_CoinSymbol -in $ExcludeCoinSymbol))) {return}

    $Pool_EthProxy = $Pool_CoinSymbolMax = $null
    if ($Pool_Algorithm_Norm -match $Global:RegexAlgoHasDAGSize) {
        $Pool_EthProxy = if ($Pool_Algorithm_Norm -match $Global:RegexAlgoIsEthash) {"ethstratum2"} else {"stratum"}
        if (-not $Pool_CoinSymbol) {
            $Algo_Coins = $PoolCoins_Request.PSObject.Properties | Where-Object {$_.Value.algo -eq $Pool_Algorithm} | Foreach-Object {$_.Name}
            if ($Algo_Coins) {
                $Pool_CoinSymbolMax = Get-EthDAGSizeMax -CoinSymbols $Algo_Coins -Algorithm $Pool_Algorithm_Norm
                if ($Pool_CoinSymbolMax.CoinSymbol -and $Pool_Algorithm -in @("ethash","kawpow")) {
                    $Pool_Algorithm_Norm = Get-Algorithm $Pool_Algorithm -CoinSymbol $Pool_CoinSymbolMax.CoinSymbol
                }
            }
        }
    }

    $Pool_Factor = [double]$Pool_Request.$_.mbtc_mh_factor
    if ($Pool_Factor -le 0) {
        Write-Log -Level Info "$($Name): Unable to determine divisor for algorithm $Pool_Algorithm. "
        return
    }

    $Pool_TSL = ($PoolCoins_Request.PSObject.Properties.Value | Where-Object algo -eq $Pool_Algorithm | Measure-Object timesincelast_shared -Minimum).Minimum
    $Pool_BLK = ($PoolCoins_Request.PSObject.Properties.Value | Where-Object algo -eq $Pool_Algorithm | Measure-Object "24h_blocks_shared" -Maximum).Maximum
    $Pool_Diff = ($PoolCoins_Request.PSObject.Properties.Value | Where-Object algo -eq $Pool_Algorithm | Measure-Object -Average difficulty).Average

    if (-not $InfoOnly) {
        $NewStat = $false
        $Pool_DataWindow = if (-not (Test-Path "Stats\Pools\$($Name)_$($Pool_Algorithm_Norm)_Profit.txt")) {$NewStat = $true;"actual_last24h_shared"} else {$DataWindow}
        $Pool_Price = Get-YiiMPValue $Pool_Request.$_ -DataWindow $Pool_DataWindow -Factor $Pool_Factor -ActualLast24h "actual_last24h_shared"
        $Stat = Set-Stat -Name "$($Name)_$($Pool_Algorithm_Norm)_Profit" -Value $Pool_Price -Duration $(if ($NewStat) {New-TimeSpan -Days 1} else {$StatSpan}) -ChangeDetection $(-not $NewStat) -Actual24h $($Pool_Request.$_.actual_last24h_shared/1000) -Estimate24h $($Pool_Request.$_.estimate_last24h) -HashRate $Pool_Request.$_.hashrate_shared -BlockRate $Pool_BLK -Difficulty $Pool_Diff -Quiet
        if (-not $Stat.HashRate_Live -and -not $AllowZero) {return}
    }

    foreach($Pool_SSL in ($false,$true)) {
        if ($Pool_SSL) {
            if (-not $Pool_Request.$_.tls_port) {continue}
            $Pool_Port_SSL = [int]$Pool_Request.$_.tls_port
            $Pool_Protocol = "stratum+ssl"
        } else {
            if ($Pool_Algorithm_Norm -match "^Ethash") {continue}
            $Pool_Port_SSL = [int]$Pool_Request.$_.port
            $Pool_Protocol = "stratum+tcp"
        }
        foreach($Pool_Region in $Pool_Regions) {
            foreach($Pool_Currency in $Pool_Currencies) {
                $Pool_Params = if ($Params.$Pool_Currency) {",$($Params.$Pool_Currency)"}
                $Pool_CurrencySymbol = if ($InfoOnly) {$Pool_Currency} else {$Pool_Currency -replace "-(BEP|TRC)20"}
                [PSCustomObject]@{
                    Algorithm          = $Pool_Algorithm_Norm
                    Algorithm0         = $Pool_Algorithm_Norm
                    CoinName           = $Pool_CoinName
                    CoinSymbol         = $Pool_CoinSymbol
                    Currency           = $Pool_CurrencySymbol
                    Price              = $Stat.$StatAverage #instead of .Live
                    StablePrice        = $Stat.$StatAverageStable
                    MarginOfError      = $Stat.Week_Fluctuation
                    Protocol           = $Pool_Protocol
                    Host               = if ($Pool_Region -eq "us") {$Pool_Host} else {"$($Pool_Algorithm).$($Pool_Region).mine.zergpool.com"}
                    Port               = $Pool_Port_SSL
                    User               = $Wallets.$Pool_Currency
                    Pass               = "c=$($Pool_Currency),ID={workername:$Worker}{diff:,sd=`$difficulty}$Pool_Params"
                    Region             = $Pool_RegionsTable.$Pool_Region
                    SSL                = $Pool_SSL
                    SSLSelfSigned      = $Pool_SSL
                    Updated            = $Stat.Updated
                    PoolFee            = $Pool_PoolFee
                    DataWindow         = $DataWindow
                    Workers            = $Pool_Request.$_.workers_shared
                    Hashrate           = $Stat.HashRate_Live
                    BLK                = $Stat.BlockRate_Average
                    TSL                = $Pool_TSL
                    EthMode            = $Pool_EthProxy
                    CoinSymbolMax      = $Pool_CoinSymbolMax.CoinSymbol
                    DagSizeMax         = $Pool_CoinSymbolMax.DagSize
                    ErrorRatio         = $Stat.ErrorRatio
                    Name               = $Name
                    Penalty            = 0
                    PenaltyFactor      = 1
                    Disabled           = $false
                    HasMinerExclusions = $false
                    Price_0            = 0.0
                    Price_Bias         = 0.0
                    Price_Unbias       = 0.0
                    Wallet             = $Wallets.$Pool_Currency
                    Worker             = "{workername:$Worker}"
                    Email              = $Email
                }
            }
        }
    }
}
