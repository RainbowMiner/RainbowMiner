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
    [String]$StatAverageStable = "Week"
)

$Name = Get-Item $MyInvocation.MyCommand.Path | Select-Object -ExpandProperty BaseName

$CoinXlat = [hashtable]@{
    ERGO = "ERG"
    MEER = "PMEER"
    VDS = "VOLLAR"
}

$Pool_Request = [PSCustomObject]@{}

$ok = $false
try {
    $Pool_Request = Invoke-RestMethodAsync "https://server.666pool.cn/server/v1/getCoinList" -tag $Name -cycletime 120 -headers $headers
    if ($Pool_Request -is [string] -and $Pool_Request.Trim() -match "(?smi)^[^{]*({.+})[^}]*$") {
        $Pool_Request = ConvertFrom-Json $Matches[1] -ErrorAction Stop
    }
    $ok = $Pool_Request.retCode -eq 200
} catch {if ($Error.Count){$Error.RemoveAt(0)}}

if (-not $ok) {
    Write-Log -Level Warn "Pool API ($Name) has failed. "
    return
}

$Pool_Region_Default = "asia"

[hashtable]$Pool_RegionsTable = @{}
@("asia") | Foreach-Object {$Pool_RegionsTable.$_ = Get-Region $_}

$Pool_Request.param | Where-Object {$Pool_Currency = if ($CoinXlat[$_.coin]) {$CoinXlat[$_.coin]} else {$_.coin};$Wallets.$Pool_Currency -or $InfoOnly} | ForEach-Object {
    $Pool_Coin       = Get-Coin $Pool_Currency
    $Pool_Fee        = [double]"$($_.pplnsRate -replace "[^\d,\.]+" -replace ",",".")"
    $Pool_Wallet     = "$($Wallets.$Pool_Currency)" -replace "@(pps|pplns)$"

    $Pool_Algorithm_Norm = Get-Algorithm $Pool_Coin.algo

    $Pool_EthProxy = if ($Pool_Algorithm_Norm -match $Global:RegexAlgoHasEthproxy) {"ethproxy"} elseif ($Pool_Algorithm_Norm -match $Global:RegexAlgoIsProgPow) {"stratum"} else {$null}

    $Pool_BlocksRequest  = [PSCustomObject]@{}

    $Pool_Rate = 0
    $Pool_TSL  = $null
    $Pool_BLK  = $null
    $Pool_Worker = $null

    $ok = $true
    if (-not $InfoOnly) {
        try {
            $Pool_BlocksRequest = Invoke-RestMethodAsync "https://server.666pool.cn/server/v1/getCoinDetail/?coin=$($_.coin)" -tag $Name -timeout 15 -cycletime 120
            if ($Pool_BlocksRequest -is [string] -and $Pool_BlocksRequest.Trim() -match "(?smi)^[^{]*({.+})[^}]*$") {
                $Pool_BlocksRequest = ConvertFrom-Json $Matches[1] -ErrorAction Stop
            }
            if ($Pool_BlocksRequest.retCode -eq 200) {
                $timestamp    = Get-UnixTimestamp
                $timestamp24h = $Pool_Now - 86400
                $blocks = @($Pool_BlocksRequest.data.block | Foreach-Object {$_.uptime} | Sort-Object -Descending)
                $blocks_measure = $blocks | Where-Object {$_ -gt $timestamp24h} | Measure-Object -Minimum -Maximum
                $Pool_BLK = [int]$($(if ($blocks_measure.Count -gt 1 -and ($blocks_measure.Maximum - $blocks_measure.Minimum)) {86400/($blocks_measure.Maximum - $blocks_measure.Minimum)} else {1})*$blocks_measure.Count)
                $Pool_TSL = if ($blocks.Count) {$timestamp - $blocks[0]}
                $Pool_Worker = $Pool_BlocksRequest.data.poolWorks
            }
        }
        catch {
            if ($Error.Count){$Error.RemoveAt(0)}
            $ok = $false
        }
        if (-not $ok) {
            Write-Log -Level Warn "Pool API ($Name) for $Pool_Currency has failed. "
        }
    }

    if ($ok -and -not $InfoOnly) {
        $Pool_Rate = if ($Global:Rates.$Pool_Currency) {$_.dailyIncome/($Global:Rates.$Pool_Currency*(ConvertFrom-Hash "1$($_.dailyIncomeUnit)"))} else {0}
        $Pool_Hashrate = ConvertFrom-Hash "$($_.poolHash)$($_.poolHashUnit)"
        $Stat = Set-Stat -Name "$($Name)_$($Pool_Currency)_Profit" -Value $Pool_Rate -Duration $StatSpan -HashRate $Pool_Hashrate -BlockRate $Pool_BLK -ChangeDetection ($Pool_Rate -gt 0) -Quiet
        if (-not $Stat.HashRate_Live -and -not $AllowZero) {return}
    }

    if ($ok -or $InfoOnly) {
        $Pool_SSL = $false
        [PSCustomObject]@{
            Algorithm     = $Pool_Algorithm_Norm
			Algorithm0    = $Pool_Algorithm_Norm
            CoinName      = $Pool_Coin.Name
            CoinSymbol    = $Pool_Currency
            Currency      = $Pool_Currency
            Price         = $Stat.$StatAverage #instead of .Live
            StablePrice   = $Stat.$StatAverageStable
            MarginOfError = $Stat.Week_Fluctuation
            Protocol      = "stratum+$(if ($Pool_SSL) {"ssl"} else {"tcp"})"
            Host          = "$($_.address -replace ":\d+$")"
            Port          = $_.address -replace "^.+:"
            User          = "$($Pool_Wallet).{workername:$Worker}"
            Pass          = "x{diff:,d=`$difficulty}"
            Region        = $Pool_RegionsTable[$Pool_Region_Default]
            SSL           = $Pool_SSL
            Updated       = $Stat.Updated
            PoolFee       = $Pool_Fee
            Workers       = $Pool_Worker
            Hashrate      = $Stat.HashRate_Live
            TSL           = $Pool_TSL
            BLK           = $Stat.BlockRate_Average
            EthMode       = $Pool_EthProxy
            WTM           = -not $Pool_Rate
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
