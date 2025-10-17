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
    [String]$StatAverageStable = "Week"
)

# $Name = Get-Item $MyInvocation.MyCommand.Path | Select-Object -ExpandProperty BaseName

$Pool_Request = [PSCustomObject]@{}

try {
    $Pool_Request = Invoke-RestMethodAsync "https://api.rbminer.net/data/mining4people.json" -retry 3 -retrywait 500 -tag $Name -cycletime 120
}
catch {
    Write-Log -Level Warn "Pool API ($Name) has failed. "
    return
}

if (-not $Pool_Request) {
    Write-Log -Level Warn "Pool API ($Name) returned nothing. "
    return
}

[hashtable]$Pool_RegionsTable = @{}

$Pool_Regions = @("au","br","eu","in","jp","us-west","us-east","us-cent")
$Pool_Regions | Foreach-Object {$Pool_RegionsTable.$_ = Get-Region $_}

$Pool_Fee = 1

$Pool_Request | Where-Object {$_.feeType -eq "PPLNSBF70" -and ($Wallets."$($_.coin)" -or $InfoOnly)} | ForEach-Object {

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
        
    $_.ports | Sort-Object {[double]$_.difficulty},{[int]$_.port},{[bool]$_.tls} | Foreach-Object {
        if ($_.tls) {
            if (-not $Pool_Ports[1]) {$Pool_Ports[1] = $_.port}
        } else {
            if (-not $Pool_Ports[0]) {$Pool_Ports[0] = $_.port}
        }
    }

    $Pool_TSL = $_.tsl

    if (-not $InfoOnly) {
        $hashrate = $_.poolHashrate
        $Stat = Set-Stat -Name "$($Name)_$($Pool_Algorithm_Norm)_$($Pool_Currency)_Profit" -Value 0 -Duration $StatSpan -ChangeDetection $false -HashRate $hashrate -Difficulty $_.diff -Quiet
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
                    Price         = 0
                    StablePrice   = 0
                    MarginOfError = 0
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
                    Workers       = $_.workers
                    Hashrate      = $Stat.HashRate_Live
                    TSL           = $Pool_TSL
                    BLK           = $null
                    Difficulty    = $Stat.Diff_Average
                    SoloMining    = $true
                    WTM           = $true
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
