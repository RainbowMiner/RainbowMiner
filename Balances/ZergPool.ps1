using module ..\Modules\Include.psm1

param(
    $Config,
    $UsePools
)

$Name = Get-Item $MyInvocation.MyCommand.Path | Select-Object -ExpandProperty BaseName

$Request = [PSCustomObject]@{}

$Payout_Currencies = @()
foreach($PoolExt in @("","Coins","CoinsParty","CoinsSolo","Party","Solo")) {
    if (-not $UsePools -or "$($Name)$($PoolExt)" -in $UsePools) {
        $Payout_Currencies += @($Config.Pools."$($Name)$($PoolExt)".Wallets.PSObject.Properties | Select-Object)
    }
}

$Payout_Currencies = $Payout_Currencies | Where-Object Value | Select-Object Name,Value -Unique | Sort-Object Name,Value

if (-not $Payout_Currencies) {
    Write-Log -Level Verbose "Cannot get balance on pool ($Name) - no wallet address specified. "
    return
}

$PoolCoins_Request = [PSCustomObject]@{}
try {
    $PoolCoins_Request = Invoke-RestMethodAsync "https://zergpool.com/api/currencies" -tag $Name -cycletime 120 -timeout 20
}
catch {
    Write-Log -Level Warn "Pool currencies API ($Name) has failed. "
}

$Count = 0
$Payout_Currencies | Where-Object {@("BTC", "DASH", "LTC","TRX","USDT") + @($PoolCoins_Request.PSObject.Properties | Foreach-Object {if ($_.Value.symbol -ne $null) {$_.Value.symbol} else {$_.Name}} | Select-Object -Unique) -icontains $_.Name} | Where-Object {-not $Config.ExcludeCoinsymbolBalances.Count -or $Config.ExcludeCoinsymbolBalances -notcontains $_.Name} | Foreach-Object {
    try {
        $Request = Invoke-RestMethodAsync "https://zergpool.com/api/walletEx?address=$($_.Value)" -delay $(if ($Count){1000} else {0}) -cycletime ($Config.BalanceUpdateMinutes*60) -tag $Name
        $Count++
        if (($Request | Get-Member -MemberType NoteProperty -ErrorAction Ignore | Measure-Object Name).Count -le 1) {
            Write-Log -Level Info "Pool Balance API ($Name) for $($_.Name) returned nothing. "
        } else {
            [PSCustomObject]@{
                Caption     = "$($Name) ($($Request.currency))"
				BaseName    = $Name
                Name        = $Name
                Currency    = $Request.currency
                Balance     = [Decimal]$Request.balance
                Pending     = [Decimal]$Request.unsold
                Total       = [Decimal]$Request.unpaid
                Paid        = [Decimal]$Request.paidtotal
                Paid24h     = [Decimal]$Request.paid24h
                Earned      = [Decimal]$Request.total
                Payouts     = @(Get-BalancesPayouts $Request.payouts | Select-Object)
                LastUpdated = (Get-Date).ToUniversalTime()
            }
        }
    }
    catch {
        Write-Log -Level Verbose "Pool Balance API ($Name) for $($_.Name) has failed. "
    }
}
