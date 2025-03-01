using module ..\Modules\Include.psm1

param(
    [String]$Name,
    $Config
)

# $Name = Get-Item $MyInvocation.MyCommand.Path | Select-Object -ExpandProperty BaseName

$Request = [PSCustomObject]@{}

$Count = 0
@("BTC","ETC","RVN") | Where-Object {$Config.Pools.$Name.Wallets.$_ -and (-not $Config.ExcludeCoinsymbolBalances.Count -or $Config.ExcludeCoinsymbolBalances -notcontains $_)} | Foreach-Object {
    $Pool_Wallet = "$($Config.Pools.$Name.Wallets.$_ -replace "^0x")".ToLower()
    try {
        $Request = Invoke-RestMethodAsync "https://hiveon.net/api/v1/stats/miner/$($Pool_Wallet)/$($_)/billing-acc" -delay $(if ($Count){500} else {0}) -cycletime ($Config.BalanceUpdateMinutes*60)
        [PSCustomObject]@{
            Caption     = "$($Name) ($($_))"
			BaseName    = $Name
            Name        = $Name
            Currency    = $_
            Balance     = [Decimal]$Request.totalUnpaid
            Pending     = 0
            Total       = [Decimal]$Request.totalUnpaid
            Paid        = [Decimal]$Request.totalPaid
            Earned      = [Decimal]0
            Payouts     = @(Get-BalancesPayouts $Request.pendingPayouts | Select-Object) + @(Get-BalancesPayouts $Request.succeedPayouts | Select-Object)
            LastUpdated = (Get-Date).ToUniversalTime()
        }
    }
    catch {
        Write-Log -Level Warn "Pool Balance API ($Name) for $($_) has failed. "
    }
    $Count++
}
