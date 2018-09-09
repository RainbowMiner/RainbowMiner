using module ..\Include.psm1

param(
    $Config
)

$Name = Get-Item $MyInvocation.MyCommand.Path | Select-Object -ExpandProperty BaseName
$PoolConfig = $Config.Pools.$Name

$Request = [PSCustomObject]@{}

$Payout_Currencies = @($PoolConfig.PSObject.Properties | Where-Object {$_.Value -is [string] -and $_.Value.Length -gt 20} | Select-Object -ExpandProperty Name)

if (-not $Payout_Currencies) {
    Write-Log -Level Verbose "Cannot get balance on pool ($Name) - no wallet address specified. "
    return
}

$Payout_Currencies | Foreach-Object {
    try {
        $Request = Invoke-RestMethod "http://zpool.ca/api/walletEx?address=$($PoolConfig.$_)" -UseBasicParsing -TimeoutSec 10 -ErrorAction Stop
        if (($Request | Get-Member -MemberType NoteProperty -ErrorAction Ignore | Measure-Object Name).Count -le 1) {
            Write-Log -Level Warn "Pool Balance API ($Name) for $_ returned nothing. "
        } else {
            [PSCustomObject]@{
                Caption     = "$($Name) ($($Request.currency))"
                Currency    = $Request.currency
                Balance     = $Request.balance
                Pending     = $Request.unsold
                Total       = $Request.unpaid
                Payed       = $Request.total - $Request.unpaid
                Earned      = $Request.total
                Payouts     = @($Request.payouts | Select-Object)
                LastUpdated = (Get-Date).ToUniversalTime()
            }
        }
    }
    catch {
        Write-Log -Level Warn "Pool Balance API ($Name) for $_ has failed. "
    }
}
