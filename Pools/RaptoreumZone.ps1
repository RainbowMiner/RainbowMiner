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
    $Pool_Request = Invoke-RestMethodAsync "https://api.raptoreum.zone/v1/rzone/" -tag $Name -cycletime 120 -retry 5 -retrywait 250
}
catch {
    if ($Global:Error.Count){$Global:Error.RemoveAt(0)}
}

if ($Pool_Request.error -or -not $Pool_Request.result.primary) {
    Write-Log -Level Warn "Pool API ($Name) has failed. "
    return
}

[hashtable]$Pool_RegionsTable = @{}

$Pool_Regions = @("europe","usa-east","usa-west","asia")
$Pool_Regions | Foreach-Object {$Pool_RegionsTable.$_ = Get-Region $_}

$Pool_Currency       = "RTM"
$Pool_Host            = "{region}.raptoreum.zone"

$Pool_Coin           = Get-Coin $Pool_Currency
$Pool_Algorithm_Norm = $Pool_Coin.Algo
$Pool_Ports          = @(3333,4444)
$Pool_PoolFee        = if ($Pool_Request.result.primary.config -and $null -ne $Pool_Request.result.primary.config.PSObject.Properties['recipientFee']) {100 * [double]$Pool_Request.result.primary.config.recipientFee} else {0.75}
$Pool_TSL            = if ($Pool_Request.result.primary.blocks -and $null -ne $Pool_Request.result.primary.blocks.PSObject.Properties['lastFound']) {[int](((Get-UnixTimestamp -Milliseconds) - $Pool_Request.result.primary.blocks.lastFound)/1000)} else {$null}
$Pool_BLK            = if ($Pool_Request.result.primary.blocks -and $null -ne $Pool_Request.result.primary.blocks.PSObject.Properties['lastDayCount']) {[int]$Pool_Request.result.primary.blocks.lastDayCount} else {$null}

$Pool_User           = $Wallets.$Pool_Currency

if (-not $InfoOnly) {
    $Stat = Set-Stat -Name "$($Name)_$($Pool_Currency)_Profit" -Value 0 -Duration $StatSpan -ChangeDetection $false -HashRate $Pool_Request.result.primary.hashrate.shared -BlockRate $Pool_BLK -Quiet
    if (-not $Stat.HashRate_Live -and -not $AllowZero) {return}
}

if ($Pool_User -or $InfoOnly) {
    $Pool_SSL = $false
    foreach($Pool_Port in $Pool_Ports) {
        $Pool_Protocol = "stratum+$(if ($Pool_SSL) {"ssl"} else {"tcp"})"
        foreach($Pool_Region in $Pool_Regions) {    
            [PSCustomObject]@{
                Algorithm     = $Pool_Algorithm_Norm
                Algorithm0    = $Pool_Algorithm_Norm
                CoinName      = $Pool_Coin.Name
                CoinSymbol    = $Pool_Currency
                Currency      = $Pool_Currency
                Price         = 0
                StablePrice   = 0
                MarginOfError = 0
                Protocol      = $Pool_Protocol
                Host          = $Pool_Host -replace "{region}",$Pool_Region
                Port          = $Pool_Port
                User          = "$($Wallets.$Pool_Currency).{workername:$Worker}"
                Pass          = "x"
                Region        = $Pool_RegionsTable.$Pool_Region
                SSL           = $Pool_SSL
                Updated       = $Stat.Updated
                PoolFee       = $Pool_PoolFee
                DataWindow    = $DataWindow
                Workers       = $Pool_Request.result.primary.status.miners
                Hashrate      = $Stat.Hashrate_Live
                TSL           = $Pool_TSL
                BLK           = $Stat.BlockRate_Average
                EthMode       = $null
                ErrorRatio    = $Stat.ErrorRatio
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
                WTM           = $true
            }
        }
        $Pool_SSL = $true
    }
}
