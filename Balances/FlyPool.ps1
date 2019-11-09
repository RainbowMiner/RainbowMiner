param(
    $Config
)

$Name = Get-Item $MyInvocation.MyCommand.Path | Select-Object -ExpandProperty BaseName

$Request = [PSCustomObject]@{}

$Pools_Data = @(
    [PSCustomObject]@{regions = @("eu","us","asia"); host = "1-beam.flypool.org";  rpc = "api-beam.flypool.org";  symbol = "BEAM"; port = @(3333,3443); fee = 1; divisor = 1}
    [PSCustomObject]@{regions = @("eu","us","asia"); host = "1-zcash.flypool.org"; rpc = "api-zcash.flypool.org"; symbol = "ZEC";  port = @(3333,3443); fee = 1; divisor = 1}
    [PSCustomObject]@{regions = @("eu","us","asia"); host = "1-ycash.flypool.org"; rpc = "api-ycash.flypool.org"; symbol = "YEC";  port = @(3333,3443); fee = 1; divisor = 1}
)

$Count = 0
$Pools_Data | Where-Object {$Config.Pools.$Name.Wallets."$($_.symbol)"} | Foreach-Object {
    try {
        $Request = Invoke-RestMethodAsync "$($_.rpc)/miner/$($Config.Pools.$Name.Wallets."$($_.symbol)")/dashboard" -delay $(if ($Count){500} else {0}) -cycletime ($Config.BalanceUpdateMinutes*60)
        $Count++
        if ($Request.status -ne "OK") {
            Write-Log -Level Info "Pool Balance API ($Name) for $($_.symbol) returned nothing. "            
        } else {
			$Divisor = [Decimal]1e18
            [PSCustomObject]@{
                Caption     = "$($Name) ($($_.symbol))"
				BaseName    = $Name
                Currency    = $_.symbol
                Balance     = [Decimal]$Request.data.currentStatistics.unpaid/$Divisor
                Pending     = [Decimal]$Request.data.currentStatistics.unconfirmed/$Divisor
                Total       = [Decimal]$Request.data.currentStatistics.unpaid/$Divisor + [Decimal]$Request.data.currentStatistics.unconfirmed/$Divisor
                Paid        = [Decimal]0
                Earned      = [Decimal]0
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
