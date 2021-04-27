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

$Pool_Regions = @("us","eu","asia")
$Pool_Regions | Foreach-Object {$Pool_RegionsTable.$_ = Get-Region $_}

$Pools_Data = @(
    [PSCustomObject]@{algo = "ethash";  port = 3333; ethproxy = "ethstratumnh"; rpc = "ethash";  divisor = 1e6; region = @("us","eu","asia")}
    [PSCustomObject]@{algo = "etchash"; port = 3333; ethproxy = "ethstratumnh"; rpc = "etchash"; divisor = 1e6; region = @("us")}
    [PSCustomObject]@{algo = "randomx"; port = 3333; ethproxy = $null;          rpc = "rx";      divisor = 1;   region = @("us","eu","asia")}
    [PSCustomObject]@{algo = "kawpow";  port = 3333; ethproxy = "stratum";      rpc = "kp";      divisor = 1e6; region = @("us"); rewardalgo = "x16rv2"}
)

$Pool_Referrals = [PSCustomObject]@{
    AAVE = "41qp-kz9q"
    ADA = "6va0-s40b"
    ALGO = "mnh2-9i5u"
    ATOM = "uy7u-k3ji"
    BAND = "d04a-ce0q"
    BAT = "9gwg-r21y"
    BCH = "d5n0-12uj"
    BNB = "09eg-lit0"
    BTC = "9fh9-4fa8"
    BTG = "ad7b-d4tl"
    BTT = "2tik-a8gp"
    DASH = "ux3r-os4a"
    DGB = "ysw1-6l8f"
    DOGE = "5oln-msuu"
    ENJ = "f2j8-u7yh"
    EOS = "vxnn-bcmf"
    ETC = "rd39-9u37"
    ETH = "61lr-wpcz"
    FUN = "nh4x-spqg"
    GAS = "7sae-7dyj"
    ICX = "cnsz-7dbi"
    KNC = "isfr-bpog"
    LINK = "8tm5-1sts"
    LSK = "69ku-jyof"
    LTC = "siif-qx8i"
    MANA = "awsm-eqwi"
    MTL = "3lyx-b4oo"
    NANO = "1x7t-hiis"
    NEO = "9vwe-a1uc"
    QTUM = "yd6u-nsc6"
    REP = "mn87-e9jl"
    RSR = "s9v8-1yff"
    RVN = "7mkm-dj0t"
    SC = "whhb-qst0"
    SKY = "5j29-3kag"
    SUSHI = "vzm5-yhp6"
    TRX = "zxih-o6yi"
    UNI = "klty-w0jc"
    USDT = "q5p2-f3mz"
    VET = "fvcq-tr1n"
    VIA = "ik6e-brmn"
    WAVES = "k9oe-8z69"
    WBTC = "dsos-mr20"
    WIN = "2czl-sedo"
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
            $Pool_Wallet = "$($Pool_Currency):$($Wallets.$Pool_Currency).{workername:$Worker}$(if ($Pool_Referrals.$Pool_Currency) {"#$($Pool_Referrals.$Pool_Currency)"})"

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
                    Protocol      = "stratum+tcp"
                    Host          = "$($_.rpc)$(if ($_.region.Count -gt 1) {"-$($Pool_Region)"}).unmineable.com"
                    Port          = $_.port
                    User          = $Pool_Wallet
                    Pass          = "x"
                    Region        = $Pool_RegionsTable.$Pool_Region
                    SSL           = $false
                    Updated       = $Stat.Updated
                    PoolFee       = if ($Pool_Referrals.$Pool_Currency) {0.75} else {1.0}
                    PaysLive      = $true
                    DataWindow    = $DataWindow
				    ErrorRatio    = $Stat.ErrorRatio
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
    }
}
