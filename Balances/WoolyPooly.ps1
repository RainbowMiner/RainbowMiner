using module ..\Modules\Include.psm1

param(
    $Config
)

$Name = Get-Item $MyInvocation.MyCommand.Path | Select-Object -ExpandProperty BaseName

$Payout_Currencies = @($Config.Pools.$Name.Wallets.PSObject.Properties | Select-Object) + @($Config.Pools."$($Name)Solo".Wallets.PSObject.Properties | Select-Object) | Where-Object Value | Select-Object Name,Value -Unique | Sort-Object Name,Value

#https://api.woolypooly.com/api/veil-1/accounts/bv1q46w7plr5lzjrn643m30g09vve8r3g4cheksr4p

$Pools_Data = @(
    [PSCustomObject]@{symbol = "AE";   port = 20000; host = "ae"; rpc = "aeternity-1"}
    [PSCustomObject]@{symbol = "AION"; port = 33333; host = "aion"; rpc = "aion-1"}
    [PSCustomObject]@{symbol = "ALPH"; port = 3106; host = "alph"; rpc = "alph-1"}
    [PSCustomObject]@{symbol = "CFX";  port = 3094; host = "cfx"; rpc = "cfx-1"}
    [PSCustomObject]@{symbol = "CTXC"; port = 40000; host = "cortex"; rpc = "cortex-1"}
    [PSCustomObject]@{symbol = "ERG";  port = 3100; host = "erg"; rpc = "ergo-1"}
    [PSCustomObject]@{symbol = "ETC";  port = 35000; host = "etc"; rpc = "etc-1"}
    [PSCustomObject]@{symbol = "ETH";  port = 3096; host = "eth"; rpc = "eth-1"}
    [PSCustomObject]@{symbol = "FIRO"; port = 3098; host = "firo"; rpc = "firo-1"}
    [PSCustomObject]@{symbol = "FLUX"; port = 3092; host = "zel"; rpc = "zel-1"}
    [PSCustomObject]@{symbol = "GRIN";  port = 12000; host = "grin"; rpc = "grin-1"}
    [PSCustomObject]@{symbol = "KVA"; port = 3112; host = "kva"; rpc = "kva-1"}
    [PSCustomObject]@{symbol = "MWC"; port = 11000; host = "mwc"; rpc = "mwc-1"}
    [PSCustomObject]@{symbol = "RTM"; port = 3110; host = "rtm"; rpc = "rtm-1"}
    [PSCustomObject]@{symbol = "RVN";  port = 55555; host = "rvn"; rpc = "raven-1"}
    [PSCustomObject]@{symbol = "VEIL"; port = 3098; host = "veil"; rpc = "veil-1"}
    [PSCustomObject]@{symbol = "VTC"; port = 3102; host = "vtc"; rpc = "vtc-1"}
    [PSCustomObject]@{symbol = "XMR"; port = 3108; host = "xmr"; rpc = "xmr-1"}
)

$Count = 0

$Payout_Currencies | Where-Object {-not $Config.ExcludeCoinsymbolBalances.Count -or $Config.ExcludeCoinsymbolBalances -notcontains "$($_.Name)"} | Foreach-Object {
    $Pool_Currency = $_.Name

    $Pool_Data = $Pools_Data | Where-Object {$_.symbol -eq $Pool_Currency}

    if (-not $Pool_Data) {
        Write-Log -Level Info "Pool Balance API ($Name) for $($Pool_Currency) missing data record. "
        return
    }

    $Request = [PSCustomObject]@{}

    try {
        $Request = Invoke-RestMethodAsync "https://api.woolypooly.com/api/$($Pool_Data.rpc)/accounts/$($_.Value)" -tag $Name -timeout 15 -delay 250 -cycletime ($Config.BalanceUpdateMinutes*60)
        if ($Request.stats) {
            [PSCustomObject]@{
                Caption     = "$($Name) ($Pool_Currency)"
			    BaseName    = $Name
                Currency    = $Pool_Currency
                Balance     = [Decimal]$Request.stats.balance
                Pending     = [Decimal]$Request.stats.immature_balance
                Total       = [Decimal]$Request.stats.balance + [Decimal]$Request.stats.immature_balance
                Paid        = [Decimal]$Request.stats.paid
                Payouts     = @(Get-BalancesPayouts $Request.payments | Select-Object)
                LastUpdated = (Get-Date).ToUniversalTime()
            }
        } else {
            Write-Log -Level Info "Pool Balance API ($Name) for $($Pool_Currency) returned nothing. "
        }
    }
    catch {
        if ($Error.Count){$Error.RemoveAt(0)}
        Write-Log -Level Verbose "Pool Balance API ($Name) for $($Pool_Currency) has failed. "
    }
    $Count++
}
