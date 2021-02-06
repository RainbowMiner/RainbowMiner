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
    [String]$Email = ""
)

$Name = Get-Item $MyInvocation.MyCommand.Path | Select-Object -ExpandProperty BaseName

$Pool_Request = [PSCustomObject]@{}

[hashtable]$Pool_RegionsTable = @{}

$Pool_Regions = @("asia","eu","jp","us-east","us-west", "au")
$Pool_Regions | Foreach-Object {$Pool_RegionsTable.$_ = Get-Region $_}

$Pools_Data = @(
    [PSCustomObject]@{symbol = "ETC";  rpc = "etc";  port = @(19999,19433); fee = 1; divisor = 1e6; useemail = $false; usepid = $false}
    [PSCustomObject]@{symbol = "ETH";  rpc = "eth";  port = @(9999,9433);   fee = 1; divisor = 1e6; useemail = $false; usepid = $false}
    [PSCustomObject]@{symbol = "ZEC";  rpc = "zec";  port = @(6666,6633);   fee = 1; divisor = 1;   useemail = $false; usepid = $false}
    [PSCustomObject]@{symbol = "XMR";  rpc = "xmr";  port = @(14444,14433); fee = 1; divisor = 1;   useemail = $false; usepid = $true}
    [PSCustomObject]@{symbol = "RVN";  rpc = "rvn";  port = @(12222,12433); fee = 1; divisor = 1e6; useemail = $false; usepid = $false}
    [PSCustomObject]@{symbol = "CFX";  rpc = "cfx";  port = @(17777,17433); fee = 1; divisor = 1e6; useemail = $false; usepid = $false}
    [PSCustomObject]@{symbol = "ERG";  rpc = "ergo"; port = @(11111,11433); fee = 1; divisor = 1e6; useemail = $false; usepid = $false}
)

$Pools_Data | Where-Object {$Wallets."$($_.symbol)" -or $InfoOnly} | ForEach-Object {
    $Pool_Coin      = Get-Coin $_.symbol
    $Pool_Algorithm_Norm = Get-Algorithm $Pool_Coin.Algo
    $Pool_Currency = $_.symbol
    $Pool_Wallet = Get-WalletWithPaymentId $Wallets.$Pool_Currency -pidchar '.' -asobject
    if ($Pool_Currency -eq "PASC" -and -not $Pool_Wallet.paymentid) {$Pool_Wallet.wallet = "$($Pool_Wallet.wallet).0"}
    $Pool_EthProxy = if ($Pool_Algorithm_Norm -match $Global:RegexAlgoHasEthproxy) {"ethproxy"} elseif ($Pool_Algorithm_Norm -eq "KawPOW") {"stratum"} else {$null}

    $ok = $true
    if (-not $InfoOnly) {
        $Pool_Request = [PSCustomObject]@{}
        $Pool_RequestWorkers = [PSCustomObject]@{}
        $Pool_RequestHashrate = [PSCustomObject]@{}

        try {
            $Pool_Request = Invoke-RestMethodAsync "https://api.nanopool.org/v1/$($_.rpc)/approximated_earnings/1000" -tag $Name -retry 5 -retrywait 200 -cycletime 120
            if (-not $Pool_Request.status) {$ok = $false}
        }
        catch {
            if ($Error.Count){$Error.RemoveAt(0)}
            $ok = $false
        }
        if (-not $ok) {
            Write-Log -Level Warn "Pool API ($Name) for $($Pool_Currency) has failed. "
            return
        }

        try {
            $Pool_RequestWorkers   = Invoke-RestMethodAsync "https://api.nanopool.org/v1/$($_.rpc)/pool/activeworkers" -tag $Name -retry 5 -retrywait 200 -cycletime 120
            $Pool_RequestHashrate  = Invoke-RestMethodAsync "https://api.nanopool.org/v1/$($_.rpc)/pool/hashrate" -tag $Name -retry 5 -retrywait 200 -cycletime 120
            $Pool_RequestBlocks    = Invoke-RestMethodAsync "https://api.nanopool.org/v1/$($_.rpc)/pool/count_blocks/24" -tag $Name -retry 5 -retrywait 200 -cycletime 120
            $Pool_RequestLastBlock = Invoke-RestMethodAsync "https://api.nanopool.org/v1/$($_.rpc)/pool/recentblocks/1" -tag $Name -retry 5 -retrywait 200 -cycletime 120
        }
        catch {
            if ($Error.Count){$Error.RemoveAt(0)}
            Write-Log -Level Info "Pool second level API ($Name) for $($Pool_Currency) has failed. "
        }

        $Pool_TSL = (Get-UnixTimestamp) - $(if ($Pool_RequestLastBlock.status -eq "True" -and ($Pool_RequestLastBlock.data | Measure-Object).Count -eq 1) {$Pool_RequestLastBlock.data[0].date})

        if ($ok) {
            $Pool_ExpectedEarning = $(if ($Global:Rates.$Pool_Currency) {[double]$Pool_Request.data.day.coins / $Global:Rates.$Pool_Currency} else {[double]$Pool_Request.data.day.bitcoins}) / $_.divisor / 1000
            $Stat = Set-Stat -Name "$($Name)_$($Pool_Currency)_Profit" -Value $Pool_ExpectedEarning -Duration $StatSpan -Hashrate ([double]$Pool_RequestHashrate.data * $_.divisor) -BlockRate $Pool_RequestBlocks.data.count -ChangeDetection $true -Quiet
            if (-not $Stat.HashRate_Live -and -not $AllowZero) {return}
        }
    }

    if ($ok) {
        foreach($Pool_Region in $Pool_Regions) {
            $Pool_SSL = $false
            foreach($Pool_Port in @($_.port | Select-Object)) {
                [PSCustomObject]@{
                    Algorithm     = $Pool_Algorithm_Norm
					Algorithm0    = $Pool_Algorithm_Norm
                    CoinName      = $Pool_Coin.Name
                    CoinSymbol    = $Pool_Currency
                    Currency      = $Pool_Currency
                    Price         = $Stat.$StatAverage #instead of .Live
                    StablePrice   = $Stat.Week
                    MarginOfError = $Stat.Week_Fluctuation
                    Protocol      = "stratum+$(if ($Pool_SSL) {"ssl"} else {"tcp"})"
                    Host          = "$($_.rpc)-$($Pool_Region)1.nanopool.org"
                    Port          = $Pool_Port
                    User          = "$($Pool_Wallet.wallet).{workername:$Worker}$(if ($_.useemail -and $Email) {"/$($Email)"})"
                    Pass          = "x"
                    Region        = $Pool_RegionsTable.$Pool_Region
                    SSL           = $Pool_SSL
                    Updated       = $Stat.Updated
                    PoolFee       = $_.fee
                    DataWindow    = $DataWindow
                    Workers       = $Pool_RequestWorkers.data
                    Hashrate      = $Stat.HashRate_Live
                    TSL           = $Pool_TSL
                    BLK           = $Stat.BlockRate_Average
                    EthMode       = $Pool_EthProxy
                    Name          = $Name
                    Penalty       = 0
                    PenaltyFactor = 1
					Disabled      = $false
					HasMinerExclusions = $false
					Price_Bias    = 0.0
					Price_Unbias  = 0.0
                    Wallet        = $Pool_Wallet.wallet
                    Worker        = "{workername:$Worker}"
                    Email         = $Email
                }
                $Pool_SSL = $true
            }
        }
    }
}
