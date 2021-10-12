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
    [PSCustomObject]@{symbol = "AEON";  port = 10651; fee = 0.9; rpc = "aeon"; region = @("de","fi","hk")}
    [PSCustomObject]@{symbol = "ARQ";   port = 10641; fee = 0.9; rpc = "arqma"; region = @("de","fi","ca","us","hk","sg")}
    [PSCustomObject]@{symbol = "BEAM";  port = 10231; fee = 0.9; rpc = "beam"; region = @("de","fi","ca","us","hk","sg")}
    [PSCustomObject]@{symbol = "TUBE";  port = 10281; fee = 0.9; rpc = "bittube"; region = @("de","fi","ca","us","hk","sg")}
    [PSCustomObject]@{symbol = "CCX";   port = 10361; fee = 0.9; rpc = "conceal"; region = @("de","fi","ca","us","hk","sg")}
    [PSCustomObject]@{symbol = "CFX";   port = 10221; fee = 0.9; rpc = "conflux"; region = @("de","fi","ca","us","hk","sg")}
    [PSCustomObject]@{symbol = "CTXC";  port = 10321; fee = 0.9; rpc = "cortex"; region = @("de","fi","ca","hk","sg")}
    [PSCustomObject]@{symbol = "DERO";  port = 10121; fee = 0.9; rpc = "dero"; region = @("de","fi","ca","us","hk","sg")}
    [PSCustomObject]@{symbol = "ERG";   port = 10251; fee = 0.9; rpc = "ergo"; region = @("de","fi","ca","us","hk","sg")}
    [PSCustomObject]@{symbol = "ETC";   port = 10161; fee = 0.9; rpc = "etc"; region = @("de","fi","ca","hk","sg")}
    [PSCustomObject]@{symbol = "ETH";   port = 10201; fee = 0.9; rpc = "ethereum"; region = @("de","fi","ca","hk","sg")}
    [PSCustomObject]@{symbol = "EXP";   port = 10181; fee = 0.9; rpc = "expanse"; region = @("de","fi","ca","hk","sg")}
    #[PSCustomObject]@{symbol = "GRIN-SEC";port = 10301; fee = 0.9; rpc = "grin"; region = @("de","fi","ca","us","hk","sg")}
    [PSCustomObject]@{symbol = "GRIN-PRI";port = 10301; fee = 0.9; rpc = "grin"; region = @("de","fi","ca","us","hk","sg")}
    [PSCustomObject]@{symbol = "XHV";   port = 10451; fee = 0.9; rpc = "haven"; region = @("de","fi","ca","us","hk","sg")}
    [PSCustomObject]@{symbol = "KVA";   port = 10141; fee = 0.9; rpc = "kevacoin"; region = @("de","fi","ca","hk","sg")}
    [PSCustomObject]@{symbol = "XMR";   port = 10191; fee = 0.9; rpc = "monero"; region = @("de","fi","ca","us","hk","sg")}
    [PSCustomObject]@{symbol = "XMV";   port = 10151; fee = 0.9; rpc = "monerov"; region = @("de","fi","ca","us","hk","sg")}
    #[PSCustomObject]@{symbol = "MWC-SEC";port = 10311; fee = 0.9; rpc = "mwc"; region = @("de","fi","ca","us","hk","sg")}
    [PSCustomObject]@{symbol = "MWC-PRI";port = 10311; fee = 0.9; rpc = "mwc"; region = @("de","fi","ca","us","hk","sg")}
    [PSCustomObject]@{symbol = "QRL";   port = 10371; fee = 0.9; rpc = "qrl"; region = @("de","fi","ca","us","hk","sg")}
    [PSCustomObject]@{symbol = "RVN";   port = 10241; fee = 0.9; rpc = "ravencoin"; region = @("de","fi","ca","us","hk","sg")}
    [PSCustomObject]@{symbol = "XLA";   port = 10131; fee = 0.9; rpc = "scala"; region = @("de","fi","ca","us","hk","sg")}
    [PSCustomObject]@{symbol = "XWP";   port = 10441; fee = 0.9; rpc = "swap"; region = @("de","fi","ca","us","hk","sg")}
    [PSCustomObject]@{symbol = "TRTL";  port = 10381; fee = 0.9; rpc = "turtlecoin"; region = @("de","fi","ca","us","hk","sg")}
    [PSCustomObject]@{symbol = "UPX";   port = 10471; fee = 0.9; rpc = "uplexa"; region = @("de","fi","ca","us","hk","sg")}
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

        $timestamp = Get-UnixTimestamp

        if ($Pool_Request.config.soloMiningPrefix -and $Wallets.$Pool_Currency -match "^$($Pool_Request.config.soloMiningPrefix)") {
            $Pool_BlockField = "solo"
            $Pool_Workers    = [int]$Pool_Request.pool.soloWorkers
            $Pool_Hashrate   = [decimal]$Pool_Request.pool.soloHashrate
            $Pool_TSL        = [int]($timestamp - ([decimal]$PooL_Request.pool.stats.lastSoloBlockFound/1000))
        } else {
            $Pool_BlockField = "blocks"
            $Pool_Workers    = [int]$Pool_Request.pool.workers
            $Pool_Hashrate   = [decimal]$Pool_Request.pool.hashrate
            $Pool_TSL        = [int]($timestamp - ([decimal]$PooL_Request.pool.stats.lastBlockFound/1000))
        }

        $Pool_BLK = [int]($Pool_Request.charts.blocks.PSObject.Properties.Value | Select-Object -Last 2 | Foreach-Object {$_.$Pool_BlockField} | Measure-Object -Average).Average

        $Stat = Set-Stat -Name "$($Name)_$($_.symbol)_Profit" -Value 0 -Duration $StatSpan -HashRate $Pool_Hashrate -BlockRate $Pool_BLK -ChangeDetection $false -Quiet

        if (-not $Stat.HashRate_Live -and -not $AllowZero) {return}
    }
    
    if ($ok -or $InfoOnly) {
        $Pool_SSL = $false
        $Pool_Wallet = Get-WalletWithPaymentId $Wallets.$Pool_Currency -asobject
        foreach ($Pool_Port in $Pool_Ports) {
            if ($Pool_Port) {
                $First = $true
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
                        Host          = "$(if (-not $First) {"$($Pool_Region)."})$($Pool_HostPath).herominers.com"
                        Port          = if ($Pool_Port.CPU -ne $null) {$Pool_Port.CPU} else {$_.port}
                        Ports         = if ($Pool_Port.CPU -ne $null) {$Pool_Port} else {$null}
                        User          = "$($Pool_Wallet.wallet)$(if ($Pool_Request.config.fixedDiffEnabled) {if ($Pool_Wallet.difficulty) {"$($Pool_Request.config.fixedDiffSeparator)$($Pool_Wallet.difficulty)"} else {"{diff:$($Pool_Request.config.fixedDiffSeparator)`$difficulty}"}})"
                        Pass          = "{workername:$Worker}"
                        Region        = $Pool_RegionsTable[$Pool_Region]
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
						Price_Bias    = 0.0
						Price_Unbias  = 0.0
                        Wallet        = $Pool_Wallet.wallet
                        Worker        = "{workername:$Worker}"
                        Email         = $Email
                    }
                    $First = $false
                }
            }
            $Pool_SSL = $true
        }
    }
}
