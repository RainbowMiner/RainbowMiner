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
    [String]$StatAverageStable = "Week",
    [String]$AECurrency = ""
)

$Name = Get-Item $MyInvocation.MyCommand.Path | Select-Object -ExpandProperty BaseName

$Pool_CoinsRequest = [PSCustomObject]@{}

try {
    $Pool_CoinsRequest = Invoke-RestMethodAsync "https://api.unmineable.com/v3/coins" -tag $Name -cycletime 21600
}
catch {
    if ($Error.Count){$Error.RemoveAt(0)}
    Write-Log -Level Warn "Pool API ($Name) has failed. "
    return
}

if (-not $Pool_CoinsRequest.coins) {
    Write-Log -Level Warn "Pool API ($Name) returned nothing. "
    return
}

[hashtable]$Pool_RegionsTable = @{}

$Pool_Regions = @("us","ca","eu","asia")
$Pool_Regions | Foreach-Object {$Pool_RegionsTable.$_ = Get-Region $_}

$Pools_Data = @(
    [PSCustomObject]@{algo = "autolykos";  port = @(3333,4444); ethproxy = $null;          rpc = "autolykos";  divisor = 1e6; mh = 1e4; region = @("us","ca","eu","asia")}
    [PSCustomObject]@{algo = "beamhash";   port = @(3333,4444); ethproxy = $null;          rpc = "beamhash";   divisor = 1;   mh = 100; region = @("us","ca","eu","asia")}
    [PSCustomObject]@{algo = "blake3alephium"; port = @(3333,4444); ethproxy = $null;      rpc = "blake3";     divisor = 1;   mh = 1e9; region = @("us","ca","eu","asia"); rewardalgo = "blake3"}
    [PSCustomObject]@{algo = "equihash";   port = @(3333,4444); ethproxy = $null;          rpc = "equihash";   divisor = 1;   mh = 1e4; region = @("us","ca","eu","asia")}
    [PSCustomObject]@{algo = "etchash";    port = @(3333,4444); ethproxy = "ethstratumnh"; rpc = "etchash";    divisor = 1e6; mh = 5e3; region = @("us","ca","eu","asia")}
    [PSCustomObject]@{algo = "ethash";     port = @(3333,4444); ethproxy = "ethstratumnh"; rpc = "ethash";     divisor = 1e6; mh = 5e3; region = @("us","ca","eu","asia")}
    [PSCustomObject]@{algo = "firopow";    port = @(3333,4444); ethproxy = $null;          rpc = "firopow";    divisor = 1e6; mh = 100; region = @("us","ca","eu","asia")}
    [PSCustomObject]@{algo = "ironfish";   port = @(3333,4444); ethproxy = $null;          rpc = "ironfish";   divisor = 1;   mh = 1e9; region = @("us","ca","eu","asia")}
    [PSCustomObject]@{algo = "karlsenhash"; port = @(3333,4444); ethproxy = $null;         rpc = "karlsenhash"; divisor = 1;  mh = 1e9; region = @("us","ca","eu","asia")}
    [PSCustomObject]@{algo = "kawpow";     port = @(3333,4444); ethproxy = "stratum";      rpc = "kp";         divisor = 1e6; mh = 100; region = @("us","ca","eu","asia")}
    [PSCustomObject]@{algo = "kheavyhash"; port = @(3333,4444); ethproxy = $null;          rpc = "kheavyhash"; divisor = 1;   mh = 1e9; region = @("us","ca","eu","asia")}
    [PSCustomObject]@{algo = "nexapow";    port = @(3333,4444); ethproxy = $null;          rpc = "nexapow";    divisor = 1;   mh = 1e9; region = @("us","ca","eu","asia")}
    [PSCustomObject]@{algo = "octopus";    port = @(3333,4444); ethproxy = $null;          rpc = "octopus";    divisor = 1;   mh = 1e9; region = @("us","ca","eu","asia")}
    [PSCustomObject]@{algo = "randomx";    port = @(3333,4444); ethproxy = $null;          rpc = "rx";         divisor = 1;   mh = 5e4; region = @("us","ca","eu","asia")}
    [PSCustomObject]@{algo = "zelhash";    port = @(3333,4444); ethproxy = $null;          rpc = "zelhash";    divisor = 1;   mh = 100; region = @("us","ca","eu","asia")}
    [PSCustomObject]@{algo = "zhash";      port = @(3333,4444); ethproxy = $null;          rpc = "zhash";      divisor = 1;   mh = 100; region = @("us","ca","eu","asia")}
)

