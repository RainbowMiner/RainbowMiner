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
    [String]$PartyPassword = ""
)

$Name = Get-Item $MyInvocation.MyCommand.Path | Select-Object -ExpandProperty BaseName

$Pool_Fee = 0.9

if (-not $PartyPassword -and -not $InfoOnly) {return}

$Pool_Request = [PSCustomObject]@{}
$PoolCoins_Request = [PSCustomObject]@{}

try {
    $PoolCoins_Request = Invoke-RestMethodAsync "https://www.gos.cx/api/currencies" -tag $Name -cycletime 120
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

try {
    $Pool_Request = Invoke-RestMethodAsync "https://www.gos.cx/api/status" -tag $Name -cycletime 120
}
catch {
    if ($Error.Count){$Error.RemoveAt(0)}
    Write-Log -Level Warn "Pool status API ($Name) has failed. "
}

[hashtable]$Pool_Algorithms = @{}
[hashtable]$Pool_RegionsTable = @{}

@("ru","eu","us","asia") | Foreach-Object {$Pool_RegionsTable.$_ = Get-Region $_}

$PoolCoins_Request | Get-Member -MemberType NoteProperty -ErrorAction Ignore | Select-Object -ExpandProperty Name | Where-Object {$Pool_CoinSymbol = $_;$Pool_Currency = $Pool_CoinSymbol -replace '-.+$';$Pool_User = $Wallets.$Pool_Currency;($PoolCoins_Request.$_.hashrate_solo -gt 0 -or $AllowZero) -and $Pool_User -or $InfoOnly} | ForEach-Object {
    $Pool_Port = $PoolCoins_Request.$Pool_CoinSymbol.port
    $Pool_Algorithm = $PoolCoins_Request.$Pool_CoinSymbol.algo
    if (-not $Pool_Algorithms.ContainsKey($Pool_Algorithm)) {$Pool_Algorithms.$Pool_Algorithm = Get-Algorithm $Pool_Algorithm}
    $Pool_Algorithm_Norm = $Pool_Algorithms.$Pool_Algorithm
    $Pool_Coin = $PoolCoins_Request.$Pool_CoinSymbol.name
    $Pool_PoolFee = if ($PoolCoins_Request.$Pool_CoinSymbol.fee_solo -ne $null) {$PoolCoins_Request.$Pool_CoinSymbol.fee_solo} else {$Pool_Fee}

    if ($Pool_Algorithm_Norm -ne "Equihash" -and $Pool_Algorithm_Norm -like "Equihash*") {$Pool_Algorithm_All = @($Pool_Algorithm_Norm,"$Pool_Algorithm_Norm-$Pool_Currency")} else {$Pool_Algorithm_All = @($Pool_Algorithm_Norm)}

    $Divisor = 1e9

    $Pool_Price = [Double]$PoolCoins_Request.$Pool_CoinSymbol.estimate
    if ($Pool_Price -eq 0 -and [Int64]$PoolCoins_Request.$Pool_CoinSymbol.block_reward -gt 0 -and [Int64]$PoolCoins_Request.$Pool_CoinSymbol.difficulty -gt 0 -and [Double]$PoolCoins_Request.$Pool_CoinSymbol."24h_blocks" -gt 0) {
        $Pool_Price = 20116.56761169 / [Int64]$PoolCoins_Request.$Pool_CoinSymbol.difficulty * [Double]$PoolCoins_Request.$Pool_CoinSymbol."24h_btc" / [Double]$PoolCoins_Request.$Pool_CoinSymbol."24h_blocks";
        if (@("sha256","sha256t","blake","blakecoin","blake2s","decred","keccak","keccakc","lbry","vanilla") -icontains $Pool_Algorithm) {$Pool_Price /= 1000}
    }

    $Pool_TSL = $PoolCoins_Request.$Pool_CoinSymbol.timesincelast_solo

    if (-not $InfoOnly) {
        $Stat = Set-Stat -Name "$($Name)_$($Pool_CoinSymbol)_Profit" -Value ($Pool_Price / $Divisor) -Duration $StatSpan -ChangeDetection $false -HashRate $PoolCoins_Request.$Pool_CoinSymbol.hashrate_solo -BlockRate $PoolCoins_Request.$Pool_CoinSymbol."24h_blocks_solo" -Quiet
    }

    $Pool_Params = if ($Params.$Pool_Currency) {",$($Params.$Pool_Currency)"}

    foreach($Pool_Region in $Pool_RegionsTable.Keys) {
        foreach($Pool_Algorithm_Norm in $Pool_Algorithm_All) {
            [PSCustomObject]@{
                Algorithm     = $Pool_Algorithm_Norm
                CoinName      = $Pool_Coin
                CoinSymbol    = $Pool_CoinSymbol
                Currency      = $Pool_Currency
                Price         = $Stat.$StatAverage #instead of .Live
                StablePrice   = $Stat.Week
                MarginOfError = $Stat.Week_Fluctuation
                Protocol      = "stratum+tcp"
                Host          = "$($Pool_Region).gos.cx"
                Port          = $Pool_Port
                User          = "$($Pool_User).{workername:$Worker}"
                Pass          = "m=party.$PartyPassword{diff:,d=`$difficulty}$Pool_Params"
                Region        = $Pool_RegionsTable.$Pool_Region
                SSL           = $false
                Updated       = $Stat.Updated
                PoolFee       = $Pool_PoolFee
                Workers       = $PoolCoins_Request.$Pool_CoinSymbol.workers
                Hashrate      = $Stat.HashRate_Live
                BLK           = $Stat.BlockRate_Average
                TSL           = $Pool_TSL
                AlgorithmList = if ($Pool_Algorithm_Norm -match "-") {@($Pool_Algorithm_Norm, ($Pool_Algorithm_Norm -replace '\-.*$'))}else{@($Pool_Algorithm_Norm)}
                Name          = $Name
                Penalty       = 0
                PenaltyFactor = 1
                Wallet        = $Pool_User
                Worker        = "{workername:$Worker}"
                Email         = $Email
            }
        }
    }
}
