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
    [String]$StatAverageStable = "Week",
    [alias("UserName")]
    [String]$User = "",
    [String]$PPMode = "pps"
)

$Name = Get-Item $MyInvocation.MyCommand.Path | Select-Object -ExpandProperty BaseName

if (-not $User -and -not $InfoOnly) {return}

$Pool_Request = [PSCustomObject]@{}
$PoolCoins_Request = [PSCustomObject]@{}

try {
    $Pool_Request = Invoke-RestMethodAsync "https://prohashing.com/api/v1/status" -tag $Name -cycletime 120
}
catch {
    if ($Error.Count){$Error.RemoveAt(0)}
}

if ($Pool_Request.code -ne 200) {
    Write-Log -Level Warn "Pool API ($Name) has failed. "
    return
}

try {
    $PoolCoins_Request = Invoke-RestMethodAsync "https://prohashing.com/api/v1/currencies" -tag $Name -cycletime 120
}
catch {
    if ($Error.Count){$Error.RemoveAt(0)}
}

if ($PoolCoins_Request.code -ne 200) {
    Write-Log -Level Warn "Pool currencies API ($Name) has failed. "
    return
}

[hashtable]$Pool_Algorithms = @{}
[hashtable]$Pool_Coins = @{}
[hashtable]$Pool_RegionsTable = @{}

$Pool_Host = "prohashing.com"

$Pool_Regions = @("us","eu")
$Pool_Regions | Foreach-Object {$Pool_RegionsTable.$_ = Get-Region $_}

if ($PPMode) {$Pool_PPMode = $PPMode}
else {
    $Pool_PPMode = if ($User -match "@(pps|fpps|pplns|solo)") {
        $User = $User -replace "@$($Matches[1])"
        $Matches[1] -replace "f"
    } else {
        "pps"
    }
}

$PoolCoins_Request.data.PSObject.Properties | Where-Object {$_.Value.port -and $_.Value.enabled -and $_.Value.lastblock} | ForEach-Object {
    $Pool_CoinSymbol = $_.Name
    $Pool_CoinName   = $_.Value.name
    $Pool_Port       = $_.Value.port
    $Pool_Algorithm  = $_.Value.algo
    $Pool_PoolFee    = [double]$Pool_Request.data.$Pool_Algorithm."$($Pool_PPMode)_fee" * 100
    $Pool_Factor     = [double]$Pool_Request.data.$Pool_Algorithm.mbtc_mh_factor
    $Pool_TSL        = [int]$_.Value.timesincelast
    $Pool_BLK        = [int]$_.Value."24h_blocks"

    if ($Pool_Factor -le 0) {
        Write-Log -Level Info "$($Name): Unable to determine divisor for algorithm $Pool_Algorithm. "
        return
    }

    if (-not $Pool_Algorithms.ContainsKey($Pool_Algorithm)) {$Pool_Algorithms.$Pool_Algorithm = Get-Algorithm $Pool_Algorithm}
    $Pool_Algorithm_Norm = $Pool_Algorithms.$Pool_Algorithm
    
    if (-not $InfoOnly) {
        $Stat = Set-Stat -Name "$($Name)_$($Pool_Algorithm_Norm)_Profit" -Value 0 -Duration $StatSpan -ChangeDetection $false -HashRate $_.Value.hashrate -BlockRate $Pool_BLK -Quiet
        if (-not $Stat.HashRate_Live -and -not $AllowZero) {return}
    }

    foreach($Pool_Region in $Pool_Regions) {
        $Pool_Params = if ($Params.$Pool_CoinSymbol) {",$($Params.$Pool_CoinSymbol)"}
        [PSCustomObject]@{
            Algorithm     = $Pool_Algorithm_Norm
            Algorithm0    = $Pool_Algorithm_Norm
            CoinName      = $Pool_CoinName
            CoinSymbol    = $Pool_CoinSymbol
            Currency      = $Pool_CoinSymbol
            Price         = 0
            StablePrice   = 0
            MarginOfError = 0
            Protocol      = "stratum+tcp"
            Host          = "$(if ($Pool_Region -eq "eu") {"eu."})$Pool_Host"
            Port          = $Pool_Port
            User          = $User
            Pass          = "a=$($_),c=$($Pool_CoinName.ToLower()),n={workername:$Worker}$(if ($Pool_PPMode -ne "pps") {",m=$($Pool_PPMode)"}){diff:,d=`$difficulty}$Pool_Params"
            Region        = $Pool_RegionsTable.$Pool_Region
            SSL           = $false
            Updated       = $Stat.Updated
            PoolFee       = $Pool_PoolFee
            DataWindow    = $DataWindow
            Hashrate      = $Stat.HashRate_Live
            Workers       = $null
            BLK           = $Stat.BlockRate_Average
            TSL           = $Pool_TSL
            WTM           = $true
			ErrorRatio    = $Stat.ErrorRatio
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
