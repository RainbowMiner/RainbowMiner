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

$Pools_Data = @(
    [PSCustomObject]@{symbol = "NIR";   port = 3377; fee = 0.9; rpc = "nirmata";    user = "{wallet}.{worker}.{diff}"; pass="x"}
    [PSCustomObject]@{symbol = "QUAI";  port = 3333; fee = 0.9; rpc = "quai";       user = "{wallet}={diff}.{worker}"; pass="x"}
    [PSCustomObject]@{symbol = "XCC";   port = 4481; fee = 0.9; rpc = "cyberchain"; user = "{wallet}={diff}.{worker}"; pass="x"}
    [PSCustomObject]@{symbol = "XE";    port = 3381; fee = 0.9; rpc = "xechain";    user = "{wallet}={diff}.{worker}"; pass="x"}
    [PSCustomObject]@{symbol = "XEL";   port = 2666; fee = 0.9; rpc = "xelis";      user = "{wallet}={diff}.{worker}"; pass="x"}
    [PSCustomObject]@{symbol = "ZANO";  port = 8877; fee = 0.9; rpc = "zano";       user = "{wallet}.{worker}";        pass="{diff}"}
)

$Pools_Data | Where-Object {$Wallets."$($_.symbol)" -or $InfoOnly} | ForEach-Object {
    $Pool_Coin          = Get-Coin $_.symbol
    $Pool_Currency      = $_.symbol
    $Pool_Fee           = $_.fee
    $Pool_Port          = $_.port
    $Pool_RpcPath       = $_.rpc
    $Pool_Divisor       = if ($_.divisor) {$_.divisor} else {1}

    $Pool_Algorithm_Norm = $Pool_Coin.Algo

    $Pool_EthProxy = if ($Pool_Algorithm_Norm -match $Global:RegexAlgoHasEthproxy) {"ethproxy"} elseif ($Pool_Algorithm_Norm -match $Global:RegexAlgoIsProgPow) {"stratum"} else {$null}

    $Pool_Request = [PSCustomObject]@{}

    try {
        $Pool_Request = Invoke-RestMethodAsync "https://$($Pool_RpcPath).luckypool.io/api/stats" -tag $Name -timeout 15 -cycletime 120
    }
    catch {
        if ($Global:Error.Count){$Global:Error.RemoveAt(0)}
        Write-Log -Level Warn "Pool API ($Name) for $Pool_Currency has failed. "
        $ok = $false
    }

    if ($Pool_Request.config.stratum -and -not $InfoOnly) {
        $Pool_Fee = $Pool_Request.config.fee

        $timestamp  = Get-UnixTimestamp

        $Pool_StatFn = "$($Name)_$($Pool_Currency)_Profit"
        $Pool_Reward = "Live"
        $Pool_Data   = Get-PoolDataFromRequest $Pool_Request -Currency $Pool_Currency -Divisor $Pool_Divisor -Timestamp $timestamp -addBlockData
        $Pool_WTM    = -not $Pool_Data.$Pool_Reward.reward

        $Stat = Set-Stat -Name $Pool_StatFn -Value ($Pool_Data.$Pool_Reward.reward/1e8) -Duration $StatSpan -HashRate $Pool_Data.$Pool_Reward.hashrate -BlockRate $Pool_Data.BLK -ChangeDetection $false -Quiet
        if (-not $Stat.HashRate_Live -and -not $AllowZero) {return}
    }
    
    if ($Pool_Request.config.stratum -or $InfoOnly) {
        $Pool_User = $_.user -replace "{wallet}","$($Wallets.$Pool_Currency)" -replace "{worker}","{workername:$Worker}" -replace "{diff}","{diff:.`$difficulty}"
        $Pool_Pass = $_.pass -replace "{diff}","{diff:.`$difficulty}" 
        foreach ($Pool_Stratum in $Pool_Request.config.stratum) {
            [PSCustomObject]@{
                Algorithm     = $Pool_Algorithm_Norm
				Algorithm0    = $Pool_Algorithm_Norm
                CoinName      = $Pool_Coin.Name
                CoinSymbol    = $Pool_Currency
                Currency      = $Pool_Currency
                Price         = $Stat.$StatAverage #instead of .Live
                StablePrice   = $Stat.$StatAverageStable
                MarginOfError = $Stat.Week_Fluctuation
                Protocol      = "stratum+tcp"
                Host          = "$(if ($Pool_Stratum.server) {$Pool_Stratum.server} else {$Pool_Stratum})"
                Port          = $Pool_Port
                User          = $Pool_User
                Pass          = $Pool_Pass
                Region        = Get-Region "$(if ($Pool_Stratum.flag) {$Pool_Stratum.flag} else {"eu"})"
                SSL           = $false
                Updated       = $Stat.Updated
                PoolFee       = $Pool_Fee
                Workers       = $Pool_Data.Workers
                Hashrate      = $Stat.HashRate_Live
                TSL           = $Pool_Data.TSL
                BLK           = $Stat.BlockRate_Average
                WTM           = $Pool_WTM
                EthMode       = $Pool_EthProxy
                Name          = $Name
                Penalty       = 0
                PenaltyFactor = 1
				Disabled      = $false
				HasMinerExclusions = $false
                Price_0       = 0.0
				Price_Bias    = 0.0
				Price_Unbias  = 0.0
                Wallet        = $Wallets.$Pool_Currency
                Worker        = "{workername:$Worker}"
                Email         = $Email
            }
        }
    }
}