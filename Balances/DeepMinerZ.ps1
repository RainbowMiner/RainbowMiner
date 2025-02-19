using module ..\Modules\Include.psm1

param(
    $Config
)

$Name = Get-Item $MyInvocation.MyCommand.Path | Select-Object -ExpandProperty BaseName

$Pool_Currency = "DNX"

if (-not $Config.Pools.$Name.Wallets.$Pool_Currency -and -not -not $Config.Pools."$($Name)Solo".Wallets.$Pool_Currency) {
    Write-Log -Level Verbose "Pool Balance API ($Name) has failed - no wallet address specified."
    return
}

if ($Config.ExcludeCoinsymbolBalances.Count -and $Config.ExcludeCoinsymbolBalances -contains "DNX") {return}

$Request = [PSCustomObject]@{}

if ($Config.Pools.$Name.Wallets.$Pool_Currency) {
    try {
        $Request = Invoke-RestMethodAsync "https://pool.deepminerz.com:8071/stats_address?address=$($Config.Pools.$Name.Wallets.DNX)&longpoll=false" -cycletime ($Config.BalanceUpdateMinutes*60)
    }
    catch {
        if ($Global:Error.Count){$Global:Error.RemoveAt(0)}
        Write-Log -Level Warn "Pool Balance API ($Name) has failed. "
        return
    }

    if ($Request.stats) {
        $Pool_Balance = [Decimal]$Request.stats.balance / 1e9
        [PSCustomObject]@{
                Caption     = "$($Name) (DNX)"
		        BaseName    = $Name
                Currency    = "DNX"
                Balance     = $Pool_Balance
                Pending     = 0
                Total       = $Pool_Balance
                #Paid        = [Decimal]$Request.total - [Decimal]$Request.unpaid
                #Paid24h     = [Decimal]$Request.earnings."1d"
                #Payouts     = @(Get-BalancesPayouts $Request.payouts | Select-Object)
                LastUpdated = (Get-Date).ToUniversalTime()
        }
    } else {
        Write-Log -Level Info "Pool Balance API ($Name) returned nothing. "
    }
}

if ($Config.Pools."$($Name)Solo".Wallets.$Pool_Currency -and $Config.Pools.$Name.Wallets.$Pool_Currency -ne $Config.Pools."$($Name)Solo".Wallets.$Pool_Currency) {
    try {
        $Request = Invoke-RestMethodAsync "https://pool.deepminerz.com:8071/stats_address?address=$($Config.Pools."$($Name)Solo".Wallets.DNX)&longpoll=false" -cycletime ($Config.BalanceUpdateMinutes*60)
    }
    catch {
        if ($Global:Error.Count){$Global:Error.RemoveAt(0)}
        Write-Log -Level Warn "Pool Balance API ($Name) has failed. "
        return
    }

    if ($Request.stats) {
        $Pool_Balance = [Decimal]$Request.stats.balance / 1e9
        [PSCustomObject]@{
                Caption     = "$($Name)Solo (DNX)"
		        BaseName    = $Name
                Currency    = "DNX"
                Balance     = $Pool_Balance
                Pending     = 0
                Total       = $Pool_Balance
                #Paid        = [Decimal]$Request.total - [Decimal]$Request.unpaid
                #Paid24h     = [Decimal]$Request.earnings."1d"
                #Payouts     = @(Get-BalancesPayouts $Request.payouts | Select-Object)
                LastUpdated = (Get-Date).ToUniversalTime()
        }
    } else {
        Write-Log -Level Info "Pool Balance API ($Name) returned nothing. "
    }
}

