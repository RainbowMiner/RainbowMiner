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

# Himpool — https://himpool.com
# Multi-algorithm mining pool. Two regions: EU (eu.himpool.com) and India (in.himpool.com).
# This file handles PPLNS pools. See HimpoolSolo.ps1 for SOLO variants.

$Pool_Fee  = 2.0
$Pool_Type = "PPLNS"
$Pool_Region_Default = "eu"

[hashtable]$Pool_RegionsTable = @{}
@("eu","us","asia") | Foreach-Object {$Pool_RegionsTable.$_ = Get-Region $_}

# Map Himpool regional hostnames to RainbowMiner region keys
$Pool_RegionHosts = [PSCustomObject]@{
    "eu"    = "eu.himpool.com"
    "asia"  = "in.himpool.com"
}

# Supported coins: symbol, Himpool pool id, algorithm, port (mid-tier), coin display name
# Low/mid/high ports are three consecutive numbers; we advertise the mid (index 1) by default
# and add a low + high alternative via port metadata so RainbowMiner can pick on diff.
$Pools_Data = @(
    [PSCustomObject]@{symbol = "ALPH";      pid = "alph";                 algo = "Blake3";     port_low = 1361; port_mid = 1362; port_high = 1363; divisor = 1e18}
    [PSCustomObject]@{symbol = "ARRR";      pid = "arrr";                 algo = "Equihash";   port_low = 1417; port_mid = 1418; port_high = 1419; divisor = 1e8}
    [PSCustomObject]@{symbol = "BCH";       pid = "bch";                  algo = "Sha256d";    port_low = 1307; port_mid = 1308; port_high = 1309; divisor = 1e8}
    [PSCustomObject]@{symbol = "BTG";       pid = "btg";                  algo = "Equihash";   port_low = 1462; port_mid = 1463; port_high = 1464; divisor = 1e8}
    [PSCustomObject]@{symbol = "DGB";       pid = "dgb";                  algo = "Sha256d";    port_low = 1316; port_mid = 1317; port_high = 1318; divisor = 1e8}
    [PSCustomObject]@{symbol = "EPX";       pid = "epx";                  algo = "Ethash";     port_low = 1426; port_mid = 1427; port_high = 1428; divisor = 1e18}
    [PSCustomObject]@{symbol = "ETC";       pid = "etc";                  algo = "Etchash";    port_low = 1382; port_mid = 1383; port_high = 1384; divisor = 1e18}
    [PSCustomObject]@{symbol = "LTC";       pid = "ltc";                  algo = "Scrypt";     port_low = 1408; port_mid = 1409; port_high = 1410; divisor = 1e8}
    [PSCustomObject]@{symbol = "OCTA";      pid = "octaspace";            algo = "Ethash";     port_low = 1376; port_mid = 1377; port_high = 1378; divisor = 1e18}
    [PSCustomObject]@{symbol = "QUAI";      pid = "quai-sha256";          algo = "Sha256d";    port_low = 1364; port_mid = 1365; port_high = 1366; divisor = 1e18}
    [PSCustomObject]@{symbol = "QUAI";      pid = "quai-scrypt";          algo = "Scrypt";     port_low = 1370; port_mid = 1371; port_high = 1372; divisor = 1e18}
    [PSCustomObject]@{symbol = "XEC";       pid = "xec";                  algo = "Sha256d";    port_low = 1304; port_mid = 1305; port_high = 1306; divisor = 100}
    # Kerrigan multi-algo — three PoW variants under one chain
    [PSCustomObject]@{symbol = "KRGN-X11";  pid = "kerrigan-x11";         algo = "X11";        port_low = 1444; port_mid = 1445; port_high = 1446; divisor = 1e8; coin_symbol = "KRGN"}
    [PSCustomObject]@{symbol = "KRGN-KAWPOW";pid = "kerrigan-kawpow";     algo = "KawPow";     port_low = 1432; port_mid = 1433; port_high = 1434; divisor = 1e8; coin_symbol = "KRGN"}
    [PSCustomObject]@{symbol = "KRGN-EH200";pid = "kerrigan-equihash200"; algo = "Equihash";   port_low = 1438; port_mid = 1439; port_high = 1440; divisor = 1e8; coin_symbol = "KRGN"}
    [PSCustomObject]@{symbol = "KRGN-EH192";pid = "kerrigan-equihash192"; algo = "Equihash";   port_low = 1468; port_mid = 1469; port_high = 1470; divisor = 1e8; coin_symbol = "KRGN"}
)

# Fetch live pool state from Himpool API
$Pool_ApiBase = "https://himpool.com/api"
$Pool_Request = $null

try {
    $Pool_Request = Invoke-RestMethodAsync "$Pool_ApiBase/pools" -tag $Name -retry 5 -retrywait 250 -cycletime 120
}
catch {
    Write-Log -Level Warn "Pool API ($Name) has failed."
    return
}

