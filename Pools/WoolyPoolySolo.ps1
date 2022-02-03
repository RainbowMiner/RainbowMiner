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

$Pools_Request       = [PSCustomObject]@{}
try {
    $Pools_Request = Invoke-RestMethodAsync "https://api.woolypooly.com/api/stats" -tag $Name -timeout 15 -cycletime 120
}
catch {
    if ($Error.Count){$Error.RemoveAt(0)}
    Write-Log -Level Warn "Pool API ($Name) for $Pool_Currency has failed. "
    return
}

$Pools_Data = @(
    [PSCustomObject]@{symbol = "AE";   port = 20000; host = "ae"; rpc = "aeternity-1"}
    [PSCustomObject]@{symbol = "AION"; port = 33333; host = "aion"; rpc = "aion-1"}
    [PSCustomObject]@{symbol = "ALPH"; port = 3106; host = "alph"; rpc = "alph-1"}
    [PSCustomObject]@{symbol = "BTG";  port = 3090; host = "btg"; rpc = "btg-1"}
    [PSCustomObject]@{symbol = "CFX";  port = 3094; host = "cfx"; rpc = "cfx-1"}
    [PSCustomObject]@{symbol = "CTXC"; port = 40000; host = "cortex"; rpc = "cortex-1"}
    [PSCustomObject]@{symbol = "ERG";  port = 3100; host = "erg"; rpc = "ergo-1"}
    [PSCustomObject]@{symbol = "ETC";  port = 35000; host = "etc"; rpc = "etc-1"}
    [PSCustomObject]@{symbol = "ETH";  port = 3096; host = "eth"; rpc = "eth-1"}
    [PSCustomObject]@{symbol = "FIRO"; port = 3098; host = "firo"; rpc = "firo-1"}
    [PSCustomObject]@{symbol = "FLUX"; port = 3092; host = "zel"; rpc = "zel-1"}
    [PSCustomObject]@{symbol = "GRIN-PRI";  port = 12000; host = "grin"; rpc = "grin-1"}
    [PSCustomObject]@{symbol = "MWC-PRI"; port = 11000; host = "mwc"; rpc = "mwc-1"}
    [PSCustomObject]@{symbol = "RVN";  port = 55555; host = "rvn"; rpc = "raven-1"}
    [PSCustomObject]@{symbol = "SERO"; port = 8008; host = "sero"; rpc = "sero-1"}
    [PSCustomObject]@{symbol = "VEIL"; port = 3098; host = "veil"; rpc = "veil-1"}
    [PSCustomObject]@{symbol = "VTC"; port = 3102; host = "vtc"; rpc = "vtc-1"}
)

$Pool_PayoutScheme = "SOLO"
$Pool_Region = Get-Region "eu"

$Pools_Data | Where-Object {$Pool_Currency = $_.symbol -replace "-.+$";$Pools_Request."$($_.rpc)" -and ($Wallets.$Pool_Currency -or $InfoOnly)} | ForEach-Object {
    $Pool_Coin      = Get-Coin $_.symbol
    $Pool_Port      = $_.port + 1
    $Pool_RpcPath   = $_.rpc

    $Pool_Algorithm_Norm = Get-Algorithm $Pool_Coin.algo

    $Pool_EthProxy  = if ($Pool_Algorithm_Norm -match $Global:RegexAlgoHasEthproxy) {"qtminer"} else {$null}

    $Pool_Diff = [double]$Pools_Request.$Pool_RpcPath.netHashrate * $Pools_Request.$Pool_RpcPath.blockTime / [Math]::Pow(2,32)

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
            Price_Bias    = 0.0
            Price_Unbias  = 0.0
            Wallet        = $Wallets.$Pool_Currency
            Worker        = "{workername:$Worker}"
            Email         = $Email
        }
    }
}
