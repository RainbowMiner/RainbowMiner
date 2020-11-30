using module ..\Modules\Include.psm1

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

$ok = $false
try {
    $Pool_Request = Invoke-RestMethodAsync "http://88.99.47.205:26022/api/pools" -tag $Name -retry 3 -retrywait 1000 -cycletime 120
    if ($Pool_Request.pools) {$ok = $true}
}
catch {
    if ($Error.Count){$Error.RemoveAt(0)}
}

if (-not $ok) {
    Write-Log -Level Warn "Pool API ($Name) for $($Pool_Currency) has failed. "
    return
}

$Count = 0
$Payout_Currencies | Where-Object {@($Pool_Request.pools | Foreach-Object {$_.coin.type} | Select-Object -Unique) -icontains $_.Name -and (-not $Config.ExcludeCoinsymbolBalances.Count -or $Config.ExcludeCoinsymbolBalances -notcontains "$($_.Name)")} | Foreach-Object {
    try {
        $Pool_Id = ($Pool_Request.pools | Where-Object {$_.coin.type -eq $_.Name}).id
        $Request = Invoke-RestMethodAsync "http://88.99.47.205:26022/api/pools/$($Pool_Id)/miners/$($_.Value)" -delay $(if ($Count){500} else {0}) -cycletime ($Config.BalanceUpdateMinutes*60)
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
