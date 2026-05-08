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

# Himpool — https://himpool.com — Miningcore-based multi-algorithm pool.
# Driven entirely from the public aggregator endpoint /api/v1/public, which already
# groups pools by coin, exposes per-coin region availability via stratums[], and
# returns deduped port metadata. Adding or removing coins on Himpool requires no
# script changes — RainbowMiner picks up changes on the next refresh cycle.
#
# This file emits the PPLNS variants. See HimpoolSolo.ps1 for SOLOLoyalty.

$Pool_Type           = "PPLNS"
$Pool_Region_Default = "eu"

# Region keys we have stratum hosts for. Stratums returned by the API for any other
# region are skipped — protects against advertising a region that doesn't actually
# accept connections for the requested coin.
$Pool_RegionHosts = @{
    "eu" = "eu.himpool.com"
    "in" = "in.himpool.com"
}

# Per-coin region whitelist override. If a coin appears here, only the listed regions
# are emitted even if the upstream API reports more. Used when the pool's coinRegions
# map advertises a region whose stratum daemon hasn't actually been deployed yet.
$Pool_CoinRegionOverrides = @{
    "FIRO" = @("eu")
}

# Multi-PoW chains: same chain hosts multiple algorithms under distinct pool ids.
# Wallet lookup uses the chain symbol; stat keys + RainbowMiner currency code use the
# variant symbol so different algos don't collide in CoinDB or Set-Stat.
$Pool_PidToVariant = @{
    "quai-sha256"               = @{ symbol = "QUAI-SHA256"; chain = "QUAI"; algo = "Sha256" }
    "quai-sha256-solo"          = @{ symbol = "QUAI-SHA256"; chain = "QUAI"; algo = "Sha256" }
    "quai-scrypt"               = @{ symbol = "QUAI-SCRYPT"; chain = "QUAI"; algo = "Scrypt" }
    "quai-scrypt-solo"          = @{ symbol = "QUAI-SCRYPT"; chain = "QUAI"; algo = "Scrypt" }
    "kerrigan-x11"              = @{ symbol = "KRGN-X11";    chain = "KRGN"; algo = "X11" }
    "kerrigan-x11-solo"         = @{ symbol = "KRGN-X11";    chain = "KRGN"; algo = "X11" }
    "kerrigan-kawpow"           = @{ symbol = "KRGN-KAWPOW"; chain = "KRGN"; algo = "KawPow" }
    "kerrigan-kawpow-solo"      = @{ symbol = "KRGN-KAWPOW"; chain = "KRGN"; algo = "KawPow" }
    "kerrigan-equihash200"      = @{ symbol = "KRGN-EH200";  chain = "KRGN"; algo = "Equihash" }
    "kerrigan-equihash200-solo" = @{ symbol = "KRGN-EH200";  chain = "KRGN"; algo = "Equihash" }
    "kerrigan-equihash192"      = @{ symbol = "KRGN-EH192";  chain = "KRGN"; algo = "Equihash" }
    "kerrigan-equihash192-solo" = @{ symbol = "KRGN-EH192";  chain = "KRGN"; algo = "Equihash" }
}

[hashtable]$Pool_RegionLabels = @{}
$Pool_RegionHosts.Keys | ForEach-Object { $Pool_RegionLabels.$_ = Get-Region $_ }

$Pool_Request = $null
try {
    $Pool_Request = Invoke-RestMethodAsync "https://himpool.com/api/v1/public" -tag $Name -retry 5 -retrywait 250 -cycletime 120
}
catch {
    Write-Log -Level Warn "Pool API ($Name) has failed."
    return
}

if (-not $Pool_Request.pools) {
    Write-Log -Level Warn "Pool API ($Name) returned nothing."
    return
}

