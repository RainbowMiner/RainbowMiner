param(
    $Config
)

$Name = Get-Item $MyInvocation.MyCommand.Path | Select-Object -ExpandProperty BaseName

$Request = [PSCustomObject]@{}

$Payout_Currencies = @($Config.Pools.$Name.Wallets.PSObject.Properties | Select-Object) | Where-Object Value | Select-Object Name,Value -Unique | Sort-Object Name,Value

if (-not $Payout_Currencies) {
    Write-Log -Level Verbose "Cannot get balance on pool ($Name) - no wallet address specified. "
    return
}

$Count = 0
$Payout_Currencies | Where-Object {$_.Name -eq "CTXC"} | Foreach-Object {
    try {
        $Request = Invoke-RestMethodAsync "http://www.cortexmint.com/api/accounts/$($_.Value)" -delay $(if ($Count){500} else {0}) -cycletime ($Config.BalanceUpdateMinutes*60)
        $Count++
        if ($Request.stats -eq $null) {
            Write-Log -Level Info "Pool Balance API ($Name) for $($_.Name) returned nothing. "
        } else {
            [PSCustomObject]@{
                Caption     = "$($Name) ($($_.Name))"
				BaseName    = $Name
                Currency    = $_.Name
                Balance     = [Decimal]$Request.stats.balance / 1e9
                Pending     = [Decimal]0
                Total       = [Decimal]$Request.stats.balance / 1e9
                Paid        = [Decimal]$Request.stats.paid / 1e9
                Payouts     = @(Get-BalancesPayouts $Request.payments -Divisor 1e9 | Select-Object)
                LastUpdated = (Get-Date).ToUniversalTime()
            }
        }
    }
    catch {
        if ($Error.Count){$Error.RemoveAt(0)}
        Write-Log -Level Warn "Pool Balance API ($Name) for $($_.Name) has failed. "
    }
}
