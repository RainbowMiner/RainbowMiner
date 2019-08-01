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
    [PSCustomObject]@{coin = "Arqma";         symbol = "ARQ";   algo = "CnTurtle";    port = 10320; fee = 0.9; rpc = "arqma"}
    [PSCustomObject]@{coin = "Arqma+Iridium"; symbol = "ARQ";   algo = "CnTurtle";    port = 10630; fee = 0.9; rpc = "iridium"; symbol2 = "IRD"}
    [PSCustomObject]@{coin = "Arqma+Plenteum";symbol = "ARQ";   algo = "CnTurtle";    port = 10630; fee = 0.9; rpc = "arqple"; symbol2 = "PLE"}
    [PSCustomObject]@{coin = "Arqma+Turtle";  symbol = "ARQ";   algo = "CnTurtle";    port = 10320; fee = 0.9; rpc = "arqma"; symbol2 = "TRTL"}
    [PSCustomObject]@{coin = "Arqma+CyprusCoin";symbol = "ARQ"; algo = "CnTurtle";    port = 10670; fee = 0.9; rpc = "cypruscoin"; symbol2 = "XCY"}
    [PSCustomObject]@{coin = "BitTube";       symbol = "TUBE";  algo = "CnSaber";     port = 10280; fee = 0.9; rpc = "tube"}
    [PSCustomObject]@{coin = "Conceal";       symbol = "CCX";   algo = "CnConceal";   port = 10361; fee = 0.9; rpc = "conceal"}
    [PSCustomObject]@{coin = "Graft";         symbol = "GRFT";  algo = "CnRwz";       port = 10100; fee = 0.9; rpc = "graft"}
    [PSCustomObject]@{coin = "Haven";         symbol = "XHV";   algo = "CnHaven";     port = 10140; fee = 0.9; rpc = "haven"}
    [PSCustomObject]@{coin = "Haven+Bloc";    symbol = "XHV";   algo = "CnHaven";     port = 10450; fee = 0.9; rpc = "havenbloc";  symbol2 = "BLOC"}
    [PSCustomObject]@{coin = "Loki";          symbol = "LOKI";  algo = "RxLoki";      port = 10111; fee = 0.9; rpc = "loki"}
    [PSCustomObject]@{coin = "Masari";        symbol = "MSR";   algo = "CnHalf";      port = 10150; fee = 0.9; rpc = "masari"}
    [PSCustomObject]@{coin = "Monero";        symbol = "XMR";   algo = "CnR";         port = 10190; fee = 0.9; rpc = "monero"}
    [PSCustomObject]@{coin = "Qrl";           symbol = "QRL";   algo = "CnV7";        port = 10370; fee = 0.9; rpc = "qrl"}
    [PSCustomObject]@{coin = "Ryo";           symbol = "RYO";   algo = "CnGpu";       port = 10270; fee = 0.9; rpc = "ryo"}
    [PSCustomObject]@{coin = "Scala";         symbol = "XLA";   algo = "CnHalf";      port = 10130; fee = 0.9; rpc = "scala"}
    [PSCustomObject]@{coin = "Scala";         symbol = "XTC";   algo = "CnHalf";      port = 10130; fee = 0.9; rpc = "scala"}
    [PSCustomObject]@{coin = "Sumocoin";      symbol = "SUMO";  algo = "CnGpu";       port = 10610; fee = 0.9; rpc = "sumo"}
    [PSCustomObject]@{coin = "Swap";          symbol = "XWP";   algo = "Cuckaroo29s"; port = 10441; fee = 0.9; rpc = "swap"; divisor = 32}
    [PSCustomObject]@{coin = "Triton";        symbol = "XTRI";  algo = "CnLiteV7";    port = 10600; fee = 0.9; rpc = "triton"}
    [PSCustomObject]@{coin = "Triton+NibbleClassic";symbol = "XTRI";algo = "CnTurtle";port = 10600; fee = 0.9; rpc = "triton"; symbol2 = "NBX"}
    [PSCustomObject]@{coin = "Turtle";        symbol = "TRTL";  algo = "CnTurtle";    port = 10380; fee = 0.9; rpc = "turtlecoin"}
    [PSCustomObject]@{coin = "uPlexa";        symbol = "UPX";   algo = "CnUpx";       port = 10470; fee = 0.9; rpc = "uplexa"}
    [PSCustomObject]@{coin = "WowNero";       symbol = "XCASH"; algo = "CnHeavyX";    port = 10440; fee = 0.9; rpc = "xcash"}
    [PSCustomObject]@{coin = "Xcash";         symbol = "WOW";   algo = "RxWow";       port = 10660; fee = 0.9; rpc = "wownero"}
)

