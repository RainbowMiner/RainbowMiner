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

$Pool_Region = "us"

$Pools_Data = @(
    #[PSCustomObject]@{coin = "Caliber"; symbol = "CAL"; algo = "CnV8"; port = 5588; fee = 0.9; walletSymbol = "caliber"; host = "caliber.luckypool.io"}
    #[PSCustomObject]@{coin = "CitiCash"; symbol = "CCH"; algo = "CnHeavy"; port = 3888; fee = 0.9; walletSymbol = "citicash"; host = "citicash.luckypool.io"}
    #[PSCustomObject]@{coin = "Graft"; symbol = "GRFT"; algo = "CnV8"; port = 5588; fee = 0.9; walletSymbol = "graft"; host = "graft.luckypool.io"}
    #[PSCustomObject]@{coin = "Haven"; symbol = "XHV"; algo = "CnHaven"; port = 7788; fee = 0.9; walletSymbol = "haven"; host = "haven.luckypool.io"}
    #[PSCustomObject]@{coin = "JyoCoin"; symbol = "JYO"; algo = "CnV8"; port = 5008; fee = 0.9; walletSymbol = "jyo"; host = "jyo.luckypool.io"}
    #[PSCustomObject]@{coin = "SafexCash"; symbol = "SFX"; algo = "CnV8"; port = 3388; fee = 0.9; walletSymbol = "sfx"; host = "safex.luckypool.io"}
    [PSCustomObject]@{coin = "Swap"; symbol = "XWP"; algo = "Cuckaroo29s"; port = 4888; fee = 0.9; walletSymbol = "swap2"; host = "swap2.luckypool.io"; divisor = 32}
    #[PSCustomObject]@{coin = "WowNero"; symbol = "WOW"; algo = "CnWow"; port = 4488; fee = 0.9; walletSymbol = "wownero"; host = "wownero.luckypool.io"}
    #[PSCustomObject]@{coin = "Xcash"; symbol = "XCASH"; algo = "CnHeavyX"; port = 4488; fee = 0.9; walletSymbol = "xcash"; host = "xcash.luckypool.io"}
)

