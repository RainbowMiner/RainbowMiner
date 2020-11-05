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
    [String]$StatAverage = "Minute_10"
)

$Name = Get-Item $MyInvocation.MyCommand.Path | Select-Object -ExpandProperty BaseName

$Pools_BlocksRequest = [PSCustomObject]@{}
try {
    $Pools_BlocksRequest = Invoke-RestMethodAsync "http://cpu-pool.com/api/blocks" -tag $Name -timeout 15 -cycletime 120
}
catch {
    if ($Error.Count){$Error.RemoveAt(0)}
    Write-Log -Level Warn "Pool blocks API ($Name) has failed. "
    return
}

$Pools_Request       = [PSCustomObject]@{}
try {
    $Pools_Request = Invoke-RestMethodAsync "http://cpu-pool.com/api/stats" -tag $Name -timeout 15 -cycletime 120
    if ($Pools_Request -is [string]) {
        $Pools_Request = ConvertFrom-Json "$($Pools_Request -replace '"workers":{".+?}},')" -ErrorAction Stop
    }
}
catch {
    if ($Error.Count){$Error.RemoveAt(0)}
    Write-Log -Level Warn "Pool API ($Name) has failed. "
    return
}

[hashtable]$Pool_RegionsTable = @{}

$Pool_Regions = @("ru")
$Pool_Regions | Foreach-Object {$Pool_RegionsTable.$_ = Get-Region $_}

$Pool_Ports = [PSCustomObject]@{
    "BELL"  = 63338
    "CPU"   = 63386
    "CRP"   = 63358
    #"ITC"   = 63328
    "KOTO"  = 63318
    "LITB"  = 63398
    "MBC"   = 63408
    "SUGAR" = 63418
    "URX"   = 63378
    "YTN"   = 63368
}

$Pools_Request.pools.PSObject.Properties.Value | Where-Object {($Wallets."$($_.symbol)" -and $Pool_Ports."$($_.symbol)") -or $InfoOnly} | ForEach-Object {
    $Pool_Currency       = $_.symbol
    $Pool_RpcPath        = $_.name
    $Pool_Algorithm      = $_.algorithm
    $Pool_Algorithm_Norm = Get-Algorithm $Pool_Algorithm
    $Pool_Fee            = 1.0
    $Pool_User           = $Wallets."$($_.symbol)"

    $TimeStamp = Get-UnixTimestamp
    if ($TimeStamp -lt $Pools_Request.time) {$TimeStamp = $Pools_Request.time}

    $Pool_TSL            = if ($FirstBlock = $Pools_BlocksRequest.PSObject.Properties.Name | Where-Object {$_ -match "^$($Pool_RpcPath)-"} | Select-Object -First 1) {$TimeStamp - ($Pools_BlocksRequest.$FirstBlock -split ':' | Select-Object -Index 4)/1000}

    if (-not $InfoOnly) {
        $Stat = Set-Stat -Name "$($Name)_$($Pool_Currency)_Profit" -Value 0 -Duration $StatSpan -ChangeDetection $false -HashRate ([int64]$_.hashrate) -BlockRate ([double]$_.maxRoundTime) -Quiet
        if (-not $Stat.HashRate_Live -and -not $AllowZero) {return}
    }

    foreach ($Pool_Region in $Pool_Regions) {    
        [PSCustomObject]@{
            Algorithm     = $Pool_Algorithm_Norm
            Algorithm0    = $Pool_Algorithm_Norm
            CoinName      = $_.namelong
            CoinSymbol    = $Pool_Currency
            Currency      = $Pool_Currency
            Price         = 0
            StablePrice   = 0
            MarginOfError = 0
            Protocol      = "stratum+tcp"
            Host          = "cpu-pool.com"
            Port          = $Pool_Ports.$Pool_Currency
            User          = "$($Pool_User).{workername:$Worker}"
            Pass          = "x"
            Region        = $Pool_RegionsTable.$Pool_Region
            SSL           = $false
            Updated       = (Get-Date).ToUniversalTime()
            PoolFee       = $Pool_Fee
            Workers       = $_.workerCount
            Hashrate      = $Stat.HashRate_Live
            TSL           = $Pool_TSL
            BLK           = $Stat.BlockRate_Average
            EthMode       = if ($Pool_Algorithm_Norm -match "^(Ethash|ProgPow|KawPow)") {"minerproxy"} else {$null}
            Name          = $Name
            Penalty       = 0
            PenaltyFactor = 1
            Disabled      = $false
            HasMinerExclusions = $false
            Price_Bias    = 0.0
            Price_Unbias  = 0.0
            Wallet        = $Pool_User
            Worker        = "{workername:$Worker}"
            Email         = $Email
            WTM           = $true
        }
    }
}
