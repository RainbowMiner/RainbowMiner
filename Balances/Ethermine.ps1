﻿using module ..\Modules\Include.psm1

param(
    $Config
)

$Name = Get-Item $MyInvocation.MyCommand.Path | Select-Object -ExpandProperty BaseName

$Pools_Data = @(
    [PSCustomObject]@{regions = @("asia","eu","useast");          host = "-etc.ethermine.org"; rpc = "api-etc.ethermine.org"; symbol = "ETC"; port = 4444; fee = 1; divisor = 1000000}
    [PSCustomObject]@{regions = @("asia","eu","uswest","useast"); host = ".ethermine.org";     rpc = "api.ethermine.org";     symbol = "ETH"; port = 4444; fee = 1; divisor = 1000000}
)

$Count = 0
$Pools_Data | Where-Object {$Config.Pools.$Name.Wallets."$($_.symbol)" -and (-not $Config.ExcludeCoinsymbolBalances.Count -or $Config.ExcludeCoinsymbolBalances -notcontains "$($_.symbol)")} | Foreach-Object {
    $Request = [PSCustomObject]@{}
    try {
        $Request = Invoke-RestMethodAsync "https://$($_.rpc)/miner/$($Config.Pools.$Name.Wallets."$($_.symbol)" -replace "^0x")/dashboard" -delay $(if ($Count){500} else {0}) -cycletime ($Config.BalanceUpdateMinutes*60) -fixbigint
        $Count++
        if ($Request.status -ne "OK") {
            Write-Log -Level Info "Pool Balance API ($Name) for $($_.symbol) returned nothing. "            
        } else {
			$Divisor = [Decimal]1e18
            [PSCustomObject]@{
                Caption     = "$($Name) ($($_.symbol))"
				BaseName    = $Name
                Currency    = $_.symbol
                Balance     = [Decimal]$Request.data.currentStatistics.unpaid/$Divisor
                Pending     = [Decimal]$Request.data.currentStatistics.unconfirmed/$Divisor
                Total       = [Decimal]$Request.data.currentStatistics.unpaid/$Divisor + [Decimal]$Request.data.currentStatistics.unconfirmed/$Divisor
                Paid        = [Decimal]0
                Earned      = [Decimal]0
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
