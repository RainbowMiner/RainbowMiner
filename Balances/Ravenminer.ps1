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

$Ravenminer_Host = "ravenminer.com"

$Success = $true
try {
    if (-not ($Request = Invoke-GetUrl "https://$($Ravenminer_Host)/api/walletEx?address=$($PoolConfig.RVN)")){$Success = $false}
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
                "balance" = [Double]($Values | Select-Object -Index 1).Value
                "unsold"  = [Double]($Values | Select-Object -Index 0).Value
                "unpaid"  = [Double]($Values | Select-Object -Index 2).Value                
                "total"  = [Double]($Values | Select-Object -Index 4).Value
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
    Write-Log -Level Warn "Pool Balance API ($Name) returned nothing. "
    return
}

[PSCustomObject]@{
        Caption     = "$($Name) (RVN)"
        Currency    = $Request.currency
        Balance     = $Request.balance
        Pending     = $Request.unsold
        Total       = $Request.unpaid
        Paid        = $Request.total - $Request.unpaid
        Earned      = $Request.total
        Payouts     = @($Request.payouts | Select-Object)
        LastUpdated = (Get-Date).ToUniversalTime()
}