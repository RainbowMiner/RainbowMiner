using module ..\Include.psm1

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
    [String]$StatAverage = "Minute_10"
)

$Name = Get-Item $MyInvocation.MyCommand.Path | Select-Object -ExpandProperty BaseName
$Pool_Currency = "AION"
$Pool_Coin     = Get-Coin $Pool_Currency
$Pool_Fee = 0.5
$Pool_Default_Region = Get-Region "eu"

if (-not $Wallets.$Pool_Currency -and -not $InfoOnly) {return}

$Pool_Algorithm_Norm = Get-Algorithm $Pool_Coin.Algo

$Pool_Request = [PSCustomObject]@{}

try {
    $Pool_Request = Invoke-RestMethodAsync "https://api.aionmine.org/api/pools" -tag $Name -retry 3 -retrywait 1000 -cycletime 120
    if (-not $Pool_Request.pools) {throw}
}
catch {
    if ($Error.Count){$Error.RemoveAt(0)}
    Write-Log -Level Warn "Pool API ($Name) for $($Pool_Currency) has failed. "
    return
}

$Pool_Request.pools | Where-Object {$Pool_Currency = $_.coin.type;$Pool_User = $Wallets.$Pool_Currency;($_.poolStats.poolHashrate -gt 0 -or $AllowZero) -and $Pool_User -or $InfoOnly} | Foreach-Object {
    
    $Pool_BLK      = [Math]::Floor(86400 / $_.networkStats.networkDifficulty * $_.poolStats.poolHashrate)
    $reward        = 1.5
    $btcPrice      = if ($Session.Rates.$Pool_Currency) {1/[double]$Session.Rates.$Pool_Currency} else {0}
    $btcRewardLive = if ($_.poolStats.poolHashrate -gt 0) {$btcPrice * $reward * $Pool_BLK / $_.poolStats.poolHashrate} else {0}
    $Divisor       = 1
    
    if (-not $InfoOnly) {
        $Stat = Set-Stat -Name "$($Name)_$($Pool_Currency)_Profit" -Value ($btcRewardLive/$Divisor) -Duration $StatSpan -ChangeDetection $true -HashRate $_.poolStats.poolHashrate -BlockRate $Pool_BLK
    }

    [PSCustomObject]@{
        Algorithm     = $Pool_Algorithm_Norm
        CoinName      = $Pool_Coin.Name
        CoinSymbol    = $Pool_Currency
        Currency      = $Pool_Currency
        Price         = $Stat.$StatAverage #instead of .Live
        StablePrice   = $Stat.Week
        MarginOfError = $Stat.Week_Fluctuation
        Protocol      = "stratum+tcp"
        Host          = "stratum.aionmine.org"
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
        #TSL           = $Pool_TSL
        AlgorithmList = if ($Pool_Algorithm_Norm -match "-") {@($Pool_Algorithm_Norm, ($Pool_Algorithm_Norm -replace '\-.*$'))}else{@($Pool_Algorithm_Norm)}
        Name          = $Name
        Penalty       = 0
        PenaltyFactor = 1
        Wallet        = $Pool_User
        Worker        = "{workername:$Worker}"
        Email         = $Email
    }
}
