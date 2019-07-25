param(
    $Config
)

$Name = Get-Item $MyInvocation.MyCommand.Path | Select-Object -ExpandProperty BaseName
$PoolConfig = $Config.Pools.$Name

if (!$PoolConfig.BTC) {
    Write-Log -Level Verbose "Cannot get balance on pool ($Name) - no wallet address specified. "
    return
}

$Platform_Version = 2

if ($Platform_Version -eq 2) {
    $Request = [PSCustomObject]@{}

    try {
        $Request = Invoke-RestMethodAsync "https://api2.nicehash.com/main/api/v2/mining/external/$($PoolConfig.BTC)/rigs/" -cycletime ($Config.BalanceUpdateMinutes*60)
    }
    catch {
        if ($Error.Count){$Error.RemoveAt(0)}
        Write-Log -Level Warn "Pool Balance API ($Name) has failed. "
        return
    }

    [PSCustomObject]@{
        Caption     = "$($Name) (BTC)"
        Currency    = "BTC"
        Balance     = [Double]$Request.externalBalance
        Pending     = [Double]$Request.unpaidAmount
        Total       = [Double]$Request.externalBalance + [Double]$Request.unpaidAmount
        Payouts     = @($UnpaidRequest.result.payments | Select-Object)
        LastUpdated = (Get-Date).ToUniversalTime()
    }

} else {
    $UnpaidRequest = [PSCustomObject]@{}

    try {
        $Sum = 0
        $UnpaidRequest = Invoke-RestMethodAsync "https://api.nicehash.com/api?method=stats.provider&addr=$($PoolConfig.BTC)" -cycletime ($Config.BalanceUpdateMinutes*60)
        $UnpaidRequest.result.stats.balance | Foreach {$Sum += $_}
    }
    catch {
        if ($Error.Count){$Error.RemoveAt(0)}
        Write-Log -Level Warn "Pool Balance API ($Name) has failed. "
        return
    }

    $PaidRequest = [PSCustomObject]@{}

    $SumPaid = 0
    if ($PoolConfig.API_ID -and $PoolConfig.API_Key) {
        try {
            $PaidRequest = Invoke-RestMethodAsync "https://api.nicehash.com/api?method=balance&id=$($PoolConfig.API_ID)&key=$($PoolConfig.API_Key)" -cycletime ($Config.BalanceUpdateMinutes*60)
            @("balance_confirmed","balance_pending") | Where-Object {$PaidRequest.result.$_} | Foreach-Object {$SumPaid += $PaidRequest.result.$_}
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
    [PSCustomObject]@{
        Caption     = "$($Name)Paid (BTC)"
        Info        = "Paid"
        Currency    = "BTC"
        Balance     = $SumPaid
        Pending     = 0 # Pending is always 0 since NiceHash doesn't report unconfirmed or unexchanged profits like other pools do
        Total       = $SumPaid
        Payouts     = @()
        LastUpdated = (Get-Date).ToUniversalTime()
    }
}
