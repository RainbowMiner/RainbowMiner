param(
    $Config
)

$Name = Get-Item $MyInvocation.MyCommand.Path | Select-Object -ExpandProperty BaseName

$Pools_Data = @(
    [PSCustomObject]@{symbol = "ARQ";   port = 10320; fee = 0.9; rpc = "arqma"}
    [PSCustomObject]@{symbol = "ARQ";   port = 10630; fee = 0.9; rpc = "iridium";    symbol2 = "IRD";  units2=1e8}
    [PSCustomObject]@{symbol = "ARQ";   port = 10630; fee = 0.9; rpc = "arqple";     symbol2 = "PLE";  units2=1e8}
    [PSCustomObject]@{symbol = "ARQ";   port = 10670; fee = 0.9; rpc = "cypruscoin"; symbol2 = "XCY";  units2=1e6}
    [PSCustomObject]@{symbol = "BLOC";  port = 10430; fee = 0.9; rpc = "bloc"}
    [PSCustomObject]@{symbol = "CCX";   port = 10361; fee = 0.9; rpc = "conceal"}
    [PSCustomObject]@{symbol = "GRFT";  port = 10100; fee = 0.9; rpc = "graft"}
    [PSCustomObject]@{symbol = "LOKI";  port = 10111; fee = 0.9; rpc = "loki"}
    [PSCustomObject]@{symbol = "MSR";   port = 10150; fee = 0.9; rpc = "masari"}
    [PSCustomObject]@{symbol = "QRL";   port = 10370; fee = 0.9; rpc = "qrl"}
    [PSCustomObject]@{symbol = "RYO";   port = 10270; fee = 0.9; rpc = "ryo"}
    [PSCustomObject]@{symbol = "SUMO";  port = 10610; fee = 0.9; rpc = "sumo"}
    [PSCustomObject]@{symbol = "TRTL";  port = 10380; fee = 0.9; rpc = "turtlecoin"}
    [PSCustomObject]@{symbol = "TUBE";  port = 10280; fee = 0.9; rpc = "tube"}
    [PSCustomObject]@{symbol = "UPX";   port = 10470; fee = 0.9; rpc = "uplexa"}
    [PSCustomObject]@{symbol = "WOW";   port = 10660; fee = 0.9; rpc = "wownero"}
    [PSCustomObject]@{symbol = "XCASH"; port = 10440; fee = 0.9; rpc = "xcash"}
    [PSCustomObject]@{symbol = "XEQ";   port = 10600; fee = 0.9; rpc = "equilibria"}
    [PSCustomObject]@{symbol = "XEQ";   port = 10600; fee = 0.9; rpc = "equilibria"; symbol2 = "NBX"; units2=1e2}
    [PSCustomObject]@{symbol = "XHV";   port = 10140; fee = 0.9; rpc = "haven"}
    [PSCustomObject]@{symbol = "XLA";   port = 10130; fee = 0.9; rpc = "scala"}
    [PSCustomObject]@{symbol = "XMR";   port = 10190; fee = 0.9; rpc = "monero"}
    [PSCustomObject]@{symbol = "XWP";   port = 10441; fee = 0.9; rpc = "swap"; divisor = 32}
)

$Pools_Data | Where-Object {$Config.Pools.$Name.Wallets."$($_.symbol)" -and (-not $_.symbol2 -or $Config.Pools.$Name.Wallets."$($_.symbol2)")} | Foreach-Object {
    $Pool_Currency = $_.symbol
    $Pool_Currency2 = $_.symbol2
    $Pool_RpcPath  = $_.rpc.ToLower()

    $Pool_Request = [PSCustomObject]@{}
    $Request = [PSCustomObject]@{}

    try {
        $Pool_Request = Invoke-RestMethodAsync "https://$($Pool_RpcPath).herominers.com/api/stats" -tag $Name -timeout 15 -cycletime 120
        $Divisor = [Decimal]$Pool_Request.config.coinUnits

        $Request = Invoke-RestMethodAsync "https://$($Pool_RpcPath).herominers.com/api/stats_address?address=$(Get-UrlEncode (Get-WalletWithPaymentId ($Config.Pools.$Name.Wallets.$Pool_Currency -replace "^solo:")))" -delay 100 -cycletime ($Config.BalanceUpdateMinutes*60) -timeout 15
        if (-not $Request.stats -or -not $Divisor) {
            Write-Log -Level Info "Pool Balance API ($Name) for $($Pool_Currency) returned nothing. "
        } else {
            $Pending = ($Request.blocks | Where-Object {$_ -match "^\d+?:\d+?:\d+?:\d+?:\d+?:(\d+?):"} | Foreach-Object {[int64]$Matches[1]} | Measure-Object -Sum).Sum / $Divisor
            [PSCustomObject]@{
                Caption     = "$($Name) ($Pool_Currency)"
                Currency    = $Pool_Currency
                Balance     = [Decimal]$Request.stats.balance / $Divisor
                Pending     = [Decimal]$Pending
                Total       = [Decimal]$Request.stats.balance / $Divisor + [Decimal]$Pending
                Paid        = [Decimal]$Request.stats.paid / $Divisor
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
