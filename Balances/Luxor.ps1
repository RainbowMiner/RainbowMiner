using module ..\Modules\Include.psm1

param(
    $Config
)

$Name = Get-Item $MyInvocation.MyCommand.Path | Select-Object -ExpandProperty BaseName

$Pools_Data = @(
    [PSCustomObject]@{symbol = "ARRR";    port = 700; fee = 3.0; rpc = "arrr"}
)

$Pools_Data | Where-Object {($Config.Pools.$Name.Wallets."$($_.symbol)" -or $Config.Pools.$Name.User) -and (-not $Config.ExcludeCoinsymbolBalances.Count -or $Config.ExcludeCoinsymbolBalances -notcontains "$($_.symbol)")} | Foreach-Object {
    $Pool_Currency = $_.symbol
    $Pool_RpcPath  = $_.rpc

    $Request = [PSCustomObject]@{}

    $coinUnits = 1e18

    try {
        $Pool_Wallet = if ($Config.Pools.$Name.Wallets."$($_.symbol)") {$Config.Pools.$Name.Wallets."$($_.symbol)"} else {$Config.Pools.$Name.User}
        $Request = Invoke-RestMethodAsync "http://mining.luxor.tech/api/$($Pool_Currency)/user/$($Pool_Wallet)" -delay 100 -cycletime ($Config.BalanceUpdateMinutes*60) -timeout 15 -fixbigint

        if (-not $Request -or -not $coinUnits) {
            Write-Log -Level Info "Pool Balance API ($Name) for $($Pool_Currency) returned nothing. "
        } else {
            [PSCustomObject]@{
                Caption     = "$($Name) ($Pool_Currency)"
                BaseName    = $Name
                Currency    = $Pool_Currency
                Balance     = [Decimal]$Request.balance / $coinUnits
                Pending     = 0
                Total       = [Decimal]$Request.balance / $coinUnits
                Paid        = [Decimal]$Request.total_payouts / $coinUnits
                Paid24h     = [Decimal]$Request.payouts_one_day / $coinUnits
                Payouts     = @(Get-BalancesPayouts $Request.payouts -Divisor $coinUnits)
                LastUpdated = (Get-Date).ToUniversalTime()
            }
        }
    }
    catch {
        if ($Error.Count){$Error.RemoveAt(0)}
        Write-Log -Level Verbose "Pool Balance API ($Name) for $($Pool_Currency) has failed. "
    }
}
