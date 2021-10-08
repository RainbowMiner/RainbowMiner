using module ..\Modules\Include.psm1

param(
    $Config
)

$Name = Get-Item $MyInvocation.MyCommand.Path | Select-Object -ExpandProperty BaseName

$Pools_Data = @(
    [PSCustomObject]@{rpc = "etc.crazypool.org"; symbol = "ETC"; port = @(7000,7777); fee = 1}
    [PSCustomObject]@{rpc = "eth.crazypool.org"; symbol = "ETH"; port = @(3333,5555); fee = 1}
    [PSCustomObject]@{rpc = "ubq.crazypool.org"; symbol = "UBQ"; port = @(3335); fee = 1}
)

$Count = 0
$Pools_Data | Where-Object {$Config.Pools.$Name.Wallets."$($_.symbol)" -and (-not $Config.ExcludeCoinsymbolBalances.Count -or $Config.ExcludeCoinsymbolBalances -notcontains "$($_.symbol)")} | Foreach-Object {
    $Request = [PSCustomObject]@{}
    try {
        $Request = Invoke-RestMethodAsync "https://$($_.rpc)/api/accounts/$($Config.Pools.$Name.Wallets."$($_.symbol)")" -delay $(if ($Count){500} else {0}) -cycletime ($Config.BalanceUpdateMinutes*60) -fixbigint
        $Count++
        if (-not $Request.stats) {
            Write-Log -Level Info "Pool Balance API ($Name) for $($_.symbol) returned nothing. "            
        } else {
			$Divisor = [Decimal]1e9
            [PSCustomObject]@{
                Caption     = "$($Name) ($($_.symbol))"
				BaseName    = $Name
                Currency    = $_.symbol
                Balance     = [Decimal]$Request.stats.balance/$Divisor
                Pending     = [Decimal]$Request.stats.pending/$Divisor
                Total       = [Decimal]$Request.stats.balance/$Divisor + [Decimal]$Request.stats.pending/$Divisor
                Paid        = [Decimal]$Request.stats.paid/$Divisor
                Earned      = [Decimal]0
                Payouts     = @(Get-BalancesPayouts $Request.payments -Divisor $Divisor)
                LastUpdated = (Get-Date).ToUniversalTime()
            }
        }
    }
    catch {
        if ($Error.Count){$Error.RemoveAt(0)}
        Write-Log -Level Warn "Pool Balance API ($Name) for $($_.Name) has failed. "
    }
}
