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

$ProfitData = @{}

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

    $Profit = 0

    if (-not $InfoOnly) {
        try {
            if ($_.ProfitUrl) {
                if (-not $ProfitData.ContainsKey($_.ProfitUrl)) {
                    $ProfitData[$_.ProfitUrl] = Invoke-RestMethodAsync $_.ProfitUrl -cycletime 120 -tag $Name
                }
                if ($ProfitData[$_.ProfitUrl]) {
                    $Request = $ProfitData[$_.ProfitUrl]
                    if ($_.ProfitValue -eq "#") {
                        $Profit = [double]$Request
                    } else {
                        $val = $null
                        foreach ($data in $_.ProfitValue -split "\.") {
                            $Pool_Params.GetEnumerator() | Foreach-Object {
                                $data = $data.Replace("`$$($_.Name)",$_.Value)
                            }
                            if ($data -match '^(.+)\[([^\]]+)\]$') {
                                $val = if ($val -ne $null) {$val."$($Matches[1])"} else {$Request."$($Matches[1])"}
                                $arrp = $Matches[2].Split("=",2)
                                if ($arrp[0] -match '^\d+$') {
                                    $val = $val[[int]$arrp[0]]
                                } else {
                                    $val = $val | ?{$_."$($arrp[0])" -eq $arrp[1]}
                                }
                            } else {
                                $val = if ($val -ne $null) {$val.$data} else {$Request.$data}
                            }
                        }
                        $Profit = [double]$val
                    }
                }
            } elseif ($_.ProfitValue) {
                $val = $_.ProfitValue -replace ",","." -replace "[^0-9\+\-\.E]+"
                if ($val -ne "") {
                    $Profit = [double]$val
                }
            }

            if ($Profit) {
                if ($_.ProfitFactor) {
                    $Profit *= [double]$_.ProfitFactor
                }
                $cur = if ($_.ProfitCurrency -ne "") {$_.ProfitCurrency} else {$_.Currency}
                if ($cur -ne "BTC") {
                    $Profit = if ($Global:Rates.$cur) {$Profit/[double]$Global:Rates.$cur} else {0}
                }
            }
        } catch {
            Write-Log -Level Warn "$($LogString): $($_.Exception.Message)"
            $Profit = 0
        }

        $Stat = Set-Stat -Name "$($Name)_$($Pool_Algorithm_Norm)$(if($Pool_Params["CoinSymbol"]) {"_$($Pool_Params["CoinSymbol"])"})_Profit" -Value $Profit -Duration $StatSpan -ChangeDetection $false -Quiet
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
        Price         = if ($Profit) {$Stat.$StatAverage} else {0}
        StablePrice   = if ($Profit) {$Stat.$StatAverageStable} else {0}
        MarginOfError = if ($Profit) {$Stat.Week_Fluctuation} else {0}
        Protocol      = "$(if ($_.Protocol) {$_.Protocol} else {"stratum+$(if ($_.SSL) {"ssl"} else {"tcp"})"})"
        Host          = $_.Host
        Port          = $_.Port
        User          = $Pool_User
        Pass          = $Pool_Pass
        Region        = "$(if ($_.Region) {Get-Region $_.Region} else {"US"})"
        SSL           = $_.SSL
        WTM           = $Profit -eq 0
        Updated       = (Get-Date).ToUniversalTime()
        PoolFee       = $_.PoolFee
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

$ProfitData = $null