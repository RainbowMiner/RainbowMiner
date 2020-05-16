param(
    $Config
)

$Name = Get-Item $MyInvocation.MyCommand.Path | Select-Object -ExpandProperty BaseName


#
# Bitcoin Wallet
#

$Wallets = @($Config.Wallet) + @($Config.Pools.PSObject.Properties.Value | Where-Object {$_.Wallets.BTC} | Foreach-Object {$_.Wallets.BTC}) | Where-Object {$_ -match "^[13]"} | Select-Object -Unique | Sort-Object

if (($Wallets | Measure-Object).Count) {
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
# Ethereum Wallet
#

$Wallets = @($Config.Pools.PSObject.Properties.Value | Where-Object {$_.Wallets.ETH} | Foreach-Object {$_.Wallets.ETH}) | Where-Object {$_ -match "^0x"} | Select-Object -Unique | Sort-Object

if (($Wallets | Measure-Object).Count) {

    $Wallets | Foreach-Object {
        $Request = [PSCustomObject]@{}

        $Success = $true
        try {
            $Request = Invoke-RestMethodAsync "https://api.ethplorer.io/getAddressInfo/$($_)?apiKey=freekey" -cycletime ($Config.BalanceUpdateMinutes*60)
            if ($Request.address -ne $_) {$Success = $false}
        }
        catch {
            if ($Error.Count){$Error.RemoveAt(0)}
            $Success=$false
        }

        if (-not $Success) {
            Write-Log -Level Warn "ETH Balance API ($Name) for $_ has failed. "
            return
        }

        [PSCustomObject]@{
                Caption     = "$($Name) ETH ($($_))"
		        BaseName    = $Name
                Info        = " $($_.Substring(2,3))..$($_.Substring($_.Length-3,3))"
                Currency    = "ETH"
                Balance     = [Decimal]$Request.ETH.balance
                Pending     = 0
                Total       = [Decimal]$Request.ETH.balance
                Payouts     = @()
                LastUpdated = (Get-Date).ToUniversalTime()
        }
    }
}


#
# RavenCoin Wallet
#

$Wallets = @($Config.Pools.PSObject.Properties.Value | Where-Object {$_.Wallets.RVN} | Foreach-Object {$_.Wallets.RVN}) | Where-Object {$_ -match "^R"} | Select-Object -Unique | Sort-Object

if (($Wallets | Measure-Object).Count) {

    $Wallets | Foreach-Object {
        $Request = [PSCustomObject]@{}

        $Success = $true
        try {
            $Request = Invoke-RestMethodAsync "https://ravencoin.network/api/addr/$_/?noTxList=1" -cycletime ($Config.BalanceUpdateMinutes*60)
            if ($Request.addrStr -ne $_) {$Success = $false}
        }
        catch {
            if ($Error.Count){$Error.RemoveAt(0)}
            $Success=$false
        }

        if (-not $Success) {
            Write-Log -Level Warn "RVN Balance API ($Name) for $_ has failed. "
            return
        }

        [PSCustomObject]@{
                Caption     = "$($Name) RVN ($($_))"
		        BaseName    = $Name
                Info        = " $($_.Substring(0,3))..$($_.Substring($_.Length-3,3))"
                Currency    = "RVN"
                Balance     = [Decimal]$Request.balance
                Pending     = 0
                Total       = [Decimal]$Request.balance
                Earned      = [Decimal]$Request.totalReceived
                Payouts     = @()
                LastUpdated = (Get-Date).ToUniversalTime()
        }
    }
}


#
# SafeCoin Wallet
#

$Wallets = @($Config.Pools.PSObject.Properties.Value | Where-Object {$_.Wallets.SAFE} | Foreach-Object {$_.Wallets.SAFE}) | Where-Object {$_ -match "^R"} | Select-Object -Unique | Sort-Object

if (($Wallets | Measure-Object).Count) {

    $Wallets | Foreach-Object {
        $Request = [PSCustomObject]@{}

        $Success = $true
        try {
            $Request = Invoke-RestMethodAsync "https://explorer.safecoin.org/api/addr/$_/?noTxList=1" -cycletime ($Config.BalanceUpdateMinutes*60)
            if ($Request.addrStr -ne $_) {$Success = $false}
        }
        catch {
            if ($Error.Count){$Error.RemoveAt(0)}
            $Success=$false
        }

        if (-not $Success) {
            Write-Log -Level Warn "SAFE Balance API ($Name) for $_ has failed. "
            return
        }

        [PSCustomObject]@{
                Caption     = "$($Name) SAFE ($($_))"
		        BaseName    = $Name
                Info        = " $($_.Substring(0,3))..$($_.Substring($_.Length-3,3))"
                Currency    = "SAFE"
                Balance     = [Decimal]$Request.balance
                Pending     = 0
                Total       = [Decimal]$Request.balance
                Earned      = [Decimal]$Request.totalReceived
                Payouts     = @()
                LastUpdated = (Get-Date).ToUniversalTime()
        }
    }
}


#
# Zcash wallet
#

$Wallets = @($Config.Pools.PSObject.Properties.Value | Where-Object {$_.Wallets.ZEC} | Foreach-Object {$_.Wallets.ZEC}) | Where-Object {$_ -match "^t[13]"} | Select-Object -Unique | Sort-Object

if (($Wallets | Measure-Object).Count) {

    $Wallets | Foreach-Object {
        $Request = [PSCustomObject]@{}

        $Success = $true
        try {
            $Request = Invoke-RestMethodAsync "https://api.zcha.in/v2/mainnet/accounts/$_" -cycletime ($Config.BalanceUpdateMinutes*60)
            if ($Request.address -ne $_) {$Success = $false}
        }
        catch {
            if ($Error.Count){$Error.RemoveAt(0)}
            $Success=$false
        }

        if (-not $Success) {
            Write-Log -Level Warn "ZEC Balance API ($Name) for $_ has failed. "
            return
        }

        [PSCustomObject]@{
                Caption     = "$($Name) ZEC ($($_))"
		        BaseName    = $Name
                Info        = " $($_.Substring(0,3))..$($_.Substring($_.Length-3,3))"
                Currency    = "ZEC"
                Balance     = [Decimal]$Request.balance
                Pending     = 0
                Total       = [Decimal]$Request.balance
                Earned      = [Decimal]$Request.totalRecv
                Payouts     = @()
                LastUpdated = (Get-Date).ToUniversalTime()
        }
    }
}
