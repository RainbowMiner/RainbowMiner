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
    [PSCustomObject]@{coin = "Aeon";        symbol = "AEON"; algo = "CnLiteV7";   port = 5555;  fee = 0.9; rpc = "aeon"}
    [PSCustomObject]@{coin = "BitTube";     symbol = "TUBE"; algo = "CnSaber";    port = 5555;  fee = 0.9; rpc = "bittube"; regions = @("eu","ca","sg")}
    [PSCustomObject]@{coin = "Boolberry";   symbol = "BBR";  algo = "wildkeccak"; port = 5555;  fee = 0.9; rpc = "boolberry"; scratchpad = "http://boolberry.miner.rocks:8008/scratchpad.bin"}
    [PSCustomObject]@{coin = "Conceal";     symbol = "CCX";  algo = "CnConceal";  port = 10126; fee = 0.9; rpc = "conceal"}
    [PSCustomObject]@{coin = "Graft";       symbol = "GRFT"; algo = "CnRwz";      port = 5005;  fee = 0.9; rpc = "graft"}
    [PSCustomObject]@{coin = "Haven";       symbol = "XHV";  algo = "CnHaven";    port = 4005;  fee = 0.9; rpc = "haven"; regions = @("eu","ca","sg")}
    [PSCustomObject]@{coin = "Italo";       symbol = "XTA";  algo = "CnR";        port = 30042; fee = 0.9; rpc = "italo"}
    [PSCustomObject]@{coin = "Loki";        symbol = "LOKI"; algo = "RxLoki";     port = 5005;  fee = 0.9; rpc = "loki"}
    [PSCustomObject]@{coin = "Masari";      symbol = "MSR";  algo = "CnHalf";     port = 5005;  fee = 0.9; rpc = "masari";   regions = @("eu","sg")}
    [PSCustomObject]@{coin = "Monero";      symbol = "XMR";  algo = "CnR";        port = 5551;  fee = 0.9; rpc = "monero"}
    [PSCustomObject]@{coin = "Ryo";         symbol = "RYO";  algo = "CnGpu";      port = 5555;  fee = 1.2; rpc = "ryo"}
    [PSCustomObject]@{coin = "Scala";       symbol = "XLA";  algo = "DefyX";      port = 5005;  fee = 0.9; rpc = "stellite"; regions = @("eu","sg")}
    [PSCustomObject]@{coin = "Sumokoin";    symbol = "SUMO"; algo = "CnR";        port = 4003;  fee = 0.9; rpc = "sumokoin"}
    [PSCustomObject]@{coin = "Turtle";      symbol = "TRTL"; algo = "Chukwa";     port = 5005;  fee = 0.9; rpc = "turtle"}
    [PSCustomObject]@{coin = "uPlexa";      symbol = "UPX";  algo = "CnUpx2";     port = 30022; fee = 0.9; rpc = "uplexa"}
)

$Pools_Requests = [hashtable]@{}

$Pools_Data | Where-Object {($Wallets."$($_.symbol)" -and (-not $_.symbol2 -or $Wallets."$($_.symbol2)")) -or $InfoOnly} | ForEach-Object {
    $Pool_Algorithm     = $_.algo
    $Pool_Currency      = $_.symbol
    $Pool_Currency2     = $_.symbol2
    $Pool_Fee           = $_.fee
    $Pool_Port          = $_.port
    $Pool_RpcPath       = $_.rpc
    $Pool_ScratchPadUrl = $_.scratchpad

    $Pool_Divisor       = if ($_.divisor) {$_.divisor} else {1}
    $Pool_HostPath      = if ($_.host) {$_.host} else {$Pool_RpcPath}

    $Pool_Regions       = if ($_.regions) {$_.regions} else {$Pool_Region_Default}

    $Pool_Algorithm_Norm = Get-Algorithm $Pool_Algorithm

    $Pool_Request  = [PSCustomObject]@{}
    $Pool_Request2 = [PSCustomObject]@{}
    $Pool_Ports    = @([PSCustomObject]@{})

    $ok = $true
    if (-not $InfoOnly) {
        try {
            $Pool_Request = Invoke-RestMethodAsync "https://$($Pool_RpcPath).miner.rocks/api/stats" -tag $Name -cycletime 120
            $Pool_Ports   = Get-PoolPortsFromRequest $Pool_Request -mCPU "low" -mGPU "modern" -mRIG "farm" -mAvoid "PPS"
            if ($Pool_Currency2) {
                $Pool_Request2 = Invoke-RestMethodAsync "https://$($Pools_Data | Where-Object {$_.symbol -eq $Pool_Currency2 -and -not $_.symbol2} | Select-Object -ExpandProperty rpc).miner.rocks/api/stats" -tag $Name -cycletime 120
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

        $timestamp    = Get-UnixTimestamp

        $Pool_StatFn = "$($Name)_$($Pool_Currency)$(if ($Pool_Currency2) {$Pool_Currency2})_Profit"
        $dayData     = -not (Test-Path "Stats\Pools\$($Pool_StatFn).txt")
        $Pool_Reward = if ($dayData) {"Day"} else {"Live"}
        $Pool_Data   = Get-PoolDataFromRequest $Pool_Request -Currency $Pool_Currency -Divisor $Pool_Divisor -Timestamp $timestamp -addDay:$dayData -addBlockData -chartCurrency "USD"

        if ($Pool_Currency2 -and $Pool_Request2) {
            $Pool_Data2 = Get-PoolDataFromRequest $Pool_Request2 -Currency $Pool_Currency2 -Divisor $Pool_Divisor -Timestamp $timestamp -addDay:$dayData -chartCurrency "USD"
            $Pool_Data.$Pool_Reward.reward += $Pool_Data2.$Pool_Reward.reward
        }

        $Stat = Set-Stat -Name $Pool_StatFn -Value ($Pool_Data.$Pool_Reward.reward/1e8) -Duration $(if ($dayData) {New-TimeSpan -Days 1} else {$StatSpan}) -HashRate $Pool_Data.$Pool_Reward.hashrate -BlockRate $Pool_Data.BLK -ChangeDetection $dayData -Quiet
    }

    if (($ok -and $Pool_Port -and ($AllowZero -or $Pool_Data.Live.hashrate -gt 0)) -or $InfoOnly) {
        $Pool_SSL = $false
        $Pool_Wallet = Get-WalletWithPaymentId $Wallets.$Pool_Currency -pidchar '.' -asobject
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
                        Host          = "$(if ($Pool_Region -ne $Pool_Region_Default) {"$($Pool_Region)."})$($Pool_HostPath).miner.rocks"
                        Port          = $Pool_Port.CPU
                        Ports         = $Pool_Port
                        User          = "$($Pool_Wallet.wallet)$(if ($Pool_Wallet.difficulty) {".$($Pool_Wallet.difficulty)"} else {"{diff:.`$difficulty}"})"
                        Pass          = "w={workername:$Worker}$(if ($Pool_Currency2) {";mm=$(Get-WalletWithPaymentId $Wallets.$Pool_Currency2 -pidchar '.')"})"
                        Region        = $Pool_RegionsTable.$Pool_Region
                        SSL           = $Pool_SSL
                        Updated       = $Stat.Updated
                        PoolFee       = $Pool_Fee
                        Workers       = $Pool_Data.Workers
                        Hashrate      = $Stat.HashRate_Live
                        TSL           = $Pool_Data.TSL
                        BLK           = $Stat.BlockRate_Average
                        ScratchPadUrl = $Pool_ScratchPadUrl
                    }
                }
            }
            $Pool_SSL = $true
        }
    }
}
