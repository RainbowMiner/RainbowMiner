using module ..\Include.psm1

param(
    $Config
)

$Name = Get-Item $MyInvocation.MyCommand.Path | Select-Object -ExpandProperty BaseName
$PoolConfig = $Config.Pools.$Name

if (!$PoolConfig.XMR) {
    Write-Log -Level Verbose "Pool Balance API ($Name) has failed - no wallet address specified. "
    return
}

$Request = [PSCustomObject]@{}

try {
    $Request = Invoke-RestMethodAsync "https://api.moneroocean.stream/miner/$($PoolConfig.XMR)/stats" -cycletime ($Config.BalanceUpdateMinutes*60)
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
    Caption     = "$($Name) (XMR)"
	BaseName    = $Name
    Currency    = "XMR"
    Balance     = [Decimal]$Request.amtDue/1e12
    Pending     = [Decimal]0
    Total       = [Decimal]$Request.amtDue/1e12
    Paid        = [Decimal]$Request.amtPaid/1e12
    Payouts     = @()
    LastUpdated = (Get-Date).ToUniversalTime()
}
