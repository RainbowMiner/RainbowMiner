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

$Pools_Data = @(
    [PSCustomObject]@{coin = "Boolberry"; symbol = "BBR";  algo = "wildkeccak";  port = 5577; fee = 0.5; rpc = "boolberry"; scratchpad = "http://#region#-bbr.luckypool.io/scratchpad.bin"; region = @("asia","eu")}
    [PSCustomObject]@{coin = "Swap";      symbol = "XWP";  algo = "Cuckaroo29s"; port = 4888; fee = 0.9; rpc = "swap2"; divisor = 32; region = @("eu")}
    [PSCustomObject]@{coin = "Zano";      symbol = "ZANO"; algo = "ProgPowZ";    port = 8877; fee = 0.9; rpc = "zano"; region = @("eu")}
)

$Pools_Data | Where-Object {$Wallets."$($_.symbol)" -or $InfoOnly} | ForEach-Object {
    $Pool_Algorithm     = $_.algo
    $Pool_Currency      = $_.symbol
    $Pool_Currency2     = $_.symbol2
    $Pool_Fee           = $_.fee
    $Pool_Port          = $_.port
    $Pool_RpcPath       = $_.rpc
    $Pool_ScratchPadUrl = $_.scratchpad

    $Pool_Divisor       = if ($_.divisor) {$_.divisor} else {1}
    $Pool_HostPath      = if ($_.host) {$_.host} else {$Pool_RpcPath}

    $Pool_Algorithm_Norm = Get-Algorithm $Pool_Algorithm

    $Pool_Request = [PSCustomObject]@{}
    $Pool_Ports   = @([PSCustomObject]@{})

    $ok = $true
    if (-not $InfoOnly) {
        try {
            $Pool_Request = Invoke-RestMethodAsync "https://$($Pool_RpcPath).luckypool.io/api/stats" -tag $Name -timeout 15 -cycletime 120
            $Pool_Ports   = Get-PoolPortsFromRequest $Pool_Request -mCPU "" -mGPU "mid" -mRIG "high"
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

        $Pool_StatFn = "$($Name)_$($Pool_Currency)_Profit"
        $dayData     = -not (Test-Path "Stats\Pools\$($Pool_StatFn).txt")
        $Pool_Reward = if ($dayData) {"Day"} else {"Live"}
        $Pool_Data   = Get-PoolDataFromRequest $Pool_Request -Currency $Pool_Currency -Divisor $Pool_Divisor -Timestamp $timestamp -addDay:$dayData -addBlockData

        $Stat = Set-Stat -Name $Pool_StatFn -Value ($Pool_Data.$Pool_Reward.reward/1e8) -Duration $(if ($dayData) {New-TimeSpan -Days 1} else {$StatSpan}) -HashRate $Pool_Data.$Pool_Reward.hashrate -BlockRate $Pool_Data.BLK -ChangeDetection $dayData -Quiet
    }
    
    if (($ok -and ($AllowZero -or $Pool_Data.Live.hashrate -gt 0)) -or $InfoOnly) {
        foreach ($Pool_Region in $_.region) {
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
                        Host          = "$($Pool_HostPath).luckypool.io"
                        Port          = $Pool_Port.CPU
                        Ports         = $Pool_Port
                        User          = "$($Wallets.$Pool_Currency){diff:.`$difficulty}"
                        Pass          = "{workername:$Worker}"
                        Region        = Get-Region $Pool_Region
                        SSL           = $Pool_SSL
                        Updated       = $Stat.Updated
                        PoolFee       = $Pool_Fee
                        Workers       = $Pool_Data.Workers
                        Hashrate      = $Stat.HashRate_Live
                        TSL           = $Pool_Data.TSL
                        BLK           = $Stat.BlockRate_Average
                        ScratchPadUrl = if ($Pool_ScratchPadUrl) {$Pool_ScratchPadUrl -replace "#region",$Pool_Region}
                    }
                }
                $Pool_SSL = $true
            }
        }
    }
}