$Pool_Referrals = [PSCustomObject]@{
    "1INCH" = "1svs-yea0"
    AAVE = "fosa-yqe2"
    ADA = "6va0-s40b"
    ALGO = "vrl4-jzoe"
    APE = "4q81-kgaz"
    APT = "ycj3-vsni"
    ATOM = "ic6q-07z3"
    AVAX = "xmzm-757r"
    BAND = "d04a-ce0q"
    BAT = "36zw-tmam"
    BCH = "tmy8-h32j"
    BNB = "1mwg-ft2s"
    BTC = "9fh9-4fa8"
    BTG = "ad7b-d4tl"
    CAKE = "m4q0-ijmx"
    CHZ = "hbqc-9pxo"
    CRO = "e5vr-nl66"
    DASH = "ux3r-os4a"
    DGB = "ysw1-6l8f"
    DOGE = "5oln-msuu"
    DOT = "6r7v-qzvp"
    ELON = "xlbi-djtr"
    ENJ = "gmdp-happ"
    EOS = "8q7w-yjxe"
    ERG = "ib4y-he7q"
    ETC = "qkvo-xxa7"
    ETH = "sz8v-su2b"
    ETHW = "ko5g-m9z9"
    FLUX = "2w2n-fifj"
    FTM = "oz1p-zo06"
    FUN = "q00g-94gy"
    GALA = "lu1p-ld28"
    GAS = "7sae-7dyj"
    HOT = "hgji-tmt3"
    ICX = "cnsz-7dbi"
    KAS = "pdmw-8pjh"
    KNC = "jw9k-db7i"
    LINK = "7sna-43ok"
    LSK = "r2hf-guhj"
    LTC = "njan-ebtu"
    LUNC = "ac2o-wrf3"
    MANA = "qtut-ua8q"
    MATIC = "81le-gb5c"
    MTL = "0b02-rnc3"
    NANO = "1x7t-hiis"
    NEO = "9vwe-a1uc"
    PEPE = "jp13-14uk"
    QTUM = "yd6u-nsc6"
    RSR = "9ycq-kxhv"
    RVN = "bqjd-08zn"
    SC = "whhb-qst0"
    SFM = "nki0-ycfn"
    SHIB = "0hcq-ztsu"
    SOL = "44vx-wkp4"
    SUSHI = "33v5-pkjv"
    TRX = "wpmm-8juc"
    UNI = "odf8-0vtf"
    USDT = "5tfd-jbel"
    VET = "l6wr-52k0"
    WAVES = "k9oe-8z69"
    WBTC = "2xlm-0f06"
    WIN = "15aw-8hft"
    WLD = "1vlh-ix4z"
    XLM = "eibb-xv0g"
    XMR = "qhky-kirz"
    XRP = "m6vk-imiz"
    XTZ = "ios2-qfwf"
    XVG = "i3c5-1h08"
    YFI = "fet2-smsf"
    ZEC = "tp3d-km6s"
    ZIL = "x6d0-by1v"
    ZRX = "yfq7-zx60"
}

$Pool_Currencies = $Pool_CoinsRequest.coins | Where-Object {$Wallets."$($_.symbol)" -or $InfoOnly}

