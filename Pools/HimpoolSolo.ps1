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

# Himpool SOLO — https://himpool.com — Miningcore-based multi-algorithm pool.
# SOLOLoyalty distribution: 90% finder reward / 8% loyalty bonus / 2% pool fee.
# Two stratum regions: EU + India. See Himpool.ps1 for the PPLNS counterpart.

$Pool_Fee  = 2.0
$Pool_Type = "SOLO"
$Pool_Region_Default = "eu"

$Pool_RegionHosts = [PSCustomObject]@{
    "eu" = "eu.himpool.com"
    "in" = "in.himpool.com"
}

# Per-coin region availability. Coins not listed here default to all regions in
# $Pool_RegionHosts. Coins listed here are restricted to the named subset.
$Pool_CoinRegions = @{
    "ALPH" = @("eu")
    "BTG"  = @("eu")
    "ETC"  = @("in")
    "FIRO" = @("eu")
    "KMD"  = @("eu")
    "XMR"  = @("eu")
    "ZEC"  = @("eu")
}

[hashtable]$Pool_RegionsTable = @{}
@("eu","in") | Foreach-Object {$Pool_RegionsTable.$_ = Get-Region $_}

# QUAI hosts two PoW variants under one chain; Kerrigan hosts four — both use
# dedicated RM symbols so Set-Stat keys don't collide and the coin DB can't
# override the algo. coin_symbol resolves back to the chain symbol for wallet
# lookup.
$Pools_Data = @(
    [PSCustomObject]@{symbol = "ALPH";         pid = "alph-solo";                 algo = "Blake3";     port_low = 1361; port_mid = 1362; port_high = 1363; divisor = 1e18}
    [PSCustomObject]@{symbol = "ARRR";         pid = "arrr-solo";                 algo = "Equihash";   port_low = 1417; port_mid = 1418; port_high = 1419; divisor = 1e8}
    [PSCustomObject]@{symbol = "BCH";          pid = "bch-solo";                  algo = "Sha256d";    port_low = 1301; port_mid = 1302; port_high = 1303; divisor = 1e8}
    [PSCustomObject]@{symbol = "BTC";          pid = "btc-solo";                  algo = "Sha256d";    port_low = 1322; port_mid = 1323; port_high = 1324; divisor = 1e8}
    [PSCustomObject]@{symbol = "BTG";          pid = "btg-solo";                  algo = "Equihash";   port_low = 1465; port_mid = 1466; port_high = 1467; divisor = 1e8}
    [PSCustomObject]@{symbol = "DGB";          pid = "dgb-solo";                  algo = "Sha256d";    port_low = 1319; port_mid = 1320; port_high = 1321; divisor = 1e8}
    [PSCustomObject]@{symbol = "EPX";          pid = "etherprime-solo";           algo = "Ethash";     port_low = 1429; port_mid = 1430; port_high = 1431; divisor = 1e18}
    [PSCustomObject]@{symbol = "ETC";          pid = "etc-solo";                  algo = "Etchash";    port_low = 1385; port_mid = 1386; port_high = 1387; divisor = 1e18}
    [PSCustomObject]@{symbol = "FIRO";         pid = "firo-solo";                 algo = "FiroPow";    port_low = 1477; port_mid = 1478; port_high = 1479; divisor = 1e8}
    [PSCustomObject]@{symbol = "KMD";          pid = "kmd-solo";                  algo = "Equihash";   port_low = 1423; port_mid = 1424; port_high = 1425; divisor = 1e8}
    [PSCustomObject]@{symbol = "LRS";          pid = "lrs-solo";                  algo = "Ethash";     port_low = 1391; port_mid = 1392; port_high = 1393; divisor = 1e18}
    [PSCustomObject]@{symbol = "LTC";          pid = "ltc-solo";                  algo = "Scrypt";     port_low = 1411; port_mid = 1412; port_high = 1413; divisor = 1e8}
    [PSCustomObject]@{symbol = "OCTA";         pid = "octaspace-solo";            algo = "Ethash";     port_low = 1379; port_mid = 1380; port_high = 1381; divisor = 1e18}
    [PSCustomObject]@{symbol = "PPC";          pid = "ppc-solo";                  algo = "Sha256d";    port_low = 1331; port_mid = 1332; port_high = 1333; divisor = 1e6}
    [PSCustomObject]@{symbol = "QUAI-SHA256";  pid = "quai-sha256-solo";          algo = "Sha256d";    port_low = 1367; port_mid = 1368; port_high = 1369; divisor = 1e18; coin_symbol = "QUAI"}
    [PSCustomObject]@{symbol = "QUAI-SCRYPT";  pid = "quai-scrypt-solo";          algo = "Scrypt";     port_low = 1373; port_mid = 1374; port_high = 1375; divisor = 1e18; coin_symbol = "QUAI"}
    [PSCustomObject]@{symbol = "XEC";          pid = "xec-solo";                  algo = "Sha256d";    port_low = 1325; port_mid = 1326; port_high = 1327; divisor = 100}
    [PSCustomObject]@{symbol = "XMR";          pid = "xmr-solo";                  algo = "RandomX";    port_low = 1459; port_mid = 1460; port_high = 1461; divisor = 1e12}
    [PSCustomObject]@{symbol = "ZEC";          pid = "zec-solo";                  algo = "Equihash";   port_low = 1344; port_mid = 1345; port_high = 1346; divisor = 1e8}
    # Kerrigan multi-algo SOLO variants
    [PSCustomObject]@{symbol = "KRGN-X11";     pid = "kerrigan-x11-solo";         algo = "X11";        port_low = 1447; port_mid = 1448; port_high = 1449; divisor = 1e8; coin_symbol = "KRGN"}
    [PSCustomObject]@{symbol = "KRGN-KAWPOW";  pid = "kerrigan-kawpow-solo";      algo = "KawPow";     port_low = 1435; port_mid = 1436; port_high = 1437; divisor = 1e8; coin_symbol = "KRGN"}
    [PSCustomObject]@{symbol = "KRGN-EH200";   pid = "kerrigan-equihash200-solo"; algo = "Equihash";   port_low = 1441; port_mid = 1442; port_high = 1443; divisor = 1e8; coin_symbol = "KRGN"}
    [PSCustomObject]@{symbol = "KRGN-EH192";   pid = "kerrigan-equihash192-solo"; algo = "Equihash";   port_low = 1471; port_mid = 1472; port_high = 1473; divisor = 1e8; coin_symbol = "KRGN"}
)

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

