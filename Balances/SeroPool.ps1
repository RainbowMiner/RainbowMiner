using module ..\Modules\Include.psm1

param(
    [String]$Name,
    $Config
)

# $Name = Get-Item $MyInvocation.MyCommand.Path | Select-Object -ExpandProperty BaseName

$Pool_Currency = "SERO"

$PoolConfig = $Config.Pools.$Name

if (-not $PoolConfig.Wallets.$Pool_Currency -or ($Config.ExcludeCoinsymbolBalances.Count -and $Config.ExcludeCoinsymbolBalances -contains $Pool_Currency)) {return}

$Request = [PSCustomObject]@{}

try {
    $Request = Invoke-RestMethodAsync "https://pool.sero.cash/api/accounts/$($PoolConfig.$Pool_Currency)" -tag $Name -cycletime ($Config.BalanceUpdateMinutes*60)
    if ($Request.stats) {
        $Divisor  = [Decimal]1e9
        $Balance  = [Decimal]$Request.stats.balance / $Divisor
        $Pending  = [Decimal]$Request.stats.immature / $Divisor
        [PSCustomObject]@{
            Caption     = "$($Name) ($($Pool_Currency))"
            BaseName    = $Name
            Name        = $Name
            Currency    = $Pool_Currency
            Balance     = $Balance
            Pending     = $Pending
            Total       = $Balance + $Pending
            Paid        = [Decimal]($Request.payments | Foreach-Object {$_.amount/$Divisor} | Measure-Object -Sum).Sum
            Payouts     = @(Get-BalancesPayouts $Request.payments -Divisor $Divisor | Select-Object)
            LastUpdated = (Get-Date).ToUniversalTime()
        }
    }
}
catch {
}
