using module ..\Include.psm1

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

[hashtable]$Pool_RegionsTable = @{}

@("eu","us") | Foreach-Object {$Pool_RegionsTable.$_ = Get-Region $_}

$Pools_Data = @(
    [PSCustomObject]@{symbol = "RVN"; url = "ravencoin"; port = 3010; fee = 0.9; ssl = $false; protocol = "stratum+tcp"}
    [PSCustomObject]@{symbol = "XZC"; url = "zcoin";     port = 3000; fee = 0.9; ssl = $false; protocol = "stratum+tcp"}
)

$Pools_Data | Where-Object {$Wallets."$($_.symbol)" -or $InfoOnly} | ForEach-Object {
    $Pool_Coin = Get-Coin $_.symbol
    $Pool_Port = $_.port
    $Pool_Algorithm_Norm = Get-Algorithm $Pool_Coin.Algo
    $Pool_Currency = $_.symbol
    $Pool_Url = "https://api.mintpond.com/v1/$($_.url)"

    $Pool_Request = [PSCustomObject]@{}
    $Pool_RequestBlockstats = [PSCustomObject]@{}
    $Pool_RequestBlocks = [PSCustomObject]@{}

    $Pool_TSL  = $timestamp = Get-UnixTimestamp
    $timestamp24h = $timestamp - 86400

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
            } else {$ok = $false}
        }
        catch {
            if ($Error.Count){$Error.RemoveAt(0)}
            Write-Log -Level Warn "Pool API ($Name) for $($Pool_Currency) has failed. "
            $ok = $false
        }

        if ($ok) {
            $blocks_measure = $Pool_RequestBlocks.pool.recentBlocks | Where-Object {$_.time -gt $timestamp24h} | Measure-Object time -Maximum -Minimum
            $avgTime        = if ($blocks_measure.Count -gt 1) {($blocks_measure.Maximum - $blocks_measure.Minimum) / ($blocks_measure.Count - 1)} else {$Pool_TSL}
            $lastBlock      = $Pool_RequestBlocks.pool.recentBlocks | Sort-Object height | Select-Object -Last 1
            $Pool_TSL      -= if ($lastBlock.time) {$lastBlock.time} else {$Pool_Request.pool.lastBlockTime*1000}
            $Pool_BLK       = $Pool_RequestBlockstats.pool.blockStats.valid24h
            $reward         = 14 #if ($lastBlock.reward) {$lastBlock.reward} else {14}
            $btcPrice       = if ($Session.Rates.$Pool_Currency) {1/[double]$Session.Rates.$Pool_Currency} else {0}            
            $btcRewardLive  = if ($Pool_Request.pool.hashrate -gt 0) {$btcPrice * $reward * 86400 / $Pool_Request.pool.estTime / $Pool_Request.pool.hashrate} else {0}
            $Divisor        = 1
            $Stat = Set-Stat -Name "$($Name)_$($Pool_Currency)_Profit" -Value ($btcRewardLive/$Divisor) -Duration $StatSpan -ChangeDetection $true -HashRate $Pool_Request.pool.hashrate -BlockRate $Pool_BLK -Quiet
        }
    }

    if ($ok) {
        foreach($Pool_Region in $Pool_RegionsTable.Keys) {
            [PSCustomObject]@{
                Algorithm     = $Pool_Algorithm_Norm
                CoinName      = $Pool_Coin.Name
                CoinSymbol    = $Pool_Currency
                Currency      = $Pool_Currency
                Price         = $Stat.$StatAverage #instead of .Live
                StablePrice   = $Stat.Week
                MarginOfError = $Stat.Week_Fluctuation
                Protocol      = $_.protocol
                Host          = "$($_.url)-$($Pool_Region).mintpond.com"
                Port          = $_.port
                User          = "$($Wallets.$Pool_Currency).{workername:$Worker}"
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
                AlgorithmList = if ($Pool_Algorithm_Norm -match "-") {@($Pool_Algorithm_Norm, ($Pool_Algorithm_Norm -replace '\-.*$'))}else{@($Pool_Algorithm_Norm)}
                Name          = $Name
                Penalty       = 0
                PenaltyFactor = 1
                Wallet        = $Wallets.$Pool_Currency
                Worker        = "{workername:$Worker}"
                Email         = $Email
            }
        }
    }
}
