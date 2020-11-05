using module ..\Include.psm1

param(
    $Config
)

$Name = Get-Item $MyInvocation.MyCommand.Path | Select-Object -ExpandProperty BaseName

$Request = [PSCustomObject]@{}

$Count = 0
@("ETH","ETC") | Where-Object {$Config.Pools.$Name.Wallets.$_ -and (-not $Config.ExcludeCoinsymbolBalances.Count -or $Config.ExcludeCoinsymbolBalances -notcontains $_)} | Foreach-Object {
    $Pool_Wallet = "$($Config.Pools.$Name.Wallets."$($_)" -replace "^0x")".ToLower()
    try {
        if ($_ -ne "ETH") {
            Write-Log -Level Warn "Pool Balance API ($Name) for $($_) not implemented. Please open an issue with your $_ wallet address on github.com"
        } else {
            $Request = Invoke-RestMethodAsync "https://hiveon.net/api/v0/miner/$($Pool_Wallet)/bill?currency=ETH" -delay $(if ($Count){500} else {0}) -cycletime ($Config.BalanceUpdateMinutes*60)
            if ($Request.status -ne 200) {
                Write-Log -Level Info "Pool Balance API ($Name) for $($_) returned nothing. "            
            } else {
                [PSCustomObject]@{
                    Caption     = "$($Name) ($($_))"
				    BaseName    = $Name
                    Currency    = $_
                    Balance     = [Decimal]$Request.stats.balance
                    Pending     = [Decimal]$Request.stats.penddingBalance
                    Total       = [Decimal]$Request.stats.balance + [Decimal]$Request.stats.penddingBalance
                    Paid        = [Decimal]$Request.stats.totalPaid
                    Earned      = [Decimal]0
                    Payouts     = @(Get-BalancesPayouts $Request.list | Select-Object)
                    LastUpdated = (Get-Date).ToUniversalTime()
                }
            }
        }
    }
    catch {
        if ($Error.Count){$Error.RemoveAt(0)}
        Write-Log -Level Warn "Pool Balance API ($Name) for $($_) has failed. "
    }
    $Count++
}
