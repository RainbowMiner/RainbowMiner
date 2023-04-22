using module ..\Modules\Include.psm1

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
    $Pool_Request = Invoke-RestMethodAsync "https://zergpool.com/api/status" -retry 3 -retrywait 1000 -tag $Name -cycletime 120
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
    $PoolCoins_Request = Invoke-RestMethodAsync "https://zergpool.com/api/currencies" -delay 1000 -tag $Name -cycletime 120 -timeout 20
}
catch {
    if ($Error.Count){$Error.RemoveAt(0)}
    Write-Log -Level Warn "Pool currencies API ($Name) has failed. "
}

if ($DataWindow -eq "actual_last24h") {$DataWindow = "actual_last24h_solo"}

[hashtable]$Pool_Algorithms = @{}
[hashtable]$Pool_Coins = @{}
[hashtable]$Pool_RegionsTable = @{}

$Pool_Fee = 0.5

$Pool_Regions = @("us")
$Pool_Regions | Foreach-Object {$Pool_RegionsTable.$_ = Get-Region $_}

$Pool_Currencies = @("BTC", "DASH", "LTC","TRX","USDT","BNB") + @($Wallets.PSObject.Properties.Name | Select-Object) + @($PoolCoins_Request | Get-Member -MemberType NoteProperty -ErrorAction Ignore | Select-Object -ExpandProperty Name | Foreach-Object {if ($PoolCoins_Request.$_.symbol -eq $null){$_} else {$PoolCoins_Request.$_.symbol}}) | Select-Object -Unique | Where-Object {$Wallets.$_ -or $InfoOnly}
if ($PoolCoins_Request) {
    $PoolCoins_Algorithms = @($Pool_Request.PSObject.Properties.Value | Where-Object coins -eq 1 | Select-Object -ExpandProperty name -Unique)
    if ($PoolCoins_Algorithms.Count) {foreach($p in $PoolCoins_Request.PSObject.Properties.Name) {if ($PoolCoins_Algorithms -contains $PoolCoins_Request.$p.algo) {$Pool_Coins[$PoolCoins_Request.$p.algo] = [hashtable]@{Name = $PoolCoins_Request.$p.name; Symbol = $p -replace '-.+$'}}}}
}

