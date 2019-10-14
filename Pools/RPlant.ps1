using module ..\Include.psm1

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
    $Pools_BlocksRequest = Invoke-RestMethodAsync "https://pool.rplant.xyz/api/blocks" -tag $Name -timeout 15 -cycletime 120
}
catch {
    if ($Error.Count){$Error.RemoveAt(0)}
    Write-Log -Level Warn "Pool blocks API ($Name) has failed. "
    return
}

$Pools_Request       = [PSCustomObject]@{}
try {
    $Pools_Request = Invoke-RestMethodAsync "https://pool.rplant.xyz/api/stats" -tag $Name -timeout 15 -cycletime 120
}
catch {
    if ($Error.Count){$Error.RemoveAt(0)}
    Write-Log -Level Warn "Pool API ($Name) has failed. "
    return
}

[hashtable]$Pool_RegionsTable = @{}

@("ru","eu","asia") | Foreach-Object {$Pool_RegionsTable.$_ = Get-Region $_}

$Pool_Ports = [PSCustomObject]@{
    "BNODE" = 7017
    "BELL"  = 3342
    "BIN"   = 3334
    "CPU"   = 7029
    "CRP"   = 3335
    "GXX"   = 7025
    "KOTO"  = 3032
    "LITB"  = 7041
    "LBTC"  = 3355
    "LTFN"  = 3385
    "LTNCG" = 7028
    "MBC"   = 7022
    "RES"   = 7040
    "SUGAR" = 7042
    "URX"   = 3361
    "VECO"  = 3351
    "YTN"   = 3382
}

$Pools_Request.pools.PSObject.Properties.Value | Where-Object {($Wallets."$($_.symbol)" -and $Pool_Ports."$($_.symbol)" -and ($_.hashrate -or $AllowZero)) -or $InfoOnly} | ForEach-Object {
    $Pool_Currency       = $_.symbol
    $Pool_RpcPath        = $_.name
    $Pool_Algorithm      = $_.algorithm
    $Pool_Algorithm_Norm = Get-Algorithm $Pool_Algorithm
    $Pool_Fee            = 1.0
    $Pool_User           = $Wallets."$($_.symbol)"

    $TimeStamp = Get-UnixTimestamp
    if ($TimeStamp -lt $Pools_Request.time) {$TimeStamp = $Pools_Request.time}

    $Pool_TSL            = if ($FirstBlock = $Pools_BlocksRequest.PSObject.Properties.Name | Where-Object {$_ -match "^$($Pool_RpcPath)-"} | Select-Object -First 1) {$TimeStamp - ($Pools_BlocksRequest.$FirstBlock -split ':' | Select-Object -Index 4)}

    if (-not $InfoOnly) {
        $Stat = Set-Stat -Name "$($Name)_$($Pool_Currency)_Profit" -Value 0 -Duration $StatSpan -ChangeDetection $false -HashRate ([int64]$_.hashrate) -BlockRate ([double]$_.maxRoundTime) -Quiet
    }

    foreach ($Pool_Region in $Pool_RegionsTable.Keys) {    
        [PSCustomObject]@{
            Algorithm     = $Pool_Algorithm_Norm
            CoinName      = $_.namelong
            CoinSymbol    = $Pool_Currency
            Currency      = $Pool_Currency
            Price         = 0
            StablePrice   = 0
            MarginOfError = 0
            Protocol      = "stratum+tcp"
            Host          = "stratum-$($Pool_Region).rplant.xyz"
            Port          = $Pool_Ports.$Pool_Currency
            User          = "$($Pool_User).{workername:$Worker}"
            Pass          = "x"
            Region        = $Pool_RegionsTable.$Pool_Region
            SSL           = $false
            Updated       = (Get-Date).ToUniversalTime()
            PoolFee       = $Pool_Fee
            Workers       = $_.minerCount
            Hashrate      = $Stat.HashRate_Live
            TSL           = $Pool_TSL
            BLK           = $Stat.BlockRate_Average
            EthMode       = if ($Pool_Algorithm_Norm -match "^(Ethash|ProgPow)") {"minerproxy"} else {$null}
            AlgorithmList = if ($Pool_Algorithm_Norm -match "-") {@($Pool_Algorithm_Norm, ($Pool_Algorithm_Norm -replace '\-.*$'))}else{@($Pool_Algorithm_Norm)}
            Name          = $Name
            Penalty       = 0
            PenaltyFactor = 1
            Wallet        = $Pool_User
            Worker        = "{workername:$Worker}"
            Email         = $Email
            WTM           = $true
        }
    }
}
