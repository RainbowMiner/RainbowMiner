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
@("eu","ca","sg") | Foreach-Object {$Pool_RegionsTable.$_ = Get-Region $_}

$Pools_Data = @(
    [PSCustomObject]@{coin = "Boolberry";  symbol = "BBR";  algo = "wildkeccak"; port = 5555; fee = 0.9; rpc = "boolberry"}
    [PSCustomObject]@{coin = "Purk";       symbol = "PURK"; algo = "wildkeccak"; port = 5555; fee = 0.9; rpc = "purk"}
    [PSCustomObject]@{coin = "QRL";        symbol = "QRL";  algo = "CnV7";       port = 9111; fee = 0.9; rpc = "qrl"}
    [PSCustomObject]@{coin = "Stellite";   symbol = "XTL";  algo = "CnXTL";      port = 4005; fee = 0.9; rpc = "stellite"; regions = @("eu","sg")}
    [PSCustomObject]@{coin = "Graft";      symbol = "GRFT"; algo = "CnV8";       port = 4005; fee = 0.9; rpc = "graft"}
    [PSCustomObject]@{coin = "Monero";     symbol = "XMR";  algo = "CnV8";       port = 5551; fee = 0.9; rpc = "monero"}
    [PSCustomObject]@{coin = "Loki";       symbol = "LOKI"; algo = "CnHeavy";    port = 5555; fee = 0.9; rpc = "loki"; regions = @("eu","ca","sg")}
    [PSCustomObject]@{coin = "Ryo";        symbol = "RYO";  algo = "CnGpu";      port = 5555; fee = 0.9; rpc = "ryo"}
    [PSCustomObject]@{coin = "Haven";      symbol = "XHV";  algo = "CnHaven";    port = 4005; fee = 0.9; rpc = "haven"; regions = @("eu","ca","sg")}
    [PSCustomObject]@{coin = "Saronite";   symbol = "XRN";  algo = "CnHeavyXhv"; port = 5555; fee = 0.9; rpc = "saronite"; regions = @("eu","sg")}
    [PSCustomObject]@{coin = "BitTube";    symbol = "TUBE"; algo = "CnSaber";    port = 5555; fee = 0.9; rpc = "bittube"; regions = @("eu","ca","sg")}
    [PSCustomObject]@{coin = "Aeon";       symbol = "AEON"; algo = "CnLiteV7";   port = 5555; fee = 0.9; rpc = "aeon"}
    [PSCustomObject]@{coin = "Turtlecoin"; symbol = "TRTL"; algo = "CnTurtle";   port = 5555; fee = 0.9; rpc = "turtle"}
    [PSCustomObject]@{coin = "Masari";     symbol = "MSR";  algo = "CnFast2";    port = 5555; fee = 0.9; rpc = "masari"; regions = @("eu","sg")}
)

$Pools_Requests = [hashtable]@{}

