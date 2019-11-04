param(
    $Config
)

$Name = Get-Item $MyInvocation.MyCommand.Path | Select-Object -ExpandProperty BaseName
$PoolConfig = $Config.Pools.$Name

if (!$PoolConfig.BTC) {
    Write-Log -Level Verbose "Pool Balance API ($Name) has failed - no wallet address specified."
    return
}

$Request = [PSCustomObject]@{}

try {
    $Request = Invoke-RestMethodAsync "https://www.ahashpool.com/api/wallet?addressEx=$($PoolConfig.BTC)" -cycletime ($Config.BalanceUpdateMinutes*60)
}
catch {
    if ($Error.Count){$Error.RemoveAt(0)}
    Write-Log -Level Warn "Pool Balance API ($Name) has failed. "
    return
}

if (($Request | Get-Member -MemberType NoteProperty -ErrorAction Ignore | Measure-Object Name).Count -le 1) {
    Write-Log -Level Info "Pool Balance API ($Name) returned nothing. "
    return
}

[PSCustomObject]@{
    Caption     = "$($Name) ($($Request.currency))"
	BaseName    = $Name
    Currency    = $Request.currency
    Balance     = [Decimal]$Request.balance
    Pending     = [Decimal]$Request.unsold
    Total       = [Decimal]$Request.total_unpaid
    Paid        = [Decimal]$Request.total_paid
    Earned      = [Decimal]$Request.total_earned
    Payouts     = @(Get-BalancesPayouts $Request.payouts | Select-Object)
    LastUpdated = (Get-Date).ToUniversalTime()
}