$Pools_Data | Where-Object {$Wallets."$($_.symbol)" -or $InfoOnly} | ForEach-Object {
    $Pool_Currency = $_.symbol
    $Pool_RpcPath = $_.walletSymbol.ToLower()
    $Pool_Algorithm = $_.algo
    $Pool_Algorithm_Norm = Get-Algorithm $Pool_Algorithm
    $Pool_Host = $_.host
    $Pool_Divisor = if ($_.divisor) {$_.divisor} else {1}

    $Pool_Fee  = 0.9

    $Pool_Request = [PSCustomObject]@{}
    $Pool_Ports   = @([PSCustomObject]@{})

    $ok = $true
    if (-not $InfoOnly) {
        $Pool_Ports_Ok = $false
        try {
            $Pool_Request = Invoke-RestMethodAsync "https://$($Pool_RpcPath).luckypool.io/api/stats" -tag $Name -timeout 15 -cycletime 120
            @("CPU","GPU","RIG","CPU-SSL","GPU-SSL","RIG-SSL") | Foreach-Object {
                $PortType = $_ -replace '-.*$'
                $Ports = if ($_ -match 'SSL') {$Pool_Request.config.ports | Where-Object {$_.ssl}} else {$Pool_Request.config.ports | Where-Object {-not $_.ssl}}
                if ($Ports) {
                    $PortIndex = if ($_ -match 'SSL') {1} else {0}
                    $Port = Switch ($PortType) {                        
                        "GPU" {$Ports | Where-Object desc -match 'high' | Select-Object -First 1}
                        "RIG" {$Ports | Where-Object desc -match '(cloud|very high|nicehash)' | Select-Object -First 1}
                    }
                    if (-not $Port) {$Port = $Ports | Select-Object -First 1}
                    if ($Pool_Ports.Count -eq 1 -and $PortIndex -eq 1) {$Pool_Ports += [PSCustomObject]@{}}
                    $Pool_Ports[$PortIndex] | Add-Member $PortType $Port.port -Force
                    $Pool_Ports_Ok = $true
                }
            }
        }
        catch {
            if ($Error.Count){$Error.RemoveAt(0)}
            Write-Log -Level Warn "Pool API ($Name) for $Pool_Currency has failed. "
            $ok = $false
        }
        if (-not $Pool_Ports_Ok) {$ok = $false}
    }

    if ($ok -and -not $InfoOnly) {
        $Pool_Fee = $Pool_Request.config.fee

        $timestamp    = Get-UnixTimestamp
        $timestamp24h = $timestamp - 24*3600

        $diffLive     = $Pool_Request.network.difficulty
        $reward       = $Pool_Request.network.reward
        $profitLive   = 86400/$diffLive*$reward/$Pool_Divisor
        $coinUnits    = $Pool_Request.config.coinUnits
        $amountLive   = $profitLive / $coinUnits

        $lastSatPrice = if ($Pool_Request.charts.price) {[Double]($Pool_Request.charts.price | Select-Object -Last 1)[1]} else {0}
        if (-not $lastSatPrice -and $Session.Rates.$Pool_Currency) {$lastSatPrice = 1/$Session.Rates.$Pool_Currency*1e8}
        $satRewardLive = $amountLive * $lastSatPrice
        if ($Pool_Request.config.priceCurrency -ne "BTC") {
            if (-not $Session.Rates."$($Pool_Request.config.priceCurrency)") {
                $GetTicker = Get-TickerGlobal $Pool_Request.config.priceCurrency
                if ($GetTicker."$($Pool_Request.config.priceCurrency)".BTC) {$Session.Rates."$($Pool_Request.config.priceCurrency)" = [double](1/$GetTicker."$($Pool_Request.config.priceCurrency)".BTC)}
            }
            $satRewardLive *= $Session.Rates."$($Pool_Request.config.priceCurrency)"
        }
        $amountDay = 0.0
        $satRewardDay = 0.0

        $Divisor = 1e8

        if ($averageDifficulties) {
            $averagePrices = if ($Pool_Request.charts.price) {($Pool_Request.charts.price | Where-Object {$_[0] -gt $timestamp24h} | Foreach-Object {$_[1]} | Measure-Object -Average).Average} else {0}
            if ($averagePrices) {
                $profitDay = 86400/$averageDifficulties*$reward/$Pool_Divisor
                $amountDay = $profitDay/$coinUnits
                $satRewardDay = $amountDay * $averagePrices
                if ($Pool_Request.config.priceCurrency -ne "BTC") {
                    $satRewardDay *= $Session.Rates."$($Pool_Request.config.priceCurrency)"
                }
            }
        }

        $blocks = $Pool_Request.pool.blocks | Where-Object {$_ -match '^.*?\:(\d+?)\:'} | Foreach-Object {$Matches[1]} | Sort-Object -Descending
        $blocks_measure = $blocks | Where-Object {$_ -gt $timestamp24h} | Measure-Object -Minimum -Maximum
        $Pool_BLK = [int]$(if ($blocks_measure.Maximum - $blocks_measure.Minimum) {24*3600/($blocks_measure.Maximum - $blocks_measure.Minimum)*$blocks_measure.Count})
        $Pool_TSL = if ($blocks.Count) {$timestamp - $blocks[0]}
    
        if (-not (Test-Path "Stats\Pools\$($Name)_$($Pool_Currency)_Profit.txt")) {$Stat = Set-Stat -Name "$($Name)_$($Pool_Currency)_Profit" -Value ($satRewardDay/$Divisor) -Duration (New-TimeSpan -Days 1) -HashRate ($Pool_Request.charts.hashrate | Where-Object {$_[0] -gt $timestamp24h} | Foreach-Object {$_[1]} | Measure-Object -Average).Average -BlockRate $Pool_BLK -Quiet}
        else {$Stat = Set-Stat -Name "$($Name)_$($Pool_Currency)_Profit" -Value ($satRewardLive/$Divisor) -Duration $StatSpan -ChangeDetection $false -HashRate $Pool_Request.pool.hashrate -BlockRate $Pool_BLK -Quiet}
    }
    
    if (($ok -and ($AllowZero -or $Pool_Request.pool.hashrate -gt 0)) -or $InfoOnly) {
        $PoolSSL = $false
        foreach ($Pool_Port in $Pool_Ports) {
            [PSCustomObject]@{
                Algorithm     = $Pool_Algorithm_Norm
                CoinName      = $_.coin
                CoinSymbol    = $Pool_Currency
                Currency      = $Pool_Currency
                Price         = $Stat.$StatAverage #instead of .Live
                StablePrice   = $Stat.Week
                MarginOfError = $Stat.Week_Fluctuation
                Protocol      = "stratum+tcp"
                Host          = $_.host
                Port          = $Pool_Port.CPU
                Ports         = $Pool_Port
                User          = "$($Wallets.$($_.symbol)){diff:.`$difficulty}"
                Pass          = "{workername:$Worker}"
                Region        = $Pool_Region
                SSL           = $False
                Updated       = $Stat.Updated
                PoolFee       = $Pool_Fee
                Workers       = $Pool_Request.pool.miners
                Hashrate      = $Stat.HashRate_Live
                TSL           = $Pool_TSL
                BLK           = $Stat.BlockRate_Average
            }
        }
    }
}
