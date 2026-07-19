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
    [String]$Email,
    [String]$MiningUsername
)

# $Name = Get-Item $MyInvocation.MyCommand.Path | Select-Object -ExpandProperty BaseName

$Pool_Request = [PSCustomObject]@{}

try {
    $Pool_Request = Invoke-RestMethodAsync "https://api.rbminer.net/data/kryptex.json" -tag $Name -cycletime 120 -retry 5 -retrywait 250
}
catch {
    Write-Log -Level Warn "Pool API ($Name) has failed. "
    return
}

if (-not ($Pool_Request | Measure-Object).Count) {
    Write-Log -Level Warn "Pool API ($Name) returned nothing. "
    return
}

[hashtable]$Pool_RegionsTable = @{}

$Pool_Regions = @("eu","ru","sg","us")
$Pool_Regions | Foreach-Object {$Pool_RegionsTable.$_ = Get-Region $_}

$Pool_Request | Where-Object {$Wallets."$($_.symbol)" -or $Email -ne "" -or $MiningUsername -ne "" -or $InfoOnly} | ForEach-Object {

    $Pool_Rpc  = $_.rpc

    $Pool_Currency = $_.symbol
    $Pool_Algorithm_Norm = Get-Algorithm $_.algo

    $Pool_PoolFee = [Double]$_.fee_pps
    $Pool_DirectMining = $_.directMining

    $Pool_BLK = if ($_.blk -gt 0 -or $_.hashrate -eq 0) {[int]$_.blk} else {$null}
    $Pool_TSL = if ($_.tsl -ge 0) {$_.tsl} else {$null}

    $Pool_WTM = -not ($_.profit -gt 0)

    $Pool_StatName = "$($Pool_Currency)$(if ($Pool_Rpc -ne $Pool_Currency.ToLower()) {"_$($Pool_Algorithm_Norm)"})"

    if (-not $InfoOnly) {
        $Stat = Set-Stat -Name "$($Name)_$($Pool_StatName)_Profit" -Value $(if ($Pool_WTM) {0} else {[Double]$_.profit}) -Duration $StatSpan -HashRate $_.hashrate -BlockRate $Pool_BLK -ChangeDetection $false -Quiet
        if (-not $Stat.HashRate_Live -and -not $AllowZero) {return}

        if ($Wallets.$Pool_Currency) {
            if ($Pool_DirectMining) {
                $Pool_ExCurrency = try {
                    [mailaddress]$Wallets.$Pool_Currency > $null
                    "BTC"
                }
                catch {
                    $Pool_Currency
                }
            } else {
                $Pool_ExCurrency = $Pool_Currency
            }
            $Pool_Wallet = $Wallets.$Pool_Currency
        } elseif ($MiningUsername -ne "") {
            if (-not $Pool_DirectMining) {return}
            $Pool_ExCurrency = "BTC"
            $Pool_Wallet = $MiningUsername
        } elseif ($Email -ne "") {
            if ($Pool_DirectMining) {
                $Pool_ExCurrency = try {
                    [mailaddress]$Email > $null
                    "BTC"
                }
                catch {
                }
            } else {
                $Pool_ExCurrency = $null
            }
            $Pool_Wallet = $Email
        }

        if (-not $Pool_ExCurrency) {return}
    } else {
        $Pool_ExCurrency = if ($Pool_Currency -in $Pool_MineToAccount) {"BTC"} else {$Pool_Currency}
    }

    $Pool_Data = $_

    foreach($Pool_Region in $Pool_Regions) {
        foreach($ssl in @("","ssl_")) {
            foreach($url in $Pool_Data.servers."$($ssl)urls") {
                if ($url -match "^(.+?-$($Pool_Region).+?):(\d+)$") {
                    $Pool_Host = $Matches[1]
                    $Pool_Port = $Matches[2]
                    $Pool_SSL  = $ssl -ne ""

                    [PSCustomObject]@{
                        Algorithm     = $Pool_Algorithm_Norm
                        Algorithm0    = $Pool_Algorithm_Norm
                        CoinName      = $Pool_Data.coin
                        CoinSymbol    = $Pool_Currency
                        Currency      = $Pool_ExCurrency
                        Price         = if ($Pool_WTM) {0} else {$Stat.$StatAverage}
                        StablePrice   = if ($Pool_WTM) {0} else {$Stat.$StatAverageStable}
                        MarginOfError = if ($Pool_WTM) {0} else {$Stat.Week_Fluctuation}
                        Protocol      = "stratum+$(if ($Pool_SSL) {"ssl"} else {"tcp"})"
                        Host          = $Pool_Host
                        Port          = $Pool_Port
                        User          = "$($Pool_Wallet)/{workername:$Worker}"
                        Pass          = "x"
                        Region        = $Pool_RegionsTable.$Pool_Region
                        SSL           = $Pool_SSL
                        Updated       = $Stat.Updated
                        PoolFee       = $Pool_PoolFee
                        Workers       = $Pool_Data.miners
                        Hashrate      = $Stat.HashRate_Live
                        TSL           = $Pool_TSL
                        BLK           = if ($Pool_BLK -ne $null) {$Stat.BlockRate_Average} else {$null}
                        PaysLive      = $Pool_Data.fee_type -eq "PPS+"
                        WTM           = $Pool_WTM
                        Name          = $Name
                        Penalty       = 0
                        PenaltyFactor = 1
                        Disabled      = $false
                        HasMinerExclusions = $false
                        Price_0       = 0.0
                        Price_Bias    = 0.0
                        Price_Unbias  = 0.0
                        Wallet        = $Wallets.$Pool_Currency
                        Worker        = "{workername:$Worker}"
                        Email         = $Email
                    }
                }
            }
        }
    }
}