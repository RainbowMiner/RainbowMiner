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

$API_Hosts = @{
    "ETH" = "https://api.ethermine.org"
    "ETC" = "https://api-etc.ethermine.org"
    "ZEC" = "https://api-zcash.flypool.org"
}

$Payout_Currencies | Foreach-Object {
    try {
        $Request = Invoke-GetUrl "$($API_Hosts."$($_.Name)")/miner/$($_.Value)/dashboard"
        if ($Request.status -ne "OK") {
            Write-Log -Level Info "Pool Balance API ($Name) for $($_.Name) returned nothing. "            
        } else {
            [PSCustomObject]@{
                Caption     = "$($Name) ($($_.Name))"
                Currency    = $_.Name
                Balance     = [double]$Request.data.currentStatistics.unpaid/1e18
                Pending     = [double]$Request.data.currentStatistics.unconfirmed/1e18
                Total       = [double]$Request.data.currentStatistics.unpaid/1e18 + [double]$Request.data.currentStatistics.unconfirmed/1e18
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
