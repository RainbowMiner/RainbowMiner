using module ..\Include.psm1

param(
    [PSCustomObject]$Wallets,
    [alias("WorkerName")]
    [String]$Worker, 
    [TimeSpan]$StatSpan,
    [String]$DataWindow = "estimate_current",
    [Bool]$InfoOnly = $false,
    [Bool]$AllowZero = $false
)

$Name = Get-Item $MyInvocation.MyCommand.Path | Select-Object -ExpandProperty BaseName

$Pool_Region = "us"

try {
    $Pool_Ngix = Invoke-RestMethodAsync "https://cryptoknight.cc/nginx.conf" -tag $Name -cycletime (4*3600)
} catch {
    if ($Error.Count){$Error.RemoveAt(0)}
    Write-Log -Level Warn "Pool API ($Name) has failed. "
    return
}

if (-not $Pool_Ngix) {
    Write-Log -Level Warn "Pool API ($Name) returned nothing. "
    return
}

$Pool_Algorithms = ([regex]"\/rpc\/([a-z]+)\/").Matches($Pool_Ngix) | Foreach-Object {$_.Groups[1]} | Select-Object -ExpandProperty Value -Unique

$Pools_Data = @(
    [PSCustomObject]@{coin = "Aeon"; symbol = "AEON"; algo = "CnLiteV7"; port = 5541; fee = 0.0; walletSymbol = "aeon"; host = "aeon.ingest.cryptoknight.cc"}
    [PSCustomObject]@{coin = "Alloy"; symbol = "XAO"; algo = "CnAlloy"; port = 5661; fee = 0.0; walletSymbol = "alloy"; host = "alloy.ingest.cryptoknight.cc"}
    [PSCustomObject]@{coin = "Arqma"; symbol = "ARQ"; algo = "CnLiteV7"; port = 3731; fee = 0.0; walletSymbol = "arq"; host = "arq.ingest.cryptoknight.cc"}
    [PSCustomObject]@{coin = "Arto"; symbol = "ARTO"; algo = "CnArto"; port = 51201; fee = 0.0; walletSymbol = "arto"; host = "arto.ingest.cryptoknight.cc"}
    [PSCustomObject]@{coin = "BBS"; symbol = "BBS"; algo = "CnLiteV7"; port = 19931; fee = 0.0; walletSymbol = "bbs"; host = "bbs.ingest.cryptoknight.cc"}
    [PSCustomObject]@{coin = "BitcoinNote"; symbol = "BTCN"; algo = "CnLiteV7"; port = 4461; fee = 0.0; walletSymbol = "btcn"; host = "btcn.ingest.cryptoknight.cc"}
    [PSCustomObject]@{coin = "BitTube"; symbol = "TUBE"; algo = "CnSaber"; port = 4461; fee = 0.0; walletSymbol = "ipbc"; host = "tube.ingest.cryptoknight.cc"}
    [PSCustomObject]@{coin = "Caliber"; symbol = "CAL"; algo = "CnV8"; port = 14101; fee = 0.0; walletSymbol = "caliber"; host = "caliber.ingest.cryptoknight.cc"}
    [PSCustomObject]@{coin = "CitiCash"; symbol = "CCH"; algo = "CnHeavy"; port = 4461; fee = 0.0; walletSymbol = "citi"; host = "citi.ingest.cryptoknight.cc"}
    [PSCustomObject]@{coin = "Elya"; symbol = "ELYA"; algo = "CnV7"; port = 50201; fee = 0.0; walletSymbol = "elya"; host = "elya.ingest.cryptoknight.cc"}
    [PSCustomObject]@{coin = "Graft"; symbol = "GRFT"; algo = "CnV8"; port = 9111; fee = 0.0; walletSymbol = "graft"; host = "graft.ingest.cryptoknight.cc"}
    [PSCustomObject]@{coin = "Haven"; symbol = "XHV"; algo = "CnHaven"; port = 5531; fee = 0.0; walletSymbol = "haven"; host = "haven.ingest.cryptoknight.cc"}
    [PSCustomObject]@{coin = "IntenseCoin"; symbol = "ITNS"; algo = "CnV7"; port = 8881; fee = 0.0; walletSymbol = "itns"; host = "intense.ingest.cryptoknight.cc"}
    [PSCustomObject]@{coin = "IPBC"; symbol = "IPBC"; algo = "CnSaber"; port = 4461; fee = 0.0; walletSymbol = "ipbc"; host = "ipbcrocks.ingest.cryptoknight.cc"}
    [PSCustomObject]@{coin = "Iridium"; symbol = "IRD"; algo = "CnLiteV7"; port = 50501; fee = 0.0; walletSymbol = "iridium"; host = "iridium.ingest.cryptoknight.cc"}
    [PSCustomObject]@{coin = "Italo"; symbol = "ITA"; algo = "CnHaven"; port = 50701; fee = 0.0; walletSymbol = "italo"; host = "italo.ingest.cryptoknight.cc"}
    [PSCustomObject]@{coin = "Lethean"; symbol = "LTHN"; algo = "CnV8"; port = 8881; fee = 0.0; walletSymbol = "lethean"; host = "lethean.ingest.cryptoknight.cc"}
    [PSCustomObject]@{coin = "Lines"; symbol = "LNS"; algo = "CnV7"; port = 50401; fee = 0.0; walletSymbol = "lines"; host = "lines.ingest.cryptoknight.cc"}
    [PSCustomObject]@{coin = "Loki"; symbol = "LOKI"; algo = "CnHeavy"; port = 7731; fee = 0.0; walletSymbol = "loki"; host = "loki.ingest.cryptoknight.cc"}
    [PSCustomObject]@{coin = "Masari"; symbol = "MSR"; algo = "CnFast"; port = 3333; fee = 0.0; walletSymbol = "msr"; host = "masari.ingest.cryptoknight.cc"}
    [PSCustomObject]@{coin = "Monero"; symbol = "XMR"; algo = "CnV8"; port = 4441; fee = 0.0; walletSymbol = "monero"; host = "monero.ingest.cryptoknight.cc"}
    [PSCustomObject]@{coin = "MoneroV"; symbol = "XMV"; algo = "CnV7"; port = 9221; fee = 0.0; walletSymbol = "monerov"; host = "monerov.ingest.cryptoknight.cc"}
    [PSCustomObject]@{coin = "Niobio"; symbol = "NBR"; algo = "CnHeavy"; port = 50101; fee = 0.0; walletSymbol = "niobio"; host = "niobio.ingest.cryptoknight.cc"}
    [PSCustomObject]@{coin = "Ombre"; symbol = "OMB"; algo = "CnHeavy"; port = 5571; fee = 0.0; walletSymbol = "ombre"; host = "ombre.ingest.cryptoknight.cc"}
    [PSCustomObject]@{coin = "Qwerty"; symbol = "QWC"; algo = "CnHeavy"; port = 8261; fee = 0.0; walletSymbol = "qwerty"; host = "qwerty.ingest.cryptoknight.cc"}
    [PSCustomObject]@{coin = "Ryo"; symbol = "RYO"; algo = "CnHeavy"; port = 52901; fee = 0.0; walletSymbol = "ryo"; host = "ryo.ingest.cryptoknight.cc"}
    [PSCustomObject]@{coin = "SafeX"; symbol = "SAFE"; algo = "CnV7"; port = 13701; fee = 0.0; walletSymbol = "safex"; host = "safex.ingest.cryptoknight.cc"}
    [PSCustomObject]@{coin = "Saronite"; symbol = "XRN"; algo = "CnHeavy"; port = 5531; fee = 0.0; walletSymbol = "saronite"; host = "saronite.ingest.cryptoknight.cc"}
    [PSCustomObject]@{coin = "Solace"; symbol = "SOL"; algo = "CnHeavy"; port = 5001; fee = 0.0; walletSymbol = "solace"; host = "solace.ingest.cryptoknight.cc"}
    [PSCustomObject]@{coin = "Stellite"; symbol = "XTL"; algo = "CnXTL"; port = 16221; fee = 0.0; walletSymbol = "stellite"; host = "stellite.ingest.cryptoknight.cc"}
    [PSCustomObject]@{coin = "Triton"; symbol = "TRIT"; algo = "CnLiteV7"; port = 6631; fee = 0.0; walletSymbol = "triton"; host = "triton.ingest.cryptoknight.cc"}
    [PSCustomObject]@{coin = "WowNero"; symbol = "WOW"; algo = "CnV8"; port = 50901; fee = 0.0; walletSymbol = "wownero"; host = "wownero.ingest.cryptoknight.cc"}
)

