using module ..\Modules\Include.psm1

param(
    $Config,
    $UsePools
)

$Name = Get-Item $MyInvocation.MyCommand.Path | Select-Object -ExpandProperty BaseName

$Payout_Currencies = @()
foreach($PoolExt in @("","AE","Solo")) {
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
    [PSCustomObject]@{rpc = "ae";   symbol = "AE";       port = 4040; fee = 1.0; divisor = 1e8}
    [PSCustomObject]@{rpc = "beam"; symbol = "BEAM";     port = 5252; fee = 1.0; divisor = 1e8; ssl = $true}
    [PSCustomObject]@{rpc = "btg";  symbol = "BTG";      port = 4040; fee = 1.0; divisor = 1e8}
    [PSCustomObject]@{rpc = "ckb";  symbol = "CKB";      port = 6464; fee = 1.0; divisor = 1e8}
    [PSCustomObject]@{rpc = "clore";symbol = "CLORE";    port = 2020; fee = 1.0; divisor = 1e8}
    [PSCustomObject]@{rpc = "ctxc"; symbol = "CTXC";     port = 2222; fee = 1.0; divisor = 1e18}
    [PSCustomObject]@{rpc = "erg";  symbol = "ERG";      port = 8888; fee = 1.0; divisor = 1e9}
    [PSCustomObject]@{rpc = "etc";  symbol = "ETC";      port = 1010; fee = 1.0; divisor = 1e18}
    [PSCustomObject]@{rpc = "ethw"; symbol = "ETHW";     port = 2020; fee = 1.0; divisor = 1e18}
    [PSCustomObject]@{rpc = "firo"; symbol = "FIRO";     port = 8080; fee = 1.0; divisor = 1e8; altsymbol = "XZC"}
    [PSCustomObject]@{rpc = "flux"; symbol = "FLUX";     port = 9090; fee = 1.0; divisor = 1e8; altsymbol = "ZEL"}
    [PSCustomObject]@{rpc = "grin"; symbol = "GRIN-PRI"; port = 3030; fee = 1.0; divisor = 1e9; cycles = 42}
    [PSCustomObject]@{rpc = "kas";  symbol = "KAS";      port = 2020; fee = 1.0; divisor = 1e8}
    [PSCustomObject]@{rpc = "kls";  symbol = "KLS";      port = 2020; fee = 1.0; divisor = 1e8}
    [PSCustomObject]@{rpc = "neox"; symbol = "NEOX";     port = 4040; fee = 1.0; divisor = 1e8}
    [PSCustomObject]@{rpc = "nexa"; symbol = "NEXA";     port = 5050; fee = 1.0; divisor = 100}
    [PSCustomObject]@{rpc = "pyi";  symbol = "PYI";      port = 2121; fee = 1.0; divisor = 1e8}
    [PSCustomObject]@{rpc = "rvn";  symbol = "RVN";      port = 6060; fee = 1.0; divisor = 1e8}
    [PSCustomObject]@{rpc = "xmr";  symbol = "XMR";      port = 2222; fee = 1.0; divisor = 1e12}
    [PSCustomObject]@{rpc = "xna";  symbol = "XNA";      port = 6060; fee = 1.0; divisor = 1e8}
    [PSCustomObject]@{rpc = "zec";  symbol = "ZEC";      port = 1010; fee = 1.0; divisor = 1e8}
    [PSCustomObject]@{rpc = "zeph"; symbol = "ZEPH";     port = 2222; fee = 1.0; divisor = 1e12}
    [PSCustomObject]@{rpc = "zen";  symbol = "ZEN";      port = 3030; fee = 1.0; divisor = 1e8}

    #AutoExchange currencies BTC
    [PSCustomObject]@{rpc = "clore"; symbol = "BTC"; port = 2020; fee = 1.0; divisor = 1e8; aesymbol = "CLORE"}
    [PSCustomObject]@{rpc = "erg";   symbol = "BTC"; port = 8888; fee = 1.0; divisor = 1e9; aesymbol = "ERG"}
    [PSCustomObject]@{rpc = "etc";   symbol = "BTC"; port = 1010; fee = 1.0; divisor = 1e9; aesymbol = "ETC"}
    [PSCustomObject]@{rpc = "ethw";  symbol = "BTC"; port = 2020; fee = 1.0; divisor = 1e9; aesymbol = "ETHW"}
    [PSCustomObject]@{rpc = "kas";   symbol = "BTC"; port = 2020; fee = 1.0; divisor = 1e8; aesymbol = "KAS"}
    [PSCustomObject]@{rpc = "kls";   symbol = "BTC"; port = 2020; fee = 1.0; divisor = 1e8; aesymbol = "KLS"}
    [PSCustomObject]@{rpc = "nexa";  symbol = "BTC"; port = 5050; fee = 1.0; divisor = 100; aesymbol = "NEXA"}
    [PSCustomObject]@{rpc = "pyi";   symbol = "BTC"; port = 2121; fee = 1.0; divisor = 1e8; aesymbol = "PYI"}
    [PSCustomObject]@{rpc = "rvn";   symbol = "BTC"; port = 6060; fee = 1.0; divisor = 1e8; aesymbol = "RVN"}
    [PSCustomObject]@{rpc = "xna";   symbol = "BTC"; port = 6060; fee = 1.0; divisor = 1e8; aesymbol = "XNA"}

    #AutoExchange currencies TON
    [PSCustomObject]@{rpc = "clore"; symbol = "TON"; port = 2020; fee = 1.0; divisor = 1e8; aesymbol = "CLORE"}
    [PSCustomObject]@{rpc = "erg";   symbol = "TON"; port = 8888; fee = 1.0; divisor = 1e9; aesymbol = "ERG"}
    [PSCustomObject]@{rpc = "etc";   symbol = "TON"; port = 1010; fee = 1.0; divisor = 1e9; aesymbol = "ETC"}
    [PSCustomObject]@{rpc = "ethw";  symbol = "TON"; port = 2020; fee = 1.0; divisor = 1e9; aesymbol = "ETHW"}
    [PSCustomObject]@{rpc = "kas";   symbol = "TON"; port = 2020; fee = 1.0; divisor = 1e8; aesymbol = "KAS"}
    #[PSCustomObject]@{rpc = "kls";   symbol = "TON"; port = 2020; fee = 1.0; divisor = 1e8; aesymbol = "KLS"}
    #[PSCustomObject]@{rpc = "nexa";  symbol = "TON"; port = 5050; fee = 1.0; divisor = 100; aesymbol = "NEXA"}
    #[PSCustomObject]@{rpc = "pyi";   symbol = "TON"; port = 2121; fee = 1.0; divisor = 1e8; aesymbol = "PYI"}
    [PSCustomObject]@{rpc = "rvn";   symbol = "TON"; port = 6060; fee = 1.0; divisor = 1e8; aesymbol = "RVN"}
    [PSCustomObject]@{rpc = "xna";   symbol = "TON"; port = 6060; fee = 1.0; divisor = 1e8; aesymbol = "XNA"}

)

