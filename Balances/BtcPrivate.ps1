param(
    $Config
)

$Name = Get-Item $MyInvocation.MyCommand.Path | Select-Object -ExpandProperty BaseName

$Pools_Data = @(
    [PSCustomObject]@{symbol = "BTCP";  port = 3032; fee = 1.5; region = @("us")}
)

$Pools_Data | Where-Object {$Config.Pools.$Name.Wallets."$($_.symbol)"} | Foreach-Object {
    $Pool_Currency = $_.symbol

    $Request = [PSCustomObject]@{}

    try {
        $Request = Invoke-RestMethodAsync "https://pool.btcprivate.org/api/worker_stats?$($Config.Pools.$Name.Wallets.$Pool_Currency)" -delay 100 -cycletime ($Config.BalanceUpdateMinutes*60) -timeout 15
        if ($Request.balance -eq $null) {
            Write-Log -Level Info "Pool Balance API ($Name) for $($Pool_Currency) returned nothing. "
        } else {
            [PSCustomObject]@{
                Caption     = "$($Name) ($Pool_Currency)"
				BaseName    = $Name
                Currency    = $Pool_Currency
                Balance     = [Decimal]$Request.balance
                Pending     = [Decimal]$Request.immature
                Total       = [Decimal]$Request.balance + [Decimal]$Request.immature
                Paid        = [Decimal]$Request.paid
                Earned      = [Decimal]$Request.paid + [Decimal]$Request.balance
                Payouts     = @()
                LastUpdated = (Get-Date).ToUniversalTime()
            }
        }
    }
    catch {
        if ($Error.Count){$Error.RemoveAt(0)}
        Write-Log -Level Verbose "Pool Balance API ($Name) for $($Pool_Currency) has failed. "
    }
}
