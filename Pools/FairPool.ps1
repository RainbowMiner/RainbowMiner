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

$Pool_Region_Default = Get-Region "eu"

$Pools_Data = @(
    [PSCustomObject]@{symbol = "LTHN"; port = 6070; fee = 1.0; rpc = "lethean"; user="%wallet%+%worker%"}
    [PSCustomObject]@{symbol = "LOKI"; port = 5577; fee = 1.0; rpc = "loki";    user="%wallet%+%worker%"}
    [PSCustomObject]@{symbol = "MSR";  port = 6060; fee = 1.0; rpc = "msr";     user="%wallet%+%worker%"}
    [PSCustomObject]@{symbol = "QRL";  port = 7000; fee = 1.0; rpc = "qrl";     user="%wallet%+%worker%"}
    [PSCustomObject]@{symbol = "RYO";  port = 5555; fee = 1.0; rpc = "ryo";     user="%wallet%+%worker%"}
    [PSCustomObject]@{symbol = "TUBE"; port = 6040; fee = 1.0; rpc = "tube";    user="%wallet%+%worker%"}
    [PSCustomObject]@{symbol = "XWP";  port = 6080; fee = 1.0; rpc = "xfh";     user="%wallet%+%worker%"; divisor = 32}
    [PSCustomObject]@{symbol = "WOW";  port = 6090; fee = 1.0; rpc = "wow";     user="%wallet%+%worker%"}
    [PSCustomObject]@{symbol = "XHV";  port = 5566; fee = 1.0; rpc = "xhv";     user="%wallet%+%worker%"}
    [PSCustomObject]@{symbol = "XTNC"; port = 7010; fee = 1.0; rpc = "xtnc";    user="%wallet%+%worker%"}

    [PSCustomObject]@{symbol = "DOGX"; port = 7788; fee = 1.0; rpc = "dogx";    user="%wallet%.%worker%"}
    [PSCustomObject]@{symbol = "ETC";  port = 4444; fee = 1.0; rpc = "etc";     user="%wallet%.%worker%"}
    [PSCustomObject]@{symbol = "ETP";  port = 6666; fee = 1.0; rpc = "etp";     user="%wallet%.%worker%"}
    [PSCustomObject]@{symbol = "NUKO"; port = 7777; fee = 1.0; rpc = "nuko";    user="%wallet%.%worker%"}
    [PSCustomObject]@{symbol = "PGC";  port = 1111; fee = 1.0; rpc = "pgc";     user="%wallet%.%worker%"}

    [PSCustomObject]@{symbol = "ZANO"; port = 7020; fee = 1.0; rpc = "zano";    user="%wallet%.%worker%"}
)

$Pool_Delay = 0

$Pools_Data | Where-Object {$Wallets."$($_.symbol)" -or $InfoOnly} | ForEach-Object {
    $Pool_Coin     = Get-Coin $_.symbol
    $Pool_Currency = $_.symbol
    $Pool_RpcPath = $_.rpc.ToLower()
    $Pool_Algorithm_Norm = Get-Algorithm $Pool_Coin.Algo
    $Pool_Divisor = if ($_.divisor) {$_.divisor} else {1}

    $Pool_Port = $_.port
    $Pool_Fee  = $_.fee
    $Pool_User = $_.user

    $Pool_Request = [PSCustomObject]@{}

    $ok = $true
    if (-not $InfoOnly) {
        try {
            $Pool_Request = Invoke-RestMethodAsync "https://$($Pool_RpcPath).fairpool.xyz/api/poolStats" -tag $Name -timeout 15 -cycletime 180 -delay $Pool_Delay
            $Pool_Delay += 100
        }
        catch {
            if ($Error.Count){$Error.RemoveAt(0)}
            Write-Log -Level Warn "Pool API ($Name) for $Pool_Currency has failed. "
            $ok = $false
        }
    }

    if ($ok -and $Pool_Port -and -not $InfoOnly) {
        $Pool_BLK = if ($Pool_Request.blockTime) {24*3600 / $Pool_Request.blockTime} else {0}
        $Pool_TSL = [int](Get-UnixTimestamp) - [int]$Pool_Request.lastBlock
    
        $Stat = Set-Stat -Name "$($Name)_$($Pool_Currency)_Profit" -Value ([Double]$Pool_Request.profitBtc) -Duration $StatSpan -ChangeDetection $false -HashRate ([int64]$Pool_Request.pool) -BlockRate $Pool_BLK -Quiet
    }
    
    if (($ok -and $Pool_Port -and ($AllowZero -or [int64]$Pool_Request.pool -gt 0)) -or $InfoOnly) {
        $Pool_Wallet = Get-WalletWithPaymentId $Wallets.$Pool_Currency -pidchar '.' -asobject
        [PSCustomObject]@{
            Algorithm     = $Pool_Algorithm_Norm
            CoinName      = $Pool_Coin.Name
            CoinSymbol    = $Pool_Currency
            Currency      = $Pool_Currency
            Price         = $Stat.$StatAverage #instead of .Live
            StablePrice   = $Stat.Week
            MarginOfError = $Stat.Week_Fluctuation
            Protocol      = "stratum+tcp"
            Host          = "mine.$($Pool_RpcPath).fairpool.xyz"
            Port          = $_.port
            Ports         = $Pool_Ports
            User          = $Pool_User -replace '%wallet%',$Pool_Wallet.wallet -replace '%worker%',"{workername:$Worker}"
            Pass          = if ($Pool_Wallet.difficulty) {$Pool_Wallet.difficulty} else {"x"}
            Region        = $Pool_Region_Default
            SSL           = $False
            Updated       = $Stat.Updated
            PoolFee       = $Pool_Fee
            Workers       = $Pool_Request.workers
            Hashrate      = $Stat.HashRate_Live
            TSL           = $Pool_TSL
            BLK           = $Stat.BlockRate_Average
            EthMode       = if ($Pool_Algorithm_Norm -match "^(Ethash|ProgPow)") {"ethproxy"} else {$null}
            AlgorithmList = if ($Pool_Algorithm_Norm -match "-") {@($Pool_Algorithm_Norm, ($Pool_Algorithm_Norm -replace '\-.*$'))}else{@($Pool_Algorithm_Norm)}
            Name          = $Name
            Penalty       = 0
            PenaltyFactor = 1
            Wallet        = $Pool_Wallet.wallet
            Worker        = "{workername:$Worker}"
            Email         = $Email
        }
    }
}
