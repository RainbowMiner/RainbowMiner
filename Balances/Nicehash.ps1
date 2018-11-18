param(
    $Config
)

$Name = Get-Item $MyInvocation.MyCommand.Path | Select-Object -ExpandProperty BaseName
$PoolConfig = $Config.Pools.$Name

if (!$PoolConfig.BTC) {
    Write-Log -Level Verbose "Cannot get balance on pool ($Name) - no wallet address specified. "
    return
}

$Request = [PSCustomObject]@{}

try {
    #NH API does not total all of your balances for each algo up, so you have to do it with another call then total them manually.
    $UnpaidRequest = Invoke-RestMethodAsync "https://api.nicehash.com/api?method=stats.provider&addr=$($PoolConfig.BTC)" -cycletime ($Config.BalanceUpdateMinutes*60)

    $Sum = 0
    $UnpaidRequest.result.stats.balance | Foreach {$Sum += $_}
}
catch {
    if ($Error.Count){$Error.RemoveAt(0)}
    Write-Log -Level Warn "Pool Balance API ($Name) has failed. "
    return
}

if ($PoolConfig.API_ID -and $PoolConfig.API_Key) {
    try {
        $PaidRequest = Invoke-RestMethodAsync "https://api.nicehash.com/api?method=balance&id=$($API_ID)&key=$($API_Key)" -cycletime ($Config.BalanceUpdateMinutes*60)
        @("balance_confirmed","balance_pending") | Where-Object {$PaidRequest.result.$_} | Foreach-Object {$Sum += $PaidRequest.result.$_}
    }
    catch {
        if ($Error.Count){$Error.RemoveAt(0)}
        Write-Log -Level Warn "Pool paid Balance API ($Name) has failed. "
    }
}

[PSCustomObject]@{
    Caption     = "$($Name) (BTC)"
    Currency    = "BTC"
    Balance     = $Sum
    Pending     = 0 # Pending is always 0 since NiceHash doesn't report unconfirmed or unexchanged profits like other pools do
    Total       = $Sum
    Payouts     = @($UnpaidRequest.result.payments | Select-Object)
    LastUpdated = (Get-Date).ToUniversalTime()
}

