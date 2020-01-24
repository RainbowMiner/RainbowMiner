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

[hashtable]$Pool_RegionsTable = @{}
@("us","us-east","us-west","eu","asia") | Foreach-Object {$Pool_RegionsTable.$_ = Get-Region $_}

$Pools_Data = @(
    [PSCustomObject]@{symbol = "BEAM";  port = 3333; fee = 0.5; rpc = "beam"; region = @("us","eu","asia"); coinUnits = 100000000}
    [PSCustomObject]@{symbol = "TTNZ";  port = 3333; fee = 0.1; rpc = "ttnz"; region = @("us","eu"); endpoint = "stats"}
    [PSCustomObject]@{symbol = "RYO";   port = 5555; fee = 1.0; rpc = "ryo";  region = @("us-west","us-east","eu"); endpoint = "stats"}
    [PSCustomObject]@{symbol = "DEFT";  port = 6622; fee = 1.0; rpc = "deft"; region = @("us","eu"); coinUnits = 1}
)

$Pools_Data | Where-Object {$Wallets."$($_.symbol)" -or $InfoOnly} | ForEach-Object {
    $Pool_Coin      = Get-Coin $_.symbol
    $Pool_Currency  = $_.symbol
    $Pool_Fee       = $_.fee
    $Pool_Port      = $_.port
    $Pool_RpcPath   = $_.rpc
    $Pool_Regions   = $_.region

    $Pool_HostPath  = "https://api-$($Pool_RpcPath).leafpool.com/$(if ($_.endpoint) {$_.endpoint} else {"api/stats"})"

    $Pool_Algorithm_Norm = Get-Algorithm $Pool_Coin.algo

    $Pool_Request  = [PSCustomObject]@{}
    $Pool_Ports    = @([PSCustomObject]@{})

    $ok = $true
    if (-not $InfoOnly) {
        try {
            $Pool_Request = Invoke-RestMethodAsync $Pool_HostPath -tag $Name -timeout 15 -cycletime 120
            $Pool_Ports   = if ($_.endpoint) {Get-PoolPortsFromRequest $Pool_Request -mCPU "" -mGPU "(multi|high|GPU)" -mRIG "(cloud|very high|nicehash)"} else {$null}
        }
        catch {
            if ($Error.Count){$Error.RemoveAt(0)}
            Write-Log -Level Warn "Pool API ($Name) for $Pool_Currency has failed. "
            $ok = $false
        }

        if (-not ($Pool_Ports_Found = ($Pool_Ports | Where-Object {$_} | Measure-Object).Count)) {
            $Pool_Ports = @([PSCustomObject]@{CPU=$Pool_Port})
        }
    }

    if ($ok -and -not $InfoOnly) {

        $timestamp  = Get-UnixTimestamp

        $Pool_StatFn = "$($Name)_$($Pool_Currency)_Profit"

        if ($Pool_Ports_Found) {
            if ($Pool_Request.config.fee -ne $null) {$Pool_Fee = $Pool_Request.config.fee}
            $Pool_Data = Get-PoolDataFromRequest $Pool_Request -Currency $Pool_Currency -Divisor 1 -Timestamp $timestamp -addDay:$dayData -addBlockData
            $dayData   = -not (Test-Path "Stats\Pools\$($Pool_StatFn).txt")
            $Pool_WTM  = $false
        } else {
            $Pool_Pools = $Pool_Request.pools.psobject.properties.value | Where-Object {$_.symbol -eq $Pool_Currency}
            if ($Pool_Pools.poolFee -ne $null) {$Pool_Fee = $Pool_Pools.poolFee}
            $Pool_Data = [PSCustomObject]@{
                Live = [PSCustomObject]@{reward=0;hashrate=[int64]$Pool_Pools.hashrate}
                Day  = [PSCustomObject]@{reward=0;hashrate=0}
                Workers = [int]$Pool_Pools.workerCount
                BLK     = if ($Pool_Pools.maxRoundTime) {[int](86400 / $Pool_Pools.maxRoundTime)} else {0}
                TSL     = [int]($Pool_Request.time - $Pool_Pools.poolStats.blockFoundTime/1000)
            }
            $dayData  = $false
            $Pool_WTM = $true
        }
        $Pool_Reward = if ($dayData) {"Day"} else {"Live"}
        $Stat = Set-Stat -Name $Pool_StatFn -Value ($Pool_Data.$Pool_Reward.reward/1e8) -Duration $(if ($dayData) {New-TimeSpan -Days 1} else {$StatSpan}) -HashRate $Pool_Data.$Pool_Reward.hashrate -BlockRate $Pool_Data.BLK -ChangeDetection $dayData -Quiet
        if (-not $Stat.HashRate_Live -and -not $AllowZero) {return}
    }
    
    if ($ok -or $InfoOnly) {
        $Pool_SSL = $false
        $Pool_Wallet = if ($Pool_Ports_Found) {Get-WalletWithPaymentId $Wallets.$Pool_Currency -asobject} else {$null}
        foreach ($Pool_Port in $Pool_Ports) {
            if ($Pool_Port) {
                foreach ($Pool_Region in $Pool_Regions) {
                    [PSCustomObject]@{
                        Algorithm     = $Pool_Algorithm_Norm
						Algorithm0    = $Pool_Algorithm_Norm
                        CoinName      = $Pool_Coin.Name
                        CoinSymbol    = $Pool_Currency
                        Currency      = $Pool_Currency
                        Price         = $Stat.$StatAverage #instead of .Live
                        StablePrice   = $Stat.Week
                        MarginOfError = $Stat.Week_Fluctuation
                        Protocol      = "stratum+$(if ($Pool_SSL) {"ssl"} else {"tcp"})"
                        Host          = "$($Pool_RpcPath)-$($Pool_Region).leafpool.com"
                        Port          = $Pool_Port.CPU
                        Ports         = if ($Pool_Ports_Found) {$Pool_Port} else {$null}
                        User          = if ($Pool_Ports_Found) {"$($Pool_Wallet.wallet)$(if ($Pool_Wallet.difficulty) {"+$($Pool_Wallet.difficulty)"} else {"{diff:+`$difficulty}"})"} else {"$($Wallets.$Pool_Currency).{workername:$Worker}"}
                        Pass          = if ($Pool_Ports_Found) {"$(if ($Email) {$Email} else {"workername:$Worker"})"} else {"x"}
                        Region        = $Pool_RegionsTable[$Pool_Region]
                        SSL           = $Pool_SSL
                        WTM           = $Pool_WTM
                        Updated       = $Stat.Updated
                        PoolFee       = $Pool_Fee
                        Workers       = $Pool_Data.Workers
                        Hashrate      = $Stat.HashRate_Live
                        TSL           = $Pool_Data.TSL
                        BLK           = $Stat.BlockRate_Average
                        Name          = $Name
                        Penalty       = 0
                        PenaltyFactor = 1
						Disabled      = $false
						HasMinerExclusions = $false
						Price_Bias    = 0.0
						Price_Unbias  = 0.0
                        Wallet        = if ($Pool_Ports_Found) {$Pool_Wallet.wallet} else {$Wallets.$Pool_Currency}
                        Worker        = "{workername:$Worker}"
                        Email         = $Email
                    }
                }
            }
            $Pool_SSL = $true
        }
    }
}
