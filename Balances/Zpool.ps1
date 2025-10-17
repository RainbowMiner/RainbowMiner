using module ..\Modules\Include.psm1

param(
    [String]$Name,
    $Config,
    $UsePools
)

# $Name = Get-Item $MyInvocation.MyCommand.Path | Select-Object -ExpandProperty BaseName

$Request = [PSCustomObject]@{}

$Payout_Currencies = @(foreach ($PoolExt in "","Coins") {
    if (-not $UsePools -or "$Name$PoolExt" -in $UsePools) {
        $Config.Pools."$Name$PoolExt".Wallets.PSObject.Properties | Where-Object Value
    }
}) | Sort-Object Name, Value -Unique

if (-not $Payout_Currencies) {
    Write-Log -Level Verbose "Cannot get balance on pool ($Name) - no wallet address specified. "
    return
}

$Count = 0
$Payout_Currencies | Where-Object {-not $Config.ExcludeCoinsymbolBalances.Count -or $Config.ExcludeCoinsymbolBalances -notcontains $_.Name} | Foreach-Object {
    try {
        $Request = Invoke-RestMethodAsync "https://zpool.ca/api/walletEx?address=$($_.Value)" -tag $Name -delay 750 -cycletime ($Config.BalanceUpdateMinutes*60)
        $Count++
        if (($Request | Get-Member -MemberType NoteProperty -ErrorAction Ignore | Measure-Object Name).Count -le 1) {
            Write-Log -Level Info "Pool Balance API ($Name) for $($_.Name) returned nothing. "
        } else {
            [PSCustomObject]@{
                Caption     = "$($Name) ($($Request.currency))"
                Name        = $Name
				BaseName    = $Name
                Currency    = $Request.currency
                Balance     = [Decimal]$Request.balance
                Pending     = [Decimal]$Request.unsold
                Total       = [Decimal]$Request.unpaid
                #Paid        = [Decimal]$Request.total - [Decimal]$Request.unpaid
                Paid24h     = [Decimal]$Request.paid24h
                Earned      = [Decimal]$Request.total
                Payouts     = @(Get-BalancesPayouts $Request.payouts | Select-Object)
                LastUpdated = (Get-Date).ToUniversalTime()
            }
        }
    }
    catch {
        Write-Log -Level Warn "Pool Balance API ($Name) for $($_.Name) has failed. "
    }
}
