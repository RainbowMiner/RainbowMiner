using module ..\Modules\Include.psm1

param(
    [String]$Name,
    $Config
)

$Pool_Currency = "PRL"
$Pool_Wallet   = $Config.Pools.$Name.Wallets.$Pool_Currency

if (-not $Pool_Wallet -or ($Config.ExcludeCoinsymbolBalances.Count -and $Config.ExcludeCoinsymbolBalances -contains $Pool_Currency)) {return}

$Request = [PSCustomObject]@{}

try {
    $Request = Invoke-RestMethodAsync "https://pearlhash.xyz/api/account/$($Pool_Wallet)" -delay 100 -cycletime ($Config.BalanceUpdateMinutes*60)
    if (-not $Request.balance_transactions) {
        Write-Log -Level Info "Pool Balance API ($Name) for $($Pool_Currency) returned nothing. "
    } else {
        $balance = ($Request.balance_transactions | Measure-Object -Sum -Property amount).Sum
        $paid    = -($Request.balance_transactions | Where-Object {$_.amount -lt 0} | Measure-Object -Sum -Property amount).Sum
        $pending = $Request.pending_rewards.total_pending
        [PSCustomObject]@{
            Caption     = "$($Name) ($Pool_Currency)"
			BaseName    = $Name
            Name        = $Name
            Currency    = $Pool_Currency
            Balance     = [Decimal]$balance
            Pending     = [Decimal]$pending
            Total       = [Decimal]($balance + $pending)
            Paid        = [Decimal]$paid
            Payouts     = @()
            LastUpdated = (Get-Date).ToUniversalTime()
        }
    }
}
catch {
    if ($Global:Error.Count){$Global:Error.RemoveAt(0)}
    Write-Log -Level Verbose "Pool Balance API ($Name) for $($_.Value) has failed. "
}