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
    [String]$StatAverageStable = "Week"
)

$Name = Get-Item $MyInvocation.MyCommand.Path | Select-Object -ExpandProperty BaseName

$Pool_Id = $null
$Pool_Request = [PSCustomObject]@{}

try {
    $Pool_Request = Invoke-RestMethodAsync "https://xdag.org/api/pools" -tag $Name -cycletime 86400
    $Pool_Ids = @($Pool_Request | Where-Object {$_.name -match "EQUAL"})

    if ($Pool_Ids) {
        foreach ( $Pool_Id in $Pool_Ids ) {
            if ($Pool_Id.id) {
                $Pool_Request = Invoke-RestMethodAsync "https://xdag.org/api/status?pool_id=$($Pool_id.id)" -tag $name -cycletime 120
                if ($Pool_Request.status -eq "online" -and $Pool_Request.workers_count -lt $Pool_Request.workers_limit) {
                    break
                }
            }
        }
    }
}
catch {
    $Pool_Id = $null
}

if (-not $Pool_Id) {
    Write-Log -Level Warn "Pool API ($Name) has failed. "
    return
}

if ($Pool_Request.workers_count -ge $Pool_Request.workers_limit) {
    Write-Log -Level Warn "Pool API ($Name) all slots are full. Waiting for an empty slot. "
    return
}

$Pool_Currency = "XDAG"

$Pool_Host = $Pool_Request.mining_stratum_domain
$Pool_Port = $Pool_Request.mining_stratum_port
$Pool_Fee  = [double]$Pool_Request.fee_percent

$Pool_User = $Wallets.$Pool_Currency

$Pool_Coin = Get-Coin $Pool_Currency
$Pool_Algorithm_Norm = $Pool_Coin.Algo

$Pool_BLK = if ($Pool_Request.block_interval_seconds) {86400 / $Pool_Request.block_interval_seconds} else {$null} 

[hashtable]$Pool_RegionsTable = @{}

$Pool_Regions = @("de")
$Pool_Regions | Foreach-Object {$Pool_RegionsTable.$_ = Get-Region $_}

if (-not $InfoOnly) {
    $Stat = Set-Stat -Name "$($Name)_$($Pool_Algorithm_Norm)_Profit" -Value 0 -Duration $StatSpan -ChangeDetection $false -HashRate $Pool_Request.stats.hashrate[0] -BlockRate $Pool_BLK -Quiet
    if (-not $Stat.HashRate_Live -and -not $AllowZero) {return}
}

$Pool_Params = "$(if ($Params.$Pool_Currency) {",$($Params.$Pool_Currency)"})"

if ($Pool_User -or $InfoOnly) {
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
            Protocol      = "stratum+tcp"
            Host          = $Pool_Host
            Port          = $Pool_Port
            User          = $Pool_User
            Pass          = "{workername:$Worker}$Pool_Params"
            Region        = $Pool_Regions.$Pool_Region
            SSL           = $false
            Updated       = $Stat.Updated
            PoolFee       = $Pool_Fee
            DataWindow    = $DataWindow
            Workers       = $Pool_Request.workersNum
            Hashrate      = $Stat.HashRate_Live
            BLK           = $Stat.BlockRate_Average
            TSL           = $null
            WTM           = $true
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
    }
}
