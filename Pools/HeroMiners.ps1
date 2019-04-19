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
    [PSCustomObject]@{coin = "Aeon";     symbol = "AEON";  algo = "CnLiteV7";    port = 10410; fee = 0.9; rpc = "aeon"}
    [PSCustomObject]@{coin = "Arqma";    symbol = "ARQ";   algo = "CnLiteV7";    port = 10320; fee = 0.9; rpc = "arqma"}
    [PSCustomObject]@{coin = "BitTube";  symbol = "TUBE";  algo = "CnSaber";     port = 10280; fee = 0.9; rpc = "tube"}
    [PSCustomObject]@{coin = "Block";    symbol = "BLOC";  algo = "CnHaven";     port = 10240; fee = 0.9; rpc = "bloc"}
    [PSCustomObject]@{coin = "Citadel";  symbol = "CTL";   algo = "CnV7";        port = 10420; fee = 0.9; rpc = "citadel"}
    [PSCustomObject]@{coin = "Conceal";  symbol = "CCX";   algo = "CnFast";      port = 10360; fee = 0.9; rpc = "conceal"}
    [PSCustomObject]@{coin = "Graft";    symbol = "GRFT";  algo = "CnRwz";       port = 10100; fee = 0.9; rpc = "graft"}
    [PSCustomObject]@{coin = "Haven";    symbol = "XHV";   algo = "CnHaven";     port = 10140; fee = 0.9; rpc = "haven"}
    [PSCustomObject]@{coin = "Lethean";  symbol = "LTHN";  algo = "CnV8";        port = 10180; fee = 0.9; rpc = "lethean"}
    [PSCustomObject]@{coin = "Loki";     symbol = "LOKI";  algo = "CnHeavy";     port = 10110; fee = 0.9; rpc = "loki"}
    [PSCustomObject]@{coin = "Masari";   symbol = "MSR";   algo = "CnHalf";      port = 10150; fee = 0.9; rpc = "masari"}
    [PSCustomObject]@{coin = "Monero";   symbol = "XMR";   algo = "CnR";         port = 10190; fee = 0.9; rpc = "monero"}
    [PSCustomObject]@{coin = "MoneroV";  symbol = "XMV";   algo = "CnV7";        port = 10200; fee = 0.9; rpc = "monerov"}
    [PSCustomObject]@{coin = "Qrl";      symbol = "QRL";   algo = "CnV7";        port = 10370; fee = 0.9; rpc = "qrl"}
    [PSCustomObject]@{coin = "Ryo";      symbol = "RYO";   algo = "CnGpu";       port = 10270; fee = 0.9; rpc = "ryo"}
    [PSCustomObject]@{coin = "SafeX";    symbol = "SAFE";  algo = "CnV7";        port = 10430; fee = 0.9; rpc = "safex"}
    [PSCustomObject]@{coin = "Saronite"; symbol = "XRN";   algo = "CnHeavy";     port = 10230; fee = 0.9; rpc = "saronite"}
    [PSCustomObject]@{coin = "Stellite"; symbol = "XTL";   algo = "CnHalf";      port = 10130; fee = 0.9; rpc = "stellite"}
    [PSCustomObject]@{coin = "Swap";     symbol = "XWP";   algo = "Cuckaroo29s"; port = 10441; fee = 0.9; rpc = "swap"; divisor = 32}
    [PSCustomObject]@{coin = "Turtle";   symbol = "TRTL";  algo = "CnTurtle";    port = 10380; fee = 0.9; rpc = "turtlecoin"}
    [PSCustomObject]@{coin = "uPlexa";   symbol = "UPX";   algo = "CnUpx";       port = 10470; fee = 0.9; rpc = "uplexa"}
    [PSCustomObject]@{coin = "Xcash";    symbol = "XCASH"; algo = "CnHalf";      port = 10440; fee = 0.9; rpc = "xcash"}
)

