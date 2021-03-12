using module ..\Modules\Include.psm1

param(
    $Config
)

$Name = Get-Item $MyInvocation.MyCommand.Path | Select-Object -ExpandProperty BaseName
$PoolConfig = $Config.Pools.$Name

if (-not $PoolConfig.BTC) {
    Write-Log -Level Verbose "Cannot get balance on pool ($Name) - no wallet address specified. "
    return
}

$Request = [PSCustomObject]@{}
try {
    $Request = Invoke-RestMethodAsync "https://api2.nicehash.com/main/api/v2/mining/external/$($PoolConfig.BTC)/rigs2/" -cycletime ($Config.BalanceUpdateMinutes*60)
}
catch {
    if ($Error.Count){$Error.RemoveAt(0)}
    Write-Log -Level Warn "Pool Mining API ($Name) has failed. "
    return
}

if ($Request.externalAddress) {

    [PSCustomObject]@{
        Caption     = "$($Name) (BTC)"
        BaseName    = $Name
        Currency    = "BTC"
        Balance     = [Decimal]$Request.externalBalance
        Pending     = [Decimal]$Request.unpaidAmount
        Total       = [Decimal]$Request.externalBalance + [Decimal]$Request.unpaidAmount
        Payouts     = @()
        LastUpdated = (Get-Date).ToUniversalTime()
    }

} elseif ($PoolConfig.API_Key -and $PoolConfig.API_Secret -and $PoolConfig.OrganizationID) {

    $Request = [PSCustomObject]@{}

    try {
        $Request = Invoke-NHRequest "/main/api/v2/accounting/account2/BTC/" $PoolConfig.API_Key $PoolConfig.API_Secret $PoolConfig.OrganizationID
    }
    catch {
        if ($Error.Count){$Error.RemoveAt(0)}
        Write-Log -Level Warn "Pool Accounts API ($Name) has failed. "
    }

    if ($Request.active) {
        [PSCustomObject]@{
            Caption     = "$($Name) ($($Request.currency))"
            BaseName    = $Name
            Currency    = $Request.currency
            Balance     = [Decimal]$Request.available
            Pending     = [Decimal]$Request.pending
            Total       = [Decimal]$Request.totalBalance
            Payouts     = @()
            LastUpdated = (Get-Date).ToUniversalTime()
        }        
    }
}
