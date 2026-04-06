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
    [String]$User = ""
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
    [PSCustomObject]@{algo = "autolykos";  coin = "ERG"; port = @(3333,4444); ethproxy = $null;           rpc = "autolykos";  divisor = 1e6; mh = 1e4; region = @("us","ca","eu","asia")}
    [PSCustomObject]@{algo = "beamhash";   coin = "BEAM"; port = @(3333,4444); ethproxy = $null;          rpc = "beamhash";   divisor = 1;   mh = 100; region = @("us","ca","eu","asia")}
    [PSCustomObject]@{algo = "blake3alephium"; coin = "ALPH"; port = @(3333,4444); ethproxy = $null;      rpc = "blake3";     divisor = 1;   mh = 1e9; region = @("us","ca","eu","asia"); rewardalgo = "blake3"}
    [PSCustomObject]@{algo = "equihash";   coin = "ZEC"; port = @(3333,4444); ethproxy = $null;           rpc = "equihash";   divisor = 1;   mh = 1e4; region = @("us","ca","eu","asia")}
    [PSCustomObject]@{algo = "etchash";    coin = "ETC"; port = @(3333,4444); ethproxy = "ethstratumnh";  rpc = "etchash";    divisor = 1e6; mh = 5e3; region = @("us","ca","eu","asia")}
    [PSCustomObject]@{algo = "ethash";     coin = "ETHW"; port = @(3333,4444); ethproxy = "ethstratumnh"; rpc = "ethash";     divisor = 1e6; mh = 5e3; region = @("us","ca","eu","asia")}
    [PSCustomObject]@{algo = "fishhash";   coin = "IRON"; port = @(3333,4444); ethproxy = "stratum";      rpc = "fishhash";   divisor = 1;   mh = 1e9; region = @("us","ca","eu","asia")}
    [PSCustomObject]@{algo = "ghostrider"; coin = "RTM"; port = @(3333,4444); ethproxy = $null;           rpc = "ghostrider"; divisor = 1;   mh = 5e4; region = @("us","ca","eu","asia")}
    [PSCustomObject]@{algo = "kawpow";     coin = "RVN"; port = @(3333,4444); ethproxy = "stratum";       rpc = "kp";         divisor = 1e6; mh = 100; region = @("us","ca","eu","asia")}
    [PSCustomObject]@{algo = "kheavyhash"; coin = "KAS"; port = @(3333,4444); ethproxy = $null;           rpc = "kheavyhash"; divisor = 1;   mh = 1e9; region = @("us","ca","eu","asia")}
    [PSCustomObject]@{algo = "nexapow";    coin = "NEXA"; port = @(3333,4444); ethproxy = $null;          rpc = "nexapow";    divisor = 1;   mh = 1e9; region = @("us","ca","eu","asia")}
    [PSCustomObject]@{algo = "octopus";    coin = "CFX"; port = @(3333,4444); ethproxy = $null;           rpc = "octopus";    divisor = 1;   mh = 1e9; region = @("us","ca","eu","asia")}
    [PSCustomObject]@{algo = "randomx";    coin = "XMR"; port = @(3333,4444); ethproxy = $null;           rpc = "rx";         divisor = 1;   mh = 5e4; region = @("us","ca","eu","asia")}    
    [PSCustomObject]@{algo = "xelishashv3";coin = "XEL"; port = @(3333,4444); ethproxy = $null;           rpc = "xelishash";  divisor = 1;   mh = 1e4; region = @("us","ca","eu","asia"); rewardalgo = "xelishash"}
)

$Pool_Referral = "U-TEMDPF" #"4tki-sy7e"

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
            $Pool_Wallet   = "$($Pool_Currency):$($Wallets.$Pool_Currency).{workername:$Worker}#$($Pool_Referral)"

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
                        PoolFee            = if ($Pool_Referral) {0.75} else {1.0}
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

    if ($User -ne "" -or $InfoOnly) {

        $Pool_Price    = 0

        $ok = $true
        if (-not $InfoOnly) {
            $Pool_Hashrate_HS   = $_.mh*$_.divisor
            $Pool_ProfitRequest = [PSCustomObject]@{}
            try {
                $bodystr = ConvertTo-Json @{mode="advanced";coin="BTC";algorithm=$Pool_RewardAlgo;hashrate_hs="$($Pool_Hashrate_HS)";scenario_set="default";referral_discount=$true} -ErrorAction Ignore
                #$Pool_ProfitRequest = Invoke-RestMethodAsync "https://api.unmineable.com/v5/calculator/simulate" -tag $Name -cycletime 240 -body $bodystr
                $Pool_ProfitRequest = Invoke-RestMethodAsync "https://api.unmineable.dev/v1/simulator" -tag $Name -cycletime 240 -body $bodystr
            } catch {
                Write-Log -Level Warn "Pool profit API ($Name) has failed for algorithm $($Pool_Algorithm_Norm). "
            }

            $ok = $Pool_ProfitRequest.success

            if ($ok) {
                $algo = $Pool_ProfitRequest.data.algorithms | Where-Object {$_.algorithm -eq $Pool_RewardAlgo}
                if ($algo -and $algo.assumptions.btc_price_usdt) {
                    $Pool_Price = $algo.windows."1d".scenarios.spot_now.comparison.auto_convert_usdt / $Pool_Hashrate_HS / $algo.assumptions.btc_price_usdt
                }
                $Stat = Set-Stat -Name "$($Name)_$($Pool_Algorithm_Norm)_Profit" -Value $Pool_Price -Duration $StatSpan -ChangeDetection $($Pool_Price -gt 0) -Quiet
            }
        }

        if ($ok -or $InfoOnly) {
            $Pool_Wallet   = "$($User).{workername:$Worker}#$($Pool_Referral)"

            $Pool_SSL = $false
            foreach($Pool_Port in $_.port) {
                $Pool_Protocol = "stratum+$(if ($Pool_SSL) {"ssl"} else {"tcp"})"
                foreach($Pool_Region in $_.region) {
                    [PSCustomObject]@{     
                        Algorithm          = $Pool_Algorithm_Norm
                        Algorithm0         = $Pool_Algorithm_Norm
                        CoinName           = $Pool_CurrencyData.name
                        CoinSymbol         = ""
                        Currency           = "BTC"
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
                        PoolFee            = if ($Pool_Referral) {0.75} else {1.0}
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
