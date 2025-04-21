using module ..\Modules\Include.psm1

param(
    [String]$Name,
    $Config,
    $UsePools
)

# $Name = Get-Item $MyInvocation.MyCommand.Path | Select-Object -ExpandProperty BaseName

if (-not $Config.Pools.$Name.API_Key) {return}

$Pool_Request = [PSCustomObject]@{}

try {
    $Pool_Request = Invoke-RestMethodAsync "https://api.gtpool.io/v2/account/summary?key=$($Config.Pools.$Name.API_Key)" -body '{"method":"coins_reward"}' -retry 3 -retrywait 1000 -tag $Name -cycletime ($Config.BalanceUpdateMinutes*60)
}
catch {
    Write-Log -Level Warn "Pool API ($Name) in balance module has failed. "
    return
}

if (-not $Pool_Request.result) {
    Write-Log -Level Warn "Pool API ($Name) in balance module returned nothing. "
    return
}

$Pool_Request.payload | Where-Object {$Currency = $_.coin.ticker;(-not $Config.ExcludeCoinsymbolBalances.Count -or $Config.ExcludeCoinsymbolBalances -notcontains $Currency)} | Foreach-Object {
    [PSCustomObject]@{
        Caption     = "$($Name) ($($Currency))"
		BaseName    = $Name
        Name        = $Name
        Currency    = $Currency
        Balance     = [Decimal]$_.balance / 1e8
        Pending     = [Decimal]$_.immature / 1e8
        Total       = ([Decimal]$_.balance + [Decimal]$_.immature) / 1e8
        LastUpdated = (Get-Date).ToUniversalTime()
    }
}
