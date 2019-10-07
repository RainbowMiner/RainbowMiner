param(
    $Config
)

$Name = Get-Item $MyInvocation.MyCommand.Path | Select-Object -ExpandProperty BaseName

$Request = [PSCustomObject]@{}

$Pools_Data = @(
    [PSCustomObject]@{symbol = "RVN"; url = "ravencoin"; port = 3010; fee = 0.9; ssl = $false; protocol = "stratum+tcp"}
    [PSCustomObject]@{symbol = "XZC"; url = "zcoin";     port = 3000; fee = 0.9; ssl = $false; protocol = "stratum+tcp"}
)

$Count = 0
$Pools_Data | Where-Object {$Config.Pools.$Name.Wallets."$($_.symbol)"} | Foreach-Object {
    $Pool_Currency = $_.symbol
    $Pool_Url = "https://api.mintpond.com/v1/$($_.url)"

    try {
        $Request = Invoke-RestMethodAsync "$($Pool_Url)/miner/balances/$($Config.Pools.$Name.Wallets.$Pool_Currency)" -delay $(if ($Count){500} else {0}) -cycletime ($Config.BalanceUpdateMinutes*60)
        $Count++
        if (-not $Request.miner.balances) {
            Write-Log -Level Info "Pool Balance API ($Name) for $($Pool_Currency) returned nothing. "            
        } else {
            [PSCustomObject]@{
                Caption     = "$($Name) ($($Pool_Currency))"
                Currency    = $Pool_Currency
                Balance     = [Decimal]$Request.miner.balances.confirmed
                Pending     = [Decimal]$Request.miner.balances.unconfirmed
                Total       = [Decimal]$Request.miner.balances.confirmed + [Decimal]$Request.miner.balances.unconfirmed
                Paid        = [Decimal]$Request.miner.balances.paid
                Earned      = 0
                Payouts     = @()
                LastUpdated = (Get-Date).ToUniversalTime()
            }
        }
    }
    catch {
        if ($Error.Count){$Error.RemoveAt(0)}
        Write-Log -Level Warn "Pool Balance API ($Name) for $($Pool_Currency) has failed. "
    }
}
