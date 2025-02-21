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
    [String]$StatAverage = "Minute_10",
    [String]$StatAverageStable = "Week",
    [String]$Email
)

$Name = Get-Item $MyInvocation.MyCommand.Path | Select-Object -ExpandProperty BaseName

$Pool_Request = [PSCustomObject]@{}

try {
    $Pool_Request = Invoke-RestMethodAsync "https://pool.kryptex.com/api/v1/rates" -tag $Name -cycletime 120 -retry 5 -retrywait 250
}
catch {
    if ($Global:Error.Count){$Global:Error.RemoveAt(0)}
    Write-Log -Level Warn "Pool API ($Name) has failed. "
    return
}

if (-not $Pool_Request.crypto) {
    Write-Log -Level Warn "Pool API ($Name) returned nothing. "
    return
}

[hashtable]$Pool_RegionsTable = @{}

$Pool_Regions = @("ru")
$Pool_Regions | Foreach-Object {$Pool_RegionsTable.$_ = Get-Region $_}

$Pool_Ports = @(7777,8888)
$Pool_ExcludeMineToAccount = @("NIR","QUAI","XEL")

$Pool_Request.crypto.PSObject.Properties.Name | Where-Object {$_ -notin @("BTC","DOGE","PYI","UBQ") -and ($Wallets.$_ -or ($Email -ne "" -and $_ -notin $Pool_ExcludeMineToAccount) -or $InfoOnly)} | ForEach-Object {
     
    $Pool_Rpc = $_.ToLower()
    $Pool_Host = "$($Pool_Rpc).kryptex.network" 

    if ($Pool_Coin = Get-Coin $_) {
        $Pool_Currency = $Pool_Coin.Symbol
        $Pool_Algorithm_Norm = $Pool_Coin.Algo
    } else {
        Write-Log -Level Warn "$($Name): $_ not found in CoinsDB"
        return
    }

    $PoolCoin_Request = [PSCustomObject]@{}

    try {
        $PoolCoin_Request = Invoke-RestMethodAsync "https://pool.kryptex.com/$($Pool_Rpc)/api/v1/pool/stats" -tag $Name -cycletime 120 -retry 5 -retrywait 250 -delay 200
    }
    catch {
        if ($Global:Error.Count){$Global:Error.RemoveAt(0)}
        Write-Log -Level Warn "Pool coin API ($Name) for $($Pool_Coin.Symbol) has failed. "
        return
    }

    $Pool_PoolFee = [Double]$PoolCoin_Request.fee * 100

    $Pool_BLK = $Pool_TSL = $null

    if (-not $InfoOnly) {
        $timestamp  = Get-UnixTimestamp
        $timestamp24h = $timestamp-86400

        $blocks_measure = $PoolCoin_Request.last_blocks_found | Where-Object {$_.date -ge $timestamp24h} | Select-Object -ExpandProperty date | Measure-Object -Minimum -Maximum
        if ($blocks_measure.Count -or $PoolCoin_Request.hashrate -eq 0) {
            $Pool_BLK = [int]$($(if ($blocks_measure.Count -gt 1 -and ($blocks_measure.Maximum - $blocks_measure.Minimum)) {86400/($blocks_measure.Maximum - $blocks_measure.Minimum)} else {1})*$blocks_measure.Count)
            $Pool_TSL = $timestamp - ($PoolCoin_Request.last_blocks_found | Select-Object -First 1).date
        }

        $Stat = Set-Stat -Name "$($Name)_$($_)_Profit" -Value 0 -Duration $StatSpan -HashRate $PoolCoin_Request.hashrate -BlockRate $Pool_BLK -ChangeDetection $false -Quiet
        if (-not $Stat.HashRate_Live -and -not $AllowZero) {return}

        if ($Wallets.$Pool_Currency) {
            $Pool_ExCurrency = try {
                [mailaddress]$Wallets.$Pool_Currency > $null
                "BTC"
            }
            catch {
                if ($Global:Error.Count){$Global:Error.RemoveAt(0)}
                $Pool_Currency
            }
            $Pool_Wallet = $Wallets.$Pool_Currency
        } elseif ($Email -ne "") {
            $Pool_ExCurrency = try {
                [mailaddress]$Email > $null
                "BTC"
            }
            catch {
                if ($Global:Error.Count){$Global:Error.RemoveAt(0)}
            }
            $Pool_Wallet = $Email
        }

        if (-not $Pool_ExCurrency) {return}
    } else {
        $Pool_ExCurrency = if ($Pool_Currency -in $Pool_MineToAccount) {"BTC"} else {$Pool_Currency}
    }


    foreach($Pool_Region in $Pool_Regions) {
        $Pool_SSL = $false
        foreach($Pool_Port in $Pool_Ports) {
            [PSCustomObject]@{
                Algorithm     = $Pool_Algorithm_Norm
                Algorithm0    = $Pool_Algorithm_Norm
                CoinName      = $Pool_Coin.Name
                CoinSymbol    = $Pool_Currency
                Currency      = $Pool_ExCurrency
                Price         = 0
                StablePrice   = 0
                MarginOfError = 0
                Protocol      = "stratum+$(if ($Pool_SSL) {"ssl"} else {"tcp"})"
                Host          = $Pool_Host
                Port          = $Pool_Port
                User          = "$($Pool_Wallet)/{workername:$Worker}"
                Pass          = "x"
                Region        = $Pool_RegionsTable.$Pool_Region
                SSL           = $Pool_SSL
                Updated       = $Stat.Updated
                PoolFee       = $Pool_PoolFee
                Workers       = $PoolCoin_Request.miners
                Hashrate      = $Stat.HashRate_Live
                TSL           = $Pool_TSL
                BLK           = if ($Pool_BLK -ne $null) {$Stat.BlockRate_Average} else {$null}
                PaysLive      = $PoolCoin_Request.fee_type -eq "PPS+"
                WTM           = $true
                Name          = $Name
                Penalty       = 0
                PenaltyFactor = 1
                Disabled      = $false
                HasMinerExclusions = $false
                Price_0       = 0.0
                Price_Bias    = 0.0
                Price_Unbias  = 0.0
                Wallet        = $Wallets.$Pool_Currency
                Worker        = "{workername:$Worker}"
                Email         = $Email
            }
            $Pool_SSL = $true
        }
    }
}
