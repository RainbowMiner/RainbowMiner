using module ..\Modules\Include.psm1

param(
    $Config
)

$Name = Get-Item $MyInvocation.MyCommand.Path | Select-Object -ExpandProperty BaseName

if ($Config.ExcludeCoinsymbolBalances.Count -and $Config.ExcludeCoinsymbolBalances -contains "RVN") {return}

$Pool_Valid_Currencies = @("RVN","BTC","ETH","LTC","BCH","ADA","DOGE","MATIC")

$Payout_Wallets = @("","Solo") | Foreach-Object {
    $Config.Pools."$($Name)$($PoolExt)".Wallets.PSObject.Properties | Where-Object {$_.Value -and $_.Name -in $Pool_Valid_Currencies}
} | Group-Object -Property Name,Value | Foreach-Object {$_.Group | Select-Object -First 1} | Sort-Object -Property Name,Value

if (-not $Payout_Wallets) {
    Write-Log -Level Verbose "Pool Balance API ($Name) has failed - no wallet address specified."
    return
}

$Payout_Wallets | Foreach-Object {
    $Request = [PSCustomObject]@{}

    #https://www.ravenminer.com/api/v1/wallet/RFV5WxTdbQEQCdgESiMLRBj5rwXyFHokmC
    try {
        $Request = Invoke-RestMethodAsync "https://www.ravenminer.com/api/v1/wallet/$($_.Value)" -cycletime ($Config.BalanceUpdateMinutes*60)
    }
    catch {
        Write-Log -Level Warn "Pool Balance API ($Name) has failed. "
        return
    }

    if (-not $Request.balance) {
        Write-Log -Level Info "Pool Balance API ($Name) returned nothing. "
        return
    }

    [PSCustomObject]@{
            Caption     = "$($Name) ($($_.Name))"
		    BaseName    = $Name
            Name        = $Name
            Currency    = "RVN"
            Balance     = [Decimal]$Request.balance.cleared
            Pending     = [Decimal]$Request.balance.pending
            Total       = [Decimal]$Request.balance.cleared + [Decimal]$Request.balance.pending
            #Paid        = [Decimal]$Request.total - [Decimal]$Request.unpaid
            Paid24h     = [Decimal]$Request.earnings."1d"
            Payouts     = @(Get-BalancesPayouts $Request.payouts | Select-Object)
            LastUpdated = (Get-Date).ToUniversalTime()
    }
}