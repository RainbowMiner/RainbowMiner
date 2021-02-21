using module ..\Modules\Include.psm1

param(
    $Config
)

$Name = Get-Item $MyInvocation.MyCommand.Path | Select-Object -ExpandProperty BaseName

$Pools_Data = @(
    [PSCustomObject]@{symbol = "TCR";  port = 2200; fee = 0.5; rpc = "tcr"; regions = @("eu","us")}
    [PSCustomObject]@{symbol = "FIRO";  port = 7017; fee = 1.0; rpc = "zcoin"; regions = @("eu","us"); altsymbol = "XZC"}
    [PSCustomObject]@{symbol = "ZEL";  port = 7011; fee = 1.0; rpc = "zel"; regions = @("eu","us")}
)

$Pools_Data | Where-Object {($Config.Pools.$Name.Wallets."$($_.symbol)" -or ($_.altsymbol -and $Config.Pools.$Name.Wallets."$($_.altsymbol)")) -and (-not $Config.ExcludeCoinsymbolBalances.Count -or $Config.ExcludeCoinsymbolBalances -notcontains "$($_.symbol)")} | Foreach-Object {
    $Pool_Currency = $_.symbol
    $Pool_RpcPath = $_.rpc

    if (-not ($Pool_Wallet = $Config.Pools.$Name.Wallets."$($_.symbol)")) {
        $Pool_Wallet = $Config.Pools.$Name.Wallets."$($_.altsymbol)"
    }

    $Pool_Request = [PSCustomObject]@{}

    try {
        $Pool_Request = Invoke-RestMethodAsync "https://$($Pool_RpcPath).zellabs.net/api/worker_stats2?address=$($Pool_Wallet)&dataPoints=720&numSeconds=0" -tag $Name -cycletime 120 -timeout 30
        if (-not $Pool_Request) {
            Write-Log -Level Info "Pool Balance API ($Name) for $($Pool_Currency) returned nothing. "
        } else {
            [PSCustomObject]@{
                Caption     = "$($Name) ($Pool_Currency)"
				BaseName    = $Name
                Currency    = $Pool_Currency
                Balance     = [Decimal]$Pool_Request.balance
                Pending     = [Decimal]$Pool_Request.immature
                Total       = [Decimal]$Pool_Request.balance + [Decimal]$Pool_Request.immature
                Paid        = [Decimal]$Pool_Request.paid
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
