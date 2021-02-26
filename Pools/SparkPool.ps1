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

$Pool_Region_Default = "asia"

[hashtable]$Pool_RegionsTable = @{}
@("eu","us","asia","cn","tw","kr","jp") | Foreach-Object {$Pool_RegionsTable.$_ = Get-Region $_}

$Pool_RegionsTable["asia"] = Get-Region "sea"

$Pool_Request = [PSCustomObject]@{}

try {
    $Pool_Request = Invoke-RestMethodAsync "https://www.sparkpool.com/v1/pool/stats?pool=SPARK_POOL_CN" -tag $Name -retry 5 -retrywait 250 -cycletime 120
    if ($Pool_Request.code -ne 200) {throw}
}
catch {
    if ($Error.Count){$Error.RemoveAt(0)}
    Write-Log -Level Warn "Pool API ($Name) has failed. "
    return
}

$Pools_Data = @(
    [PSCustomObject]@{id = "beam";   symbol = "BEAM";    port = 2222;  fee = 1; ssl = $true;  region = @("cn","asia","eu","us"); noid = @()}
    [PSCustomObject]@{id = "eth";    symbol = "ETH";     port = 3333;  fee = 1; ssl = $false; region = @("cn","asia","eu","us","kr","jp"); noid = @("cn","asia","kr","jp")}
    [PSCustomObject]@{id = "ckb";    symbol = "CKB";     port = 8888;  fee = 1; ssl = $false; region = @("cn","asia","eu"); noid = @()}
)

$Pools_Data | Where-Object {$Pool_Currency = $_.symbol -replace "_.+$";$Wallets.$Pool_Currency -or $InfoOnly} | ForEach-Object {
    $Pool_Coin = Get-Coin $_.symbol
    $Pool_Port = $_.port
    $Pool_Algorithm_Norm = Get-Algorithm $Pool_Coin.algo
    $Pool_Symbol = $_.symbol
    $Pool_Fee = $_.fee
    $Pool_ID = $_.id
    $Pool_Regions = $_.region
    $Pool_RegionsWithNoID = $_.noid
    $Pool_SSL = $_.ssl
    $Pool_EthProxy = if ($Pool_Algorithm_Norm -match $Global:RegexAlgoHasEthproxy) {"ethproxy"} elseif ($Pool_Algorithm_Norm -eq "KawPOW") {"stratum"} else {$null}

    $Pool_Request.data | Where-Object currency -eq $Pool_Symbol | Foreach-Object {
        if (-not $InfoOnly) {
            $Pool_Rates = $Global:Rates.$Pool_Currency
            if (-not $Pool_Rates -and $_.usd -and $Global:Rates.USD) {$Pool_Rates = $Global:Rates.USD / $_.usd}
            $NewStat = -not (Test-Path "Stats\Pools\$($Name)_$($Pool_Symbol)_Profit.txt")
            $Income = if ($NewStat -and $_.meanIncome24h) {$_.meanIncome24h} else {$_.income}
            $Stat = Set-Stat -Name "$($Name)_$($Pool_Symbol)_Profit" -Value $(if ($Pool_Rates) {$Income / $_.incomeHashrate / $Pool_Rates} else {0}) -Duration $(if ($NewStat) {New-TimeSpan -Days 1} else {$StatSpan}) -ChangeDetection $false -HashRate $_.hashrate -BlockRate $_.blocks -Quiet
            if (-not $Stat.HashRate_Live -and -not $AllowZero) {return}
        }

        foreach ($Pool_Region in $Pool_Regions) {

            $Pool_RegionWithID = $Pool_Region -notin $Pool_RegionsWithNoID

            [PSCustomObject]@{
                Algorithm     = $Pool_Algorithm_Norm
                Algorithm0    = $Pool_Algorithm_Norm
                CoinName      = $Pool_Coin.Name
                CoinSymbol    = $Pool_Currency
                Currency      = $Pool_Currency
                Price         = $Stat.$StatAverage #instead of .Live
                StablePrice   = $Stat.$StatAverageStable
                MarginOfError = $Stat.Week_Fluctuation
                Protocol      = "stratum+$(if ($Pool_SSL) {"ssl"} else {"tcp"})"
                Host          = "$(if ($Pool_RegionWithID) {$Pool_ID})$(if ($Pool_RegionWithID -and $Pool_Region -ne "cn") {"-"})$(if ($Pool_Region -ne "cn" -or -not $Pool_RegionWithID) {$Pool_Region}).sparkpool.com"
                Port          = $Pool_Port
                User          = "$($Wallets.$Pool_Currency)$(if ($Pool_Currency -match "GRIN") {"/"} else {"."}){workername:$Worker}"
                Pass          = "x"
                Region        = $Pool_RegionsTable.$Pool_Region
                SSL           = $Pool_SSL
                Updated       = $Stat.Updated
                PoolFee       = $Pool_Fee
                DataWindow    = $DataWindow
                Workers       = $_.workers
                Hashrate      = $Stat.HashRate_Live
                #TSL           = $Pool_TSL
                BLK           = $Stat.BlockRate_Average
                EthMode       = $Pool_EthProxy
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
