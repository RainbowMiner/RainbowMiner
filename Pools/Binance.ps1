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

$Pool_Fee = 0.0
$Pool_Default_Region = Get-Region "asia"

$Pools_Request = [PSCustomObject]@{}
try {
    $Pools_Request = Invoke-RestMethodAsync "https://pool.binance.com/mining-api/v1/public/pool/index" -tag $Name -timeout 15 -cycletime 120
}
catch {
    if ($Error.Count){$Error.RemoveAt(0)}
    Write-Log -Level Warn "Pool API ($Name) has failed. "
    return
}

$Pools_Request.data.algoList | ForEach-Object {
    $Pool_Algorithm = $_.algoName.ToLower()
    $Pool_HashRate = $_.poolHash
    $Pool_Workers  = $_.effectiveCount

    $_.symbolInfos | Where-Object {$Wallets."$($_.symbol)" -or $InfoOnly} | Foreach-Object {

        $Pool_Currency = $_.symbol
        $Pool_Coin  = Get-Coin $Pool_Currency
        $Pool_Algorithm_Norm = Get-Algorithm $Pool_Coin.Algo
        
        $Stat = Set-Stat -Name "$($Name)_$($Pool_Currency)_Profit" -Value 0 -Duration $StatSpan -ChangeDetection $false -HashRate $Pool_HashRate -Quiet
        if (-not $Stat.HashRate_Live -and -not $AllowZero) {return}
    
        [PSCustomObject]@{
            Algorithm     = $Pool_Algorithm_Norm
            Algorithm0    = $Pool_Algorithm_Norm
            CoinName      = $Pool_Coin.Name
            CoinSymbol    = $Pool_Currency
            Currency      = $Pool_Currency
            Price         = 0
            StablePrice   = 0
            MarginOfError = 0
            Protocol      = "stratum+tcp"
            Host          = "$($Pool_Algorithm).poolbinance.com"
            Port          = 8888
            User          = "$($Wallets.$Pool_Currency).{workername:$Worker}"
            Pass          = "x"
            Region        = $Pool_Default_Region
            SSL           = $false
            Updated       = (Get-Date).ToUniversalTime()
            PoolFee       = $Pool_Fee
            DataWindow    = $DataWindow
            Workers       = $Pool_Workers
            Hashrate      = $Stat.HashRate_Live
            #TSL           = $Pool_TSL
            #BLK           = $Stat.BlockRate_Average
            WTM           = $true
            EthMode       = if ($Pool_Algorithm_Norm -eq "Ethash") {"ethproxy"} else {$null}
            Name          = $Name
            Penalty       = 0
            PenaltyFactor = 1
            Disabled      = $false
            HasMinerExclusions = $false
            Price_Bias    = 0.0
            Price_Unbias  = 0.0
            Wallet        = $Wallets.$Pool_Currency
            Worker        = "{workername:$Worker}"
            Email         = $Email
        }
    }
}
