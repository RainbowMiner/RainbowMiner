param(
    $Config
)

$Name = Get-Item $MyInvocation.MyCommand.Path | Select-Object -ExpandProperty BaseName

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

$Pools_Data | Where-Object {$Config.Pools.$Name.Wallets."$($_.symbol)"} | Foreach-Object {
    $Pool_Currency = $_.symbol
    $Pool_RpcPath = $_.walletSymbol.ToLower()

    $Pool_Request = [PSCustomObject]@{}
    $Request = [PSCustomObject]@{}

    try {
        #$Pool_Request = Invoke-RestMethodAsync "https://$($Pool_RpcPath).fairpool.xyz/api/poolStats" -tag $Name
        #$Divisor = $Pool_Request.config.coinUnits
        $Divisor = 1e12

        $Request = Invoke-RestMethodAsync "https://$($Pool_RpcPath).fairpool.xyz/api/stats?login=$($Config.Pools.$Name.Wallets.$Pool_Currency)" -delay 100 -cycletime ($Config.BalanceUpdateMinutes*60)
        if (-not $Request.stats -or -not $Divisor) {
            Write-Log -Level Info "Pool Balance API ($Name) for $($Pool_Currency) returned nothing. "
        } else {            
            [PSCustomObject]@{
                Caption     = "$($Name) ($Pool_Currency)"
                Currency    = $Pool_Currency
                Balance     = $Request.balance / $Divisor
                Pending     = $Request.unconfirmed / $Divisor
                Total       = ($Request.balance + $Request.unconfirmed) / $Divisor
                Paid        = $Request.paid / $Divisor
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
