using module ..\Include.psm1

param(
    $Config
)

$Name = Get-Item $MyInvocation.MyCommand.Path | Select-Object -ExpandProperty BaseName

$Request = [PSCustomObject]@{}

$Payout_Currencies = @(@($Config.Pools.$Name.Wallets.PSObject.Properties | Select-Object) + @($Config.Pools."$($Name)Coins".Wallets.PSObject.Properties | Select-Object) | Select-Object Name,Value -Unique | Sort-Object Name,Value)

if (-not $Payout_Currencies) {
    Write-Log -Level Verbose "Cannot get balance on pool ($Name) - no wallet address specified. "
    return
}

$Payout_Currencies | Foreach-Object {
    try {
        $Request = Invoke-RestMethod "http://zerg.zergpool.com/api/walletEx?address=$($_.Value)" -UseBasicParsing -TimeoutSec 10 -ErrorAction Stop
        if (($Request | Get-Member -MemberType NoteProperty -ErrorAction Ignore | Measure-Object Name).Count -le 1) {
            Write-Log -Level Warn "Pool Balance API ($Name) for $($_.Name) returned nothing. "
        } else {
            [PSCustomObject]@{
                Caption     = "$($Name) ($($Request.currency))"
                Currency    = $Request.currency
                Balance     = $Request.balance
                Pending     = $Request.unsold
                Total       = $Request.unpaid
                Earned      = $Request.paidtotal
                Payouts     = @($Request.payouts)
                LastUpdated = (Get-Date).ToUniversalTime()
            }
        }
    }
    catch {
        $Error.Remove($Error[$Error.Count - 1])
        Write-Log -Level Warn "Pool Balance API ($Name) for $($_.Name) has failed. "
    }
}
