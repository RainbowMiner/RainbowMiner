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
    [alias("UserName")]
    [String]$User,
    [String]$AEcurrency = ""
)

# $Name = Get-Item $MyInvocation.MyCommand.Path | Select-Object -ExpandProperty BaseName

if (-not $User -and -not $InfoOnly) {return}

$Pool_Request = [PSCustomObject]@{}

try {
    $Pool_Request = Invoke-RestMethodAsync "https://api.rbminer.net/data/miningdutch.json" -retry 3 -retrywait 500 -tag $Name -cycletime 120
}
catch {
    Write-Log -Level Warn "Pool API ($Name) has failed. "
    return
}

if (-not $Pool_Request -or ($Pool_Request.PSObject.Properties.Name | Measure-Object).Count -le 5) {
    Write-Log -Level Warn "Pool API ($Name) returned nothing. "
    return
}

[hashtable]$Pool_RegionsTable = @{}

$Pool_Regions = @("americas","asia","brazil","canada","europe","india","singapore","hongkong","moscow","kazakhstan")
$Pool_Regions | Foreach-Object {$Pool_RegionsTable.$_ = Get-Region $_}

$Pool_Fee = 2

$Pool_Currency = if ($AEcurrency) {$AEcurrency} else {"BTC"}

$Pool_Request.PSObject.Properties.Value | ForEach-Object {

    $Pool_Algorithm = $_.name
    $Pool_Algorithm_Norm = Get-Algorithm $_.name
    $Pool_Coin = ''
    $Pool_Fee = [double]$_.fees
    $Pool_Symbol = ''
    $Pool_Port = [int]$_.port
    $Pool_Host = "mining-dutch.nl"
    $Pool_EthProxy = if ($Pool_Algorithm_Norm -match $Global:RegexAlgoHasEthproxy) {"ethstratumnh"} elseif ($Pool_Algorithm_Norm -match $Global:RegexAlgoIsProgPow) {"stratum"} else {$null}
        
    $Pool_Factor = [double]$_.mbtc_mh_factor
    if ($Pool_Factor -le 0) {
        Write-Log -Level Info "$($Name): Unable to determine divisor for algorithm $Pool_Algorithm. "
        return
    }

    #$Pool_TSL = ($PoolCoins_Request.PSObject.Properties | Where-Object algo -eq $Pool_Algorithm | Measure-Object timesincelast_shared -Minimum).Minimum
    #$Pool_BLK = ($PoolCoins_Request.PSObject.Properties | Where-Object algo -eq $Pool_Algorithm | Measure-Object "24h_blocks_shared" -Maximum).Maximum

    if (-not $InfoOnly) {
        $Pool_Price = [double]$_.estimate_current * 1e-6 / $Pool_Factor
        $Stat = Set-Stat -Name "$($Name)_$($Pool_Algorithm_Norm)_Profit" -Value $Pool_Price -Duration $StatSpan -ChangeDetection $false -FaultDetection $true -FaultTolerance 5 -HashRate ([double]$_.hashrate_shared * 1e6) -BlockRate $Pool_BLK -Quiet
        if (-not $Stat.HashRate_Live -and -not $AllowZero) {return}
    }

    foreach($Pool_Region in $Pool_Regions) {
        if ($User -or $InfoOnly) {
            [PSCustomObject]@{
                Algorithm     = $Pool_Algorithm_Norm
                Algorithm0    = $Pool_Algorithm_Norm
                CoinName      = $Pool_Coin
                CoinSymbol    = $Pool_Symbol
                Currency      = $Pool_Currency
                Price         = $Stat.$StatAverage #instead of .Live
                StablePrice   = $Stat.$StatAverageStable
                MarginOfError = $Stat.Week_Fluctuation
                Protocol      = "stratum+tcp"
                Host          = "$($Pool_Region).$($Pool_Host)"
                Port          = $Pool_Port
                User          = "$User.{workername:$Worker}"
                Pass          = "x{diff:,d=`$difficulty}"
                Region        = $Pool_RegionsTable.$Pool_Region
                SSL           = $false
                Updated       = $Stat.Updated
                PoolFee       = $Pool_Fee
                DataWindow    = $DataWindow
                Workers       = [int]$_.workers_shared
                Hashrate      = $Stat.HashRate_Live
                EthMode       = $Pool_EthProxy
                Name          = $Name
                Penalty       = 0
                PenaltyFactor = 1
                Disabled      = $false
                HasMinerExclusions = $false
                Price_0       = 0.0
                Price_Bias    = 0.0
                Price_Unbias  = 0.0
                Wallet        = $User
                Worker        = "{workername:$Worker}"
                Email         = $Email
            }
        }
    }
}
