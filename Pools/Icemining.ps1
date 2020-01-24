﻿using module ..\Include.psm1

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

$Pool_Fee = 1

$Pool_Request = [PSCustomObject]@{}
$PoolCoins_Request = [PSCustomObject]@{}

try {
    $PoolCoins_Request = Invoke-RestMethodAsync "https://icemining.ca/api/currencies" -tag $Name -cycletime 120
    if ($PoolCoins_Request -is [string]) {$PoolCoins_Request = ($PoolCoins_Request -replace '<script.+?/script>' -replace '<.+?>').Trim() | ConvertFrom-Json -ErrorAction Stop}
}
catch {
    if ($Error.Count){$Error.RemoveAt(0)}
    Write-Log -Level Warn "Pool API ($Name) has failed. "
    return
}

if (($PoolCoins_Request | Get-Member -MemberType NoteProperty -ErrorAction Ignore | Measure-Object Name).Count -le 1) {
    Write-Log -Level Warn "Pool API ($Name) returned nothing. "
    return
}

[hashtable]$Pool_Algorithms = @{}
[hashtable]$Pool_RegionsTable = @{}

$Pool_Regions = @("us")
$Pool_Regions | Foreach-Object {$Pool_RegionsTable.$_ = Get-Region $_}

$PoolCoins_Request.PSObject.Properties.Name | Where-Object {$Pool_CoinSymbol = $_;$Pool_Currency = if ($PoolCoins_Request.$Pool_CoinSymbol.symbol) {$PoolCoins_Request.$Pool_CoinSymbol.symbol} else {$Pool_CoinSymbol};$Pool_User = $Wallets.$Pool_Currency;$Pool_User -or $InfoOnly} | ForEach-Object {
    $Pool_Currency = $Pool_Currency -replace '-.+$'

    $Pool_Host = "$(if ($Pool_Currency -eq "NIM") {"nimiq"} else {"stratum"}).icemining.ca"

    $Pool_Port = $PoolCoins_Request.$Pool_CoinSymbol.port
    $Pool_Algorithm = $PoolCoins_Request.$Pool_CoinSymbol.algo

    if ($Pool_Algorithm -eq "epic") {
        $Pool_Algorithm_Norm = @("RandomX","ProgPoW","CuckooCycle") | Foreach-Object {
            if (-not $Pool_Algorithms.ContainsKey($_)) {$Pool_Algorithms.$_ = Get-Algorithm $_}
            $Pool_Algorithms.$_
        }
    } else {
        if (-not $Pool_Algorithms.ContainsKey($Pool_Algorithm)) {$Pool_Algorithms.$Pool_Algorithm = Get-Algorithm $Pool_Algorithm}
        $Pool_Algorithm_Norm = $Pool_Algorithms.$Pool_Algorithm
    }

    $Pool_Coin = $PoolCoins_Request.$Pool_CoinSymbol.name
    $Pool_PoolFee = if ($Pool_Request.$Pool_Algorithm) {$Pool_Request.$Pool_Algorithm.fees} else {$Pool_Fee}

    $Divisor = 1e9

    $Pool_TSL = $PoolCoins_Request.$Pool_CoinSymbol.timesincelast

    $Pool_Params = if ($Params.$Pool_Currency) {",$($Params.$Pool_Currency)"}

    $Pool_Algorithm_Norm | Foreach-Object {

        if (-not $InfoOnly) {
            $Stat = Set-Stat -Name "$($Name)_$($Pool_CoinSymbol)$(if ($Pool_CoinSymbol -eq "EPIC") {"-$_"})_Profit" -Value ([Double]$PoolCoins_Request.$Pool_CoinSymbol.estimate / $Divisor) -Duration $StatSpan -ChangeDetection $false -HashRate $(if ($Pool_CoinSymbol -eq "EPIC") {10} else {$PoolCoins_Request.$Pool_CoinSymbol.hashrate}) -BlockRate $PoolCoins_Request.$Pool_CoinSymbol."24h_blocks" -Quiet
            if (-not $Stat.HashRate_Live -and -not $AllowZero) {return}
        }

        foreach($Pool_Region in $Pool_Regions) {        
            [PSCustomObject]@{
                Algorithm     = $_
				Algorithm0    = $_
                CoinName      = $Pool_Coin
                CoinSymbol    = $Pool_CoinSymbol
                Currency      = $Pool_Currency
                Price         = 0
                StablePrice   = 0
                MarginOfError = 0
                Protocol      = "stratum+tcp"
                Host          = $Pool_Host
                Port          = $Pool_Port
                User          = $Pool_User
                Pass          = "{workername:$Worker},c=$Pool_Currency{diff:,d=`$difficulty}$Pool_Params"
                Region        = $Pool_RegionsTable.$Pool_Region
                SSL           = $false
                Updated       = $Stat.Updated
                PoolFee       = $Pool_PoolFee
                Workers       = $PoolCoins_Request.$Pool_CoinSymbol.workers
                Hashrate      = $Stat.HashRate_Live
                BLK           = $Stat.BlockRate_Average
                TSL           = $Pool_TSL
                WTM           = $true
                Name          = $Name
                Penalty       = 0
                PenaltyFactor = 1
                Disabled      = $false
                HasMinerExclusions = $false
                Price_Bias    = 0.0
                Price_Unbias  = 0.0
                Wallet        = $Pool_User
                Worker        = "{workername:$Worker}"
                Email         = $Email
            }
        }
    }
}
