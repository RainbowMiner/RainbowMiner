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
    [String]$Password
)

$Name = Get-Item $MyInvocation.MyCommand.Path | Select-Object -ExpandProperty BaseName

[hashtable]$Pool_RegionsTable = @{}
@("us") | Foreach-Object {$Pool_RegionsTable.$_ = Get-Region $_}

$Pools_Data = @(
    [PSCustomObject]@{symbol = "VRM";   port = @(3333); fee = 1.0; rpc = "vrm"; region = @("us")}
)

$Pools_Data | Where-Object {$Wallets."$($_.symbol)" -or $InfoOnly} | ForEach-Object {
    $Pool_Coin      = Get-Coin $_.symbol
    $Pool_Currency  = $_.symbol
    $Pool_Fee       = $_.fee
    $Pool_Ports     = $_.port
    $Pool_RpcPath   = $_.rpc
    $Pool_Regions   = $_.region

    if (-not $InfoOnly -and $Wallets.$Pool_Currency -notmatch "\.") {
        Write-Log -Level Warn "$Name's $Pool_Currency wallet must be in the form xxx.yyy - check the pool's `"My Workers`" page."
        return
    }

    $Pool_Algorithm_Norm = Get-Algorithm $Pool_Coin.algo

    $Pool_Request = [PSCustomObject]@{}

    if (-not $InfoOnly) {
        try {
            $Network_Request = Invoke-RestMethodAsync "https://veriumstats.vericoin.info/stats.json" -tag "veriumstats" -timeout 15 -cycletime 120
            $Pool_Request    = (Invoke-RestMethodAsync "https://rbminer.net/api/data/poolium.json" -tag $Name -timeout 15 -cycletime 120).getpoolstatus.data | Select-Object -First 1
        }
        catch {
            if ($Error.Count){$Error.RemoveAt(0)}
            Write-Log -Level Warn "Pool API ($Name) has failed. "
            return
        }
        if ($Pool_Request.esttime -gt 0 -and $Pool_Request.hashrate -gt 0) {
            $Pool_BLK   = 86400 / $Pool_Request.esttime
            $Pool_HR    = $Pool_Request.hashrate * 1000
            $rewardBtc  = if ($Global:Rates.$Pool_Currency) {$Pool_BLK * $Network_Request.blockreward / $Global:Rates.$Pool_Currency} else {0}
            $profitLive = $rewardBtc / $Pool_HR
        } else {
            $Pool_BLK   = $Pool_HR = $profitLive = 0
        }
        $Stat = Set-Stat -Name "$($Name)_$($Pool_Currency)_Profit" -Value $profitLive -Duration $StatSpan -HashRate $Pool_HR -BlockRate $Pool_BLK -ChangeDetection $($profitLive -gt 0) -Quiet
        if (-not $Stat.HashRate_Live -and -not $AllowZero) {return}
    }

    foreach ($Pool_Region in $Pool_Regions) {
        $Pool_SSL = $false
        foreach ($Pool_Port in $Pool_Ports) {
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
                Host          = "$Pool_RpcPath.poolium.win"
                Port          = $Pool_Port
                User          = $Wallets.$Pool_Currency
                Pass          = "$(if ($Password) {$Password} else {"x"})"
                Region        = $Pool_RegionsTable[$Pool_Region]
                SSL           = $Pool_SSL
                WTM           = $profitLive -eq 0
                Updated       = $Stat.Updated
                PoolFee       = $Pool_Fee
                Workers       = $Pool_Request.workers
                Hashrate      = $Stat.HashRate_Live
                TSL           = $Pool_Request.timesincelast
                BLK           = $Stat.BlockRate_Average
                Name          = $Name
                Penalty       = 0
                PenaltyFactor = 1
				Disabled      = $false
				HasMinerExclusions = $false
				Price_Bias    = 0.0
				Price_Unbias  = 0.0
                Wallet        = $Wallets.$Pool_Currency -replace "\..+$"
                Worker        = $Wallets.$Pool_Currency -replace "^.+\."
                Email         = $Email
            }
            $Pool_SSL = $true
        }
    }
}
