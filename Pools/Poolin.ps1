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

$Pool_Region_Default = Get-Region "ca"

$Pools_Data = @(
    [PSCustomObject]@{coin="ETH";fee=3.0;divisor=1}
    [PSCustomObject]@{coin="RVN";fee=4.0;divisor=[math]::Pow(2,32)}
)

$Pools_Data | Where-Object {$Wallets."$($_.coin)" -or $InfoOnly} | ForEach-Object {
    $Pool_Currency  = $_.coin
    $Pool_Coin = Get-Coin $_.coin
    $Pool_Rpc  = $_.coin.ToLower()

    $ok = $true
    if (-not $InfoOnly) {

        $Pool_RequestBase = [PSCustomObject]@{}
        $Pool_RequestCoin = [PSCustomObject]@{}

        $errno = "NF"
        try {
            $Pool_RequestBase = Invoke-RestMethodAsync "https://api-prod.poolin.com/api/public/v2/basedata/coin/$Pool_Rpc" -tag $Name -cycletime 120
            if ("$($Pool_RequestBase.err_no)" -ne "0" -or -not $Pool_RequestBase.data) {$ok=$false;if ($Pool_RequestBase.err_no) {$errno = $Pool_RequestBase.err_no}}
            else {
                $Pool_RequestCoin = Invoke-RestMethodAsync "https://api-prod.poolin.com/api/public/v1/pool/stats/merge?coin_type=$Pool_Rpc" -tag $Name -cycletime 120
                if ("$($Pool_RequestCoin.err_no)" -ne "0" -or -not $Pool_RequestCoin.data) {$ok=$false;if ($Pool_RequestCoin.err_no) {$errno = $Pool_RequestCoin.err_no}}
            }
        }
        catch {
            if ($Error.Count){$Error.RemoveAt(0)}
            $ok = $false
        }
        if (-not $ok) {
            Write-Log -Level Warn "Pool API ($Name) has failed. (errno=$errno)"
            return
        }

        $Pool_Hashrate = ConvertFrom-Hash "$($Pool_RequestCoin.data.shares.shares_5m)$($Pool_RequestCoin.data.shares.shares_unit)"
        $Pool_BLK      = if ($Pool_Hashrate -gt 0 -and $Pool_RequestBase.data.difficulty -gt 0) {86400/$Pool_RequestBase.data.difficulty * $Pool_Hashrate / $_.divisor} else {0}

        $Stat = Set-Stat -Name "$($Name)_$($Pool_Currency)_Profit" -Value 0 -Duration $StatSpan -ChangeDetection $false -HashRate $Pool_Hashrate -BlockRate $Pool_BLK -Quiet

        if (-not $Stat.HashRate_Live -and -not $AllowZero) {return}
    }
    
    [PSCustomObject]@{
        Algorithm     = $Pool_Coin.Algo
		Algorithm0    = $Pool_Coin.Algo
        CoinName      = $Pool_Coin.Name
        CoinSymbol    = $Pool_Currency
        Currency      = $Pool_Currency
        Price         = 0
        StablePrice   = 0
        MarginOfError = 0
        Protocol      = "stratum+tcp"
        Host          = "$Pool_Rpc.ss.poolin.com"
        Port          = 443
        User          = "$($Wallets.$Pool_Currency)$(if ($Wallets.$Pool_Currency -notmatch '\.') {".001"})"
        Pass          = "123"
        Region        = $Pool_Region_Default
        SSL           = $false
        Updated       = (Get-Date).ToUniversalTime()
        PoolFee       = $_.fee
        Workers       = $Pool_RequestCoin.data.workers
        Hashrate      = $Stat.HashRate_Live
        #TSL           = $Pool_TSL
        BLK           = $Stat.BlockRate_Average
        WTM           = $true
        EthMode       = if ($Pool_Coin.Algo -match "^(Ethash|ProgPow)") {"ethproxy"} elseif ($Pool_Algorithm_Norm -match "^(KawPOW)") {"stratum"} else {$null}
        Name          = $Name
        Penalty       = 0
        PenaltyFactor = 1
        Disabled      = $false
        HasMinerExclusions = $false
        Price_Bias    = 0.0
        Price_Unbias  = 0.0
        Wallet        = "$($Wallets.$Pool_Currency -replace '\.[^.]+$')"
        Worker        = "$(if ($Wallets.$Pool_Currency -match '\.([^.]+)$') {$Matches[1]} else {"001"})"
        Email         = $Email
    }
}
