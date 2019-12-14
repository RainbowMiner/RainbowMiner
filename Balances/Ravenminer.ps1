param(
    $Config
)

$Name = Get-Item $MyInvocation.MyCommand.Path | Select-Object -ExpandProperty BaseName
$PoolConfig = $Config.Pools.$Name

if (!$PoolConfig.RVN) {
    Write-Log -Level Verbose "Pool Balance API ($Name) has failed - no wallet address specified."
    return
}

$Request = [PSCustomObject]@{}

$Ravenminer_Host = "www.ravenminer.com"

#https://www.ravenminer.com/api/wallet?address=RFtHhp8S43JDnzAJz9GDvups6pdJjBA7nM
$Success = $true
try {
    if (-not ($Request = Invoke-RestMethodAsync "https://$($Ravenminer_Host)/api/wallet?address=$($PoolConfig.RVN)" -cycletime ($Config.BalanceUpdateMinutes*60))){$Success = $false}
}
catch {
    if ($Error.Count){$Error.RemoveAt(0)}
    $Success=$false
}

if (-not $Success) {
    Write-Log -Level Warn "Pool Balance API ($Name) has failed. "
    return
}

if (($Request | Get-Member -MemberType NoteProperty -ErrorAction Ignore | Measure-Object Name).Count -le 1) {
    Write-Log -Level Info "Pool Balance API ($Name) returned nothing. "
    return
}

[PSCustomObject]@{
        Caption     = "$($Name) (RVN)"
		BaseName    = $Name
        Currency    = $Request.currency
        Balance     = [Decimal]$Request.balance
        Pending     = [Decimal]$Request.unsold
        Total       = [Decimal]$Request.unpaid
        #Paid        = [Decimal]$Request.total - [Decimal]$Request.unpaid
        Paid24h     = [Decimal]$Request.paid24h
        Earned      = [Decimal]$Request.total
        Payouts     = @()
        LastUpdated = (Get-Date).ToUniversalTime()
}