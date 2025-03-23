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
    [String]$Password = ""
)

$Pool_ProfitData = @{}

$map = @{
    'api1' = 'api1'; '1' = 'api1'; 'apiurl1' = 'api1'
    'api2' = 'api2'; '2' = 'api2'; 'apiurl2' = 'api2'
    'api3' = 'api3'; '3' = 'api3'; 'apiurl3' = 'api3'
}


$Session.Config.Userpools | Where-Object {$_.Name -eq $Name -and $_.Enable -and ($Wallets."$($_.Currency)" -or $InfoOnly)} | ForEach-Object {

    $Pool_Params = [ordered]@{
        Wallet     = $Wallets."$($_.Currency)"
        WorkerName = "{workername:$Worker}"
        Currency   = "$($_.Currency)"
        CoinSymbol = "$($_.CoinSymbol)"
        Password   = "$($Password)"
        Params     = $Params."$($_.Currency)"
    }

    $LogString = "Userpool $Name$(if ($Pool_Params["Currency"]) {", Currency $($Pool_Params["Currency"])"})$(if ($Pool_Params["CoinSymbol"]) {", CoinSymbol $($Pool_Params["CoinSymbol"])"})"

    if (-not $Pool_Params["Currency"]) {
        Write-Log -Level Warn "$($LogString): no Currency set"
        return
    }

    if ($Pool_Params["CoinSymbol"]) {
        if ($Pool_Coin = Get-Coin $Pool_Params["CoinSymbol"]) {
            $Pool_Algorithm_Norm = $Pool_Coin.Algo
        } else {
            $Pool_Algorithm_Norm = Get-Algorithm "$($_.Algorithm)" -CoinSymbol $Pool_Params["CoinSymbol"]
        }
    } else {
        $Pool_Algorithm_Norm = Get-Algorithm "$($_.Algorithm)"
    }

    if (-not $Pool_Algorithm_Norm) {
        Write-Log -Level Warn "$($LogString): no Algorithm set"
        return
    }

    $Pool_User     = "$(if ($_.User) {$_.User} else {"`$Wallet.`$WorkerName"})"
    $Pool_Pass     = "$(if ($_.Pass) {$_.Pass} else {"x"})"
    $Pool_EthProxy = if ($Pool_Algorithm_Norm -match $Global:RegexAlgoHasEthproxy) {"ethproxy"} elseif ($Pool_Algorithm_Norm -match $Global:RegexAlgoIsProgPow) {"stratum"} else {$null}

    $Pool_Values = [PSCustomObject]@{
        Profit        = 0
        ProfitFactor  = 1
        Hashrate      = $null
        Workers       = $null
        TimeSinceLast = $null
        Blocks24h     = $null
        Difficulty    = $null
        PoolFee       = 0
    }

    if (-not $InfoOnly) {
        try {
            $Request = [PSCustomObject]@{api1=$null; api2=$null; api3=$null}
            foreach ($api in @(1,2,3)) {
                try {
                    $apiurl = $_."APIUrl$api"
                    if ($apiurl) {
                        if (-not $Pool_ProfitData.ContainsKey($apiurl)) {
                            $Pool_ProfitData[$apiurl] = Invoke-RestMethodAsync $apiurl -cycletime 120 -tag $Name
                        }
                        if ($Pool_ProfitData[$apiurl]) {
                            $Request."api$api" = $Pool_ProfitData[$apiurl]
                        }
                    }
                } catch {
                    Write-Log -Level Warn "$($LogString): $apiurl $($_.Exception.Message)"
                }
            }

            if ($_.Profit -eq "#" -or $_.Profit -eq "#1") {
                $Pool_Values.Profit = [double]$Request.api1
            } elseif ($_.Profit -eq "#2") {
                $Pool_Values.Profit = [double]$Request.api2
            } elseif ($_.Profit  -eq "#3") {
                $Pool_Values.Profit = [double]$Request.api3
            } else {
                foreach ($fld in @("Profit","ProfitFactor","Hashrate","Difficulty","Workers","TimeSinceLast","Blocks24h","PoolFee")) {
                    $apifld = $_.$fld
                    if ($apifld) {
                        $val = $null
                        if ($apifld -match "^[0-9\+\-\.,E]+$") {
                            $val = $apifld -replace ",","."
                        } else {
                            if ($apifld -match '^(api1|api2|api3|1|2|3|apiurl1|apiurl2|apiurl3)\.') {
                                $apiN   = $map[$matches[1]]
                                $apifld = $apifld -replace "^[^\.]+",$apiN
                            } else {
                                $apiN   = "api1"
                                $apifld = "api1.$($apifld)"
                            }

                            if ($Request.$apiN) {
                                $val = Get-ValueFromRequest -Request $Request -Value $apifld -Params $Pool_Params
                            }
                        }
                        if ($val -ne $null) {
                            $Pool_Values.$fld = [double]$val
                        }
                    }
                }
            }

            if ($_.SoloMining) {
                $Pool_Values.Profit = 0
            }

            if ($Pool_Values.Profit) {
                if ($Pool_Values.ProfitFactor) {
                    if ($_.ProfitFactor -match "mbtc_mh_factor") {
                        $Pool_Values.ProfitFactor *= 1e6
                    }
                    $Pool_Values.Profit /= $Pool_Values.ProfitFactor
                } else {
                    $Pool_Values.Profit = 0
                }

                $cur = if ($_.ProfitCurrency -ne "") {$_.ProfitCurrency} else {$_.Currency}
                if ($cur -ne "BTC") {
                    $Pool_Values.Profit = if ($Global:Rates.$cur) {$Pool_Values.Profit/[double]$Global:Rates.$cur} else {0}
                }
            }

        } catch {
            Write-Log -Level Warn "$($LogString): $($_.Exception.Message)"
            $Pool_Values.Profit = 0
        }

        $Stat = Set-Stat -Name "$($Name)_$($Pool_Algorithm_Norm)$(if($Pool_Params["CoinSymbol"]) {"_$($Pool_Params["CoinSymbol"])"})_Profit" -Value $Pool_Values.Profit -Duration $StatSpan -Hashrate $Pool_Values.Hashrate -BlockRate $Pool_Values.Blocks24h -Difficulty $Pool_Values.Difficulty -ChangeDetection $false -Quiet
    }

    $Pool_Params.GetEnumerator() | Foreach-Object {
        $Pool_User = $Pool_User.Replace("`$$($_.Name)",$_.Value)
        $Pool_Pass = $Pool_Pass.Replace("`$$($_.Name)",$_.Value)
    }

    [PSCustomObject]@{
        Algorithm     = $Pool_Algorithm_Norm
		Algorithm0    = $Pool_Algorithm_Norm
        CoinName      = "$(if ($Pool_Coin) {$Pool_Coin.Name} elseif ($_.CoinName) {$_.CoinName} else {$_.CoinSymbol})"
        CoinSymbol    = $Pool_Params["CoinSymbol"]
        Currency      = $Pool_Params["Currency"]
        Price         = if ($Pool_Values.Profit) {$Stat.$StatAverage} else {0}
        StablePrice   = if ($Pool_Values.Profit) {$Stat.$StatAverageStable} else {0}
        MarginOfError = if ($Pool_Values.Profit) {$Stat.Week_Fluctuation} else {0}
        Protocol      = "$(if ($_.Protocol) {$_.Protocol} else {"stratum+$(if ($_.SSL) {"ssl"} else {"tcp"})"})"
        Host          = $_.Host
        Port          = $_.Port
        User          = $Pool_User
        Pass          = $Pool_Pass
        Region        = "$(if ($_.Region) {Get-Region $_.Region} else {"US"})"
        SSL           = $_.SSL
        WTM           = $Pool_Values.Profit -eq 0
        Updated       = (Get-Date).ToUniversalTime()
        PoolFee       = $Pool_Values.PoolFee
        Workers       = if ($_.SoloMining) {$null} else {$Pool_Values.Workers}
        Hashrate      = if ($_.SoloMining -or $Pool_Values.Hashrate -eq $null) {$null} else {$Stat.HashRate_Live}
        TSL           = if ($_.SoloMining) {$null} else {$Pool_Values.TimeSinceLast}
        BLK           = if ($_.SoloMining -or $Pool_Values.Blocks24h -eq $null) {$null} else {$Stat.BlockRate_Average}
        Difficulty    = if ($Pool_Values.Difficulty -eq $null) {$null} else {$Stat.Diff_Average}
        SoloMining    = $_.SoloMining
        EthMode       = "$(if ($_.EthMode) {$_.EthMode} else {$Pool_EthProxy})"
        Name          = $Name
        Penalty       = 0
        PenaltyFactor = 1
        Disabled      = $false
        HasMinerExclusions = $false
        Price_0       = 0.0
        Price_Bias    = 0.0
        Price_Unbias  = 0.0
        Wallet        = $Pool_Params["Wallet"]
        Worker        = $Pool_Params["WorkerName"]
        Email         = $Email
    }
}

$Pool_ProfitData = $null