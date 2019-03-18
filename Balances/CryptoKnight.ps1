param(
    $Config
)

$Name = Get-Item $MyInvocation.MyCommand.Path | Select-Object -ExpandProperty BaseName

$Pools_Data = @(
    [PSCustomObject]@{coin = "Aeon"; symbol = "AEON"; algo = "CnLiteV7"; port = 5541; fee = 0.0; walletSymbol = "aeon"; host = "aeon.ingest.cryptoknight.cc"}
    [PSCustomObject]@{coin = "Alloy"; symbol = "XAO"; algo = "CnAlloy"; port = 5661; fee = 0.0; walletSymbol = "alloy"; host = "alloy.ingest.cryptoknight.cc"}
    [PSCustomObject]@{coin = "Arqma"; symbol = "ARQ"; algo = "CnLiteV7"; port = 3731; fee = 0.0; walletSymbol = "arq"; host = "arq.ingest.cryptoknight.cc"}
    [PSCustomObject]@{coin = "Arto"; symbol = "RTO"; algo = "CnArto"; port = 51201; fee = 0.0; walletSymbol = "arto"; host = "arto.ingest.cryptoknight.cc"}
    [PSCustomObject]@{coin = "BBS"; symbol = "BBS"; algo = "CnLiteV7"; port = 19931; fee = 0.0; walletSymbol = "bbs"; host = "bbs.ingest.cryptoknight.cc"}
    [PSCustomObject]@{coin = "BitcoinNote"; symbol = "BTCN"; algo = "CnLiteV7"; port = 4461; fee = 0.0; walletSymbol = "btcn"; host = "btcn.ingest.cryptoknight.cc"}
    [PSCustomObject]@{coin = "Bittorium"; symbol = "BTOR"; algo = "CnLiteV7"; port = 10401; fee = 0.0; walletSymbol = "bittorium"; host = "bittorium.ingest.cryptoknight.cc"}
    [PSCustomObject]@{coin = "BitTube"; symbol = "TUBE"; algo = "CnSaber"; port = 4461; fee = 0.0; walletSymbol = "ipbc"; host = "tube.ingest.cryptoknight.cc"}
    [PSCustomObject]@{coin = "Caliber"; symbol = "CAL"; algo = "CnV8"; port = 14101; fee = 0.0; walletSymbol = "caliber"; host = "caliber.ingest.cryptoknight.cc"}
    [PSCustomObject]@{coin = "CitiCash"; symbol = "CCH"; algo = "CnHeavy"; port = 4461; fee = 0.0; walletSymbol = "citi"; host = "citi.ingest.cryptoknight.cc"}
    [PSCustomObject]@{coin = "Elya"; symbol = "ELYA"; algo = "CnV7"; port = 50201; fee = 0.0; walletSymbol = "elya"; host = "elya.ingest.cryptoknight.cc"}
    [PSCustomObject]@{coin = "Graft"; symbol = "GRFT"; algo = "CnV8"; port = 9111; fee = 0.0; walletSymbol = "graft"; host = "graft.ingest.cryptoknight.cc"}
    [PSCustomObject]@{coin = "Haven"; symbol = "XHV"; algo = "CnHaven"; port = 5531; fee = 0.0; walletSymbol = "haven"; host = "haven.ingest.cryptoknight.cc"}
    [PSCustomObject]@{coin = "IPBC"; symbol = "IPBC"; algo = "CnSaber"; port = 4461; fee = 0.0; walletSymbol = "ipbc"; host = "ipbcrocks.ingest.cryptoknight.cc"}
    [PSCustomObject]@{coin = "Iridium"; symbol = "IRD"; algo = "CnLiteV7"; port = 50501; fee = 0.0; walletSymbol = "iridium"; host = "iridium.ingest.cryptoknight.cc"}
    [PSCustomObject]@{coin = "Italo"; symbol = "ITA"; algo = "CnHaven"; port = 50701; fee = 0.0; walletSymbol = "italo"; host = "italo.ingest.cryptoknight.cc"}
    [PSCustomObject]@{coin = "Lethean"; symbol = "LTHN"; algo = "CnV8"; port = 8881; fee = 0.0; walletSymbol = "lethean"; host = "lethean.ingest.cryptoknight.cc"}
    #[PSCustomObject]@{coin = "Lines"; symbol = "LNS"; algo = "CnV7"; port = 50401; fee = 0.0; walletSymbol = "lines"; host = "lines.ingest.cryptoknight.cc"}
    [PSCustomObject]@{coin = "Loki"; symbol = "LOKI"; algo = "CnHeavy"; port = 7731; fee = 0.0; walletSymbol = "loki"; host = "loki.ingest.cryptoknight.cc"}
    [PSCustomObject]@{coin = "Masari"; symbol = "MSR"; algo = "CnHalf"; port = 3333; fee = 0.0; walletSymbol = "msr"; host = "masari.ingest.cryptoknight.cc"}
    [PSCustomObject]@{coin = "Monero"; symbol = "XMR"; algo = "CnV8"; port = 4441; fee = 0.0; walletSymbol = "monero"; host = "monero.ingest.cryptoknight.cc"}
    [PSCustomObject]@{coin = "MoneroV"; symbol = "XMV"; algo = "CnV7"; port = 9221; fee = 0.0; walletSymbol = "monerov"; host = "monerov.ingest.cryptoknight.cc"}
    [PSCustomObject]@{coin = "Niobio"; symbol = "NBR"; algo = "CnHeavy"; port = 50101; fee = 0.0; walletSymbol = "niobio"; host = "niobio.ingest.cryptoknight.cc"}
    [PSCustomObject]@{coin = "Ombre"; symbol = "OMB"; algo = "CnHeavy"; port = 5571; fee = 0.0; walletSymbol = "ombre"; host = "ombre.ingest.cryptoknight.cc"}
    #[PSCustomObject]@{coin = "Qwerty"; symbol = "QWC"; algo = "CnHeavy"; port = 8261; fee = 0.0; walletSymbol = "qwerty"; host = "qwerty.ingest.cryptoknight.cc"}
    [PSCustomObject]@{coin = "Ryo"; symbol = "RYO"; algo = "CnGpu"; port = 52901; fee = 0.0; walletSymbol = "ryo"; host = "ryo.ingest.cryptoknight.cc"}
    [PSCustomObject]@{coin = "SafeX"; symbol = "SAFE"; algo = "CnV7"; port = 13701; fee = 0.0; walletSymbol = "safex"; host = "safex.ingest.cryptoknight.cc"}
    [PSCustomObject]@{coin = "Saronite"; symbol = "XRN"; algo = "CnHeavy"; port = 5531; fee = 0.0; walletSymbol = "saronite"; host = "saronite.ingest.cryptoknight.cc"}
    [PSCustomObject]@{coin = "Solace"; symbol = "SOL"; algo = "CnHeavy"; port = 5001; fee = 0.0; walletSymbol = "solace"; host = "solace.ingest.cryptoknight.cc"}
    [PSCustomObject]@{coin = "Stellite"; symbol = "XTL"; algo = "CnHalf"; port = 16221; fee = 0.0; walletSymbol = "stellite"; host = "stellite.ingest.cryptoknight.cc"}
    [PSCustomObject]@{coin = "Swap"; symbol = "XWP"; algo = "Cuckaroo29s"; port = 7731; fee = 0.0; walletSymbol = "swap"; host = "swap.ingest.cryptoknight.cc"}
    [PSCustomObject]@{coin = "Triton"; symbol = "TRIT"; algo = "CnLiteV7"; port = 6631; fee = 0.0; walletSymbol = "triton"; host = "triton.ingest.cryptoknight.cc"}
    [PSCustomObject]@{coin = "WowNero"; symbol = "WOW"; algo = "CnWow"; port = 50901; fee = 0.0; walletSymbol = "wownero"; host = "wownero.ingest.cryptoknight.cc"}
)

