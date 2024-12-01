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

if ($PoolConfig.API_Key -and $PoolConfig.API_Secret -and $PoolConfig.OrganizationID) {

    try {
        $Request = Invoke-NHRequest "/main/api/v2/accounting/account2/BTC/" $PoolConfig.API_Key $PoolConfig.API_Secret $PoolConfig.OrganizationID
    }
    catch {
        if ($Error.Count){$Error.RemoveAt(0)}
        Write-Log -Level Warn "Pool Accounts API ($Name) has failed. "
    }
	
	try {
        $RequestUnpaid = Invoke-NHRequest "/main/api/v2/mining/rigs2/" $PoolConfig.API_Key $PoolConfig.API_Secret $PoolConfig.OrganizationID
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
            Pending     = [Decimal]$RequestUnpaid.unpaidAmount
            Total       = [Decimal]$Request.available + [Decimal]$RequestUnpaid.unpaidAmount
            Payouts     = @()
            LastUpdated = (Get-Date).ToUniversalTime()
        }        
    }
}
