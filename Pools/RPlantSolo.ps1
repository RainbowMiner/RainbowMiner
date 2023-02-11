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

$Pool_Regions = @("ru","eu","asia","na")
$Pool_Regions | Foreach-Object {$Pool_RegionsTable.$_ = Get-Region $_}

$Pools_Request.tbs.PSObject.Properties.Value | Where-Object {$_.info.solo -and $Wallets."$($_.symbol)" -or $InfoOnly} | ForEach-Object {
    $Pool_Currency       = $_.symbol
    
    $Pool_Coin           = Get-Coin $Pool_Currency -Algorithm $_.algo
    
    if ($Pool_Coin) {
        $Pool_Algorithm_Norm = $Pool_Coin.Algo
        $Pool_CoinName       = $Pool_Coin.Name
    } else {
        $Pool_Algorithm_Norm = Get-Algorithm $_.algo
        $Pool_CoinName       = (Get-Culture).TextInfo.ToTitleCase($_.info.coin)
    }

    $Pool_Fee            = if ($PoolCurrencies_Request.$Pool_Currency.fee_solo -ne $null) {[double]$PoolCurrencies_Request.$Pool_Currency.fee_solo} else {1.0}
    $Pool_User           = $Wallets.$Pool_Currency
    $Pool_EthProxy       = if ($Pool_Algorithm_Norm -match $Global:RegexAlgoHasEthproxy) {"minerproxy"} elseif ($Pool_Algorithm_Norm -match $Global:RegexAlgoIsProgPow) {"stratum"} else {$null}

    $Pool_Stratum        = if ($_.info.links.stratums) {"randomx"} else {"stratum-%region%"}

    $Pool_Profit         = 0

    if (-not $InfoOnly) {
        $Pool_Profit = if ($_.marketStats.btc -and $_.d) {86400 / [Math]::Pow(2,32) / $_.d * $_.r * $_.marketStats.btc} else {0}
        $Stat = Set-Stat -Name "$($Name)_$($Pool_Currency)_Profit" -Value $Pool_Profit -Duration $StatSpan -ChangeDetection $false -Difficulty $_.d -Quiet
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
                        CoinSymbol    = $Pool_Currency
                        Currency      = $Pool_Currency
                        Price         = if ($Pool_Profit) {$Stat.$StatAverage} else {0}
                        StablePrice   = if ($Pool_Profit) {$Stat.$StatAverageStable} else {0}
                        MarginOfError = if ($Pool_Profit) {$Stat.Week_Fluctuation} else {0}
                        Protocol      = "stratum+$(if ($SSL) {"ssl"} else {"tcp"})"
                        Host          = "$($Pool_Stratum -replace "%region%",$Pool_Region).rplant.xyz"
                        Port          = $Pool_Port
                        User          = "$($Pool_User).{workername:$Worker}"
                        Pass          = "m=solo"
                        Region        = $Pool_RegionsTable.$Pool_Region
                        SSL           = $SSL
                        Updated       = (Get-Date).ToUniversalTime()
                        PoolFee       = $Pool_Fee
                        Workers       = $null
                        Hashrate      = $null
                        TSL           = $null
                        BLK           = $null
                        Difficulty    = $Stat.Diff_Average
                        SoloMining    = $true
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
                        WTM           = $Pool_Profit -eq 0
                    }
                }
            }
        }
    }
}
