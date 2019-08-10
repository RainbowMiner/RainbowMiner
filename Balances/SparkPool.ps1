param(
    $Config
)

$Name = Get-Item $MyInvocation.MyCommand.Path | Select-Object -ExpandProperty BaseName

$Pool_Request = [PSCustomObject]@{}

try {
    $Pool_Request = Invoke-RestMethodAsync "https://www.sparkpool.com/v1/pool/stats?pool=SPARK_POOL_CN" -tag $Name -retry 5 -retrywait 250 -cycletime 120
    if ($Pool_Request.code -ne 200) {throw}
}
catch {
    if ($Error.Count){$Error.RemoveAt(0)}
    Write-Log -Level Warn "Pool API ($Name) has failed. "
    return
}

$Pool_Request.data | Where-Object {$Pool_Currency = $_.currency -replace "_.+$";$Config.Pools.$Name.Wallets.$Pool_Currency} | Foreach-Object {

    $Request = [PSCustomObject]@{}

    try {
        $Request = Invoke-RestMethodAsync "https://www.sparkpool.com/v1/bill/stats?miner=$(Get-UrlEncode $Config.Pools.$Name.Wallets.$Pool_Currency)&pool=$($_.pool)&currency=$($_.currency)" -delay 100 -cycletime ($Config.BalanceUpdateMinutes*60)
        if ($Request.code -ne 200) {
            Write-Log -Level Info "Pool Balance API ($Name) for $($Pool_Currency) returned nothing. "
        } else {
            [PSCustomObject]@{
                Caption     = "$($Name) ($($_.currency))"
                Info        = "$(if ($_.currency -ne $Pool_Currency) {"$($_.currency)"})"
                Currency    = $Pool_Currency
                Balance     = [Decimal]$Request.data.balance
                Pending     = [Decimal]0
                Total       = [Decimal]$Request.data.balance
                Paid24h     = [Decimal]0
                Paid        = [Decimal]$Request.data.totalPaid
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
