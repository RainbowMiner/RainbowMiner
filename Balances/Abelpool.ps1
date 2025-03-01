using module ..\Modules\Include.psm1

param(
    [String]$Name,
    $Config
)

# $Name = Get-Item $MyInvocation.MyCommand.Path | Select-Object -ExpandProperty BaseName

$Pool_Currency = "ABEL"

if (-not $Config.Pools.$Name.ReadonlyPageCode -or ($Config.ExcludeCoinsymbolBalances.Count -and $Config.ExcludeCoinsymbolBalances -contains $Pool_Currency)) {
    Write-Log -Level Verbose "Cannot get balance on pool ($Name) - no ReadonlyPageCode specified. "
    return
}

if ($Config.Pools.$Name.ReadonlyPageCode -match "code=([a-zA-Z0-9]+)") {
    $Pool_ReadonlyPageCode = $Matches[1]
} else {
    $Pool_ReadonlyPageCode = $Config.Pools.$Name.ReadonlyPageCode
}

$Pool_Request = [PSCustomObject]@{}

$ok = $false
try {
    $Pool_Request = Invoke-RestMethodAsync "https://api.abelpool.io/api/v1/readonly/url/$($Pool_ReadonlyPageCode)" -tag $Name -retry 3 -retrywait 1000 -cycletime ($Config.BalanceUpdateMinutes*60)
    if ($Pool_Request.code -eq 200) {$ok = $true}
}
catch {
}

if (-not $ok) {
    Write-Log -Level Warn "Pool API ($Name) for $($Pool_Currency) has failed. "
    return
}

$Count = 0

$Pool_Balance = [Decimal]0
$Pool_Pending = [Decimal]0
$Pool_Total   = [Decimal]0
$Pool_Paid    = [Decimal]0

$Pool_Request.data.accountIds | Foreach-Object {
    try {
        $Request = Invoke-RestMethodAsync "https://api.abelpool.io/api/v1/readonly/profit/summary/4DK4rVUyS934U2c7xyy3?account_id=$($_)&currency=$($Pool_Currency)" -delay $(if ($Count){500} else {0}) -cycletime ($Config.BalanceUpdateMinutes*60)
        $Count++
        if ($Request.code -eq 200) {
            $Pool_Balance += [Decimal]$Request.data.balance
            $Pool_Pending += [Decimal]$Request.data.today_estimated
            $Pool_Total   += [Decimal]$Request.data.total_income
            $Pool_Paid    += [Decimal]$Request.data.total_payout
        } else {
            $ok = $false
        }
    }
    catch {
        Write-Log -Level Warn "Pool Balance API ($Name) for $($_.Name) has failed. "
        $ok = $false
    }
}

if ($ok) {
    [PSCustomObject]@{
        Caption     = "$($Name) ($($Pool_Currency))"
		BaseName    = $Name
        Name        = $Name
        Currency    = $Pool_Currency
        Balance     = $Pool_Balance
        Pending     = $Pool_Pending
        Total       = $Pool_Total + $Pool_Pending
        Paid        = $Pool_Paid
        Payouts     = @()
        LastUpdated = (Get-Date).ToUniversalTime()
    }
}
