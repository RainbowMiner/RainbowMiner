param(
    $Config
)

$Name = Get-Item $MyInvocation.MyCommand.Path | Select-Object -ExpandProperty BaseName
$PoolConfig = $Config.Pools.$Name

if (!$PoolConfig.BTC) {
    Write-Log -Level Verbose "Cannot get balance on pool ($Name) - no wallet address specified. "
    return
}

$Platform_Version = if ($PoolConfig.Platform -in @("2","v2","new")) {2} else {1}

if ($Platform_Version -eq 2) {
    $Request = [PSCustomObject]@{}

    try {
        $Request = Invoke-NHRequest "/main/api/v2/accounting/accounts" $PoolConfig.API_Key $PoolConfig.API_Secret $PoolConfig.OrganizationID -Cache ($Config.BalanceUpdateMinutes*60)
    }
    catch {
        if ($Error.Count){$Error.RemoveAt(0)}
        Write-Log -Level Warn "Pool Accounts API ($Name) has failed. "
    }

    if ($Request) {
        $Request | Where-Object {$_.currency -eq "BTC"} | Foreach-Object {
            $Pending = if ($_.currency -eq "BTC") {[Decimal]$Request.unpaidAmount} else {0}
            [PSCustomObject]@{
                Caption     = "$($Name) ($($_.currency))"
                Currency    = $_.currency
                Balance     = [Decimal]$_.balance
                Pending     = [Decimal]$Pending
                Total       = [Decimal]$Pending + [Decimal]$_.balance
                Payouts     = @()
                LastUpdated = (Get-Date).ToUniversalTime()
            }        
        }
    } else {
        try {
            $Request = Invoke-RestMethodAsync "https://api2.nicehash.com/main/api/v2/mining/external/$($PoolConfig.BTC)/rigs/" -cycletime ($Config.BalanceUpdateMinutes*60)
        }
        catch {
            if ($Error.Count){$Error.RemoveAt(0)}
            Write-Log -Level Warn "Pool Mining API ($Name) has failed. "
            return
        }

        [PSCustomObject]@{
            Caption     = "$($Name) (BTC)"
            Currency    = "BTC"
            Balance     = [Decimal]$Request.externalBalance
            Pending     = [Decimal]$Request.unpaidAmount
            Total       = [Decimal]$Request.externalBalance + [Decimal]$Request.unpaidAmount
            Payouts     = @()
            LastUpdated = (Get-Date).ToUniversalTime()
        }
    }
} else {
    $UnpaidRequest = [PSCustomObject]@{}

    try {
        [Decimal]$Sum = 0
        $UnpaidRequest = Invoke-RestMethodAsync "https://api.nicehash.com/api?method=stats.provider&addr=$($PoolConfig.BTC)" -cycletime ($Config.BalanceUpdateMinutes*60)
        $UnpaidRequest.result.stats.balance | Foreach {$Sum += [Decimal]$_}
    }
    catch {
        if ($Error.Count){$Error.RemoveAt(0)}
        Write-Log -Level Warn "Pool Balance API ($Name) has failed. "
        return
    }

    $PaidRequest = [PSCustomObject]@{}

    [Decimal]$SumPaid = 0
    if ($PoolConfig.API_ID -and $PoolConfig.API_Key) {
        try {
            $PaidRequest = Invoke-RestMethodAsync "https://api.nicehash.com/api?method=balance&id=$($PoolConfig.API_ID)&key=$($PoolConfig.API_Key)" -cycletime ($Config.BalanceUpdateMinutes*60)
            @("balance_confirmed","balance_pending") | Where-Object {$PaidRequest.result.$_} | Foreach-Object {$SumPaid += [Decimal]$PaidRequest.result.$_}
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
        Pending     = [Decimal]0 # Pending is always 0 since NiceHash doesn't report unconfirmed or unexchanged profits like other pools do
        Total       = $Sum
        Payouts     = @($UnpaidRequest.result.payments | Select-Object)
        LastUpdated = (Get-Date).ToUniversalTime()
    }
    [PSCustomObject]@{
        Caption     = "$($Name)Paid (BTC)"
        Info        = "Paid"
        Currency    = "BTC"
        Balance     = $SumPaid
        Pending     = [Decimal]0 # Pending is always 0 since NiceHash doesn't report unconfirmed or unexchanged profits like other pools do
        Total       = $SumPaid
        Payouts     = @()
        LastUpdated = (Get-Date).ToUniversalTime()
    }
}
