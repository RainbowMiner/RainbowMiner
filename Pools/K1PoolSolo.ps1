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

$Pools_Request = [PSCustomObject]@{}
try {
    $Pools_Request = Invoke-RestMethodAsync "https://rbminer.net/api/data/k1pool.json" -tag "K1Pool" -timeout 30 -cycletime 3600 
}
catch {
    if ($Error.Count){$Error.RemoveAt(0)}
    Write-Log -Level Warn "Pool API ($Name) has failed."
    return
}

[hashtable]$Pool_RegionsTable = @{}

$Pool_Regions = @("eu","us","cn")
$Pool_Regions | Foreach-Object {$Pool_RegionsTable.$_ = Get-Region $_}

$Pools_Request | Where-Object {$_.name -match "solo$" -and ($Wallets."$($_.symbol)" -or $InfoOnly)} | ForEach-Object {
    $Pool_Currency       = $_.symbol    
    $Pool_Coin           = Get-Coin $Pool_Currency
    
    if ($Pool_Coin) {
        $Pool_Algorithm_Norm = $Pool_Coin.Algo
        $Pool_CoinName       = $Pool_Coin.Name
    } else {
        $Pool_Algorithm_Norm = Get-Algorithm $_.algo
        $Pool_CoinName       = (Get-Culture).TextInfo.ToTitleCase($_.name)
    }

    $Pool_Fee            = $_.fee
    $Pool_User           = $Wallets.$Pool_Currency
    $Pool_EthProxy       = if ($Pool_Algorithm_Norm -match $Global:RegexAlgoHasEthproxy) {"ethstratum1"} elseif ($Pool_Algorithm_Norm -match $Global:RegexAlgoIsProgPow) {"stratum"} else {$null}

    $Pools_StatsRequest = [PSCustomObject]@{}
    try {
        $Pools_StatsRequest = Invoke-RestMethodAsync "https://k1pool.com/api/stats/$($_.name)" -tag $Name -timeout 30 -cycletime 120 
    }
    catch {
        if ($Error.Count){$Error.RemoveAt(0)}
        Write-Log -Level Warn "Pool API ($Name) for pool $($_.name) has failed."
        return
    }

    if (-not $InfoOnly) {                    
        $Stat = Set-Stat -Name "$($Name)_$($Pool_Currency)_Profit" -Value 0 -Duration $StatSpan -ChangeDetection $false -Difficulty ([decimal]$Pools_StatsRequest.networkDiff) -Quiet
    }

    foreach ($Pool_Region in $_.stratum.PSObject.Properties.Name) {
        foreach ($Pool_Host_Data in $_.stratum.$Pool_Region) {
            [PSCustomObject]@{
                Algorithm     = $Pool_Algorithm_Norm
                Algorithm0    = $Pool_Algorithm_Norm
                CoinName      = $Pool_CoinName
                CoinSymbol    = $Pool_Currency
                Currency      = $Pool_Currency
                Price         = 0
                StablePrice   = 0
                MarginOfError = 0
                Protocol      = "stratum+$(if ($Pool_Host_Data.ssl) {"ssl"} else {"tcp"})"
                Host          = "$($Pool_Host_Data.host)"
                Port          = $Pool_Host_Data.port
                User          = "$($Pool_User).{workername:$Worker}"
                Pass          = "x"
                Region        = $Pool_RegionsTable.$Pool_Region
                SSL           = [bool]$Pool_Host_Data.ssl
                Updated       = (Get-Date).ToUniversalTime()
                PoolFee       = $Pool_Fee
                Workers       = $null
                Hashrate      = $null
                BLK           = $null
                TSL           = $null
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
                Wallet        = $Pool_User
                Worker        = "{workername:$Worker}"
                Email         = $Email
            }
         }
    }
}
