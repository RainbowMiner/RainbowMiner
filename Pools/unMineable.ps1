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
    [PSCustomObject]@{algo = "autolykos";  port = @(3333,4444); ethproxy = $null;          rpc = "autolykos";  divisor = 1e6; region = @("us","ca","eu","asia")}
    [PSCustomObject]@{algo = "ethash";     port = @(3333);      ethproxy = "ethstratumnh"; rpc = "ethash";     divisor = 1e6; region = @("us","ca","eu","asia")}
    [PSCustomObject]@{algo = "etchash";    port = @(3333);      ethproxy = "ethstratumnh"; rpc = "etchash";    divisor = 1e6; region = @("us","eu","asia")}
    [PSCustomObject]@{algo = "randomx";    port = @(3333,443);  ethproxy = $null;          rpc = "rx";         divisor = 1;   region = @("us","eu","asia")}
    [PSCustomObject]@{algo = "kawpow";     port = @(3333);      ethproxy = "stratum";      rpc = "kp";         divisor = 1e6; region = @("us","eu","asia")}
)

$Pool_Referrals = [PSCustomObject]@{
    "1INCH" = "fy3x-kyu5"
    AAVE = "41qp-kz9q"
    ADA = "6va0-s40b"
    ALGO = "mnh2-9i5u"
    APE = "tho7-kex8"
    ATOM = "rkzy-ct1s"
    AVAX = "daax-rm2h"
    BAND = "d04a-ce0q"
    BAT = "9gwg-r21y"
    BCH = "d5n0-12uj"
    BNB = "09eg-lit0"
    BTC = "9fh9-4fa8"
    BTG = "ad7b-d4tl"
    CAKE = "jvjw-oe6g"
    CHZ = "s205-1crw"
    CRO = "e5vr-nl66"
    DASH = "ux3r-os4a"
    DGB = "ysw1-6l8f"
    DOGE = "5oln-msuu"
    ELON = "re67-y6da"
    ENJ = "f2j8-u7yh"
    EOS = "vxnn-bcmf"
    ETC = "rd39-9u37"
    ETH = "61lr-wpcz"
    FTM = "gqgp-02zh"
    FUN = "nh4x-spqg"
    GALA = "48ne-szrx"
    GAS = "7sae-7dyj"
    HOT = "et4j-moy3"
    ICX = "cnsz-7dbi"
    KNC = "isfr-bpog"
    LINK = "8tm5-1sts"
    LSK = "6nli-2hpf"
    LTC = "siif-qx8i"
    MANA = "awsm-eqwi"
    MATIC = "kn0o-dzfz"
    MTL = "3lyx-b4oo"
    NANO = "1x7t-hiis"
    NEO = "9vwe-a1uc"
    QTUM = "yd6u-nsc6"
    REP = "mn87-e9jl"
    RSR = "s9v8-1yff"
    RVN = "7mkm-dj0t"
    SC = "whhb-qst0"
    SHIB = "dqak-tlkv"
    SOL = "44vx-wkp4"
    SUSHI = "vzm5-yhp6"
    TRX = "zxih-o6yi"
    UNI = "klty-w0jc"
    USDT = "p8pi-sju9"
    VET = "fvcq-tr1n"
    WAVES = "k9oe-8z69"
    WBTC = "dsos-mr20"
    WIN = "ucgt-hhgl"
    XLM = "mvri-yw11"
    XMR = "b4xt-40za"
    XRP = "1kp2-2sxz"
    XTZ = "c4qu-cls0"
    XVG = "i3c5-1h08"
    YFI = "gsx6-01j1"
    ZEC = "tp3d-km6s"
    ZIL = "qkze-gt4v"
    ZRX = "ar8a-rfqo"
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
                $Pool_ProfitRequest = Invoke-RestMethodAsync "https://api.unminable.com/v3/calculate/reward" -tag $Name -delay 100 -cycletime 120 -body @{algo=$Pool_RewardAlgo;coin=$Pool_Currency;mh=100}
            } catch {
                if ($Error.Count){$Error.RemoveAt(0)}
                Write-Log -Level Warn "Pool profit API ($Name) has failed for coin $($Pool_Currency). "
            }

            $ok = $Pool_ProfitRequest.algo -eq $Pool_RewardAlgo

            if ($ok) {
                $btcPrice = if ($Global:Rates.$Pool_Currency) {1/[double]$Global:Rates.$Pool_Currency} else {0}
                $Pool_Price = $btcPrice * $Pool_ProfitRequest.per_day / 100 / $_.divisor
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
                        Algorithm     = $Pool_Algorithm_Norm
                        Algorithm0    = $Pool_Algorithm_Norm
                        CoinName      = $Pool_CurrencyData.name
                        CoinSymbol    = $Pool_Currency
                        Currency      = $Pool_Currency
                        Price         = $Stat.$StatAverage #instead of .Live
                        StablePrice   = $Stat.$StatAverageStable
                        MarginOfError = $Stat.Week_Fluctuation
                        Protocol      = $Pool_Protocol
                        Host          = "$($_.rpc)$(if ($_.region.Count -gt 1) {"-$($Pool_Region)"}).unmineable.com"
                        Port          = $_.port
                        User          = $Pool_Wallet
                        Pass          = "x"
                        Region        = $Pool_RegionsTable.$Pool_Region
                        SSL           = $Pool_SSL
                        Updated       = $Stat.Updated
                        PoolFee       = if ($Pool_Referal) {0.75} else {1.0}
                        PaysLive      = $true
                        DataWindow    = $DataWindow
				        ErrorRatio    = $Stat.ErrorRatio
                        EthMode       = $Pool_EthProxy
                        Name          = $Name
                        Penalty       = 0
                        PenaltyFactor = 1
                        Disabled      = $false
                        HasMinerExclusions = $false
                        Price_0       = 0.0
                        Price_Bias    = 0.0
                        Price_Unbias  = 0.0
                        Wallet        = $Pool_Wallet
                        Worker        = "{workername:$Worker}"
                        Email         = $Email
                    }
                }
                $Pool_SSL = $true
            }
        }
    }
}
