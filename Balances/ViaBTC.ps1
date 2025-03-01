using module ..\Modules\Include.psm1

param(
    [String]$Name,
    $Config
)

# $Name = Get-Item $MyInvocation.MyCommand.Path | Select-Object -ExpandProperty BaseName

if ($Config.Pools.$Name.API_Key) {

    $Request = [PSCustomObject]@{}
    try {
        $Request = Invoke-RestMethodAsync "https://www.viabtc.net/res/openapi/v1/account" -tag $Name -retry 5 -retrywait 250 -cycletime 3600 -delay 250 -fixbigint -headers @{"X-API-KEY" = $Config.Pools.$Name.API_Key}
    }
    catch {
        Write-Log -Level Warn "Pool Accounts API ($Name) has failed. "
    }

    if ($Request.message -ne "OK") {
        Write-Log -Level Warn "Pool Balance API ($Name) has failed: $($Request.message)"
    } else {
        $Request.data.balance | Foreach-Object {
            [PSCustomObject]@{
                Caption     = "$($Name) ($($_.coin))"
                BaseName    = $Name
                Name        = $Name
                Currency    = $_.coin
                Balance     = [Decimal]$_.amount
                Pending     = 0
                Total       = [Decimal]$_.amount
                Payouts     = @()
                LastUpdated = (Get-Date).ToUniversalTime()
            }
        }
    }
}
