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

$Pool_Region_Default = "eu"

[hashtable]$Pool_RegionsTable = @{}
@("eu","us","asia") | Foreach-Object {$Pool_RegionsTable.$_ = Get-Region $_}

$Pools_Data = @(
    [PSCustomObject]@{coin = "Aeon";        symbol = "AEON"; algo = "CnLiteV7";    port = 5541;  fee = 0.0; rpc = "aeon"}
    #[PSCustomObject]@{coin = "Alloy";       symbol = "XAO";  algo = "CnAlloy";     port = 5661;  fee = 0.0; rpc = "alloy"}
    #[PSCustomObject]@{coin = "Arqma";       symbol = "ARQ";  algo = "CnTurtle";    port = 3731;  fee = 0.0; rpc = "arq"}
    #[PSCustomObject]@{coin = "Arto";        symbol = "RTO";  algo = "CnArto";      port = 51201; fee = 0.0; rpc = "arto"}
    #[PSCustomObject]@{coin = "BBS";         symbol = "BBS";  algo = "CnLiteV7";    port = 19931; fee = 0.0; rpc = "bbs"}
    #[PSCustomObject]@{coin = "BitcoinNote"; symbol = "BTCN"; algo = "CnLiteV7";    port = 9732;  fee = 0.0; rpc = "btcn"}
    #[PSCustomObject]@{coin = "Bittorium";   symbol = "BTOR"; algo = "CnLiteV7";    port = 10401; fee = 0.0; rpc = "btor"; host = "bittorium"}
    [PSCustomObject]@{coin = "BitTube";     symbol = "TUBE"; algo = "CnSaber";     port = 5631;  fee = 0.0; rpc = "ipbc"; host = "tube"}
    #[PSCustomObject]@{coin = "Caliber";     symbol = "CAL";  algo = "CnV8";        port = 14101; fee = 0.0; rpc = "caliber"}
    #[PSCustomObject]@{coin = "CitiCash";    symbol = "CCH";  algo = "CnHeavy";     port = 4461;  fee = 0.0; rpc = "citi"}
    #[PSCustomObject]@{coin = "Elya";        symbol = "ELYA"; algo = "CnV7";        port = 50201; fee = 0.0; rpc = "elya"}
    [PSCustomObject]@{coin = "Graft";       symbol = "GRFT"; algo = "CnRwz";       port = 9111;  fee = 0.0; rpc = "graft"}
    #[PSCustomObject]@{coin = "Grin";        symbol = "GRIN"; algo = "Cuckarood29"; port = 6511;  fee = 0.0; rpc = "grin"; divisor = 32; regions = @("eu","us","asia"); diffdot = "+"; hashrate = "hashrate_ar"}
    [PSCustomObject]@{coin = "Haven";       symbol = "XHV";  algo = "CnHaven";     port = 5831;  fee = 0.0; rpc = "haven"}
    #[PSCustomObject]@{coin = "IPBC";        symbol = "IPBC"; algo = "CnSaber";     port = 5631;  fee = 0.0; rpc = "ipbc"; host = "ipbcrocks"}
    #[PSCustomObject]@{coin = "Iridium";     symbol = "IRD";  algo = "CnLiteV7";    port = 50501; fee = 0.0; rpc = "iridium"}
    #[PSCustomObject]@{coin = "Italo";       symbol = "ITA";  algo = "CnHaven";     port = 50701; fee = 0.0; rpc = "italo"}
    #[PSCustomObject]@{coin = "Lethean";     symbol = "LTHN"; algo = "CnR";         port = 8881;  fee = 0.0; rpc = "lethean"}
    #[PSCustomObject]@{coin = "Lines";       symbol = "LNS";  algo = "CnV7";        port = 50401; fee = 0.0; rpc = "lines"}
    #[PSCustomObject]@{coin = "Loki";        symbol = "LOKI"; algo = "CnTurtle";    port = 7731;  fee = 0.0; rpc = "loki"}
    [PSCustomObject]@{coin = "Masari";      symbol = "MSR";  algo = "CnHalf";      port = 3333;  fee = 0.0; rpc = "msr"; host = "masari"}
    [PSCustomObject]@{coin = "Monero";      symbol = "XMR";  algo = "CnR";         port = 4441;  fee = 0.0; rpc = "xmr"; host = "monero"}
    #[PSCustomObject]@{coin = "MoneroV";     symbol = "XMV";  algo = "CnV7";        port = 9221;  fee = 0.0; rpc = "monerov"}
    #[PSCustomObject]@{coin = "Niobio";      symbol = "NBR";  algo = "CnHeavy";     port = 5801;  fee = 0.0; rpc = "niobio"}
    #[PSCustomObject]@{coin = "Ombre";       symbol = "OMB";  algo = "CnHeavy";     port = 5571;  fee = 0.0; rpc = "ombre"}
    #[PSCustomObject]@{coin = "Qwerty";      symbol = "QWC";  algo = "CnHeavy";     port = 8261;  fee = 0.0; rpc = "qwerty"}
    #[PSCustomObject]@{coin = "Ryo";         symbol = "RYO";  algo = "CnGpu";       port = 52901; fee = 0.0; rpc = "ryo"}
    #[PSCustomObject]@{coin = "SafeX";       symbol = "SAFE"; algo = "CnV7";        port = 13701; fee = 0.0; rpc = "safex"}
    #[PSCustomObject]@{coin = "Saronite";    symbol = "XRN";  algo = "CnHeavy";     port = 11301; fee = 0.0; rpc = "saronite"}
    #[PSCustomObject]@{coin = "Solace";      symbol = "SOL";  algo = "CnHeavy";     port = 5001;  fee = 0.0; rpc = "solace"}
    #[PSCustomObject]@{coin = "Stellite";    symbol = "XTL";  algo = "CnHalf";      port = 16221; fee = 0.0; rpc = "stellite"}
    [PSCustomObject]@{coin = "Swap";        symbol = "XWP";  algo = "Cuckaroo29s"; port = 7731;  fee = 0.0; rpc = "swap"; divisor = 32; regions = @("eu","asia")}
    [PSCustomObject]@{coin = "Torque";      symbol = "XTC";  algo = "CnFast2";     port = 16221;  fee = 0.0; rpc = "torque"}
    #[PSCustomObject]@{coin = "Triton";      symbol = "TRIT"; algo = "CnLiteV7";    port = 6631;  fee = 0.0; rpc = "triton"}
    #[PSCustomObject]@{coin = "WowNero";     symbol = "WOW";  algo = "RandomWow";   port = 50901; fee = 0.0; rpc = "wownero"}
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

    $Pool_Regions   = if ($_.regions) {$_.regions} else {$Pool_Region_Default}
    $Pool_Hashrate  = if ($_.hashrate) {$_.hashrate} else {"hashrate"}

    $Pool_Algorithm_Norm = Get-Algorithm $Pool_Algorithm

    $Pool_Request  = [PSCustomObject]@{}
    $Pool_Request2 = [PSCustomObject]@{}
    $Pool_Ports    = @([PSCustomObject]@{})

    $ok = $true
    if (-not $InfoOnly) {
        try {
            $Pool_Request = Invoke-RestMethodAsync "https://cryptoknight.club/rpc/$($Pool_RpcPath)/stats" -tag $Name -timeout 15 -cycletime 120
            $Pool_Ports   = Get-PoolPortsFromRequest $Pool_Request -mCPU "" -mGPU "GPU" -mRIG "RIG"
            if ($Pool_Currency2) {
                $Pool_Request2 = Invoke-RestMethodAsync "https://cryptoknight.club/rpc/$($Pools_Data | Where-Object {$_.symbol -eq $Pool_Currency2 -and -not $_.symbol2} | Select-Object -ExpandProperty rpc)/stats" -tag $Name -timeout 15 -cycletime 120
            }
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

        $timestamp   = Get-UnixTimestamp

        $Pool_StatFn = "$($Name)_$($Pool_Currency)$(if ($Pool_Currency2) {$Pool_Currency2})_Profit"
        $dayData     = -not (Test-Path "Stats\Pools\$($Pool_StatFn).txt")
        $Pool_Reward = if ($dayData) {"Day"} else {"Live"}
        $Pool_Data   = Get-PoolDataFromRequest $Pool_Request -Currency $Pool_Currency -Divisor $Pool_Divisor -Timestamp $timestamp -addDay:$dayData -addBlockData -HashrateField $Pool_Hashrate

        if ($Pool_Currency2 -and $Pool_Request2) {
            $Pool_Data2 = Get-PoolDataFromRequest $Pool_Request2 -Currency $Pool_Currency2 -Divisor $Pool_Divisor -Timestamp $timestamp -addDay:$dayData -HashrateField $Pool_Hashrate
            $Pool_Data.$Pool_Reward.reward += $Pool_Data2.$Pool_Reward.reward
        }

        $Stat = Set-Stat -Name $Pool_StatFn -Value ($Pool_Data.$Pool_Reward.reward/1e8) -Duration $(if ($dayData) {New-TimeSpan -Days 1} else {$StatSpan}) -HashRate $Pool_Data.$Pool_Reward.hashrate -BlockRate $Pool_Data.BLK -ChangeDetection $dayData -Quiet
    }
    
    if (($ok -and ($AllowZero -or $Pool_Data.Live.hashrate -gt 0)) -or $InfoOnly) {
        $Pool_SSL = $false
        foreach ($Pool_Port in $Pool_Ports) {
            if ($Pool_Port) {
                foreach($Pool_Region in $Pool_Regions) {
                    [PSCustomObject]@{
                        Algorithm     = $Pool_Algorithm_Norm
                        CoinName      = $_.coin
                        CoinSymbol    = $Pool_Currency
                        Currency      = $Pool_Currency
                        Price         = $Stat.$StatAverage #instead of .Live
                        StablePrice   = $Stat.Week
                        MarginOfError = $Stat.Week_Fluctuation
                        Protocol      = "stratum+$(if ($Pool_SSL) {"ssl"} else {"tcp"})"
                        Host          = "$($Pool_HostPath).ingest$(if ($Pool_Region -ne $Pool_Region_Default) {"-$Pool_Region"}).cryptoknight.club"
                        Port          = $Pool_Port.CPU
                        Ports         = $Pool_Port
                        User          = "$($Wallets.$Pool_Currency){diff:$(if ($_.diffdot) {$_.diffdot} else {"."})`$difficulty}"
                        Pass          = "{workername:$Worker}"
                        Region        = $Pool_RegionsTable.$Pool_Region
                        SSL           = $Pool_SSL
                        Updated       = $Stat.Updated
                        PoolFee       = $Pool_Fee
                        Workers       = $Pool_Data.Workers
                        Hashrate      = $Stat.HashRate_Live
                        TSL           = $Pool_Data.TSL
                        BLK           = $Stat.BlockRate_Average
                    }
                }
            }
            $Pool_SSL = $true
        }
    }
}
