﻿using module ..\Modules\Include.psm1

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
    [String]$StatAverageStable = "Week",
    [String]$AECurrency = ""
)

$Name = Get-Item $MyInvocation.MyCommand.Path | Select-Object -ExpandProperty BaseName

$Pool_Request = [PSCustomObject]@{}
$PoolCoins_Request = [PSCustomObject]@{}

try {
    $Pool_Request = Invoke-RestMethodAsync "http://api.zergpool.com:8080/api/status" -retry 3 -retrywait 1000 -tag $Name -cycletime 120
}
catch {
    if ($Error.Count){$Error.RemoveAt(0)}
    Write-Log -Level Warn "Pool API ($Name) has failed. "
    return
}

if (($Pool_Request | Get-Member -MemberType NoteProperty -ErrorAction Ignore | Measure-Object Name).Count -le 1) {
    Write-Log -Level Warn "Pool API ($Name) returned nothing. "
    return
}

try {
    $PoolCoins_Request = Invoke-RestMethodAsync "http://api.zergpool.com:8080/api/currencies" -delay 1000 -tag $Name -cycletime 120 -timeout 20
}
catch {
    if ($Error.Count){$Error.RemoveAt(0)}
    Write-Log -Level Warn "Pool currencies API ($Name) has failed. "
}

[hashtable]$Pool_Algorithms = @{}
[hashtable]$Pool_Coins = @{}
[hashtable]$Pool_RegionsTable = @{}

$Pool_Regions = @("us")
$Pool_Regions | Foreach-Object {$Pool_RegionsTable.$_ = Get-Region $_}

$Pool_Currencies = @("BTC", "DASH", "LTC") + @($Wallets.PSObject.Properties.Name | Select-Object) + @($PoolCoins_Request | Get-Member -MemberType NoteProperty -ErrorAction Ignore | Select-Object -ExpandProperty Name | Foreach-Object {if ($PoolCoins_Request.$_.symbol -eq $null){$_} else {$PoolCoins_Request.$_.symbol}}) | Select-Object -Unique | Where-Object {$Wallets.$_ -or $InfoOnly}
if ($PoolCoins_Request) {
    $PoolCoins_Algorithms = @($Pool_Request.PSObject.Properties.Value | Where-Object coins -eq 1 | Select-Object -ExpandProperty name -Unique)
    if ($PoolCoins_Algorithms.Count) {foreach($p in $PoolCoins_Request.PSObject.Properties.Name) {if ($PoolCoins_Algorithms -contains $PoolCoins_Request.$p.algo) {$Pool_Coins[$PoolCoins_Request.$p.algo] = [hashtable]@{Name = $PoolCoins_Request.$p.name; Symbol = $p -replace '-.+$'}}}}
}

if (-not $InfoOnly -and $Pool_Currencies.Count -gt 1) {
    if ($AECurrency -eq "" -or $AECurrency -notin $Pool_Currencies) {$AECurrency = $Pool_Currencies | Select-Object -First 1}
    $Pool_Currencies = $Pool_Currencies | Where-Object {$_ -eq $AECurrency}
}

