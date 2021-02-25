using module ..\Modules\Include.psm1

param(
    $Config
)

if (-not $Config.ShowWalletBalances) {return}

$Name = Get-Item $MyInvocation.MyCommand.Path | Select-Object -ExpandProperty BaseName

#
# Bitcoin wallet
#

$Wallets = @($Config.Wallet) + @($Config.Coins.PSObject.Properties | Where-Object {"$($_.Name -replace "_\d+$")" -eq "BTC"} | Foreach-Object {$_.Value}) + @($Config.Pools.PSObject.Properties.Value | Where-Object {$_.Wallets.BTC} | Foreach-Object {$_.Wallets.BTC}) | Where-Object {$_ -match "^[13]|^bc1"} | Select-Object -Unique | Sort-Object

if (($Wallets | Measure-Object).Count -and (-not $Config.WalletBalances.Count -or $Config.WalletBalances -contains "BTC") -and (-not $Config.ExcludeCoinsymbolBalances.Count -or $Config.ExcludeCoinsymbolBalances -notcontains "BTC")) {
    $Request = [PSCustomObject]@{}

    $Success = $true
    try {
        $Request = Invoke-RestMethodAsync "https://blockchain.info/multiaddr?active=$($Wallets -join "|")&n=0" -cycletime ($Config.BalanceUpdateMinutes*60)
        if ($Request.addresses -eq $null) {$Success = $false}
    }
    catch {
        if ($Error.Count){$Error.RemoveAt(0)}
        $Success=$false
    }

    if (-not $Success) {
        Write-Log -Level Warn "BTC Balance API ($Name) has failed. "
        return
    }

    $Request.addresses | Sort-Object {$_.address} | Foreach-Object {
        [PSCustomObject]@{
                Caption     = "$($Name) BTC ($($_.address))"
		        BaseName    = $Name
                Info        = " $($_.address.Substring(0,3))..$($_.address.Substring($_.address.Length-3,3))"
                Currency    = "BTC"
                Balance     = [Decimal]$_.final_balance / 1e8
                Pending     = 0
                Total       = [Decimal]$_.final_balance / 1e8
                Earned      = [Decimal]$_.total_received / 1e8
                Payouts     = @()
                LastUpdated = (Get-Date).ToUniversalTime()
        }
    }
}

#
# Other wallets
#

$Wallets_Data = @(
    [PSCustomObject]@{symbol = "AE";   match = "^ak_";  rpc = "http://www.aeknow.org/api/account/{w}";                                address = "id";                               balance = "balance";                         received = "";                                 divisor = 1e18}
    [PSCustomObject]@{symbol = "BCH";  match = "^1";    rpc = "https://api.blockchair.com/bitcoin-cash/dashboards/address/{w}";       address = "data.{w}.address.legacy";          balance = "data.{w}.address.balance";        received = "data.{w}.address.received";        divisor = 1e8; verify = "context.code"; verify_value = "200"}
    [PSCustomObject]@{symbol = "BCH";  match = "^q";    rpc = "https://api.blockchair.com/bitcoin-cash/dashboards/address/{w}";       address = "data.{w}.address.cashaddr";        balance = "data.{w}.address.balance";        received = "data.{w}.address.received";        divisor = 1e8; verify = "context.code"; verify_value = "200"}
    [PSCustomObject]@{symbol = "DASH"; match = "^X";    rpc = "https://api.blockcypher.com/v1/dash/main/addrs/{w}";                   address = "address";                          balance = "balance";                         received = "total_received";                   divisor = 1e8}
    [PSCustomObject]@{symbol = "DOGE"; match = "^D";    rpc = "https://api.blockcypher.com/v1/doge/main/addrs/{w}";                   address = "address";                          balance = "balance";                         received = "total_received";                   divisor = 1e8}
    [PSCustomObject]@{symbol = "ETH";  match = "^0x";   rpc = "https://api.blockcypher.com/v1/eth/main/addrs/{w}";                    address = "address";                          balance = "balance";                         received = "total_received";                   divisor = 1e18}
    [PSCustomObject]@{symbol = "FIRO"; match = "^[aZ]"; rpc = "https://explorer.zcoin.io/insight-api-zcoin/addr/{w}/?noTxList=1";     address = "addrStr";                          balance = "balance";                         received = "totalReceived";                    divisor = 1}
    [PSCustomObject]@{symbol = "LTC";  match = "^[M3]"; rpc = "https://sochain.com/api/v2/get_address_balance/ltc/{w}";               address = "data.address";                     balance = "data.confirmed_balance";          received = "";                                 divisor = 1; verify = "status"; verify_value = "success"}
    [PSCustomObject]@{symbol = "RVN";  match = "^R";    rpc = "https://ravencoin.network/api/addr/{w}/?noTxList=1";                   address = "addrStr";                          balance = "balance";                         received = "totalReceived";                    divisor = 1}
    [PSCustomObject]@{symbol = "SAFE"; match = "^R";    rpc = "https://explorer.safecoin.org/api/addr/{w}/?noTxList=1";               address = "addrStr";                          balance = "balance";                         received = "totalReceived";                    divisor = 1}
    [PSCustomObject]@{symbol = "XLM";  match = "^G";    rpc = "https://horizon.stellar.org/accounts/{w}";                             address = "id";                               balance = "balances";                        received = "";                                 divisor = 1}
	[PSCustomObject]@{symbol = "XRP";  match = "^r";    rpc = "https://api.xrpscan.com/api/v1/account/{w}";                           address = "account";                          balance = "xrpBalance";                      received = "";                                 divisor = 1}
	[PSCustomObject]@{symbol = "XTZ";  match = "^tz";   rpc = "https://api.blockchair.com/tezos/raw/account/{w}";                     address = "data.{w}.account.address";         balance = "data.{w}.account.total_balance";  received = "data.{w}.account.total_received";  divisor = 1}
    [PSCustomObject]@{symbol = "ZEC";  match = "^t";    rpc = "https://api.zcha.in/v2/mainnet/accounts/{w}";                          address = "address";                          balance = "balance";                         received = "totalRecv";                        divisor = 1}
)

