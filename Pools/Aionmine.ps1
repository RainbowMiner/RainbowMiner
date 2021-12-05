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
$Pool_Currency = "AION"
$Pool_Coin     = Get-Coin $Pool_Currency
$Pool_Fee = 0.5
$Pool_Default_Region = Get-Region "eu"

if (-not $Wallets.$Pool_Currency -and -not $InfoOnly) {return}

$Pool_Algorithm_Norm = Get-Algorithm $Pool_Coin.Algo

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

$Pool_Request.pools | Where-Object {$Pool_Currency = $_.coin.type;$Pool_User = $Wallets.$Pool_Currency;$Pool_User -or $InfoOnly} | Foreach-Object {
    $ok = $true
    if (-not $InfoOnly) {
        $Pool_Id = $_.id
        $Pool_BlocksRequest = @()
        try {
            $Pool_BlocksRequest = Invoke-RestMethodAsync "https://aionmine.org/api/pools/$($Pool_Id)/blocks?pageSize=500" -tag $Name -retry 3 -retrywait 1000 -timeout 15 -cycletime 120
            $Pool_BlocksRequest = @($Pool_BlocksRequest | Where-Object {$_.status -ne "orphaned"} | Foreach-Object {Get-Date $_.created})
        }
        catch {
            if ($Error.Count){$Error.RemoveAt(0)}
            Write-Log -Level Warn "Pool blocks API ($Name) for $Pool_Currency has failed. "
            $ok = $false
        }
        if ($ok -and ($Pool_BlocksRequest | Measure-Object).Count) {
            $timestamp24h = (Get-Date).AddHours(-24).ToUniversalTime()
            $blocks_measure = $Pool_BlocksRequest | Where-Object {$_ -gt $timestamp24h} | Measure-Object -Minimum -Maximum
            $Pool_BLK = [int]$($(if ($blocks_measure.Count -gt 1 -and ($blocks_measure.Maximum - $blocks_measure.Minimum).TotalSeconds) {24*3600/($blocks_measure.Maximum - $blocks_measure.Minimum).TotalSeconds} else {1})*$blocks_measure.Count)
            $Pool_TSL = ((Get-Date).ToUniversalTime() - $Pool_BlocksRequest[0]).TotalSeconds
        }

        $Stat = Set-Stat -Name "$($Name)_$($Pool_Currency)_Profit" -Value 0 -Duration $StatSpan -ChangeDetection $false -HashRate $_.poolStats.poolHashrate -BlockRate $Pool_BLK
        if (-not $Stat.HashRate_Live -and -not $AllowZero) {return}
    }

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
        Port          = 3333
        User          = "$($Pool_User).{workername:$Worker}"
        Pass          = "x"
        Region        = $Pool_Default_Region
        SSL           = $false
        Updated       = $Stat.Updated
        PoolFee       = $_.poolFeePercent
        DataWindow    = $DataWindow
        Workers       = $_.poolStats.connectedMiners
        Hashrate      = $Stat.HashRate_Live
        BLK           = $Stat.BlockRate_Average
        TSL           = $Pool_TSL
        WTM           = $true
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
