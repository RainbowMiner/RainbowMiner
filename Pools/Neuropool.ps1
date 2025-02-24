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

$Pool_AllRegions = @("eu","us","in","au","as","as2","ca","me")
[hashtable]$Pool_RegionsTable = @{}
$Pool_AllRegions | Foreach-Object {$Pool_RegionsTable.$_ = Get-Region $_}
$Pool_RegionsTable.as2 = Get-Region "hk"

$Pools_Data = @(
    [PSCustomObject]@{symbol = "DNX";   port = 19330; fee = 1.0; rpc = "dynex"; region = $Pool_AllRegions; host = "dnx"; mallob = $true}
)

$Pools_Data | Where-Object {$Pool_Currency = $_.symbol -replace "-.+$";$Wallets.$Pool_Currency -or $InfoOnly} | ForEach-Object {
    $Pool_Coin      = Get-Coin $_.symbol
    $Pool_Fee       = $_.fee
    $Pool_Port      = $_.port
    $Pool_RpcPath   = $_.rpc
    $Pool_Regions   = $_.region

    $Pool_Divisor   = 1
    $Pool_HostPath  = if ($_.host) {$_.host} else {$Pool_RpcPath}

    $Pool_Algorithm_Norm = $Pool_Coin.algo

    $Pool_EthProxy = if ($Pool_Algorithm_Norm -match $Global:RegexAlgoHasEthproxy) {"ethproxy"} elseif ($Pool_Algorithm_Norm -match $Global:RegexAlgoIsProgPow) {"stratum"} else {$null}

    $Pool_Request  = [PSCustomObject]@{}
    $Pool_Ports    = @([PSCustomObject]@{})

    $Pool_Password = "$(if ($_.pass) {$_.pass} else {"{workername:$Worker}"})"
    $Pool_UserWN   = "$(if ($_.pass) {".{workername:$Worker}"})"

    $ok = $true
    if (-not $InfoOnly) {
        try {
            $Pool_Request = Invoke-RestMethodAsync "https://$($Pool_RpcPath).neuropool.net:8119/stats" -tag $Name -timeout 15 -cycletime 120
            $Pool_Ports   = Get-PoolPortsFromRequest $Pool_Request -mCPU "" -mGPU "8khs" -mRIG "25khs"
            if ($Pool_Request.config.cycleLength) {$Pool_Divisor = $Pool_Request.config.cycleLength}
        }
        catch {
            Write-Log -Level Warn "Pool API ($Name) for $Pool_Currency has failed. "
            $ok = $false
        }

        if (-not ($Pool_Ports | Where-Object {$_} | Measure-Object).Count) {$ok = $false}
    }


    if ($ok -and -not $InfoOnly) {
        $Pool_Fee = $Pool_Request.config.fee

        if ($Wallets.$Pool_Currency -match "^solo:") {
            $blkTime         = if ($Pool_Request.config.avgDifficultyTargetEnabled) {$Pool_Request.network.difficultyTarget} else {$Pool_Request.config.coinDifficultyTarget}
            $diffFactor      = if ($_.diffFactor) {$_.diffFactor} else {1}

            $Pool_SoloMining = $true
            $Pool_Diff       = if ($_.cycles -and [bool]$Pool_Request.network.PSObject.Properties["hashrate"]) {[double]$Pool_Request.network.hashrate."$($_.cycles)" * $blkTime} else {[double]$Pool_Request.network.difficulty * $(if ($_.cycles) {$_.cycles} else {1})}
            $Pool_Diff      *= $diffFactor / 4294967296 #2^32

            $Stat = Set-Stat -Name "$($Name)_$($_.symbol)_Profit" -Value 0 -Duration $StatSpan -Difficulty $Pool_Diff -ChangeDetection $false -Quiet
        } else {
            $timestamp       = Get-UnixTimestamp
            $timestamp24h    = $timestamp - 86400

            $Pool_SoloMining = $false
            $Pool_Workers    = [int]$Pool_Request.pool.workers
            $Pool_Hashrate   = [decimal]$Pool_Request.pool.hashrate
            $blocks          = $Pool_Request.pool.blocks | Where-Object {$_ -match "^[0-9a-z\.]+:.*?(\d{10}):" -and ($Matches[1] -ge $timestamp24h)} | Foreach-Object {$Matches[1]}
            $blocks_measure  = $blocks | Where-Object {$_ -gt $timestamp24h} | Measure-Object -Minimum -Maximum
            $Pool_BLK        = [int]$($(if ($blocks_measure.Count -gt 1 -and ($blocks_measure.Maximum - $blocks_measure.Minimum)) {86400/($blocks_measure.Maximum - $blocks_measure.Minimum)} else {1})*$blocks_measure.Count)
            $Pool_TSL        = [int]($timestamp - ([decimal]$PooL_Request.pool.stats.lastBlockFoundprop/1000))

            $Stat = Set-Stat -Name "$($Name)_$($_.symbol)_Profit" -Value 0 -Duration $StatSpan -HashRate $Pool_Hashrate -BlockRate $Pool_BLK -ChangeDetection $false -Quiet
            if (-not $Stat.HashRate_Live -and -not $AllowZero) {return}
        }
    }
    
    if ($ok -or $InfoOnly) {
        $Pool_SSL = $false
        $Pool_Wallet = Get-WalletWithPaymentId $Wallets.$Pool_Currency -asobject
        foreach ($Pool_Port in $Pool_Ports) {
            if ($Pool_Port) {
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
                        Protocol      = "stratum+$(if ($Pool_SSL) {"ssl"} else {"tcp"})"
                        Host          = "$($Pool_HostPath).$($Pool_Region).neuropool.net"
                        Port          = if ($Pool_Port.CPU -ne $null) {$Pool_Port.CPU} else {$_.port}
                        Ports         = if ($Pool_Port.CPU -ne $null) {$Pool_Port} else {$null}
                        User          = "$($Pool_Wallet.wallet)$(if ($Pool_Request.config.fixedDiffEnabled) {if ($Pool_Wallet.difficulty) {"$($Pool_Request.config.fixedDiffSeparator)$($Pool_Wallet.difficulty)"} else {"{diff:$($Pool_Request.config.fixedDiffSeparator)`$difficulty}"}})$($Pool_UserWN)"
                        Pass          = $Pool_Password
                        Region        = $Pool_RegionsTable[$Pool_Region]
                        SSL           = $Pool_SSL
                        Updated       = $Stat.Updated
                        PoolFee       = $Pool_Fee
                        Workers       = if (-not $Pool_SoloMining) {$Pool_Workers} else {$null}
                        Hashrate      = if (-not $Pool_SoloMining) {$Stat.HashRate_Live} else {$null}
                        BLK           = if (-not $Pool_SoloMining) {$Stat.BlockRate_Average} else {$null}
                        TSL           = if (-not $Pool_SoloMining) {$Pool_TSL} else {$null}
                        Difficulty    = if ($Pool_SoloMining) {$Stat.Diff_Average} else {$null}
                        SoloMining    = $Pool_SoloMining
                        WTM           = $true
                        WTMMode       = $_.wtmmode
                        EthMode       = $Pool_EthProxy
                        Mallob        = if ($_.mallob) {" http://mallob-ml.$($Pool_Region).neuropool.net/"} else {$null}
                        Name          = $Name
                        Penalty       = 0
                        PenaltyFactor = 1
						Disabled      = $false
						HasMinerExclusions = $false
                        Price_0       = 0.0
						Price_Bias    = 0.0
						Price_Unbias  = 0.0
                        Wallet        = $Pool_Wallet.wallet
                        Worker        = "{workername:$Worker}"
                        Email         = $Email
                    }
                }
            }
            $Pool_SSL = $true
        }
    }
}
