param(
    $Config
)

#https://turtle.hashvault.pro/api/miner/TRTLv1Hqo3wHdqLRXuCyX3MwvzKyxzwXeBtycnkDy8ceFp4E23bm3P467xLEbUusH6Q1mqQUBiYwJ2yULJbvr5nKe8kcyc4uyps.2b66ef38b93ed6d9c9bfe9af2ebc2e830eb422f9a0c9c0e9147e55fc2579da0f/stats
$Name = Get-Item $MyInvocation.MyCommand.Path | Select-Object -ExpandProperty BaseName

$Pools_Data = @(
    [PSCustomObject]@{symbol = "AEON";  port = 3333; fee = 0.9; rpc = "aeon"} #pool.aeon.hashvault.pro:3333
    [PSCustomObject]@{symbol = "BLOC";  port = 2222; fee = 0.9; rpc = "bloc"} #pool.bloc.hashvault.pro:2222
    [PSCustomObject]@{symbol = "CCX";   port = 3333; fee = 0.9; rpc = "conceal"} #pool.conceal.hashvault.pro:3333
    [PSCustomObject]@{symbol = "GRFT";  port = 3333; fee = 0.9; rpc = "graft"} #pool.graft.hashvault.pro:3333
    [PSCustomObject]@{symbol = "IRD";   port = 4445; fee = 0.9; rpc = "iridium"} #pool.iridium.hashvault.pro:4445
    [PSCustomObject]@{symbol = "LTHN";  port = 3333; fee = 0.9; rpc = "lethean"} #pool.lethean.hashvault.pro:3333
    [PSCustomObject]@{symbol = "LOKI";  port = 3333; fee = 0.9; rpc = "loki"} #pool.loki.hashvault.pro:3333
    [PSCustomObject]@{symbol = "MSR";   port = 3333; fee = 0.9; rpc = "masari"} #pool.masari.hashvault.pro:3333
    [PSCustomObject]@{symbol = "RYO";   port = 3333; fee = 0.9; rpc = "ryo"} #pool.ryo.hashvault.pro:3333
    [PSCustomObject]@{symbol = "SUMO";  port = 3333; fee = 0.9; rpc = "sumo"} #pool.sumo.hashvault.pro:3333
    [PSCustomObject]@{symbol = "TUBE";  port = 3333; fee = 0.9; rpc = "bittube"} #pool.bittube.hashvault.pro:3333
    [PSCustomObject]@{symbol = "TRTL";  port = 3333; fee = 0.9; rpc = "turtle"} #pool.turtle.hashvault.pro:3333
    [PSCustomObject]@{symbol = "WOW";   port = 3333; fee = 0.9; rpc = "wownero"} #pool.wownero.hashvault.pro:3333
    [PSCustomObject]@{symbol = "XTNC";  port = 3333; fee = 0.9; rpc = "xtendcash"} #pool.xtendcash.hashvault.pro:3333
    [PSCustomObject]@{symbol = "XEQ";   port = 3333; fee = 0.9; rpc = "equilibria"} #pool.equilibria.hashvault.pro:3333
    [PSCustomObject]@{symbol = "XHV";   port = 3333; fee = 0.9; rpc = "haven"} #pool.haven.hashvault.pro:3333
    [PSCustomObject]@{symbol = "XMR";   port = 3333; fee = 0.9; rpc = "monero"} #pool.hashvault.pro:3333
    [PSCustomObject]@{symbol = "XWP";   port = 3333; fee = 0.9; rpc = "swap"} #pool.swap.hashvault.pro:3333
)

$Pools_Data | Where-Object {$Config.Pools.$Name.Wallets."$($_.symbol)"} | Foreach-Object {
    $Pool_Currency = $_.symbol
    $Pool_RpcPath  = $_.rpc

    $Pool_Request = [PSCustomObject]@{}
    $Request = [PSCustomObject]@{}

    try {
        $Pool_Request = Invoke-RestMethodAsync "https://$($Pool_RpcPath).hashvault.pro/api/stats" -tag $Name -timeout 15 -cycletime 120
        $coinUnits    = [decimal]$Pool_Request.config.sigDivisor

        $Request = Invoke-RestMethodAsync "https://$($Pool_RpcPath).hashvault.pro/api/miner/$(Get-UrlEncode (Get-WalletWithPaymentId ($Config.Pools.$Name.Wallets.$Pool_Currency) -pidchar '.'))/stats" -delay 100 -cycletime ($Config.BalanceUpdateMinutes*60) -timeout 15

        if (-not $Request -or -not $coinUnits) {
            Write-Log -Level Info "Pool Balance API ($Name) for $($Pool_Currency) returned nothing. "
        } else {
            [PSCustomObject]@{
                Caption     = "$($Name) ($Pool_Currency)"
                Currency    = $Pool_Currency
                Balance     = [Decimal]$Request.amtDue / $coinUnits
                Pending     = 0
                Total       = [Decimal]$Request.amtDue / $coinUnits
                Paid        = [Decimal]$Request.amtPaid / $coinUnits
                Paid24h     = [Decimal]$Request.amtDailyPayouts / $coinUnits
                Payouts     = @()
                LastUpdated = (Get-Date).ToUniversalTime()
            }
        }
    }
    catch {
        if ($Error.Count){$Error.RemoveAt(0)}
        Write-Log -Level Verbose "Pool Balance API ($Name) for $($Pool_Currency) has failed. "
    }
}
