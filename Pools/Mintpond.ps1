using module ..\Modules\Include.psm1

param(
    [String]$Name,
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

# $Name = Get-Item $MyInvocation.MyCommand.Path | Select-Object -ExpandProperty BaseName

[hashtable]$Pool_RegionsTable = @{}

$Pool_Regions = @("eu","us")
$Pool_Regions | Foreach-Object {$Pool_RegionsTable.$_ = Get-Region $_}

$Pools_Data = @(
    [PSCustomObject]@{symbol = "RVN";  url = "ravencoin"; port = 3010; fee = 0.9; ssl = $false; protocol = "stratum+tcp"}
    [PSCustomObject]@{symbol = "FIRO"; url = "firo";      port = 3000; fee = 0.9; ssl = $false; protocol = "stratum+tcp"; altsymbol = "XZC"}
)

$Pools_Data | Where-Object {$Wallets."$($_.symbol)" -or ($_.altsymbol -and $Wallets."$($_.altsymbol)") -or $InfoOnly} | ForEach-Object {
    $Pool_Coin = Get-Coin $_.symbol
    $Pool_Port = $_.port
    $Pool_Algorithm_Norm = $Pool_Coin.Algo
    $Pool_Currency = $_.symbol
    $Pool_Url = "https://api.mintpond.com/v1/$($_.url)"

    $Pool_EthProxy = if ($Pool_Algorithm_Norm -match $Global:RegexAlgoHasEthproxy) {"ethproxy"} elseif ($Pool_Algorithm_Norm -match $Global:RegexAlgoIsProgPow) {"stratum"} else {$null}

    if (-not ($Pool_Wallet = $Wallets.$Pool_Currency)) {
        $Pool_Wallet = $Wallets."$($_.altsymbol)"
    }

    $Pool_Request = [PSCustomObject]@{}
    $Pool_RequestBlockstats = [PSCustomObject]@{}
    $Pool_RequestBlocks = [PSCustomObject]@{}
    $Pool_LastBlocks = @()

    $ok = $true
    if (-not $InfoOnly) {
        try {
            $Pool_Request = Invoke-RestMethodAsync "$($Pool_Url)/pool/status" -tag $Name -retry 5 -retrywait 250 -cycletime 120
            if (-not $Pool_Request.pool) {throw}
            if ($Pool_Request.pool.hashrate -or $AllowZero) {
                $Pool_RequestBlockstats = Invoke-RestMethodAsync "$($Pool_Url)/pool/blockstats" -tag $Name -retry 5 -retrywait 250 -cycletime 120 -delay 250
                if (-not $Pool_RequestBlockstats.pool.blockStats) {throw}
                $Pool_RequestBlocks = Invoke-RestMethodAsync "$($Pool_Url)/pool/recentblocks" -tag $Name -retry 5 -retrywait 250 -cycletime 120 -delay 250
                if (-not $Pool_RequestBlocks.pool.recentBlocks) {throw}
                $Pool_LastBlocks = $Pool_RequestBlocks.pool.recentBlocks | Sort-Object height | Select-Object -Last 3
            } else {$ok = $false}
        }
        catch {
            Write-Log -Level Warn "Pool API ($Name) for $($Pool_Currency) has failed. "
            $ok = $false
        }

        if ($ok) {
            $Pool_TSL       = Get-UnixTimestamp
            $lastBlock      = $Pool_LastBlocks | Select-Object -Last 1
            $Pool_TSL      -= if ($lastBlock.time) {$lastBlock.time} else {$Pool_Request.pool.lastBlockTime*1000}
            $Pool_BLK       = $Pool_RequestBlockstats.pool.blockStats.valid24h
            $reward         = if ($Pool_LastBlocks) {($Pool_LastBlocks.reward | Measure-Object -Average).Average} else {6.25}
            $btcPrice       = if ($Global:Rates.$Pool_Currency) {1/[double]$Global:Rates.$Pool_Currency} else {0}            
            $btcRewardLive  = if ($Pool_Request.pool.hashrate -gt 0) {$btcPrice * $reward * 86400 / $Pool_Request.pool.estTime / $Pool_Request.pool.hashrate} else {0}
            $Divisor        = 1
            $Stat = Set-Stat -Name "$($Name)_$($Pool_Currency)_Profit" -Value ($btcRewardLive/$Divisor) -Duration $StatSpan -ChangeDetection $true -HashRate $Pool_Request.pool.hashrate -BlockRate $Pool_BLK -Quiet
            if (-not $Stat.HashRate_Live -and -not $AllowZero) {return}
        }
    }

    if ($ok) {
        foreach($Pool_Region in $Pool_Regions) {
            [PSCustomObject]@{
                Algorithm     = $Pool_Algorithm_Norm
                Algorithm0    = $Pool_Algorithm_Norm
                CoinName      = $Pool_Coin.Name
                CoinSymbol    = $Pool_Currency
                Currency      = $Pool_Currency
                Price         = $Stat.$StatAverage #instead of .Live
                StablePrice   = $Stat.$StatAverageStable
                MarginOfError = $Stat.Week_Fluctuation
                Protocol      = $_.protocol
                Host          = "$($_.url)-$($Pool_Region).mintpond.com"
                Port          = $_.port
                User          = "$($Pool_Wallet).{workername:$Worker}"
                Pass          = "x{diff:,d=`$difficulty}"
                Region        = $Pool_RegionsTable.$Pool_Region
                SSL           = $_.ssl
                Updated       = $Stat.Updated
                PoolFee       = $_.fee
                DataWindow    = $DataWindow
                Workers       = $Pool_Request.pool.workerCount
                Hashrate      = $Stat.HashRate_Live
                BLK           = $Stat.BlockRate_Average
                TSL           = $Pool_TSL
                EthMode       = $Pool_EthProxy
                Name          = $Name
                Penalty       = 0
                PenaltyFactor = 1
                Disabled      = $false
                HasMinerExclusions = $false
                Price_0       = 0.0
                Price_Bias    = 0.0
                Price_Unbias  = 0.0
                Wallet        = $Pool_Wallet
                Worker        = "{workername:$Worker}"
                Email         = $Email
            }
        }
    }
}
