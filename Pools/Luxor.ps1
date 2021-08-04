﻿using module ..\Modules\Include.psm1

param(
    [PSCustomObject]$Wallets,
    [PSCustomObject]$Params,
    [alias("WorkerName")]
    [String]$Worker,
    [alias("UserName")]
    [String]$User,
    [TimeSpan]$StatSpan,
    [String]$DataWindow = "estimate_current",
    [Bool]$InfoOnly = $false,
    [Bool]$AllowZero = $false,
    [String]$StatAverage = "Minute_10",
    [String]$StatAverageStable = "Week"
)

$Name = Get-Item $MyInvocation.MyCommand.Path | Select-Object -ExpandProperty BaseName

[hashtable]$Pool_RegionsTable = @{}

$Pool_Regions = @("us")
$Pool_Regions | Foreach-Object {$Pool_RegionsTable.$_ = Get-Region $_}

$Pools_Data = @(
    [PSCustomObject]@{symbol = "ARRR";    port = 700; fee = 3.0; rpc = "arrr"}
)

$Pools_Data | Where-Object {$Pool_Currency = $_.symbol -replace "(29|31)$";$User -or $Wallets.$Pool_Currency -or $InfoOnly} | ForEach-Object {
    $Pool_Coin      = Get-Coin $_.symbol
    $Pool_Fee       = $_.fee
    $Pool_Port      = $_.port
    $Pool_RpcPath   = $_.rpc

    $Pool_Algorithm_Norm = Get-Algorithm $Pool_Coin.algo

    $Pool_Request        = [PSCustomObject]@{}
    $Pool_Request_Blocks = [PSCustomObject]@{}

    $ok = $true
    if (-not $InfoOnly) {
        try {
            $Pool_Request = Invoke-RestMethodAsync "https://mining.luxor.tech/api/$($Pool_Currency)/stats" -tag $Name -timeout 15 -cycletime 120
            $Pool_Request_Blocks = Invoke-RestMethodAsync "https://mining.luxor.tech/api/$($Pool_Currency)/blocks" -tag $Name -timeout 15 -cycletime 120
        }
        catch {
            if ($Error.Count){$Error.RemoveAt(0)}
            Write-Log -Level Warn "Pool API ($Name) for $Pool_Currency has failed. "
            $ok = $false
        }
        if ($Pool_Request.fee -ne $null) {$Pool_Fee = $Pool_Request.fee}
    }

    if ($ok -and -not $InfoOnly) {
        $timestamp      = Get-UnixTimestamp
        $timestamp24h   = $timestamp - 24*3600
        $blocks_measure = $Pool_Request_Blocks | Where-Object {$_.timestamp -gt $timestamp24h} | Select-Object -ExpandProperty timestamp | Measure-Object -Minimum -Maximum
        $Pool_BLK       = [int]$($(if ($blocks_measure.Count -gt 1 -and ($blocks_measure.Maximum - $blocks_measure.Minimum)) {24*3600/($blocks_measure.Maximum - $blocks_measure.Minimum)} else {1})*$blocks_measure.Count)
        $Pool_TSL       = [int]($timestamp) - [int]($Pool_Request_Blocks | Select-Object -ExpandProperty timestamp -First 1)
        if ($Pool_TSL -lt 0) {$Pool_TSL = 0}

        $Stat = Set-Stat -Name "$($Name)_$($Pool_Currency)_Profit" -Value 0 -Duration $StatSpan -HashRate $Pool_Request.hashrate -BlockRate $Pool_BLK -ChangeDetection $false -Quiet
        if (-not $Stat.HashRate_Live -and -not $AllowZero) {return}
    }
    
    if ($ok -or $InfoOnly) {
        $Pool_Wallet = if ($Wallets.$Pool_Currency) {$Wallets.$Pool_Currency} else {$User}
        foreach ($Pool_Region in $Pool_Regions) {
            [PSCustomObject]@{
                Algorithm     = $Pool_Algorithm_Norm
                Algorithm0    = $Pool_Algorithm_Norm
                CoinName      = $Pool_Coin.Name
                CoinSymbol    = $Pool_Currency
                Currency      = $Pool_Currency
                Price         = 0
                StablePrice   = 0
                MarginOfError = 0
                Protocol      = "stratum+tcp"
                Host          = "$($Pool_RpcPath).luxor.tech"
                Port          = $Pool_Port
                User          = "$($Pool_Wallet).{workername:$Worker}"
                Pass          = "x"
                Region        = $Pool_RegionsTable[$Pool_Region]
                SSL           = $false
                Updated       = $Stat.Updated
                WTM           = $true
                PoolFee       = $Pool_Fee
                Workers       = $Pool_Request.totalMiners
                Hashrate      = $Stat.HashRate_Live
                TSL           = $Pool_TSL
                BLK           = $Stat.BlockRate_Average
                Name          = $Name
                Penalty       = 0
                PenaltyFactor = 1
                Disabled      = $false
                HasMinerExclusions = $false
                Price_Bias    = 0.0
                Price_Unbias  = 0.0
                Wallet        = $Pool_Wallet
                Worker        = "{workername:$Worker}"
                Email         = $Email
            }
        }
    }
}
