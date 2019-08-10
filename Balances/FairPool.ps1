param(
    $Config
)

$Name = Get-Item $MyInvocation.MyCommand.Path | Select-Object -ExpandProperty BaseName

$Pools_Data = @(
    [PSCustomObject]@{coin = "BitTube";         symbol = "TUBE"; algo = "CnSaber";     port = 6040; fee = 1.0; rpc = "tube";    user="%wallet%+%worker%"}
    [PSCustomObject]@{coin = "Haven";           symbol = "XHV";  algo = "CnHaven";     port = 5566; fee = 1.0; rpc = "xhv";     user="%wallet%+%worker%"}
    [PSCustomObject]@{coin = "Lethean";         symbol = "LTHN"; algo = "CnR";         port = 6070; fee = 1.0; rpc = "lethean"; user="%wallet%+%worker%"}
    [PSCustomObject]@{coin = "Loki";            symbol = "LOKI"; algo = "RxLoki";      port = 5577; fee = 1.0; rpc = "loki";    user="%wallet%+%worker%"}
    [PSCustomObject]@{coin = "Masari";          symbol = "MSR";  algo = "CnHalf";      port = 6060; fee = 1.0; rpc = "msr";     user="%wallet%+%worker%"}
    [PSCustomObject]@{coin = "Qrl";             symbol = "QRL";  algo = "CnV7";        port = 7000; fee = 1.0; rpc = "qrl";     user="%wallet%+%worker%"}
    [PSCustomObject]@{coin = "Ryo";             symbol = "RYO";  algo = "CnGpu";       port = 5555; fee = 1.0; rpc = "ryo";     user="%wallet%+%worker%"}
    [PSCustomObject]@{coin = "Swap";            symbol = "XWP";  algo = "Cuckaroo29s"; port = 6080; fee = 1.0; rpc = "xfh";     user="%wallet%+%worker%"; divisor = 32}
    [PSCustomObject]@{coin = "WowNero";         symbol = "WOW";  algo = "RxWow";       port = 6090; fee = 1.0; rpc = "wow";     user="%wallet%+%worker%"}
    [PSCustomObject]@{coin = "Xtend";           symbol = "XTNC"; algo = "CnTurtle";    port = 7010; fee = 1.0; rpc = "xtnc";    user="%wallet%+%worker%"}

    [PSCustomObject]@{coin = "DogEthereum";     symbol = "DOGX"; algo = "Ethash";      port = 7788; fee = 1.0; rpc = "dogx";    user="%wallet%.%worker%"}
    [PSCustomObject]@{coin = "EthereumClassic"; symbol = "ETC";  algo = "Ethash";      port = 4444; fee = 1.0; rpc = "etc";     user="%wallet%.%worker%"}
    [PSCustomObject]@{coin = "Metaverse";       symbol = "ETP";  algo = "Ethash";      port = 6666; fee = 1.0; rpc = "etp";     user="%wallet%.%worker%"}
    [PSCustomObject]@{coin = "Nekonium";        symbol = "NUKO"; algo = "Ethash";      port = 7777; fee = 1.0; rpc = "nuko";    user="%wallet%.%worker%"}
    [PSCustomObject]@{coin = "Pegascoin";       symbol = "PGC";  algo = "Ethash";      port = 1111; fee = 1.0; rpc = "pgc";     user="%wallet%.%worker%"}

    [PSCustomObject]@{coin = "Zano";            symbol = "ZANO"; algo = "ProgPowZ";    port = 7020; fee = 1.0; rpc = "zano";    user="%wallet%.%worker%"}
)

$Pools_Data | Where-Object {$Config.Pools.$Name.Wallets."$($_.symbol)"} | Foreach-Object {
    $Pool_Currency = $_.symbol
    $Pool_RpcPath = $_.rpc.ToLower()

    $Pool_Request = [PSCustomObject]@{}
    $Request = [PSCustomObject]@{}

    try {
        #$Pool_Request = Invoke-RestMethodAsync "https://$($Pool_RpcPath).fairpool.xyz/api/poolStats" -tag $Name
        #$Divisor = $Pool_Request.config.coinUnits
        $Divisor = [Decimal]1e12

        $Request = Invoke-RestMethodAsync "https://$($Pool_RpcPath).fairpool.xyz/api/stats?login=$(Get-WalletWithPaymentId $Config.Pools.$Name.Wallets.$Pool_Currency -pidchar '.')" -delay 100 -cycletime ($Config.BalanceUpdateMinutes*60)
        if ($Request.method -ne "stats" -or -not $Divisor) {
            Write-Log -Level Info "Pool Balance API ($Name) for $($Pool_Currency) returned nothing. "
        } else {            
            [PSCustomObject]@{
                Caption     = "$($Name) ($Pool_Currency)"
                Currency    = $Pool_Currency
                Balance     = [Decimal]$Request.balance / $Divisor
                Pending     = [Decimal]$Request.unconfirmed / $Divisor
                Total       = ([Decimal]$Request.balance + [Decimal]$Request.unconfirmed) / $Divisor
                Paid        = [Decimal]$Request.paid / $Divisor
                Payouts     = @($i=0;$Request.payments | Where-Object {$_ -match "^(.+?):(\d+?):"} | Foreach-Object {[PSCustomObject]@{time=$Request.payments[$i+1];amount=[Decimal]$Matches[2] / $Divisor;txid=$Matches[1]};$i+=2})
                LastUpdated = (Get-Date).ToUniversalTime()
            }
        }
    }
    catch {
        if ($Error.Count){$Error.RemoveAt(0)}
        Write-Log -Level Verbose "Pool Balance API ($Name) for $($Pool_Currency) has failed. "
    }
}
