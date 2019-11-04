param(
    $Config
)

$Name = Get-Item $MyInvocation.MyCommand.Path | Select-Object -ExpandProperty BaseName
$PoolConfig = $Config.Pools.$Name

if (!$PoolConfig.RVN) {
    Write-Log -Level Verbose "Pool Balance API ($Name) has failed - no wallet address specified."
    return
}

$Request = [PSCustomObject]@{}

$Ravenminer_Host = "www.ravenminer.com"

$Success = $true
try {
    if (-not ($Request = Invoke-RestMethodAsync "https://$($Ravenminer_Host)/api/wallet?address=$($PoolConfig.RVN)" -cycletime ($Config.BalanceUpdateMinutes*60))){$Success = $false}
}
catch {
    if ($Error.Count){$Error.RemoveAt(0)}
    $Success=$false
}

if (-not $Success) {
    $Success = $true
    try {
        $Request = Invoke-GetUrl "https://$($Ravenminer_Host)/site/wallet_results?address=$($PoolConfig.RVN)" -method "WEB"
        if (-not ($Values = ([regex]'([\d\.]+?)\s+RVN').Matches($Request.Content).Groups | Where-Object Name -eq 1)){$Success=$false}
        else {
            $Request = [PSCustomObject]@{
                "currency" = "RVN"
                "balance" = [Decimal]($Values | Select-Object -Index 1).Value
                "unsold"  = [Decimal]($Values | Select-Object -Index 0).Value
                "unpaid"  = [Decimal]($Values | Select-Object -Index 2).Value                
                "total"  = [Decimal]($Values | Select-Object -Index 4).Value
            }
        }
    }
    catch {
        if ($Error.Count){$Error.RemoveAt(0)}
        $Success=$false
    }
}

if (-not $Success) {
    Write-Log -Level Warn "Pool Balance API ($Name) has failed. "
}

if (($Request | Get-Member -MemberType NoteProperty -ErrorAction Ignore | Measure-Object Name).Count -le 1) {
    Write-Log -Level Info "Pool Balance API ($Name) returned nothing. "
    return
}

[PSCustomObject]@{
        Caption     = "$($Name) (RVN)"
		BaseName    = $Name
        Currency    = $Request.currency
        Balance     = [Decimal]$Request.balance
        Pending     = [Decimal]$Request.unsold
        Total       = [Decimal]$Request.unpaid
        #Paid        = [Decimal]$Request.total - [Decimal]$Request.unpaid
        Paid24h     = [Decimal]$Request.paid24h
        Earned      = [Decimal]$Request.total
        Payouts     = @(Get-BalancesPayouts $Request.payouts | Select-Object)
        LastUpdated = (Get-Date).ToUniversalTime()
}