if (-not $InfoOnly) {
    $USDT_Token = if ($Pool_Currencies -contains "USDT") {
        if ($Wallets.USDT -match "^0x") {"USDT"}
        elseif ($Wallets.USDT -clike "T*") {"USDT-TRC20"}
        else {
            Write-Log -Level Warn "Pool $($Name): wrong wallet address format for USDT. Please use either ERC20 0x... or TRC20 T... format"
            $Pool_Currencies = $Pool_Currencies | Where-Object {$_ -ne "USDT"}
        }
    }
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
    $Pool_PoolFee    = [Math]::Min($Pool_Fee,[Double]$Pool_Request.$_.fees)

    if ($Pool_CoinName -and -not $Pool_CoinSymbol) {$Pool_CoinSymbol = Get-CoinSymbol $Pool_CoinName}

    if ($Pool_Algorithm -eq "ethash" -and $Pool_CoinSymbol) {
        $Pool_Algorithm_Norm = Get-Algorithm $Pool_Algorithm -CoinSymbol $Pool_CoinSymbol
    } else {
        if ($Pool_Algorithm -eq "cryptonight_fast") {$Pool_Algorithm = "cryptonight_fast2"} #temp. fix since MSR is mined with CnFast2
        if (-not $Pool_Algorithms.ContainsKey($Pool_Algorithm)) {$Pool_Algorithms[$Pool_Algorithm] = Get-Algorithm $Pool_Algorithm}
        $Pool_Algorithm_Norm = $Pool_Algorithms[$Pool_Algorithm]
    }

    $Pool_EthProxy = if ($Pool_Algorithm_Norm -match $Global:RegexAlgoHasDAGSize) {if ($Pool_Algorithm_Norm -match $Global:RegexAlgoIsEthash) {"ethstratum2"} else {"stratum"}} else {$null}

    $Pool_Factor = [double]$Pool_Request.$_.mbtc_mh_factor
    if ($Pool_Factor -le 0) {
        Write-Log -Level Info "$($Name): Unable to determine divisor for algorithm $Pool_Algorithm. "
        return
    }

    $Pool_Diff = ($PoolCoins_Request.PSObject.Properties.Value | Where-Object algo -eq $Pool_Algorithm | Foreach-Object {
        if ([double]$_.network_hashrate -gt [double]$_.hashrate -or [int]$_."24h_blocks" -eq 0) {
            [double]$_.network_hashrate * $_.blocktime / [Math]::Pow(2,32)
        } else {
            [double]$_.hashrate * 86400 / $_."24h_blocks" / [Math]::Pow(2,32)
        }
    } | Measure-Object -Average).Average

    if (-not $InfoOnly) {
        $NewStat = $false
        $Pool_DataWindow = if (-not (Test-Path "Stats\Pools\$($Name)_$($Pool_Algorithm_Norm)_Profit.txt")) {$NewStat = $true;"actual_last24h_solo"} else {$DataWindow}
        $Pool_Price = Get-YiiMPValue $Pool_Request.$_ -DataWindow $Pool_DataWindow -Factor $Pool_Factor -ActualLast24h "actual_last24h_solo"
        $Stat = Set-Stat -Name "$($Name)_$($Pool_Algorithm_Norm)_Profit" -Value $Pool_Price -Duration $(if ($NewStat) {New-TimeSpan -Days 1} else {$StatSpan}) -ChangeDetection $false -Actual24h $($Pool_Request.$_.actual_last24h_solo/1000) -Estimate24h $($Pool_Request.$_.estimate_last24h) -Difficulty $Pool_Diff -Quiet
    }


    foreach($Pool_SSL in ($false,$true)) {
        if ($Pool_SSL) {
            if (-not $Pool_Request.$_.tls_port) {continue}
            $Pool_Port_SSL = [int]$Pool_Request.$_.tls_port
            $Pool_Protocol = "stratum+ssl"
        } else {
            $Pool_Port_SSL = [int]$Pool_Request.$_.port
            $Pool_Protocol = "stratum+tcp"
        }
        foreach($Pool_Region in $Pool_Regions) {
            foreach($Pool_Currency in $Pool_Currencies) {
                $Pool_Params = if ($Params.$Pool_Currency) {",$($Params.$Pool_Currency)"}
                [PSCustomObject]@{
                    Algorithm          = $Pool_Algorithm_Norm
                    Algorithm0         = $Pool_Algorithm_Norm
                    CoinName           = $Pool_CoinName
                    CoinSymbol         = $Pool_CoinSymbol
                    Currency           = $Pool_Currency
                    Price              = $Stat.$StatAverage #instead of .Live
                    StablePrice        = $Stat.$StatAverageStable
                    MarginOfError      = $Stat.Week_Fluctuation
                    Protocol           = $Pool_Protocol
                    Host               = if ($Pool_Region -eq "us") {$Pool_Host} else {"$($Pool_Algorithm).$($Pool_Region).mine.zergpool.com"}
                    Port               = $Pool_Port_SSL
                    User               = $Wallets.$Pool_Currency
                    Pass               = "c=$(if ($Pool_Currency -eq "USDT" -and $USDT_Token) {$USDT_Token} else {$Pool_Currency}),m=solo,ID={workername:$Worker}{diff:,sd=`$difficulty}$Pool_Params"
                    Region             = $Pool_RegionsTable.$Pool_Region
                    SSL                = $Pool_SSL
                    SSLSelfSigned      = $Pool_SSL
                    Updated            = $Stat.Updated
                    PoolFee            = $Pool_PoolFee
                    DataWindow         = $DataWindow
                    Workers            = $null
                    Hashrate           = $null
                    BLK                = $null
                    TSL                = $null
                    Difficulty         = $Stat.Diff_Average
                    SoloMining         = $true
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
                    Wallet             = $Wallets.$Pool_Currency
                    Worker             = "{workername:$Worker}"
                    Email              = $Email
                }
            }
        }
    }
}
