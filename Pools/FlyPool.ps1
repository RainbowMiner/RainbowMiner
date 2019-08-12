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
    [PSCustomObject]@{regions = @("asia","eu","us"); host = "1-zcash.flypool.org"; rpc = "api-zcash.flypool.org"; coin = "Zcash"; algo = "Equihash";     symbol = "ZEC"; port = 3443; fee = 1; divisor = 1;       ssl = $true;  protocol = "stratum+ssl"}
    [PSCustomObject]@{regions = @("asia","eu","us"); host = "1-ycash.flypool.org"; rpc = "api-ycash.flypool.org"; coin = "Ycash"; algo = "Equihash24x7"; symbol = "YEC"; port = 3333; fee = 1; divisor = 1;       ssl = $true;  protocol = "stratum+ssl"}
)

$Pool_Currencies = $Pools_Data.symbol | Select-Object -Unique | Where-Object {$Wallets.$_ -or $InfoOnly}
if (-not $Pool_Currencies -and -not $InfoOnly) {return}

$Pools_Data | Where-Object {$Wallets."$($_.symbol)" -or $InfoOnly} | ForEach-Object {
    $Pool_Port = $_.port
    $Pool_Algorithm = $_.algo
    $Pool_Algorithm_Norm = Get-Algorithm $_.algo
    $Pool_Currency = $_.symbol

    $Pool_Request = [PSCustomObject]@{}
    try {
        $Pool_Request = Invoke-RestMethodAsync "https://$($_.rpc)/poolStats" -tag $Name -cycletime 120
        if ($Pool_Request.status -ne "OK") {throw}
    }
    catch {
        if ($Error.Count){$Error.RemoveAt(0)}
        Write-Log -Level Warn "Pool API ($Name) has failed. "
    }
    
    if ($Pool_Algorithm_Norm -ne "Equihash" -and $Pool_Algorithm_Norm -like "Equihash*") {$Pool_Algorithm_All = @($Pool_Algorithm_Norm,"$Pool_Algorithm_Norm-$Pool_Currency")} else {$Pool_Algorithm_All = @($Pool_Algorithm_Norm)}

    $Pool_TSL = if ($Pool_Request.data.minedBlocks) {(Get-UnixTimestamp)-($Pool_Request.data.minedBlocks.time | Measure-Object -Maximum).Maximum}

    if (-not $InfoOnly) {
        $Stat = Set-Stat -Name "$($Name)_$($Pool_Currency)_Profit" -Value 0 -Duration $StatSpan -ChangeDetection $false -HashRate $Pool_Request.data.poolStats.hashRate -BlockRate (24*$Pool_Request.data.poolStats.blocksPerHour) -Quiet
    }

    foreach($Pool_Region in $_.regions) {
        foreach($Pool_Algorithm_Norm in $Pool_Algorithm_All) {
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
                Wallet        = $Wallets.$Pool_Currency
                Worker        = "{workername:$Worker}"
                Pass          = "x"
                Region        = $Pool_RegionsTable.$Pool_Region
                SSL           = $_.ssl
                Updated       = (Get-Date).ToUniversalTime()
                PoolFee       = $_.fee
                DataWindow    = $DataWindow
                Workers       = $Pool_Request.data.poolStats.workers
                Hashrate      = $Stat.HashRate_Live
                TSL           = $Pool_TSL
                BLK           = $Stat.BlockRate_Average
                WTM           = $true
                EthMode       = if ($Pool_Algorithm_Norm -match "^(Ethash|ProgPow)") {"qtminer"} else {$null}
            }
        }
    }
}
