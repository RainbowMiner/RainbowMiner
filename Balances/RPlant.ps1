﻿using module ..\Modules\Include.psm1

param(
    $Config
)

$Name = Get-Item $MyInvocation.MyCommand.Path | Select-Object -ExpandProperty BaseName

$Payout_Currencies = $Config.Pools.$Name.Wallets.PSObject.Properties | Where-Object Value | Select-Object Name,Value -Unique | Sort-Object Name,Value

return # currently out-of-order

if (-not $Payout_Currencies) {
    Write-Log -Level Verbose "Cannot get balance on pool ($Name) - no wallet address specified. "
    return
}

try {
    $Pools_Request = Invoke-RestMethodAsync "https://pool.rplant.xyz/api/stats" -tag $Name -timeout 15 -cycletime 120
}
catch {
    if ($Error.Count){$Error.RemoveAt(0)}
    Write-Log -Level Warn "Pool API ($Name) has failed. "
    return
}

$Count = 0
$Payout_Currencies | Where-Object {@($Pools_Request.pools.PSObject.Properties.Value | Select-Object -ExpandProperty symbol -Unique) -icontains $_.Name -and (-not $Config.ExcludeCoinsymbolBalances.Count -or $Config.ExcludeCoinsymbolBalances -notcontains $_.Name)} | Foreach-Object {
    $Pool_Currency = $_.Name
    $Pool_Name = "$($Pools_Request.pools.PSObject.Properties | Where-Object {$_.Value.symbol -eq $Pool_Currency} | Foreach-Object {$_.Name} | Select-Object -First 1)"
    if ($Pool_Name) {
        $Request = [PSCustomObject]@{}
        try {
            $Request = Invoke-RestMethodAsync "https://pool.rplant.xyz/api/wallet/$($Pool_Name)/$($_.Value)" -delay $(if ($Count){500} else {0}) -cycletime ($Config.BalanceUpdateMinutes*60)
            $Count++
            if (-not $Request.address) {
                Write-Log -Level Info "Pool Balance API ($Name) for $($Pool_Currency) returned nothing. "
            } else {
                [PSCustomObject]@{
                    Caption     = "$($Name) ($($Pool_Currency))"
				    BaseName    = $Name
                    Currency    = $Pool_Currency
                    Balance     = [Decimal]$Request.balance
                    Pending     = [Decimal]$Request.unsold
                    Total       = [Decimal]$Request.unpaid
                    Paid        = [Decimal]$Request.total
                    Payouts     = @()
                    LastUpdated = (Get-Date).ToUniversalTime()
                }
            }
        }
        catch {
            if ($Error.Count){$Error.RemoveAt(0)}
            Write-Log -Level Verbose "Pool Balance API ($Name) for $($_.Name) has failed. "
        }
    }
}