using module ..\Modules\Include.psm1

param(
    $Config,
    $UsePools
)

$Name = Get-Item $MyInvocation.MyCommand.Path | Select-Object -ExpandProperty BaseName

$Payout_Currencies = @()
foreach($PoolExt in @("","Solo")) {
    if (-not $UsePools -or "$($Name)$($PoolExt)" -in $UsePools) {
        $Payout_Currencies += @($Config.Pools."$($Name)$($PoolExt)".Wallets.PSObject.Properties | Select-Object)
    }
}

$Payout_Currencies = $Payout_Currencies | Where-Object Value | Select-Object Name,Value -Unique | Sort-Object Name,Value

if (-not $Payout_Currencies) {
    Write-Log -Level Verbose "Cannot get balance on pool ($Name) - no wallet address specified. "
    return
}

$Pools_Data = @(
    [PSCustomObject]@{symbol = "AE";   port = 20000; host = "ae"; rpc = "aeternity-1"}
    [PSCustomObject]@{symbol = "ALPH"; port = 3106; host = "alph"; rpc = "alph-1"}
    [PSCustomObject]@{symbol = "BLOCX";  port = 3148; host = "blocx"; rpc = "blocx-1"}
    [PSCustomObject]@{symbol = "CFX";  port = 3094; host = "cfx"; rpc = "cfx-1"}
    [PSCustomObject]@{symbol = "CLO";  port = 3126; host = "clore"; rpc = "clore-1"}
    [PSCustomObject]@{symbol = "CTXC"; port = 40000; host = "cortex"; rpc = "cortex-1"}
    [PSCustomObject]@{symbol = "ERG";  port = 3100; host = "erg"; rpc = "ergo-1"}
    [PSCustomObject]@{symbol = "ETC";  port = 35000; host = "etc"; rpc = "etc-1"}
    [PSCustomObject]@{symbol = "ETHW";  port = 3096; host = "ethw"; rpc = "ethw-1"}
    [PSCustomObject]@{symbol = "FIRO"; port = 3098; host = "firo"; rpc = "firo-1"}
    [PSCustomObject]@{symbol = "HTN"; port = 3142; host = "htn"; rpc = "htn-1"}
    [PSCustomObject]@{symbol = "KAS"; port = 3112; host = "kas"; rpc = "kas-1"}
    [PSCustomObject]@{symbol = "KLS"; port = 3132; host = "kls"; rpc = "kls-1"}
    [PSCustomObject]@{symbol = "MEWC"; port = 3116; host = "mewc"; rpc = "mewc-1"}
    [PSCustomObject]@{symbol = "NEXA"; port = 3124; host = "nexa"; rpc = "nexa-1"}
    [PSCustomObject]@{symbol = "NOVO"; port = 3134; host = "novo"; rpc = "novo-1"}
    [PSCustomObject]@{symbol = "OCTA"; port = 3130; host = "octa"; rpc = "octa-1"}
    [PSCustomObject]@{symbol = "RTM"; port = 3110; host = "rtm"; rpc = "rtm-1"}
    [PSCustomObject]@{symbol = "RVN";  port = 55555; host = "rvn"; rpc = "raven-1"}
    [PSCustomObject]@{symbol = "RXD"; port = 3122; host = "rxd"; rpc = "rxd-1"}
    [PSCustomObject]@{symbol = "SDR"; port = 3144; host = "sdr"; rpc = "sdr-1"}
    [PSCustomObject]@{symbol = "VTC"; port = 3102; host = "vtc"; rpc = "vtc-1"}
    [PSCustomObject]@{symbol = "WART"; port = 3140; host = "wart"; rpc = "wart-1"}
    [PSCustomObject]@{symbol = "XNA"; port = 3128; host = "xna"; rpc = "xna-1"}
    [PSCustomObject]@{symbol = "ZANO"; port = 3146; host = "zano"; rpc = "zano-1"}
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
                Name        = $Name
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
        Write-Log -Level Verbose "Pool Balance API ($Name) for $($Pool_Currency) has failed. "
    }
    $Count++
}
