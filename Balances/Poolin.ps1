using module ..\Modules\Include.psm1

param(
    [String]$Name,
    $Config
)

# $Name = Get-Item $MyInvocation.MyCommand.Path | Select-Object -ExpandProperty BaseName

$Pools_Data = @(
    [PSCustomObject]@{coin="ETC";host="etc.ss.poolin.me";fee=1.0;divisor=1}
    [PSCustomObject]@{coin="ETHW";host="ethw.ss.poolin.one";fee=1.0;divisor=1}
)

$Count = 0
$Pools_Data | Where-Object {$Config.Pools.$Name."API_$($_.symbol)_PUID" -and $Config.Pools.$Name."API_$($_.symbol)_ReadToken" -match "^wow" -and $Config.Pools.$Name.Wallets."$($_.symbol)" -and (-not $Config.ExcludeCoinsymbolBalances.Count -or $Config.ExcludeCoinsymbolBalances -notcontains "$($_.symbol)")} | Foreach-Object {
    $Request = [PSCustomObject]@{}
    try {
        $Request = Invoke-RestMethodAsync "https://api-prod.poolin.me/api/public/v2/payment/stats?puid=$($Config.Pools.$Name."API_$($_.symbol)_PUID")&coin_type=$($_.symbol.ToLower())&three_month=1" -tag $Name -delay $(if ($Count){500} else {0}) -cycletime ($Config.BalanceUpdateMinutes*60) -fixbigint -headers @{authorization="Bearer $($Config.Pools.$Name."API_$($_.symbol)_ReadToken")"}
        $Count++
        if ("$($Request.err_no)" -ne "0") {
            Write-Log -Level Info "Pool Balance API ($Name) for $($_.symbol) returned nothing. "            
        } else {
            $Request_Payments = if ($Request.data.last_payment_time) {
                try {
                    (Invoke-RestMethodAsync "https://api-prod.poolin.me/api/public/v2/payment/payout-history?puid=$($Config.Pools.$Name."API_$($_.symbol)_PUID")&coin_type=$($_.symbol.ToLower())" -tag $Name -delay $(if ($Count){500} else {0}) -cycletime ($Config.BalanceUpdateMinutes*60) -fixbigint -headers @{authorization="Bearer $($Config.Pools.$Name."API_$($_.symbol)_ReadToken")"}).data
                } catch {
                }
            }
			$Divisor = [Decimal]1e9
            [PSCustomObject]@{
                Caption     = "$($Name) ($($_.symbol))"
				BaseName    = $Name
                Name        = $Name
                Currency    = $_.symbol
                Balance     = [Decimal]$Request.data.balance/$Divisor
                Pending     = [Decimal]0
                Total       = [Decimal]$Request.data.balance/$Divisor
                Paid        = [Decimal]$Request.data.total_paid_amount/$Divisor
                Earned      = [Decimal]0
                Payouts     = @(Get-BalancesPayouts $Request_Payments -Divisor $Divisor)
                LastUpdated = (Get-Date).ToUniversalTime()
            }
        }
    }
    catch {
        Write-Log -Level Warn "Pool Balance API ($Name) for $($_.Name) has failed. "
    }
}
