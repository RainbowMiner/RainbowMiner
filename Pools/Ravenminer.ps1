using module ..\Modules\Include.psm1

param(
    [PSCustomObject]$Wallets,
    [PSCustomObject]$Params,
    [alias("WorkerName")]
    [String]$Worker,
    [TimeSpan]$StatSpan,
    [String]$DataWindow = "avg",
    [Bool]$InfoOnly = $false,
    [Bool]$AllowZero = $false,
    [String]$StatAverage = "Minute_10",
    [String]$StatAverageStable = "Week",
    [String]$AECurrency = ""
)

$Name = Get-Item $MyInvocation.MyCommand.Path | Select-Object -ExpandProperty BaseName

$Pool_Currency = "RVN"

$Pool_Coin = Get-Coin $Pool_Currency
$Pool_Host = "ravenminer.com"
$Pool_Algorithm_Norm = $Pool_Coin.Algo
$Pool_Ports = @(3838,13838)

$Pool_Request = [PSCustomObject]@{}
try {
    $Pool_Request = Invoke-RestMethodAsync "https://www.ravenminer.com/api/v1/dashboard" -tag $Name -cycletime 120
}
catch {
    if ($Error.Count){$Error.RemoveAt(0)}
    Write-Log -Level Warn "Pool API ($Name) has failed. "
    return
}

[hashtable]$Pool_RegionsTable = @{}

$Pool_Regions = @("us","eu","asia")
$Pool_Regions | Foreach-Object {$Pool_RegionsTable.$_ = Get-Region $_}

$Pool_User = $Pool_TLS = $Pool_BLK = $null
$Pool_AE   = $Pool_Currency

if (-not $InfoOnly) {
    $Pool_Valid_Currencies = @("RVN","BTC","ETH","LTC","BCH","ADA","DOGE","MATIC")
    if ($AECurrency -eq "" -and $Params.$Pool_Currency -ne "") {
        foreach ($Pool_AE in $Pool_Valid_Currencies) {
            if ($Params.$Pool_Currency -match $Pool_AE) {
                $AECurrency = $Pool_AE
                break
            }
        }
    }
    if ($AECurrency -eq "" -or $AECurrency -notin $Pool_Valid_Currencies) {
        foreach ($Pool_AE in $Pool_Valid_Currencies) {
            if ($Wallets.$Pool_AE) {
                $Pool_User = $Wallets.$Pool_AE
                break
            }
        }
    } else {
        $Pool_User = $Wallets.$AECurrency
        $Pool_AE   = $AECurrency
    }

    $PoolBlocks_Request = [PSCustomObject]@{}
    try {
        $PoolBlocks_Request = Invoke-RestMethodAsync "https://www.ravenminer.com/api/v1/blocks" -tag $Name -cycletime 120
    }
    catch {
        if ($Error.Count){$Error.RemoveAt(0)}
        Write-Log -Level Warn "Pool blocks API ($Name) has failed. "
    }

    $timestamp       = Get-UnixTimestamp
    $timestamp24h    = $timestamp - 86400

    $blocks          = $PoolBlocks_Request.blocks | Where-Object payment_type -eq 0 | Select-Object -ExpandProperty time | Sort-Object -Descending
    $blocks_measure  = $blocks | Where-Object {$_ -gt $timestamp24h} | Measure-Object -Minimum -Maximum
    $Pool_BLK        = [int]$($(if ($blocks_measure.Count -gt 1 -and ($blocks_measure.Maximum - $blocks_measure.Minimum)) {86400000/($blocks_measure.Maximum - $blocks_measure.Minimum)} else {1})*$blocks_measure.Count)
    $Pool_TSL        = [int]($timestamp - ($blocks | Select-Object -First 1)/1000)

    $Stat = Set-Stat -Name "$($Name)_$($Pool_Currency)_Profit" -Value 0 -Duration $StatSpan -HashRate $Pool_Request.hashrate -BlockRate $Pool_BLK -Difficulty $Pool_Request.coin.difficulty -ChangeDetection $false -Quiet
    if (-not $Stat.HashRate_Live -and -not $AllowZero) {return}
}

if ($Pool_User -or $InfoOnly) {
    $Pool_Pass = $Params.$Pool_AE
    $Pool_AE   = $Pool_AE.ToLower()

    if ($Pool_AE -ne "rvn") {
        if ($Pool_Pass -notmatch $Pool_AE) {
            $Pool_Pass = if ($Pool_Pass -ne "") {"$($Pool_Pass),$($Pool_AE)"} else {$Pool_AE}
        }
    }

    $Pool_Mode = if ($Pool_Pass -match "pps") {"pps"} elseif ($Pool_Pass -match "solo") {"solo"} else {"pplns"}
    $Pool_Fee  = $Pool_Request."$($Pool_Mode)_fees"
    $Pool_Solo = $Pool_Mode -eq "solo"

    foreach($Pool_Region in $Pool_Regions) {
        $Pool_SSL = $false
        foreach($Pool_Port in $Pool_Ports) {
            [PSCustomObject]@{
                Algorithm     = $Pool_Algorithm_Norm
                Algorithm0    = $Pool_Algorithm_Norm
                CoinName      = $Pool_Coin.Name
                CoinSymbol    = $Pool_Currency
                Currency      = $Pool_Currency
                Price         = 0
                StablePrice   = 0
                MarginOfError = 0
                Protocol      = "stratum+$(if ($Pool_SSL) {"ssl"} else {"tcp"})"
                Host          = "$($Pool_Region).$($Pool_Host)"
                Port          = $Pool_Port
                User          = "$($Pool_User).{workername:$Worker}"
                Pass          = $Pool_Pass
                Region        = $Pool_Regions.$Pool_Region
                SSL           = $Pool_SSL
                Updated       = $Stat.Updated
                PoolFee       = $Pool_Fee
                DataWindow    = $DataWindow
                Workers       = if (-not $Pool_Solo) {$Pool_Request.workersNum} else {$null}
                Hashrate      = if (-not $Pool_Solo) {$Stat.HashRate_Live} else {$null}
                BLK           = if (-not $Pool_Solo) {$Stat.BlockRate_Average} else {$null}
                TSL           = if (-not $Pool_Solo) {$Pool_TSL} else {$null}
                WTM           = $true
                Difficulty    = if ($Pool_Solo) {$Stat.Diff_Average} else {$null}
                SoloMining    = $Pool_Solo
				ErrorRatio    = $Stat.ErrorRatio
                EthMode       = "stratum"
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
            $Pool_SSL = $true
        }
    }
}