$Pools_Data | Where-Object {$Pool_Algorithms -icontains $_.walletSymbol} | Where-Object {$Wallets."$($_.symbol)" -or $InfoOnly} | ForEach-Object {
    $Pool_Currency = $_.symbol
    $Pool_RpcPath = $_.walletSymbol.ToLower()
    $Pool_Algorithm = $_.algo
    $Pool_Algorithm_Norm = Get-Algorithm $Pool_Algorithm

    $Pool_Port = 0
    $Pool_Fee  = 0.0

    $Pool_Request = [PSCustomObject]@{}
    $Pool_Ports   = [PSCustomObject]@{}

    $ok = $true
    if (-not $InfoOnly) {
        try {
            $Pool_Request = Invoke-RestMethodAsync "https://cryptoknight.cc/rpc/$($Pool_RpcPath)/live_stats" -tag $Name
            $Pool_Port = $Pool_Request.config.ports | Where-Object desc -match '(CPU|GPU)' | Select-Object -First 1 -ExpandProperty port
            @("CPU","GPU","RIG") | Foreach-Object {
                $PortType = $_
                $Pool_Request.config.ports | Where-Object desc -match $PortType | Select-Object -First 1 -ExpandProperty port | Foreach-Object {$Pool_Ports | Add-Member $PortType $_ -Force}
            }
        }
        catch {
            if ($Error.Count){$Error.RemoveAt(0)}
            Write-Log -Level Warn "Pool API ($Name) for $Pool_Currency has failed. "
            $ok = $false
        }
    }

    if ($ok -and $Pool_Port -and -not $InfoOnly) {
        $Pool_Fee = $Pool_Request.config.fee

        $timestamp    = Get-UnixTimestamp
        $timestamp24h = $timestamp - 24*3600

        $diffLive     = $Pool_Request.network.difficulty
        $reward       = $Pool_Request.network.reward
        $profitLive   = 86400/$diffLive*$reward
        $coinUnits    = $Pool_Request.config.coinUnits
        $amountLive   = $profitLive / $coinUnits

        $lastSatPrice = [Double]($Pool_Request.charts.price | Select-Object -Last 1)[1]
        $satRewardLive = $amountLive * $lastSatPrice

        $amountDay = 0.0
        $satRewardDay = 0.0

        $Divisor = 1e8

        $averageDifficulties = ($Pool_Request.charts.difficulty | Where-Object {$_[0] -gt $timestamp24h} | Foreach-Object {$_[1]} | Measure-Object -Average).Average
        if ($averageDifficulties) {
            $averagePrices = ($Pool_Request.charts.price | Where-Object {$_[0] -gt $timestamp24h} | Foreach-Object {$_[1]} | Measure-Object -Average).Average
            if ($averagePrices) {
                $profitDay = 86400/$averageDifficulties * $reward
                $amountDay = $profitDay/$coinUnits
                $satRewardDay = $amountDay * $averagePrices
            }
        }

        $blocks = $Pool_Request.pool.blocks | Where-Object {$_ -match '^.+?\:(\d+?)\:'} | Foreach-Object {$Matches[1]} | Sort-Object -Descending
        $Pool_BLK = ($blocks | Where-Object {$_ -gt $timestamp24h} | Measure-Object).Count
        $Pool_TSL = if ($blocks.Count) {$timestamp - $blocks[1]}
    
        if (-not (Test-Path "Stats\Pools\$($Name)_$($Pool_Currency)_Profit.txt")) {$Stat = Set-Stat -Name "$($Name)_$($Pool_Currency)_Profit" -Value ($satRewardDay/$Divisor) -Duration (New-TimeSpan -Days 1) -HashRate ($Pool_Request.pool.hashrate | Where-Object {$timestamp - $_[0] -gt 24*3600} | Foreach-Object {$_[1]} | Measure-Object -Average).Average -BlockRate $Pool_BLK -Quiet}
        else {$Stat = Set-Stat -Name "$($Name)_$($Pool_Currency)_Profit" -Value ($satRewardLive/$Divisor) -Duration $StatSpan -ChangeDetection $true -HashRate $Pool_Request.pool.hashrate -BlockRate $Pool_BLK -Quiet}
    }
    
    if (($ok -and $Pool_Port -and ($AllowZero -or $Pool_Request.pool.hashrate -gt 0)) -or $InfoOnly) {
        [PSCustomObject]@{
            Algorithm     = $Pool_Algorithm_Norm
            CoinName      = $_.coin
            CoinSymbol    = $Pool_Currency
            Currency      = $Pool_Currency
            Price         = $Stat.Minute_10 #instead of .Live
            StablePrice   = $Stat.Week
            MarginOfError = $Stat.Week_Fluctuation
            Protocol      = "stratum+tcp"
            Host          = $_.host
            Port          = if (-not $Pool_Port) {$_.port} else {$Pool_Port}
            Ports         = $Pool_Ports
            User          = "$($Wallets.$($_.symbol)){diff:.`$difficulty}"
            Pass          = $Worker
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
