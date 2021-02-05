using module ..\Modules\Include.psm1

param(
    $Config
)

$Name = Get-Item $MyInvocation.MyCommand.Path | Select-Object -ExpandProperty BaseName

$Pools_Data = @(
    [PSCustomObject]@{symbol = "ETC";  rpc = "etc";  port = @(19999,19433); fee = 1; divisor = 1e6; useemail = $false; usepid = $false}
    [PSCustomObject]@{symbol = "ETH";  rpc = "eth";  port = @(9999,9433);   fee = 1; divisor = 1e6; useemail = $false; usepid = $false}
    [PSCustomObject]@{symbol = "ZEC";  rpc = "zec";  port = @(6666,6633);   fee = 1; divisor = 1;   useemail = $false; usepid = $false}
    [PSCustomObject]@{symbol = "XMR";  rpc = "xmr";  port = @(14444,14433); fee = 1; divisor = 1;   useemail = $false; usepid = $true}
    [PSCustomObject]@{symbol = "RVN";  rpc = "rvn";  port = @(12222,12433); fee = 1; divisor = 1e6; useemail = $false; usepid = $false}
    [PSCustomObject]@{symbol = "CFX";  rpc = "cfx";  port = @(17777,17433); fee = 1; divisor = 1e6; useemail = $false; usepid = $false}
    [PSCustomObject]@{symbol = "ERG";  rpc = "ergo"; port = @(11111,11433); fee = 1; divisor = 1e6; useemail = $false; usepid = $false}
)

$Count = 0
$Pools_Data | Where-Object {$Config.Pools.$Name.Wallets."$($_.symbol)" -and (-not $Config.ExcludeCoinsymbolBalances.Count -or $Config.ExcludeCoinsymbolBalances -notcontains "$($_.symbol)")} | Foreach-Object {
    $Pool_Currency = $_.symbol
    $Pool_User = $Config.Pools.$Name.Wallets.$Pool_Currency
    $Pool_Wallet = Get-WalletWithPaymentId $Config.Pools.$Name.Wallets.$Pool_Currency -pidchar '.' -asobject
    if ($Pool_Currency -eq "PASC") {$Pool_Wallet.wallet = "$($Pool_Wallet.wallet -replace "-\d+")$(if (-not $Pool_Wallet.paymentid) {".0"})"}
    try {
        #$Request = Invoke-RestMethodAsync "https://api.nanopool.org/v1/$($Pool_Currency.ToLower())/user/$($Pool_Wallet.wallet)" -delay $(if ($Count){500} else {0}) -cycletime ($Config.BalanceUpdateMinutes*60) -retry 5 -retrywait 200
        $Request = Invoke-RestMethodAsync "https://$($_.rpc).nanopool.org/api/v1/load_account/$($Pool_Wallet.wallet)" -delay $(if ($Count){500} else {0}) -cycletime ($Config.BalanceUpdateMinutes*60) -retry 5 -retrywait 200
        $Count++
        if (-not $Request.status) {
            Write-Log -Level Info "Pool Balance API ($Name) for $($Pool_Currency) returned $($Request.error). "
        } else {
            $Balance = [Math]::Max([Decimal]$Request.data.userParams.balance,0)
            $Pending = [Decimal]$Request.data.userParams.balance_uncomfirmed
			$Payouts = @(try {Invoke-RestMethodAsync "https://api.nanopool.org/v1/$($Pool_Currency.ToLower())/payments/$($Pool_Wallet.wallet)/0/50" -delay $(if ($Count){500} else {0}) -cycletime ($Config.BalanceUpdateMinutes*60) -retry 5 -retrywait 200 | Where-Object status | Select-Object -ExpandProperty data} catch {})
            [PSCustomObject]@{
                Caption     = "$($Name) ($Pool_Currency)"
				BaseName    = $Name
                Currency    = $Pool_Currency
                Balance     = [Decimal]$Balance
                Pending     = [Decimal]$Pending
                Total       = [Decimal]$Balance + [Decimal]$Pending
                Paid        = [Decimal]$Request.data.userParams.e_sum
                Earned      = [Decimal]0
                Payouts     = @(Get-BalancesPayouts $Payouts | Select-Object)
                LastUpdated = (Get-Date).ToUniversalTime()
            }
			Remove-Variable "Payouts"
        }
    }
    catch {
        if ($Error.Count){$Error.RemoveAt(0)}
        Write-Log -Level Warn "Pool Balance API ($Name) for $($Pool_Currency) has failed. "
    }
}
