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

$Pool_Request = [PSCustomObject]@{}

try {
    $Pool_Request = Invoke-RestMethodAsync "https://mining4people.com/api/pools" -retry 3 -retrywait 500 -tag $Name -cycletime 120
}
catch {
    if ($Error.Count){$Error.RemoveAt(0)}
    Write-Log -Level Warn "Pool API ($Name) has failed. "
    return
}

if (-not $Pool_Request -or ($Pool_Request | Measure-Object).Count -le 5) {
    Write-Log -Level Warn "Pool API ($Name) returned nothing. "
    return
}

[hashtable]$Pool_RegionsTable = @{}

$Pool_Regions = @("au","br","eu","in","jp","us-west","us-east","us-cent")
$Pool_Regions | Foreach-Object {$Pool_RegionsTable.$_ = Get-Region $_}

$Pool_Fee = 1

$Pool_Request | Where-Object {$_.feeType -eq "PPLNSBF" -and ($Wallets."$($_.coin)" -or $InfoOnly)} | ForEach-Object {

    $Pool_Currency = $_.coin
    $Pool_Coin = Get-Coin $Pool_Currency

    if ($_.id -notmatch "^\w+-\w+-pplns" -and $Pool_Coin -and -not $Pool_Coin.Multi) {
        $Pool_Algorithm_Norm = $Pool_Coin.algo
        $Pool_CoinName  = $Pool_Coin.name
    } else {
        $Pool_Algorithm_Norm = Get-Algorithm $_.algorithm -CoinSymbol $Pool_Currency
        $Pool_CoinName  = $_.name
    }

    $Pool_Fee = [double]$_.fee
    $Pool_Host = ".mining4people.com"
    $Pool_EthProxy = if ($Pool_Algorithm_Norm -match $Global:RegexAlgoHasEthproxy) {"ethstratumnh"} elseif ($Pool_Algorithm_Norm -match $Global:RegexAlgoIsProgPow) {"stratum"} else {$null}
    $Pool_Ports = @(0,0)
        
    $Pool_CoinRequest = [PSCustomObject]@{}
    try {
        $Pool_CoinRequest = Invoke-RestMethodAsync "https://mining4people.com/calcapi/pools/$($_.id)" -retry 3 -retrywait 500 -tag $Name -cycletime 120 -delay 200
    }
    catch {
        if ($Error.Count){$Error.RemoveAt(0)}
        Write-Log -Level Warn "Pool coin API ($Name) has failed for $($Pool_Currency) "
        return
    }

    $Pool_CoinRequest = $Pool_CoinRequest.pool | Select-Object -First 1

    $Pool_CoinRequest.ports.PSObject.Properties | Sort-Object {[double]$_.Value.difficulty},{[int]$_.Name},{[bool]$_.Value.tls} | Foreach-Object {
        if ([bool]$_.Value.tls) {
            if (-not $Pool_Ports[1]) {$Pool_Ports[1] = $_.Name}
        } else {
            if (-not $Pool_Ports[0]) {$Pool_Ports[0] = $_.Name}
        }
    }

    if (-not $InfoOnly) {
        $hashrate      = $_.poolHashrate
        $avgTime       = if ($_.poolHashrate -gt 0) {$Pool_CoinRequest.networkStats.networkDifficulty * [Math]::Pow(2,32) / $hashrate} else {0}
        $Pool_BLK      = [int]$(if ($avgTime -gt 0) {86400/$avgTime})
        $lastBlocktime = if ($Pool_CoinRequest.lastPoolBlockTime) {([datetime]$Pool_CoinRequest.lastPoolBlockTime).ToUniversalTime()} else {[datetime]"1970-01-01T00:00:00"}
        $Pool_TSL      = ((Get-Date).ToUniversalTime() - $lastBlocktime).TotalSeconds - [int]$Session.TimeDiff
        $reward        = [int]$_.blockReward
        $btcPrice      = if ($Global:Rates.$Pool_Currency) {1/[double]$Global:Rates.$Pool_Currency} else {0}

        $btcRewardLive =  if ($hashrate -gt 0) {$btcPrice * $reward * $Pool_BLK / $hashrate} else {0}

        $Stat = Set-Stat -Name "$($Name)_$($Pool_Algorithm_Norm)_$($Pool_Currency)_Profit" -Value $btcRewardLive -Duration $StatSpan -ChangeDetection $false -HashRate $hashrate -BlockRate $Pool_BLK -Quiet
        if (-not $Stat.HashRate_Live -and -not $AllowZero) {return}
    }

    $Pool_TLS = $false

    $Pool_User = $Wallets.$Pool_Currency

    foreach($Pool_Port in $Pool_Ports) {
        if (($Pool_User -and $Pool_Port -gt 0) -or $InfoOnly) {
            $Pool_Stratum = "stratum+$(if($Pool_TLS) {"ssl"} else {"tcp"})"
            foreach($Pool_Region in $Pool_Regions) {
                [PSCustomObject]@{
                    Algorithm     = $Pool_Algorithm_Norm
                    Algorithm0    = $Pool_Algorithm_Norm
                    CoinName      = $Pool_CoinName
                    CoinSymbol    = $Pool_Currency
                    Currency      = $Pool_Currency
                    Price         = $Stat.$StatAverage #instead of .Live
                    StablePrice   = $Stat.$StatAverageStable
                    MarginOfError = $Stat.Week_Fluctuation
                    Protocol      = $Pool_Stratum
                    Host          = "$($Pool_Region)$($Pool_Host)"
                    Port          = $Pool_Port
                    User          = "$Pool_User.{workername:$Worker}"
                    Pass          = "x{diff:,d=`$difficulty}"
                    Region        = $Pool_RegionsTable.$Pool_Region
                    SSL           = $Pool_TLS
                    Updated       = $Stat.Updated
                    PoolFee       = $Pool_Fee
                    DataWindow    = $DataWindow
                    Workers       = [int]$_.workers
                    Hashrate      = $Stat.HashRate_Live
                    TSL           = $Pool_TSL
                    BLK           = $Stat.BlockRate_Average
                    EthMode       = $Pool_EthProxy
                    Name          = $Name
                    Penalty       = 0
                    PenaltyFactor = 1
                    Disabled      = $false
                    HasMinerExclusions = $false
                    Price_0       = 0.0
                    Price_Bias    = 0.0
                    Price_Unbias  = 0.0
                    Wallet        = $Pool_User
                    Worker        = "{workername:$Worker}"
                    Email         = $Email
                }
            }
        }
        $Pool_TLS = $true
    }
}