$Pool_Request.pools | ForEach-Object {
    $Coin_Symbol  = $_.symbol
    $Coin_Algo    = $_.algorithm
    $Coin_Name    = $_.name
    $Coin_Streams = @($_.stratums)
    $Coin_Schemes = @($_.schemes)
    $Coin_Ports   = @($_.ports)

    if (-not $Coin_Schemes -or -not $Coin_Streams -or -not $Coin_Ports) { return }

    $Allowed_Regions = if ($Pool_CoinRegionOverrides.ContainsKey($Coin_Symbol)) {
        $Pool_CoinRegionOverrides[$Coin_Symbol]
    } else {
        @($Pool_RegionHosts.Keys)
    }

    # Single port per region: prefer mid-tier (index 1 of 3), else first available.
    $Pool_Port = if ($Coin_Ports.Count -ge 3) { $Coin_Ports[1] } else { $Coin_Ports[0] }
    if (-not $Pool_Port) { return }
    $Pool_PortNumber = [int]$Pool_Port.port
    $Pool_PortTLS    = [bool]$Pool_Port.tls

    $Coin_Schemes | Where-Object { $_.scheme -eq "PPLNS" } | ForEach-Object {
        $Scheme = $_

        if ($Pool_PidToVariant.ContainsKey($Scheme.poolId)) {
            $Variant        = $Pool_PidToVariant[$Scheme.poolId]
            $Pool_Symbol_RM = $Variant.symbol
            $Pool_Chain     = $Variant.chain
            $Pool_AlgoHint  = $Variant.algo
        } else {
            $Pool_Symbol_RM = $Coin_Symbol
            $Pool_Chain     = $Coin_Symbol
            $Pool_AlgoHint  = $Coin_Algo
        }

        $Pool_Wallet = $Wallets.$Pool_Chain
        if (-not $Pool_Wallet -and -not $InfoOnly) { return }

        $Pool_Coin = Get-Coin $Pool_Symbol_RM
        if ($Pool_Coin) {
            $Pool_Algorithm_Norm = Get-Algorithm $Pool_Coin.Algo
        } else {
            $Pool_Algorithm_Norm = Get-Algorithm $Pool_AlgoHint -CoinSymbol $Pool_Chain
        }

        $Pool_EthProxy = if ($Pool_Algorithm_Norm -match $Global:RegexAlgoHasEthproxy) {"qtminer"}
                         elseif ($Pool_Algorithm_Norm -match $Global:RegexAlgoIsProgPow) {"stratum"}
                         else {$null}

        $Pool_Hashrate = [double]$Scheme.hashrate
        $Pool_Workers  = [int]   $Scheme.workers
        $Pool_TSL      = $null
        if ($Scheme.lastBlockTime) {
            try { $Pool_TSL = ((Get-Date).ToUniversalTime() - ([datetime]::Parse($Scheme.lastBlockTime))).TotalSeconds } catch {}
        }

        $Stat = $null
        if (-not $InfoOnly) {
            $Stat = Set-Stat -Name "$($Name)_$($Pool_Symbol_RM)_Profit" -Value 0 -Duration $StatSpan -ChangeDetection $false -HashRate $Pool_Hashrate -BlockRate 0 -Quiet
            if (-not $Stat.HashRate_Live -and -not $AllowZero) { return }
        }

        $Coin_Streams | Where-Object { $Allowed_Regions -contains $_.region } | ForEach-Object {
            $Region_Key = $_.region
            $Pool_Host  = $Pool_RegionHosts.$Region_Key
            if (-not $Pool_Host) { return }

            [PSCustomObject]@{
                Algorithm         = $Pool_Algorithm_Norm
                Algorithm0        = $Pool_Algorithm_Norm
                CoinName          = if ($Pool_Coin) { $Pool_Coin.Name } else { $Coin_Name }
                CoinSymbol        = $Pool_Chain
                Currency          = $Pool_Chain
                Price             = 0
                StablePrice       = 0
                MarginOfError     = 0
                Protocol          = if ($Pool_PortTLS) { "stratum+ssl" } else { "stratum+tcp" }
                Host              = $Pool_Host
                Port              = $Pool_PortNumber
                User              = "$($Pool_Wallet).{workername:$Worker}"
                Pass              = "x"
                Region            = $Pool_RegionLabels.$Region_Key
                SSL               = $Pool_PortTLS
                Updated           = (Get-Date).ToUniversalTime()
                PoolFee           = [double]$Scheme.fee
                Workers           = $Pool_Workers
                Hashrate          = if ($Stat) { $Stat.HashRate_Live } else { 0 }
                BLK               = 0
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
            }
        }
    }
}
