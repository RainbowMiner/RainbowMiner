using module ..\Modules\Include.psm1

param(
    [String]$Name,
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

# $Name = Get-Item $MyInvocation.MyCommand.Path | Select-Object -ExpandProperty BaseName

$Pools_Request       = [PSCustomObject]@{}
try {
    $Pools_Request = Invoke-RestMethodAsync "https://api.woolypooly.com/api/stats" -tag $Name -timeout 15 -cycletime 120 -delay 250
}
catch {
    Write-Log -Level Warn "Pool API ($Name) for $Pool_Currency has failed. "
    return
}

$Pools_Data = @(
    [PSCustomObject]@{symbol = "AE";   port = 20000; host = "ae"; rpc = "aeternity-1"}
    [PSCustomObject]@{symbol = "ALPH"; port = 3106; host = "alph"; rpc = "alph-1"}
    [PSCustomObject]@{symbol = "BLOCX";  port = 3148; host = "blocx"; rpc = "blocx-1"}
    [PSCustomObject]@{symbol = "CFX";  port = 3094; host = "cfx"; rpc = "cfx-1"}
    [PSCustomObject]@{symbol = "CLO";  port = 3126; host = "clore"; rpc = "clore-1"}
    [PSCustomObject]@{symbol = "CTXC"; port = 40000; host = "cortex"; rpc = "cortex-1"}
    [PSCustomObject]@{symbol = "ERG";  port = 3100; host = "erg"; rpc = "ergo-1"}
    [PSCustomObject]@{symbol = "ETC";  port = 35000; host = "etc"; rpc = "etc-1"}
    [PSCustomObject]@{symbol = "ETHW";  port = 3096; host = "ethw"; rpc = "ethw-1"}
    [PSCustomObject]@{symbol = "FIRO"; port = 3104; host = "firo"; rpc = "firo-1"}
    #[PSCustomObject]@{symbol = "HTN"; port = 3142; host = "htn"; rpc = "htn-1"}
    [PSCustomObject]@{symbol = "KAS"; port = 3112; host = "kas"; rpc = "kas-1"}
    [PSCustomObject]@{symbol = "KLS"; port = 3132; host = "kls"; rpc = "kls-1"}
    [PSCustomObject]@{symbol = "MEWC"; port = 3116; host = "mewc"; rpc = "mewc-1"}
    [PSCustomObject]@{symbol = "NEXA"; port = 3124; host = "nexa"; rpc = "nexa-1"}
    [PSCustomObject]@{symbol = "NOVO"; port = 3134; host = "novo"; rpc = "novo-1"}
    [PSCustomObject]@{symbol = "OCTA"; port = 3130; host = "octa"; rpc = "octa-1"}
    [PSCustomObject]@{symbol = "RTM"; port = 3110; host = "rtm"; rpc = "rtm-1"}
    [PSCustomObject]@{symbol = "RVN";  port = 55555; host = "rvn"; rpc = "raven-1"}
    [PSCustomObject]@{symbol = "RXD"; port = 3122; host = "rxd"; rpc = "rxd-1"}
    [PSCustomObject]@{symbol = "SDR"; port = 3144; host = "sdr"; rpc = "sdr-1"}
    [PSCustomObject]@{symbol = "VTC"; port = 3102; host = "vtc"; rpc = "vtc-1"}
    [PSCustomObject]@{symbol = "WART"; port = 3140; host = "wart"; rpc = "wart-1"}
    [PSCustomObject]@{symbol = "XEL"; port = 3150; host = "xel"; rpc = "xel-1"}
    [PSCustomObject]@{symbol = "XNA"; port = 3128; host = "xna"; rpc = "xna-1"}
    [PSCustomObject]@{symbol = "ZANO"; port = 3146; host = "zano"; rpc = "zano-1"}
)

$Pool_PayoutScheme = "SOLO"
$Pool_Region = Get-Region "eu"

$Pools_Data | Where-Object {$Pool_Currency = $_.symbol -replace "-.+$";$Pools_Request."$($_.rpc)" -and ($Wallets.$Pool_Currency -or $InfoOnly)} | ForEach-Object {
    $Pool_Coin      = Get-Coin $_.symbol
    $Pool_Port      = $_.port + 1
    $Pool_RpcPath   = $_.rpc

    $Pool_Algorithm_Norm = $Pool_Coin.algo

    $Pool_EthProxy  = if ($Pool_Algorithm_Norm -match $Global:RegexAlgoHasEthproxy) {"qtminer"} else {$null}

    $Pool_Diff = [double]$Pools_Request.$Pool_RpcPath.netHashrate * $Pools_Request.$Pool_RpcPath.blockTime / 4294967296 #2^32

    $Pool_Request = [PSCustomObject]@{}

    if (-not $InfoOnly) {
        $Stat = Set-Stat -Name "$($Name)_$($_.symbol)_Profit" -Value 0 -Duration $StatSpan -ChangeDetection $false -Difficulty $Pool_Diff -Quiet
    }

    foreach($Pool_SSL in @($false,$true)) {
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
            Host          = "pool.woolypooly.com"
            Port          = $Pool_Port
            User          = "$($Wallets.$Pool_Currency).{workername:$Worker}"
            Pass          = "x"
            Region        = $Pool_Region
            SSL           = $Pool_SSL
            WTM           = $true
            Updated       = $Stat.Updated
            Workers       = $Pool_AlgoStats.minersTotal
            PoolFee       = $Pools_Request.$Pool_RpcPath.fee
            Hashrate      = $null
            TSL           = $null
            BLK           = $null
            Difficulty    = $Stat.Diff_Average
            SoloMining    = $true
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
}
