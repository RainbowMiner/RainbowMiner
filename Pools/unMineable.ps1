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
    [String]$StatAverageStable = "Week",
    [String]$AECurrency = ""
)

# $Name = Get-Item $MyInvocation.MyCommand.Path | Select-Object -ExpandProperty BaseName

$Pool_CoinsRequest = [PSCustomObject]@{}

try {
    $Pool_CoinsRequest = Invoke-RestMethodAsync "https://api.unmineable.com/v4/coin" -tag $Name -cycletime 21600
}
catch {
    Write-Log -Level Warn "Pool API ($Name) has failed. "
    return
}

if (-not $Pool_CoinsRequest.success) {
    Write-Log -Level Warn "Pool API ($Name) returned nothing. "
    return
}

[hashtable]$Pool_RegionsTable = @{}

$Pool_Regions = @("us","ca","eu","asia")
$Pool_Regions | Foreach-Object {$Pool_RegionsTable.$_ = Get-Region $_}

$Pools_Data = @(
    [PSCustomObject]@{algo = "autolykos";  coin = "ERG"; port = @(3333,4444); ethproxy = $null;          rpc = "autolykos";  divisor = 1e6; mh = 1e4; region = @("us","ca","eu","asia")}
    [PSCustomObject]@{algo = "beamhash";   coin = "BEAM"; port = @(3333,4444); ethproxy = $null;          rpc = "beamhash";   divisor = 1;   mh = 100; region = @("us","ca","eu","asia")}
    [PSCustomObject]@{algo = "blake3alephium"; coin = "ALPH"; port = @(3333,4444); ethproxy = $null;      rpc = "blake3";     divisor = 1;   mh = 1e9; region = @("us","ca","eu","asia"); rewardalgo = "blake3"}
    [PSCustomObject]@{algo = "equihash";   coin = "ZEC"; port = @(3333,4444); ethproxy = $null;          rpc = "equihash";   divisor = 1;   mh = 1e4; region = @("us","ca","eu","asia")}
    [PSCustomObject]@{algo = "etchash";    coin = "ETC"; port = @(3333,4444); ethproxy = "ethstratumnh"; rpc = "etchash";    divisor = 1e6; mh = 5e3; region = @("us","ca","eu","asia")}
    [PSCustomObject]@{algo = "ethash";     coin = "ETHW"; port = @(3333,4444); ethproxy = "ethstratumnh"; rpc = "ethash";     divisor = 1e6; mh = 5e3; region = @("us","ca","eu","asia")}
    [PSCustomObject]@{algo = "fishhash";   coin = "IRON"; port = @(3333,4444); ethproxy = "stratum";      rpc = "fishhash";   divisor = 1;   mh = 1e9; region = @("us","ca","eu","asia")}
    [PSCustomObject]@{algo = "karlsenhashv2"; coin = "KLS"; port = @(3333,4444); ethproxy = $null;         rpc = "karlsenhash"; divisor = 1;  mh = 1e9; region = @("us","ca","eu","asia"); rewardalgo = "karlsenhash"}
    [PSCustomObject]@{algo = "kawpow";     coin = "RVN"; port = @(3333,4444); ethproxy = "stratum";      rpc = "kp";         divisor = 1e6; mh = 100; region = @("us","ca","eu","asia")}
    [PSCustomObject]@{algo = "kheavyhash"; coin = "KAS"; port = @(3333,4444); ethproxy = $null;          rpc = "kheavyhash"; divisor = 1;   mh = 1e9; region = @("us","ca","eu","asia")}
    [PSCustomObject]@{algo = "nexapow";    coin = "NEXA"; port = @(3333,4444); ethproxy = $null;          rpc = "nexapow";    divisor = 1;   mh = 1e9; region = @("us","ca","eu","asia")}
    [PSCustomObject]@{algo = "octopus";    coin = "CFX"; port = @(3333,4444); ethproxy = $null;          rpc = "octopus";    divisor = 1;   mh = 1e9; region = @("us","ca","eu","asia")}
    [PSCustomObject]@{algo = "randomx";    coin = "XMR"; port = @(3333,4444); ethproxy = $null;          rpc = "rx";         divisor = 1;   mh = 5e4; region = @("us","ca","eu","asia")}    
    [PSCustomObject]@{algo = "ghostrider"; coin = "RTM"; port = @(3333,4444); ethproxy = $null;          rpc = "ghostrider"; divisor = 1;   mh = 5e4; region = @("us","ca","eu","asia")}
    [PSCustomObject]@{algo = "xelishashv3";coin = "XEL"; port = @(3333,4444); ethproxy = $null;          rpc = "xelishash";  divisor = 1;   mh = 1e4; region = @("us","ca","eu","asia"); rewardalgo = "xelishash"}

    #[PSCustomObject]@{algo = "dynexsolve"; port = @(3333,4444); ethproxy = $null;          rpc = "dynexsolve"; divisor = 1;   mh = 1e4; region = @("us","ca","eu","asia")}
    #[PSCustomObject]@{algo = "ethashb3";   port = @(3333,4444); ethproxy = $null;          rpc = "ethashb3";   divisor = 1;   mh = 1e12; region = @("us","ca","eu","asia")}
    #[PSCustomObject]@{algo = "firopow";    port = @(3333,4444); ethproxy = $null;          rpc = "firopow";    divisor = 1e6; mh = 100; region = @("us","ca","eu","asia")}
    #[PSCustomObject]@{algo = "pyrinhashv2";  port = @(3333,4444); ethproxy = $null;          rpc = "pyrinhash";  divisor = 1;   mh = 1e9; region = @("us","ca","eu","asia"); rewardalgo = "pyrinhash"}
    #[PSCustomObject]@{algo = "sha512256d"; port = @(3333,4444); ethproxy = $null;          rpc = "sha512256d"; divisor = 1;   mh = 1e9; region = @("us","ca","eu","asia")}
    #[PSCustomObject]@{algo = "zelhash";    coin = "FLUX"; port = @(3333,4444); ethproxy = $null;          rpc = "zelhash";    divisor = 1;   mh = 100; region = @("us","ca","eu","asia")}
    #[PSCustomObject]@{algo = "zhash";      port = @(3333,4444); ethproxy = $null;          rpc = "zhash";      divisor = 1;   mh = 100; region = @("us","ca","eu","asia")}
)

