﻿using module ..\Modules\Include.psm1

param(
    $Config
)

$Name = Get-Item $MyInvocation.MyCommand.Path | Select-Object -ExpandProperty BaseName

$Payout_Currencies = $Config.Pools.$Name.Wallets.PSObject.Properties | Where-Object Value | Select-Object Name,Value -Unique | Sort-Object Name,Value

if (-not $Payout_Currencies) {
    Write-Log -Level Verbose "Cannot get balance on pool ($Name) - no wallet address specified. "
    return
}

try {
    $Pools_Request = Invoke-RestMethodAsync "http://cpu-pool.com/api/stats" -tag $Name -timeout 15 -cycletime 120
    if ($Pools_Request -is [string]) {
        $Pools_Request = ConvertFrom-Json "$($Pools_Request -replace '"workers":{".+?}},')" -ErrorAction Stop
    }
}
catch {
    if ($Error.Count){$Error.RemoveAt(0)}
    Write-Log -Level Warn "Pool API ($Name) has failed. "
    return
}

$Count = 0
$Payout_Currencies | Where-Object {@($Pools_Request.pools.PSObject.Properties.Value | Select-Object -ExpandProperty symbol -Unique) -icontains $_.Name -and (-not $Config.ExcludeCoinsymbolBalances.Count -or $Config.ExcludeCoinsymbolBalances -notcontains "$($_.Name)")} | Foreach-Object {
    $Request = [PSCustomObject]@{}
    try {
        $Request = Invoke-RestMethodAsync "http://cpu-pool.com/api/worker_stats?$($_.Value)" -delay $(if ($Count){500} else {0}) -cycletime ($Config.BalanceUpdateMinutes*60)
        $Count++
        if ($Request.miner -ne $_.Value) {
            Write-Log -Level Info "Pool Balance API ($Name) for $($_.Name) returned nothing. "
        } else {
            [PSCustomObject]@{
                Caption     = "$($Name) ($($_.Name))"
				BaseName    = $Name
                Currency    = $_.Name
                Balance     = [Decimal]$Request.balance
                Pending     = [Decimal]$Request.immature
                Total       = [Decimal]$Request.balance + [Decimal]$Request.immature
                Paid        = [Decimal]$Request.paid
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