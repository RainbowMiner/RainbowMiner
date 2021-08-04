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
@("eu","us","asia") | Foreach-Object {$Pool_RegionsTable.$_ = Get-Region $_}

$Pools_Data = @(
    [PSCustomObject]@{regions = @("eu","us","asia"); host = "1-beam.flypool.org";      rpc = "api-beam.flypool.org";      symbol = "BEAM"; port = @(3333,3443); fee = 1; divisor = 1}
    [PSCustomObject]@{regions = @("eu","us","asia"); host = "1-zcash.flypool.org";     rpc = "api-zcash.flypool.org";     symbol = "ZEC";  port = @(3333,3443); fee = 1; divisor = 1}
    [PSCustomObject]@{regions = @("eu","us","asia"); host = "1-ycash.flypool.org";     rpc = "api-ycash.flypool.org";     symbol = "YEC";  port = @(3333,3443); fee = 1; divisor = 1}
    [PSCustomObject]@{regions = @("stratum");        host = "-ravencoin.flypool.org";  rpc = "api-ravencoin.flypool.org"; symbol = "RVN";  port = @(3333,3443); fee = 1; divisor = 1}
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
    }

    $Pool_TSL = if ($Pool_Request.data.minedBlocks) {(Get-UnixTimestamp)-($Pool_Request.data.minedBlocks.time | Measure-Object -Maximum).Maximum}

    if ($AllowZero -or $Pool_Request.data.poolStats.hashRate -gt 0 -or $InfoOnly) {
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
                    Host          = "$($Pool_Region)$($_.host)"
                    Port          = $Pool_Port
                    User          = "$($Wallets.$Pool_Currency).{workername:$Worker}"
                    Pass          = "x"
                    Region        = $Pool_RegionsTable."$(if ($Pool_Region -eq "stratum") {"eu"} else {$Pool_Region})"
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
}
