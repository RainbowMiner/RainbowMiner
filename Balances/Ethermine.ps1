param(
    $Config
)

$Name = Get-Item $MyInvocation.MyCommand.Path | Select-Object -ExpandProperty BaseName

$Request = [PSCustomObject]@{}

$API_Hosts = [PSCustomObject]@{
    "ETH" = "https://api.ethermine.org"
    "ETC" = "https://api-etc.ethermine.org"
    "ZEC" = "https://api-zcash.flypool.org"
}

$Count = 0
$API_Hosts.PSObject.Properties | Where-Object {$Config.Pools.$Name.Wallets."$($_.Name)"} | Foreach-Object {
    try {
        $Request = Invoke-RestMethodAsync "$($_.Value)/miner/$($Config.Pools.$Name.Wallets."$($_.Name)")/dashboard" -delay $(if ($Count){500} else {0}) -cycletime ($Config.BalanceUpdateMinutes*60)
        $Count++
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
