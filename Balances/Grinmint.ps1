using module ..\Modules\Include.psm1

param(
    $Config
)

$Name = Get-Item $MyInvocation.MyCommand.Path | Select-Object -ExpandProperty BaseName

$Pool_Currency = "GRIN"

$PoolConfig = $Config.Pools.$Name

if (-not $PoolConfig.Wallets.$Pool_Currency -or ($Config.ExcludeCoinsymbolBalances.Count -and $Config.ExcludeCoinsymbolBalances -contains $Pool_Currency)) {return}

$Request = [PSCustomObject]@{}

try {
    if ($Request = Invoke-RestMethodAsync "https://api.grinmint.com/v2/user/$($PoolConfig.$Pool_Currency)/userStats" -cycletime ($Config.BalanceUpdateMinutes*60)) {
        if ($Request.status) {
			$Divisor  = [Decimal]1e9
            $Unpaid   = [Decimal]$Request.unpaid_balance / $Divisor
            $Immature = [Decimal]$Request.immature_balance / $Divisor
            [PSCustomObject]@{
                    Caption     = "$($Name) ($($Pool_Currency))"
					BaseName    = $Name
                    Currency    = $Pool_Currency
                    Balance     = $Unpaid
                    Pending     = $Immature
                    Total       = $Unpaid + $Immature
                    Paid        = 0
                    Earned      = 0
                    Payouts     = @()
                    LastUpdated = (Get-Date).ToUniversalTime()
            }
        }
    }
}
catch {
    if ($Error.Count){$Error.RemoveAt(0)}
}
