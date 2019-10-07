param(
    $Config
)

$Name = Get-Item $MyInvocation.MyCommand.Path | Select-Object -ExpandProperty BaseName

$Pools_Data = @(
    [PSCustomObject]@{symbol = "AEON"; port = 5541;  fee = 0.0; rpc = "aeon"}
    [PSCustomObject]@{symbol = "TUBE"; port = 5631;  fee = 0.0; rpc = "ipbc"; host = "tube"}
    [PSCustomObject]@{symbol = "GRFT"; port = 9111;  fee = 0.0; rpc = "graft"}
    [PSCustomObject]@{symbol = "XHV";  port = 5831;  fee = 0.0; rpc = "haven"}
    [PSCustomObject]@{symbol = "MSR";  port = 3333;  fee = 0.0; rpc = "msr"; host = "masari"}
    [PSCustomObject]@{symbol = "XMR";  port = 4441;  fee = 0.0; rpc = "xmr"; host = "monero"}
    [PSCustomObject]@{symbol = "XWP";  port = 7731;  fee = 0.0; rpc = "swap"; divisor = 32; regions = @("eu","asia")}
)

$Pools_Data | Where-Object {$Config.Pools.$Name.Wallets."$($_.symbol)"} | Foreach-Object {
    $Pool_Currency = $_.symbol
    $Pool_RpcPath = $_.rpc

    $Pool_Request = [PSCustomObject]@{}
    $Request = [PSCustomObject]@{}

    $Pool_Wallet = Get-WalletWithPaymentId $Config.Pools.$Name.Wallets."$($_.symbol)" -asobject

    if (-not $Pool_Wallet.paymentid) {
        try {
            $Pool_Request = Invoke-RestMethodAsync "https://cryptoknight.cc/rpc/$($Pool_RpcPath)/stats" -tag $Name
            $Divisor = [Decimal]$Pool_Request.config.coinUnits

            $Request = Invoke-RestMethodAsync "https://cryptoknight.cc/rpc/$($Pool_RpcPath)/stats_address?address=$($Pool_Wallet.wallet)" -delay 100 -cycletime ($Config.BalanceUpdateMinutes*60)
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
}
