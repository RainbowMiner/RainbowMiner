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
@("us","eu","asia","east.us","west.us","ca") | Foreach-Object {$Pool_RegionsTable.$_ = Get-Region $(if ($_ -match '^(.+)\.(.+)$') {"$($Matches[2])$($Matches[1])"} else {$_})}

$Pool_Coins = [PSCustomObject]@{
    MYNT = [PSCustomObject]@{port = 4548; fee = 1.0; rpc="mynt";     regions=@("us")}
    PGN  = [PSCustomObject]@{port = 4517; fee = 1.0; rpc="pgn";      regions=@("us")}
    RITO = [PSCustomObject]@{port = 4545; fee = 1.0; rpc="rito";     regions=@("us","eu","asia")}
    RVN  = [PSCustomObject]@{port = 4501; fee = 1.0; rpc="rvn";      regions=@("us","eu","asia","east.us","west.us","ca")}
    RVNt = [PSCustomObject]@{port = 4505; fee = 1.0; rpc="rvnt";     regions=@("us")}
    SAFE = [PSCustomObject]@{port = 4503; fee = 0.0; rpc="safe";     regions=@("us")}
    VDL  = [PSCustomObject]@{port = 4547; fee = 1.0; rpc="vdl";      regions=@("us")}
    XSG  = [PSCustomObject]@{port = 4508; fee = 0.0; rpc="xsg";      regions=@("us")}
}

$PoolCoins_Request | Get-Member -MemberType NoteProperty -ErrorAction Ignore | Select-Object -ExpandProperty Name | Where-Object {$Pool_CoinSymbol = $_;$Pool_Currency = if ($PoolCoins_Request.$Pool_CoinSymbol.symbol) {$PoolCoins_Request.$Pool_CoinSymbol.symbol} else {$Pool_CoinSymbol};$Pool_User = $Wallets.$Pool_Currency;$Pool_User -or $InfoOnly} | ForEach-Object {

    $Pool_CoinData  = $Pool_Coins.$Pool_CoinSymbol
    $Pool_Coin      = Get-Coin $Pool_CoinSymbol

    $Pool_Host      = "$(if ($Pool_CoinData.rpc -ne $null) {$Pool_CoinData.rpc} else {$Pool_CoinSymbol.ToLower()}).minermore.com"
    $Pool_Port      = if ($Pool_CoinData.port) {$Pool_CoinData.port} else {$PoolCoins_Request.$Pool_CoinSymbol.port}
    $Pool_PoolFee   = if ($Pool_CoinData.fee -ne $null) {$Pool_CoinData.fee} else {$Pool_Fee}
    $Pool_Regions   = if ($Pool_CoinData.regions) {$Pool_CoinData.regions} else {@("us")}

    $Pool_Algorithm = $Pool_Coin.Algo
    $Pool_CoinName  = $Pool_Coin.Name

    if (-not $Pool_Algorithms.ContainsKey($Pool_Algorithm)) {$Pool_Algorithms.$Pool_Algorithm = Get-Algorithm $Pool_Algorithm}
    $Pool_Algorithm_Norm = $Pool_Algorithms.$Pool_Algorithm

    $Pool_TSL = (Get-UnixTimestamp)-$PoolCoins_Request.$Pool_CoinSymbol.timesincelast

    if (-not $InfoOnly) {
        $Stat = Set-Stat -Name "$($Name)_$($Pool_CoinSymbol)_Profit" -Value 0 -Duration $StatSpan -ChangeDetection $false -HashRate $PoolCoins_Request.$Pool_CoinSymbol.hashrate -BlockRate $PoolCoins_Request.$Pool_CoinSymbol."24h_blocks" -Quiet
        if (-not $Stat.HashRate_Live -and -not $AllowZero) {return}
    }

    foreach($Pool_Region in $Pool_Regions) {
        [PSCustomObject]@{
            Algorithm     = $Pool_Algorithm_Norm
            Algorithm0    = $Pool_Algorithm_Norm
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
            EthMode       = if ($Pool_Algorithm_Norm -match "^(Ethash|ProgPow)") {"minerproxy"} elseif ($Pool_Algorithm_Norm -match "^(KawPOW)") {"stratum"} else {$null}
            Name          = $Name
            Penalty       = 0
            PenaltyFactor = 1
            Disabled      = $false
            HasMinerExclusions = $false
            Price_Bias    = 0.0
            Price_Unbias  = 0.0
            Wallet        = $Pool_User
            Worker        = "{workername:$Worker}"
            Email         = $Email
        }
    }
}
