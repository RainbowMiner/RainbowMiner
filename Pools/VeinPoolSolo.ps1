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
    $Pool_Request = Invoke-RestMethodAsync "https://veinpool.fr/api/pools" -tag $Name
}
catch {
    Write-Log -Level Warn "Pool API ($Name) has failed. "
    return
}

if (($Pool_Request.pools | Measure-Object).Count -le 1) {
    Write-Log -Level Warn "Pool API ($Name) returned nothing. "
    return
}

# VeinPool (https://veinpool.fr) runs Miningcore in France (EU): one stratum host, TLS on every port at TCP port + 10000
# SOLO pools only ("*squad" pools are shared-solo groups and are left out); the block reward goes straight to the finder
$Pool_Region = Get-Region "fr"

$Pool_Request.pools | Where-Object {$Pool_Currency = $_.coin.symbol;$_.paymentProcessing.payoutScheme -eq "SOLO" -and $_.id -notmatch "squad$" -and ($Wallets.$Pool_Currency -or $InfoOnly)} | Foreach-Object {

    $Pool_Coin = Get-Coin $Pool_Currency
    if (-not $Pool_Coin) {return}
    $Pool_CoinName = $_.coin.name

    $Pool_Algorithm_Norm = $Pool_Coin.Algo
    $Pool_PoolFee = [Double]$_.poolFeePercent

    # skip the low difficulty ports made for NerdMiner / Bitaxe style devices
    $Pool_Port = [int]($_.ports.PSObject.Properties | Where-Object {-not $_.Value.tls -and $_.Value.name -notmatch "NerdMiner|Bitaxe|mini"} | Foreach-Object {$_.Name} | Select-Object -First 1)

    if (-not $InfoOnly) {
        $Stat = Set-Stat -Name "$($Name)_$($Pool_Currency)_Profit" -Value 0 -Duration $StatSpan -ChangeDetection $false -Difficulty $_.networkStats.networkDifficulty -Quiet
    }

    foreach($Pool_SSL in @($false,$true)) {
        [PSCustomObject]@{
            Algorithm     = $Pool_Algorithm_Norm
            Algorithm0    = $Pool_Algorithm_Norm
            CoinName      = $Pool_Coin.Name
            CoinSymbol    = $Pool_Coin.Symbol
            Currency      = $Pool_Currency
            Price         = $Stat.$StatAverage #instead of .Live
            StablePrice   = $Stat.$StatAverageStable
            MarginOfError = $Stat.Week_Fluctuation
            Protocol      = "stratum+$(if ($Pool_SSL) {"ssl"} else {"tcp"})"
            Host          = "veinpool.fr"
            Port          = if ($Pool_SSL) {$Pool_Port + 10000} else {$Pool_Port}
            User          = "$($Wallets.$Pool_Currency).{workername:$Worker}"
            Pass          = "x"
            Region        = $Pool_Region
            SSL           = $Pool_SSL
            Updated       = $Stat.Updated
            PoolFee       = $Pool_PoolFee
            DataWindow    = $DataWindow
            Workers       = $null
            Hashrate      = $null
            TSL           = $null
            BLK           = $null
            WTM           = $true
            Difficulty    = $Stat.Diff_Average
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
        }
    }
}
