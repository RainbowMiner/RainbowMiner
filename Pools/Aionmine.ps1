using module ..\Modules\Include.psm1

param(
    [PSCustomObject]$Wallets,
    [PSCustomObject]$Params,
    [alias("WorkerName")]
    [String]$Worker,
    [String]$Password,
    [TimeSpan]$StatSpan,
    [String]$DataWindow = "estimate_current",
    [Bool]$InfoOnly = $false,
    [Bool]$AllowZero = $false,
    [String]$StatAverage = "Minute_10",
    [String]$StatAverageStable = "Week"
)

$Name = Get-Item $MyInvocation.MyCommand.Path | Select-Object -ExpandProperty BaseName

if (-not $Wallets.AION -and -not $InfoOnly) {return}

$Pool_Request = [PSCustomObject]@{}

$ok = $false
try {
    $Pool_Request = Invoke-RestMethodAsync "https://aionmine.org/api/pools" -tag $Name -retry 3 -retrywait 1000 -cycletime 120
    if ($Pool_Request.pools) {$ok = $true}
}
catch {
    if ($Error.Count){$Error.RemoveAt(0)}
}

if (-not $ok) {
    Write-Log -Level Warn "Pool API ($Name) for $($Pool_Currency) has failed. "
    return
}

[hashtable]$Pool_RegionsTable = @{}

$Pool_Regions = @("eu")
$Pool_Regions | Foreach-Object {$Pool_RegionsTable.$_ = Get-Region $_}

$Pool_Request.pools | Where-Object {$Pool_Currency = $_.coin.type;$Pool_User = $Wallets.$Pool_Currency;$Pool_Currency -eq "AION" -and ($Pool_User -or $InfoOnly)} | Foreach-Object {
    $ok = $true

    $Pool_Coin = Get-Coin $Pool_Currency
    $Pool_Algorithm_Norm = Get-Algorithm $Pool_Coin.Algo

    if (-not $InfoOnly) {
        $Pool_Id = $_.id
        $Pool_BlocksRequest = @()
        try {
            $Pool_BlocksRequest = Invoke-RestMethodAsync "https://aionmine.org/api/pools/$($Pool_Id)/blocks?pageSize=500" -tag $Name -retry 3 -retrywait 1000 -timeout 15 -cycletime 120
            $Pool_BlocksRequest = @($Pool_BlocksRequest | Where-Object {$_.status -ne "orphaned"} | Foreach-Object {[PSCustomObject]@{created = Get-Date $_.created;status = $_.status;reward = $_.reward}})
        }
        catch {
            if ($Error.Count){$Error.RemoveAt(0)}
            Write-Log -Level Warn "Pool blocks API ($Name) for $Pool_Currency has failed. "
            $ok = $false
        }

        $btcRewardLive = 0

        if ($ok -and ($Pool_BlocksRequest | Measure-Object).Count) {
            $timestamp24h = (Get-Date).AddHours(-24).ToUniversalTime()

            $Pool_BlocksRequest_Completed = $Pool_BlocksRequest | Where-Object {$_.created -gt $timestamp24h -and $_.status -eq "confirmed"}

            $blocks_measure = $Pool_BlocksRequest_Completed | Measure-Object -Minimum -Maximum -Property created
            $blocks_reward  = ($Pool_BlocksRequest_Completed | Measure-Object -Average -Property reward).Average

            $Pool_BLK       = [int]$($(if ($blocks_measure.Count -gt 1 -and ($blocks_measure.Maximum - $blocks_measure.Minimum).TotalSeconds) {24*3600/($blocks_measure.Maximum - $blocks_measure.Minimum).TotalSeconds} else {1})*$blocks_measure.Count)
            $Pool_TSL       = ((Get-Date).ToUniversalTime() - $Pool_BlocksRequest[0].created).TotalSeconds

            $btcPrice       = if ($Global:Rates.$Pool_Currency) {1/[double]$Global:Rates.$Pool_Currency} else {0}
            $btcRewardLive  = if ($_.poolStats.poolHashrate) {$btcPrice * $blocks_reward * $Pool_BLK / $_.poolStats.poolHashrate} else {0}
        }

        $Stat = Set-Stat -Name "$($Name)_$($Pool_Currency)_Profit" -Value $btcRewardLive -Duration $StatSpan -ChangeDetection $false -HashRate $_.poolStats.poolHashrate -BlockRate $Pool_BLK
        if (-not $Stat.HashRate_Live -and -not $AllowZero) {return}
    }

    $Pool_Ports = @(foreach ($Port_SSL in @($false,$true)) {($_.ports.PSObject.Properties | Where-Object {$_.Value.tls -eq $Port_SSL} | Select-Object -First 1).Name})

    foreach ($Pool_Region in $Pool_Regions) {
        $Pool_SSL = $false
        foreach ($Pool_Port in $Pool_Ports) {
            if ($Pool_Port) {
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
                    Host          = "pool.aionmine.org"
                    Port          = $Pool_Port
                    User          = "$($Pool_User).{workername:$Worker}"
                    Pass          = "x"
                    Region        = $Pool_RegionsTable.$Pool_Region
                    SSL           = $Pool_SSL
                    Updated       = $Stat.Updated
                    PoolFee       = $_.poolFeePercent
                    DataWindow    = $DataWindow
                    Workers       = $_.poolStats.connectedMiners
                    Hashrate      = $Stat.HashRate_Live
                    BLK           = $Stat.BlockRate_Average
                    TSL           = $Pool_TSL
                    WTM           = -not $btcRewardLive
                    Name          = $Name
                    Penalty       = 0
                    PenaltyFactor = 1
                    Disabled      = $false
                    HasMinerExclusions = $false
                    Price_Bias    = 0.0
                    Price_Unbias  = 0.0
                    Wallet        = $Pool_User
                    Worker        = "{workername:$Worker}"
                    Email         = $Email
                }
            }
            $Pool_SSL = $true
        }
    }
}
