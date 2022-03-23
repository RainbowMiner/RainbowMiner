using module ..\Modules\Include.psm1

param(
    $Config
)

$Name = Get-Item $MyInvocation.MyCommand.Path | Select-Object -ExpandProperty BaseName

$Pools_Data = @(
    [PSCustomObject]@{symbol = "ETC";  ports = @(4444,5555); fee = 0.9; divisor = 1e18; stratum = "etc-%region%.flexpool.io"; regions = @("us-east","de","sg","asia"); altstratum = [PSCustomObject]@{asia="sgeetc.gfwroute.co"}}
    [PSCustomObject]@{symbol = "ETH";  ports = @(4444,5555); fee = 0.9; divisor = 1e18; stratum = "eth-%region%.flexpool.io"; regions = @("us-east","us-west","de","se","sg","au","br","kr","hk","asia"); altstratum = [PSCustomObject]@{asia="eth-hke.flexpool.io"}}
)

$Pools_Data | Where-Object {$Pool_Currency = $_.symbol;$Config.Pools.$Name.Wallets.$Pool_Currency -and (-not $Config.ExcludeCoinsymbolBalances.Count -or $Config.ExcludeCoinsymbolBalances -notcontains $Pool_Currency)} | Foreach-Object {

    $Pool_Wallet = $Config.Pools.$Name.Wallets.$Pool_Currency

    $ok = $false

    $Pool_BalanceRequest  = [PSCustomObject]@{}
    $Pool_TotalRequest    = [PSCustomObject]@{}
    $Pool_PaymentsRequest = [PSCustomObject]@{}

    try {
        $Pool_BalanceRequest = Invoke-RestMethodAsync "https://api.flexpool.io/v2/miner/balance?coin=$($Pool_Currency)&address=$($Pool_Wallet)" -cycletime ($Config.BalanceUpdateMinutes*60) -fixbigint
        $Pool_StatsRequest   = Invoke-RestMethodAsync "https://api.flexpool.io/v2/miner/paymentsStats?coin=$($Pool_Currency)&address=$($Pool_Wallet)" -cycletime ($Config.BalanceUpdateMinutes*60) -fixbigint
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
            $Pool_PaymentsResult = Invoke-RestMethodAsync "https://api.flexpool.io/v2/miner/payments?coin=$($Pool_Currency)&address=$($Pool_Wallet)&page=$($page)" -cycletime ($Config.BalanceUpdateMinutes*60) -fixbigint
            $ok = -not $Pool_PaymentsResult.error -and (++$page -lt $Pool_PaymentsResult.result.totalPages)
            if (-not $Pool_PaymentsResult.error) {
                $Pool_PaymentsResult.result.data | Foreach-Object {$Pool_PaymentsData += $_}
            }
        }
        catch {
            if ($Error.Count){$Error.RemoveAt(0)}
        }
    } until (-not $ok)

    $Unpaid = [Decimal]$Pool_BalanceRequest.result.balance / $_.divisor
    $Paid   = [Decimal]$Pool_StatsRequest.result.stats.totalPaid / $_.divisor

    [PSCustomObject]@{
            Caption     = "$($Name) ($Pool_Currency)"
		    BaseName    = $Name
            Currency    = $Pool_Currency
            Balance     = $Unpaid
            Pending     = ""
            Total       = $Unpaid
            Paid        = $Paid
            Earned      = $Unpaid + $Paid
            Payouts     = @(Get-BalancesPayouts $Pool_PaymentsData -Divisor $_.divisor | Select-Object)
            LastUpdated = (Get-Date).ToUniversalTime()
    }

    $Pool_PaymentsData = $null
}
