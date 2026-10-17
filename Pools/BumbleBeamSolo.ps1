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

# BumbleBeam solo: the whole block (less the fee) goes to the miner whose share found it

$Pool_Region_Default = Get-Region "eu"

$Pools_Data = @(
    [PSCustomObject]@{symbol = "BEAM"; host = "stratum.bumblebeam.org"; port = 3334; sslport = 3444; fee = 0.5}
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
            if (-not $Pool_Request.nodes) {$ok = $false}
        }
        catch {
            $ok = $false
        }

        if (-not $ok) {
            Write-Log -Level Warn "Pool API ($Name) for $($Pool_Currency) has failed. "
            return
        }

        if ($Pool_Request.config.soloFee -ne $null) {$Pool_Fee = [double]$Pool_Request.config.soloFee}

        $node = $Pool_Request.nodes | Select-Object -First 1
        $Stat = Set-Stat -Name "$($Name)_$($Pool_Currency)_Profit" -Value 0 -Duration $StatSpan -ChangeDetection $false -Difficulty ([double]$node.difficulty) -Quiet
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
                Workers            = $null
                Hashrate           = $null
                TSL                = $null
                BLK                = $null
                WTM                = $true
                Difficulty         = $Stat.Diff_Average
                SoloMining         = $true
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
