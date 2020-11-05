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

$Pool_Regions = @("ru","eu","asia","na")
$Pool_Regions | Foreach-Object {$Pool_RegionsTable.$_ = Get-Region $_}

$Pools_Data = [PSCustomObject]@{
    "ALTEX" = [PSCustomObject]@{port = 7070; region = $Pool_Regions}
    "BELL"  = [PSCustomObject]@{port = 3342; region = $Pool_Regions}
    "BCX"   = [PSCustomObject]@{port = 7045; region = $Pool_Regions}
    "BSF"   = [PSCustomObject]@{port = 7065; region = $Pool_Regions}
    "BTX"   = [PSCustomObject]@{port = 7066; region = $Pool_Regions}
    "ZNY"   = [PSCustomObject]@{port = 7054; region = $Pool_Regions}
    "CPU"   = [PSCustomObject]@{port = 7029; region = $Pool_Regions}
    "CRP"   = [PSCustomObject]@{port = 3335; region = $Pool_Regions}
    "DMS"   = [PSCustomObject]@{port = 7047; region = $Pool_Regions}
    "GLEEC" = [PSCustomObject]@{port = 7051; region = $Pool_Regions}
    "GOLD"  = [PSCustomObject]@{port = 7057; region = $Pool_Regions}
    "GXX"   = [PSCustomObject]@{port = 7025; region = $Pool_Regions}
    "ISO"   = [PSCustomObject]@{port = 7030; region = $Pool_Regions}
    "KVA"   = [PSCustomObject]@{port = 7061; region = @("us"); stratum = "randomx"}
    "KLR"   = [PSCustomObject]@{port = 3355; region = @("us"); stratum = "randomx"}
    "KOTO"  = [PSCustomObject]@{port = 3032; region = $Pool_Regions}
    "KYF"   = [PSCustomObject]@{port = 7049; region = $Pool_Regions}
    "LITB"  = [PSCustomObject]@{port = 7041; region = $Pool_Regions}
    "LRA"   = [PSCustomObject]@{port = 7050; region = $Pool_Regions}
    "MBC"   = [PSCustomObject]@{port = 7022; region = $Pool_Regions}
    "NAD"   = [PSCustomObject]@{port = 7064; region = $Pool_Regions}
    "QRN"   = [PSCustomObject]@{port = 7067; region = $Pool_Regions}
    "RES"   = [PSCustomObject]@{port = 7040; region = $Pool_Regions}
    "RNG"   = [PSCustomObject]@{port = 7018; region = $Pool_Regions}
    "SPRX"  = [PSCustomObject]@{port = 7052; region = $Pool_Regions}
    "SUGAR" = [PSCustomObject]@{port = 7042; region = $Pool_Regions}
    "SWAMP" = [PSCustomObject]@{port = 7023; region = $Pool_Regions}
    "TDC"   = [PSCustomObject]@{port = 7017; region = $Pool_Regions}
    "URX"   = [PSCustomObject]@{port = 3361; region = $Pool_Regions}
    "VECO"  = [PSCustomObject]@{port = 3351; region = $Pool_Regions}
    "XOL"   = [PSCustomObject]@{port = 7068; region = @("us"); stratum = "randomx"}
    "YTN"   = [PSCustomObject]@{port = 3382; region = $Pool_Regions}
    "ZELS"  = [PSCustomObject]@{port = 7060; region = $Pool_Regions}
}

$Pools_Request.PSObject.Properties | Where-Object {($Wallets."$($_.Name)" -and $Pools_Data."$($_.Name)") -or $InfoOnly} | ForEach-Object {
    $Pool_Currency       = $_.Name
    $Pool_Algorithm      = $_.Value.algo
    $Pool_Algorithm_Norm = Get-Algorithm $Pool_Algorithm
    $Pool_Fee            = 1.0
    $Pool_User           = $Wallets."$($_.Name)"
    if (-not ($Pool_Data = $Pools_Data.$Pool_Currency)) {
        Write-Log -Level Warn "Pool $($Name) missing port for $($Pool_Currency)"
        return
    }
    $Pool_Stratum        = if ($Pool_Data.stratum) {$Pool_Data.stratum} else {"stratum-%region%"}

    if (-not $InfoOnly) {
        $Stat = Set-Stat -Name "$($Name)_$($Pool_Currency)_Profit" -Value 0 -Duration $StatSpan -ChangeDetection $false -HashRate ([int64]$_.Value.hashrate) -BlockRate ([double]$_.Value."24h_blocks") -Quiet
        if (-not $Stat.HashRate_Live -and -not $AllowZero) {return}
    }

    foreach ($Pool_Region in $Pool_Data.region) {
        foreach ($SSL in @($false,$true)) {
            [PSCustomObject]@{
                Algorithm     = $Pool_Algorithm_Norm
                Algorithm0    = $Pool_Algorithm_Norm
                CoinName      = $_.Value.name
                CoinSymbol    = $Pool_Currency
                Currency      = $Pool_Currency
                Price         = 0
                StablePrice   = 0
                MarginOfError = 0
                Protocol      = "stratum+$(if ($SSL) {"ssl"} else {"tcp"})"
                Host          = "$($Pool_Stratum -replace "%region%",$Pool_Region).rplant.xyz"
                Port          = if ($SSL) {$Pool_Data.port+10000} else {$Pool_Data.port}
                User          = "$($Pool_User).{workername:$Worker}"
                Pass          = "x"
                Region        = $Pool_RegionsTable.$Pool_Region
                SSL           = $SSL
                Updated       = (Get-Date).ToUniversalTime()
                PoolFee       = $Pool_Fee
                Workers       = [int]$_.Value.workers
                Hashrate      = $Stat.HashRate_Live
                TSL           = [int]$_.Value.timesincelast
                BLK           = $Stat.BlockRate_Average
                EthMode       = if ($Pool_Algorithm_Norm -match "^(Ethash|ProgPow)") {"minerproxy"} elseif ($Pool_Algorithm_Norm -match "^(KawPOW)") {"stratum"} else {$null}
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
}
