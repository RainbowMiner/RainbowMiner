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
    [String]$StatAverageStable = "Week"
)

$Name = Get-Item $MyInvocation.MyCommand.Path | Select-Object -ExpandProperty BaseName

$Pool_Region_Default = Get-Region "eu"

$Pools_Request       = [PSCustomObject]@{}
try {
    $Pools_Request = Invoke-RestMethodAsync "https://hashcity.org/back/stats" -tag $Name -timeout 15 -cycletime 120
}
catch {
    if ($Error.Count){$Error.RemoveAt(0)}
    Write-Log -Level Warn "Pool API ($Name) for $Pool_Currency has failed. "
    return
}

#(convertfrom-json '{"btc":"btc.hashcity.org:3333",
#"eth":"eth.hashcity.org:7777",
#"ltc":"ltc.hashcity.org:3000",
#"bch":"bch.hashcity.org:2222",
#"bsv":"bsv.hashcity.org:5000",
#"xmr":"xmr.hashcity.org:4444",
#"dash":"dash.hashcity.org:4000",
#"zec":"zec.hashcity.org:3030",
#"etc":"etc.hashcity.org:8888",
#"rvn":"rvn.hashcity.org:8080",
#"btg":"btg.hashcity.org:4040",
#"bcn":"bcn.hashcity.org:5454",
#"moac":"moac.hashcity.org:5555",
#"clo":"clo.hashcity.org:6666",
#"sumo":"sumo.hashcity.org:4555",
#"pirl":"pirl.hashcity.org:9999",
#"dbix":"dbix.hashcity.org:4646",
#"lthn":"lthn.hashcity.org:4545",
#"exp":"exp.hashcity.org:9999",
#"xmrx":""}').PSObject.Properties | Sort-Object Name | Foreach-Object {
#    "[PSCustomObject]@{symbol = `"$($_.Name.ToUpper())`";$(if ($_.Name.Length -eq 3) {" "}) port = $($_.Value -split ':' | Select-Object -Last 1); fee = $(if ($_.Name -in @("bch","btc","ltc","dash")) {0} else {1}).0; rpc = `"$($_.Value -split '\.' | Select-Object -First 1)`"}"
#}

$Pools_Data = @(
    [PSCustomObject]@{symbol = "BCH";  port = 2222; fee = 0.0; rpc = "bch"}
    [PSCustomObject]@{symbol = "BCN";  port = 5454; fee = 1.0; rpc = "bcn"}
    [PSCustomObject]@{symbol = "BSV";  port = 5000; fee = 1.0; rpc = "bsv"}
    [PSCustomObject]@{symbol = "BTC";  port = 3333; fee = 0.0; rpc = "btc"}
    [PSCustomObject]@{symbol = "BTG";  port = 4040; fee = 1.0; rpc = "btg"}
    [PSCustomObject]@{symbol = "CLO";  port = 6666; fee = 1.0; rpc = "clo"}
    [PSCustomObject]@{symbol = "DASH"; port = 4000; fee = 0.0; rpc = "dash"}
    [PSCustomObject]@{symbol = "DBIX"; port = 4646; fee = 1.0; rpc = "dbix"}
    [PSCustomObject]@{symbol = "ETC";  port = 8888; fee = 1.0; rpc = "etc"}
    [PSCustomObject]@{symbol = "ETH";  port = 7777; fee = 1.0; rpc = "eth"}
    [PSCustomObject]@{symbol = "EXP";  port = 9999; fee = 1.0; rpc = "exp"}
    [PSCustomObject]@{symbol = "LTC";  port = 3000; fee = 0.0; rpc = "ltc"}
    [PSCustomObject]@{symbol = "LTHN"; port = 4545; fee = 1.0; rpc = "lthn"}
    [PSCustomObject]@{symbol = "MOAC"; port = 5555; fee = 1.0; rpc = "moac"}
    [PSCustomObject]@{symbol = "PIRL"; port = 9999; fee = 1.0; rpc = "pirl"}
    [PSCustomObject]@{symbol = "RVN";  port = 8080; fee = 1.0; rpc = "rvn"}
    [PSCustomObject]@{symbol = "SUMO"; port = 4555; fee = 1.0; rpc = "sumo"}
    [PSCustomObject]@{symbol = "XMR";  port = 4444; fee = 1.0; rpc = "xmr"}
    [PSCustomObject]@{symbol = "ZEC";  port = 3030; fee = 1.0; rpc = "zec"}
)

$Pools_Data | Where-Object {[double]$Pools_Request.pools."$($_.symbol)".speed_pool -gt 0.0 -and ($Wallets."$($_.symbol)" -or $InfoOnly)} | ForEach-Object {
    $Pool_Coin      = Get-Coin $_.symbol
    $Pool_Currency  = $_.symbol
    $Pool_Fee       = $_.fee
    $Pool_Port      = $_.port
    $Pool_RpcPath   = $_.rpc

    $Pool_Algorithm_Norm = Get-Algorithm $Pool_Coin.algo

    $Pool_EthProxy = if ($Pool_Algorithm_Norm -match $Global:RegexAlgoHasEthproxy) {"ethproxy"} elseif ($Pool_Algorithm_Norm -eq "KawPOW") {"stratum"} else {$null}

    $Pool_Hashrate = ConvertFrom-Hash "$($Pools_Request.pools."$($_.symbol)".speed_pool)$($Pools_Request.pools."$($_.symbol)".speed_pool_type)"

    if (-not $InfoOnly) {
        $Stat = Set-Stat -Name "$($Name)_$($Pool_Currency)_Profit" -Value 0 -Duration $StatSpan -ChangeDetection $false -HashRate $Pool_Hashrate -Quiet
        if (-not $Stat.HashRate_Live -and -not $AllowZero) {return}
    }
    
    [PSCustomObject]@{
        Algorithm     = $Pool_Algorithm_Norm
		Algorithm0    = $Pool_Algorithm_Norm
        CoinName      = $_.name
        CoinSymbol    = $Pool_Currency
        Currency      = $Pool_Currency
        Price         = $Stat.$StatAverage #instead of .Live
        StablePrice   = $Stat.$StatAverageStable
        MarginOfError = $Stat.Week_Fluctuation
        Protocol      = "stratum+tcp"
        Host          = "$($Pool_RpcPath).hashcity.org"
        Port          = $Pool_Port
        User          = "$($Wallets."$($_.symbol)").{workername:$Worker}"
        Pass          = "x"
        Region        = $Pool_Region_Default
        SSL           = $false
        WTM           = $true
        Updated       = $Stat.Updated
        PoolFee       = $Pool_Fee
        Hashrate      = $Stat.HashRate_Live
        EthMode       = $Pool_EthProxy
        Name          = $Name
        Penalty       = 0
        PenaltyFactor = 1
        Disabled      = $false
        HasMinerExclusions = $false
        Price_Bias    = 0.0
        Price_Unbias  = 0.0
        Wallet        = $Wallets."$($_.symbol)"
        Worker        = "{workername:$Worker}"
        Email         = $Email
    }
}
