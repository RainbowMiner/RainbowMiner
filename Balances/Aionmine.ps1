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

$Pool_Request = [PSCustomObject]@{}

try {
    $Pool_Request = Invoke-RestMethodAsync "https://api.aionmine.org/api/pools" -tag $Name -retry 3 -retrywait 1000 -cycletime 120
    if (-not $Pool_Request.pools) {throw}
}
catch {
    if ($Error.Count){$Error.RemoveAt(0)}
    Write-Log -Level Warn "Pool API ($Name) for $($Pool_Currency) has failed. "
    return
}

$Count = 0
$Payout_Currencies | Where-Object {@($Pool_Request.pools | Foreach-Object {$_.coin.type} | Select-Object -Unique) -icontains $_.Name} | Foreach-Object {
    $id = $Pool_Request.pools | Where-Object {$_.coin.type -eq $_.Name} | Select-Object -ExpandProperty id
    try {
        $Request = Invoke-RestMethodAsync "https://api.aionmine.org/api/pools/aion/miners/$($_.Value)" -delay $(if ($Count){500} else {0}) -cycletime ($Config.BalanceUpdateMinutes*60)
        $Count++
        if ($Request.totalPaid -eq $null) {
            Write-Log -Level Info "Pool Balance API ($Name) for $($_.Name) returned nothing. "
        } else {
            [PSCustomObject]@{
                Caption     = "$($Name) ($($_.Name))"
				BaseName    = $Name
                Currency    = $_.Name
                Balance     = [Decimal]$Request.pendingBalance
                Pending     = [Decimal]0
                Total       = [Decimal]$Request.pendingBalance
                Paid        = [Decimal]$Request.totalPaid
                Payouts     = @()
                LastUpdated = (Get-Date).ToUniversalTime()
            }
        }
    }
    catch {
        if ($Error.Count){$Error.RemoveAt(0)}
        Write-Log -Level Warn "Pool Balance API ($Name) for $($_.Name) has failed. "
    }
}
