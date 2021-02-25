﻿using module ..\Modules\Include.psm1

param(
    $Config
)

#https://xzc.2miners.com/api/accounts/aKB3gmAiNe3c4SasGbSo35sNoA3mAqrxtM
$Name = Get-Item $MyInvocation.MyCommand.Path | Select-Object -ExpandProperty BaseName

$Pools_Data = @(
    [PSCustomObject]@{rpc = "ae";    symbol = "AE";    port = 4040; fee = 1.0; divisor = 1e8}
    [PSCustomObject]@{rpc = "beam";  symbol = "BEAM";  port = 5252; fee = 1.0; divisor = 1e8}
    [PSCustomObject]@{rpc = "btg";   symbol = "BTG";   port = 4040; fee = 1.0; divisor = 1e8}
    [PSCustomObject]@{rpc = "ckb";   symbol = "CKB";   port = 6464; fee = 1.0; divisor = 1e8}
    [PSCustomObject]@{rpc = "clo";   symbol = "CLO";   port = 3030; fee = 1.0; divisor = 1e9}
    [PSCustomObject]@{rpc = "ctxc";  symbol = "CTXC";  port = 2222; fee = 1.0; divisor = 1e9}
    [PSCustomObject]@{rpc = "etc";   symbol = "ETC";   port = 1010; fee = 1.0; divisor = 1e9}
    [PSCustomObject]@{rpc = "eth";   symbol = "ETH";   port = 2020; fee = 1.0; divisor = 1e9}
    [PSCustomObject]@{rpc = "etp";   symbol = "ETP";   port = 9292; fee = 1.0; divisor = 1e9}
    [PSCustomObject]@{rpc = "exp";   symbol = "EXP";   port = 3030; fee = 1.0; divisor = 1e9}
    [PSCustomObject]@{rpc = "grin";  symbol = "GRIN";  port = 3030; fee = 1.0; divisor = 1e9; cycles = 42}
    [PSCustomObject]@{rpc = "mwc";   symbol = "MWC";   port = 1111; fee = 1.0; divisor = 1e9; cycles = 42}
    [PSCustomObject]@{rpc = "pirl";  symbol = "PIRL";  port = 6060; fee = 1.0; divisor = 1e9}
    [PSCustomObject]@{rpc = "rvn";   symbol = "RVN";   port = 6060; fee = 1.0; divisor = 1e8}
    [PSCustomObject]@{rpc = "xmr";   symbol = "XMR";   port = 2222; fee = 1.0; divisor = 1e12}
    [PSCustomObject]@{rpc = "xzc";   symbol = "FIRO";   port = 8080; fee = 1.0; divisor = 1e8; altsymbol = "XZC"}
    [PSCustomObject]@{rpc = "zec";   symbol = "ZEC";   port = 1010; fee = 1.0; divisor = 1e8}
    [PSCustomObject]@{rpc = "zel";   symbol = "ZEL";   port = 9090; fee = 1.0; divisor = 1e8}
    [PSCustomObject]@{rpc = "zen";   symbol = "ZEN";   port = 3030; fee = 1.0; divisor = 1e8}
)

$Pools_Data | Where-Object {($Config.Pools.$Name.Wallets."$($_.symbol)" -or ($_.altsymbol -and $Config.Pools.$Name.Wallets."$($_.altsymbol)")) -and (-not $Config.ExcludeCoinsymbolBalances.Count -or $Config.ExcludeCoinsymbolBalances -notcontains "$($_.symbol)")} | Foreach-Object {
    $Pool_Currency = $_.symbol

    $Request = [PSCustomObject]@{}
    $Divisor = if ($_.divisor) {$_.divisor} else {[Decimal]1e8}

    if (-not ($Pool_Wallet = $Config.Pools.$Name.Wallets."$($_.symbol)")) {
        $Pool_Wallet = $Config.Pools.$Name.Wallets."$($_.altsymbol)"
    }

    try {
        $Request = Invoke-RestMethodAsync "https://$($_.rpc).2miners.com/api/accounts/$(Get-WalletWithPaymentId $Pool_Wallet -pidchar '.')" -cycletime ($Config.BalanceUpdateMinutes*60)

        if (-not $Request.stats -or -not $Divisor) {
            Write-Log -Level Info "Pool Balance API ($Name) for $($Pool_Currency) returned nothing. "
        } else {
            [PSCustomObject]@{
                Caption     = "$($Name) ($Pool_Currency)"
				BaseName    = $Name
                Currency    = $Pool_Currency
                Balance     = [Decimal]$Request.stats.balance / $Divisor
                Pending     = [Decimal]$Request.stats.immature / $Divisor
                Total       = ([Decimal]$Request.stats.balance + [Decimal]$Request.stats.immature ) / $Divisor
                Paid        = [Decimal]$Request.stats.paid / $Divisor
                Payouts     = @(Get-BalancesPayouts $Request.payments -Divisor $Divisor | Select-Object)
                LastUpdated = (Get-Date).ToUniversalTime()
            }
        }
    }
    catch {
        if ($Error.Count){$Error.RemoveAt(0)}
        Write-Log -Level Verbose "Pool Balance API ($Name) for $($Pool_Currency) has failed. "
    }
}
