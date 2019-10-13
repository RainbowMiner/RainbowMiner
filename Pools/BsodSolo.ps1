using module ..\Include.psm1

param(
    [PSCustomObject]$Wallets,
    [PSCustomObject]$Params,
    [alias("WorkerName")]
    [String]$Worker,
    [TimeSpan]$StatSpan,
    [String]$DataWindow = "average-2",
    [Bool]$InfoOnly = $false,
    [Bool]$AllowZero = $false,
    [String]$StatAverage = "Minute_10"
)

$Name = Get-Item $MyInvocation.MyCommand.Path | Select-Object -ExpandProperty BaseName

$Pool_Fee = 1.9

$Pool_Request = [PSCustomObject]@{}
$PoolCoins_Request = [PSCustomObject]@{}

try {
    $PoolCoins_Request = Invoke-RestMethodAsync "http://api.bsod.pw/api/currencies" -tag $Name -cycletime 120
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
    $Pool_Request = Invoke-RestMethodAsync "http://api.bsod.pw/api/status" -tag $Name -cycletime 120
}
catch {
    if ($Error.Count){$Error.RemoveAt(0)}
    Write-Log -Level Warn "Pool status API ($Name) has failed. "
}

[hashtable]$Pool_Algorithms = @{}
[hashtable]$Pool_RegionsTable = @{}

@("eu","us","asia","ru") | Foreach-Object {$Pool_RegionsTable.$_ = Get-Region $_}

$PoolCoins_Request | Get-Member -MemberType NoteProperty -ErrorAction Ignore | Select-Object -ExpandProperty Name | Where-Object {$Pool_CoinSymbol = $_;$Pool_Currency = if ($PoolCoins_Request.$Pool_CoinSymbol.symbol) {$PoolCoins_Request.$Pool_CoinSymbol.symbol} else {$Pool_CoinSymbol};$Pool_User = $Wallets.$Pool_Currency;($PoolCoins_Request.$_.hashrate_solo -gt 0 -or $AllowZero) -and $Pool_User -or $InfoOnly} | ForEach-Object {

    $Pool_Host = "bsod.pw"
    $Pool_Port = $PoolCoins_Request.$Pool_CoinSymbol.port
    $Pool_Algorithm = $PoolCoins_Request.$Pool_CoinSymbol.algo
    if (-not $Pool_Algorithms.ContainsKey($Pool_Algorithm)) {$Pool_Algorithms.$Pool_Algorithm = Get-Algorithm $Pool_Algorithm}
    $Pool_Algorithm_Norm = $Pool_Algorithms.$Pool_Algorithm
    $Pool_Coin = $PoolCoins_Request.$Pool_CoinSymbol.name
    $Pool_Key = "$($Pool_Algorithm)_$($Pool_CoinSymbol)".ToLower()
    $Pool_PoolFee = if ($PoolCoins_Request.$Pool_CoinSymbol.fees_solo -ne $null) {$PoolCoins_Request.$Pool_CoinSymbol.fees_solo} else {$Pool_Fee}
    $Pool_DataWindow = $DataWindow

    if ($Pool_Algorithm_Norm -ne "Equihash" -and $Pool_Algorithm_Norm -like "Equihash*") {$Pool_Algorithm_All = @($Pool_Algorithm_Norm,"$Pool_Algorithm_Norm-$Pool_Currency")} else {$Pool_Algorithm_All = @($Pool_Algorithm_Norm)}

    #$Divisor = 1e9 * [Double]$Pool_Request.$Pool_Algorithm.mbtc_mh_factor

    $Pool_Factor = [Double]$(switch ($Pool_Algorithm) {
        "blake2s" {1000}
        "sha256d" {1000}
        default {1}
    })

    $Pool_TSL = $PoolCoins_Request.$Pool_CoinSymbol.timesincelast_solo
    $Pool_BLK = $PoolCoins_Request.$Pool_CoinSymbol."24h_blocks_solo"

    if (-not $InfoOnly) {
        if ($Pool_Request -and $Pool_Request.$Pool_Key) {
            $NewStat = $false; if (-not (Test-Path "Stats\Pools\$($Name)_$($Pool_CoinSymbol)_Profit.txt")) {$NewStat = $true; $DataWindow = "estimate_last24h"}
            $Pool_Price = Get-YiiMPValue $Pool_Request.$Pool_Key -DataWindow $DataWindow -Factor $Pool_Factor
            $Stat = Set-Stat -Name "$($Name)_$($Pool_CoinSymbol)_Profit" -Value $Pool_Price -Duration $(if ($NewStat) {New-TimeSpan -Days 1} else {$StatSpan}) -ChangeDetection $(-not $NewStat) -Actual24h $($Pool_Request.$_.actual_last24h/1000) -Estimate24h $($Pool_Request.$_.estimate_last24h) -HashRate $PoolCoins_Request.$Pool_CoinSymbol.hashrate_solo -BlockRate $Pool_BLK -Quiet
        } else {
            $Divisor = $Pool_Factor * 1e9
            $Stat = Set-Stat -Name "$($Name)_$($Pool_CoinSymbol)_Profit" -Value ([Double]$PoolCoins_Request.$Pool_CoinSymbol.estimate / $Divisor) -Duration $StatSpan -ChangeDetection $true -HashRate $PoolCoins_Request.$Pool_CoinSymbol.hashrate_solo -BlockRate $PoolCoins_Request.$Pool_CoinSymbol."24h_blocks_solo" -Quiet
            $Pool_DataWindow = $null
        }
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
                Host          = "$($Pool_Region).bsod.pw"
                Port          = $Pool_Port
                User          = "$($Pool_User).{workername:$Worker}"
                Pass          = "m=solo,c=$Pool_Currency{diff:,d=`$difficulty}$Pool_Params"
                Region        = $Pool_RegionsTable.$Pool_Region
                SSL           = $false
                Updated       = $Stat.Updated
                PoolFee       = $Pool_PoolFee
                DataWindow    = $Pool_DataWindow
                Workers       = $PoolCoins_Request.$Pool_CoinSymbol.workers_solo
                Hashrate      = $Stat.HashRate_Live
                BLK           = $Stat.BlockRate_Average
                TSL           = $Pool_TSL
				ErrorRatio    = $Stat.ErrorRatio
                Failover      = @($Pool_RegionsTable.Keys | Where-Object {$_ -ne $Pool_Region} | Foreach-Object {
                    [PSCustomObject]@{
                        Protocol      = "stratum+tcp"
                        Host          = "$($_).bsod.pw"
                        Port          = $Pool_Port
                        User          = "$($Pool_User).{workername:$Worker}"
                        Pass          = "m=solo,c=$Pool_Currency{diff:,d=`$difficulty}"
                    }
                })
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
