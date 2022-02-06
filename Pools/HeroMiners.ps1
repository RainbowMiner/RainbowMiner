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
@("de","fi","ca","us","hk","sg","tr") | Foreach-Object {$Pool_RegionsTable.$_ = Get-Region $_}

$Pools_Data = @(
    [PSCustomObject]@{symbol = "AEON";  port = 1145; fee = 0.9; rpc = "aeon"; region = @("de","fi","hk")}
    [PSCustomObject]@{symbol = "ALPH";  port = 1199; fee = 0.0; rpc = "alephium"; region = @("de","fi","ca","us","hk","sg","tr")}
    [PSCustomObject]@{symbol = "ARQ";   port = 1143; fee = 0.9; rpc = "arqma"; region = @("de","fi","ca","us","hk","sg","tr")}
    [PSCustomObject]@{symbol = "BEAM";  port = 1130; fee = 0.9; rpc = "beam"; region = @("de","fi","ca","us","hk","sg","tr")}
    [PSCustomObject]@{symbol = "TUBE";  port = 1120; fee = 0.9; rpc = "bittube"; region = @("de","fi","ca","us","hk","sg","tr"); diffFactor = 40}
    [PSCustomObject]@{symbol = "CCX";   port = 1115; fee = 0.9; rpc = "conceal"; region = @("de","fi","ca","us","hk","sg","tr")}
    [PSCustomObject]@{symbol = "CFX";   port = 1170; fee = 0.9; rpc = "conflux"; region = @("de","fi","ca","us","hk","sg","tr")}
    [PSCustomObject]@{symbol = "CTXC";  port = 1155; fee = 0.9; rpc = "cortex"; region = @("de","fi","ca","hk","sg","tr"); diffFactor = 42}
    [PSCustomObject]@{symbol = "DERO";  port = 1117; fee = 0.9; rpc = "dero"; region = @("de","fi","ca","us","hk","sg","tr")}
    [PSCustomObject]@{symbol = "XEQ";   port = 1195; fee = 0.9; rpc = "equilibria"; region = @("de","fi","ca","hk","sg","tr")}
    [PSCustomObject]@{symbol = "ERG";   port = 1180; fee = 0.9; rpc = "ergo"; region = @("de","fi","ca","us","hk","sg","tr")}
    [PSCustomObject]@{symbol = "ETC";   port = 1150; fee = 0.9; rpc = "etc"; region = @("de","fi","ca","us","hk","sg","tr")}
    [PSCustomObject]@{symbol = "ETH";   port = 1147; fee = 0.9; rpc = "ethereum"; region = @("de","fi","ca","us","hk","sg","tr")}
    [PSCustomObject]@{symbol = "FLUX";  port = 1200; fee = 0.9; rpc = "flux"; region = @("de","fi","ca","us","hk","sg","tr")}
    [PSCustomObject]@{symbol = "GRIN-PRI";port = 1125; fee = 0.9; rpc = "grin"; region = @("de","fi","ca","us","hk","sg","tr"); cycles = 32}
    [PSCustomObject]@{symbol = "XHV";   port = 1110; fee = 0.9; rpc = "haven"; region = @("de","fi","ca","us","hk","sg","tr")}
    [PSCustomObject]@{symbol = "KVA";   port = 1163; fee = 0.9; rpc = "kevacoin"; region = @("de","fi","ca","hk","sg")}
    [PSCustomObject]@{symbol = "XMR";   port = 1111; fee = 0.9; rpc = "monero"; region = @("de","fi","ca","us","hk","sg","tr")}
    [PSCustomObject]@{symbol = "MWC-PRI";port = 1128; fee = 0.9; rpc = "mwc"; region = @("de","fi","ca","us","hk","sg","tr"); cycles = 31}
    [PSCustomObject]@{symbol = "QRL";   port = 1166; fee = 0.9; rpc = "qrl"; region = @("de","fi","ca","us","hk","sg","tr")}
    [PSCustomObject]@{symbol = "RVN";   port = 1140; fee = 0.9; rpc = "ravencoin"; region = @("de","fi","ca","us","hk","sg","tr"); diffFactor = [Math]::Pow(2,32)}
    [PSCustomObject]@{symbol = "XLA";   port = 1190; fee = 0.9; rpc = "scala"; region = @("de","fi","ca","us","hk","sg","tr")}
    [PSCustomObject]@{symbol = "XWP";   port = 1123; fee = 0.9; rpc = "swap"; region = @("de","fi","ca","us","hk","sg","tr"); diffFactor = 32}
    [PSCustomObject]@{symbol = "TRTL";  port = 1160; fee = 0.9; rpc = "turtlecoin"; region = @("de","fi","ca","us","hk","sg","tr")}
    [PSCustomObject]@{symbol = "UPX";   port = 1177; fee = 0.9; rpc = "uplexa"; region = @("de","fi","ca","us","hk","sg","tr")}

    #[PSCustomObject]@{symbol = "EXP";   port = 10181; fee = 0.9; rpc = "expanse"; region = @("de","fi","ca","us","hk","sg","tr")}
    #[PSCustomObject]@{symbol = "GRIN-SEC";port = 10301; fee = 0.9; rpc = "grin"; region = @("de","fi","ca","us","hk","sg","tr")}
    #[PSCustomObject]@{symbol = "XMV";   port = 10151; fee = 0.9; rpc = "monerov"; region = @("de","fi","ca","us","hk","sg","tr"); diffFactor = 16}
    #[PSCustomObject]@{symbol = "MWC-SEC";port = 10311; fee = 0.9; rpc = "mwc"; region = @("de","fi","ca","us","hk","sg","tr")}
    #[PSCustomObject]@{symbol = "WOW";   port = 10661; fee = 0.9; rpc = "wownero"; region = @("de","fi","ca","us","hk","sg")}
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

    $ok = $true
    if (-not $InfoOnly) {
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
    }


    if ($ok -and -not $InfoOnly) {
        $Pool_Fee = $Pool_Request.config.fee

        if ($Pool_Request.config.soloMiningPrefix -and $Wallets.$Pool_Currency -match "^$($Pool_Request.config.soloMiningPrefix)") {
            $blkTime         = if ($Pool_Request.config.avgDifficultyTargetEnabled) {$Pool_Request.network.difficultyTarget} else {$Pool_Request.config.coinDifficultyTarget}
            $diffFactor      = if ($_.diffFactor) {$_.diffFactor} else {1}

            $Pool_SoloMining = $true
            $Pool_Diff       = if ($_.cycles) {[double]$Pool_Request.network.hashrate."$($_.cycles)" * $blkTime} else {[double]$Pool_Request.network.difficulty}
            $Pool_Diff      *= $diffFactor / [Math]::Pow(2,32)

            $Stat = Set-Stat -Name "$($Name)_$($_.symbol)_Profit" -Value 0 -Duration $StatSpan -Difficulty $Pool_Diff -ChangeDetection $false -Quiet
        } else {
            $timestamp       = Get-UnixTimestamp
            $timestamp24h    = $timestamp - 86400

            $Pool_SoloMining = $false
            $Pool_Workers    = [int]$Pool_Request.pool.workers
            $Pool_Hashrate   = [decimal]$Pool_Request.pool.hashrate
            $Pool_TSL        = [int]($timestamp - ([decimal]$PooL_Request.pool.stats.lastBlockFound/1000))
            $Pool_BLK        = ($Pool_Request.pool.blocks | Where-Object {$_ -match "^[0-9a-f]+:(\d+)" -and ($Matches[1] -ge $timestamp24h)} | Measure-Object).Count

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
                        User          = "$($Pool_Wallet.wallet)$(if ($Pool_Request.config.fixedDiffEnabled) {if ($Pool_Wallet.difficulty) {"$($Pool_Request.config.fixedDiffSeparator)$($Pool_Wallet.difficulty)"} else {"{diff:$($Pool_Request.config.fixedDiffSeparator)`$difficulty}"}})"
                        Pass          = "{workername:$Worker}"
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
                        WTMMode       = if ($Pool_Currency -eq "FLUX") {"WTM"} else {$null}
                        EthMode       = $Pool_EthProxy
                        Name          = $Name
                        Penalty       = 0
                        PenaltyFactor = 1
						Disabled      = $false
						HasMinerExclusions = $false
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
