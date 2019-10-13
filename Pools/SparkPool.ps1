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
    [String]$StatAverage = "Minute_10"
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
    [PSCustomObject]@{id = "beam";   symbol = "BEAM";     port = 2222;  fee = 1; ssl = $true;  region = @("cn","asia","eu","us")}
    [PSCustomObject]@{id = "";       symbol = "ETH";      port = 3333;  fee = 1; ssl = $false; region = @("cn","asia","tw","kr","jp")}
    #[PSCustomObject]@{id = "ckb";    symbol = "CKB";      port = 8888;  fee = 1; ssl = $false; region = @("cn")}
    [PSCustomObject]@{id = "ckb";    symbol = "CKB_TEST"; port = 8888;  fee = 1; ssl = $false; region = @("cn","eu")}
    [PSCustomObject]@{id = "grin";   symbol = "GRIN_29";  port = 6666;  fee = 1; ssl = $false; region = @("cn","asia","eu","us")}
    [PSCustomObject]@{id = "grin";   symbol = "GRIN_31";  port = 6667;  fee = 1; ssl = $false; region = @("cn","asia","eu","us")}
)

$Pools_Data | Where-Object {$Wallets."$($_.symbol -replace "_.+$")" -or $InfoOnly} | ForEach-Object {
    $Pool_Coin = Get-Coin $_.symbol
    $Pool_Port = $_.port
    $Pool_Algorithm_Norm = Get-Algorithm $Pool_Coin.algo
    $Pool_Symbol = $_.symbol
    $Pool_Currency = $_.symbol -replace "_.+$"
    $Pool_Fee = $_.fee
    $Pool_ID = $_.id
    $Pool_Regions = $_.region
    $Pool_SSL = $_.ssl

    $Pool_Request.data | Where-Object currency -eq $Pool_Symbol | Foreach-Object {
        if (-not $InfoOnly) {
            $Pool_Rates = $Session.Rates.$Pool_Currency
            if (-not $Pool_Rates -and $_.usd -and $Session.Rates.USD) {$Pool_Rates = $Session.Rates.USD / $_.usd}
            $Stat = Set-Stat -Name "$($Name)_$($Pool_Symbol)_Profit" -Value $(if ($Pool_Rates) {$_.income / $_.incomeHashrate / $Pool_Rates} else {0}) -Duration $(if ($NewStat) {New-TimeSpan -Days 1} else {$StatSpan}) -ChangeDetection $false -HashRate $_.hashrate -BlockRate $_.blocks -Quiet
        }

        foreach ($Pool_Region in $Pool_Regions) {
            [PSCustomObject]@{
                Algorithm     = $Pool_Algorithm_Norm
                CoinName      = $Pool_Coin.Name
                CoinSymbol    = $Pool_Currency
                Currency      = $Pool_Currency
                Price         = $Stat.$StatAverage #instead of .Live
                StablePrice   = $Stat.Week
                MarginOfError = $Stat.Week_Fluctuation
                Protocol      = "stratum+$(if ($Pool_SSL) {"ssl"} else {"tcp"})"
                Host          = "$(if ($Pool_ID) {$Pool_ID})$(if ($Pool_ID -and $Pool_Region -ne "cn") {"-"})$(if ($Pool_Region -ne "cn" -or -not $Pool_ID) {$Pool_Region}).sparkpool.com"
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
                EthMode       = if ($Pool_Algorithm_Norm -match "^(Ethash|ProgPow)") {"ethproxy"} else {$null}
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
