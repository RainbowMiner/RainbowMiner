param(
    $Config
)

#https://xzc.2miners.com/api/accounts/aKB3gmAiNe3c4SasGbSo35sNoA3mAqrxtM
$Name = Get-Item $MyInvocation.MyCommand.Path | Select-Object -ExpandProperty BaseName

$Pools_Data = @(
    [PSCustomObject]@{rpc = "eth";   symbol = "ETH";   port = 2020; fee = 1.0; divisor = 1e18}
    [PSCustomObject]@{rpc = "etc";   symbol = "ETC";   port = 1010; fee = 1.0; divisor = 1e18}
    [PSCustomObject]@{rpc = "clo";   symbol = "CLO";   port = 3030; fee = 1.0; divisor = 1e18}
    [PSCustomObject]@{rpc = "moac";  symbol = "MOAC";  port = 5050; fee = 1.0; divisor = 1e18}
    [PSCustomObject]@{rpc = "exp";   symbol = "EXP";   port = 3030; fee = 1.0; divisor = 1e18}
    #[PSCustomObject]@{rpc = "music"; symbol = "MUSIC"; port = 4040; fee = 1.0; divisor = 1e18}
    [PSCustomObject]@{rpc = "pirl";  symbol = "PIRL";  port = 6060; fee = 1.0; divisor = 1e18}
    [PSCustomObject]@{rpc = "etp";   symbol = "ETP";   port = 9292; fee = 1.0; divisor = 1e18}
    #[PSCustomObject]@{rpc = "ella";  symbol = "ELLA";  port = 3030; fee = 1.0; divisor = 1e18}
    #[PSCustomObject]@{rpc = "dbix";  symbol = "DBIX";  port = 2020; fee = 1.0; divisor = 1e18}
    #[PSCustomObject]@{rpc = "yoc";   symbol = "YOC";   port = 4040; fee = 1.0; divisor = 1e18}
    #[PSCustomObject]@{rpc = "aka";   symbol = "AKA";   port = 5050; fee = 1.0; divisor = 1e18}
    [PSCustomObject]@{rpc = "zec";   symbol = "ZEC";   port = 1010; fee = 1.0; divisor = 1e8}
    [PSCustomObject]@{rpc = "zcl";   symbol = "ZCL";   port = 2020; fee = 1.0; divisor = 1e8}
    [PSCustomObject]@{rpc = "zen";   symbol = "ZEN";   port = 3030; fee = 1.0; divisor = 1e8}
    #[PSCustomObject]@{rpc = "hush";  symbol = "HUSH";  port = 7070; fee = 1.0; divisor = 1e8}
    #[PSCustomObject]@{rpc = "btcp";  symbol = "BTCP";  port = 1010; fee = 1.0; divisor = 1e8}
    [PSCustomObject]@{rpc = "btg";   symbol = "BTG";   port = 4040; fee = 1.0; divisor = 1e8}
    [PSCustomObject]@{rpc = "btcz";  symbol = "BTCZ";  port = 2020; fee = 1.0; divisor = 1e8}
    [PSCustomObject]@{rpc = "zel";   symbol = "ZEL";   port = 9090; fee = 1.0; divisor = 1e8}
    [PSCustomObject]@{rpc = "xmr";   symbol = "XMR";   port = 2222; fee = 1.0; divisor = 1e12}
    [PSCustomObject]@{rpc = "xzc";   symbol = "XZC";   port = 8080; fee = 1.0; divisor = 1e8}
    [PSCustomObject]@{rpc = "grin";  symbol = "GRIN";  port = 3030; fee = 1.0; divisor = 1e9; cycles = 42}
    [PSCustomObject]@{rpc = "ae";    symbol = "AE";    port = 4040; fee = 1.0; divisor = 1e8}
    [PSCustomObject]@{rpc = "rvn";   symbol = "RVN";   port = 6060; fee = 1.0; divisor = 1e8}
    [PSCustomObject]@{rpc = "beam";  symbol = "BEAM";  port = 5252; fee = 1.0; divisor = 1e8}
)


$Pools_Data | Where-Object {$Config.Pools.$Name.Wallets."$($_.symbol)"} | Foreach-Object {
    $Pool_Currency = $_.symbol

    $Request = [PSCustomObject]@{}
    $Divisor = if ($_.divisor) {$_.divisor} else {[Decimal]1e8}

    try {
        $Request = Invoke-RestMethodAsync "https://$($_.rpc).2miners.com/api/accounts/$(Get-WalletWithPaymentId $Config.Pools.$Name.Wallets.$Pool_Currency -pidchar '.')" -cycletime ($Config.BalanceUpdateMinutes*60)

        if (-not $Request.stats -or -not $Divisor) {
            Write-Log -Level Info "Pool Balance API ($Name) for $($Pool_Currency) returned nothing. "
        } else {
            [PSCustomObject]@{
                Caption     = "$($Name) ($Pool_Currency)"
                Currency    = $Pool_Currency
                Balance     = [Decimal]$Request.stats.balance / $Divisor
                Pending     = [Decimal]$Request.stats.pending / $Divisor
                Total       = [Decimal]$Request.stats.balance / $Divisor
                Paid        = [Decimal]$Request.stats.paid / $Divisor
                Payouts     = @($Request.payments | Foreach-Object {[PSCustomObject]@{time=$_.timestamp;amount=[Decimal]$_.amount / $Divisor;txid=$_.tx}})
                LastUpdated = (Get-Date).ToUniversalTime()
            }
        }
    }
    catch {
        if ($Error.Count){$Error.RemoveAt(0)}
        Write-Log -Level Verbose "Pool Balance API ($Name) for $($Pool_Currency) has failed. "
    }
}
