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

    $Pool_Params = [ordered]@{
        Wallet     = $Wallets."$($_.Currency)"
        WorkerName = "{workername:$Worker}"
        Currency   = "$($_.Currency)".ToUpper()
        CoinSymbol = "$($_.CoinSymbol)".ToUpper()
    }

    $Pool_Coin     = Get-Coin $Pool_Params["CoinSymbol"]
    $Pool_User     = "$(if ($_.User) {$_.User} else {"`$Wallet.`$WorkerName"})"
    $Pool_Pass     = "$(if ($_.Pass) {$_.Pass} else {"x"})"
    $Pool_EthProxy = if ($Pool_Algorithm_Norm -match $Global:RegexAlgoHasEthproxy) {"ethproxy"} elseif ($Pool_Algorithm_Norm -eq "KawPOW") {"stratum"} else {$null}

    $Pool_Algorithm_Norm = Get-Algorithm "$(if ($_.Algorithm) {$_.Algorithm} else {$Pool_Coin.Algo})"

    if (-not $Pool_Algorithm_Norm) {
        Write-Log -Level Warn "Userpool $Name has no algorithm for coin $($Pool_Params["CoinSymbol"])"
        return
    }

    if (-not $InfoOnly) {
        $Stat = Set-Stat -Name "$($_.Name)_$($Pool_Algorithm_Norm)_$($Pool_Params["CoinSymbol"])_Profit" -Value 0 -Duration $StatSpan -ChangeDetection $false -Quiet
    }

    $Pool_Params.GetEnumerator() | Foreach-Object {
        $Pool_User = $Pool_User.Replace("`$$($_.Name)",$_.Value)
        $Pool_Pass = $Pool_Pass.Replace("`$$($_.Name)",$_.Value)
    }

    [PSCustomObject]@{
        Algorithm     = $Pool_Algorithm_Norm
		Algorithm0    = $Pool_Algorithm_Norm
        CoinName      = "$(if ($Pool_Coin) {$Pool_Coin.Name} elseif ($_.CoinName) {$_.CoinName} else {$_.CoinSymbol})"
        CoinSymbol    = $Pool_Params["CoinSymbol"]
        Currency      = $Pool_Params["Currency"]
        Price         = 0
        StablePrice   = 0
        MarginOfError = 0
        Protocol      = "$(if ($_.Protocol) {$_.Protocol} else {"stratum+$(if ($_.SSL) {"ssl"} else {"tcp"})"})"
        Host          = $_.Host
        Port          = $_.Port
        User          = $Pool_User
        Pass          = $Pool_Pass
        Region        = "$(if ($_.Region) {Get-Region $_.Region} else {"US"})"
        SSL           = $_.SSL
        WTM           = $true
        Updated       = (Get-Date).ToUniversalTime()
        Workers       = $null
        PoolFee       = $_.PoolFee
        Hashrate      = $null
        TSL           = $null
        BLK           = $null
        EthMode       = "$(if ($_.EthMode) {$_.EthMode} else {$Pool_EthProxy})"
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
