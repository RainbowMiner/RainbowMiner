param(
    $Config
)

$Name = Get-Item $MyInvocation.MyCommand.Path | Select-Object -ExpandProperty BaseName

$Pools_Data = @(
    [PSCustomObject]@{coin = "Boolberry";   symbol = "BBR";  algo = "wildkeccak"; port = 5555; fee = 0.9; rpc = "boolberry"}

    [PSCustomObject]@{coin = "Loki";        symbol = "LOKI"; algo = "RxLoki";     port = 5005; fee = 0.9; rpc = "loki"}

    [PSCustomObject]@{coin = "Masari";      symbol = "MSR";  algo = "CnHalf";     port = 5005; fee = 0.9; rpc = "masari";   regions = @("eu","sg")}
    [PSCustomObject]@{coin = "Scala";       symbol = "XLA";  algo = "CnHalf";     port = 5005; fee = 0.9; rpc = "stellite"; regions = @("eu","sg")}
    [PSCustomObject]@{coin = "Scala";       symbol = "XTC";  algo = "CnHalf";     port = 5005; fee = 0.9; rpc = "stellite"; regions = @("eu","sg")}

    [PSCustomObject]@{coin = "Monero";      symbol = "XMR";  algo = "CnR";        port = 5551; fee = 0.9; rpc = "monero"}
    [PSCustomObject]@{coin = "Sumokoin";    symbol = "SUMO"; algo = "CnR";        port = 4003; fee = 0.9; rpc = "sumokoin"}

    [PSCustomObject]@{coin = "Haven";       symbol = "XHV";  algo = "CnHaven";    port = 4005; fee = 0.9; rpc = "haven"; regions = @("eu","ca","sg")}

    [PSCustomObject]@{coin = "BitTube";     symbol = "TUBE"; algo = "CnSaber";    port = 5555; fee = 0.9; rpc = "bittube"; regions = @("eu","ca","sg")}

    [PSCustomObject]@{coin = "Aeon";        symbol = "AEON"; algo = "CnLiteV7";   port = 5555; fee = 0.9; rpc = "aeon"}

    [PSCustomObject]@{coin = "Turtle";      symbol = "TRTL"; algo = "CnTurtle";   port = 5005; fee = 0.9; rpc = "turtle"}

    [PSCustomObject]@{coin = "Ryo";         symbol = "RYO";  algo = "CnGpu";      port = 5555; fee = 1.2; rpc = "ryo"}

    [PSCustomObject]@{coin = "Graft";       symbol = "GRFT"; algo = "CnRwz";      port = 5005; fee = 0.9; rpc = "graft"}
)

$Pools_Data | Where-Object {$Config.Pools.$Name.Wallets."$($_.symbol)"} | Foreach-Object {
    $Pool_Currency = $_.symbol
    $Pool_RpcPath = $_.rpc

    $Pool_Request = [PSCustomObject]@{}
    $Request = [PSCustomObject]@{}

    try {
        $Pool_Request = Invoke-RestMethodAsync "https://$($Pool_RpcPath).miner.rocks/api/stats" -tag $Name
        $Divisor = [Decimal]$Pool_Request.config.coinUnits

        $Request = Invoke-RestMethodAsync "https://$($Pool_RpcPath).miner.rocks/api/stats_address?address=$(Get-WalletWithPaymentId $Config.Pools.$Name.Wallets.$Pool_Currency -pidchar '.')" -delay 100 -cycletime ($Config.BalanceUpdateMinutes*60)
        if (-not $Request.stats -or -not $Divisor) {
            Write-Log -Level Info "Pool Balance API ($Name) for $($_.Name) returned nothing. "
        } else {
            [PSCustomObject]@{
                Caption     = "$($Name) ($Pool_Currency)"
                Currency    = $Pool_Currency
                Balance     = [Decimal]$Request.stats.balance / $Divisor
                Pending     = [Decimal]$Request.stats.pendingIncome / $Divisor
                Total       = [Decimal]$Request.stats.balance / $Divisor + [Decimal]$Request.stats.pendingIncome / $Divisor
                Paid        = [Decimal]$Request.stats.paid / $Divisor
                Payouts     = @($i=0;$Request.payments | Where-Object {$_ -match "^(.+?):(\d+?):"} | Foreach-Object {[PSCustomObject]@{time=$Request.payments[$i+1];amount=[Decimal]$Matches[2] / $Divisor;txid=$Matches[1]};$i+=2})
                LastUpdated = (Get-Date).ToUniversalTime()
            }
        }
    }
    catch {
        if ($Error.Count){$Error.RemoveAt(0)}
        Write-Log -Level Verbose "Pool Balance API ($Name) for $($_.Name) has failed. "
    }
}
