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
    [String]$StatAverage = "Minute_10",
    [String]$Email = ""
)

$Name = Get-Item $MyInvocation.MyCommand.Path | Select-Object -ExpandProperty BaseName

$Pool_Request = [PSCustomObject]@{}

[hashtable]$Pool_Regions = @{
    (Get-Region "eu")   = "-eu1.nanopool.org"
    (Get-Region "us")   = "-us-east1.nanopool.org"
    (Get-Region "asia") = "-asia1.nanopool.org"
}

$Pools_Data = @(
    [PSCustomObject]@{symbol = "ETC";  port = 19999;          fee = 1; divisor = 1e6; useemail = $false; usepid = $false}
    [PSCustomObject]@{symbol = "ETH";  port = 9999;           fee = 1; divisor = 1e6; useemail = $false; usepid = $false}
    [PSCustomObject]@{symbol = "ZEC";  port = @(6666,6633);   fee = 1; divisor = 1;   useemail = $false; usepid = $false}
    [PSCustomObject]@{symbol = "XMR";  port = @(14444,14433); fee = 1; divisor = 1;   useemail = $false; usepid = $true}
    [PSCustomObject]@{symbol = "ETN";  port = @(13333,13433); fee = 2; divisor = 1;   useemail = $false; usepid = $false}
    [PSCustomObject]@{symbol = "RVN";  port = 12222;          fee = 1; divisor = 1e6; useemail = $false; usepid = $false}
    [PSCustomObject]@{symbol = "PASC"; port = 15556;          fee = 2; divisor = 1;   useemail = $true;  usepid = $true}
    [PSCustomObject]@{symbol = "GRIN"; port = 12111;          fee = 2; divisor = 1;   useemail = $false; walletsymbol = "GRIN29"}
)

$Pools_Data | Where-Object {$Wallets."$($_.symbol)" -or $InfoOnly} | ForEach-Object {
    $Pool_Coin      = Get-Coin $_.walletsymbol
    $Pool_Algorithm_Norm = Get-Algorithm $Pool_Coin.Algo
    $Pool_Currency = $_.symbol
    $Pool_Symbol = if ($_.walletsymbol) {$_.walletsymbol} else {$_.symbol}
    $Pool_Wallet = Get-WalletWithPaymentId $Wallets.$Pool_Currency -pidchar '.' -asobject
    if ($Pool_Currency -eq "PASC" -and -not $Pool_Wallet.paymentid) {$Pool_Wallet.wallet = "$($Pool_Wallet.wallet).0"}

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
            $Pool_SSL = $false
            foreach($Pool_Port in @($_.port | Select-Object)) {
                [PSCustomObject]@{
                    Algorithm     = $Pool_Algorithm_Norm
                    CoinName      = $Pool_Coin.Name
                    CoinSymbol    = $Pool_Currency
                    Currency      = $Pool_Currency
                    Price         = $Stat.$StatAverage #instead of .Live
                    StablePrice   = $Stat.Week
                    MarginOfError = $Stat.Week_Fluctuation
                    Protocol      = "stratum+$(if ($Pool_SSL) {"ssl"} else {"tcp"})"
                    Host          = "$($_.symbol.ToLower())$($Pool_Regions.$Pool_Region)"
                    Port          = $Pool_Port
                    User          = "$($Pool_Wallet.wallet).{workername:$Worker}$(if ($_.useemail -and $Email) {"/$($Email)"})"
                    Pass          = "x"
                    Wallet        = $Pool_Wallet.wallet
                    Worker        = "{workername:$Worker}"
                    Email         = $Email
                    Region        = $Pool_Region
                    SSL           = $Pool_SSL
                    Updated       = $Stat.Updated
                    PoolFee       = $_.fee
                    DataWindow    = $DataWindow
                    Workers       = $Pool_RequestWorkers.data
                    Hashrate      = $Stat.HashRate_Live
                    EthMode       = if ($Pool_Algorithm_Norm -match "^(Ethash|ProgPow)") {"ethproxy"} else {$null}
                }
                $Pool_SSL = $true
            }
        }
    }
}
