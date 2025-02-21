using module ..\Modules\Include.psm1

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
@("fr","ca","us-w","br","sg","za") | Foreach-Object {$Pool_RegionsTable.$_ = Get-Region $_}

$Pools_Data = @(
    [PSCustomObject]@{symbol = "CCX";   port = 30041; fee = 0.9; rpc = "conceal"; regions = @("fr")}
    [PSCustomObject]@{symbol = "DERO";  port = 30182; fee = 0.9; rpc = "dero";   regions =@("fr","ca","sg"); solo = $true}
    [PSCustomObject]@{symbol = "XHV";   port = 30031; fee = 0.9; rpc = "haven"; regions = @("fr","ca","us-w","br","sg","za")}
    [PSCustomObject]@{symbol = "RYO";   port = 30172; fee = 1.2; rpc = "ryo"; regions = @("fr","ca","us-w","br","sg","za")}
    [PSCustomObject]@{symbol = "UPX";   port = 30022; fee = 0.9; rpc = "uplexa"; regions = @("fr")}
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

    $Pool_Algorithm_Norm = $Pool_Coin.Algo

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
            if ($Pool_Request.config.fee) {$Pool_Fee = [double]$Pool_Request.config.fee}
        }
        catch {
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

        if ($_.solo) {
            $Stat = Set-Stat -Name $Pool_StatFn -Value ($Pool_Data.$Pool_Reward.reward/1e8) -Duration $(if ($dayData) {New-TimeSpan -Days 1} else {$StatSpan}) -Difficulty $Pool_Request.network.difficulty -ChangeDetection $false -Quiet
        } else {
            $Stat = Set-Stat -Name $Pool_StatFn -Value ($Pool_Data.$Pool_Reward.reward/1e8) -Duration $(if ($dayData) {New-TimeSpan -Days 1} else {$StatSpan}) -HashRate $Pool_Data.$Pool_Reward.hashrate -BlockRate $Pool_Data.BLK -ChangeDetection $dayData -Quiet
            if (-not $Stat.HashRate_Live -and -not $AllowZero) {return}
        }
    }

    if (($ok -and $Pool_Port) -or $InfoOnly) {
        $Pool_SSL = $false
        $Pool_Wallet = Get-WalletWithPaymentId $Wallets.$Pool_Currency -pidchar '.' -asobject
        foreach ($Pool_Port in $Pool_Ports) {
            if ($Pool_Port) {
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
                        Host          = "$($Pool_Region).$($Pool_HostPath).miner.rocks"
                        Port          = if ($Pool_Port.CPU -ne $null) {$Pool_Port.CPU} else {$_.port}
                        Ports         = if ($Pool_Port.CPU -ne $null) {$Pool_Port} else {$null}
                        User          = "$($Pool_Wallet.wallet)$(if ($Pool_Wallet.difficulty) {".$($Pool_Wallet.difficulty)"} else {"{diff:.`$difficulty}"})"
                        Pass          = "w={workername:$Worker}$(if ($Pool_Currency2) {";mm=$(Get-WalletWithPaymentId $Wallets.$Pool_Currency2 -pidchar '.')"})"
                        Region        = $Pool_RegionsTable.$Pool_Region
                        SSL           = $Pool_SSL
                        Updated       = $Stat.Updated
                        PoolFee       = $Pool_Fee
                        Workers       = if (-not $_.solo) {$Pool_Data.Workers} else {$null}
                        Hashrate      = if (-not $_.solo) {$Stat.HashRate_Live} else {$null}
                        TSL           = if (-not $_.solo) {$Pool_Data.TSL} else {$null}
                        BLK           = if (-not $_.solo) {$Stat.BlockRate_Average} else {$null}
                        Difficulty    = $Stat.Difficulty
                        SoloMining    = $_.solo
                        Name          = $Name
                        Penalty       = 0
                        PenaltyFactor = 1
						Disabled      = $false
						HasMinerExclusions = $false
                        Price_0       = 0.0
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
