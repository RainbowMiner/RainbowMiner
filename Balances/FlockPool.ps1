using module ..\Modules\Include.psm1

param(
    $Config
)

$Name = Get-Item $MyInvocation.MyCommand.Path | Select-Object -ExpandProperty BaseName

$Pool_Currency = "RTM"

$PoolConfig = $Config.Pools.$Name

if (-not $PoolConfig.Wallets.$Pool_Currency -or ($Config.ExcludeCoinsymbolBalances.Count -and $Config.ExcludeCoinsymbolBalances -contains $Pool_Currency)) {return}

$Request = [PSCustomObject]@{}

try {
    $Request = Invoke-RestMethodAsync "https://flockpool.com/api/v1/wallets/rtm/$($PoolConfig.$Pool_Currency)" -tag $Name -cycletime ($Config.BalanceUpdateMinutes*60)
    if ($Request.balance) {
        $Divisor  = [Decimal]1e8
        $Balance  = [Decimal]$Request.balance.mature / $Divisor
        $Pending  = [Decimal]$Request.balance.immature / $Divisor
        $Paid     = [Decimal]$Request.balance.paid / $Divisor
        [PSCustomObject]@{
            Caption     = "$($Name) ($($Pool_Currency))"
            BaseName    = $Name
            Currency    = $Pool_Currency
            Balance     = $Balance
            Pending     = $Pending
            Total       = $Balance + $Pending
            Paid        = $Paid
            Payouts     = @(Get-BalancesPayouts $Request.payments -Divisor $Divisor | Select-Object)
            LastUpdated = (Get-Date).ToUniversalTime()
        }
    }
}
catch {
    if ($Error.Count){$Error.RemoveAt(0)}
}
