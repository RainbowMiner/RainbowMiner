﻿using module ..\Include.psm1

param(
    [PSCustomObject]$Wallets,
    [PSCustomObject]$Params,
    [alias("WorkerName")]
    [String]$Worker,
    [TimeSpan]$StatSpan,
    [String]$DataWindow = "average-2",
    [Bool]$InfoOnly = $false,
    [Bool]$AllowZero = $false,
    [String]$StatAverage = "Minute_10"
)

$Name = Get-Item $MyInvocation.MyCommand.Path | Select-Object -ExpandProperty BaseName

$Pool_Fee = 0.9

$Pool_Request = [PSCustomObject]@{}
$PoolCoins_Request = [PSCustomObject]@{}

try {
    $PoolCoins_Request = Invoke-RestMethodAsync "https://hashpool.eu/api/currencies" -tag $Name -cycletime 120
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

try {
    $Pool_Request = Invoke-RestMethodAsync "https://hashpool.eu/api/status" -delay 2000 -tag $Name -cycletime 120
}
catch {
    if ($Error.Count){$Error.RemoveAt(0)}
    Write-Log -Level Warn "Pool status API ($Name) has failed. "
}

[hashtable]$Pool_Algorithms = @{}
[hashtable]$Pool_RegionsTable = @{}

$Pool_Regions = @("eu")
$Pool_Regions | Foreach-Object {$Pool_RegionsTable.$_ = Get-Region $_}

$PoolCoins_Request | Get-Member -MemberType NoteProperty -ErrorAction Ignore | Select-Object -ExpandProperty Name | Where-Object {$Pool_CoinSymbol = $_;$Pool_User = $Wallets.$Pool_CoinSymbol;$Pool_User -or $InfoOnly} | ForEach-Object {

    $Pool_Host = "pool.hashpool.eu"
    $Pool_Port = if ($PoolCoins_Request.$Pool_CoinSymbol.symbol -match "^\d+$") {$PoolCoins_Request.$Pool_CoinSymbol.symbol} else {$PoolCoins_Request.$Pool_CoinSymbol.port}
    $Pool_Algorithm = $PoolCoins_Request.$Pool_CoinSymbol.algo
    if (-not $Pool_Algorithms.ContainsKey($Pool_Algorithm)) {$Pool_Algorithms.$Pool_Algorithm = Get-Algorithm $Pool_Algorithm}
    $Pool_Algorithm_Norm = $Pool_Algorithms.$Pool_Algorithm
    $Pool_Coin = $PoolCoins_Request.$Pool_CoinSymbol.name
    $Pool_PoolFee = if ($Pool_Request.$Pool_Algorithm.fees -ne $null) {$Pool_Request.$Pool_Algorithm.fees} else {$Pool_Fee}
    $Pool_DataWindow = $DataWindow

    $Pool_TSL = $PoolCoins_Request.$Pool_CoinSymbol.timesincelast
    $Pool_BLK = $PoolCoins_Request.$Pool_CoinSymbol."24h_blocks"

    if (-not $InfoOnly) {
        $Stat = Set-Stat -Name "$($Name)_$($Pool_CoinSymbol)_Profit" -Value 0 -Duration $StatSpan -ChangeDetection $false -HashRate $PoolCoins_Request.$Pool_CoinSymbol.hashrate -BlockRate $Pool_BLK -Quiet
        if (-not $Stat.HashRate_Live -and -not $AllowZero) {return}
    }

    $Pool_Params = if ($Params.$Pool_CoinSymbol) {",$($Params.$Pool_CoinSymbol)"}

    foreach($Pool_Region in $Pool_Regions) {
        [PSCustomObject]@{
            Algorithm     = $Pool_Algorithm_Norm
            Algorithm0    = $Pool_Algorithm_Norm
            CoinName      = $Pool_Coin
            CoinSymbol    = $Pool_CoinSymbol
            Currency      = $Pool_CoinSymbol
            Price         = 0
            StablePrice   = 0
            MarginOfError = 0
            Protocol      = "stratum+tcp"
            Host          = "pool.hashpool.eu"
            Port          = $Pool_Port
            User          = "$($Pool_User).{workername:$Worker}"
            Pass          = "c=$Pool_CoinSymbol{diff:,d=`$difficulty}$Pool_Params"
            Region        = $Pool_RegionsTable.$Pool_Region
            SSL           = $false
            Updated       = (Get-Date).ToUniversalTime()
            PoolFee       = $Pool_PoolFee
            DataWindow    = $Pool_DataWindow
            Workers       = $PoolCoins_Request.$Pool_CoinSymbol.workers
            Hashrate      = $Stat.HashRate_Live
            BLK           = $Stat.BlockRate_Average
            TSL           = $Pool_TSL
			ErrorRatio    = $Stat.ErrorRatio
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
