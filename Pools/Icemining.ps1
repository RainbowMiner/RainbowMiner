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

$Pool_Fee = 1

$Pool_Request = [PSCustomObject]@{}
$PoolCoins_Request = [PSCustomObject]@{}

try {
    $PoolCoins_Request = Invoke-RestMethodAsync "https://icemining.ca/api/currencies" -tag $Name -cycletime 120
    if ($PoolCoins_Request -is [string]) {$PoolCoins_Request = ($PoolCoins_Request -replace '<script.+?/script>' -replace '<.+?>').Trim() | ConvertFrom-Json -ErrorAction Stop}
}
catch {
    if ($Error.Count){$Error.RemoveAt(0)}
    Write-Log -Level Warn "Pool API ($Name) has failed. "
    return
}

if (($PoolCoins_Request | Get-Member -MemberType NoteProperty -ErrorAction Ignore | Measure-Object Name).Count -le 1) {
    Write-Log -Level Warn "Pool API ($Name) returned nothing. "
    return
}

[hashtable]$Pool_RegionsTable = @{}

@("us","eu","asia") | Foreach-Object {$Pool_RegionsTable.$_ = Get-Region $_}

$Pools_Data = @(
    [PSCustomObject]@{symbol="SIN";  host=@("stratum","eu","asia"); region=@("us","eu","asia"); fee = 1}
    [PSCustomObject]@{symbol="XRD";  host=@("stratum","eu","asia"); region=@("us","eu","asia"); fee = 1}
    [PSCustomObject]@{symbol="NIM";  host=@("nimiq");               region=@("us");           ; fee = 1.25; ssl = $true}
    [PSCustomObject]@{symbol="KDA";  host=@("kda-us","kda-eu");     region=@("us","eu")       ; fee = 2}
    [PSCustomObject]@{symbol="EPIC"; host=@("epic");                region=@("us");           ; fee = 2; algo = "ProgPow"}
    [PSCustomObject]@{symbol="EPIC"; host=@("epic");                region=@("us");           ; fee = 2; algo = "RandomX"}
    [PSCustomObject]@{symbol="EPIC"; host=@("epic");                region=@("us");           ; fee = 2; algo = "CuckooCycle"}
    [PSCustomObject]@{symbol="MWC";  host=@("mwc-us","mwc-eu");     region=@("us","eu");      ; fee = 1; algo = "Cuckarood29"; hashrate = "C29d"}
    [PSCustomObject]@{symbol="MWC";  host=@("mwc-us","mwc-eu");     region=@("us","eu");      ; fee = 1; algo = "Cuckatoo31";  hashrate = "C31"}
    [PSCustomObject]@{symbol="ATOM"; host=@("atom-us");             region=@("us");           ; fee = 0; ssl = $true}
    [PSCustomObject]@{symbol="ARW";  host=@("stratum","eu","asia"); region=@("us","eu","asia"); fee = 1}

    #[PSCustomObject]@{symbol="BITC"; host=@("stratum","eu","asia"); region=@("us","eu","asia"); fee = 1}
    #[PSCustomObject]@{symbol="PHL";  host=@("stratum","eu","asia"); region=@("us","eu","asia"); fee = 1}
    #[PSCustomObject]@{symbol="CKB";  host=@("stratum","eu","asia"); region=@("us","eu","asia"); fee = 1}
    #[PSCustomObject]@{symbol="ZMY";  host=@("stratum","eu","asia"); region=@("us","eu","asia"); fee = 1}
)

$Pools_Data | Where-Object {$Pool_Currency = $_.symbol; $PoolCoins_Request.$Pool_Currency -ne $null -and ($Wallets.$Pool_Currency -or $InfoOnly)} | ForEach-Object {
    $Pool_Coin           = Get-Coin "$Pool_Currency$(if ($_.algo) {"-$($_.algo)"})"

    if ($Pool_Coin) {
        $Pool_Algorithm  = $Pool_Coin.Algo
        $Pool_CoinName   = $Pool_Coin.Name
    } else {
        $Pool_Algorithm  = $PoolCoins_Request.$Pool_Currency.algo
        $Pool_CoinName   = $PoolCoins_Request.$Pool_Currency.name
    }

    $Pool_Algorithm_Norm = Get-Algorithm $Pool_Algorithm

    $Pool_Params = if ($Params.$Pool_Currency) {",$($Params.$Pool_Currency)"}

    if (-not $InfoOnly) {
        $Stat = Set-Stat -Name "$($Name)_$($Pool_Currency)$(if ($_.algo) {"-$Pool_Algorithm_Norm"})_Profit" -Value 0 -Duration $StatSpan -ChangeDetection $false -HashRate $(if ($Pool_Currency -eq "EPIC") {10} elseif ($_.hashrate) {$PoolCoins_Request.$Pool_Currency.hashrate."$($_.hashrate)"} else {$PoolCoins_Request.$Pool_Currency.hashrate}) -BlockRate $PoolCoins_Request.$Pool_Currency."24h_blocks" -Quiet
        if (-not $Stat.HashRate_Live -and -not $AllowZero) {return}
    }

    $Pool_User = if ($Pool_Currency -eq "MWC") {
        $Wallets.$Pool_Currency
    } else {
        "$($Wallets.$Pool_Currency).{workername:$Worker}"
    }

    $Pool_Pass = if ($Pool_Currency -eq "MWC") {
        "$(if ($Pool_Params) {$Pool_Params} else {"x"})"
    } else {
        "c=$Pool_Currency{diff:,d=`$difficulty}$Pool_Params"
    }

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
            Protocol      = "stratum+$(if ($_.ssl) {"ssl"} else {"tcp"})"
            Host          = "$($_.host[$i]).icemining.ca"
            Port          = $PoolCoins_Request.$Pool_Currency.port
            User          = $Pool_User
            Pass          = $Pool_Pass
            Region        = $Pool_RegionsTable.$Pool_Region
            SSL           = if ($_.ssl) {$true} else {$false}
            Updated       = $Stat.Updated
            PoolFee       = $_.fee
            Workers       = $PoolCoins_Request.$Pool_Currency.workers
            Hashrate      = $Stat.HashRate_Live
            BLK           = $Stat.BlockRate_Average
            TSL           = $PoolCoins_Request.$Pool_Currency.timesincelast
            WTM           = $true
            Name          = $Name
            Penalty       = 0
            PenaltyFactor = 1
            Disabled      = $false
            HasMinerExclusions = $false
            Price_Bias    = 0.0
            Price_Unbias  = 0.0
            Wallet        = $Wallets.$Pool_Currency
            Worker        = "{workername:$Worker}"
            Email         = $Email
        }
        $i++
    }
}
