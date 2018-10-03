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
        $Request = Invoke-RestMethod "https://api.nanopool.org/v1/$($_.Name.ToLower())/user/$($_.Value)" -UseBasicParsing -TimeoutSec 10 -ErrorAction Stop
        if ($Request.status -ne "OK") {
            Write-Log -Level Warn "Pool Balance API ($Name) for $($_.Name) returned nothing. "            
        } else {
            [PSCustomObject]@{
                Caption     = "$($Name) ($($_.Name))"
                Currency    = $_.Name
                Balance     = [Math]::Max([double]$Request.data.balance,0)
                Pending     = [double]$Request.data.unconfirmed_balance
                Total       = [Math]::Max([double]$Request.data.balance,0) + [double]$Request.data.unconfirmed_balance
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