$Pool_Referrals = [PSCustomObject]@{
    "1INCH" = "1svs-yea0"
    A = "p4si-q179"
    AAVE = "fosa-yqe2"
    ADA = "fpsw-w55b"
    ALGO = "vrl4-jzoe"
    ALPH = "xhog-3n2h"
    APE = "4q81-kgaz"
    APT = "ycj3-vsni"
    ATOM = "ic6q-07z3"
    AVAX = "xmzm-757r"
    BAT = "y8yu-fle9"
    BCH = "tmy8-h32j"
    BNB = "7etf-gaqv"
    BOME = "m310-dhlf"
    BONK = "agcw-njc6"
    BTC = "4tki-sy7e"
    CAKE = "m4q0-ijmx"
    CFX = "m4q6-x9pp"
    CHZ = "hbqc-9pxo"
    CRO = "e5vr-nl66"
    DASH = "lg3k-bdvv"
    DGB = "o0v1-mknd"
    DNX = "ssdg-svo1"
    DOGE = "1tue-l3w6"
    DOT = "6r7v-qzvp"
    ELON = "xlbi-djtr"
    ENJ = "gmdp-happ"
    EOS = "p4si-q179"
    ERG = "ib4y-he7q"
    ETC = "qkvo-xxa7"
    ETH = "sz8v-su2b"
    ETHW = "ko5g-m9z9"
    FLUX = "2w2n-fifj"
    FUN = "q00g-94gy"
    GALA = "lu1p-ld28"
    GAS = "1jpg-s7kt"
    HOT = "hgji-tmt3"
    ICX = "6q59-skcz"
    JUP = "hvnr-4dqd"
    KAS = "qq1p-uq9i"
    KNC = "jw9k-db7i"
    LINK = "7sna-43ok"
    LTC = "njan-ebtu"
    LUNC = "ac2o-wrf3"
    MANA = "qtut-ua8q"
    MATIC = "4qtu-uuh1"
    NANO = "1x7t-hiis"
    NEO = "q2ou-zidc"
    NEXA = "cc60-yyy5"
    PEPE = "jp13-14uk"
    QTUM = "mpmd-8cjz"
    RSR = "9ycq-kxhv"
    RTM = "0swo-94ti"
    RVN = "bqjd-08zn"
    SC = "62n8-3nzn"
    SHIB = "0hcq-ztsu"
    SOL = "zpqt-v3rw"
    SUSHI = "33v5-pkjv"
    TRX = "wpmm-8juc"
    UNI = "odf8-0vtf"
    VET = "l6wr-52k0"
    WBTC = "2xlm-0f06"
    WIF = "4vmv-ibrh"
    WIN = "15aw-8hft"
    WLD = "1vlh-ix4z"
    XEL = "8gk4-sj0w"
    XLM = "f7k1-ux6j"
    XMR = "qhky-kirz"
    XRP = "m6vk-imiz"
    XTZ = "ios2-qfwf"
    XVG = "w3fg-5nzr"
    YFI = "fet2-smsf"
    ZIL = "x6d0-by1v"
    ZRX = "yfq7-zx60"
}

