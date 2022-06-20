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

$Pool_Fee = 2

$Pools_Data = @(
    [PSCustomObject]@{symbol="KAS"; region=@("eu","ca","ru","hk"); host="acc-pool.pw"; web="kaspa.acc-pool.pw"; port=16061; fee=2}
)

[hashtable]$Pool_RegionsTable = @{}
$Pools_Data.region | Select-Object -Unique | Foreach-Object {$Pool_RegionsTable.$_ = Get-Region $_}

$Pools_Data | Where-Object {$Pool_Currency = $_.symbol;$Wallets.$Pool_Currency -or $InfoOnly} | ForEach-Object {
    $Pool_Coin           = Get-Coin $_.symbol

    if ($Pool_Coin) {
        $Pool_Algorithm  = $Pool_Coin.Algo
        $Pool_CoinName   = $Pool_Coin.Name
    } else {
        $Pool_Algorithm  = $PoolCoins_Request.$Pool_Currency.algo
        $Pool_CoinName   = $PoolCoins_Request.$Pool_Currency.name
    }

    $Pool_Algorithm_Norm = Get-Algorithm $Pool_Algorithm
    $Pool_HR = $null

    try {
        $Pool_Request = (Invoke-WebRequestAsync "https://$($_.web)/poolstatistics/" -tag $Name -timeout 15 -cycletime 120) -split "<script>" | Where-Object {$_ -match "hashrate"} | Where-Object {$_ -match "(?ms)series:[^\[]+\[(\{.+\})\]"} | Foreach-Object {ConvertFrom-Json $Matches[1] -ErrorAction Stop}
        if ($Pool_Request.name -and $Pool_Request.data.Count) {
            $Pool_HR = ConvertFrom-Hash "$(($Pool_Request.data | Select-Object -Last 1) | Select-Object -Last 1)$($Pool_Request.name)"
            $Pool_Request = $null
        }
    } catch {

    }

    if (-not $InfoOnly) {
        $Stat = Set-Stat -Name "$($Name)_$($_.symbol)_Profit" -Value 0 -Duration $StatSpan -ChangeDetection $false -HashRate $Pool_HR -Quiet
        if (-not $Stat.HashRate_Live -and -not $AllowZero) {return}
    }

    $Pool_User     = "$($Wallets.$Pool_Currency).{workername:$Worker}"
    $Pool_Protocol = "stratum+$(if ($_.ssl) {"ssl"} else {"tcp"})"
    $Pool_Fee      = $_.fee
    $Pool_Pass     = "x"

    $i = 0
    foreach($Pool_Region in $_.region) {
        [PSCustomObject]@{
            Algorithm     = $Pool_Algorithm_Norm
			Algorithm0    = $Pool_Algorithm_Norm
            CoinName      = $Pool_CoinName
            CoinSymbol    = $Pool_Currency
            Currency      = $Pool_Currency
            Price         = 0
            StablePrice   = 0
            MarginOfError = 0
            Protocol      = $Pool_Protocol
            Host          = "$(if ($Pool_Region -ne "eu") {"$($Pool_Region)."})$($_.host)"
            Port          = $_.port
            User          = $Pool_User
            Pass          = $Pool_Pass
            Region        = $Pool_RegionsTable.$Pool_Region
            SSL           = if ($_.ssl) {$true} else {$false}
            Updated       = $Stat.Updated
            PoolFee       = $Pool_Fee
            Workers       = $null
            Hashrate      = $Stat.HashRate_Live
            BLK           = $null
            TSL           = $null
            WTM           = $true
            EthMode       = $null
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
        $i++
    }
}
