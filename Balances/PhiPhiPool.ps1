using module ..\Include.psm1

param(
    $Config
)
$Name = Get-Item $MyInvocation.MyCommand.Path | Select-Object -ExpandProperty BaseName
$PoolConfig = $Config.Pools.$Name

if (!$PoolConfig.BTC) {
    Write-Log -Level Verbose "Cannot get balance on pool ($Name) - no wallet address specified. "
    return
}

$Request = [PSCustomObject]@{}

try {
    $Request = Invoke-RestMethod "http://www.phi-phi-pool.com/api/walletEx?address=$($PoolConfig.BTC)" -UseBasicParsing -TimeoutSec 10 -ErrorAction Stop
}
catch {
    $Error.Remove($Error[$Error.Count - 1])
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
    Total       = $Request.unpaid
    Payed       = $Request.total - $Request.unpaid
    Earned      = $Request.total
    Payouts     = @($Request.payouts | Select-Object)
    LastUpdated = (Get-Date).ToUniversalTime()
}