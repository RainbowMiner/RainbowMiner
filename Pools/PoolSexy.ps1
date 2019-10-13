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

$Pools_Data = @(
    [PSCustomObject]@{symbol = "AKA";   port = 20022; fee = 0.5;  rpc = "aka"}
    [PSCustomObject]@{symbol = "CLO";   port = 20052; fee = 0.5;  rpc = "clo"}
    [PSCustomObject]@{symbol = "DBIX";  port = 10032; fee = 0.25; rpc = "dbix"}
    [PSCustomObject]@{symbol = "ELLA";  port = 10082; fee = 0.25; rpc = "ella"}
    [PSCustomObject]@{symbol = "ETC";   port = 10042; fee = 0.5;  rpc = "etc"}
    [PSCustomObject]@{symbol = "ETCC";  port = 20062; fee = 0.5;  rpc = "etcc"}
    [PSCustomObject]@{symbol = "ETHO";  port = 20032; fee = 0.5;  rpc = "etho"}
    [PSCustomObject]@{symbol = "GOL";   port = 20012; fee = 0.25; rpc = "gol"}
    [PSCustomObject]@{symbol = "MOAC";  port = 10092; fee = 0.25; rpc = "moac"}
    [PSCustomObject]@{symbol = "MUSIC"; port = 10012; fee = 0.25; rpc = "music"}
    [PSCustomObject]@{symbol = "PIRL";  port = 10052; fee = 0.25; rpc = "pirl"}
    [PSCustomObject]@{symbol = "ROL";   port = 10022; fee = 0.5;  rpc = "rol"}
    [PSCustomObject]@{symbol = "UBQ";   port = 20042; fee = 0.25; rpc = "ubq"}
    [PSCustomObject]@{symbol = "VIC";   port = 10062; fee = 0.25; rpc = "vic"}
)

$Pools_Data | Where-Object {$Wallets."$($_.symbol)" -or $InfoOnly} | ForEach-Object {
    $Pool_Coin      = Get-Coin $_.symbol
    $Pool_Currency  = $_.symbol
    $Pool_RpcPath   = $_.rpc.ToLower()
    $Pool_Algorithm_Norm = Get-Algorithm $Pool_Coin.Algo

    $Pool_Port      = $_.port
    $Pool_Fee       = $_.fee

    $ok = $false

    if (-not $InfoOnly) {
        $Pool_Request = [PSCustomObject]@{}
        $Pool_RequestBlocks = [PSCustomObject]@{}
        
        try {
            $Pool_Request = Invoke-RestMethodAsync "http://mining-$($Pool_RpcPath).pool.sexy/api/stats" -tag $Name -cycletime 120
            $Pool_RequestBlocks = Invoke-RestMethodAsync "http://mining-$($Pool_RpcPath).pool.sexy/api/blocks" -tag $Name -cycletime 120
            if ($Pool_Request.now) {$ok=$true}
        }
        catch {
            if ($Error.Count){$Error.RemoveAt(0)}
            Write-Log -Level Warn "Pool API ($Name) for $Pool_Currency has failed. "
            $ok = $false
        }

        if ($ok) {
            $timestamp    = Get-UnixTimestamp
            $timestamp24h = $timestamp - 24*3600

            $coinUnits    = 1e18
            $Divisor      = 1e8

            $priceBTC     = if ($Session.Rates.$Pool_Currency) {1/$Session.Rates.$Pool_Currency} else {[double]$Pool_Request.prices.price_btc}

            $blocks       = $Pool_RequestBlocks.candidates + $Pool_RequestBlocks.immature + $Pool_RequestBlocks.matured | Where-Object {$_.timestamp -gt $timestamp24h -and -not $_.orphan} | Sort-Object timestamp -Descending
            $blocks_measure = $blocks | Select-Object -ExpandProperty timestamp | Measure-Object -Minimum -Maximum
            $blocks_last  = if ($blocks.Count) {$blocks[0].timestamp} else {$Pool_Request.stats.lastBlockFound}

            $diffLive     = $Pool_Request.nodes | Where-Object name -eq "main" | Select-Object -ExpandProperty difficulty
            $reward       = ($blocks | Where-Object reward | Measure-Object reward -Average).Average
            $profitLive   = 86400/$diffLive * $reward/$coinUnits * $priceBTC

            $Pool_BLK = [int]$(if ($blocks_measure.Maximum - $blocks_measure.Minimum) {24*3600/($blocks_measure.Maximum - $blocks_measure.Minimum)*$blocks_measure.Count})
            $Pool_TSL = if ($blocks_last) {$timestamp - $blocks_last}

            $Stat = Set-Stat -Name "$($Name)_$($Pool_Currency)_Profit" -Value $profitLive -Duration $StatSpan -ChangeDetection $false -HashRate $Pool_Request.hashrate -BlockRate $Pool_BLK -Quiet
        }
    }

    if ($ok -and ($AllowZero -or $Pool_Request.hashrate -gt 0) -or $InfoOnly) {
        [PSCustomObject]@{
            Algorithm     = $Pool_Algorithm_Norm
            CoinName      = $Pool_Coin.Name
            CoinSymbol    = $Pool_Currency
            Currency      = $Pool_Currency
            Price         = $Stat.$StatAverage #instead of .Live
            StablePrice   = $Stat.Week
            MarginOfError = $Stat.Week_Fluctuation
            Protocol      = "stratum+tcp"
            Host          = "$($Pool_RpcPath).pool.sexy"
            Port          = $_.port
            User          = "$($Wallets.$Pool_Currency).{workername:$Worker}"
            Pass          = "x"
            Region        = Get-Region "eu"
            SSL           = $False
            Updated       = $Stat.Updated
            PoolFee       = $Pool_Fee
            Workers       = $Pool_Request.minersTotal
            Hashrate      = $Stat.HashRate_Live
            TSL           = $Pool_TSL
            BLK           = $Stat.BlockRate_Average
            EthMode       = if ($Pool_Algorithm_Norm -match "^(Ethash|ProgPow)") {"ethproxy"} else {$null}
            AlgorithmList = if ($Pool_Algorithm_Norm -match "-") {@($Pool_Algorithm_Norm, ($Pool_Algorithm_Norm -replace '\-.*$'))}else{@($Pool_Algorithm_Norm)}
            Name          = $Name
            Penalty       = 0
            PenaltyFactor = 1
            Wallet        = $Wallets.$Pool_Currency
            Worker        = "{workername:$Worker}"
            Email         = $Email
        }
    }
}