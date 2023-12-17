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

$Pool_AllRegions = @("de","fi","ru","ca","us","br","hk","kr","in","sg","tr","au")
[hashtable]$Pool_RegionsTable = @{}
$Pool_AllRegions | Foreach-Object {$Pool_RegionsTable.$_ = Get-Region $_}

$Pools_Data = @(
    [PSCustomObject]@{symbol = "ALPH";  port = 1199; fee = 0.0; rpc = "alephium"; region = $Pool_AllRegions; pass = "x"}
    [PSCustomObject]@{symbol = "BEAM";  port = 1130; fee = 0.9; rpc = "beam"; region = $Pool_AllRegions}
    [PSCustomObject]@{symbol = "CCX";   port = 1115; fee = 0.9; rpc = "conceal"; region = $Pool_AllRegions}
    [PSCustomObject]@{symbol = "CFX";   port = 1170; fee = 0.9; rpc = "conflux"; region = $Pool_AllRegions}
    [PSCustomObject]@{symbol = "CTXC";  port = 1155; fee = 0.9; rpc = "cortex"; region = $Pool_AllRegions; cycles = 42}
    [PSCustomObject]@{symbol = "CLORE"; port = 1163; fee = 0.9; rpc = "clore"; region = $Pool_AllRegions}
    [PSCustomObject]@{symbol = "DNX";   port = 1120; fee = 0.9; rpc = "dynex"; region = $Pool_AllRegions; MallobPort = 1119}
    [PSCustomObject]@{symbol = "ERG";   port = 1180; fee = 0.9; rpc = "ergo"; region = $Pool_AllRegions}
    [PSCustomObject]@{symbol = "ETC";   port = 1150; fee = 0.9; rpc = "etc"; region = $Pool_AllRegions}
    [PSCustomObject]@{symbol = "ETHW";  port = 1147; fee = 0.9; rpc = "ethw"; region = $Pool_AllRegions}
    [PSCustomObject]@{symbol = "FLUX";  port = 1200; fee = 0.9; rpc = "flux"; region = $Pool_AllRegions; wtmmode = "WTM"}
    [PSCustomObject]@{symbol = "GRIN-PRI";port = 1125; fee = 0.9; rpc = "grin"; region = $Pool_AllRegions; cycles = 32}
    [PSCustomObject]@{symbol = "XHV";   port = 1110; fee = 0.9; rpc = "haven"; region = $Pool_AllRegions}
    [PSCustomObject]@{symbol = "IRON";  port = 1145; fee = 0.0; rpc = "ironfish"; region = $Pool_AllRegions; pass = "x"}
    [PSCustomObject]@{symbol = "KAS";   port = 1206; fee = 0.9; rpc = "kaspa"; region = $Pool_AllRegions}
    [PSCustomObject]@{symbol = "XLA";   port = 1190; fee = 0.9; rpc = "scala"; region = $Pool_AllRegions}
    [PSCustomObject]@{symbol = "XMR";   port = 1111; fee = 0.9; rpc = "monero"; region = $Pool_AllRegions}
    [PSCustomObject]@{symbol = "NEOX";  port = 1202; fee = 0.9; rpc = "neoxa"; region = $Pool_AllRegions}
    [PSCustomObject]@{symbol = "XNA";   port = 1160; fee = 0.9; rpc = "neurai"; region = $Pool_AllRegions}
    [PSCustomObject]@{symbol = "QRL";   port = 1166; fee = 0.9; rpc = "qrl"; region = $Pool_AllRegions}
    [PSCustomObject]@{symbol = "RVN";   port = 1140; fee = 0.9; rpc = "ravencoin"; region = $Pool_AllRegions; diffFactor = [Math]::Pow(2,32)}
    [PSCustomObject]@{symbol = "ZEPH";  port = 1123; fee = 0.9; rpc = "zephyr"; region = $Pool_AllRegions}
    [PSCustomObject]@{symbol = "PYI";   port = 1177; fee = 0.9; rpc = "pyrin"; region = $Pool_AllRegions}
    [PSCustomObject]@{symbol = "KLS";   port = 1195; fee = 0.9; rpc = "karlsen"; region = $Pool_AllRegions}

    #[PSCustomObject]@{symbol = "AEON";  port = 1145; fee = 0.9; rpc = "aeon"; region = @("de","fi","hk")}
    #[PSCustomObject]@{symbol = "ARQ";   port = 1143; fee = 0.9; rpc = "arqma"; region = $Pool_AllRegions}
    #[PSCustomObject]@{symbol = "ETHF";  port = 1204; fee = 0.9; rpc = "ethf"; region = $Pool_AllRegions}
    #[PSCustomObject]@{symbol = "TUBE";  port = 1120; fee = 0.9; rpc = "bittube"; region = $Pool_AllRegions; cycles = 40}
    #[PSCustomObject]@{symbol = "KVA";   port = 1163; fee = 0.9; rpc = "kevacoin"; region = @("de","fi","ca","hk","sg")}    
    #[PSCustomObject]@{symbol = "XWP";   port = 1123; fee = 0.9; rpc = "swap"; region = $Pool_AllRegions; cycles = 32}
    #[PSCustomObject]@{symbol = "UPX";   port = 1177; fee = 0.9; rpc = "uplexa"; region = $Pool_AllRegions}
    #[PSCustomObject]@{symbol = "DERO";  port = 1117; fee = 0.9; rpc = "dero"; region = $Pool_AllRegions}
    #[PSCustomObject]@{symbol = "EXP";   port = 10181; fee = 0.9; rpc = "expanse"; region = $Pool_AllRegions}
    #[PSCustomObject]@{symbol = "TRTL";  port = 1160; fee = 0.9; rpc = "turtlecoin"; region = $Pool_AllRegions}
    #[PSCustomObject]@{symbol = "GRIN-SEC";port = 10301; fee = 0.9; rpc = "grin"; region = $Pool_AllRegions}
    #[PSCustomObject]@{symbol = "XMV";   port = 10151; fee = 0.9; rpc = "monerov"; region = $Pool_AllRegions; diffFactor = 16}
    #[PSCustomObject]@{symbol = "MWC-PRI";port = 1128; fee = 0.9; rpc = "mwc"; region = $Pool_AllRegions; cycles = 31}
    #[PSCustomObject]@{symbol = "MWC-SEC";port = 10311; fee = 0.9; rpc = "mwc"; region = $Pool_AllRegions}
    #[PSCustomObject]@{symbol = "WOW";   port = 10661; fee = 0.9; rpc = "wownero"; region = @("de","fi","ca","us","hk","sg")}
    #[PSCustomObject]@{symbol = "XEQ";   port = 1195; fee = 0.9; rpc = "equilibria"; region = $Pool_AllRegions}
)

