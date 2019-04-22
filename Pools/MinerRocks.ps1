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
    [PSCustomObject]@{coin = "Boolberry";   symbol = "BBR";  algo = "wildkeccak"; port = 5555; fee = 0.9; rpc = "boolberry"}

    [PSCustomObject]@{coin = "Masari";      symbol = "MSR";  algo = "CnHalf";     port = 5005; fee = 0.9; rpc = "masari";   regions = @("eu","sg")}
    [PSCustomObject]@{coin = "Torque";      symbol = "XTL";  algo = "CnHalf";     port = 5005; fee = 0.9; rpc = "stellite"; regions = @("eu","sg")}

    [PSCustomObject]@{coin = "Monero";      symbol = "XMR";  algo = "CnR";        port = 5551; fee = 0.9; rpc = "monero"}
    [PSCustomObject]@{coin = "Sumokoin";    symbol = "SUMO"; algo = "CnR";        port = 4003; fee = 0.9; rpc = "sumokoin"}

    [PSCustomObject]@{coin = "Haven";       symbol = "XHV";  algo = "CnHaven";    port = 4005; fee = 0.9; rpc = "haven"; regions = @("eu","ca","sg")}

    [PSCustomObject]@{coin = "BitTube";     symbol = "TUBE"; algo = "CnSaber";    port = 5555; fee = 0.9; rpc = "bittube"; regions = @("eu","ca","sg")}

    [PSCustomObject]@{coin = "Aeon";        symbol = "AEON"; algo = "CnLiteV7";   port = 5555; fee = 0.9; rpc = "aeon"}

    [PSCustomObject]@{coin = "Loki";        symbol = "LOKI"; algo = "CnTurtle";   port = 4005; fee = 0.9; rpc = "loki"; regions = @("eu","ca","sg")}
    [PSCustomObject]@{coin = "Loki+Turtle"; symbol = "LOKI"; algo = "CnTurtle";   port = 4005; fee = 0.9; rpc = "loki"; regions = @("eu"); symbol2 = "TRTL"}

    [PSCustomObject]@{coin = "Turtle";      symbol = "TRTL"; algo = "CnTurtle";   port = 5005; fee = 0.9; rpc = "turtle"}

    [PSCustomObject]@{coin = "Ryo";         symbol = "RYO";  algo = "CnGpu";      port = 5555; fee = 1.2; rpc = "ryo"}

    [PSCustomObject]@{coin = "Graft";       symbol = "GRFT"; algo = "CnRwz";      port = 5005; fee = 0.9; rpc = "graft"}
)

$Pools_Requests = [hashtable]@{}

$Pools_Data | Where-Object {($Wallets."$($_.symbol)" -and (-not $_.symbol2 -or $Wallets."$($_.symbol2)")) -or $InfoOnly} | ForEach-Object {
    $Pool_Algorithm = $_.algo
    $Pool_Currency  = $_.symbol
    $Pool_Currency2 = $_.symbol2
    $Pool_Fee       = $_.fee
    $Pool_Port      = $_.port
    $Pool_RpcPath   = $_.rpc

    $Pool_Divisor   = if ($_.divisor) {$_.divisor} else {1}
    $Pool_HostPath  = if ($_.host) {$_.host} else {$Pool_RpcPath}

    $Pool_Regions = if ($_.regions) {$_.regions} else {$Pool_Region_Default}

    $Pool_Algorithm_Norm = Get-Algorithm $Pool_Algorithm

    $Pool_Request  = [PSCustomObject]@{}
    $Pool_Request2 = [PSCustomObject]@{}
    $Pool_Ports    = @([PSCustomObject]@{})

    $ok = $true
    if (-not $InfoOnly) {
        try {
            $Pool_Request = Invoke-RestMethodAsync "https://$($Pool_RpcPath).miner.rocks/api/stats" -tag $Name -cycletime 120
            $Ports = $Pool_Request.config.ports | Where-Object {$_.Disabled -ne $true -and $_.Virtual -ne $true} | Where-Object desc -match '(CPU|GPU)'
            $Pool_Port = $Ports | Select-Object -First 1 -ExpandProperty port
            @("CPU","GPU","RIG") | Foreach-Object {
                $PortType = $_
                $Ports | Where-Object desc -match $(if ($PortType -eq "RIG") {"farm"} else {$PortType}) | Select-Object -First 1 -ExpandProperty port | Foreach-Object {$Pool_Ports | Add-Member $PortType $_ -Force}
            }
            if ($Pool_Currency2) {
                $Pool_Request2 = Invoke-RestMethodAsync "https://$($Pools_Data | Where-Object {$_.symbol -eq $Pool_Currency2 -and -not $_.symbol2} | Select-Object -ExpandProperty rpc).miner.rocks/api/stats" -tag $Name -cycletime 120
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
                User          = "$($Wallets.$Pool_Currency){diff:.`$difficulty}"
                Pass          = "w={workername:$Worker}$(if ($Pool_Currency2) {";mm=$($Wallets.$Pool_Currency2)"})"
                Region        = $Pool_RegionsTable.$Pool_Region
                SSL           = $False
                Updated       = $Stat.Updated
                PoolFee       = $Pool_Fee
                Workers       = $Pool_Data.Workers
                Hashrate      = $Stat.HashRate_Live
                TSL           = $Pool_Data.TSL
                BLK           = $Stat.BlockRate_Average
            }
        }
    }
}
