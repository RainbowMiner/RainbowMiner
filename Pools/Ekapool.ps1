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

$Pool_Request = [PSCustomObject]@{}

try {
    $Pool_Request = Invoke-RestMethodAsync "https://ekapool.com/api/pools" -tag $Name -cycletime 120
}
catch {
    if ($Error.Count){$Error.RemoveAt(0)}
    Write-Log -Level Warn "Pool API ($Name) has failed. "
    return
}

if (($Pool_Request.pools | Measure-Object).Count -le 1) {
    Write-Log -Level Warn "Pool API ($Name) returned nothing. "
    return
}

[hashtable]$Pool_RegionsTable = @{}

$Pool_Regions = @("us","eu","sg")
$Pool_Regions | Foreach-Object {$Pool_RegionsTable.$_ = Get-Region $_}

$Pool_Request.pools | Where-Object {$Pool_Currency = $_.coin.symbol;$_.paymentProcessing.payoutScheme -eq "PPLNS" -and ($Wallets.$Pool_Currency -or $InfoOnly)} | Foreach-Object {

    $Pool_Coin = Get-Coin $Pool_Currency

    if ($Pool_Coin) {
        $Pool_CoinName = $Pool_Coin.Name
        $Pool_Algorithm_Norm = Get-Algorithm $Pool_Coin.Algo -CoinSymbol $Pool_Currency
    } else {
        $Pool_CoinName = $_.coin.name
        $Pool_Algorithm_Norm = Get-Algorithm $_.coin.algorithm -CoinSymbol $Pool_Currency
    }

    $Pool_EthProxy = if ($Pool_Algorithm_Norm -match $Global:RegexAlgoHasEthproxy) {"ethstratum"} elseif ($Pool_Algorithm_Norm -match $Global:RegexAlgoIsProgPow) {"stratum"} else {$null}

    $Pool_PoolFee = [Double]$_.poolFeePercent

    $Pool_Workers = [int]$_.poolStats.connectedMiners

    $Pool_Port = [int]($_.ports.PSObject.Properties | Sort-Object {[int]$_.Name} | Where-Object {-not $_.Value.tls} | Foreach-Object {$_.Name} | Select-Object -First 1)

    if (-not $InfoOnly) {

        if (-not $_.poolStats.poolHashrate -and -not $AllowZero) {return}

        $Pool_BlocksRequest = $null
        try {
            $Pool_BlocksRequest = Invoke-RestMethodAsync "https://ekapool.com/api/pools/$($_.id)/blocks?page=0&pageSize=100" -tag $Name -timeout 15 -cycletime 120
        }
        catch {
            if ($Error.Count){$Error.RemoveAt(0)}
            Write-Log -Level Warn "Pool blocks API ($Name) for $Pool_Currency has failed. "
        }
    
        if ($Pool_BlocksRequest) {
            $now             = [datetime]::UtcNow
            $blocks          = $Pool_BlocksRequest | Foreach-Object {[int]($now - ([datetime]$_.created).ToUniversalTime()).TotalSeconds} | Where-Object {$_ -lt 86400}
            $blocks_measure  = $blocks | Measure-Object -Minimum -Maximum
            $Pool_BLK        = [int]$($(if ($blocks_measure.Count -gt 1 -and ($blocks_measure.Maximum - $blocks_measure.Minimum)) {86400/($blocks_measure.Maximum - $blocks_measure.Minimum)} else {1})*$blocks_measure.Count)
            $Stat = Set-Stat -Name "$($Name)_$($Pool_Currency)_Profit" -Value 0 -Duration $StatSpan -ChangeDetection $false -HashRate $_.poolStats.poolHashrate -BlockRate $Pool_BLK -Quiet
        }
    }

    $Pool_TSL = if ($_.lastPoolBlockTime) {[int]([datetime]::UtcNow - ([datetime]$_.lastPoolBlockTime).ToUniversalTime()).TotalSeconds} else {$null}

    $Pool_Stratum = $Pool_Currency.ToLower()

    foreach($Pool_Region in $Pool_Regions) {
        foreach($Pool_SSL in @($false)) {
            [PSCustomObject]@{
                Algorithm     = $Pool_Algorithm_Norm
                Algorithm0    = $Pool_Algorithm_Norm
                CoinName      = $Pool_Coin.Name
                CoinSymbol    = $Pool_Coin.Symbol
                Currency      = $Pool_Currency
                Price         = $Stat.$StatAverage #instead of .Live
                StablePrice   = $Stat.$StatAverageStable
                MarginOfError = $Stat.Week_Fluctuation
                Protocol      = "stratum+$(if ($Pool_SSL) {"ssl"} else {"tcp"})"
                Host          = "$($Pool_Stratum).$($Pool_Region).ekapool.com"
                Port          = if ($Pool_SSL) {$Pool_Port + 100} else {$Pool_Port}
                User          = "$($Wallets.$Pool_Currency).{workername:$Worker}"
                Pass          = "x"
                Region        = $Pool_RegionsTable.$Pool_Region
                SSL           = $Pool_SSL
                Updated       = $Stat.Updated
                PoolFee       = $Pool_PoolFee
                DataWindow    = $DataWindow
                Workers       = $Pool_Workers
                BLK           = $Stat.BlockRate_Average
                TSL           = $Pool_TSL
                WTM           = $true
                EthMode       = $Pool_EthProxy
                Hashrate      = $Stat.HashRate_Live
				ErrorRatio    = $Stat.ErrorRatio
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
