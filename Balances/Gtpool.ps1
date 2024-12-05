using module ..\Modules\Include.psm1

param(
    $Config,
    $UsePools
)

$Name = Get-Item $MyInvocation.MyCommand.Path | Select-Object -ExpandProperty BaseName

if (-not $Config.Pools.$Name.API_Key) {return}

$Pool_Request = [PSCustomObject]@{}

try {
    $Pool_Request = Invoke-RestMethodAsync "https://api.gtpool.io/?key=$($Config.Pools.$Name.API_Key)" -body '{"method":"coins_reward"}' -retry 3 -retrywait 1000 -tag $Name -cycletime ($Config.BalanceUpdateMinutes*60)
}
catch {
    if ($Error.Count){$Error.RemoveAt(0)}
    Write-Log -Level Warn "Pool API ($Name) in balance module has failed. "
    return
}

if (-not $Pool_Request.result) {
    Write-Log -Level Warn "Pool API ($Name) in balance module returned nothing. "
    return
}

$Pool_Request.data | Where-Object {$Currency = $_.coin;(-not $Config.ExcludeCoinsymbolBalances.Count -or $Config.ExcludeCoinsymbolBalances -notcontains $Currency)} | Foreach-Object {
    [PSCustomObject]@{
        Caption     = "$($Name) ($($Currency))"
		BaseName    = $Name
        Currency    = $Currency
        Balance     = [Decimal]$_.balance / 1e9
        Pending     = [Decimal]$_.balanceImmature / 1e9
        Total       = ([Decimal]$_.balance + [Decimal]$_.balanceImmature) / 1e9
        LastUpdated = (Get-Date).ToUniversalTime()
    }
}
