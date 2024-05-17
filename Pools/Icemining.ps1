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

$Pool_Fee = 1

$Pool_Request = [PSCustomObject]@{}
$PoolCoins_Request = [PSCustomObject]@{}

try {
    $PoolCoins_Request = Invoke-RestMethodAsync "https://rbminer.net/api/data/icemining.json" -tag $Name -cycletime 120
}
catch {
    if ($Error.Count){$Error.RemoveAt(0)}
    Write-Log -Level Warn "Pool API ($Name) has failed. "
    return
}

if (-not ($PoolCoins_Request | Get-Member -MemberType NoteProperty -ErrorAction Ignore | Measure-Object Name).Count) {
    Write-Log -Level Warn "Pool API ($Name) returned nothing. "
    return
}

$Pools_Data = @(
    [PSCustomObject]@{symbol="CHAPA";           region = @("de","fi");                            host="%region%.chapa.hashrate.to"; port=4003; fee = 30}
    [PSCustomObject]@{symbol="GRAM";            region = @("de","fi");                            host="%region%.ton.hashrate.to";   port=4003; fee = 30}
    [PSCustomObject]@{symbol="NIM";             region = @("ca");                                 host="nimiq.icemining.ca";         port=2053; fee = 1.25; ssl = $true; solo = $true}
)

[hashtable]$Pool_RegionsTable = @{}
$Pools_Data.region | Select-Object -Unique | Foreach-Object {$Pool_RegionsTable.$_ = Get-Region $_}

$Pools_Data | Where-Object {$Pool_Currency = $_.symbol -replace "-.+$"; $PoolCoins_Request.$Pool_Currency -ne $null -and ($Wallets.$Pool_Currency -or $InfoOnly)} | ForEach-Object {
    $Pool_Coin           = Get-Coin $_.symbol

    if ($Pool_Coin) {
        $Pool_Algorithm  = $Pool_Coin.Algo
        $Pool_CoinName   = $Pool_Coin.Name
    } else {
        $Pool_Algorithm  = $PoolCoins_Request.$Pool_Currency.algo
        $Pool_CoinName   = $PoolCoins_Request.$Pool_Currency.name
    }

    $Pool_Algorithm_Norm = Get-Algorithm $Pool_Algorithm

    if (-not $InfoOnly) {
        $Stat = Set-Stat -Name "$($Name)_$($_.symbol)_Profit" -Value 0 -Duration $StatSpan -ChangeDetection $false -HashRate $PoolCoins_Request.$Pool_Currency.hashrate -BlockRate $PoolCoins_Request.$Pool_Currency.blocks24h -Difficulty $PoolCoins_Request.$Pool_Currency.diff -Quiet
        if (-not $Stat.HashRate_Live -and -not $AllowZero) {return}
    }

    $Pool_User     = "$($Wallets.$Pool_Currency -replace "\s")$(if ($Pool_Algorithm_Norm -ne "SHA256ton") {".{workername:$Worker}"})"
    $Pool_Protocol = "stratum+$(if ($_.ssl) {"ssl"} else {"tcp"})"
    $Pool_Fee      = if ($PoolCoins_Request.$Pool_Currency.fee -ne $null) {[double]$PoolCoins_Request.$Pool_Currency.fee} else {$_.fee}
    $Pool_Pass     = "$(if ($Params.$Pool_Currency) {$Params.$Pool_Currency} else {"x"})"

    foreach($Pool_Region in $_.region) {
        [PSCustomObject]@{
            Algorithm     = $Pool_Algorithm_Norm
			Algorithm0    = $Pool_Algorithm_Norm
            CoinName      = $Pool_CoinName
            CoinSymbol    = $Pool_Currency
            Currency      = $Pool_Currency
            Price         = 0
            StablePrice   = 0
            MarginOfError = 0
            Protocol      = $Pool_Protocol
            Host          = "$($_.host -replace "%region%",$Pool_Region)"
            Port          = $_.port
            User          = $Pool_User
            Pass          = $Pool_Pass
            Region        = $Pool_RegionsTable.$Pool_Region
            SSL           = if ($_.ssl) {$true} else {$false}
            Updated       = $Stat.Updated
            PoolFee       = $Pool_Fee
            Workers       = $PoolCoins_Request.$Pool_Currency.workers
            Hashrate      = $Stat.HashRate_Live
            BLK           = $Stat.BlockRate_Average
            TSL           = $PoolCoins_Request.$Pool_Currency.timesincelast
            Difficulty    = $Stat.Diff_Average
            SoloMining    = if ($_.solo) {$true} else {$false}
            WTM           = $true
            EthMode       = if ($Pool_Algorithm_Norm -eq "SHA256ton") {"icemining"} else {$null}
            Name          = $Name
            Penalty       = 0
            PenaltyFactor = 1
            Disabled      = $false
            HasMinerExclusions = $false
            Price_0       = 0.0
            Price_Bias    = 0.0
            Price_Unbias  = 0.0
            Wallet        = $Wallets.$Pool_Currency
            Worker        = "{workername:$Worker}"
            Email         = $Email
        }
    }
}