foreach ($Wallet_Data in $Wallets_Data) {
    $Wallet_Symbol  = $Wallet_Data.symbol

    if ((-not $Config.WalletBalances.Count -or $Config.WalletBalances -contains $Wallet_Symbol) -and (-not $Config.ExcludeCoinsymbolBalances.Count -or $Config.ExcludeCoinsymbolBalances -notcontains $Wallet_Symbol)) {

        @($Config.Coins.PSObject.Properties | Where-Object {"$($_.Name -replace "_\d+$")" -eq $Wallet_Symbol -and $_.Value.Wallet -match $Wallet_Data.match} | Foreach-Object {$_.Value.Wallet}) + @($Config.Pools.PSObject.Properties.Value | Where-Object {$_.Wallets.$Wallet_Symbol -match $Wallet_Data.match} | Foreach-Object {$_.Wallets.$Wallet_Symbol}) | Select-Object -Unique | Sort-Object | Foreach-Object {

            $Wallet_Address = $_

            $Request = [PSCustomObject]@{}

            $Success = $true
            try {
                $Request = Invoke-RestMethodAsync "$($Wallet_Data.rpc -replace "{w}",$Wallet_Address)" -cycletime ($Config.BalanceUpdateMinutes*60) -fixbigint
                if (($Wallet_Data.verify -eq $null -and "$(Invoke-Expression "`$Request.$($Wallet_Data.address -replace "{w}",$Wallet_Address)")" -ne $Wallet_Address) -or 
                    ($Wallet_Data.verify -ne $null -and "$(Invoke-Expression "`$Request.$($Wallet_Data.verify -replace "{w}",$Wallet_Address)")" -ne $Wallet_Data.verify_value)
                    ) {$Success = $false}
            }
            catch {
                if ($Error.Count){$Error.RemoveAt(0)}
                $Success=$false
            }

            if (-not $Success) {
                Write-Log -Level Verbose "$Wallet_Symbol Balance API ($Name) for $Wallet_Address has failed. "
                return
            }

            $Wallet_Info = $Wallet_Address -replace "^0x"

            $Wallet_Balance = [Decimal]$(Switch ($Wallet_Symbol) {
                "XLM" {
                    ($Request.balances | Where-Object {$_.asset_type -eq "native"} | Select-Object -ExpandProperty balance | Measure-Object -Sum).Sum
                }
                default {
                    $val = $null
                    $Wallet_Data.balance -replace "{w}",$Wallet_Address -split "\." | Foreach-Object {
                        $val = if ($val -ne $null) {$val.$_} else {$Request.$_}
                    }
                    $val
                }
            })

            [PSCustomObject]@{
                    Caption     = "$Name $Wallet_Symbol ($Wallet_Address)"
		            BaseName    = $Name
                    Info        = " $($Wallet_Info.Substring(0,3))..$($Wallet_Info.Substring($Wallet_Info.Length-3,3))"
                    Currency    = $Wallet_Symbol
                    Balance     = $Wallet_Balance / $Wallet_Data.divisor
                    Pending     = 0
                    Total       = $Wallet_Balance / $Wallet_Data.divisor
                    Earned      = if ($Wallet_Data.received) {[Decimal](Invoke-Expression "`$Request.$($Wallet_Data.received)") / $Wallet_Data.divisor} else {$null}
                    Payouts     = @()
                    LastUpdated = (Get-Date).ToUniversalTime()
            }
        }
    }
}
