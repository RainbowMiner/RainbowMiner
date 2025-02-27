using module ..\Modules\Include.psm1

param(
    $Config
)

$Name = Get-Item $MyInvocation.MyCommand.Path | Select-Object -ExpandProperty BaseName

if (-not $Config.Pools.$Name.Wallets.RTM) {
    Write-Log -Level Verbose "Pool Balance API ($Name) has failed - no wallet address specified."
    return
}

if ($Config.ExcludeCoinsymbolBalances.Count -and $Config.ExcludeCoinsymbolBalances -contains "RTM") {return}

$Request = [PSCustomObject]@{}

try {
    $Request = Invoke-RestMethodAsync "https://api.raptoreum.zone/v1/rzone/miner/paymentDetails?address=$($Config.Pools.$Name.Wallets.RTM)&currency=btc" -cycletime ($Config.BalanceUpdateMinutes*60)
}
catch {
    Write-Log -Level Warn "Pool Balance API ($Name) has failed. "
    return
}

if ($Request.error -or -not $Request.result) {
    Write-Log -Level Info "Pool Balance API ($Name) returned nothing. "
    return
}

$Request_Payments = try {
    $Request_Payments_Page = Invoke-RestMethodAsync "https://api.raptoreum.zone/v1/rzone/miner/payments?page=1&address=$($Config.Pools.$Name.Wallets.RTM)&currency=usd" -cycletime ($Config.BalanceUpdateMinutes*60)
    if (-not $Request_Payments_Page.error -and $Request_Payments_Page.result.data) {
        $Request_Payments_Page.result.data | Foreach-Object {[PSCustomObject]@{Date = $Session.UnixEpoch + [TimeSpan]::FromSeconds($_.timestamp/1000); Amount = [double]$_.amount; Txid = $_.transaction}}
    }
}
catch {
}

[PSCustomObject]@{
        Caption     = "$($Name) (RTM)"
		BaseName    = $Name
        Name        = $Name
        Currency    = "RTM"
        Balance     = [Decimal]$Request.result.totalBalance - [Decimal]$Request.result.immatureBalance
        Pending     = [Decimal]$Request.result.immatureBalance
        Total       = [Decimal]$Request.result.totalBalance
        Paid        = [Decimal]$Request.result.sumPayments
        #Paid24h     = [Decimal]$Request.earnings."1d"
        Payouts     = @($Request_Payments | Select-Object)
        LastUpdated = (Get-Date).ToUniversalTime()
}