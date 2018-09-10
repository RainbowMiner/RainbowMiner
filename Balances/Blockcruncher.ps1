using module ..\Include.psm1

param(
    $Config
)

$Name = Get-Item $MyInvocation.MyCommand.Path | Select-Object -ExpandProperty BaseName

$Request = [PSCustomObject]@{}

$Payout_Currencies = @($Config.Pools.$Name.PSObject.Properties | Where-Object Membertype -eq "NoteProperty" | Where-Object {$_.Value -is [string] -and $_.Value.Length -gt 10 -and @("API_Key","API_ID","User","Worker") -inotcontains $_.Name} | Select-Object Name,Value -Unique | Sort-Object Name,Value)

if (-not $Payout_Currencies) {
    Write-Log -Level Verbose "Cannot get balance on pool ($Name) - no wallet address specified. "
    return
}

$Payout_Currencies | Foreach-Object {
    try {
        $Request = Invoke-RestMethod "https://blockcruncher.com/api/walletEx?address=$($_.Value)" -UseBasicParsing -TimeoutSec 10 -ErrorAction Stop
        if (($Request | Get-Member -MemberType NoteProperty -ErrorAction Ignore | Measure-Object Name).Count -le 1) {
            Write-Log -Level Warn "Pool Balance API ($Name) for $($_.Name) returned nothing. "
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
        Write-Log -Level Verbose "Pool Balance API ($Name) for $($_.Name) has failed. "
    }
}