$Pool_Currencies = $Pool_CoinsRequest.data | Where-Object {($Wallets."$($_.symbol)" -or ($_.symbol -eq "EOS" -and $Wallets."A" -and -not $Wallets."EOS")) -or $InfoOnly}

$Pools_Data | ForEach-Object {
    $Pool_RewardAlgo = if ($_.rewardalgo) {$_.rewardalgo} else {$_.algo}
    $Pool_Algorithm  = $_.algo
    $Pool_EthProxy   = $_.ethproxy
    $Pool_CoinSymbol = $_.coin
    $Pool_CoinName   = ($Pool_CoinsRequest.Data | Where-Object {$_.symbol -eq $Pool_CoinSymbol}).name

    if ($Pool_Algorithm -in @("ethash","kawpow") -and $Pool_CoinSymbol) {
        $Pool_Algorithm_Norm = Get-Algorithm $Pool_Algorithm -CoinSymbol $Pool_CoinSymbol
    } else {
        $Pool_Algorithm_Norm = Get-Algorithm $Pool_Algorithm
    }

    $Pool_DagSizeMax = $Pool_CoinSymbolMax = $null
    if ($Pool_Algorithm_Norm -match $Global:RegexAlgoHasDAGSize) {
        $Pool_DagSizeMax = Get-EthDAGSize -Algorithm $Pool_Algorithm_Norm -CoinSymbol $Pool_CoinSymbol
        $Pool_CoinSymbolMax = $Pool_CoinSymbol
    }

    foreach($Pool_CurrencyData in $Pool_Currencies) {

        $Pool_Currency = $Pool_CurrencyData.symbol
        $Pool_Price    = 0

        $ok = $true
        if (-not $InfoOnly) {
            $Pool_ProfitRequest = [PSCustomObject]@{}
            try {
                $Pool_ProfitRequest = Invoke-RestMethodAsync "https://api.unminable.com/v3/calculate/reward" -tag $Name -cycletime 240 -body @{algo=$Pool_RewardAlgo;coin=$Pool_Currency;mh=$_.mh}
            } catch {
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
                        #SSLSelfSigned      = $Pool_SSL
                        Updated            = $Stat.Updated
                        PoolFee            = if ($Pool_Referal) {0.75} else {1.0}
                        PaysLive           = $true
                        DataWindow         = $DataWindow
                        ErrorRatio         = $Stat.ErrorRatio
                        EthMode            = $Pool_EthProxy
                        CoinSymbolMax      = $Pool_CoinSymbolMax
                        DagSizeMax         = $Pool_DagSizeMax
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