$Pools_Data | Where-Object {$Config.Pools.$Name.Wallets."$($_.symbol)"} | Foreach-Object {
    $Pool_Currency = $_.symbol
    $Pool_RpcPath = $_.walletSymbol.ToLower()

    $Pool_Request = [PSCustomObject]@{}
    $Request = [PSCustomObject]@{}

    try {
        $Pool_Request = Invoke-RestMethodAsync "https://cryptoknight.cc/rpc/$($Pool_RpcPath)/stats" -tag $Name
        $Divisor = $Pool_Request.config.coinUnits

        $Request = Invoke-RestMethodAsync "https://cryptoknight.cc/rpc/$($Pool_RpcPath)/stats_address?address=$($Config.Pools.$Name.Wallets.$Pool_Currency)" -delay 100 -cycletime ($Config.BalanceUpdateMinutes*60)
        if (-not $Request.stats -or -not $Divisor) {
            Write-Log -Level Info "Pool Balance API ($Name) for $($Pool_Currency) returned nothing. "
        } else {
            $Pending = ($Request.blocks | Where-Object {$_ -match "^\d+?:\d+?:\d+?:\d+?:\d+?:(\d+?):"} | Foreach-Object {[int64]$Matches[1]} | Measure-Object -Sum).Sum / $Divisor
            [PSCustomObject]@{
                Caption     = "$($Name) ($Pool_Currency)"
                Currency    = $Pool_Currency
                Balance     = $Request.stats.balance / $Divisor
                Pending     = $Pending
                Total       = $Request.stats.balance / $Divisor + $Pending
                Paid        = $Request.stats.paid / $Divisor
                Payouts     = @($i=0;$Request.payments | Where-Object {$_ -match "^(.+?):(\d+?):"} | Foreach-Object {[PSCustomObject]@{time=$Request.payments[$i+1];amount=$Matches[2] / $Divisor;txid=$Matches[1]};$i+=2})
                LastUpdated = (Get-Date).ToUniversalTime()
            }
        }
    }
    catch {
        if ($Error.Count){$Error.RemoveAt(0)}
        Write-Log -Level Verbose "Pool Balance API ($Name) for $($Pool_Currency) has failed. "
    }
}