$Pools_Data | Where-Object {$Pool_Currency = $_.symbol -replace "-.+$";$Wallets.$Pool_Currency -or $InfoOnly} | ForEach-Object {
    $Pool_Coin      = Get-Coin $_.symbol
    $Pool_Fee       = $_.fee
    $Pool_Port      = $_.port
    $Pool_RpcPath   = $_.rpc
    $Pool_Regions   = $_.region

    $Pool_Divisor   = 1
    $Pool_HostPath  = if ($_.host) {$_.host} else {$Pool_RpcPath}

    $Pool_Algorithm_Norm = Get-Algorithm $Pool_Coin.algo

    $Pool_EthProxy = if ($Pool_Algorithm_Norm -match $Global:RegexAlgoHasEthproxy) {"ethproxy"} elseif ($Pool_Algorithm_Norm -match $Global:RegexAlgoIsProgPow) {"stratum"} else {$null}

    $Pool_Request  = [PSCustomObject]@{}
    $Pool_Ports    = @([PSCustomObject]@{})

    $Pool_Password = "$(if ($_.pass) {$_.pass} else {"{workername:$Worker}"})"
    $Pool_UserWN   = "$(if ($_.pass) {".{workername:$Worker}"})"

    $ok = $true
    try {
        $Pool_Request = Invoke-RestMethodAsync "https://$($Pool_RpcPath).herominers.com/api/stats" -tag $Name -timeout 15 -cycletime 120
        $Pool_Ports   = Get-PoolPortsFromRequest $Pool_Request -mCPU "" -mGPU "(modern|mid)" -mRIG "(higher|high-end|cloud|nicehash)"
        if ($Pool_Request.config.cycleLength) {$Pool_Divisor = $Pool_Request.config.cycleLength}
    }
    catch {
        if ($Error.Count){$Error.RemoveAt(0)}
        Write-Log -Level Warn "Pool API ($Name) for $Pool_Currency has failed. "
        $ok = $false
    }

    if (-not ($Pool_Ports | Where-Object {$_} | Measure-Object).Count) {$ok = $false}


    if ($ok -and -not $InfoOnly) {
        $Pool_Fee = $Pool_Request.config.fee

        if ($Pool_Request.config.soloMiningPrefix -and $Wallets.$Pool_Currency -match "^$($Pool_Request.config.soloMiningPrefix)") {
            $blkTime         = if ($Pool_Request.config.avgDifficultyTargetEnabled) {$Pool_Request.network.difficultyTarget} else {$Pool_Request.config.coinDifficultyTarget}
            $diffFactor      = if ($_.diffFactor) {$_.diffFactor} else {1}

            $Pool_SoloMining = $true
            $Pool_Diff       = if ($_.cycles -and [bool]$Pool_Request.network.PSObject.Properties["hashrate"]) {[double]$Pool_Request.network.hashrate."$($_.cycles)" * $blkTime} else {[double]$Pool_Request.network.difficulty * $(if ($_.cycles) {$_.cycles} else {1})}
            $Pool_Diff      *= $diffFactor / [Math]::Pow(2,32)

            $Stat = Set-Stat -Name "$($Name)_$($_.symbol)_Profit" -Value 0 -Duration $StatSpan -Difficulty $Pool_Diff -ChangeDetection $false -Quiet
        } else {
            $timestamp       = Get-UnixTimestamp
            $timestamp24h    = $timestamp - 86400

            $Pool_SoloMining = $false
            $Pool_Workers    = [int]$Pool_Request.pool.workers
            $Pool_Hashrate   = [decimal]$Pool_Request.pool.hashrate
            $blocks          = $Pool_Request.pool.blocks | Where-Object {$_ -match "^[0-9a-fx]+:.*?(\d{10}):" -and ($Matches[1] -ge $timestamp24h)} | Foreach-Object {$Matches[1]}
            $blocks_measure  = $blocks | Where-Object {$_ -gt $timestamp24h} | Measure-Object -Minimum -Maximum
            $Pool_BLK        = [int]$($(if ($blocks_measure.Count -gt 1 -and ($blocks_measure.Maximum - $blocks_measure.Minimum)) {86400/($blocks_measure.Maximum - $blocks_measure.Minimum)} else {1})*$blocks_measure.Count)
            $Pool_TSL        = [int]($timestamp - ([decimal]$PooL_Request.pool.stats.lastBlockFound/1000))

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
                        Host          = "$($Pool_Region).$($Pool_HostPath).herominers.com"
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
                        Mallob        = if ($_.mallobport) {"$($Pool_Region).$($Pool_HostPath).herominers.com:$($_.mallobport)"} else {$null}
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
