param(
    $Config
)

$Name = Get-Item $MyInvocation.MyCommand.Path | Select-Object -ExpandProperty BaseName

$Pools_Data = @(
    [PSCustomObject]@{symbol = "BBR";   port = 5577; fee = 0.5; rpc = "boolberry"; scratchpad = "http://#region#-bbr.luckypool.io/scratchpad.bin"; region = @("asia","eu")}
    [PSCustomObject]@{symbol = "RYO";   port = 7777; fee = 0.9; rpc = "ryo"; region = @("eu")}
    [PSCustomObject]@{symbol = "XCASH"; port = 4477; fee = 0.9; rpc = "xcash"; region = @("eu")}
    [PSCustomObject]@{symbol = "XWP";   port = 4888; fee = 0.9; rpc = "swap2"; divisor = 32; region = @("eu")}
    [PSCustomObject]@{symbol = "ZANO";  port = 8877; fee = 0.9; rpc = "zano"; region = @("eu")}
)

$Pools_Data | Where-Object {$Config.Pools.$Name.Wallets."$($_.symbol)"} | Foreach-Object {
    $Pool_Currency = $_.symbol
    $Pool_RpcPath = $_.rpc

    $Pool_Request = [PSCustomObject]@{}
    $Request = [PSCustomObject]@{}

    try {
        $Pool_Request = Invoke-RestMethodAsync "https://$($Pool_RpcPath).luckypool.io/api/stats" -tag $Name -cycletime 120
        $Divisor = [Decimal]$Pool_Request.config.coinUnits

        $Request = Invoke-RestMethodAsync "https://$($Pool_RpcPath).luckypool.io/api/stats_address?address=$(Get-WalletWithPaymentId $Config.Pools.$Name.Wallets.$Pool_Currency -pidchar '')" -delay 100 -cycletime ($Config.BalanceUpdateMinutes*60) -timeout 15
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
