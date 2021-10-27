using module ..\Modules\Include.psm1

param(
    $Config
)

#https://xzc.2miners.com/api/accounts/aKB3gmAiNe3c4SasGbSo35sNoA3mAqrxtM
$Name = Get-Item $MyInvocation.MyCommand.Path | Select-Object -ExpandProperty BaseName

$Payout_Currencies = @($Config.Pools.$Name.Wallets.PSObject.Properties | Select-Object) + @($Config.Pools."$($Name)AE".Wallets.PSObject.Properties | Select-Object) + @($Config.Pools."$($Name)Solo".Wallets.PSObject.Properties | Select-Object) | Where-Object Value | Select-Object Name,Value -Unique | Sort-Object Name,Value

$Pools_Data = @(
    [PSCustomObject]@{rpc = "ae";    symbol = "AE";    port = 4040; fee = 1.0; divisor = 1e8}
    [PSCustomObject]@{rpc = "beam";  symbol = "BEAM";  port = 5252; fee = 1.0; divisor = 1e8; ssl = $true}
    [PSCustomObject]@{rpc = "btg";   symbol = "BTG";   port = 4040; fee = 1.0; divisor = 1e8}
    [PSCustomObject]@{rpc = "ckb";   symbol = "CKB";   port = 6464; fee = 1.0; divisor = 1e8}
    [PSCustomObject]@{rpc = "clo";   symbol = "CLO";   port = 3030; fee = 1.0; divisor = 1e18}
    [PSCustomObject]@{rpc = "ctxc";  symbol = "CTXC";  port = 2222; fee = 1.0; divisor = 1e18}
    [PSCustomObject]@{rpc = "erg";   symbol = "ERG";   port = 9999; fee = 1.5; divisor = 1e9}
    [PSCustomObject]@{rpc = "etc";   symbol = "ETC";   port = 1010; fee = 1.0; divisor = 1e18}
    [PSCustomObject]@{rpc = "eth";   symbol = "ETH";   port = 2020; fee = 1.0; divisor = 1e18}
    [PSCustomObject]@{rpc = "etp";   symbol = "ETP";   port = 9292; fee = 1.0; divisor = 1e18}
    [PSCustomObject]@{rpc = "exp";   symbol = "EXP";   port = 3030; fee = 1.0; divisor = 1e18}
    [PSCustomObject]@{rpc = "grin";  symbol = "GRIN-PRI";port = 3030; fee = 1.0; divisor = 1e9; cycles = 42}
    [PSCustomObject]@{rpc = "mwc";   symbol = "MWC-PRI"; port = 1111; fee = 1.0; divisor = 1e9; cycles = 42}
    [PSCustomObject]@{rpc = "rvn";   symbol = "RVN";   port = 6060; fee = 1.0; divisor = 1e8}
    [PSCustomObject]@{rpc = "xmr";   symbol = "XMR";   port = 2222; fee = 1.0; divisor = 1e12}
    [PSCustomObject]@{rpc = "firo";  symbol = "FIRO";   port = 8080; fee = 1.0; divisor = 1e8; altsymbol = "XZC"}
    [PSCustomObject]@{rpc = "zec";   symbol = "ZEC";   port = 1010; fee = 1.0; divisor = 1e8}
    [PSCustomObject]@{rpc = "zel";   symbol = "FLUX";   port = 9090; fee = 1.0; divisor = 1e8; altsymbol = "ZEL"}
    [PSCustomObject]@{rpc = "zen";   symbol = "ZEN";   port = 3030; fee = 1.0; divisor = 1e8}

    #AutoExchange currencies
    [PSCustomObject]@{rpc = "eth";   symbol = "BTC";   port = 2020; fee = 1.0; divisor = 1e8}
    [PSCustomObject]@{rpc = "eth";   symbol = "NANO";   port = 2020; fee = 1.0; divisor = 1e8}
)

$Payout_Currencies | Where-Object {$Pool_Currency = $_.Name;$Pool_Data = $Pools_Data | Where-Object {$_.symbol -eq $Pool_Currency -or $_.altsymbol -eq $Pool_Currency};$Pool_Data -and (-not $Config.ExcludeCoinsymbolBalances.Count -or $Config.ExcludeCoinsymbolBalances -notcontains "$($_.Name)")} | Foreach-Object {

    $Request = [PSCustomObject]@{}
    $Divisor = if ($Pool_Data.divisor) {$Pool_Data.divisor} else {[Decimal]1e8}

    $Pool_Wallet = $_.Value

    try {
        $Request = Invoke-RestMethodAsync "https://$($Pool_Data.rpc).2miners.com/api/accounts/$(Get-WalletWithPaymentId $Pool_Wallet -pidchar '.')" -cycletime ($Config.BalanceUpdateMinutes*60)

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
