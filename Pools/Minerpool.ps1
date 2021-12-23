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
    [String]$StatAverageStable = "Week",
    [String]$Password = "xyz"
)

$Name = Get-Item $MyInvocation.MyCommand.Path | Select-Object -ExpandProperty BaseName

$Pool_Regions = @("eu","na","asia")

[hashtable]$Pool_RegionsTable = @{}
$Pool_Regions | Foreach-Object {$Pool_RegionsTable.$_ = Get-Region $_}

$Pools_Data = @(
    [PSCustomObject]@{symbol = "FLUX";  port = 2033;  fee = 1.0; rpc = "flux"; rewards = "hourlyRewardsPerSol"}
    [PSCustomObject]@{symbol = "RVN";   port = 16059; fee = 1.0; rpc = "rvn";  rewards = "hourlyRewardsPerHash"}
    [PSCustomObject]@{symbol = "TENT";  port = 3034;  fee = 4.0; rpc = "tent"; rewards = "hourlyRewardsPerSol"}
    [PSCustomObject]@{symbol = "ZER";   port = 15058; fee = 1.0; rpc = "zer";  rewards = "hourlyRewardsPerSol"}
)

if (-not $Password) {$Password = "xyz"}

$Pools_Data | Where-Object {$Pool_Currency = $_.symbol;$Wallets.$Pool_Currency -or $InfoOnly} | ForEach-Object {
    $Pool_Coin      = Get-Coin $_.symbol
    $Pool_Fee       = $_.fee
    $Pool_Port      = $_.port
    $Pool_RpcPath   = $_.rpc

    $Pool_Divisor   = 1
    $Pool_HostPath  = if ($_.host) {$_.host} else {$Pool_RpcPath}

    $Pool_Algorithm_Norm = Get-Algorithm $Pool_Coin.algo

    $Pool_EthProxy = if ($Pool_Algorithm_Norm -match $Global:RegexAlgoHasEthproxy) {"ethproxy"} elseif ($Pool_Algorithm_Norm -match $Global:RegexAlgoIsProgPow) {"stratum"} else {$null}

    $Pool_Request  = [PSCustomObject]@{}
    $Pool_Ports    = @([PSCustomObject]@{})

    $ok = $true
    if (-not $InfoOnly) {
        try {
            $Pool_Request = Invoke-RestMethodAsync "https://$($Pool_RpcPath).minerpool.org/api/stats" -tag $Name -timeout 15 -cycletime 120
            if ($Pool_Request.name -ne $Pool_RpcPath) {$ok = $false}
        }
        catch {
            if ($Error.Count){$Error.RemoveAt(0)}
            Write-Log -Level Warn "Pool API ($Name) for $Pool_Currency has failed. "
            $ok = $false
        }

        if (-not ($Pool_Ports | Where-Object {$_} | Measure-Object).Count) {$ok = $false}
    }


    if ($ok -and -not $InfoOnly) {
        $Pool_Fee = [double]"$($Pool_Request.poolFee -replace "[^\d]+")"

        $Pool_Workers  = [int]$Pool_Request.workerCount
        $Pool_Hashrate = [decimal]$Pool_Request.hashrate
        $Pool_TSL      = [int]$Pool_Request.lbfSeconds
        $Pool_BLK      = [int]$Pool_Request.poolStats.last24hBlocks

        $Pool_Price    = if ($Global:Rates.$Pool_Currency) {[double]$Pool_Request.poolStats."$($_.rewards)" / $Global:Rates.$Pool_Currency * 24} else {0}

        $Stat = Set-Stat -Name "$($Name)_$($_.symbol)_Profit" -Value $Pool_Price -Duration $StatSpan -HashRate $Pool_Hashrate -BlockRate $Pool_BLK -ChangeDetection $false -Quiet

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
                Price         = 0
                StablePrice   = 0
                MarginOfError = 0
                Protocol      = "stratum+tcp"
                Host          = "$($Pool_Region).minerpool.org"
                Port          = $Pool_Port
                User          = "$($Wallets.$Pool_Currency).{workername:$Worker}"
                Pass          = $Password
                Region        = $Pool_RegionsTable[$Pool_Region]
                SSL           = $Pool_SSL
                Updated       = $Stat.Updated
                PoolFee       = $Pool_Fee
                Workers       = $Pool_Workers
                Hashrate      = $Stat.HashRate_Live
                TSL           = $Pool_TSL
                BLK           = $Stat.BlockRate_Average
                WTM           = $Pool_Price -eq 0
                WTMMode       = "WTM"
                EthMode       = $Pool_EthProxy
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