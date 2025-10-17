using module ..\Modules\Include.psm1

param(
    [String]$Name,
    $Config
)

# $Name = Get-Item $MyInvocation.MyCommand.Path | Select-Object -ExpandProperty BaseName

$Payout_Currencies = @(foreach ($PoolExt in "","Solo") {
    if (-not $UsePools -or "$Name$PoolExt" -in $UsePools) {
        $Config.Pools."$Name$PoolExt".Wallets.PSObject.Properties | Where-Object Value
    }
}) | Sort-Object Name, Value -Unique

if (-not $Payout_Currencies) {
    Write-Log -Level Verbose "Cannot get balance on pool ($Name) - no wallet address specified. "
    return
}

$Pool_Request = [PSCustomObject]@{}

try {
    $Pool_Request = Invoke-RestMethodAsync "https://pool.kryptex.com/api/v1/rates" -tag $Name -cycletime 120 -retry 5 -retrywait 250
}
catch {
    Write-Log -Level Warn "Pool API ($Name) has failed. "
    return
}

if (-not $Pool_Request.crypto) {
    Write-Log -Level Warn "Pool API ($Name) returned nothing. "
    return
}

$Pool_Request.crypto.PSObject.Properties.Name | Where-Object {$Config.Pools.$Pool_Name.Wallets.$_ -and (-not $Config.ExcludeCoinsymbolBalances.Count -or $Config.ExcludeCoinsymbolBalances -notcontains $_)} | Foreach-Object {

    $Pool_Currency = $_
    $Pool_Wallet   = $Config.Pools.$Pool_Name.Wallets.$Pool_Currency

    $Request = [PSCustomObject]@{}
    $Request_Paid = [PSCustomObject]@{}

    try {
        $Request = Invoke-RestMethodAsync "https://pool.kryptex.com/nexa/api/v1/miner/balance/$($Pool_Wallet)" -tag $Name -timeout 15 -cycletime ($Config.BalanceUpdateMinutes*60) -delay 100
        try {
            $Request_Paid = Invoke-RestMethodAsync "https://pool.kryptex.com/nexa/api/v1/miner/payouts/$($Pool_Wallet)" -tag $Name -timeout 15 -cycletime ($Config.BalanceUpdateMinutes*60) -delay 100
        } catch {
            Write-Log -Level Verbose "Pool Balance/Payouts API ($Name) for $($Pool_Currency) has failed. "
        }
        [PSCustomObject]@{
            Caption     = "$($Pool_Name) ($Pool_Currency)"
			BaseName    = $Pool_Name
            Name        = $Name
            Currency    = $Pool_Currency
            Balance     = [Decimal]$Request.confirmed
            Pending     = [Decimal]$Request.unconfirmed
            Total       = [Decimal]$Request.total
            Paid        = [Decimal]$Request.miner.paidBalance
            Payouts     = @(Get-BalancesPayouts $Request_Paid.results | Select-Object)
            LastUpdated = (Get-Date).ToUniversalTime()
        }
    }
    catch {
        Write-Log -Level Verbose "Pool Balance API ($Name) for $($Pool_Currency) has failed. "
    }
}
