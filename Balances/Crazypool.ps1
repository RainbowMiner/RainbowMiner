using module ..\Modules\Include.psm1

param(
    $Config
)

$Name = Get-Item $MyInvocation.MyCommand.Path | Select-Object -ExpandProperty BaseName

$Pools_Data = @(
    [PSCustomObject]@{rpc = "cau.crazypool.org";  symbol = "CAU";  port = @(3113,3223); fee = 1; region = $Pool_Regions}
    [PSCustomObject]@{rpc = "etc.crazypool.org";  symbol = "ETC";  port = @(7000,7777); fee = 1; region = $Pool_Regions}
    [PSCustomObject]@{rpc = "ethf.crazypool.org"; symbol = "ETHF"; port = @(8008,9009); fee = 1; region = $Pool_Regions}
    [PSCustomObject]@{rpc = "ethw.crazypool.org"; symbol = "ETHW"; port = @(3333,5555); fee = 1; region = $Pool_Regions}
    [PSCustomObject]@{rpc = "kas.crazypool.org";  symbol = "KAS";  port = @(5555);      fee = 1; region = @("sg","eu","us","br"); region_prefix = "kas-"}
    [PSCustomObject]@{rpc = "kls.crazypool.org";  symbol = "KLS";  port = @(5555);      fee = 1; region = @("sg","eu","us","br"); region_prefix = "kls-"}
    [PSCustomObject]@{rpc = "octa.crazypool.org"; symbol = "OCTA"; port = @(5225,5885); fee = 1; region = $Pool_Regions}
    #[PSCustomObject]@{rpc = "pac.crazypool.org";  symbol = "PAC";  port = @();      fee = 1; region = $Pool_Regions}
    [PSCustomObject]@{rpc = "rth.crazypool.org";  symbol = "RTH";  port = @(3553);      fee = 1; region = $Pool_Regions}
    [PSCustomObject]@{rpc = "ubq.crazypool.org";  symbol = "UBQ";  port = @(3335);      fee = 1; region = $Pool_Regions}
    [PSCustomObject]@{rpc = "xpb.crazypool.org";  symbol = "XPB";  port = @(4114,4224); fee = 1; region = $Pool_Regions}
    [PSCustomObject]@{rpc = "zil.crazypool.org";  symbol = "ZIL";  port = @(5005,5995); fee = 1; region = $Pool_Regions}
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
