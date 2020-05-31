param(
    $Config
)

if (-not $Config.ShowWalletBalances) {return}

$Name = Get-Item $MyInvocation.MyCommand.Path | Select-Object -ExpandProperty BaseName

#
# Bitcoin Wallet
#

$Wallets = @($Config.Wallet) + @($Config.Pools.PSObject.Properties.Value | Where-Object {$_.Wallets.BTC} | Foreach-Object {$_.Wallets.BTC}) | Where-Object {$_ -match "^[13]"} | Select-Object -Unique | Sort-Object

if (($Wallets | Measure-Object).Count -and (-not $Config.WalletBalances.Count -or $Config.WalletBalances -contains "BTC")) {
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

$Wallets_Data = @(
    [PSCustomObject]@{symbol = "ETH";  match = "^0x";   rpc = "https://api.ethplorer.io/getAddressInfo/{w}?apiKey=freekey";           address = "address"; balance = "ETH.balance"; received = "";              divisor = 1}
    [PSCustomObject]@{symbol = "RVN";  match = "^R";    rpc = "https://ravencoin.network/api/addr/{w}/?noTxList=1";                   address = "addrStr"; balance = "balance";     received = "totalReceived"; divisor = 1}
    [PSCustomObject]@{symbol = "SAFE"; match = "^R";    rpc = "https://explorer.safecoin.org/api/addr/{w}/?noTxList=1";               address = "addrStr"; balance = "balance";     received = "totalReceived"; divisor = 1}
    [PSCustomObject]@{symbol = "XLM";  match = "^G";    rpc = "https://horizon.stellar.org/accounts/{w}";                             address = "id";      balance = "balances";    received = "";              divisor = 1}
    [PSCustomObject]@{symbol = "XZC";  match = "^[aZ]"; rpc = "https://explorer.zcoin.io/insight-api-zcoin/addr/{w}/?noTxList=1";     address = "addrStr"; balance = "balance";     received = "totalReceived"; divisor = 1}
    [PSCustomObject]@{symbol = "ZEC";  match = "^t";    rpc = "https://api.zcha.in/v2/mainnet/accounts/{w}";                          address = "address"; balance = "balance";     received = "totalRecv";     divisor = 1}
)

foreach ($Wallet_Data in $Wallets_Data) {
    $Wallet_Symbol  = $Wallet_Data.symbol

    if (-not $Config.WalletBalances.Count -or $Config.WalletBalances -contains $Wallet_Symbol) {

        @($Config.Coins.PSObject.Properties | Where-Object {$_.Name -eq $Wallet_Symbol -and $_.Value.Wallet -match $Wallet_Data.match} | Foreach-Object {$_.Value.Wallet}) + @($Config.Pools.PSObject.Properties.Value | Where-Object {$_.Wallets.$Wallet_Symbol -match $Wallet_Data.match} | Foreach-Object {$_.Wallets.$Wallet_Symbol}) | Select-Object -Unique | Sort-Object | Foreach-Object {
            $Request = [PSCustomObject]@{}

            $Success = $true
            try {
                $Request = Invoke-RestMethodAsync "$($Wallet_Data.rpc -replace "{w}",$_)" -cycletime ($Config.BalanceUpdateMinutes*60)
                if ($Request."$($Wallet_Data.address)" -ne $_) {$Success = $false}
            }
            catch {
                if ($Error.Count){$Error.RemoveAt(0)}
                $Success=$false
            }

            if (-not $Success) {
                Write-Log -Level Verbose "$Wallet_Symbol Balance API ($Name) for $_ has failed. "
                return
            }

            $Wallet_Info = $_ -replace "^0x"

            $Wallet_Balance = [Decimal]$(Switch ($Wallet_Symbol) {
                "XLM" {
                    ($Request.balances | Where-Object {$_.asset_type -eq "native"} | Select-Object -ExpandProperty balance | Measure-Object -Sum).Sum
                }
                default {
                    $val = $null
                    $Wallet_Data.balance -split "\." | Foreach-Object {
                        $val = if ($val -ne $null) {$val.$_} else {$Request.$_}
                    }
                    $val
                }
            })

            [PSCustomObject]@{
                    Caption     = "$Name $Wallet_Symbol ($($_))"
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
