﻿using module ..\Modules\Include.psm1

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
@("eu","ca","sg") | Foreach-Object {$Pool_RegionsTable.$_ = Get-Region $_}

$Pools_Data = @(
    #ASIC
    [PSCustomObject]@{symbol = "AEON";  port = 30112; fee = 0.9; rpc = "aeon"; regions = @("eu")}
    [PSCustomObject]@{symbol = "KRB";  port = 30192; fee = 0.9; rpc = "krb"; regions = @("eu")}
    [PSCustomObject]@{symbol = "QWC";   port = 30052; fee = 0.9; rpc = "qwertycoin";   regions = @("eu")}

    #Other
    [PSCustomObject]@{symbol = "TUBE";  port = 30212; fee = 0.9; rpc = "bittubecash"; regions = @("eu")}
    #[PSCustomObject]@{symbol = "BBR";   port = 5555;  fee = 0.9; rpc = "boolberry"; regions = @("eu"); scratchpad = "http://boolberry.miner.rocks:8008/scratchpad.bin"}
    [PSCustomObject]@{symbol = "CCX";   port = 10126; fee = 0.9; rpc = "conceal"; regions = @("eu")}
    [PSCustomObject]@{symbol = "DERO";  port = 30182; fee = 0.9; rpc = "dero";   regions = @("eu","sg")}
    [PSCustomObject]@{symbol = "XHV";   port = 4005;  fee = 0.9; rpc = "haven"; regions = @("eu","ca","sg")}
    #[PSCustomObject]@{symbol = "LOKI";  port = 30122; fee = 0.9; rpc = "loki"; regions = @("eu")}
    [PSCustomObject]@{symbol = "MSR";   port = 30162; fee = 0.9; rpc = "masari";   regions = @("eu","sg")}
    [PSCustomObject]@{symbol = "RYO";   port = 30172; fee = 1.2; rpc = "ryo"; regions = @("eu")}
    #[PSCustomObject]@{symbol = "XLA";   port = 30092; fee = 0.9; rpc = "stellite"; regions = @("eu")}
    [PSCustomObject]@{symbol = "SUMO";  port = 30152; fee = 0.9; rpc = "sumokoin"; regions = @("eu")}
    #[PSCustomObject]@{symbol = "TRTL";  port = 30132; fee = 0.9; rpc = "turtle"; regions = @("eu")}
    [PSCustomObject]@{symbol = "UPX";   port = 30022; fee = 0.9; rpc = "uplexa"; regions = @("eu")}
    [PSCustomObject]@{symbol = "XCASH"; port = 30062;  fee = 0.9; rpc = "xcash"; regions = @("eu")}
)

$Pools_Requests = [hashtable]@{}

$Pools_Data | Where-Object {($Wallets."$($_.symbol)" -and (-not $_.symbol2 -or $Wallets."$($_.symbol2)")) -or $InfoOnly} | ForEach-Object {
    $Pool_Coin          = Get-Coin $_.symbol
    $Pool_Coin2         = if ($_.symbol2) {Get-Coin $_.symbol2}
    $Pool_Currency      = $_.symbol
    $Pool_Currency2     = $_.symbol2
    $Pool_Fee           = $_.fee
    $Pool_Port          = $_.port
    $Pool_RpcPath       = $_.rpc
    $Pool_ScratchPadUrl = $_.scratchpad

    $Pool_Divisor       = if ($_.divisor) {$_.divisor} else {1}
    $Pool_HostPath      = if ($_.host) {$_.host} else {$Pool_RpcPath}

    $Pool_Regions       = $_.regions

    $Pool_Algorithm_Norm = Get-Algorithm $Pool_Coin.Algo

    $Pool_Request  = [PSCustomObject]@{}
    $Pool_Request2 = [PSCustomObject]@{}
    $Pool_Ports    = @([PSCustomObject]@{})

    $ok = -not $_.algo -or ($_.algo -eq $Pool_Algorithm_Norm)

    if ($ok -and -not $InfoOnly) {
        try {
            $Pool_Request = Invoke-RestMethodAsync "https://$($Pool_RpcPath).miner.rocks/api/stats" -tag $Name -cycletime 120
            if ($Pool_Request.config.hashrateMultiplier) {$Pool_Divisor = $Pool_Request.config.hashrateMultiplier}
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
        if (-not $Stat.HashRate_Live -and -not $AllowZero) {return}
    }

    if (($ok -and $Pool_Port) -or $InfoOnly) {
        $Pool_SSL = $false
        $Pool_Wallet = Get-WalletWithPaymentId $Wallets.$Pool_Currency -pidchar '.' -asobject
        foreach ($Pool_Port in $Pool_Ports) {
            if ($Pool_Port) {
                $First = $true
                foreach($Pool_Region in $Pool_Regions) {
                    [PSCustomObject]@{
                        Algorithm     = $Pool_Algorithm_Norm
						Algorithm0    = $Pool_Algorithm_Norm
                        CoinName      = "$($Pool_Coin.Name)$(if ($Pool_Coin2) {"+$($Pool_Coin2.Name)"})"
                        CoinSymbol    = $Pool_Currency
                        Currency      = $Pool_Currency
                        Price         = $Stat.$StatAverage #instead of .Live
                        StablePrice   = $Stat.$StatAverageStable
                        MarginOfError = $Stat.Week_Fluctuation
                        Protocol      = "stratum+$(if ($Pool_SSL) {"ssl"} else {"tcp"})"
                        Host          = "$(if (-not $First) {"$($Pool_Region)."})$($Pool_HostPath).miner.rocks"
                        Port          = if ($Pool_Port.CPU -ne $null) {$Pool_Port.CPU} else {$_.port}
                        Ports         = if ($Pool_Port.CPU -ne $null) {$Pool_Port} else {$null}
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