$Pools_Data | Where-Object {$Wallets."$($_.symbol)" -or $InfoOnly} | ForEach-Object {
    $Pool_Currency = $_.symbol
    $Pool_RpcPath = $_.rpc.ToLower()
    $Pool_HostPath = if ($_.host) {$_.host} else {$Pool_RpcPath}
    $Pool_Algorithm = $_.algo
    $Pool_Algorithm_Norm = Get-Algorithm $Pool_Algorithm
    $Pool_Divisor = if ($_.divisor) {$_.divisor} else {1}
    $Pool_Regions = if ($_.regions) {$_.regions} else {$Pool_Region_Default}

    $Pool_Port = $_.port
    $Pool_Fee  = $_.fee

    $Pool_Request = [PSCustomObject]@{}
    $Pool_Ports   = [PSCustomObject]@{}

    $ok = $true
    if (-not $InfoOnly) {
        try {
            $Pool_Request = Invoke-RestMethodAsync "https://$($Pool_RpcPath).miner.rocks/api/stats" -tag $Name -cycletime 120
            $Pool_Port = $Pool_Request.config.ports | Where-Object desc -match '(CPU|GPU)' | Select-Object -First 1 -ExpandProperty port
            @("CPU","GPU","RIG") | Foreach-Object {
                $PortType = $_
                $Pool_Request.config.ports | Where-Object desc -match $(if ($PortType -eq "RIG") {"farm"} else {$PortType}) | Select-Object -First 1 -ExpandProperty port | Foreach-Object {$Pool_Ports | Add-Member $PortType $_ -Force}
            }
        }
        catch {
            if ($Error.Count){$Error.RemoveAt(0)}
            Write-Log -Level Warn "Pool API ($Name) for $Pool_Currency has failed. "
            $ok = $false
        }
    }

    if ($ok -and $Pool_Port -and -not $InfoOnly) {
        $Pool_Fee = $Pool_Request.config.fee

        $timestamp    = Get-UnixTimestamp
        $timestamp24h = $timestamp - 24*3600

        $diffDay      = $Pool_Request.pool.stats.diffs.wavg24h
        $diffLive     = $Pool_Request.network.difficulty
        $reward       = $Pool_Request.network.reward

        $profitDay    = 86400/$diffDay*$reward/$Pool_Divisor
        $profitLive   = 86400/$diffLive*$reward/$Pool_Divisor

        $coinUnits    = $Pool_Request.config.coinUnits
        $amountDay    = $profitDay / $coinUnits
        $amountLive   = $profitLive / $coinUnits

        $btcPrice     = $Pool_Request.coinPrice."coin-btc"
        if (-not $btcPrice -and $Session.Rates.$Pool_Currency) {$btcPrice = 1/$Session.Rates.$Pool_Currency}
        $btcRewardDay = $amountDay*$btcPrice
        $btcRewardLive= $amountLive*$btcPrice

        $Divisor      = 1

        $blocks = $Pool_Request.pool.blocks | Where-Object {$_ -match '^.*?\:(\d+?)\:'} | Foreach-Object {$Matches[1]} | Sort-Object -Descending
        $Pool_BLK = ($blocks | Where-Object {$_ -gt $timestamp24h} | Measure-Object).Count
        $Pool_TSL = if ($blocks.Count) {$timestamp - $blocks[0]}
    
        if (-not (Test-Path "Stats\Pools\$($Name)_$($Pool_Currency)_Profit.txt")) {$Stat = Set-Stat -Name "$($Name)_$($Pool_Currency)_Profit" -Value ($btcRewardDay/$Divisor) -Duration (New-TimeSpan -Days 1) -HashRate ($Pool_Request.charts.hashrate | Where-Object {$_[0] -gt $timestamp24h} | Foreach-Object {$_[1]} | Measure-Object -Average).Average -BlockRate $Pool_BLK -Quiet}
        else {$Stat = Set-Stat -Name "$($Name)_$($Pool_Currency)_Profit" -Value ($btcRewardLive/$Divisor) -Duration $StatSpan -ChangeDetection $false -HashRate $Pool_Request.pool.hashrate -BlockRate $Pool_BLK -Quiet}
    }

    if (($ok -and $Pool_Port -and ($AllowZero -or $Pool_Request.pool.hashrate -gt 0)) -or $InfoOnly) {
        foreach($Pool_Region in $Pool_Regions) {
            [PSCustomObject]@{
                Algorithm     = $Pool_Algorithm_Norm
                CoinName      = $_.coin
                CoinSymbol    = $Pool_Currency
                Currency      = $Pool_Currency
                Price         = $Stat.$StatAverage #instead of .Live
                StablePrice   = $Stat.Week
                MarginOfError = $Stat.Week_Fluctuation
                Protocol      = "stratum+tcp"
                Host          = "$(if ($Pool_Region -ne $Pool_Region_Default) {"$($Pool_Region)."})$($Pool_HostPath).miner.rocks"
                Port          = if (-not $Pool_Port) {$_.port} else {$Pool_Port}
                Ports         = $Pool_Ports
                User          = "$($Wallets.$($_.symbol)){diff:.`$difficulty}"
                Pass          = "w={workername:$Worker}"
                Region        = $Pool_RegionsTable.$Pool_Region
                SSL           = $False
                Updated       = $Stat.Updated
                PoolFee       = $Pool_Fee
                Workers       = $Pool_Request.pool.workers
                Hashrate      = $Stat.HashRate_Live
                TSL           = $Pool_TSL
                BLK           = $Stat.BlockRate_Average
            }
        }
    }
}
