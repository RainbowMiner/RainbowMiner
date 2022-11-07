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
@("eu") | Foreach-Object {$Pool_RegionsTable.$_ = Get-Region $_}

$Pools_Data = @(
    [PSCustomObject]@{symbol = "ETHW"; port = 3331; fee = 1.0; rpc = "ethw-pplns"; regions = @("eu")}
)

$Pools_Requests = [hashtable]@{}

$Pools_Data | Where-Object {$Wallets."$($_.symbol)" -or $InfoOnly} | ForEach-Object {
    $Pool_Coin          = Get-Coin $_.symbol
    $Pool_Currency      = $_.symbol
    $Pool_Fee           = $_.fee
    $Pool_Port          = $_.port
    $Pool_RpcPath       = $_.rpc

    $Pool_Regions       = $_.regions

    $Pool_Algorithm_Norm = Get-Algorithm $Pool_Coin.Algo

    $Pool_EthProxy = if ($Pool_Algorithm_Norm -match $Global:RegexAlgoHasEthproxy) {"ethproxy"} elseif ($Pool_Algorithm_Norm -match $Global:RegexAlgoIsProgPow) {"stratum"} else {$null}

    if (-not $InfoOnly) {

        $Pool_Request  = [PSCustomObject]@{}

        try {
            $Pool_Request = Invoke-RestMethodAsync "https://$($Pool_RpcPath).molepool.com/api/stats" -tag $Name -cycletime 120
        }
        catch {
            if ($Error.Count){$Error.RemoveAt(0)}
            Write-Log -Level Warn "Pool API ($Name) for $Pool_Currency has failed. "
            return
        }

        $Pool_BlocksRequest  = [PSCustomObject]@{}

        try {
            $Pool_BlocksRequest = Invoke-RestMethodAsync "https://$($Pool_RpcPath).molepool.com/api/blocks" -tag $Name -cycletime 120
        }
        catch {
            if ($Error.Count){$Error.RemoveAt(0)}
            Write-Log -Level Info "Pool blocks API ($Name) for $Pool_Currency has failed. "
        }

        if (-not $Global:Rates[$Pool_Currency] -and $Pool_Request.price.btc) {$Global:Rates[$Pool_Currency] = 1/$Pool_Request.price.btc}

        $timestamp       = Get-UnixTimestamp
        $timestamp24h    = $timestamp - 86400

        $Pool_Workers    = [int]$Pool_Request.stats.workerTotal
        $Pool_Hashrate   = [decimal]$Pool_Request.hashrate
        $blocks          = $Pool_BlocksRequest.candidates + $Pool_BlocksRequest.immature + $Pool_BlocksRequest.matured | Where-Object {$_.timestamp -ge $timestamp24h} | Foreach-Object {$_.timestamp}
        $blocks_measure  = $blocks | Where-Object {$_ -gt $timestamp24h} | Measure-Object -Minimum -Maximum
        $Pool_BLK        = [int]$($(if ($blocks_measure.Count -gt 1 -and ($blocks_measure.Maximum - $blocks_measure.Minimum)) {86400/($blocks_measure.Maximum - $blocks_measure.Minimum)} else {1})*$blocks_measure.Count)
        $Pool_TSL        = [int]($timestamp - $blocks_measure.Maximum)

        $Stat = Set-Stat -Name "$($Name)_$($Pool_Currency)_Profit" -Value 0 -Duration $StatSpan -HashRate $Pool_Hashrate -BlockRate $Pool_BLK -ChangeDetection $false -Quiet
        if (-not $Stat.HashRate_Live -and -not $AllowZero) {return}
    }

    foreach($Pool_SSL in @($false,$true)) {
        foreach($Pool_Region in $Pool_Regions) {
            [PSCustomObject]@{
                Algorithm     = $Pool_Algorithm_Norm
				Algorithm0    = $Pool_Algorithm_Norm
                CoinName      = $Pool_Coin.Name
                CoinSymbol    = $Pool_Currency
                Currency      = $Pool_Currency
                Price         = 0
                StablePrice   = 0
                MarginOfError = 0
                Protocol      = "stratum+$(if ($Pool_SSL) {"ssl"} else {"tcp"})"
                Host          = "$($Pool_Region).molepool.com"
                Port          = if ($Pool_SSL) {$Pool_Port + 10000} else {$Pool_Port}
                User          = "$($Wallets.$Pool_Currency).{workername:$Worker}"
                Pass          = "x"
                Region        = $Pool_RegionsTable.$Pool_Region
                SSL           = $Pool_SSL
                Updated       = $Stat.Updated
                PoolFee       = $Pool_Fee
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
        }
    }
}
