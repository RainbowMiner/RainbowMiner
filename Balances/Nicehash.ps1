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
    $Request_Balance = [PSCustomObject]@{}

    try {
        $Request = Invoke-RestMethodAsync "https://api2.nicehash.com/main/api/v2/mining/external/$($PoolConfig.BTC)/rigs/" -cycletime ($Config.BalanceUpdateMinutes*60)
    }
    catch {
        if ($Error.Count){$Error.RemoveAt(0)}
        Write-Log -Level Warn "Pool Mining API ($Name) has failed. "
        return
    }

    if ($PoolConfig.API_Key -and $PoolConfig.API_Secret -and $PoolConfig.OrganizationID) {
        try {
            $Request_Balance = Invoke-NHRequest "/main/api/v2/accounting/accounts" $PoolConfig.API_Key $PoolConfig.API_Secret $PoolConfig.OrganizationID -Cache ($Config.BalanceUpdateMinutes*60)
        }
        catch {
            if ($Error.Count){$Error.RemoveAt(0)}
            Write-Log -Level Warn "Pool Accounts API ($Name) has failed. "
        }
    }

    if ($Request_Balance.currency -match "BTC") {
        $Request_Balance | Where-Object {$_.currency -eq "BTC"} | Foreach-Object {
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
}