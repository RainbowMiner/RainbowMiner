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

$Pool_Regions = @("eu","us-east","us-west","asia")

[hashtable]$Pool_RegionsTable = @{}
$Pool_Regions | Foreach-Object {$Pool_RegionsTable.$_ = Get-Region $_}

$Pools_Data = @(
    [PSCustomObject]@{symbol = "FIRO";  port = 14068;         fee = 1.0; rpc = "solo-firo"; host = "firo"; rewards = "hourlyRewardsPerHash"}
    [PSCustomObject]@{symbol = "FLUX";  port = @(2058,2059);  fee = 1.0; rpc = "solo-flux"; host = "flux"; rewards = "hourlyRewardsPerSol"}
    [PSCustomObject]@{symbol = "NEOX";  port = 10069;         fee = 1.0; rpc = "solo-neox"; host = "neox"; rewards = "hourlyRewardsPerHash"}
    [PSCustomObject]@{symbol = "RVN";   port = 16069;         fee = 1.0; rpc = "solo-rvn";  host = "rvn";  rewards = "hourlyRewardsPerHash"}
)

if (-not $Password) {$Password = "xyz"}

$Pools_Data | Where-Object {$Pool_Currency = $_.symbol;$Wallets.$Pool_Currency -or $InfoOnly} | ForEach-Object {
    $Pool_Coin      = Get-Coin $_.symbol
    $Pool_Fee       = $_.fee
    $Pool_RpcPath   = $_.rpc

    $Pool_Divisor   = 1
    $Pool_HostPath  = if ($_.host) {$_.host} else {$Pool_RpcPath}

    $Pool_Algorithm_Norm = $Pool_Coin.algo

    $Pool_EthProxy = if ($Pool_Algorithm_Norm -match $Global:RegexAlgoHasEthproxy) {"ethproxy"} elseif ($Pool_Algorithm_Norm -match $Global:RegexAlgoIsProgPow) {"stratum"} else {$null}

    $Pool_Request  = [PSCustomObject]@{}

    $ok = $true
    if (-not $InfoOnly) {
        try {
            $Pool_Request = Invoke-RestMethodAsync "https://$($Pool_RpcPath).minerpool.org/api/stats" -tag $Name -timeout 15 -cycletime 120
            if ($Pool_Request.name -ne $Pool_RpcPath) {$ok = $false}
        }
        catch {
            Write-Log -Level Warn "Pool API ($Name) for $Pool_Currency has failed. "
            $ok = $false
        }
    }


    if ($ok -and -not $InfoOnly) {
        $Pool_Fee = [double]"$($Pool_Request.poolFee -replace "[^\d]+")"
        $Stat = Set-Stat -Name "$($Name)_$($_.symbol)_Profit" -Value 0 -Duration $StatSpan -Difficulty $Pool_Request.poolStats.networkDiff -ChangeDetection $false -Quiet
    }
    
    if ($ok -or $InfoOnly) {
        $Pool_SSL = $false
        foreach ($Pool_Port in $_.port) {
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
                    Protocol      = "stratum+$(if ($Pool_SSL) {"ssl"} else {"tcp"})"
                    Host          = "$($Pool_HostPath)-$($Pool_Region).minerpool.org"
                    Port          = $Pool_Port
                    User          = "$($Wallets.$Pool_Currency).{workername:$Worker}"
                    Pass          = $Password
                    Region        = $Pool_RegionsTable[$Pool_Region]
                    SSL           = $Pool_SSL
                    Updated       = $Stat.Updated
                    PoolFee       = $Pool_Fee
                    Workers       = $null
                    Hashrate      = $null
                    TSL           = $null
                    BLK           = $null
                    Difficulty    = $Stat.Diff_Average
                    SoloMining    = $true
                    WTM           = $true
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
            $Pool_SSL = $true
        }
    }
}