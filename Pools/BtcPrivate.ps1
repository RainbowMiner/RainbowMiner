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
@("us") | Foreach-Object {$Pool_RegionsTable.$_ = Get-Region $_}

$Pools_Data = @(
    [PSCustomObject]@{symbol = "BTCP";  port = 3032; fee = 1.5; region = @("us")}
)

$Pools_Data | Where-Object {$Wallets."$($_.symbol)" -or $InfoOnly} | ForEach-Object {
    $Pool_Coin      = Get-Coin $_.symbol
    $Pool_Currency  = $_.symbol
    $Pool_Fee       = $_.fee
    $Pool_Port      = $_.port
    $Pool_Regions   = $_.region

    $Pool_Algorithm_Norm = Get-Algorithm $Pool_Coin.algo

    $ok = $true
    if (-not $InfoOnly) {
        try {
            $Pool_Request = ((Invoke-RestMethodAsync "https://pool.btcprivate.org/api/pool_stats" -tag $Name -timeout 15 -cycletime 120) | Select-Object -Last 1).pools
            $Pool_Blocks  = [int](Invoke-RestMethodAsync "https://pool.btcprivate.org/api/last24" -tag $Name -timeout 15 -cycletime 120)
            $ok = $Pool_Request.'bitcoin private' -ne $null
        }
        catch {
            if ($Error.Count){$Error.RemoveAt(0)}
            Write-Log -Level Warn "Pool API ($Name) for $Pool_Currency has failed. "
            $ok = $false
        }
    }

    if ($ok -and -not $InfoOnly) {
        $Stat = Set-Stat -Name "$($Name)_$($Pool_Currency)_Profit" -Value 0 -Duration $StatSpan -HashRate ([Math]::Round($Pool_Request.'bitcoin private'.hashrate * 2 / 1000) / 1000) -BlockRate $Pool_Blocks -ChangeDetection $false -Quiet
        if (-not $Stat.HashRate_Live -and -not $AllowZero) {return}
    }
    
    if ($ok -or $InfoOnly) {
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
                Protocol      = "stratum+tcp"
                Host          = "pool.btcp.network"
                Port          = $Pool_Port
                User          = "$($Wallets.$Pool_Currency).{workername:$Worker}"
                Pass          = "x"
                Region        = $Pool_RegionsTable[$Pool_Region]
                SSL           = $false
                WTM           = $true
                Updated       = $Stat.Updated
                PoolFee       = $Pool_Fee
                Workers       = [int]$Pool_Request.'bitcoin private'.workerCount
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
                Wallet        = $Wallets.$Pool_Currency
                Worker        = "{workername:$Worker}"
                Email         = $Email
            }
        }
    }
}
