using module ..\Include.psm1

param(
    [PSCustomObject]$Wallets,
    [alias("WorkerName")]
    [String]$Worker,
    [TimeSpan]$StatSpan,
    [String]$DataWindow = "estimate_current",
    [Bool]$InfoOnly = $false,
    [Bool]$AllowZero = $false,
    [String]$StatAverage = "Minute_10"
)

$Name = Get-Item $MyInvocation.MyCommand.Path | Select-Object -ExpandProperty BaseName

$Pool_Region = "eu"

$Pools_Data = @(
    [PSCustomObject]@{coin = "BitTube"; symbol = "TUBE"; algo = "CnSaber"; port = 6040; fee = 1.0; walletSymbol = "tube"; host = "mine.tube.fairpool.xyz"; user="%wallet%+%worker%"}
    [PSCustomObject]@{coin = "Swap"; symbol = "XWP"; algo = "CnSwap"; port = 6080; fee = 1.0; walletSymbol = "xfh"; host = "mine.xfh.fairpool.xyz"; user="%wallet%+%worker%"}
    [PSCustomObject]@{coin = "Haven"; symbol = "XHV"; algo = "CnHaven"; port = 5566; fee = 1.0; walletSymbol = "xhv"; host = "mine.xhv.fairpool.xyz"; user="%wallet%+%worker%"}
    [PSCustomObject]@{coin = "Lethean"; symbol = "LTHN"; algo = "CnV8"; port = 6070; fee = 1.0; walletSymbol = "lethean"; host = "mine.lethean.fairpool.xyz"; user="%wallet%+%worker%"}
    [PSCustomObject]@{coin = "Loki"; symbol = "LOKI"; algo = "CnHeavy"; port = 5577; fee = 1.0; walletSymbol = "loki"; host = "mine.loki.fairpool.xyz"; user="%wallet%+%worker%"}
    [PSCustomObject]@{coin = "Masari"; symbol = "MSR"; algo = "CnHalf"; port = 6060; fee = 1.0; walletSymbol = "msr"; host = "mine.msr.fairpool.xyz"; user="%wallet%+%worker%"}
    [PSCustomObject]@{coin = "PrivatePay"; symbol = "XPP"; algo = "CnFast"; port = 6050; fee = 1.0; walletSymbol = "xpp"; host = "mine.xpp.fairpool.xyz"; user="%wallet%+%worker%"}
    [PSCustomObject]@{coin = "QuantumResistantLedger"; symbol = "QRL"; algo = "CnV7"; port = 7000; fee = 1.0; walletSymbol = "qrl"; host = "mine.qrl.fairpool.xyz"; user="%wallet%+%worker%"}
    [PSCustomObject]@{coin = "Ryo"; symbol = "RYO"; algo = "CnGpu"; port = 5555; fee = 1.0; walletSymbol = "ryo"; host = "mine.ryo.fairpool.xyz"; user="%wallet%+%worker%"}
    [PSCustomObject]@{coin = "Saronite"; symbol = "XRN"; algo = "CnHaven"; port = 5599; fee = 1.0; walletSymbol = "xrn"; host = "mine.xrn.fairpool.xyz"; user="%wallet%+%worker%"}
    [PSCustomObject]@{coin = "Solace"; symbol = "XPP"; algo = "CnHeavy"; port = 5588; fee = 1.0; walletSymbol = "solace"; host = "mine.solace.fairpool.xyz"; user="%wallet%+%worker%"}
    [PSCustomObject]@{coin = "Swap"; symbol = "XWP"; algo = "Cuckaroo29s"; port = 5588; fee = 1.0; walletSymbol = "xfh"; host = "mine.xfh.fairpool.xyz"; user="%wallet%+%worker%"}

    [PSCustomObject]@{coin = "Akroma"; symbol = "AKA"; algo = "Ethash"; port = 2222; fee = 1.0; walletSymbol = "aka"; host = "mine.aka.fairpool.xyz"; user="%wallet%.%worker%"}
    [PSCustomObject]@{coin = "DogEthereum"; symbol = "DOGX"; algo = "Ethash"; port = 7788; fee = 1.0; walletSymbol = "dogx"; host = "mine.dogx.fairpool.xyz"; user="%wallet%.%worker%"}
    [PSCustomObject]@{coin = "EthereumClassic"; symbol = "ETC"; algo = "Ethash"; port = 4444; fee = 1.0; walletSymbol = "etc"; host = "mine.etc.fairpool.xyz"; user="%wallet%.%worker%"}
    [PSCustomObject]@{coin = "Metaverse"; symbol = "ETP"; algo = "Ethash"; port = 6666; fee = 1.0; walletSymbol = "etp"; host = "mine.etp.fairpool.xyz"; user="%wallet%.%worker%"}
    [PSCustomObject]@{coin = "Nekonium"; symbol = "NUKO"; algo = "Ethash"; port = 7777; fee = 1.0; walletSymbol = "nuko"; host = "mine.nuko.fairpool.xyz"; user="%wallet%.%worker%"}
    [PSCustomObject]@{coin = "Pegascoin"; symbol = "PGC"; algo = "Ethash"; port = 1111; fee = 1.0; walletSymbol = "pgc"; host = "mine.pgc.fairpool.xyz"; user="%wallet%.%worker%"}

    [PSCustomObject]@{coin = "Purk"; symbol = "PURK"; algo = "WildKeccak"; port = 2244; fee = 1.0; walletSymbol = "purk"; host = "mine.purk.fairpool.xyz"}
)

$Pools_Data | Where-Object {$Wallets."$($_.symbol)" -or $InfoOnly} | ForEach-Object {
    $Pool_Currency = $_.symbol
    $Pool_RpcPath = $_.walletSymbol.ToLower()
    $Pool_Algorithm = $_.algo
    $Pool_Algorithm_Norm = Get-Algorithm $Pool_Algorithm

    $Pool_Port = $_.port
    $Pool_Fee  = $_.fee
    $Pool_User = $_.user

    $Pool_Request = [PSCustomObject]@{}

    $ok = $true
    if (-not $InfoOnly) {
        try {
            $Pool_Request = Invoke-RestMethodAsync "https://$($Pool_RpcPath).fairpool.xyz/api/poolStats" -tag $Name -timeout 15 -cycletime 120
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
            Port          = $_.port
            Ports         = $Pool_Ports
            User          = $Pool_User -replace '%wallet%',"$($Wallets.$($_.symbol))" -replace '%worker%',"{workername:$Worker}"
            Pass          = "x"
            Region        = $Pool_Region
            SSL           = $False
            Updated       = $Stat.Updated
            PoolFee       = $Pool_Fee
            Workers       = $Pool_Request.workers
            Hashrate      = $Stat.HashRate_Live
            TSL           = $Pool_TSL
            BLK           = $Stat.BlockRate_Average
        }
    }
}
