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
    [String]$StatAverageStable = "Week"
)

$Name = Get-Item $MyInvocation.MyCommand.Path | Select-Object -ExpandProperty BaseName

$Pools_Request           = [PSCustomObject]@{}
$PoolsCurrencies_Request = [PSCustomObject]@{}
try {
    $Pools_Request = Invoke-RestMethodAsync "https://pool.rplant.xyz/api/dash" -tag $Name -timeout 30 -cycletime 120
    $PoolsCurrencies_Request = Invoke-RestMethodAsync "https://pool.rplant.xyz/api/currencies" -tag $Name -timeout 15 -cycletime 120 -delay 250
}
catch {
    if ($Error.Count){$Error.RemoveAt(0)}
    Write-Log -Level Warn "Pool API ($Name) has failed."
    return
}

[hashtable]$Pool_RegionsTable = @{}

$Pool_Regions = @("eu","asia","na")
$Pool_Regions | Foreach-Object {$Pool_RegionsTable.$_ = Get-Region $_}

$Pools_Request.tbs.PSObject.Properties.Value | Where-Object {(($Wallets."$($_.symbol)" -and $_.Symbol -ne "SKY") -or ($Wallets.SKYDOGE -and $_.Symbol -eq "SKY")) -or $InfoOnly} | ForEach-Object {
    $Pool_Currency       = $_.symbol
    
    $Pool_CurrencyXlat = if ($Pool_Currency -eq "SKY") {"SKYDOGE"} else {$Pool_Currency}
    
    $Pool_Coin           = Get-Coin $Pool_CurrencyXlat -Algorithm $_.algo
    
    if ($Pool_Coin) {
        $Pool_Algorithm_Norm = $Pool_Coin.Algo
        $Pool_CoinName       = $Pool_Coin.Name
    } else {
        $Pool_Algorithm_Norm = Get-Algorithm $_.algo
        $Pool_CoinName       = (Get-Culture).TextInfo.ToTitleCase($_.info.coin)
    }

    $Pool_Fee            = if ($PoolsCurrencies_Request.$Pool_Currency.fee -ne $null) {$PoolsCurrencies_Request.$Pool_Currency.fee} else {1.0}
    if ($Pool_Fee -is [string]) { $Pool_Fee = [double]($Pool_Fee -replace "[^\.,0-9]") }
    $Pool_User           = $Wallets.$Pool_CurrencyXlat
    $Pool_EthProxy       = if ($Pool_Algorithm_Norm -match $Global:RegexAlgoHasEthproxy) {"minerproxy"} elseif ($Pool_Algorithm_Norm -match $Global:RegexAlgoIsProgPow) {"stratum"} else {$null}

    $Pool_Stratum        = if ($_.info.links.stratums) {"randomx"} else {"stratum-%region%"}

    if (-not $InfoOnly) {
        $reward = if ($PoolsCurrencies_Request.$Pool_Currency.hashrate) {$PoolsCurrencies_Request.$Pool_Currency."24h_blocks" * $PoolsCurrencies_Request.$Pool_Currency.reward / $PoolsCurrencies_Request.$Pool_Currency.hashrate} else {0}
        $btcPrice = if ($Global:Rates."$($Pool_CurrencyXlat)") {1/[double]$Global:Rates."$($Pool_CurrencyXlat)"} elseif ($Global:Rates.USD -and $_.marketStats.usd) {[double]$_.marketStats.usd/[double]$Global:Rates.USD} else {0}
        $Pool_Profit = $reward * $btcPrice
        $Stat = Set-Stat -Name "$($Name)_$($Pool_CurrencyXlat)_Profit" -Value $Pool_Profit -Duration $StatSpan -ChangeDetection $false -HashRate ([int64]$PoolsCurrencies_Request.$Pool_Currency.hashrate) -BlockRate ([double]$PoolsCurrencies_Request.$Pool_Currency."24h_blocks") -Quiet
        if (-not $Stat.HashRate_Live -and -not $AllowZero) {return}
    }

    $Pool_Ports = $_.info.ports.PSObject.Properties | Group-Object {$_.Value.tls}

    foreach ($Pool_Region in $Pool_Regions) {
        if ($Pool_Stratum -ne "randomx" -or $Pool_Region -in $_.info.links.stratums) {
            foreach ($SSL in @($false,$true)) {
                if ($Pool_Port = (($Pool_Ports | Where Name -eq $SSL).Group | Sort-Object {[int64]$_.Value.diff} | Select-Object -First 1).Name) {
                    [PSCustomObject]@{
                        Algorithm     = $Pool_Algorithm_Norm
                        Algorithm0    = $Pool_Algorithm_Norm
                        CoinName      = $Pool_CoinName
                        CoinSymbol    = $Pool_CurrencyXlat
                        Currency      = $Pool_CurrencyXlat
                        Price         = $Stat.$StatAverage #instead of .Live
                        StablePrice   = $Stat.$StatAverageStable
                        MarginOfError = $Stat.Week_Fluctuation
                        Protocol      = "stratum+$(if ($SSL) {"ssl"} else {"tcp"})"
                        Host          = "$($Pool_Stratum -replace "%region%",$Pool_Region).rplant.xyz"
                        Port          = $Pool_Port
                        User          = "$($Pool_User).{workername:$Worker}"
                        Pass          = "x"
                        Region        = $Pool_RegionsTable.$Pool_Region
                        SSL           = $SSL
                        Updated       = (Get-Date).ToUniversalTime()
                        PoolFee       = $Pool_Fee
                        Workers       = [int]$PoolsCurrencies_Request.$Pool_Currency.workers
                        Hashrate      = $Stat.HashRate_Live
                        TSL           = [int]$PoolsCurrencies_Request.$Pool_Currency.timesincelast
                        BLK           = $Stat.BlockRate_Average
                        EthMode       = $Pool_EthProxy
                        Name          = $Name
                        Penalty       = 0
                        PenaltyFactor = 1
                        Disabled      = $false
                        HasMinerExclusions = $false
                        Price_0       = 0.0
                        Price_Bias    = 0.0
                        Price_Unbias  = 0.0
                        Wallet        = $Pool_User
                        Worker        = "{workername:$Worker}"
                        Email         = $Email
                    }
                }
            }
        }
    }
}
