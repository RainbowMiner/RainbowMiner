param(
    $Config
)

$Pool_Currency  = "XMR"
$Pool_CoinName  = "Monero"
$Pool_Algorithm_Norm = Get-Algorithm "Monero"
$Pool_Fee       = 1.0

$coinUnits      = [Decimal]1e12

if (-not $Config.Pools.$Name.Wallets.$Pool_Currency -and -not $InfoOnly) {return}

$Name = Get-Item $MyInvocation.MyCommand.Path | Select-Object -ExpandProperty BaseName

$Request = [PSCustomObject]@{}

try {
    $Request = Invoke-RestMethodAsync "https://minexmr.com/api/pool/stats_address?address=$(Get-WalletWithPaymentId $Config.Pools.$Name.Wallets.$Pool_Currency -pidchar '.')" -delay 100 -cycletime ($Config.BalanceUpdateMinutes*60)
    if (-not $Request.stats) {
        Write-Log -Level Info "Pool Balance API ($Name) for $($Pool_Currency) returned nothing. "
    } else {
        $Pending = ($Request.blocks | Where-Object {$_ -match "^\d+?:\d+?:\d+?:\d+?:\d+?:(\d+?):"} | Foreach-Object {[int64]$Matches[1]} | Measure-Object -Sum).Sum / $coinUnits
		$Payouts = @($i=0;$Request.payments | Where-Object {$_ -match "^(.+?):(\d+?):"} | Foreach-Object {[PSCustomObject]@{time=$Request.payments[$i+1];amount=[Decimal]$Matches[2] / $coinUnits;txid=$Matches[1]};$i+=2})
        [PSCustomObject]@{
            Caption     = "$($Name) ($Pool_Currency)"
			BaseName    = $Name
            Currency    = $Pool_Currency
            Balance     = [Decimal]$Request.stats.balance / $coinUnits
            Pending     = [Decimal]$Pending
            Total       = [Decimal]$Request.stats.balance / $coinUnits + [Decimal]$Pending
            Paid        = [Decimal]$Request.stats.paid / $coinUnits
            Payouts     = @(Get-BalancesPayouts $Payouts | Select-Object)
            LastUpdated = (Get-Date).ToUniversalTime()
        }
		Remove-Variable "Payouts"
    }
}
catch {
    if ($Error.Count){$Error.RemoveAt(0)}
    Write-Log -Level Verbose "Pool Balance API ($Name) for $($Pool_Currency) has failed. "
}
