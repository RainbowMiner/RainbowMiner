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
@("na","eu","ap") | Foreach-Object {$Pool_RegionsTable.$_ = Get-Region $_}

$Pools_Data = @(
    #[PSCustomObject]@{symbol = "YEC";   port = @(3456,3458); fee = 0.0; rpc = "ycash"; region = @("na","eu","ap")}
    [PSCustomObject]@{symbol = "VRSC";  port = @(3956);      fee = 1.0; rpc = "verus"; region = @("na","eu","ap"); allow_difficulty = $true}
    [PSCustomObject]@{symbol = "ZEN";   port = @(3056,3058); fee = 1.0; rpc = "zen"; region = @("na","eu","ap"); allow_difficulty = $true}
    [PSCustomObject]@{symbol = "KMD";   port = @(3856,3858); fee = 1.0; rpc = "komodo"; region = @("na","eu","ap"); allow_difficulty = $true}
    [PSCustomObject]@{symbol = "HUSH";  port = @(3756,3758); fee = 1.0; rpc = "hush"; region = @("na","eu","ap"); allow_difficulty = $true}
    [PSCustomObject]@{symbol = "ZEC";   port = @(3356,3358); fee = 1.0; rpc = "zcash"; region = @("na","eu","ap"); allow_difficulty = $true}
)

$Pools_Data | Where-Object {$Wallets."$($_.symbol)" -or $InfoOnly} | ForEach-Object {
    $Pool_Coin      = Get-Coin $_.symbol
    $Pool_Currency  = $_.symbol
    $Pool_Fee       = $_.fee
    $Pool_Ports     = $_.port
    $Pool_RpcPath   = $_.rpc
    $Pool_Regions   = $_.region

    $Pool_Algorithm_Norm = Get-Algorithm $Pool_Coin.algo

    $Pool_Request  = [PSCustomObject]@{}

    $ok = $true
    if (-not $InfoOnly) {
        try {
            $Pool_Request = Invoke-RestMethodAsync "https://luckpool.net/$Pool_RpcPath/stats" -tag $Name -timeout 15 -cycletime 120
        }
        catch {
            if ($Error.Count){$Error.RemoveAt(0)}
            Write-Log -Level Warn "Pool API ($Name) for $Pool_Currency has failed. "
            $ok = $false
        }
    }

    if ($ok -and -not $InfoOnly) {
        $Stat = Set-Stat -Name "$($Name)_$($Pool_Currency)_Profit" -Value 0 -Duration $StatSpan -HashRate $Pool_Request.poolStats.hashrateSols -BlockRate $Pool_Request.poolStats.blocksLast24 -ChangeDetection $false -Quiet
        if (-not $Stat.HashRate_Live -and -not $AllowZero) {return}
    }
    
    if ($ok -or $InfoOnly) {
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
                    StablePrice   = $Stat.$StatAverageStable
                    MarginOfError = $Stat.Week_Fluctuation
                    Protocol      = "stratum+$(if ($Pool_SSL) {"ssl"} else {"tcp"})"
                    Host          = "$Pool_Region.luckpool.net"
                    Port          = $Pool_Port
                    User          = "$($Wallets.$Pool_Currency).{workername:$Worker}"
                    Pass          = "x{diff:,d=`$difficulty}"
                    Region        = $Pool_RegionsTable[$Pool_Region]
                    SSL           = $Pool_SSL
                    WTM           = $true
                    Updated       = $Stat.Updated
                    PoolFee       = $Pool_Fee
                    Workers       = $Pool_Request.poolStats.workerCount
                    Hashrate      = $Stat.HashRate_Live
                    TSL           = $Pool_Request.poolStats.currentRoundTimeMin * 60
                    BLK           = $Stat.BlockRate_Average
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
                $Pool_SSL = $true
            }
        }
    }
}
