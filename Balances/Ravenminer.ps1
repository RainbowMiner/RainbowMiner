using module ..\Include.psm1

param(
    $Config
)

$Ravenminer_Regions = "eu", "us"

$Name = Get-Item $MyInvocation.MyCommand.Path | Select-Object -ExpandProperty BaseName
$PoolConfig = $Config.Pools.$Name

$Request = [PSCustomObject]@{}

if (!$PoolConfig.RVN) {
    Write-Log -Level Verbose "Pool Balance API ($Name) has failed - no wallet address specified."
    return
}

$Ravenminer_Regions | ForEach-Object {
    if ( $_ -eq "eu" ) { $Ravenminer_Host = "eu.ravenminer.com" }
    else { $Ravenminer_Host = "ravenminer.com" }

    try {
        $Request = Invoke-RestMethod "https://$($Ravenminer_Host)/api/wallet?address=$($PoolConfig.RVN)" -UseBasicParsing -TimeoutSec 10 -ErrorAction Stop
    }
    catch {
        Write-Log -Level Warn "Pool Balance API ($Name) has failed. "
    }

    if (($Request | Get-Member -MemberType NoteProperty -ErrorAction Ignore | Measure-Object Name).Count -le 1) {
        Write-Log -Level Warn "Pool Balance API ($Name) returned nothing. "
        return
    }

    [PSCustomObject]@{
        "region" = $_
        "currency" = $Request.currency
        "balance" = $Request.balance
        "pending" = $Request.unsold
        "total" = $Request.unpaid
        'lastupdated' = (Get-Date).ToUniversalTime()
    }
}