$Pools_Data | Where-Object {($Wallets."$($_.symbol)" -and (-not $_.symbol2 -or $Wallets."$($_.symbol2)")) -or $InfoOnly} | ForEach-Object {
    $Pool_Algorithm = $_.algo
    $Pool_Currency  = $_.symbol
    $Pool_Currency2 = $_.symbol2
    $Pool_Fee       = $_.fee
    $Pool_Port      = $_.port
    $Pool_RpcPath   = $_.rpc

    $Pool_Divisor   = if ($_.divisor) {$_.divisor} else {1}
    $Pool_HostPath  = if ($_.host) {$_.host} else {$Pool_RpcPath}

    $Pool_Algorithm_Norm = Get-Algorithm $Pool_Algorithm

    $Pool_Request  = [PSCustomObject]@{}
    $Pool_Ports    = @([PSCustomObject]@{})

    $ok = $true
    if (-not $InfoOnly) {
        try {
            $Pool_Request = Invoke-RestMethodAsync "https://$($Pool_RpcPath).herominers.com/api/stats" -tag $Name -timeout 15 -cycletime 120
            $Pool_Ports   = Get-PoolPortsFromRequest $Pool_Request -mCPU "" -mGPU "high" -mRIG "(cloud|very high|nicehash)"
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

        $timestamp  = Get-UnixTimestamp

        $Pool_StatFn = "$($Name)_$($Pool_Currency)$(if ($Pool_Currency2) {$Pool_Currency2})_Profit"
        $dayData     = -not (Test-Path "Stats\Pools\$($Pool_StatFn).txt")
        $Pool_Reward = if ($dayData) {"Day"} else {"Live"}
        $Pool_Data   = Get-PoolDataFromRequest $Pool_Request -Currency $Pool_Currency -Divisor $Pool_Divisor -Timestamp $timestamp -addDay:$dayData -addBlockData

        if ($Pool_Currency2) {
            $Pool_Data2 = Get-PoolDataFromRequest $Pool_Request -Currency $Pool_Currency2 -Divisor $Pool_Divisor -Timestamp $timestamp -addDay:$dayData -NetworkField "childnetwork" -LastblockField "lastchildblock" -priceFromSession
            $Pool_Data.$Pool_Reward.reward += $Pool_Data2.$Pool_Reward.reward
        }

        $Stat = Set-Stat -Name $Pool_StatFn -Value ($Pool_Data.$Pool_Reward.reward/1e8) -Duration $(if ($dayData) {New-TimeSpan -Days 1} else {$StatSpan}) -HashRate $Pool_Data.$Pool_Reward.hashrate -BlockRate $Pool_Data.BLK -ChangeDetection $dayData -Quiet
    }
    
    if (($ok -and ($AllowZero -or $Pool_Data.Live.hashrate -gt 0)) -or $InfoOnly) {
        $Pool_SSL = $false
        foreach ($Pool_Port in $Pool_Ports) {
            if ($Pool_Port) {
                [PSCustomObject]@{
                    Algorithm     = $Pool_Algorithm_Norm
                    CoinName      = $_.coin
                    CoinSymbol    = $Pool_Currency
                    Currency      = $Pool_Currency
                    Price         = $Stat.$StatAverage #instead of .Live
                    StablePrice   = $Stat.Week
                    MarginOfError = $Stat.Week_Fluctuation
                    Protocol      = "stratum+$(if ($Pool_SSL) {"ssl"} else {"tcp"})"
                    Host          = "$($Pool_HostPath).herominers.com"
                    Port          = $Pool_Port.CPU
                    Ports         = $Pool_Port
                    User          = "$($Wallets.$Pool_Currency){diff:$(if ($Pool_Request.config.fixedDiffEnabled) {$Pool_Request.config.fixedDiffSeparator})`$difficulty}"
                    Pass          = "$(if ($Pool_Currency2) {"$($Wallets.$Pool_Currency2)@"}){workername:$Worker}"
                    Region        = $Pool_Region_Default
                    SSL           = $Pool_SSL
                    Updated       = $Stat.Updated
                    PoolFee       = $Pool_Fee
                    Workers       = $Pool_Data.Workers
                    Hashrate      = $Stat.HashRate_Live
                    TSL           = $Pool_Data.TSL
                    BLK           = $Stat.BlockRate_Average
                }
            }
            $Pool_SSL = $true
        }
    }
}
