using module ..\Modules\Include.psm1

param(
    $Config
)

$Name = Get-Item $MyInvocation.MyCommand.Path | Select-Object -ExpandProperty BaseName

$Pools_Data = @(
    [PSCustomObject]@{symbol = "ETH";    port = @(1100); fee = 0.0; rpc = "eth-"}
    [PSCustomObject]@{symbol = "ETC";    port = @(5500); fee = 0.0; rpc = ""}
    [PSCustomObject]@{symbol = "XMR";    port = @(4400); fee = 0.0; rpc = ""}
    [PSCustomObject]@{symbol = "RVN";    port = @(6600); fee = 0.0; rpc = ""}
    [PSCustomObject]@{symbol = "BTG";    port = @(8800); fee = 0.0; rpc = ""}
    [PSCustomObject]@{symbol = "XWP";    port = @(9900); fee = 0.0; rpc = ""}
)

$Pools_Data | Where-Object {$Pool_Currency = "$($_.symbol -replace "\d+$")";$Config.Pools.$Name.Wallets.$Pool_Currency -and (-not $Config.ExcludeCoinsymbolBalances.Count -or $Config.ExcludeCoinsymbolBalances -notcontains $Pool_Currency)} | Foreach-Object {

    $Request = [PSCustomObject]@{}

    try {
        $Request = Invoke-RestMethodAsync "https://hellominer.com/api/v1?currency=$Pool_Currency&command=AccountBalance&address=$($Config.Pools.$Name.Wallets.$Pool_Currency)" -delay 100 -cycletime ($Config.BalanceUpdateMinutes*60) -timeout 15 | ConvertFrom-Json -ErrorAction Stop
        if (-not $Request.Status) {
            Write-Log -Level Info "Pool Balance API ($Name) for $($Pool_Currency)$(if ($Request.Message) {": $($Request.Message)"} else {" returned nothing."})"
        } else {
            [PSCustomObject]@{
                Caption     = "$($Name) ($Pool_Currency)"
				BaseName    = $Name
                Currency    = $Pool_Currency
                Balance     = [Decimal]$Request.Balance
                Pending     = [Decimal]0
                Total       = [Decimal]$Request.Balance
                Payouts     = @()
                LastUpdated = (Get-Date).ToUniversalTime()
            }
        }
    }
    catch {
        if ($Error.Count){$Error.RemoveAt(0)}
        Write-Log -Level Verbose "Pool Balance API ($Name) for $($Pool_Currency) has failed. "
    }
}
