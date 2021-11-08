using module ..\Modules\Include.psm1

param(
    $Config
)

$Name = Get-Item $MyInvocation.MyCommand.Path | Select-Object -ExpandProperty BaseName

$Pool_Currency = "SERO"

$PoolConfig = $Config.Pools.$Name

if (-not $PoolConfig.Wallets.$Pool_Currency -or ($Config.ExcludeCoinsymbolBalances.Count -and $Config.ExcludeCoinsymbolBalances -contains $Pool_Currency)) {return}

$Request = [PSCustomObject]@{}

try {
    if ($Request = Invoke-RestMethodAsync "https://pool.sero.cash/api/accounts/$($PoolConfig.$Pool_Currency)" -cycletime ($Config.BalanceUpdateMinutes*60)) {
        if ($Request.status) {
            $Divisor  = [Decimal]1e9
            $Balance  = [Decimal]$Request.stats.balance / $Divisor
            $Pending  = [Decimal]$Request.stats.immature / $Divisor
            $Unpaid   = $Unpaid + $Immature
            $Paid     = [Decimal]$Request.paymentsTotal / $Divisor
            [PSCustomObject]@{
                    Caption     = "$($Name) ($($Pool_Currency))"
                    BaseName    = $Name
                    Currency    = $Pool_Currency
                    Balance     = $Balance
                    Pending     = $Pending
                    Total       = $Unpaid
                    Paid        = $Paid
                    Earned      = $Paid + $Unpaid
                    Payouts     = @()
                    LastUpdated = (Get-Date).ToUniversalTime()
            }
        }
    }
}
catch {
    if ($Error.Count){$Error.RemoveAt(0)}
}
