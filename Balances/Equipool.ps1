param(
    $Config
)

$Name = Get-Item $MyInvocation.MyCommand.Path | Select-Object -ExpandProperty BaseName

$Payout_Currencies = $Config.Pools.$Name.Wallets.PSObject.Properties | Where-Object Value | Select-Object Name,Value -Unique | Sort-Object Name,Value

if (-not $Payout_Currencies) {
    Write-Log -Level Verbose "Cannot get balance on pool ($Name) - no wallet address specified. "
    return
}

$Pool_Request = [PSCustomObject]@{}

$ok = $false
try {
    $Pool_Request = Invoke-RestMethodAsync "https://equipool.1ds.us/api/stats" -tag $Name -cycletime 120
    if ($Pool_Request.time -and ($Pool_Request.pools.PSObject.Properties.Name | Measure-Object).Count) {$ok = $true}
}
catch {
    if ($Error.Count){$Error.RemoveAt(0)}
}

if (-not $ok) {
    Write-Log -Level Warn "Pool API ($Name) has failed. "
    return
}

$Pool_Coins = @($Pool_Request.pools.PSObject.Properties.Value.symbol | Select-Object -Unique)

$Count = 0
$Payout_Currencies | Where-Object {$Pool_Coins -icontains $_.Name -and (-not $Config.ExcludeCoinsymbolBalances.Count -or $Config.ExcludeCoinsymbolBalances -notcontains "$($_.Name)")} | Foreach-Object {
    $Pool_Currency   = $_.Name

    try {
        $Request = [PSCustomObject]@{}
        $Request = Invoke-RestMethodAsync "https://equipool.1ds.us/api/worker_stats?$($_.Value)" -delay $(if ($Count){500} else {0}) -cycletime ($Config.BalanceUpdateMinutes*60)
        $Count++
        if ($Request.code -ne 0 -or $Request.data.address -eq $null) {
            Write-Log -Level Info "Pool Balance API ($Name) for $($_.Name) returned nothing. "
        } else {
            [PSCustomObject]@{
                Caption     = "$($Name) ($($Pool_Currency))"
				BaseName    = $Name
                Currency    = $Pool_Currency
                Balance     = [Decimal]$Request.balance
                Pending     = [Decimal]$Request.immature
                Total       = [Decimal]$Request.immature + [Decimal]$Request.balance
                Earned      = [Decimal]$Request.paid
                Payouts     = @()
                LastUpdated = (Get-Date).ToUniversalTime()
            }
        }
    }
    catch {
        if ($Error.Count){$Error.RemoveAt(0)}
        Write-Log -Level Verbose "Pool Balance API ($Name) for $($_.Name) has failed. "
    }
}
