using module ..\Modules\Include.psm1

param(
    $Config
)

#https://api.unminable.com/v3/stats/0xaaD1d2972f99A99248464cdb075B28697d4d8EEd?tz=1&coin=ETH
$Name = Get-Item $MyInvocation.MyCommand.Path | Select-Object -ExpandProperty BaseName

$Pool_CoinsRequest = [PSCustomObject]@{}

try {
    $Pool_CoinsRequest = Invoke-RestMethodAsync "https://api.unmineable.com/v3/coins" -tag $Name -cycletime 21600
}
catch {
    if ($Error.Count){$Error.RemoveAt(0)}
    Write-Log -Level Warn "Pool API ($Name) has failed. "
    return
}

if (-not $Pool_CoinsRequest.coins) {
    Write-Log -Level Warn "Pool API ($Name) returned nothing. "
    return
}


$Pool_CoinsRequest.coins | Where-Object {$Config.Pools.$Name.Wallets."$($_.symbol)" -and (-not $Config.ExcludeCoinsymbolBalances.Count -or $Config.ExcludeCoinsymbolBalances -notcontains "$($_.symbol)")} | Foreach-Object {
    $Pool_Currency = $_.symbol

    $Request = [PSCustomObject]@{}

    try {
        $Request = Invoke-WebRequestAsync "https://api.unminable.com/v3/stats/$($Config.Pools.$Name.Wallets.$Pool_Currency)?coin=$($Pool_Currency)" -delay 100 -cycletime ($Config.BalanceUpdateMinutes*60)
        $Request = ConvertFrom-Json "$($Request -replace ',"hashrate".+$','}}')" -ErrorAction Stop

        if (-not $Request.success) {
            Write-Log -Level Info "Pool Balance API ($Name) for $($Pool_Currency) returned nothing. "
        } else {
            [PSCustomObject]@{
                Caption     = "$($Name) ($Pool_Currency)"
				BaseName    = $Name
                Currency    = $Pool_Currency
                Balance     = [Decimal]$Request.data.pending_balance
                Pending     = 0
                Total       = [Decimal]$Request.data.pending_balance
                Paid        = [Decimal]$Request.data.total_paid
                Paid24h     = [Decimal]$Request.data.total_24h
                Payouts     = @()
                LastUpdated = (Get-Date).ToUniversalTime()
            }
        }
    }
    catch {
        if ($Error.Count){$Error.RemoveAt(0)}
        Write-Log -Level Verbose "Pool Balance API ($Name) for $($Pool_Currency) has failed. "
    }
}
