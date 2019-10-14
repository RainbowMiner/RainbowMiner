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

if (-not $InfoOnly -and -not (Compare-Object @("ETH","ETC","ETP","GRIN") $Wallets.PSObject.Properties.Name -IncludeEqual -ExcludeDifferent)) {return}

$Name = Get-Item $MyInvocation.MyCommand.Path | Select-Object -ExpandProperty BaseName

$Pool_Region_Default = Get-Region "us"


$Pool_Request = [PSCustomObject]@{}
try {
    $Pool_Request = Invoke-RestMethodAsync "https://rbminer.net/api/data/ethashpool.json"  -tag $Name -cycletime 120
}
catch {
    if ($Error.Count){$Error.RemoveAt(0)}
    Write-Log -Level Warn "Pool API ($Name) has failed. "
}

$Pool_Request.PSObject.Properties.Name | Where-Object {$Wallets."$($_ -replace "[^A-Z]")" -or $InfoOnly} | ForEach-Object {
    $Pool_Currency  = $_
    $Pool_Request1  = $Pool_Request.$Pool_Currency
    $Pool_Algorithm = $Pool_Request1.algo

    $Pool_Algorithm_Norm = Get-Algorithm $Pool_Algorithm

    if (-not $InfoOnly) {
        $timestamp      = (Get-Date).ToUniversalTime()
        $timestamp24h   = (Get-Date).AddHours(-24).ToUniversalTime()

        if (-not ($timestamp_lastblock = ($Pool_Request1.blocks | Select-Object -First 1).timestamp)) {$timestamp_lastblock = 0}

        $Pool_BLK = ($Pool_Request1.blocks | Where-Object {[DateTime]$_.timestamp -gt $timestamp24h} | Measure-Object).Count
        $Pool_TSL = [int64]($timestamp - [DateTime]$timestamp_lastblock).TotalSeconds

        $Stat = Set-Stat -Name "$($Name)_$($Pool_Currency)_Profit" -Value 0 -Duration $StatSpan -HashRate $Pool_Request1.stats.pool_hash_rate -BlockRate $Pool_BLK -ChangeDetection $false -Quiet
    }
    
    if (($AllowZero -or $Pool_Request1.stats.pool_hash_rate -gt 0) -or $InfoOnly) {
        $Pool_Currency = $Pool_Currency -replace "[^A-Z]"
        [PSCustomObject]@{
            Algorithm     = $Pool_Algorithm_Norm
            CoinName      = $Pool_Request1.coin
            CoinSymbol    = $Pool_Currency
            Currency      = $Pool_Currency
            Price         = 0
            StablePrice   = 0
            MarginOfError = 0
            Protocol      = "stratum+tcp"
            Host          = $Pool_Request1.host
            Port          = $Pool_Request1.port
            User          = "$($Wallets.$Pool_Currency)$(if ($Pool_Currency -match "GRIN") {"."} else {"."}){workername:$Worker}"
            Pass          = "x"
            Region        = $Pool_Region_Default
            SSL           = $false
            Updated       = (Get-Date).ToUniversalTime()
            PoolFee       = $Pool_Request1.fee
            Workers       = $Pool_Request1.stats.workers_online
            Hashrate      = $Stat.HashRate_Live
            TSL           = $Pool_TSL
            BLK           = $Stat.BlockRate_Average
            WTM           = $true
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