if (-not $Pool_Request.pools) {
    Write-Log -Level Warn "Pool API ($Name) returned nothing."
    return
}

# Index pools by id for quick lookup
$Pool_ById = @{}
$Pool_Request.pools | ForEach-Object { $Pool_ById[$_.id] = $_ }

$Pools_Data | Where-Object {
    $Wallet_Symbol = if ($_.coin_symbol) { $_.coin_symbol } else { $_.symbol }
    $Wallets.$Wallet_Symbol -or $InfoOnly
} | ForEach-Object {

    $Pool_Id           = $_.pid
    $Pool_Symbol_RM    = $_.symbol                                  # what RainbowMiner keys by (e.g. KRGN-X11)
    $Pool_Symbol_Chain = if ($_.coin_symbol) { $_.coin_symbol } else { $_.symbol }  # actual chain symbol for wallet lookup
    $Pool_Algo_Hint    = $_.algo
    $Pool_Divisor      = $_.divisor
    $Pool_Port         = $_.port_mid

    # RainbowMiner coin DB lookup
    $Pool_Coin = Get-Coin $Pool_Symbol_RM
    if ($Pool_Coin) {
        $Pool_Algorithm_Norm = Get-Algorithm $Pool_Coin.Algo
    } else {
        $Pool_Algorithm_Norm = Get-Algorithm $Pool_Algo_Hint
    }

    # Pool-side live data
    $Pool_Live = $Pool_ById[$Pool_Id]
    if (-not $Pool_Live) {
        # Pool currently offline / disabled / unknown — skip quietly unless InfoOnly
        if (-not $InfoOnly) { return }
    }

    $Pool_Wallet = $Wallets.$Pool_Symbol_Chain

    $Pool_Hashrate = 0
    $Pool_Workers  = 0
    $Pool_TSL      = $null
    $Pool_BLK      = 0

    if (-not $InfoOnly -and $Pool_Live) {
        $Pool_Hashrate   = [double]($Pool_Live.poolStats.poolHashrate    | Select-Object -First 1)
        $Pool_Workers    = [int]   ($Pool_Live.poolStats.connectedMiners | Select-Object -First 1)
        $Net_Hashrate    = [double]($Pool_Live.networkStats.networkHashrate | Select-Object -First 1)

        if ($Pool_Live.lastPoolBlockTime) {
            try {
                $Pool_TSL = ((Get-Date).ToUniversalTime() - ([datetime]::Parse($Pool_Live.lastPoolBlockTime))).TotalSeconds
            } catch { $Pool_TSL = $null }
        }

        # Blocks-per-day estimate: 86400 / (network_target_spacing) * pool_share_of_network
        $Block_Time = if ($Pool_Live.networkStats.blockTime) { [double]$Pool_Live.networkStats.blockTime } else { 600 }
        if ($Net_Hashrate -gt 0 -and $Block_Time -gt 0) {
            $Pool_BLK = (86400.0 / $Block_Time) * ($Pool_Hashrate / $Net_Hashrate)
        }

        $Stat = Set-Stat -Name "$($Name)_$($Pool_Symbol_RM)_Profit" -Value 0 -Duration $StatSpan -ChangeDetection $false -HashRate $Pool_Hashrate -BlockRate $Pool_BLK -Quiet
        if (-not $Stat.HashRate_Live -and -not $AllowZero) { return }
    }

    # Emit one pool object per region
    foreach ($Region_Key in @("eu","asia")) {
        $Host = $Pool_RegionHosts.$Region_Key
        if (-not $Host) { continue }

        [PSCustomObject]@{
            Algorithm         = $Pool_Algorithm_Norm
            Algorithm0        = $Pool_Algorithm_Norm
            CoinName          = if ($Pool_Coin) { $Pool_Coin.Name } else { $Pool_Symbol_Chain }
            CoinSymbol        = $Pool_Symbol_Chain
            Currency          = $Pool_Symbol_Chain
            Price             = 0
            StablePrice       = 0
            MarginOfError     = 0
            Protocol          = "stratum+tcp"
            Host              = $Host
            Port              = $Pool_Port
            User              = "$($Pool_Wallet).$($Worker)"
            Pass              = "x"
            Region            = $Pool_RegionsTable.$Region_Key
            SSL               = $false
            Updated           = (Get-Date).ToUniversalTime()
            PoolFee           = $Pool_Fee
            Workers           = $Pool_Workers
            Hashrate          = $Stat.HashRate_Live
            BLK               = $Stat.BlockRate_Average
            TSL               = $Pool_TSL
            WTM               = $false
            Name              = $Name
            Penalty           = 0
            PenaltyFactor     = 1
            Disabled          = $false
            HasMinerExclusions= $false
            Price_Bias        = 0.0
            Price_Unbias      = 0.0
            Wallet            = $Pool_Wallet
            Worker            = $Worker
            Email             = $null
        }
    }
}
