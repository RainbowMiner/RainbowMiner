using module ..\Modules\Include.psm1

param(
    $Config
)

$Name = Get-Item $MyInvocation.MyCommand.Path | Select-Object -ExpandProperty BaseName

$Request = [PSCustomObject]@{}

$Payout_Currencies = $Config.Pools.$Name.Wallets.PSObject.Properties | Where-Object Value | Select-Object Name,Value -Unique | Sort-Object Name,Value

if (-not $Payout_Currencies) {
    Write-Log -Level Verbose "Cannot get balance on pool ($Name) - no wallet address specified. "
    return
}

$PoolCoins_Request = [PSCustomObject]@{}
try {
    $PoolCoins_Request = Invoke-RestMethodAsync "https://api.rbminer.net/data/icemining.json" -tag $Name -cycletime 120
    if ($PoolCoins_Request -is [string]) {$PoolCoins_Request = ($PoolCoins_Request -replace '<script.+?/script>' -replace '<.+?>').Trim() | ConvertFrom-Json -ErrorAction Stop}
}
catch {
    Write-Log -Level Warn "Pool API ($Name) has failed. "
    return
}

$Count = 0
$Payout_Currencies | Where-Object {@($PoolCoins_Request.PSObject.Properties | Foreach-Object {if ($_.Value.symbol -ne $null) {$_.Value.symbol} else {$_.Name}} | Select-Object -Unique) -icontains $_.Name -and (-not $Config.ExcludeCoinsymbolBalances.Count -or $Config.ExcludeCoinsymbolBalances -notcontains "$($_.Name)")} | Foreach-Object {
    try {
        $Request = Invoke-RestMethodAsync "https://icemining.ca/api/wallet/$($_.Value -replace "\s")" -delay $(if ($Count){500} else {0}) -cycletime ($Config.BalanceUpdateMinutes*60)
        $Count++
        if (($Request | Get-Member -MemberType NoteProperty -ErrorAction Ignore | Measure-Object Name).Count -le 1) {
            Write-Log -Level Info "Pool Balance API ($Name) for $($_.Name) returned $(if ($Request -is [string] -and $Request.Length -lt 200) {$Request} else {"nothing"}). "
        } else {
            [PSCustomObject]@{
                Caption     = "$($Name) ($($_.Name))"
				BaseName    = $Name
                Name        = $Name
                Currency    = $_.Name
                Balance     = [Decimal]$Request.balance
                Pending     = [Decimal]$Request.unsold
                Total       = [Decimal]$Request.total_unpaid
                Paid        = [Decimal]$Request.total_paid
                Earned      = [Decimal]$Request.total_earned
                Payouts     = @(Get-BalancesPayouts $Request.user_payments | Select-Object)
                LastUpdated = (Get-Date).ToUniversalTime()
            }
        }
    }
    catch {
        Write-Log -Level Verbose "Pool Balance API ($Name) for $($_.Name) has failed. "
    }
}
