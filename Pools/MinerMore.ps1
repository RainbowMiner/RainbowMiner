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

$Pool_Fee = 1.0

$PoolCoins_Request = [PSCustomObject]@{}
try {
    $PoolCoins_Request = Invoke-RestMethodAsync "https://minermore.com/api/currencies" -tag $Name -cycletime 120
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

[hashtable]$Pool_Algorithms = @{}

[hashtable]$Pool_RegionsTable = @{}
@("us","eu","hk","east.us","west.us","ca") | Foreach-Object {$Pool_RegionsTable.$_ = Get-Region $(if ($_ -match '^(.+)\.(.+)$') {"$($Matches[2])$($Matches[1])"} else {$_})}

$Pool_Coins = [PSCustomObject]@{
    HTH  = [PSCustomObject]@{port = 4515; fee = 1.0; rpc="hth";      regions=@("us")}
    MYNT = [PSCustomObject]@{port = 4548; fee = 1.0; rpc="mynt";     regions=@("us")}
    PEXA = [PSCustomObject]@{port = 4553; fee = 1.0; rpc="pexa";     regions=@("us")}
    PGN  = [PSCustomObject]@{port = 4517; fee = 1.0; rpc="pgn";      regions=@("us")}
    RITO = [PSCustomObject]@{port = 4545; fee = 1.0; rpc="rito";     regions=@("us","eu")}
    RVN  = [PSCustomObject]@{port = 4501; fee = 1.0; rpc="rvn";      regions=@("us","eu","hk","east.us","west.us","ca"); algo = "X16rv2"}
    RVNt = [PSCustomObject]@{port = 4505; fee = 1.0; rpc="rvnt";     regions=@("us"); algo = "X16rv2"}
    SAFE = [PSCustomObject]@{port = 4503; fee = 1.0; rpc="safe";     regions=@("us")}
    STONE= [PSCustomObject]@{port = 4518; fee = 1.0; rpc="pool";     regions=@("us")}
    VDL  = [PSCustomObject]@{port = 4547; fee = 1.0; rpc="vdl";      regions=@("us")}
    XMG  = [PSCustomObject]@{port = 4537; fee = 1.0; rpc="xmg";      regions=@("us")}
    XRD  = [PSCustomObject]@{port = 4552; fee = 1.0; rpc="xrd";      regions=@("us")}
    YEC  = [PSCustomObject]@{port = 4550; fee = 1.0; rpc="yec";      regions=@("us")}
    YTN  = [PSCustomObject]@{port = 4543; fee = 1.0; rpc="ytn";      regions=@("us")}
}

$PoolCoins_Request | Get-Member -MemberType NoteProperty -ErrorAction Ignore | Select-Object -ExpandProperty Name | Where-Object {$Pool_CoinSymbol = $_;$Pool_Currency = if ($PoolCoins_Request.$Pool_CoinSymbol.symbol) {$PoolCoins_Request.$Pool_CoinSymbol.symbol} else {$Pool_CoinSymbol};$Pool_User = $Wallets.$Pool_Currency;($PoolCoins_Request.$_.hashrate -gt 0 -or $AllowZero) -and $Pool_User -or $InfoOnly} | ForEach-Object {

    $Pool_Coin = $Pool_Coins.$Pool_CoinSymbol

    $Pool_Host      = "$(if ($Pool_Coin.rpc -ne $null) {$Pool_Coin.rpc} else {$Pool_CoinSymbol.ToLower()}).minermore.com"
    $Pool_Port      = if ($Pool_Coin.port) {$Pool_Coin.port} else {$PoolCoins_Request.$Pool_CoinSymbol.port}
    $Pool_PoolFee   = if ($Pool_Coin.fee -ne $null) {$Pool_Coin.fee} else {$Pool_Fee}
    $Pool_Regions   = if ($Pool_Coin.regions) {$Pool_Coin.regions} else {@("us")}

    $Pool_Algorithm = if ($Pool_Coin.algo) {$Pool_Coin.algo} else {$PoolCoins_Request.$Pool_CoinSymbol.algo}
    $Pool_CoinName  = $PoolCoins_Request.$Pool_CoinSymbol.name

    if ($Pool_Algorithm -eq "equihash") {
        $Pool_Algorithm = Switch ($Pool_CoinSymbol) {
            "SAFE" {"Equihash24x7"}
            "VDL"  {"Equihash24x7"}
            "XSG"  {"Equihash24x5"}
            "YEC"  {"Equihash24x7"}
            default {"Equihash24x7"}
        }
    }
    if (-not $Pool_Algorithms.ContainsKey($Pool_Algorithm)) {$Pool_Algorithms.$Pool_Algorithm = Get-Algorithm $Pool_Algorithm}
    $Pool_Algorithm_Norm = $Pool_Algorithms.$Pool_Algorithm

    if ($Pool_Algorithm_Norm -ne "Equihash" -and $Pool_Algorithm_Norm -like "Equihash*") {$Pool_Algorithm_All = @($Pool_Algorithm_Norm,"$Pool_Algorithm_Norm-$Pool_Currency")} else {$Pool_Algorithm_All = @($Pool_Algorithm_Norm)}

    $Pool_TSL = (Get-UnixTimestamp)-$PoolCoins_Request.$Pool_CoinSymbol.timesincelast

    if (-not $InfoOnly) {
        $Stat = Set-Stat -Name "$($Name)_$($Pool_CoinSymbol)_Profit" -Value 0 -Duration $StatSpan -ChangeDetection $false -HashRate $PoolCoins_Request.$Pool_CoinSymbol.hashrate -BlockRate $PoolCoins_Request.$Pool_CoinSymbol."24h_blocks" -Quiet
    }

    foreach($Pool_Region in $Pool_Regions) {
        foreach($Pool_Algorithm_Norm in $Pool_Algorithm_All) {
            [PSCustomObject]@{
                Algorithm     = $Pool_Algorithm_Norm
                CoinName      = $Pool_CoinName
                CoinSymbol    = $Pool_CoinSymbol
                Currency      = $Pool_Currency
                Price         = 0
                StablePrice   = 0
                MarginOfError = 0
                Protocol      = "stratum+tcp"
                Host          = "$(if ($Pool_Regions.Count -gt 1) {"$($Pool_Region)."})$($Pool_Host)"
                Port          = $Pool_Port
                User          = "$($Pool_User).{workername:$Worker}"
                Pass          = "x{diff:,d=`$difficulty}"
                Region        = $Pool_RegionsTable.$Pool_Region
                SSL           = $false
                Updated       = (Get-Date).ToUniversalTime()
                PoolFee       = $Pool_PoolFee
                Workers       = $PoolCoins_Request.$Pool_CoinSymbol.workers
                Hashrate      = $Stat.HashRate_Live
                BLK           = $Stat.BlockRate_Average
                TSL           = $Pool_TSL
                WTM           = $true
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
