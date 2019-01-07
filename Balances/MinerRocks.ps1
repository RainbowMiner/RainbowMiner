param(
    $Config
)

$Name = Get-Item $MyInvocation.MyCommand.Path | Select-Object -ExpandProperty BaseName

$Pools_Data = @(
    [PSCustomObject]@{coin = "Boolberry"; symbol = "BBR"; algo = "wildkeccak"; port = 5555; fee = 0.9; walletSymbol = "boolberry"; host = "boolberry.miner.rocks"; region = "eu"}
    [PSCustomObject]@{coin = "Purk"; symbol = "PURK"; algo = "wildkeccak"; port = 5555; fee = 0.9; walletSymbol = "purk"; host = "purk.miner.rocks"; region = "eu"}
    [PSCustomObject]@{coin = "QRL"; symbol = "QRL"; algo = "CnV7"; port = 9111; fee = 0.9; walletSymbol = "qrl"; host = "qrl.miner.rocks"; region = "eu"}
    [PSCustomObject]@{coin = "Stellite"; symbol = "XTL"; algo = "CnXTL"; port = 4005; fee = 0.9; walletSymbol = "stellite"; host = "stellite.miner.rocks"; region = "eu"}
    [PSCustomObject]@{coin = "Graft"; symbol = "GRFT"; algo = "CnV8"; port = 4005; fee = 0.9; walletSymbol = "graft"; host = "graft.miner.rocks"; region = "eu"}
    [PSCustomObject]@{coin = "Monero"; symbol = "XMR"; algo = "CnV8"; port = 5555; fee = 0.9; walletSymbol = "monero"; host = "monero.miner.rocks"; region = "eu"}
    [PSCustomObject]@{coin = "Loki"; symbol = "LOKI"; algo = "CnHeavy"; port = 5555; fee = 0.9; walletSymbol = "loki"; host = "loki.miner.rocks"; region = "eu"}
    [PSCustomObject]@{coin = "Ryo"; symbol = "RYO"; algo = "CnHeavy"; port = 5555; fee = 0.9; walletSymbol = "ryo"; host = "ryo.miner.rocks"; region = "eu"}
    [PSCustomObject]@{coin = "Haven"; symbol = "XHV"; algo = "CnHeavyXhv"; port = 4005; fee = 0.9; walletSymbol = "haven"; host = "haven.miner.rocks"; region = "eu"}
    [PSCustomObject]@{coin = "Saronite"; symbol = "XRN"; algo = "CnHeavyXhv"; port = 5555; fee = 0.9; walletSymbol = "haven"; host = "saronite.miner.rocks"; region = "eu"}
    [PSCustomObject]@{coin = "BitTube"; symbol = "TUBE"; algo = "CnSaber"; port = 5555; fee = 0.9; walletSymbol = "bittube"; host = "bittube.miner.rocks"; region = "eu"}
    [PSCustomObject]@{coin = "Aeon"; symbol = "AEON"; algo = "CnLiteV7"; port = 5555; fee = 0.9; walletSymbol = "aeon"; host = "aeon.miner.rocks"; region = "eu"}
    [PSCustomObject]@{coin = "Turtlecoin"; symbol = "TRTL"; algo = "CnLiteV7"; port = 5555; fee = 0.9; walletSymbol = "turtle"; host = "turtle.miner.rocks"; region = "eu"}
    [PSCustomObject]@{coin = "Masari"; symbol = "MSR"; algo = "CnFast"; port = 5555; fee = 0.9; walletSymbol = "masari"; host = "masari.miner.rocks"; region = "eu"}
)

$Pools_Data | Where-Object {$Config.Pools.$Name.Wallets."$($_.symbol)"} | Foreach-Object {
    $Pool_Currency = $_.symbol
    $Pool_RpcPath = $_.walletSymbol.ToLower()

    $Pool_Request = [PSCustomObject]@{}
    $Request = [PSCustomObject]@{}

    try {
        $Pool_Request = Invoke-RestMethodAsync "https://$($Pool_RpcPath).miner.rocks/api/stats" -tag $Name
        $Divisor = $Pool_Request.config.coinUnits

        $Request = Invoke-RestMethodAsync "https://$($Pool_RpcPath).miner.rocks/api/stats_address?address=$($Config.Pools.$Name.Wallets.$Pool_Currency)" -delay 100 -cycletime ($Config.BalanceUpdateMinutes*60)
        if (-not $Request.stats -or -not $Divisor) {
            Write-Log -Level Info "Pool Balance API ($Name) for $($_.Name) returned nothing. "
        } else {
            [PSCustomObject]@{
                Caption     = "$($Name) ($Pool_Currency)"
                Currency    = $Pool_Currency
                Balance     = $Request.stats.balance / $Divisor
                Pending     = $Request.stats.pendingIncome / $Divisor
                Total       = $Request.stats.balance / $Divisor + $Request.stats.pendingIncome / $Divisor
                Payed       = $Request.stats.paid / $Divisor
                Payouts     = @($i=0;$Request.payments | Where-Object {$_ -match "^(.+?):(\d+?):"} | Foreach-Object {[PSCustomObject]@{time=$Request.payments[$i+1];amount=$Matches[2] / $Divisor;txid=$Matches[1]};$i+=2})
                LastUpdated = (Get-Date).ToUniversalTime()
            }
        }
    }
    catch {
        if ($Error.Count){$Error.RemoveAt(0)}
        Write-Log -Level Verbose "Pool Balance API ($Name) for $($_.Name) has failed. "
    }
}
