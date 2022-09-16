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

[hashtable]$Pool_RegionsTable = @{}
@("eu","us","asia") | Foreach-Object {$Pool_RegionsTable.$_ = Get-Region $_}

$Pools_Data = @(
    [PSCustomObject]@{regions = @("eu","us","asia"); symbol = "ETHW"; port = @(8008); fee = 1}
)

$Pool_Currencies = $Pools_Data.symbol | Select-Object -Unique | Where-Object {$Wallets.$_ -or $InfoOnly}
if (-not $Pool_Currencies -and -not $InfoOnly) {return}

$Pools_Data | Where-Object {$Wallets."$($_.symbol)" -or $InfoOnly} | ForEach-Object {
    $Pool_Coin  = Get-Coin $_.symbol
    $Pool_Ports = $_.port
    $Pool_Algorithm_Norm = Get-Algorithm $Pool_Coin.Algo
    $Pool_Currency = $_.symbol

    $Pool_EthProxy = if ($Pool_Algorithm_Norm -match $Global:RegexAlgoHasEthproxy) {"ethproxy"} elseif ($Pool_Algorithm_Norm -match $Global:RegexAlgoIsProgPow) {"stratum"} else {$null}

    $Pool_Request = [PSCustomObject]@{}

    if (-not $InfoOnly) {
        try {
            $Pool_Request = Invoke-RestMethodAsync "https://iceberg.ethwmine.com/api/stats" -tag $Name -cycletime 120
        }
        catch {
            if ($Error.Count){$Error.RemoveAt(0)}
            Write-Log -Level Warn "Pool API ($Name) has failed. "
            return
        }

        $Pool_BlocksRequest = [PSCustomObject]@{}

        try {
            $Pool_BlocksRequest = Invoke-RestMethodAsync "https://iceberg.ethwmine.com/api/blocks" -tag $Name -cycletime 120
        }
        catch {
            if ($Error.Count){$Error.RemoveAt(0)}
            Write-Log -Level Info "Pool blocks API ($Name) has failed. "
        }

        $timestamp       = Get-UnixTimestamp
        $timestamp24h    = $timestamp - 86400

        $Pool_Workers    = [int]$Pool_Request.workerTotal
        $Pool_Hashrate   = [decimal]$Pool_Request.hashrate
        $blocks          = $Pool_BlocksRequest.candidates + $Pool_BlocksRequest.immature + $Pool_BlocksRequest.matured | Where-Object {$_.timestamp -ge $timestamp24h} | Foreach-Object {$_.timestamp}
        $blocks_measure  = $blocks | Where-Object {$_ -gt $timestamp24h} | Measure-Object -Minimum -Maximum
        $Pool_BLK        = [int]$($(if ($blocks_measure.Count -gt 1 -and ($blocks_measure.Maximum - $blocks_measure.Minimum)) {86400/($blocks_measure.Maximum - $blocks_measure.Minimum)} else {1})*$blocks_measure.Count)
        $Pool_TSL        = [int]($timestamp - $blocks_measure.Maximum)        

        $Stat = Set-Stat -Name "$($Name)_$($Pool_Currency)_Profit" -Value 0 -Duration $StatSpan -ChangeDetection $false -HashRate $Pool_Hashrate -BlockRate $Pool_BLK -Quiet
        if (-not $Stat.HashRate_Live -and -not $AllowZero) {return}
    }

    foreach($Pool_Region in $_.regions) {
        $Pool_Ssl = $false
        foreach($Pool_Port in $Pool_Ports) {
            $Pool_Protocol = "stratum+$(if ($Pool_Ssl) {"ssl"} else {"tcp"})"
            $Pool_User     = "$($Wallets.$Pool_Currency).{workername:$Worker}"
            [PSCustomObject]@{
                Algorithm     = $Pool_Algorithm_Norm
                Algorithm0    = $Pool_Algorithm_Norm
                CoinName      = $Pool_Coin.Name
                CoinSymbol    = $Pool_Currency
                Currency      = $Pool_Currency
                Price         = 0
                StablePrice   = 0
                MarginOfError = 0
                Protocol      = $Pool_Protocol
                Host          = "$($Pool_Region).ethwmine.com"
                Port          = $Pool_Port
                User          = $Pool_User
                Pass          = "x"
                Region        = $Pool_RegionsTable.$Pool_Region
                SSL           = $Pool_Ssl
                Updated       = (Get-Date).ToUniversalTime()
                PoolFee       = $_.fee
                DataWindow    = $DataWindow
                Workers       = $Pool_Workers
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
                Price_0       = 0.0
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
