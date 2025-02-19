using module ..\Modules\Include.psm1

param(
    [PSCustomObject]$Wallets,
    [PSCustomObject]$Params,
    [alias("WorkerName")]
    [String]$Worker,
    [String]$Password,
    [TimeSpan]$StatSpan,
    [String]$DataWindow = "estimate_current",
    [Bool]$InfoOnly = $false,
    [Bool]$AllowZero = $false,
    [String]$StatAverage = "Minute_10",
    [String]$StatAverageStable = "Week"
)

$Name = Get-Item $MyInvocation.MyCommand.Path | Select-Object -ExpandProperty BaseName

$Pool_Currency = "ABEL"

if ($Wallets.$Pool_Currency -match "^(.+?):(.+?)$") {
    $Pool_User = $Matches[1]
    $Pool_Pass = $Matches[2]
} else {
    $Pool_User = $Wallets.$Pool_Currency
    $Pool_Pass = $Params.$Pool_Currency
}

if ((-not $Pool_User -or -not $Pool_Pass) -and -not $InfoOnly) {return}

[hashtable]$Pool_RegionsTable = @{}

$Pool_Regions = @("us","asia")
$Pool_Regions | Foreach-Object {$Pool_RegionsTable.$_ = Get-Region $_}

$Pool_Coin = Get-Coin $Pool_Currency
$Pool_Algorithm_Norm = $Pool_Coin.Algo

$Pool_BLK = $Pool_TSL = $null

if (-not $InfoOnly) {

    $Pool_Request = @()

    try {
        $Pool_Request = Invoke-RestMethodAsync "https://api.abelpool.io/api/v1/home/online/summary" -tag $Name -retry 3 -retrywait 1000 -timeout 15 -cycletime 120
    }
    catch {
        if ($Global:Error.Count){$Global:Error.RemoveAt(0)}
    }

    if ($Pool_Request.code -eq 200) {
        $Pool_BLK = if ($Pool_Request.data.AvgBlockTime) {[int](86400 / $Pool_Request.data.AvgBlockTime)} else {$null}
        $Pool_TSL = [int]((Get-UnixTimestamp) - $Pool_Request.data.CreatedAt)
    }

    $Stat = Set-Stat -Name "$($Name)_$($Pool_Currency)_Profit" -Value 0 -Duration $StatSpan -ChangeDetection $false -HashRate $null -BlockRate $Pool_BLK
    #if (-not $Stat.HashRate_Live -and -not $AllowZero) {return}
}

foreach ($Pool_Region in $Pool_Regions) {
    [PSCustomObject]@{
        Algorithm     = $Pool_Algorithm_Norm
		Algorithm0    = $Pool_Algorithm_Norm
        CoinName      = $Pool_Coin.Name
        CoinSymbol    = $Pool_Currency
        Currency      = $Pool_Currency
        Price         = 0
        StablePrice   = 0
        MarginOfError = 0
        Protocol      = "stratum+ssl"
        Host          = "$(if ($Pool_Region -eq "us") {"global"} else {$Pool_Region})-service.abelpool.io"
        Port          = 27778
        User          = $Pool_User
        Pass          = $Pool_Pass
        Region        = $Pool_RegionsTable.$Pool_Region
        SSL           = $true
        Updated       = $Stat.Updated
        PoolFee       = 1.0
        DataWindow    = $DataWindow
        Workers       = $null
        Hashrate      = $null
        BLK           = if ($Pool_BLK -ne $null) {$Stat.BlockRate_Average} else {$null}
        TSL           = $Pool_TSL
        WTM           = $true
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
