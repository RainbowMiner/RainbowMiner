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
    [String]$Name = ""
)

$Session.Config.Userpools | Where-Object {$_.Name -eq $Name -and $_.Enable -and ($Wallets."$($_.Currency)" -or $InfoOnly)} | ForEach-Object {
    $Pool_Coin      = Get-Coin $_.CoinSymbol
    $Pool_Algorithm_Norm = Get-Algorithm "$(if ($Pool_Coin) {Get-Algorithm $Pool_Coin.Algo} else {$_.Algorithm})"
    $Pool_Wallet    = $Wallets."$($_.Currency)"

    if (-not $InfoOnly) {
        $Stat = Set-Stat -Name "$($_.Name)_$($Pool_Algorithm_Norm)_$($_.CoinSymbol)_Profit" -Value 0 -Duration $StatSpan -ChangeDetection $false -Quiet
    }

    [PSCustomObject]@{
        Algorithm     = $Pool_Algorithm_Norm
		Algorithm0    = $Pool_Algorithm_Norm
        CoinName      = "$(if ($Pool_Coin) {$Pool_Coin.Name} elseif ($_.CoinName) {$_.CoinName} else {$_.CoinSymbol})"
        CoinSymbol    = "$($_.CoinSymbol)".ToUpper()
        Currency      = "$($_.Currency)".ToUpper()
        Price         = 0
        StablePrice   = 0
        MarginOfError = 0
        Protocol      = "$(if ($_.Protocol) {$_.Protocol} else {"stratum+$(if ($_.SSL) {"ssl"} else {"tcp"})"})"
        Host          = $_.Host
        Port          = $_.Port
        User          = "$(if ($_.User) {$_.User} else {"`$Wallet.`$WorkerName"})".Replace("`$Wallet",$Pool_Wallet).Replace("`$WorkerName","{workername:$Worker}")
        Pass          = "$(if ($_.Pass) {$_.Pass} else {"x"})"
        Region        = "$(if ($_.Region) {Get-Region $_.Region} else {"US"})"
        SSL           = $_.SSL
        WTM           = $true
        Updated       = (Get-Date).ToUniversalTime()
        Workers       = $null
        PoolFee       = $_.PoolFee
        Hashrate      = $null
        TSL           = $null
        BLK           = $null
        EthMode       = "$(if ($Pool_Algorithm_Norm -match $Global:RegexAlgoHasEthproxy) {$_.EthMode} else {$null})"
        Name          = $Name
        Penalty       = 0
        PenaltyFactor = 1
        Disabled      = $false
        HasMinerExclusions = $false
        Price_Bias    = 0.0
        Price_Unbias  = 0.0
        Wallet        = $Pool_Wallet
        Worker        = "{workername:$Worker}"
        Email         = $Email
    }
}
