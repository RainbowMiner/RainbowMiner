param(
    $Config
)

$Name = Get-Item $MyInvocation.MyCommand.Path | Select-Object -ExpandProperty BaseName

$Pools_Data = @(
    #[PSCustomObject]@{coin = "Caliber"; symbol = "CAL"; algo = "CnV8"; port = 5588; fee = 0.9; walletSymbol = "caliber"; host = "caliber.luckypool.io"}
    #[PSCustomObject]@{coin = "CitiCash"; symbol = "CCH"; algo = "CnHeavy"; port = 3888; fee = 0.9; walletSymbol = "citicash"; host = "citicash.luckypool.io"}
    #[PSCustomObject]@{coin = "Graft"; symbol = "GRFT"; algo = "CnRwz"; port = 5588; fee = 0.9; walletSymbol = "graft"; host = "graft.luckypool.io"}
    #[PSCustomObject]@{coin = "Haven"; symbol = "XHV"; algo = "CnHaven"; port = 7788; fee = 0.9; walletSymbol = "haven"; host = "haven.luckypool.io"}
    #[PSCustomObject]@{coin = "JyoCoin"; symbol = "JYO"; algo = "CnV8"; port = 5008; fee = 0.9; walletSymbol = "jyo"; host = "jyo.luckypool.io"}
    #[PSCustomObject]@{coin = "SafexCash"; symbol = "SFX"; algo = "CnV8"; port = 3388; fee = 0.9; walletSymbol = "sfx"; host = "safex.luckypool.io"}
    [PSCustomObject]@{coin = "Swap"; symbol = "XWP"; algo = "Cuckaroo29s"; port = 4888; fee = 0.9; walletSymbol = "swap2"; host = "swap2.luckypool.io"; divisor = 32}
    #[PSCustomObject]@{coin = "WowNero"; symbol = "WOW"; algo = "CnWow"; port = 4488; fee = 0.9; walletSymbol = "wownero"; host = "wownero.luckypool.io"}
    #[PSCustomObject]@{coin = "Xcash"; symbol = "XCASH"; algo = "CnHeavyX"; port = 4488; fee = 0.9; walletSymbol = "xcash"; host = "xcash.luckypool.io"}
)

$Pools_Data | Where-Object {$Config.Pools.$Name.Wallets."$($_.symbol)"} | Foreach-Object {
    $Pool_Currency = $_.symbol
    $Pool_RpcPath = $_.walletSymbol.ToLower()

    $Pool_Request = [PSCustomObject]@{}
    $Request = [PSCustomObject]@{}

    try {
        $Pool_Request = Invoke-RestMethodAsync "https://$($Pool_RpcPath).luckypool.io/api/stats" -tag $Name -cycletime 120
        $Divisor = $Pool_Request.config.coinUnits

        $Request = Invoke-RestMethodAsync "https://$($Pool_RpcPath).luckypool.io/api/stats_address?address=$($Config.Pools.$Name.Wallets.$Pool_Currency -replace "\..+$" -replace "\+.+$")" -delay 100 -cycletime ($Config.BalanceUpdateMinutes*60) -timeout 15
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
