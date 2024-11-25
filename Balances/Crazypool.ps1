using module ..\Modules\Include.psm1

param(
    $Config
)

$Name = Get-Item $MyInvocation.MyCommand.Path | Select-Object -ExpandProperty BaseName

$Pools_Data = @(
    [PSCustomObject]@{rpc = "etc.crazypool.org";  symbol = "ETC";  port = @(7000,7777);   fee = 1; region = $Pool_Regions; region_prefix = "etc-"}
    [PSCustomObject]@{rpc = "ethw.crazypool.org"; symbol = "ETHW"; port = @(3333,5555);   fee = 1; region = $Pool_Regions; region_prefix = "ethw-"}
    [PSCustomObject]@{rpc = "kas.crazypool.org";  symbol = "KAS";  port = @(25101);       fee = 1; region = $Pool_Regions; region_prefix = "kas-"}
    [PSCustomObject]@{rpc = "lrs.crazypool.org";  symbol = "LRS";  port = @(25001,26001); fee = 1; region = $Pool_Regions; region_prefix = "lrs-"}
    [PSCustomObject]@{rpc = "octa.crazypool.org"; symbol = "OCTA"; port = @(5225,5885);   fee = 1; region = $Pool_Regions; region_prefix = "octa-"}
    #[PSCustomObject]@{rpc = "pac.crazypool.org";  symbol = "PAC";  port = @();            fee = 1; region = $Pool_Regions; region_prefix = "pac-"}
    [PSCustomObject]@{rpc = "sdr.crazypool.org";  symbol = "SDR";  port = @(25101);       fee = 1; region = $Pool_Regions; region_prefix = "sdr-"}
    [PSCustomObject]@{rpc = "zil.crazypool.org";  symbol = "ZIL";  port = @(5005,5995);   fee = 1; region = $Pool_Regions; region_prefix = "zil-"}
    [PSCustomObject]@{rpc = "zth.crazypool.org";  symbol = "ZTH";  port = @(25002,26002); fee = 1; region = $Pool_Regions; region_prefix = "zth-"}
)

$Count = 0
$Pools_Data | Where-Object {$Config.Pools.$Name.Wallets."$($_.symbol)" -and (-not $Config.ExcludeCoinsymbolBalances.Count -or $Config.ExcludeCoinsymbolBalances -notcontains "$($_.symbol)")} | Foreach-Object {
    $Request = [PSCustomObject]@{}
    try {
        $Request = Invoke-RestMethodAsync "https://$($_.rpc)/api/accounts/$($Config.Pools.$Name.Wallets."$($_.symbol)")" -delay $(if ($Count){500} else {0}) -cycletime ($Config.BalanceUpdateMinutes*60) -fixbigint
        $Count++
        if (-not $Request.stats) {
            Write-Log -Level Info "Pool Balance API ($Name) for $($_.symbol) returned nothing. "            
        } else {
			$Divisor = [Decimal]1e12
            [PSCustomObject]@{
                Caption     = "$($Name) ($($_.symbol))"
				BaseName    = $Name
                Currency    = $_.symbol
                Balance     = [Decimal]$Request.stats.balance/$Divisor
                Pending     = [Decimal]$Request.stats.pending/$Divisor
                Total       = [Decimal]$Request.stats.balance/$Divisor + [Decimal]$Request.stats.pending/$Divisor
                Paid        = [Decimal]$Request.stats.paid/$Divisor
                Earned      = [Decimal]0
                Payouts     = @(Get-BalancesPayouts $Request.payments -Divisor $Divisor)
                LastUpdated = (Get-Date).ToUniversalTime()
            }
        }
    }
    catch {
        if ($Error.Count){$Error.RemoveAt(0)}
        Write-Log -Level Warn "Pool Balance API ($Name) for $($_.Name) has failed. "
    }
}