$Pools_Data | Where-Object {$Wallets."$($_.symbol)" -or $InfoOnly} | ForEach-Object {
    $Pool_Currency = $_.symbol
    $Pool_RpcPath = $_.rpc.ToLower()
    $Pool_Algorithm = $_.algo
    $Pool_Algorithm_Norm = Get-Algorithm $Pool_Algorithm
    $Pool_Divisor = if ($_.divisor) {$_.divisor} else {1}

    $Pool_Fee  = 0.9

    $Pool_Request = [PSCustomObject]@{}
    $Pool_Ports   = @([PSCustomObject]@{})    

    $ok = $true
    if (-not $InfoOnly) {
        $Pool_Ports_Ok = $false
        try {
            $Pool_Request = Invoke-RestMethodAsync "https://$($Pool_RpcPath).herominers.com/api/stats" -tag $Name -timeout 15 -cycletime 120
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
        $reward       = $Pool_Request.lastblock.reward
        $profitLive   = 86400/$diffLive*$reward/$Pool_Divisor
        $coinUnits    = $Pool_Request.config.coinUnits
        $amountLive   = $profitLive / $coinUnits

        if ($Pool_Request.price.btc) {$lastSatPrice = 1e8*[Double]$Pool_Request.price.btc}
        else {
            $lastSatPrice = if ($Pool_Request.charts.price) {[Double]($Pool_Request.charts.price | Select-Object -Last 1)[1]} else {0}
            if ($Pool_Request.config.priceCurrency -ne "BTC" -and $Session.Rates."$($Pool_Request.config.priceCurrency)") {$lastSatPrice *= 1e8/$Session.Rates."$($Pool_Request.config.priceCurrency)"}
            if (-not $lastSatPrice -and $Session.Rates.$Pool_Currency) {$lastSatPrice = 1/$Session.Rates.$Pool_Currency*1e8}
        }
        if ($lastSatPrice -and $Session.Rates -and -not $Session.Rates.$Pool_Currency) {$Session.Rates.$Pool_Currency = 1/$lastSatPrice*1e8}

        $satRewardLive = $amountLive * $lastSatPrice        

        $satRewardDay = 0.0

        $averageDifficulties = ($Pool_Request.charts.difficulty | Where-Object {$_[0] -gt $timestamp24h} | Foreach-Object {$_[1]} | Measure-Object -Average).Average
        if ($averageDifficulties) {
            $averagePrices = if ($Pool_Request.charts.price) {($Pool_Request.charts.price | Where-Object {$_[0] -gt $timestamp24h} | Foreach-Object {$_[1]} | Measure-Object -Average).Average} else {0}
            if ($Pool_Request.config.priceCurrency -ne "BTC" -and $Session.Rates."$($Pool_Request.config.priceCurrency)") {$averagePrices *= 1e8/$Session.Rates."$($Pool_Request.config.priceCurrency)"}
            if (-not $averagePrices) {$averagePrices = $lastSatPrice}
            $profitDay = 86400/$averageDifficulties*$reward/$Pool_Divisor
            $amountDay = $profitDay/$coinUnits
            $satRewardDay = $amountDay * $averagePrices
        }
        if (-not $satRewardDay) {$satRewardDay = $satRewardLive}

        $blocks = $Pool_Request.pool.blocks | Where-Object {$_ -match '^.*?\:(\d+?)\:'} | Foreach-Object {$Matches[1]} | Sort-Object -Descending
        $blocks_measure = $blocks | Where-Object {$_ -gt $timestamp24h} | Measure-Object -Minimum -Maximum
        $Pool_BLK = [int]$(if ($blocks_measure.Maximum - $blocks_measure.Minimum) {24*3600/($blocks_measure.Maximum - $blocks_measure.Minimum)*$blocks_measure.Count})
        $Pool_TSL = if ($blocks.Count) {$timestamp - $blocks[0]}

        $Divisor = 1e8
    
        if (-not (Test-Path "Stats\Pools\$($Name)_$($Pool_Currency)_Profit.txt")) {$Stat = Set-Stat -Name "$($Name)_$($Pool_Currency)_Profit" -Value ($satRewardDay/$Divisor) -Duration (New-TimeSpan -Days 1) -HashRate ($Pool_Request.charts.hashrate | Where-Object {$_[0] -gt $timestamp24h} | Foreach-Object {$_[1]} | Measure-Object -Average).Average -BlockRate $Pool_BLK -Quiet}
        else {$Stat = Set-Stat -Name "$($Name)_$($Pool_Currency)_Profit" -Value ($satRewardLive/$Divisor) -Duration $StatSpan -ChangeDetection $false -HashRate $Pool_Request.pool.hashrate -BlockRate $Pool_BLK -Quiet}
    }
    
    if (($ok -and ($AllowZero -or $Pool_Request.pool.hashrate -gt 0)) -or $InfoOnly) {
        $Pool_SSL = $false
        foreach ($Pool_Port in $Pool_Ports) {
            [PSCustomObject]@{
                Algorithm     = $Pool_Algorithm_Norm
                CoinName      = $_.coin
                CoinSymbol    = $Pool_Currency
                Currency      = $Pool_Currency
                Price         = $Stat.$StatAverage #instead of .Live
                StablePrice   = $Stat.Week
                MarginOfError = $Stat.Week_Fluctuation
                Protocol      = "stratum+$(if ($Pool_SSL) {"ssl"} else {"tcp"})"
                Host          = "$($Pool_RpcPath).herominers.com"
                Port          = $Pool_Port.CPU
                Ports         = $Pool_Port
                User          = "$($Wallets.$Pool_Currency){diff:.`$difficulty}"
                Pass          = "{workername:$Worker}"
                Region        = $Pool_Region_Default
                SSL           = $Pool_SSL
                Updated       = $Stat.Updated
                PoolFee       = $Pool_Fee
                Workers       = $Pool_Request.pool.miners
                Hashrate      = $Stat.HashRate_Live
                TSL           = $Pool_TSL
                BLK           = $Stat.BlockRate_Average
            }
            $Pool_SSL = $true
        }
    }
}