$Pool_Request | Get-Member -MemberType NoteProperty -ErrorAction Ignore | Select-Object -ExpandProperty Name | ForEach-Object {
    $Pool_Host = "$($Pool_Request.$_.name).mine.zergpool.com"
    $Pool_Port = $Pool_Request.$_.port
    $Pool_Algorithm = $Pool_Request.$_.name
    if ($Pool_Algorithm -eq "cryptonight_fast") {$Pool_Algorithm = "cryptonight_fast2"} #temp. fix since MSR is mined with CnFast2
    if (-not $Pool_Algorithms.ContainsKey($Pool_Algorithm)) {$Pool_Algorithms[$Pool_Algorithm] = Get-Algorithm $Pool_Algorithm}
    $Pool_Algorithm_Norm = $Pool_Algorithms[$Pool_Algorithm]
    $Pool_Coin = $Pool_Coins.$Pool_Algorithm.Name
    $Pool_Symbol = $Pool_Coins.$Pool_Algorithm.Symbol
    $Pool_PoolFee = [Double]$Pool_Request.$_.fees
    if ($Pool_Coin -and -not $Pool_Symbol) {$Pool_Symbol = Get-CoinSymbol $Pool_Coin}
    $Pool_EthProxy = $null

    if ($Pool_Algorithm_Norm -match $Global:RegexAlgoHasDAGSize) {
        $Pool_EthProxy   = if ($Pool_Algorithm_Norm -match $Global:RegexAlgoIsEthash) {"ethproxy"} else {"stratum"}
    }

    $Pool_Factor = [double]$Pool_Request.$_.mbtc_mh_factor
    if ($Pool_Factor -le 0) {
        Write-Log -Level Info "$($Name): Unable to determine divisor for algorithm $Pool_Algorithm. "
        return
    }

    $Pool_TSL = ($PoolCoins_Request.PSObject.Properties.Value | Where-Object algo -eq $Pool_Algorithm | Measure-Object timesincelast_solo -Minimum).Minimum
    $Pool_BLK = ($PoolCoins_Request.PSObject.Properties.Value | Where-Object algo -eq $Pool_Algorithm | Measure-Object "24h_blocks_solo" -Maximum).Maximum

    if (-not $InfoOnly) {
        $NewStat = $false; if (-not (Test-Path "Stats\Pools\$($Name)_$($Pool_Algorithm_Norm)_Profit.txt")) {$NewStat = $true; $DataWindow = "actual_last24h_solo"}
        $Pool_Price = Get-YiiMPValue $Pool_Request.$_ -DataWindow $DataWindow -Factor $Pool_Factor
        $Stat = Set-Stat -Name "$($Name)_$($Pool_Algorithm_Norm)_Profit" -Value $Pool_Price -Duration $(if ($NewStat) {New-TimeSpan -Days 1} else {$StatSpan}) -ChangeDetection $(-not $NewStat) -Actual24h $($Pool_Request.$_.actual_last24h/1000) -Estimate24h $($Pool_Request.$_.estimate_last24h) -HashRate $Pool_Request.$_.hashrate_solo -BlockRate $Pool_BLK -Quiet
        if (-not $Stat.HashRate_Live -and -not $AllowZero) {return}
    }

    foreach($Pool_Region in $Pool_Regions) {
        foreach($Pool_Currency in $Pool_Currencies) {
            $Pool_Params = if ($Params.$Pool_Currency) {",$($Params.$Pool_Currency)"}
            [PSCustomObject]@{
                Algorithm     = $Pool_Algorithm_Norm
                Algorithm0    = $Pool_Algorithm_Norm
                CoinName      = $Pool_Coin
                CoinSymbol    = $Pool_Symbol
                Currency      = $Pool_Currency
                Price         = $Stat.$StatAverage #instead of .Live
                StablePrice   = $Stat.$StatAverageStable
                MarginOfError = $Stat.Week_Fluctuation
                Protocol      = "stratum+tcp"
                Host          = if ($Pool_Region -eq "us") {$Pool_Host} else {"$Pool_Region.$Pool_Host"}
                Port          = $Pool_Port
                User          = $Wallets.$Pool_Currency
                Pass          = "ID={workername:$Worker},c=$Pool_Currency,m=solo{diff:,sd=`$difficulty}$Pool_Params"
                Region        = $Pool_RegionsTable.$Pool_Region
                SSL           = $false
                Updated       = $Stat.Updated
                PoolFee       = $Pool_PoolFee
                DataWindow    = $DataWindow
                Workers       = $Pool_Request.$_.workers_solo
                Hashrate      = $Stat.HashRate_Live
                BLK           = $Stat.BlockRate_Average
                TSL           = $Pool_TSL
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
                Wallet        = $Wallets.$Pool_Currency
                Worker        = "{workername:$Worker}"
                Email         = $Email
            }
        }
    }
}
