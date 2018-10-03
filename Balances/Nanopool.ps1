param(
    $Config
)

$Name = Get-Item $MyInvocation.MyCommand.Path | Select-Object -ExpandProperty BaseName

$Request = [PSCustomObject]@{}

$Payout_Currencies = @($Config.Pools.$Name.Wallets.PSObject.Properties | Select-Object Name,Value -Unique | Sort-Object Name,Value)

if (-not $Payout_Currencies) {
    Write-Log -Level Verbose "Cannot get balance on pool ($Name) - no wallet address specified. "
    return
}

$Payout_Currencies | Foreach-Object {
    try {
        $Request = Invoke-RestMethod "https://api.nanopool.org/v1/$($_.Name.ToLower())/balance/$($_.Value)" -UseBasicParsing -TimeoutSec 10 -ErrorAction Stop
        if ($false -and $Request.status -eq "OK") {
            Write-Log -Level Warn "Pool Balance API ($Name) for $($_.Name) returned nothing. "            
        } else {
            [PSCustomObject]@{
                Caption     = "$($Name) ($($_.Name))"
                Currency    = $_.Name
                Balance     = $Request.data
                Pending     = 0
                Total       = $Request.data
                Payed       = 0
                Earned      = 0
                Payouts     = @()
                LastUpdated = (Get-Date).ToUniversalTime()
            }
        }
    }
    catch {
        if ($Error.Count){$Error.RemoveAt(0)}
        Write-Log -Level Warn "Pool Balance API ($Name) for $($_.Name) has failed. "
    }
}
