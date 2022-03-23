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

$Pool_Region_Default = "asia"

[hashtable]$Pool_RegionsTable = @{}

$Pool_Request = [PSCustomObject]@{}
try {
    $Pool_Request = Invoke-RestMethodAsync "http://rbminer.net/api/data/f2pool.json" -tag $Name -cycletime 300
    $Pool_Request.PSObject.Properties.Value.Region | Select-Object -Unique | Foreach-Object {$Pool_RegionsTable.$_ = Get-Region $_}
}
catch {
    if ($Error.Count){$Error.RemoveAt(0)}
    Write-Log -Level Warn "Pool API ($Name) has failed. "
}

$Pool_Request.PSObject.Properties.Value | Where-Object {$Pool_Currency = $_.currency;$Wallets.$Pool_Currency -or ($_.altsymbol -and $Wallets."$($_.altsymbol)") -or $InfoOnly} | ForEach-Object {

    $Pool_Coin = Get-Coin $Pool_Currency
    $Pool_Algorithm_Norm = Get-Algorithm $_.algo

    if (-not ($Pool_Wallet = $Wallets.$Pool_Currency)) {
        $Pool_Wallet = $Wallets."$($_.altsymbol)"
    }

    $Pool_EthProxy = if ($Pool_Algorithm_Norm -match $Global:RegexAlgoHasEthproxy) {"ethproxy"} elseif ($Pool_Algorithm_Norm -match $Global:RegexAlgoIsProgPow) {"stratum"} else {$null}

    if (-not $InfoOnly) {
        $Divisor  = ConvertFrom-Hash "1$($_.scale)"
        $Hashrate = ConvertFrom-Hash "1$($_.hashrateunit)"
        $Pool_Rate = $Global:Rates.$Pool_Currency
        if (-not $Pool_Rate -and $_.price -and $Global:Rates.USD) {$Pool_Rate = $Global:Rates.USD / $_.price}                          
        $Stat = Set-Stat -Name "$($Name)_$($Pool_Currency)$($_.id -split '-' | Select-Object -Skip 1)_Profit" -Value $(if ($Pool_Rate) {$_.estimate / $Divisor / $Pool_Rate} else {0}) -Duration $StatSpan -ChangeDetection $false -HashRate ($_.hashrate * $Hashrate) -Quiet
        if (-not $Stat.HashRate_Live -and -not $AllowZero) {return}
    }

    $Pool_SSL = $Pool_Currency -in @("BEAM")

    $Pool_Wallet = Get-WalletWithPaymentId $Pool_Wallet -pidchar '.'
    foreach($Region in $_.region) {
        [PSCustomObject]@{
            Algorithm     = $Pool_Algorithm_Norm
            Algorithm0    = $Pool_Algorithm_Norm
            CoinName      = $Pool_Coin.Name
            CoinSymbol    = $Pool_Currency
            Currency      = $Pool_Currency
            Price         = $Stat.$StatAverage #instead of .Live
            StablePrice   = $Stat.$StatAverageStable
            MarginOfError = $Stat.Week_Fluctuation
            Protocol      = "stratum+$(if ($Pool_SSL) {"ssl"} else {"tcp"})"
            Host          = "$($_.host)$(if ($Region -ne "asia") {"-$($Region)"}).f2pool.com"
            Port          = if ($Pool_Currency -eq "ETH" -and $Pool_Wallet -match "^0x[0-9a-f]{40}") {8008} else {$_.port}
            User          = "$($Pool_Wallet).{workername:$Worker}"
            Pass          = "x"
            Region        = $Pool_RegionsTable.$Region
            SSL           = $Pool_SSL
            Updated       = $Stat.Updated
            PoolFee       = $_.fee
            DataWindow    = $DataWindow
            Hashrate      = $Stat.HashRate_Live
            EthMode       = $Pool_EthProxy
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
