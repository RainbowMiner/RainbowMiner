using module ..\Modules\Include.psm1

param(
    $Config
)

#https://turtle.hashvault.pro/api/miner/TRTLv1Hqo3wHdqLRXuCyX3MwvzKyxzwXeBtycnkDy8ceFp4E23bm3P467xLEbUusH6Q1mqQUBiYwJ2yULJbvr5nKe8kcyc4uyps.2b66ef38b93ed6d9c9bfe9af2ebc2e830eb422f9a0c9c0e9147e55fc2579da0f/stats
$Name = Get-Item $MyInvocation.MyCommand.Path | Select-Object -ExpandProperty BaseName

$Pools_Data = @(
    [PSCustomObject]@{symbol = "AEON";  port = 3333; fee = 0.9; rpc = "aeon"} #pool.aeon.hashvault.pro:3333
    [PSCustomObject]@{symbol = "CCX";   port = 3333; fee = 0.9; rpc = "conceal"} #pool.conceal.hashvault.pro:3333
    [PSCustomObject]@{symbol = "GRFT";  port = 3333; fee = 0.9; rpc = "graft"} #pool.graft.hashvault.pro:3333
    [PSCustomObject]@{symbol = "KVA";   port = 3333; fee = 0.9; rpc = "kevacoin"} #pool.hashvault.pro:3333
    [PSCustomObject]@{symbol = "LTHN";  port = 3333; fee = 0.9; rpc = "lethean"} #pool.lethean.hashvault.pro:3333
    [PSCustomObject]@{symbol = "LOKI";  port = 3333; fee = 0.9; rpc = "loki"} #pool.loki.hashvault.pro:3333
    [PSCustomObject]@{symbol = "MSR";   port = 3333; fee = 0.9; rpc = "masari"} #pool.masari.hashvault.pro:3333
    [PSCustomObject]@{symbol = "RYO";   port = 3333; fee = 0.9; rpc = "ryo"} #pool.ryo.hashvault.pro:3333
    [PSCustomObject]@{symbol = "SUMO";  port = 3333; fee = 0.9; rpc = "sumo"} #pool.sumo.hashvault.pro:3333
    [PSCustomObject]@{symbol = "TUBE";  port = 3333; fee = 0.9; rpc = "bittube"} #pool.bittube.hashvault.pro:3333
    [PSCustomObject]@{symbol = "TRTL";  port = 3333; fee = 0.9; rpc = "turtle"} #pool.turtle.hashvault.pro:3333
    [PSCustomObject]@{symbol = "WOW";   port = 3333; fee = 0.9; rpc = "wownero"} #pool.wownero.hashvault.pro:3333
    [PSCustomObject]@{symbol = "XHV";   port = 3333; fee = 0.9; rpc = "haven"} #pool.haven.hashvault.pro:3333
    [PSCustomObject]@{symbol = "XMR";   port = 3333; fee = 0.9; rpc = "monero"} #pool.hashvault.pro:3333
    [PSCustomObject]@{symbol = "XWP";   port = 3333; fee = 0.9; rpc = "swap"} #pool.swap.hashvault.pro:3333
)

$Pools_Data | Where-Object {$Config.Pools.$Name.Wallets."$($_.symbol)" -and (-not $Config.ExcludeCoinsymbolBalances.Count -or $Config.ExcludeCoinsymbolBalances -notcontains "$($_.symbol)")} | Foreach-Object {
    $Pool_Currency = $_.symbol
    $Pool_RpcPath  = $_.rpc

    $Pool_Request = [PSCustomObject]@{}
    $Request = [PSCustomObject]@{}

    try {
        $Pool_Request = Invoke-RestMethodAsync "https://api.hashvault.pro/v3/$($Pool_RpcPath)/stats" -tag $Name -timeout 15 -cycletime 120
        $coinUnits    = [decimal]$Pool_Request.config.sigDivisor

        $Request = Invoke-RestMethodAsync "https://api.hashvault.pro/v3/$($Pool_RpcPath)/wallet/$(Get-UrlEncode (Get-WalletWithPaymentId ($Config.Pools.$Name.Wallets.$Pool_Currency) -pidchar '.'))/stats?chart=false&poolType=false&workers=false" -delay 100 -cycletime ($Config.BalanceUpdateMinutes*60) -timeout 15

        if (-not $Request -or -not $coinUnits) {
            Write-Log -Level Info "Pool Balance API ($Name) for $($Pool_Currency) returned nothing. "
        } else {
            [PSCustomObject]@{
                Caption     = "$($Name) ($Pool_Currency)"
				BaseName    = $Name
                Currency    = $Pool_Currency
                Balance     = [Decimal]$Request.revenue.confirmedBalance / $coinUnits
                Pending     = 0
                Total       = [Decimal]$Request.revenue.confirmedBalance / $coinUnits
                Paid        = [Decimal]$Request.revenue.totalPaid / $coinUnits
                Paid24h     = [Decimal]$Request.revenue.dailyPaid / $coinUnits
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
