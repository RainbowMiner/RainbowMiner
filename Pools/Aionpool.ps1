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
    $Pool_Request = Invoke-RestMethodAsync "https://api.aionpool.tech/api/pools" -tag $Name -retry 3 -retrywait 1000 -cycletime 120
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

$Pool_Regions = @("na","eu","asia")
$Pool_Regions | Foreach-Object {$Pool_RegionsTable.$_ = Get-Region $_}

$Pool_Request.pools | Where-Object {$Pool_Currency = $_.coin.type;$Pool_User = $Wallets.$Pool_Currency;$Pool_Currency -eq "AION" -and ($Pool_User -or $InfoOnly)} | Foreach-Object {
    $ok = $true

    $Pool_Coin = Get-Coin $Pool_Currency
    $Pool_Algorithm_Norm = Get-Algorithm $Pool_Coin.Algo

    if (-not $InfoOnly) {
        $Pool_Id = $_.id
        $Pool_BlocksRequest = @()
        try {
            $Pool_BlocksRequest = @((Invoke-RestMethodAsync "https://api.aionpool.tech/api/pools/$($Pool_Id)/blocks?pageSize=1000" -tag $Name -retry 3 -retrywait 1000 -timeout 15 -cycletime 120) | Foreach-Object {[PSCustomObject]@{created = Get-Date $_.created;status = $_.status;reward = $_.reward}})
        }
        catch {
            if ($Error.Count){$Error.RemoveAt(0)}
            Write-Log -Level Warn "Pool blocks API ($Name) for $Pool_Currency has failed. "
            $ok = $false
        }

        $btcRewardLive = 0

        if ($ok -and ($Pool_BlocksRequest | Measure-Object).Count) {

            $Pool_PerformanceRequest = @()
            try {
                $Pool_PerformanceRequest = @((Invoke-RestMethodAsync "https://api.aionpool.tech/api/pools/$($Pool_Id)/performance" -tag $Name -retry 3 -retrywait 1000 -timeout 15 -cycletime 3600).stats | Foreach-Object {[PSCustomObject]@{created = Get-Date $_.created;hashrate = $_.poolHashrate}})
            }
            catch {
                if ($Error.Count){$Error.RemoveAt(0)}
                Write-Log -Level Info "Pool performance API ($Name) for $Pool_Currency has failed. "
            }

            $timestamp24h = (Get-Date).AddHours(-24).ToUniversalTime()

            $Pool_BlocksRequest_Status = $Pool_BlocksRequest | Where-Object {$_.created -gt $timestamp24h} | Group-Object -Property status

            $blocks_measure = ($Pool_BlocksRequest_Status | Where-Object {$_.Name -eq "confirmed"}).Group | Measure-Object -Minimum -Maximum -Property created
            $blocks_reward  = (($Pool_BlocksRequest_Status | Where-Object {$_.Name -eq "confirmed"}).Group | Measure-Object -Average -Property reward).Average

            $blocks_count   = $blocks_measure.Count

            if (($Pool_BlocksRequest_Status | Where-Object {$_.Name -eq "pending"}).Count) {
                $blocks_measure_pending = ($Pool_BlocksRequest_Status | Where-Object {$_.Name -eq "pending"}).Group | Measure-Object -Minimum -Maximum -Property created
                if ($blocks_measure.Maximum -lt $blocks_measure_pending.Maximum) {$blocks_measure.Maximum = $blocks_measure_pending.Maximum}
                if (-not $blocks_measure.Minimum) {$blocks_measure.Minimum = $blocks_measure_pending.Minimum}
                $blocks_count += (1 - ($Pool_BlocksRequest_Status | Where-Object {$_.Name -eq "orphaned"}).Count / (($Pool_BlocksRequest_Status | Where-Object {$_.Name -eq "orphaned"}).Count + ($Pool_BlocksRequest_Status | Where-Object {$_.Name -eq "confirmed"}).Count)) * $blocks_measure_pending.Count
            }

            $Pool_BLK       = $(if ($blocks_count -gt 1 -and ($blocks_measure.Maximum - $blocks_measure.Minimum).TotalSeconds) {86400/($blocks_measure.Maximum - $blocks_measure.Minimum).TotalSeconds} else {1})*$blocks_count
            $Pool_TSL       = ((Get-Date).ToUniversalTime() - $Pool_BlocksRequest[0].created).TotalSeconds

            if (($Pool_PerformanceRequest | Measure-Object).Count) {
                $Pool_HR = ($Pool_PerformanceRequest | Where-Object {$_.created -ge $blocks_measure.Minimum} | Measure-Object -Average -Property hashrate).Average
                if (-not $Pool_HR) {$Pool_HR = ($Pool_PerformanceRequest | Measure-Object -Average -Property hashrate).Average}
            } else {
                $Pool_HR = $_.poolStats.poolHashrate
            }

            $btcPrice       = if ($Global:Rates.$Pool_Currency) {1/[double]$Global:Rates.$Pool_Currency} else {0}
            $btcRewardLive  = if ($Pool_HR) {$btcPrice * $blocks_reward * $Pool_BLK / $Pool_HR} else {0}
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
                    Protocol      = "stratum+$(if ($Pool_SSL) {"ssl"} else {"tcp"})"
                    Host          = "$($Pool_Region).aionpool.tech"
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
                    Price_0       = 0.0
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
