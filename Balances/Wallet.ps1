param(
    $Config
)

$Name = Get-Item $MyInvocation.MyCommand.Path | Select-Object -ExpandProperty BaseName

if ($Config.Wallet -notmatch "^[13]" -or $Config.Currency -notcontains "BTC") {
    Write-Log -Level Verbose "Pool Balance API ($Name) has failed - no wallet address specified."
    return
}

$Request = [PSCustomObject]@{}

$Success = $true
try {
    $Request = Invoke-RestMethodAsync "https://blockchain.info/balance?active=$($Config.Wallet)" -cycletime ($Config.BalanceUpdateMinutes*60)
    if ($Request."$($Config.Wallet)" -eq $null){$Success = $false}
}
catch {
    if ($Error.Count){$Error.RemoveAt(0)}
    $Success=$false
}

if (-not $Success) {
    Write-Log -Level Warn "Pool Balance API ($Name) has failed. "
    return
}

[PSCustomObject]@{
        Caption     = "$($Name) (BTC)"
		BaseName    = $Name
        Currency    = "BTC"
        Balance     = [Decimal]$Request."$($Config.Wallet)".final_balance / 1e8
        Pending     = 0
        Total       = [Decimal]$Request."$($Config.Wallet)".final_balance / 1e8
        Earned      = [Decimal]$Request."$($Config.Wallet)".total_received / 1e8
        Payouts     = @()
        LastUpdated = (Get-Date).ToUniversalTime()
}