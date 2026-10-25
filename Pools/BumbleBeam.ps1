using module ..\Modules\Include.psm1

param(
    [String]$Name,
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

# $Name = Get-Item $MyInvocation.MyCommand.Path | Select-Object -ExpandProperty BaseName

# BumbleBeam: open-source BEAM pool (https://github.com/profinch/bumblebeam), PPLNS and solo on one host.
# The API (https://pool.bumblebeam.org/api/stats) follows the open-ethereum-pool shape, plus "config" and "modes".

$Pool_Region_Default = Get-Region "eu"

$Pools_Data = @(
    [PSCustomObject]@{symbol = "BEAM"; host = "stratum.bumblebeam.org"; port = 3333; sslport = 3443; fee = 0.5; divisor = 1e8; blocktime = 60}
)

$Pools_Data | Where-Object {$Wallets."$($_.symbol)" -or $InfoOnly} | ForEach-Object {
    $Pool_Coin           = Get-Coin $_.symbol
    $Pool_Currency       = $_.symbol
    $Pool_Algorithm_Norm = $Pool_Coin.Algo
    $Pool_Fee            = $_.fee

    $ok = $true
    if (-not $InfoOnly) {
        $Pool_Request = [PSCustomObject]@{}
        try {
            $Pool_Request = Invoke-RestMethodAsync "https://pool.bumblebeam.org/api/stats" -tag $Name -retry 3 -retrywait 500 -cycletime 120
            if (-not $Pool_Request.nodes -or -not $Pool_Request.modes.pplns) {$ok = $false}
        }
        catch {
            $ok = $false
        }

        if (-not $ok) {
            Write-Log -Level Warn "Pool API ($Name) for $($Pool_Currency) has failed. "
            return
        }

        $timestamp = Get-UnixTimestamp
        $node      = $Pool_Request.nodes | Select-Object -First 1
        $mode      = $Pool_Request.modes.pplns

        if ($Pool_Request.config.fee -ne $null) {$Pool_Fee = [double]$Pool_Request.config.fee}

        # Expected (luck-neutral) reward per Sol/s and day from the network hashrate: the pool's own
        # 24h block count moves too much with rented hashrate to be a fair estimate
        $reward        = [double]$(if ($Pool_Request.config.blockReward) {$Pool_Request.config.blockReward} else {2500000000}) / $_.divisor
        $btcPrice      = if ($Global:Rates.$Pool_Currency) {1/[double]$Global:Rates.$Pool_Currency} else {0}
        $btcRewardLive = if ([double]$node.networkhashps -gt 0) {$btcPrice * $reward * 86400 / $_.blocktime / [double]$node.networkhashps} else {0}

        $Pool_BLK = [int]$mode.blocks24h
        $Pool_TSL = if ($mode.lastBlockFound) {$timestamp - [int64]$mode.lastBlockFound} else {$null}

        $Stat = Set-Stat -Name "$($Name)_$($Pool_Currency)_Profit" -Value $btcRewardLive -Duration $StatSpan -ChangeDetection $false -HashRate ([double]$mode.hashrate) -BlockRate $Pool_BLK -Quiet
        if (-not $Stat.HashRate_Live -and -not $AllowZero) {return}
    }

    if ($ok) {
        $Pool_Wallet = Get-WalletWithPaymentId $Wallets.$Pool_Currency -pidchar '.'
        foreach ($Pool_SSL in @($false,$true)) {
            [PSCustomObject]@{
                Algorithm          = $Pool_Algorithm_Norm
                Algorithm0         = $Pool_Algorithm_Norm
                CoinName           = $Pool_Coin.Name
                CoinSymbol         = $Pool_Currency
                Currency           = $Pool_Currency
                Price              = $Stat.$StatAverage #instead of .Live
                StablePrice        = $Stat.$StatAverageStable
                MarginOfError      = $Stat.Week_Fluctuation
                Protocol           = "stratum+$(if ($Pool_SSL) {"ssl"} else {"tcp"})"
                Host               = $_.host
                Port               = if ($Pool_SSL) {$_.sslport} else {$_.port}
                User               = "$($Pool_Wallet).{workername:$Worker}"
                Pass               = "x"
                Region             = $Pool_Region_Default
                SSL                = $Pool_SSL
                Updated            = $Stat.Updated
                PoolFee            = $Pool_Fee
                DataWindow         = $DataWindow
                Workers            = $mode.workers
                Hashrate           = $Stat.HashRate_Live
                TSL                = $Pool_TSL
                BLK                = $Stat.BlockRate_Average
                Name               = $Name
                Penalty            = 0
                PenaltyFactor      = 1
                Disabled           = $false
                HasMinerExclusions = $false
                Price_0            = 0.0
                Price_Bias         = 0.0
                Price_Unbias       = 0.0
                Wallet             = $Pool_Wallet
                Worker             = "{workername:$Worker}"
                Email              = $Email
            }
        }
    }
}
