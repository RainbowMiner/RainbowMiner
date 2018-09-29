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
    $Request = Invoke-RestMethod "http://www.ahashpool.com/api/walletEx?address=$($PoolConfig.BTC)" -UseBasicParsing -TimeoutSec 10 -ErrorAction Stop
}
catch {
    if ($Error.Count){$Error.RemoveAt(0)}
    Write-Log -Level Warn "Pool Balance API ($Name) has failed. "
    return
}

if (($Request | Get-Member -MemberType NoteProperty -ErrorAction Ignore | Measure-Object Name).Count -le 1) {
    Write-Log -Level Warn "Pool Balance API ($Name) returned nothing. "
    return
}

[PSCustomObject]@{
    Caption     = "$($Name) ($($Request.currency))"
    Currency    = $Request.currency
    Balance     = $Request.balance
    Pending     = $Request.unsold
    Total       = $Request.total_unpaid
    Paid        = $Request.total_paid
    Earned      = $Request.total_earned
    Payouts     = @($Request.payouts | Select-Object)
    LastUpdated = (Get-Date).ToUniversalTime()
}
