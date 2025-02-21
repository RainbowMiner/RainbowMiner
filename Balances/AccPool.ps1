using module ..\Modules\Include.psm1

param(
    $Config
)

$Name = Get-Item $MyInvocation.MyCommand.Path | Select-Object -ExpandProperty BaseName

$Pools_Data = @(
    [PSCustomObject]@{symbol="KAS";  region=@("eu","ca","us","ru","hk","arg"); host="acc-pool.pw"; web="kaspa.acc-pool.pw"; port=@(16061,16062); fee=0.8}
    [PSCustomObject]@{symbol="NEXA"; region=@("eu","ca","us","ru","hk","arg"); host="acc-pool.pw"; web="nexa.acc-pool.pw";  port=@(16011,16012); fee=1}
)

$Pools_Data | Where-Object {$Pool_Currency = $_.symbol;$Config.Pools.$Name.Wallets.$Pool_Currency -and (-not $Config.ExcludeCoinsymbolBalances.Count -or $Config.ExcludeCoinsymbolBalances -notcontains $Pool_Currency)} | Foreach-Object {

    $Pool_Wallet   = $Config.Pools.$Name.Wallets.$Pool_Currency -replace "^kaspa:"

    $Divisor = 1

    $Request = [PSCustomObject]@{}

    try {
        $Request = Invoke-RestMethodAsync "https://kaspa.acc-pool.pw/api/$($Pool_Wallet)/" -tag $Name -timeout 15 -cycletime ($Config.BalanceUpdateMinutes*60) -delay 100
        if ($Request.status -ne "success") {
            Write-Log -Level Info "Pool Balance API ($Name) for $($Pool_Currency) returned nothing. "
        } else {
            [PSCustomObject]@{
                Caption     = "$($Name) ($Pool_Currency)"
				BaseName    = $Name
                Currency    = $Pool_Currency
                Balance     = [Decimal]$Request.result.earnings.balance
                Pending     = [Decimal]$Request.result.earnings.unconfirmed
                Total       = [Decimal]$Request.result.earnings.balance + [Decimal]$Request.result.earnings.unconfirmed
                Paid        = [Decimal]$Request.result.earnings.paid
                Payouts     = @(Get-BalancesPayouts $Request.result.transactions.debit -Divisor $Divisor | Select-Object)
                LastUpdated = (Get-Date).ToUniversalTime()
            }
        }
    }
    catch {
        Write-Log -Level Verbose "Pool Balance API ($Name) for $($Pool_Currency) has failed. "
    }
}
