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

$Pools_Request       = [PSCustomObject]@{}
try {
    $Pools_Request = Invoke-RestMethodAsync "https://pool.rplant.xyz/api/currencies" -tag $Name -timeout 15 -cycletime 120
}
catch {
    if ($Error.Count){$Error.RemoveAt(0)}
    Write-Log -Level Warn "Pool API ($Name) has failed. "
    return
}

[hashtable]$Pool_RegionsTable = @{}

$Pool_Regions = @("ru","eu","asia")
$Pool_Regions | Foreach-Object {$Pool_RegionsTable.$_ = Get-Region $_}

$Pool_Ports = [PSCustomObject]@{
    "BNODE" = 7017
    "BELL"  = 3342
    "BIN"   = 3334
    "CPU"   = 7029
    "CRP"   = 3335
    "CSM"   = 7044
    "DMS"   = 7047
    "DNGR"  = 7045
    "GXX"   = 7025
    "ITC"   = 7048
    "IOTS"  = 7028
    "ISO"   = 7030
    "KOTO"  = 3032
    "LDC"   = 7046
    "LITB"  = 7041
    "LBTC"  = 3355
    "LTFN"  = 3385
    "MBC"   = 7022
    "RES"   = 7040
    "SUGAR" = 7042
    "SWAMP" = 7023
    "URX"   = 3361
    "VECO"  = 3351
    "XEBEC" = 7051
    "YTN"   = 3382
}

$Pools_Request.PSObject.Properties | Where-Object {($Wallets."$($_.Name)" -and $Pool_Ports."$($_.Name)") -or $InfoOnly} | ForEach-Object {
    $Pool_Currency       = $_.Name
    $Pool_Algorithm      = $_.Value.algo
    $Pool_Algorithm_Norm = Get-Algorithm $Pool_Algorithm
    $Pool_Fee            = 1.0
    $Pool_User           = $Wallets."$($_.Name)"

    if (-not $InfoOnly) {
        $Stat = Set-Stat -Name "$($Name)_$($Pool_Currency)_Profit" -Value 0 -Duration $StatSpan -ChangeDetection $false -HashRate ([int64]$_.Value.hashrate) -BlockRate ([double]$_.Value."24h_blocks") -Quiet
        if (-not $Stat.HashRate_Live -and -not $AllowZero) {return}
    }

    foreach ($Pool_Region in $Pool_Regions) {    
        [PSCustomObject]@{
            Algorithm     = $Pool_Algorithm_Norm
            Algorithm0    = $Pool_Algorithm_Norm
            CoinName      = $_.Value.name
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
            Workers       = [int]$_.Value.workers
            Hashrate      = $Stat.HashRate_Live
            TSL           = [int]$_.Value.timesincelast
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
