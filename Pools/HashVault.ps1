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

$Pool_Region_Default = Get-Region "eu"

$Pools_Data = @(
    [PSCustomObject]@{symbol = "AEON";  port = 3333; fee = 0.9; rpc = "aeon"} #pool.aeon.hashvault.pro:3333
    [PSCustomObject]@{symbol = "BLOC";  port = 2222; fee = 0.9; rpc = "bloc"} #pool.bloc.hashvault.pro:2222
    [PSCustomObject]@{symbol = "CCX";   port = 3333; fee = 0.9; rpc = "conceal"} #pool.conceal.hashvault.pro:3333
    [PSCustomObject]@{symbol = "GRFT";  port = 3333; fee = 0.9; rpc = "graft"} #pool.graft.hashvault.pro:3333
    [PSCustomObject]@{symbol = "IRD";   port = 4445; fee = 0.9; rpc = "iridium"} #pool.iridium.hashvault.pro:4445
    [PSCustomObject]@{symbol = "LTHN";  port = 3333; fee = 0.9; rpc = "lethean"} #pool.lethean.hashvault.pro:3333
    [PSCustomObject]@{symbol = "LOKI";  port = 3333; fee = 0.9; rpc = "loki"} #pool.loki.hashvault.pro:3333
    [PSCustomObject]@{symbol = "MSR";   port = 3333; fee = 0.9; rpc = "masari"} #pool.masari.hashvault.pro:3333
    [PSCustomObject]@{symbol = "RYO";   port = 3333; fee = 0.9; rpc = "ryo"} #pool.ryo.hashvault.pro:3333
    [PSCustomObject]@{symbol = "SUMO";  port = 3333; fee = 0.9; rpc = "sumo"} #pool.sumo.hashvault.pro:3333
    [PSCustomObject]@{symbol = "TUBE";  port = 3333; fee = 0.9; rpc = "bittube"} #pool.bittube.hashvault.pro:3333
    [PSCustomObject]@{symbol = "TRTL";  port = 3333; fee = 0.9; rpc = "turtle"} #pool.turtle.hashvault.pro:3333
    [PSCustomObject]@{symbol = "WOW";   port = 3333; fee = 0.9; rpc = "wownero"} #pool.wownero.hashvault.pro:3333
    [PSCustomObject]@{symbol = "XTNC";  port = 3333; fee = 0.9; rpc = "xtendcash"} #pool.xtendcash.hashvault.pro:3333
    [PSCustomObject]@{symbol = "XEQ";   port = 3333; fee = 0.9; rpc = "equilibria"} #pool.equilibria.hashvault.pro:3333
    [PSCustomObject]@{symbol = "XHV";   port = 3333; fee = 0.9; rpc = "haven"} #pool.haven.hashvault.pro:3333
    [PSCustomObject]@{symbol = "XMR";   port = 3333; fee = 0.9; rpc = "monero"} #pool.hashvault.pro:3333
    [PSCustomObject]@{symbol = "XWP";   port = 3333; fee = 0.9; rpc = "swap"} #pool.swap.hashvault.pro:3333
)