$Pools_Data | ForEach-Object {
    $Pool_RewardAlgo = if ($_.rewardalgo) {$_.rewardalgo} else {$_.algo}
    $Pool_Algorithm_Norm = Get-Algorithm $_.algo
    $Pool_EthProxy = $_.ethproxy

    foreach($Pool_CurrencyData in $Pool_Currencies) {

        $Pool_Currency = $Pool_CurrencyData.symbol
        $Pool_Price    = 0

        $ok = $true
        if (-not $InfoOnly) {
            $Pool_ProfitRequest = [PSCustomObject]@{}
            try {
                $Pool_ProfitRequest = Invoke-RestMethodAsync "https://api.unminable.com/v3/calculate/reward" -tag $Name -delay 100 -cycletime 120 -body @{algo=$Pool_RewardAlgo;coin=$Pool_Currency;mh=$_.mh}
            } catch {
                if ($Error.Count){$Error.RemoveAt(0)}
                Write-Log -Level Warn "Pool profit API ($Name) has failed for coin $($Pool_Currency). "
            }

            $ok = $Pool_ProfitRequest.algo -eq $Pool_RewardAlgo

            if ($ok) {
                $btcPrice = if ($Global:Rates.$Pool_Currency) {1/[double]$Global:Rates.$Pool_Currency} else {0}
                $Pool_Price = $btcPrice * $Pool_ProfitRequest.per_day / $_.mh / $_.divisor
                $Stat = Set-Stat -Name "$($Name)_$($Pool_Algorithm_Norm)_$($Pool_Currency)_Profit" -Value $Pool_Price -Duration $StatSpan -ChangeDetection $($Pool_Price -gt 0) -Quiet
            }
        }

        if ($ok -or $InfoOnly) {
            $Pool_Referal = if ($Params.$Pool_Currency -match "^\w{4}-\w{4}$") {$Params.$Pool_Currency} elseif ($Pool_Referrals.$Pool_Currency) {$Pool_Referrals.$Pool_Currency}
            $Pool_Wallet = "$($Pool_Currency):$($Wallets.$Pool_Currency).{workername:$Worker}$(if ($Pool_Referal) {"#$($Pool_Referal)"})"

            $Pool_SSL = $false
            foreach($Pool_Port in $_.port) {
                $Pool_Protocol = "stratum+$(if ($Pool_SSL) {"ssl"} else {"tcp"})"
                foreach($Pool_Region in $_.region) {
                    [PSCustomObject]@{     
                        Algorithm          = $Pool_Algorithm_Norm
                        Algorithm0         = $Pool_Algorithm_Norm
                        CoinName           = $Pool_CurrencyData.name
                        CoinSymbol         = $Pool_Currency
                        Currency           = $Pool_Currency
                        Price              = $Stat.$StatAverage #instead of .Live
                        StablePrice        = $Stat.$StatAverageStable
                        MarginOfError      = $Stat.Week_Fluctuation
                        Protocol           = $Pool_Protocol
                        Host               = "$($_.rpc)$(if ($_.region.Count -gt 1) {"-$($Pool_Region)"}).unmineable.com"
                        Port               = $Pool_Port
                        User               = $Pool_Wallet
                        Pass               = "x"
                        Region             = $Pool_RegionsTable.$Pool_Region
                        SSL                = $Pool_SSL
                        Updated            = $Stat.Updated
                        PoolFee            = if ($Pool_Referal) {0.75} else {1.0}
                        PaysLive           = $true
                        DataWindow         = $DataWindow
                        ErrorRatio         = $Stat.ErrorRatio
                        EthMode            = $Pool_EthProxy
                        Name               = $Name
                        Penalty            = 0
                        PenaltyFactor      = 1
                        Disabled           = $false
                        HasMinerExclusions = $false
                        Price_0            = 0.0
                        Price_Bias         = 0.0
                        Price_Unbias       = 0.0
                        Wallet             = $Pool_Wallet
                        Worker             = "{workername:$Worker}"
                        Email              = $Email
                    }
                }
                $Pool_SSL = $true
            }
        }
    }
}
