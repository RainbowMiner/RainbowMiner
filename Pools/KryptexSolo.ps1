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
    $Pool_Request = Invoke-RestMethodAsync "https://api.rbminer.net/data/kryptex.json" -tag $Name -cycletime 120 -retry 5 -retrywait 250
}
catch {
    Write-Log -Level Warn "Pool API ($Name) has failed. "
    return
}

if (-not ($Pool_Request | Measure-Object).Count) {
    Write-Log -Level Warn "Pool API ($Name) returned nothing. "
    return
}

[hashtable]$Pool_RegionsTable = @{}

$Pool_Regions = @("eu","ru","sg","us")
$Pool_Regions | Foreach-Object {$Pool_RegionsTable.$_ = Get-Region $_}

$Pool_Request | Where-Object {$_.modes -contains "solo" -and ($Wallets."$($_.symbol)" -or $InfoOnly)} | ForEach-Object {

    $Pool_Rpc  = $_.rpc

    $Pool_Currency = $_.symbol
    $Pool_Algorithm_Norm = Get-Algorithm $_.algo

    $Pool_Wallet = "solo:$($Wallets.$Pool_Currency -replace "^solo:")"

    $Pool_PoolFee = [Double]$_.fee_solo

    $Pool_StatName = "$($Pool_Currency)$(if ($Pool_Rpc -ne $Pool_Currency.ToLower()) {"-$($Pool_Algorithm_Norm)"})"

    if (-not $InfoOnly) {
        $Stat = Set-Stat -Name "$($Name)_$($Pool_StatName)_Profit" -Value 0 -Duration $StatSpan -ChangeDetection $false -Difficulty ([decimal]$(if ($_.diff_native) {$_.diff} else {0})) -Quiet
    }

    $Pool_Data = $_

    foreach($Pool_Region in $Pool_Regions) {
        foreach($ssl in @("","ssl_")) {
            foreach($url in $Pool_Data.servers."$($ssl)urls") {
                if ($url -match "^(.+?-$($Pool_Region).+?):(\d+)$") {
                    $Pool_Host = $Matches[1]
                    $Pool_Port = $Matches[2]
                    $Pool_SSL  = $ssl -ne ""

                    [PSCustomObject]@{
                        Algorithm     = $Pool_Algorithm_Norm
                        Algorithm0    = $Pool_Algorithm_Norm
                        CoinName      = $Pool_Data.coin
                        CoinSymbol    = $Pool_Currency
                        Currency      = $Pool_Currency
                        Price         = 0
                        StablePrice   = 0
                        MarginOfError = 0
                        Protocol      = "stratum+$(if ($Pool_SSL) {"ssl"} else {"tcp"})"
                        Host          = $Pool_Host
                        Port          = $Pool_Port
                        User          = "$($Pool_Wallet)/{workername:$Worker}"
                        Pass          = "x"
                        Region        = $Pool_RegionsTable.$Pool_Region
                        SSL           = $Pool_SSL
                        Updated       = (Get-Date).ToUniversalTime()
                        PoolFee       = $Pool_PoolFee
                        Workers       = $null
                        Hashrate      = $null
                        BLK           = $null
                        TSL           = $null
                        Difficulty    = $Stat.Diff_Average
                        SoloMining    = $true
                        WTM           = $true
                        Name          = $Name
                        Penalty       = 0
                        PenaltyFactor = 1
                        Disabled      = $false
                        HasMinerExclusions = $false
                        Price_0       = 0.0
                        Price_Bias    = 0.0
                        Price_Unbias  = 0.0
                        Wallet        = $Pool_Wallet
                        Worker        = "{workername:$Worker}"
                        Email         = $Email
                    }
                }
            }
        }
    }
}