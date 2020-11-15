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
    [String]$StatAverage = "Minute_10"
)

$Name = Get-Item $MyInvocation.MyCommand.Path | Select-Object -ExpandProperty BaseName

$Pool_Regions = @("us","eu","asia")

[hashtable]$Pool_RegionsTable = @{}
$Pool_Regions | Foreach-Object {$Pool_RegionsTable.$_ = Get-Region $_}

$Pools_Data = @(
    [PSCustomObject]@{symbol = "ETH";    port = @(1100); fee = 0.0; rpc = "eth-"}
    [PSCustomObject]@{symbol = "ETC";    port = @(5500); fee = 0.0; rpc = ""}
    [PSCustomObject]@{symbol = "XMR";    port = @(4400); fee = 0.0; rpc = ""}
    [PSCustomObject]@{symbol = "RVN";    port = @(6600); fee = 0.0; rpc = ""}
    [PSCustomObject]@{symbol = "BTG";    port = @(8800); fee = 0.0; rpc = ""}
    [PSCustomObject]@{symbol = "GRIN29"; port = @(7700); fee = 0.0; rpc = ""}
    [PSCustomObject]@{symbol = "XWP";    port = @(9900); fee = 0.0; rpc = ""}
)

$Pools_Data | Where-Object {$Pool_Currency = "$($_.symbol -replace "\d+$")";$Wallets.$Pool_Currency -or $InfoOnly} | ForEach-Object {

    $Pool_Coin      = Get-Coin $_.symbol
    $Pool_RpcPath   = $Pool_Data.rpc
    $Pool_Fee       = $_.fee
    $Pool_Ports     = $_.port
    $Pool_Wallet    = "$($Wallets.$Pool_Currency)"

    $Pool_Algorithm_Norm = Get-Algorithm $Pool_Coin.algo

    $Pool_Request = [PSCustomObject]@{}
    if (-not $InfoOnly) {
        try {
            $Pool_Request = Invoke-RestMethodAsync "https://hellominer.com/api/v1?currency=$Pool_Currency&command=PoolStats" -tag $Name -cycletime 300 -timeout 20 | ConvertFrom-Json -ErrorAction Stop
        }
        catch {
            if ($Error.Count){$Error.RemoveAt(0)}
        }

        $Stat = Set-Stat -Name "$($Name)_$($Pool_Currency)_Profit" -Value 0 -Duration $StatSpan -HashRate ($Pool_Request.Hashrate * $Pool_Request.HashrateMultiply) -ChangeDetection $false -Quiet
        if (-not $Stat.HashRate_Live -and -not $AllowZero) {return}
    }

    foreach($Pool_Region in $Pool_Regions) {
        $Pool_SSL = $false
        foreach($Pool_Port in $Pool_Ports) {
            [PSCustomObject]@{
                Algorithm     = $Pool_Algorithm_Norm
                Algorithm0    = $Pool_Algorithm_Norm
                CoinName      = $Pool_Coin.Name
                CoinSymbol    = $Pool_Currency
                Currency      = $Pool_Currency
                Price         = 0
                StablePrice   = 0
                MarginOfError = 0
                Protocol      = "stratum+$(if ($Pool_SSL) {"ssl"} else {"tcp"})"
                Host          = "$($Pool_RpcPath)$($Pool_Region)1.hellominer.com"
                Port          = $Pool_Port
                User          = "$($Pool_Wallet).{workername:$Worker}"
                Pass          = "x"
                Region        = $Pool_RegionsTable.$Pool_Region
                SSL           = $Pool_SSL
                Updated       = $Stat.Updated
                PoolFee       = $Pool_Request.PoolFee
                DataWindow    = $DataWindow
                Workers       = $Pool_Request.Miners
                Hashrate      = $Stat.HashRate_Live
                EthMode       = if ($Session.RegexAlgoHasEthproxy.Matches($Pool_Algorithm_Norm)) {"ethproxy"} elseif ($Pool_Algorithm_Norm -eq "KawPOW") {"stratum"} else {$null}
                WTM           = $true
                Name          = $Name
                Penalty       = 0
                PenaltyFactor = 1
                Disabled      = $false
                HasMinerExclusions = $false
                Price_Bias    = 0.0
                Price_Unbias  = 0.0
                Wallet        = $Pool_Wallet
                Worker        = "{workername:$Worker}"
                Email         = $Email
            }
            $Pool_SSL = $true
        }
    }
}