$Payout_Currencies | Where-Object {
        $Pool_CoinSymbol = $_.Name
        $Pool_Wallet     = $_.Value
        $Pool_Data = $Pools_Data | Where-Object {
            ($_.symbol -eq $Pool_CoinSymbol -or $_.altsymbol -eq $Pool_CoinSymbol) -and
            (-not $_.aesymbol -or "$($Name)AE" -notin $Config.PoolName -or (
                (-not $Config.Pools."$($Name)AE".CoinSymbol.Count -or $_.aesymbol -in $Config.Pools."$($Name)AE".CoinSymbol) -and
                (-not $Config.Pools."$($Name)AE".ExcludeCoinSymbol.Count -or $_.aesymbol -notin $Config.Pools."$($Name)AE".ExcludeCoinSymbol)
            ))
        }
        $Pool_Data -and (-not $Config.ExcludeCoinsymbolBalances.Count -or $Pool_CoinSymbol -notin $Config.ExcludeCoinsymbolBalances)
    } | Foreach-Object {

    $Pool_Data | Foreach-Object {

        $Request = [PSCustomObject]@{}
        $Divisor = if ($_.divisor) {$_.divisor} else {[Decimal]1e8}

        $Pool_Name     = $Name
        $Pool_Currency = $Pool_CoinSymbol
        $Pool_Info     = $null
        if ($_.aesymbol) {
            $Pool_Name     = "$($Name)AE"
            $Pool_Info     = "AE $($Pool_CoinSymbol)"
            $Pool_Currency = $_.aesymbol
        }

        try {
            $Request = Invoke-RestMethodAsync "https://$($_.rpc).2miners.com/api/accounts/$(Get-WalletWithPaymentId $Pool_Wallet -pidchar '.')" -cycletime ($Config.BalanceUpdateMinutes*60)

            if (-not $Request.stats -or -not $Divisor) {
                Write-Log -Level Info "Pool Balance API ($($Pool_Name)) for $($Pool_Currency) returned nothing. "
            } else {
                [PSCustomObject]@{
                    Caption     = "$($Pool_Name) ($Pool_Currency)"
				    BaseName    = $Pool_Name
                    Info        = $Pool_Info
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
            Write-Log -Level Verbose "Pool Balance API ($($Pool_Name)) for $($Pool_Currency) has failed. "
        }
    }
}
