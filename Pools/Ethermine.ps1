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

[hashtable]$Pool_RegionsTable = @{}
@("eu","us","asia") | Foreach-Object {$Pool_RegionsTable.$_ = Get-Region $_}

$Pools_Data = @(
    [PSCustomObject]@{regions = @("eu","us");        host = "1-etc.ethermine.org"; coin = "EthereumClassic"; algo = "Ethash";   symbol = "ETC"; port = 4444; fee = 1; divisor = 1000000; ssl = $false; protocol = "stratum+tcp"}
    [PSCustomObject]@{regions = @("asia","eu","us"); host = "1.ethermine.org";     coin = "Ethereum";        algo = "Ethash";   symbol = "ETH"; port = 4444; fee = 1; divisor = 1000000; ssl = $false; protocol = "stratum+tcp"}
    [PSCustomObject]@{regions = @("asia","eu","us"); host = "1-zcash.flypool.org"; coin = "Zcash";           algo = "Equihash"; symbol = "ZEC"; port = 3443; fee = 1; divisor = 1;       ssl = $true;  protocol = "stratum+ssl"}
)

$Pool_Currencies = $Pools_Data.symbol | Select-Object -Unique | Where-Object {$Wallets.$_ -or $InfoOnly}
if (-not $Pool_Currencies -and -not $InfoOnly) {return}

$Pools_Data | Where-Object {$Wallets."$($_.symbol)" -or $InfoOnly} | ForEach-Object {
    $Pool_Port = $_.port
    $Pool_Algorithm = $_.algo
    $Pool_Algorithm_Norm = Get-Algorithm $_.algo
    $Pool_Currency = $_.symbol

    foreach($Pool_Region in $_.regions) {
        [PSCustomObject]@{
            Algorithm     = $Pool_Algorithm_Norm
            CoinName      = $_.coin
            CoinSymbol    = $Pool_Currency
            Currency      = $Pool_Currency
            Price         = 0
            StablePrice   = 0
            MarginOfError = 0
            Protocol      = $_.protocol
            Host          = "$($Pool_Region)$($_.host)"
            Port          = $_.port
            User          = "$($Wallets.$Pool_Currency).{workername:$Worker}"
            Pass          = "x"
            Region        = $Pool_RegionsTable.$Pool_Region
            SSL           = $_.ssl
            Updated       = (Get-Date).ToUniversalTime()
            PoolFee       = $_.fee
            DataWindow    = $DataWindow
            WTM           = $true
            EthMode       = if ($Pool_Algorithm_Norm -match "^(Ethash|ProgPow)") {"qtminer"} else {$null}
        }
    }
}
