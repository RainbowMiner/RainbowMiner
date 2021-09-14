using module ..\Modules\Include.psm1

param(
    $Config
)

$Name = Get-Item $MyInvocation.MyCommand.Path | Select-Object -ExpandProperty BaseName

$Pool_Currency = "ETH"

$PoolConfig = $Config.Pools.$Name

if (-not $PoolConfig.Wallets.$Pool_Currency -or ($Config.ExcludeCoinsymbolBalances.Count -and $Config.ExcludeCoinsymbolBalances -contains $Pool_Currency)) {return}

$ok = $false

$Pool_BalanceRequest  = [PSCustomObject]@{}
$Pool_TotalRequest    = [PSCustomObject]@{}
$Pool_PaymentsRequest = [PSCustomObject]@{}

try {
    $Pool_BalanceRequest = Invoke-RestMethodAsync "https://api.flexpool.io/v2/miner/balance?coin=ETH&address=$($PoolConfig.$Pool_Currency)" -cycletime ($Config.BalanceUpdateMinutes*60) -fixbigint
    $Pool_StatsRequest   = Invoke-RestMethodAsync "https://api.flexpool.io/v2/miner/paymentsStats?coin=ETH&address=$($PoolConfig.$Pool_Currency)" -cycletime ($Config.BalanceUpdateMinutes*60) -fixbigint
    $ok = -not $Pool_BalanceRequest.error -and -not $Pool_TotalRequest.error
}
catch {
    if ($Error.Count){$Error.RemoveAt(0)}
}

if (-not $ok) {
    Write-Log -Level Warn "Pool Balance API ($Name) has failed. "
    return
}

$Pool_PaymentsData = @()

$page = 0
do {
    $ok = $false
    try {
        $Pool_PaymentsResult = Invoke-RestMethodAsync "https://api.flexpool.io/v2/miner/payments?coin=ETH&address=$($PoolConfig.$Pool_Currency)&page=$($page)" -cycletime ($Config.BalanceUpdateMinutes*60) -fixbigint
        $ok = -not $Pool_PaymentsResult.error -and (++$page -lt $Pool_PaymentsResult.result.totalPages)
        if (-not $Pool_PaymentsResult.error) {
            $Pool_PaymentsResult.result.data | Foreach-Object {$Pool_PaymentsData += $_}
        }
    }
    catch {
        if ($Error.Count){$Error.RemoveAt(0)}
    }
} until (-not $ok)

$Pool_Divisor = 1e18

$Unpaid = [Decimal]$Pool_BalanceRequest.result.balance / $Pool_Divisor
$Paid   = [Decimal]$Pool_StatsRequest.result.stats.totalPaid / $Pool_Divisor

[PSCustomObject]@{
        Caption     = "$($Name) ($Pool_Currency)"
		BaseName    = $Name
        Currency    = $Pool_Currency
        Balance     = $Unpaid
        Pending     = ""
        Total       = $Unpaid
        Paid        = $Paid
        Earned      = $Unpaid + $Paid
        Payouts     = @(Get-BalancesPayouts $Pool_PaymentsData -Divisor $Pool_Divisor | Select-Object)
        LastUpdated = (Get-Date).ToUniversalTime()
}

$Pool_PaymentsData = $null
