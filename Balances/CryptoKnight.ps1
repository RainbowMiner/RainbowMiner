param(
    $Config
)

$Name = Get-Item $MyInvocation.MyCommand.Path | Select-Object -ExpandProperty BaseName

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

$Pools_Data | Where-Object {$Config.Pools.$Name.Wallets."$($_.symbol)"} | Foreach-Object {
    $Pool_Currency = $_.symbol
    $Pool_RpcPath = $_.rpc

    $Pool_Request = [PSCustomObject]@{}
    $Request = [PSCustomObject]@{}

    try {
        $Pool_Request = Invoke-RestMethodAsync "https://cryptoknight.cc/rpc/$($Pool_RpcPath)/stats" -tag $Name
        $Divisor = $Pool_Request.config.coinUnits

        $Request = Invoke-RestMethodAsync "https://cryptoknight.cc/rpc/$($Pool_RpcPath)/stats_address?address=$($Config.Pools.$Name.Wallets.$Pool_Currency)" -delay 100 -cycletime ($Config.BalanceUpdateMinutes*60)
        if (-not $Request.stats -or -not $Divisor) {
            Write-Log -Level Info "Pool Balance API ($Name) for $($Pool_Currency) returned nothing. "
        } else {
            $Pending = ($Request.blocks | Where-Object {$_ -match "^\d+?:\d+?:\d+?:\d+?:\d+?:(\d+?):"} | Foreach-Object {[int64]$Matches[1]} | Measure-Object -Sum).Sum / $Divisor
            [PSCustomObject]@{
                Caption     = "$($Name) ($Pool_Currency)"
                Currency    = $Pool_Currency
                Balance     = $Request.stats.balance / $Divisor
                Pending     = $Pending
                Total       = $Request.stats.balance / $Divisor + $Pending
                Paid        = $Request.stats.paid / $Divisor
                Payouts     = @($i=0;$Request.payments | Where-Object {$_ -match "^(.+?):(\d+?):"} | Foreach-Object {[PSCustomObject]@{time=$Request.payments[$i+1];amount=$Matches[2] / $Divisor;txid=$Matches[1]};$i+=2})
                LastUpdated = (Get-Date).ToUniversalTime()
            }
        }
    }
    catch {
        if ($Error.Count){$Error.RemoveAt(0)}
        Write-Log -Level Verbose "Pool Balance API ($Name) for $($Pool_Currency) has failed. "
    }
}
