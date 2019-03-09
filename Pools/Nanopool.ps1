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

$Pool_Request = [PSCustomObject]@{}

[hashtable]$Pool_Regions = @{
    (Get-Region "eu")   = "-eu1.nanopool.org"
    (Get-Region "us")   = "-us-east1.nanopool.org"
    (Get-Region "asia") = "-asia1.nanopool.org"
}

$Pools_Data = @(
    [PSCustomObject]@{coin = "EthereumClassic"; algo = "Ethash";        symbol = "ETC";  port = 19999; fee = 1; divisor = 1e6; ssl = $false; protocol = "stratum+tcp"}
    [PSCustomObject]@{coin = "Ethereum";        algo = "Ethash";        symbol = "ETH";  port = 9999;  fee = 1; divisor = 1e6; ssl = $false; protocol = "stratum+tcp"}
    [PSCustomObject]@{coin = "Zcash";           algo = "Equihash";      symbol = "ZEC";  port = 6666;  fee = 1; divisor = 1;   ssl = $true;  protocol = "stratum+ssl"}
    [PSCustomObject]@{coin = "Monero";          algo = "CrypotnightR";  symbol = "XMR";  port = 14444; fee = 1; divisor = 1;   ssl = $true;  protocol = "stratum+ssl"}
    [PSCustomObject]@{coin = "Electroneum";     algo = "Cryptonight";   symbol = "ETN";  port = 13333; fee = 2; divisor = 1;   ssl = $true;  protocol = "stratum+ssl"}
    [PSCustomObject]@{coin = "RavenCoin";       algo = "X16r";          symbol = "RVN";  port = 12222; fee = 1; divisor = 1e6; ssl = $false; protocol = "stratum+tcp"}
    [PSCustomObject]@{coin = "PascalCoin";      algo = "Randomhash";    symbol = "PASC"; port = 15556; fee = 2; divisor = 1;   ssl = $false; protocol = "stratum+tcp"}
    [PSCustomObject]@{coin = "Grin";            algo = "Cuckaroo29";    symbol = "GRIN"; port = 12111; fee = 2; divisor = 1;   ssl = $false; protocol = "stratum+tcp"; walletsymbol = "GRIN29"}
)

$Pools_Data | Where-Object {$Wallets."$($_.symbol)" -or $InfoOnly} | ForEach-Object {
    $Pool_Port = $_.port
    $Pool_Algorithm = $_.algo
    $Pool_Algorithm_Norm = Get-Algorithm $_.algo
    $Pool_Currency = $_.symbol
    $Pool_Symbol = if ($_.walletsymbol) {$_.walletsymbol} else {$_.symbol}

    $ok = $true
    if (-not $InfoOnly) {
        $Pool_Request = [PSCustomObject]@{}
        $Pool_RequestWorkers = [PSCustomObject]@{}
        $Pool_RequestHashrate = [PSCustomObject]@{}

        try {
            $Pool_Request = Invoke-RestMethodAsync "https://api.nanopool.org/v1/$($Pool_Symbol.ToLower())/approximated_earnings/1000" -tag $Name -retry 5 -retrywait 200 -cycletime 120
            if (-not $Pool_Request.status) {throw}
        }
        catch {
            if ($Error.Count){$Error.RemoveAt(0)}
            Write-Log -Level Warn "Pool API ($Name) for $($Pool_Currency) has failed. "
            $ok = $false
        }


        try {
            $Pool_RequestWorkers = Invoke-RestMethodAsync "https://api.nanopool.org/v1/$($Pool_Symbol.ToLower())/pool/activeworkers" -tag $Name -retry 5 -retrywait 200 -cycletime 120
            $Pool_RequestHashrate= Invoke-RestMethodAsync "https://api.nanopool.org/v1/$($Pool_Symbol.ToLower())/pool/hashrate" -tag $Name -retry 5 -retrywait 200 -cycletime 120
        }
        catch {
            if ($Error.Count){$Error.RemoveAt(0)}
            Write-Log -Level Info "Pool second level API ($Name) for $($Pool_Currency) has failed. "
        }

        if ($ok) {
            $Pool_ExpectedEarning = [double]$Pool_Request.data.day.bitcoins / $_.divisor / 1000
            $Stat = Set-Stat -Name "$($Name)_$($Pool_Currency)_Profit" -Value $Pool_ExpectedEarning -Duration $StatSpan -Hashrate ([double]$Pool_RequestHashrate.data * $_.divisor) -ChangeDetection $true -Quiet
        }
    }

    if ($ok) {
        foreach($Pool_Region in $Pool_Regions.Keys) {
            [PSCustomObject]@{
                Algorithm     = $Pool_Algorithm_Norm
                CoinName      = $_.coin
                CoinSymbol    = $Pool_Currency
                Currency      = $Pool_Currency
                Price         = $Stat.$StatAverage #instead of .Live
                StablePrice   = $Stat.Week
                MarginOfError = $Stat.Week_Fluctuation
                Protocol      = $_.protocol
                Host          = "$($_.symbol.ToLower())$($Pool_Regions.$Pool_Region)"
                Port          = $_.port
                User          = "$($Wallets."$($_.symbol)")/{workername:$Worker}"
                Pass          = "x"
                Region        = $Pool_Region
                SSL           = $_.ssl
                Updated       = $Stat.Updated
                PoolFee       = $_.fee
                DataWindow    = $DataWindow
                Workers       = $Pool_RequestWorkers.data
                Hashrate      = $Stat.HashRate_Live
            }
        }
    }
}
