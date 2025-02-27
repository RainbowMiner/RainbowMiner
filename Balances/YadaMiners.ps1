using module ..\Modules\Include.psm1

param(
    $Config
)

$Name = Get-Item $MyInvocation.MyCommand.Path | Select-Object -ExpandProperty BaseName

$Pool_Currency = "YDA"
$Pool_Wallet   = $Config.Pools.$Name.$Pool_Currency

if (-not $Pool_Wallet) {
    Write-Log -Level Verbose "Cannot get balance on pool ($Name) - no wallet address specified. "
    return
}

if ($Config.ExcludeCoinsymbolBalances.Count -and $Config.ExcludeCoinsymbolBalances -contains $Pool_Currency) {return}

$Request = [PSCustomObject]@{}

try {
    $Request = Invoke-RestMethodAsync "http://yadaminers.pl/payouts-for-address?address=$($Pool_Wallet)" -delay $(if ($Count){500} else {0}) -cycletime ($Config.BalanceUpdateMinutes*60)

    $Payouts = @($Request.results.txn | Foreach-Object {
                [PSCustomObject]@{
                    Date     = $Session.UnixEpoch + [TimeSpan]::FromSeconds($_.time)
                    Amount   = [Double]($_.outputs | Where-Object {$_.to -eq $Pool_Wallet} | Measure-Object -Property value -Sum).Sum
                    Txid     = $_.id
                }})

    [PSCustomObject]@{
        Caption     = "$($Name) ($($Payout_Currency))"
		BaseName    = $Name
        Name        = $Name
        Currency    = $Payout_Currency
        Balance     = [Decimal]0
        Pending     = [Decimal]0
        Total       = [Decimal]0
        Paid        = [Decimal]($Payouts | Measure-Object -Property Amount -Sum).Sum
        Payouts     = $Payouts
        LastUpdated = (Get-Date).ToUniversalTime()
    }
}
catch {
    Write-Log -Level Warn "Pool Balance API ($Name) for $($_.Name) has failed. "
}
