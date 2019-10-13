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

$Pool_Region_Default = "asia"

[hashtable]$Pool_RegionsTable = @{}
@("eu","us","asia") | Foreach-Object {$Pool_RegionsTable.$_ = Get-Region $_}

$Pool_Request = [PSCustomObject]@{}
try {
    $Pool_Request = Invoke-RestMethodAsync "http://rbminer.net/api/data/f2pool.json" -tag $Name -cycletime 300
}
catch {
    if ($Error.Count){$Error.RemoveAt(0)}
    Write-Log -Level Warn "Pool API ($Name) has failed. "
}

$Pool_Request.PSObject.Properties.Value | Where-Object {$Pool_Currency = $_.currency; ($Wallets.$Pool_Currency -and ($AllowZero -or $_.hashrate)) -or $InfoOnly} | ForEach-Object {

    $Pool_Algorithm_Norm = Get-Algorithm $_.algo
    $Pool_SSL = $Pool_Algorithm_Norm -match "Equihash"
    $Pool_CoinName = Get-CoinSymbol $Pool_Currency -Reverse
    if (-not $Pool_CoinName) {$Pool_CoinName = $Pool_Currency}

    if (-not $InfoOnly) {
        $Divisor  = Switch($_.scale) {"K" {1e3}; "M" {1e6}; "G" {1e9}; "T" {1e12}; "P" {1e15}; "E" {1e18}; default {1}}
        $Hashrate = Switch($_.hashrateunit) {"K" {1e3}; "M" {1e6}; "G" {1e9}; "T" {1e12}; "P" {1e15}; "E" {1e18}; default {1}}
        $Pool_Rate = $Session.Rates.$Pool_Currency
        if (-not $Pool_Rate -and $_.price -and $Session.Rates.USD) {$Pool_Rate = $Session.Rates.USD / $_.price}                          
        $Stat = Set-Stat -Name "$($Name)_$($Pool_Currency)_Profit" -Value $(if ($Pool_Rate) {$_.estimate / $Divisor / $Pool_Rate} else {0}) -Duration $StatSpan -ChangeDetection $false -HashRate ($_.hashrate * $Hashrate) -Quiet
    }

    $Pool_Wallet = Get-WalletWithPaymentId $Wallets.$Pool_Currency -pidchar '.'
    foreach($Region in $_.region) {
        [PSCustomObject]@{
            Algorithm     = $Pool_Algorithm_Norm
            CoinName      = $Pool_CoinName
            CoinSymbol    = $Pool_Currency
            Currency      = $Pool_Currency
            Price         = $Stat.$StatAverage #instead of .Live
            StablePrice   = $Stat.Week
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
            EthMode       = if ($Pool_Algorithm_Norm -match "^(Ethash|ProgPow)") {"ethproxy"} else {$null}
            AlgorithmList = if ($Pool_Algorithm_Norm -match "-") {@($Pool_Algorithm_Norm, ($Pool_Algorithm_Norm -replace '\-.*$'))}else{@($Pool_Algorithm_Norm)}
            Name          = $Name
            Penalty       = 0
            PenaltyFactor = 1
            Wallet        = $Pool_Wallet
            Worker        = "{workername:$Worker}"
            Email         = $Email
        }
    }
}
