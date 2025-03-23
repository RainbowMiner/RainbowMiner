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
    }

    if (-not $InfoOnly) {
        try {
            $Request = $null
            if ($_.APIUrl) {
                if (-not $Pool_ProfitData.ContainsKey($_.APIUrl)) {
                    $Pool_ProfitData[$_.APIUrl] = Invoke-RestMethodAsync $_.APIUrl -cycletime 120 -tag $Name
                }
                if ($Pool_ProfitData[$_.APIUrl]) {
                    $Request = $Pool_ProfitData[$_.APIUrl]
                }
            }

            if ($_.Profit -eq "#") {
                $Pool_Values.Profit = [double]$Request
            } else {
                foreach ($fld in @("Profit","ProfitFactor","Hashrate","Difficulty","Workers","TimeSinceLast","Blocks24h")) {
                    if ($_.$fld) {
                        $val = $null
                        if ($_.$fld -match "^[0-9\+\-\.,E]+$") {
                            $val = $_.$fld -replace ",","."
                        } elseif ($Request) {
                            $val = Get-ValueFromRequest -Request $Request -Value $_.$fld -Params $Pool_Params
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
        PoolFee       = $_.PoolFee
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