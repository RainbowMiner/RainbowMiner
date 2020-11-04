using module ..\Include.psm1

param(
    $Config
)

$Name = Get-Item $MyInvocation.MyCommand.Path | Select-Object -ExpandProperty BaseName

$Pools_Data = @(
    [PSCustomObject]@{symbol = "BEAM";  port = 3334; fee = 1.0; rpc = "beam"; region = @("eu")}
    [PSCustomObject]@{symbol = "XGM";   port = 3334; fee = 1.0; rpc = "defis"; region = @("eu"); altsymbol = "DEFIS"}
)

$Pools_Data | Where-Object {($Config.Pools.$Name.Wallets."$($_.symbol)" -or ($_.altsymbol -and $Config.Pools.$Name.Wallets."$($_.altsymbol)")) -and (-not $Config.ExcludeCoinsymbolBalances.Count -or $Config.ExcludeCoinsymbolBalances -notcontains "$($_.symbol)")} | Foreach-Object {
    $Pool_Currency = $_.symbol
    $Pool_RpcPath  = $_.rpc

    $Pool_Wallet   = if ($Config.Pools.$Name.Wallets.$Pool_Currency) {$Config.Pools.$Name.Wallets.$Pool_Currency} else {$Config.Pools.$Name.Wallets."$($_.altsymbol)"}

    $Request = [PSCustomObject]@{}

    try {
        $Request = Invoke-RestMethodAsync "https://$($Pool_RpcPath).acepool.top/api.php?query=miner-balances&miner=$($Pool_Wallet)" -delay 100 -cycletime ($Config.BalanceUpdateMinutes*60) -timeout 15
        if ($Request.status -ne "OK") {
            Write-Log -Level Info "Pool Balance API ($Name) for $($Pool_Currency) returned nothing. "
        } else {
            [PSCustomObject]@{
                Caption     = "$($Name) ($Pool_Currency)"
				BaseName    = $Name
                Currency    = $Pool_Currency
                Balance     = [Decimal]$Request.data.availableBalance
                Pending     = [Decimal]$Request.data.unconfirmedBalance
                Total       = [Decimal]$Request.data.availableBalance + [Decimal]$Request.data.unconfirmedBalance
                Paid        = [Decimal]$Request.data.totalPaid
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