$Pools_Data | Where-Object {$Wallets."$($_.symbol)" -or $InfoOnly} | ForEach-Object {
    $Pool_Coin      = Get-Coin $_.symbol
    $Pool_Currency  = $_.symbol
    $Pool_Fee       = $_.fee
    $Pool_Port      = $_.port
    $Pool_RpcPath   = $_.rpc

    $Pool_Divisor   = if ($_.divisor) {$_.divisor} else {1}
    $Pool_HostPath  = "pool$(if ($_.symbol -ne "XMR") {".$Pool_RpcPath"}).hashvault.pro"

    $Pool_Algorithm_Norm = Get-Algorithm $Pool_Coin.Algo

    $Pool_Request       = [PSCustomObject]@{}
    $Pool_PortsRequest  = [PSCustomObject]@{}
    $Pool_Blocks        = @([PSCustomObject]@{})
    $Pool_Ports         = @([PSCustomObject]@{})

    $ok = $true
    if (-not $InfoOnly) {
        try {
            $Pool_Request = Invoke-RestMethodAsync "https://$($Pool_RpcPath).hashvault.pro/api/stats" -tag $Name -timeout 15 -cycletime 120
            $Pool_Blocks = Invoke-RestMethodAsync "https://$($Pool_RpcPath).hashvault.pro/api/pool/blocks" -tag $Name -timeout 15 -cycletime 120
            $Pool_PortsRequest = Invoke-RestMethodAsync "https://$($Pool_RpcPath).hashvault.pro/api/pool/ports" -tag $Name -timeout 15 -cycletime 86400
            $Pool_Ports   = Get-PoolPortsFromRequest $Pool_PortsRequest.pplns -mCPU "low" -mGPU "mid" -mRIG "(high|ultra)" -descField "description"
        }
        catch {
            if ($Error.Count){$Error.RemoveAt(0)}
            Write-Log -Level Warn "Pool API ($Name) for $Pool_Currency has failed."
            $ok = $false
        }

        if (-not ($Pool_Ports | Where-Object {$_} | Measure-Object).Count) {$ok = $false}
    }

    if ($ok -and -not $InfoOnly) {
        $Pool_Fee = $Pool_Request.config.pplns_fee

        $timestamp  = Get-UnixTimestamp
        $timestamp24h = ($timestamp-86400)*1000

        $coinUnits    = [decimal]$Pool_Request.config.sigDivisor
        $diffLive     = [decimal]$Pool_Request.network_statistics.difficulty
        $reward       = [decimal]$Pool_Request.network_statistics.value
        $profitLive   = if ($diffLive) {86400/$diffLive*$reward/$coinUnits} else {0}
        $lastBTCPrice = if ($Session.Rates.$Pool_Currency) {1/$Session.Rates.$Pool_Currency} else {[decimal]$Pool_Request.market.price_btc}

        $blocks_measure = $Pool_Blocks | Where-Object {$_.ts -ge $timestamp24h} | Select-Object -ExpandProperty ts | Measure-Object -Minimum -Maximum
        $Pool_BLK = [int]$($(if ($blocks_measure.Count -gt 1 -and ($blocks_measure.Maximum - $blocks_measure.Minimum)) {86400000/($blocks_measure.Maximum - $blocks_measure.Minimum)} else {1})*$blocks_measure.Count)

        $Pool_StatFn = "$($Name)_$($Pool_Currency)_Profit"
        $dayData     = -not (Test-Path "Stats\Pools\$($Pool_StatFn).txt")

        $Stat = Set-Stat -Name $Pool_StatFn -Value ($profitLive*$lastBTCPrice) -Duration $(if ($dayData) {New-TimeSpan -Days 1} else {$StatSpan}) -HashRate $(if ($dayData) {$Pool_Request.pool_statistics.avg24} else {$Pool_Request.pool_statistics.hashRate}) -BlockRate $Pool_BLK -ChangeDetection $false -Quiet
    }
    
    if (($ok -and ($AllowZero -or $Pool_Request.pool_statistics.hashRate -gt 0)) -or $InfoOnly) {
        $Pool_SSL = $false
        $Pool_Wallet = Get-WalletWithPaymentId $Wallets.$Pool_Currency -asobject -pidchar '.'
        foreach ($Pool_Port in $Pool_Ports) {
            if ($Pool_Port) {
                [PSCustomObject]@{
                    Algorithm     = $Pool_Algorithm_Norm
                    CoinName      = $Pool_Coin.Name
                    CoinSymbol    = $Pool_Currency
                    Currency      = $Pool_Currency
                    Price         = $Stat.$StatAverage #instead of .Live
                    StablePrice   = $Stat.Week
                    MarginOfError = $Stat.Week_Fluctuation
                    Protocol      = "stratum+$(if ($Pool_SSL) {"ssl"} else {"tcp"})"
                    Host          = $Pool_HostPath
                    Port          = $Pool_Port.CPU
                    Ports         = $Pool_Port
                    User          = "$($Pool_Wallet.wallet)$(if ($Pool_Wallet.difficulty) {"{diff:+`$difficulty}"})"
                    Pass          = "{workername:$Worker}"
                    Region        = $Pool_Region_Default
                    SSL           = $Pool_SSL
                    Updated       = $Stat.Updated
                    PoolFee       = $Pool_Fee
                    Workers       = $Pool_Request.pool_statistics.miners
                    Hashrate      = $Stat.HashRate_Live
                    TSL           = $timestamp - $Pool_Request.pool_statistics.lastBlockFoundTime
                    BLK           = $Stat.BlockRate_Average
                    AlgorithmList = if ($Pool_Algorithm_Norm -match "-") {@($Pool_Algorithm_Norm, ($Pool_Algorithm_Norm -replace '\-.*$'))}else{@($Pool_Algorithm_Norm)}
                    Name          = $Name
                    Penalty       = 0
                    PenaltyFactor = 1
                    Wallet        = $Pool_Wallet.wallet
                    Worker        = "{workername:$Worker}"
                    Email         = $Email
                }
            }
            $Pool_SSL = $true
        }
    }
}
