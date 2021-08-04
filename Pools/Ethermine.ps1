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

[hashtable]$Pool_RegionsTable = @{}
@("eu","useast","uswest","asia") | Foreach-Object {$Pool_RegionsTable.$_ = Get-Region $_}

[hashtable]$Pool_RegionsMap = @{
    "eu"     = "eu1"
    "useast" = "us1"
    "uswest" = "us2"
    "asia"   = "asia1"
}

$Pools_Data = @(
    [PSCustomObject]@{regions = @("asia","eu","useast");          host = "-etc.ethermine.org"; rpc = "api-etc.ethermine.org"; symbol = "ETC"; port = 4444; fee = 1; divisor = 1000000}
    [PSCustomObject]@{regions = @("asia","eu","uswest","useast"); host = ".ethermine.org";     rpc = "api.ethermine.org";     symbol = "ETH"; port = 4444; fee = 1; divisor = 1000000}
)

$Pool_Currencies = $Pools_Data.symbol | Select-Object -Unique | Where-Object {$Wallets.$_ -or $InfoOnly}
if (-not $Pool_Currencies -and -not $InfoOnly) {return}

$Pools_Data | Where-Object {$Wallets."$($_.symbol)" -or $InfoOnly} | ForEach-Object {
    $Pool_Coin  = Get-Coin $_.symbol
    $Pool_Ports = $_.port
    $Pool_Algorithm_Norm = Get-Algorithm $Pool_Coin.Algo
    $Pool_Currency = $_.symbol

    $Pool_EthProxy = if ($Pool_Algorithm_Norm -match $Global:RegexAlgoHasEthproxy) {"qtminer"} elseif ($Pool_Algorithm_Norm -eq "KawPOW") {"stratum"} else {$null}

    $Pool_Request = [PSCustomObject]@{}

    if (-not $InfoOnly) {
        try {
            $Pool_Request = Invoke-RestMethodAsync "https://$($_.rpc)/poolStats" -tag $Name -cycletime 120
            if ($Pool_Request.status -ne "OK") {throw}
        }
        catch {
            if ($Error.Count){$Error.RemoveAt(0)}
            Write-Log -Level Warn "Pool API ($Name) has failed. "
        }
        $Stat = Set-Stat -Name "$($Name)_$($Pool_Currency)_Profit" -Value 0 -Duration $StatSpan -ChangeDetection $false -HashRate $Pool_Request.data.poolStats.hashRate -BlockRate (24*$Pool_Request.data.poolStats.blocksPerHour) -Quiet
        if (-not $Stat.HashRate_Live -and -not $AllowZero) {return}
    }
    
    $Pool_TSL = if ($Pool_Request.data.minedBlocks) {(Get-UnixTimestamp)-($Pool_Request.data.minedBlocks.time | Measure-Object -Maximum).Maximum}

    foreach($Pool_Region in $_.regions) {
        $Pool_Ssl = $false
        foreach($Pool_Port in $Pool_Ports) {
            [PSCustomObject]@{
                Algorithm     = $Pool_Algorithm_Norm
                Algorithm0    = $Pool_Algorithm_Norm
                CoinName      = $Pool_Coin.Name
                CoinSymbol    = $Pool_Currency
                Currency      = $Pool_Currency
                Price         = 0
                StablePrice   = 0
                MarginOfError = 0
                Protocol      = "stratum+$(if ($Pool_Ssl) {"ssl"} else {"tcp"})"
                Host          = "$($Pool_RegionsMap.$Pool_Region)$($_.host)"
                Port          = $Pool_Port
                User          = "$($Wallets.$Pool_Currency).{workername:$Worker}"
                Pass          = "x"
                Region        = $Pool_RegionsTable.$Pool_Region
                SSL           = $Pool_Ssl
                Updated       = (Get-Date).ToUniversalTime()
                PoolFee       = $_.fee
                DataWindow    = $DataWindow
                Workers       = $Pool_Request.data.poolStats.workers
                Hashrate      = $Stat.HashRate_Live
                TSL           = $Pool_TSL
                BLK           = $Stat.BlockRate_Average
                WTM           = $true
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
            $Pool_Ssl = $true
        }
    }
}
