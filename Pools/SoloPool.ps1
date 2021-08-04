﻿using module ..\Modules\Include.psm1

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

$Pool_Fee = 1.5

$Pool_Request = [PSCustomObject]@{}
try {
    $Pool_Request = Invoke-RestMethodAsync "https://stats.solopool.org" -tag $Name -cycletime 120
}
catch {
    if ($Error.Count){$Error.RemoveAt(0)}
    Write-Log -Level Warn "Pool API ($Name) has failed. "
    return
}

if (($Pool_Request | Get-Member -MemberType NoteProperty -ErrorAction Ignore | Measure-Object Name).Count -le 1) {
    Write-Log -Level Warn "Pool API ($Name) returned nothing. "
    return
}

[hashtable]$Pool_Algorithms = @{}

$Pool_Request.PSObject.Properties.Name | Where-Object {$Pool_Currency = $_.ToUpper();($Wallets.$Pool_Currency -or ($Pool_Currency -eq "FIRO" -and $Wallets.XZC) -or $InfoOnly) -and $_ -notmatch "^dgb-"} | ForEach-Object {

    $Pool_Coin = Get-Coin $Pool_Currency

    $Pool_Algorithm = $Pool_Coin.Algo
    $Pool_CoinName  = $Pool_Coin.Name

    if (-not ($Pool_Wallet = $Wallets.$Pool_Currency)) {
        $Pool_Wallet = $Wallets.XZC
    }

    $ok = $false
    try {
        $Pool_HelpPage = Invoke-WebRequestAsync "https://$_.solopool.org/help" -tag $Name -cycletime 86400
        if ($Pool_HelpPage -match 'meta\s+name="arts-pool/config/environment"\s+content="(.+?)"') {
            $Pool_MetaVars = [System.Web.HttpUtility]::UrlDecode($Matches[1]) | ConvertFrom-Json -ErrorAction Stop
            $ok = $true
            if (-not $Pool_Coin) {
                $Pool_Algorithm = $Pool_MetaVars.TEMPLATE.algorithmTitle
                $Pool_CoinName  = $Pool_MetaVars.COIN.Name
            }
        }
    } catch {
        Write-Log -Level Warn "$($Name): $($Pool_Currency) help page not readable"
    }

    if (-not $Pool_Algorithm) {
        Write-Log -Level Warn "Pool $($Name) missing coin $($Pool_Currency)"
        return
    }

    if ($_ -eq "xwp" -or $_ -eq "xmr") {
        $Pool_User = $Pool_Wallet
        $Pool_Pass = "{workername:$Worker}"
    } else {
        $Pool_User = "$Pool_Wallet.{workername:$Worker}"
        $Pool_Pass = "x"
    }

    $Pool_PoolFee   = $_.fee

    if (-not $Pool_Algorithms.ContainsKey($Pool_Algorithm)) {$Pool_Algorithms.$Pool_Algorithm = Get-Algorithm $Pool_Algorithm}
    $Pool_Algorithm_Norm = $Pool_Algorithms.$Pool_Algorithm
    $Pool_EthProxy  = if ($Pool_Algorithm_Norm -match $Global:RegexAlgoHasEthproxy) {"ethproxy"} elseif ($Pool_Algorithm_Norm -eq "KawPOW") {"stratum"} else {$null}

    if ($ok) {
        $Pool_Host      = $Pool_MetaVars.APP.StratumHost
        $Pool_Port      = if ($Pool_MetaVars.APP.StratumPortVar) {$Pool_MetaVars.APP.StratumPortVar} else {$Pool_MetaVars.APP.StratumPortLow}

        if (-not $InfoOnly) {
            $Stat = Set-Stat -Name "$($Name)_$($Pool_Currency)_Profit" -Value 0 -Duration $StatSpan -ChangeDetection $false -HashRate (ConvertFrom-Hash $_.hashrate) -Quiet
        }
    }

    if ($ok -or $InfoOnly) {
        [PSCustomObject]@{
            Algorithm     = $Pool_Algorithm_Norm
            Algorithm0    = $Pool_Algorithm_Norm
            CoinName      = $Pool_CoinName
            CoinSymbol    = $Pool_Currency
            Currency      = $Pool_Currency
            Price         = 0
            StablePrice   = 0
            MarginOfError = 0
            Protocol      = "stratum+$(if ($_ -eq "beam") {"ssl"} else {"tcp"})"
            Host          = $Pool_Host
            Port          = $Pool_Port
            User          = $Pool_User
            Pass          = $Pool_Pass
            Region        = "US"
            SSL           = $_ -eq "beam"
            Updated       = (Get-Date).ToUniversalTime()
            PoolFee       = $Pool_PoolFee
            Workers       = $PoolCoins_Request.$Pool_Currency.workers
            Hashrate      = $Stat.HashRate_Live
            BLK           = $null
            TSL           = $null
            SoloMining    = $true
            WTM           = $true
            EthMode       = $Pool_EthProxy
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
}
