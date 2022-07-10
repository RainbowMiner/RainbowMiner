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

$Wallets_Data = Get-WalletsData

foreach ($Wallet_Data in $Wallets_Data) {
    $Wallet_Symbol  = $Wallet_Data.symbol

    if ((-not $Config.WalletBalances.Count -or $Config.WalletBalances -contains $Wallet_Symbol) -and (-not $Config.ExcludeCoinsymbolBalances.Count -or $Config.ExcludeCoinsymbolBalances -notcontains $Wallet_Symbol)) {

        @($Config.Coins.PSObject.Properties | Where-Object {"$($_.Name -replace "_\d+$")" -eq $Wallet_Symbol -and $_.Value.Wallet -match $Wallet_Data.match} | Foreach-Object {$_.Value.Wallet}) + @($Config.Pools.PSObject.Properties.Value | Where-Object {$_.Wallets.$Wallet_Symbol -match $Wallet_Data.match} | Foreach-Object {$_.Wallets.$Wallet_Symbol}) | Select-Object -Unique | Sort-Object | Foreach-Object {

            $Wallet_Address = $_

            $Request = [PSCustomObject]@{}

            $Success = $true
            try {
                $Request = Invoke-RestMethodAsync "$($Wallet_Data.rpc -replace "{w}",$Wallet_Address)" -cycletime ($Config.BalanceUpdateMinutes*60) -fixbigint
                if (($Wallet_Data.verify -eq $null -and $Wallet_Data.address -ne "" -and "$(Invoke-Expression "`$Request.$($Wallet_Data.address -replace "{w}",$Wallet_Address)")" -ne $Wallet_Address) -or 
                    ($Wallet_Data.verify -eq "exists" -and "$(Invoke-Expression "`$Request.$($Wallet_Data.verify_value -replace "{w}",$Wallet_Address)")" -eq "") -or
                    ($Wallet_Data.verify -ne "exists" -and $Wallet_Data.verify -ne $null -and "$(Invoke-Expression "`$Request.$($Wallet_Data.verify -replace "{w}",$Wallet_Address)")" -ne $Wallet_Data.verify_value)
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

            $Wallet_Received = $null
            if ($Wallet_Data.received) {
                $Wallet_Received = [Decimal](Invoke-Expression "`$Request.$($Wallet_Data.received)")
            }

            $Wallet_Balance = [Decimal]$(Switch ($Wallet_Symbol) {
                "XLM" {
                    ($Request.balances | Where-Object {$_.asset_type -eq "native"} | Select-Object -ExpandProperty balance | Measure-Object -Sum).Sum
                }
                default {
                    if ($Wallet_Data.balance -eq "#") {
                        $Request
                    } elseif ($Wallet_Data.balance -eq "" -and $Wallet_Received -ne $null) {
                        $val = $Wallet_Received
                        if ($Wallet_Data.spent) {
                            $val -= [Decimal](Invoke-Expression "`$Request.$($Wallet_Data.spent)")
                        }
                        $val
                    } else {
                        $val = $null
                        $Wallet_Data.balance -replace "{w}",$Wallet_Address -split "\." | Foreach-Object {
                            if ($_ -match '^(.+)\[([^\]]+)\]$') {
                                $val = if ($val -ne $null) {$val."$($Matches[1])"} else {$Request."$($Matches[1])"}
                                $arrp = $Matches[2].Split("=",2)
                                if ($arrp[0] -match '^\d+$') {
                                    $val = $val[[int]$arrp[0]]
                                } else {
                                    $val = $val | ?{$_."$($arrp[0])" -eq $arrp[1]}
                                }
                            } else {
                                $val = if ($val -ne $null) {$val.$_} else {$Request.$_}
                            }
                        }
                        $val
                    }
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
                    Earned      = $Wallet_Received / $Wallet_Data.divisor
                    Payouts     = @()
                    LastUpdated = (Get-Date).ToUniversalTime()
            }
        }
    }
}

#
# Binance Wallets
#

if ($Config.Pools.Binance.EnableShowWallets -and $Config.Pools.Binance.API_Key -and $Config.Pools.Binance.API_Secret) {
    $Request = @()
    try {
        $Request = (Invoke-BinanceRequest "/api/v3/account" $Config.Pools.Binance.API_Key $Config.Pools.Binance.API_Secret).balances | Where-Object {[decimal]$_.free -gt 0 -or [decimal]$_.locked -gt 0}
    }
    catch {
        if ($Error.Count){$Error.RemoveAt(0)}
        Write-Log -Level Verbose "Binance Wallet API has failed ($Name) "
    }

    $Request | Foreach-Object {
        $Total_Free   = [decimal]$_.free
        $Total_Locked = [decimal]$_.locked
        [PSCustomObject]@{
                Caption     = "$Name $($_.asset) (Binance)"
		        BaseName    = $Name
                Info        = " Binance"
                Currency    = $_.asset
                Balance     = $Total_Free
                Pending     = $Total_Locked
                Total       = $Total_Free + $Total_Locked
                Payouts     = @()
                LastUpdated = (Get-Date).ToUniversalTime()
        }
    }
}

#
# Nicehash Wallets
#

if ($Config.Pools.Nicehash.EnableShowWallets -and $Config.Pools.Nicehash.API_Key -and $Config.Pools.Nicehash.API_Secret -and $Config.Pools.Nicehash.OrganizationID) {

    $ShowBTCWallet = $true

    if ($Config.Pools.Nicehash.BTC) {

        if (-not (Test-Path "Variable:Global:NHWallets")) {$Global:NHWallets = [hashtable]@{}}

        if (-not $Global:NHWallets.ContainsKey($Config.Pools.Nicehash.BTC)) {
            $Request = [PSCustomObject]@{}
            try {
                $Request = Invoke-GetUrl "https://api2.nicehash.com/main/api/v2/mining/external/$($Config.Pools.Nicehash.BTC)/rigs2/"
                $Global:NHWallets[$Config.Pools.Nicehash.BTC] = $Request.externalAddress
            }
            catch {
                if ($Error.Count){$Error.RemoveAt(0)}
            }
        }
        $ShowBTCWallet = $Global:NHWallets[$Config.Pools.Nicehash.BTC]
    }

    $Request = @()
    try {
        $Request = (Invoke-NHRequest "/main/api/v2/accounting/accounts2" $Config.Pools.Nicehash.API_Key $Config.Pools.Nicehash.API_Secret $Config.Pools.Nicehash.OrganizationID).currencies | Where-Object {$_.active -and [decimal]$_.totalBalance -and ($ShowBTCWallet -or $_.currency -ne "BTC")}
    }
    catch {
        if ($Error.Count){$Error.RemoveAt(0)}
        Write-Log -Level Verbose "Nicehash Wallet API has failed ($Name) "
    }

    $Request | Foreach-Object {
        [PSCustomObject]@{
                Caption     = "$Name $($_.currency) (Nicehash)"
		        BaseName    = $Name
                Info        = " Nicehash"
                Currency    = $_.currency
                Balance     = [decimal]$_.totalBalance
                Pending     = [decimal]$_.pending
                Total       = [decimal]$_.totalBalance
                Payouts     = @()
                LastUpdated = (Get-Date).ToUniversalTime()
        }
    }
}

#
# Covalent
#

if ($Config.CovalentAPIKey) {

    # Polygon chain

    $Polygon_Base_Wallet_Symbol  = "WETH"

    @($Config.Coins.PSObject.Properties | Where-Object {"$($_.Name -replace "_\d+$")" -eq $Polygon_Base_Wallet_Symbol -and $_.Value.Wallet -match "^0x"} | Foreach-Object {$_.Value.Wallet}) + @($Config.Pools.PSObject.Properties.Value | Where-Object {$_.Wallets.$Polygon_Base_Wallet_Symbol -match "^0x"} | Foreach-Object {$_.Wallets.$Polygon_Base_Wallet_Symbol}) | Select-Object -Unique | Sort-Object | Foreach-Object {

        $Wallet_Address = $_
        $Wallet_Info = $Wallet_Address -replace "^0x"

        $Request = @()
        try {
            $Request = Invoke-RestMethodAsync "https://api.covalenthq.com/v1/137/address/$($Wallet_Address)/balances_v2/?key=$($Config.CovalentAPIKey)" -cycletime ($Config.BalanceUpdateMinutes*60) -fixbigint
        }
        catch {
            if ($Error.Count){$Error.RemoveAt(0)}
            Write-Log -Level Verbose "Covalent API has failed ($Name)"
        }

        if ($Request.error) {
            Write-Log -Level Verbose "Covalent API returned error ($Name): $($error_code) $($error_message)"
            return
        }

        $Request.data.items | Foreach-Object {

            $Wallet_Symbol = $_.contract_ticker_symbol
            if (($Session.Config.Coins."$($Wallet_Symbol)") -and (-not $Config.ExcludeCoinsymbolBalances.Count -or $Config.ExcludeCoinsymbolBalances -notcontains $Wallet_Symbol)) {

                $Wallet_Balance = $_.balance / [Math]::Pow(10,$_.contract_decimals)

                [PSCustomObject]@{
                        Caption     = "$Name $($Wallet_Symbol) $($Wallet_Address)"
                        BaseName    = $Name
                        Info        = " $($Wallet_Info.Substring(0,3))..$($Wallet_Info.Substring($Wallet_Info.Length-3,3)) Polygon"
                        Currency    = $_.contract_ticker_symbol
                        Balance     = $Wallet_Balance
                        Pending     = 0
                        Total       = $Wallet_Balance
                        Payouts     = @()
                        LastUpdated = (Get-Date).ToUniversalTime()
                }
            }
        }
    }
}
