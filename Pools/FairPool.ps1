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
    [PSCustomObject]@{coin = "BitTube";         symbol = "TUBE"; algo = "CnSaber";     port = 6040; fee = 1.0; rpc = "tube";    user="%wallet%+%worker%"}
    [PSCustomObject]@{coin = "Haven";           symbol = "XHV";  algo = "CnHaven";     port = 5566; fee = 1.0; rpc = "xhv";     user="%wallet%+%worker%"}
    [PSCustomObject]@{coin = "Lethean";         symbol = "LTHN"; algo = "CnR";         port = 6070; fee = 1.0; rpc = "lethean"; user="%wallet%+%worker%"}
    [PSCustomObject]@{coin = "Loki";            symbol = "LOKI"; algo = "CnHeavy";     port = 5577; fee = 1.0; rpc = "loki";    user="%wallet%+%worker%"}
    [PSCustomObject]@{coin = "Masari";          symbol = "MSR";  algo = "CnHalf";      port = 6060; fee = 1.0; rpc = "msr";     user="%wallet%+%worker%"}
    #[PSCustomObject]@{coin = "PrivatePay";      symbol = "XPP";  algo = "CnFast";      port = 6050; fee = 1.0; rpc = "xpp";     user="%wallet%+%worker%"}
    [PSCustomObject]@{coin = "Qrl";             symbol = "QRL";  algo = "CnV7";        port = 7000; fee = 1.0; rpc = "qrl";     user="%wallet%+%worker%"}
    [PSCustomObject]@{coin = "Ryo";             symbol = "RYO";  algo = "CnGpu";       port = 5555; fee = 1.0; rpc = "ryo";     user="%wallet%+%worker%"}
    #[PSCustomObject]@{coin = "Saronite";        symbol = "XRN";  algo = "CnHaven";     port = 5599; fee = 1.0; rpc = "xrn";     user="%wallet%+%worker%"}
    #[PSCustomObject]@{coin = "Solace";          symbol = "XPP";  algo = "CnHeavy";     port = 5588; fee = 1.0; rpc = "solace";  user="%wallet%+%worker%"}
    [PSCustomObject]@{coin = "Swap";            symbol = "XWP";  algo = "Cuckaroo29s"; port = 6080; fee = 1.0; rpc = "xfh";     user="%wallet%+%worker%"; divisor = 32}
    [PSCustomObject]@{coin = "Wow";             symbol = "WOW";  algo = "RandomWow";   port = 6090; fee = 1.0; rpc = "wow";     user="%wallet%+%worker%"}
    [PSCustomObject]@{coin = "Xtend";           symbol = "XTNC"; algo = "CnTurtle";    port = 7010; fee = 1.0; rpc = "xtnc";    user="%wallet%+%worker%"}

    #[PSCustomObject]@{coin = "Akroma";          symbol = "AKA";  algo = "Ethash";      port = 2222; fee = 1.0; rpc = "aka";     user="%wallet%.%worker%"}
    [PSCustomObject]@{coin = "DogEthereum";     symbol = "DOGX"; algo = "Ethash";      port = 7788; fee = 1.0; rpc = "dogx";    user="%wallet%.%worker%"}
    [PSCustomObject]@{coin = "EthereumClassic"; symbol = "ETC";  algo = "Ethash";      port = 4444; fee = 1.0; rpc = "etc";     user="%wallet%.%worker%"}
    [PSCustomObject]@{coin = "Metaverse";       symbol = "ETP";  algo = "Ethash";      port = 6666; fee = 1.0; rpc = "etp";     user="%wallet%.%worker%"}
    [PSCustomObject]@{coin = "Nekonium";        symbol = "NUKO"; algo = "Ethash";      port = 7777; fee = 1.0; rpc = "nuko";    user="%wallet%.%worker%"}
    [PSCustomObject]@{coin = "Pegascoin";       symbol = "PGC";  algo = "Ethash";      port = 1111; fee = 1.0; rpc = "pgc";     user="%wallet%.%worker%"}

    [PSCustomObject]@{coin = "Zano";            symbol = "ZANO"; algo = "ProgPowZ";    port = 7020; fee = 1.0; rpc = "zano";    user="%wallet%.%worker%"}

    #[PSCustomObject]@{coin = "Purk";            symbol = "PURK"; algo = "WildKeccak";  port = 2244; fee = 1.0; rpc = "purk";    user="%wallet%+%worker%"}
)

$Pools_Data | Where-Object {$Wallets."$($_.symbol)" -or $InfoOnly} | ForEach-Object {
    $Pool_Currency = $_.symbol
    $Pool_RpcPath = $_.rpc.ToLower()
    $Pool_Algorithm = $_.algo
    $Pool_Algorithm_Norm = Get-Algorithm $Pool_Algorithm
    $Pool_Divisor = if ($_.divisor) {$_.divisor} else {1}

    $Pool_Port = $_.port
    $Pool_Fee  = $_.fee
    $Pool_User = $_.user

    $Pool_Request = [PSCustomObject]@{}

    $ok = $true
    if (-not $InfoOnly) {
        try {
            $Pool_Request = Invoke-RestMethodAsync "https://$($Pool_RpcPath).fairpool.xyz/api/poolStats" -tag $Name -timeout 15 -cycletime 120
        }
        catch {
            if ($Error.Count){$Error.RemoveAt(0)}
            Write-Log -Level Warn "Pool API ($Name) for $Pool_Currency has failed. "
            $ok = $false
        }
    }

    if ($ok -and $Pool_Port -and -not $InfoOnly) {
        $Pool_BLK = if ($Pool_Request.blockTime) {24*3600 / $Pool_Request.blockTime} else {0}
        $Pool_TSL = [int](Get-UnixTimestamp) - [int]$Pool_Request.lastBlock
    
        $Stat = Set-Stat -Name "$($Name)_$($Pool_Currency)_Profit" -Value ([Double]$Pool_Request.profitBtc) -Duration $StatSpan -ChangeDetection $false -HashRate ([int64]$Pool_Request.pool) -BlockRate $Pool_BLK -Quiet
    }
    
    if (($ok -and $Pool_Port -and ($AllowZero -or [int64]$Pool_Request.pool -gt 0)) -or $InfoOnly) {
        [PSCustomObject]@{
            Algorithm     = $Pool_Algorithm_Norm
            CoinName      = $_.coin
            CoinSymbol    = $Pool_Currency
            Currency      = $Pool_Currency
            Price         = $Stat.$StatAverage #instead of .Live
            StablePrice   = $Stat.Week
            MarginOfError = $Stat.Week_Fluctuation
            Protocol      = "stratum+tcp"
            Host          = "mine.$($Pool_RpcPath).fairpool.xyz"
            Port          = $_.port
            Ports         = $Pool_Ports
            User          = $Pool_User -replace '%wallet%',"$($Wallets.$Pool_Currency)" -replace '%worker%',"{workername:$Worker}"
            Pass          = "x"
            Region        = $Pool_Region_Default
            SSL           = $False
            Updated       = $Stat.Updated
            PoolFee       = $Pool_Fee
            Workers       = $Pool_Request.workers
            Hashrate      = $Stat.HashRate_Live
            TSL           = $Pool_TSL
            BLK           = $Stat.BlockRate_Average
            EthMode       = if ($Pool_Algorithm_Norm -match "^(Ethash|ProgPow)") {"ethproxy"}
        }
    }
}