$Pool_ById = @{}
$Pool_Request.pools | ForEach-Object { $Pool_ById[$_.id] = $_ }

$Pools_Data | Where-Object {
    $Wallet_Symbol = if ($_.coin_symbol) { $_.coin_symbol } else { $_.symbol }
    $Wallets.$Wallet_Symbol -or $InfoOnly
} | ForEach-Object {

    $Pool_Id           = $_.pid
    $Pool_Symbol_RM    = $_.symbol
    $Pool_Symbol_Chain = if ($_.coin_symbol) { $_.coin_symbol } else { $_.symbol }
    $Pool_Algo_Hint    = $_.algo
    $Pool_Divisor      = $_.divisor
    $Pool_PortNumber   = $_.port_mid

    $Pool_Coin = Get-Coin $Pool_Symbol_RM
    if ($Pool_Coin) {
        $Pool_Algorithm_Norm = Get-Algorithm $Pool_Coin.Algo
    } else {
        $Pool_Algorithm_Norm = Get-Algorithm $Pool_Algo_Hint -CoinSymbol $Pool_Symbol_Chain
    }

    $Pool_EthProxy = if ($Pool_Algorithm_Norm -match $Global:RegexAlgoHasEthproxy) {"qtminer"} elseif ($Pool_Algorithm_Norm -match $Global:RegexAlgoIsProgPow) {"stratum"} else {$null}

    $Pool_Live = $Pool_ById[$Pool_Id]
    if (-not $Pool_Live -and -not $InfoOnly) { return }

    $Pool_Wallet = $Wallets.$Pool_Symbol_Chain

    $Pool_PortTLS = $false
    if ($Pool_Live -and $Pool_Live.ports) {
        $Mid_PortInfo = $Pool_Live.ports.$Pool_PortNumber
        if ($Mid_PortInfo -and $Mid_PortInfo.tls) { $Pool_PortTLS = $true }
    }

    $Pool_Hashrate = 0
    $Pool_Workers  = 0
    $Pool_TSL      = $null
    $Pool_BLK      = 0

    if (-not $InfoOnly -and $Pool_Live) {
        $Pool_Hashrate = [double]($Pool_Live.poolStats.poolHashrate    | Select-Object -First 1)
        $Pool_Workers  = [int]   ($Pool_Live.poolStats.connectedMiners | Select-Object -First 1)
        $Net_Hashrate  = [double]($Pool_Live.networkStats.networkHashrate | Select-Object -First 1)

        if ($Pool_Live.lastPoolBlockTime) {
            try { $Pool_TSL = ((Get-Date).ToUniversalTime() - ([datetime]::Parse($Pool_Live.lastPoolBlockTime))).TotalSeconds } catch {}
        }

        $Block_Time = if ($Pool_Live.networkStats.blockTime) { [double]$Pool_Live.networkStats.blockTime } else { 600 }
        if ($Net_Hashrate -gt 0 -and $Block_Time -gt 0) {
            $Pool_BLK = (86400.0 / $Block_Time) * ($Pool_Hashrate / $Net_Hashrate)
        }

        $Stat = Set-Stat -Name "$($Name)_$($Pool_Symbol_RM)_Profit" -Value 0 -Duration $StatSpan -ChangeDetection $false -HashRate $Pool_Hashrate -BlockRate $Pool_BLK -Quiet
        if (-not $Stat.HashRate_Live -and -not $AllowZero) { return }
    }

    $Allowed_Regions = if ($Pool_CoinRegions.ContainsKey($Pool_Symbol_Chain)) {
        $Pool_CoinRegions[$Pool_Symbol_Chain]
    } else {
        @("eu","in")
    }

    foreach ($Region_Key in $Allowed_Regions) {
        $Pool_Host = $Pool_RegionHosts.$Region_Key
        if (-not $Pool_Host) { continue }

        [PSCustomObject]@{
            Algorithm         = $Pool_Algorithm_Norm
            Algorithm0        = $Pool_Algorithm_Norm
            CoinName          = if ($Pool_Coin) { $Pool_Coin.Name } else { $Pool_Symbol_Chain }
            CoinSymbol        = $Pool_Symbol_Chain
            Currency          = $Pool_Symbol_Chain
            Price             = 0
            StablePrice       = 0
            MarginOfError     = 0
            Protocol          = if ($Pool_PortTLS) { "stratum+ssl" } else { "stratum+tcp" }
            Host              = $Pool_Host
            Port              = $Pool_PortNumber
            User              = "$($Pool_Wallet).{workername:$Worker}"
            Pass              = "x"
            Region            = $Pool_RegionsTable.$Region_Key
            SSL               = $Pool_PortTLS
            Updated           = (Get-Date).ToUniversalTime()
            PoolFee           = $Pool_Fee
            Workers           = $Pool_Workers
            Hashrate          = $Stat.HashRate_Live
            BLK               = $Stat.BlockRate_Average
            TSL               = $Pool_TSL
            WTM               = $false
            EthMode           = $Pool_EthProxy
            Name              = $Name
            Penalty           = 0
            PenaltyFactor     = 1
            Disabled          = $false
            HasMinerExclusions= $false
            Price_Bias        = 0.0
            Price_Unbias      = 0.0
            Price_0           = 0.0
            Wallet            = $Pool_Wallet
            Worker            = "{workername:$Worker}"
            Email             = $null
            SoloMining        = $true
        }
    }
}
