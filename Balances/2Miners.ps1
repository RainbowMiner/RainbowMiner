param(
    $Config
)

#https://xzc.2miners.com/api/accounts/aKB3gmAiNe3c4SasGbSo35sNoA3mAqrxtM
$Name = Get-Item $MyInvocation.MyCommand.Path | Select-Object -ExpandProperty BaseName

$Pools_Data = @(
    [PSCustomObject]@{rpc = "eth";   coin = "Ethereum";        algo = "Ethash";       symbol = "ETH";   port = 2020; fee = 1.5; divisor = 1e18}
    [PSCustomObject]@{rpc = "etc";   coin = "EthereumClassic"; algo = "Ethash";       symbol = "ETC";   port = 1010; fee = 1.5; divisor = 1e18}
    [PSCustomObject]@{rpc = "clo";   coin = "Callisto";        algo = "Ethash";       symbol = "CLO";   port = 3030; fee = 1.5; divisor = 1e18}
    [PSCustomObject]@{rpc = "moac";  coin = "MOAC";            algo = "Ethash";       symbol = "MOAC";  port = 5050; fee = 1.5; divisor = 1e18}
    [PSCustomObject]@{rpc = "exp";   coin = "Expanse";         algo = "Ethash";       symbol = "EXP";   port = 3030; fee = 1.5; divisor = 1e18}
    [PSCustomObject]@{rpc = "music"; coin = "Musicoin";        algo = "Ethash";       symbol = "MUSIC"; port = 4040; fee = 1.5; divisor = 1e18}
    [PSCustomObject]@{rpc = "pirl";  coin = "Pirl";            algo = "Ethash";       symbol = "PIRL";  port = 6060; fee = 1.5; divisor = 1e18}
    [PSCustomObject]@{rpc = "etp";   coin = "Metaverse ETP";   algo = "Ethash";       symbol = "ETP";   port = 9292; fee = 1.5; divisor = 1e18}
    #[PSCustomObject]@{rpc = "ella";  coin = "Ellaism";         algo = "Ethash";       symbol = "ELLA";  port = 3030; fee = 1.5; divisor = 1e18}
    #[PSCustomObject]@{rpc = "dbix";  coin = "Dubaicoin";       algo = "Ethash";       symbol = "DBIX";  port = 2020; fee = 1.5; divisor = 1e18}
    #[PSCustomObject]@{rpc = "yoc";   coin = "Yocoin";          algo = "Ethash";       symbol = "YOC";   port = 4040; fee = 1.5; divisor = 1e18}
    [PSCustomObject]@{rpc = "aka";   coin = "Akroma";          algo = "Ethash";       symbol = "AKA";   port = 5050; fee = 1.5; divisor = 1e18}
    [PSCustomObject]@{rpc = "zec";   coin = "Zcash";           algo = "Equihash";     symbol = "ZEC";   port = 1010; fee = 1.5; divisor = 1e8}
    [PSCustomObject]@{rpc = "zcl";   coin = "Zclassic";        algo = "Equihash";     symbol = "ZCL";   port = 2020; fee = 1.5; divisor = 1e8}
    [PSCustomObject]@{rpc = "zen";   coin = "Zencash";         algo = "Equihash";     symbol = "ZEN";   port = 3030; fee = 1.5; divisor = 1e8}
    #[PSCustomObject]@{rpc = "hush";  coin = "Hush";            algo = "Equihash";     symbol = "HUSH";  port = 7070; fee = 1.5; divisor = 1e8}
    #[PSCustomObject]@{rpc = "btcp";  coin = "BitcoinPrivate";  algo = "Equihash";     symbol = "BTCP";  port = 1010; fee = 1.5; divisor = 1e8}
    [PSCustomObject]@{rpc = "btg";   coin = "BitcoinGold";     algo = "Equihash24x5"; symbol = "BTG";   port = 4040; fee = 1.5; divisor = 1e8}
    [PSCustomObject]@{rpc = "btcz";  coin = "BitcoinZ";        algo = "Equihash24x5"; symbol = "BTCZ";  port = 2020; fee = 1.5; divisor = 1e8}
    [PSCustomObject]@{rpc = "zel";   coin = "ZelCash";         algo = "Equihash25x4"; symbol = "ZEL";   port = 9090; fee = 1.5; divisor = 1e8}
    [PSCustomObject]@{rpc = "xmr";   coin = "Monero";          algo = "Monero";       symbol = "XMR";   port = 2222; fee = 1.5; divisor = 1e12}
    [PSCustomObject]@{rpc = "xzc";   coin = "Zсoin";           algo = "MTP";          symbol = "XZC";   port = 8080; fee = 1.5; divisor = 1e8}
    [PSCustomObject]@{rpc = "rvn";   coin = "RavenCoin";       algo = "X16R";         symbol = "RVN";   port = 6060; fee = 1.5; divisor = 1e8}
    [PSCustomObject]@{rpc = "grin";  coin = "GRIN";            algo = "Cuckarood29";  symbol = "GRIN";  port = 3030; fee = 1.5; divisor = 1e9; cycles = 42}
    #[PSCustomObject]@{rpc = "grin";  coin = "GRIN";            algo = "Cuckatoo31";   symbol = "GRIN";  port = 3030; fee = 1.5; divisor = 1e9; cycles = 42; primary = $true}
    #[PSCustomObject]@{rpc = "progpow-eth"; coin = "Ethereum ProgPoW"; algo = "ProgPoW"; symbol = "ETH"; port = 2020; fee = 1.5; divisor = 1e18}
)

$Pools_Data | Where-Object {$Config.Pools.$Name.Wallets."$($_.symbol)"} | Foreach-Object {
    $Pool_Currency = $_.symbol

    $Request = [PSCustomObject]@{}
    $Divisor = 1e8

    try {
        $Request = Invoke-RestMethodAsync "https://$($_.rpc).2miners.com/api/accounts/$($Config.Pools.$Name.Wallets.$Pool_Currency)" -cycletime ($Config.BalanceUpdateMinutes*60)

        if (-not $Request.stats -or -not $Divisor) {
            Write-Log -Level Info "Pool Balance API ($Name) for $($Pool_Currency) returned nothing. "
        } else {
            [PSCustomObject]@{
                Caption     = "$($Name) ($Pool_Currency)"
                Currency    = $Pool_Currency
                Balance     = $Request.stats.balance / $Divisor
                Pending     = $Request.stats.pending / $Divisor
                Total       = $Request.stats.balance / $Divisor
                Payed       = $Request.stats.paid / $Divisor
                Payouts     = @($Request.payments | Foreach-Object {[PSCustomObject]@{time=$_.timestamp;amount=$_.amount / $Divisor;txid=$_.tx}})
                LastUpdated = (Get-Date).ToUniversalTime()
            }
        }
    }
    catch {
        if ($Error.Count){$Error.RemoveAt(0)}
        Write-Log -Level Verbose "Pool Balance API ($Name) for $($Pool_Currency) has failed. "
    }
}
