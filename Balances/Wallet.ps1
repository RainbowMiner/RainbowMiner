param(
    $Config
)

$Name = Get-Item $MyInvocation.MyCommand.Path | Select-Object -ExpandProperty BaseName

if ($Config.Wallet -notmatch "^[13]" -or $Config.Currency -notcontains "BTC") {
    Write-Log -Level Verbose "Pool Balance API ($Name) has failed - no wallet address specified."
    return
}

$Wallets = @($Config.Wallet) + @($Config.Pools.PSObject.Properties.Value | Where-Object {$_.BTC} | Foreach-Object {$_.BTC}) | Select-Object -Unique | Sort-Object

$Request = [PSCustomObject]@{}

$Success = $true
try {
    $Request = Invoke-RestMethodAsync "https://blockchain.info/multiaddr?active=$($Wallets -join "|")" -cycletime ($Config.BalanceUpdateMinutes*60)
    if ($Request.addresses -eq $null) {$Success = $false}
}
catch {
    if ($Error.Count){$Error.RemoveAt(0)}
    $Success=$false
}

if (-not $Success) {
    Write-Log -Level Warn "Pool Balance API ($Name) has failed. "
    return
}

$Request.addresses | Sort-Object {$_.address} | Foreach-Object {
    [PSCustomObject]@{
            Caption     = "$($Name) ($($_.address))"
		    BaseName    = $Name
            Info        = " $($_.address.Substring(0,3))..$($_.address.Substring($_.address.Length-4,3))"
            Currency    = "BTC"
            Balance     = [Decimal]$_.final_balance / 1e8
            Pending     = 0
            Total       = [Decimal]$_.final_balance / 1e8
            Earned      = [Decimal]$_.total_received / 1e8
            Payouts     = @()
            LastUpdated = (Get-Date).ToUniversalTime()
    }
}