param(
    $Config
)

$Pool_Currency  = "XMR"
$Pool_CoinName  = "Monero"
$Pool_Algorithm_Norm = Get-Algorithm "Monero"
$Pool_Fee       = 1.0

$coinUnits      = 1e12

if (-not $Config.Pools.$Name.Wallets.$Pool_Currency -and -not $InfoOnly) {return}

$Name = Get-Item $MyInvocation.MyCommand.Path | Select-Object -ExpandProperty BaseName

$Request = [PSCustomObject]@{}

try {
    $Request = Invoke-RestMethodAsync "https://minexmr.com/api/pool/stats_address?address=$($Config.Pools.$Name.Wallets.$Pool_Currency)" -delay 100 -cycletime ($Config.BalanceUpdateMinutes*60)
    if (-not $Request.stats) {
        Write-Log -Level Info "Pool Balance API ($Name) for $($Pool_Currency) returned nothing. "
    } else {
        $Pending = ($Request.blocks | Where-Object {$_ -match "^\d+?:\d+?:\d+?:\d+?:\d+?:(\d+?):"} | Foreach-Object {[int64]$Matches[1]} | Measure-Object -Sum).Sum / $coinUnits
        [PSCustomObject]@{
            Caption     = "$($Name) ($Pool_Currency)"
            Currency    = $Pool_Currency
            Balance     = $Request.stats.balance / $coinUnits
            Pending     = $Pending
            Total       = $Request.stats.balance / $coinUnits + $Pending
            Paid        = $Request.stats.paid / $coinUnits
            Payouts     = @($i=0;$Request.payments | Where-Object {$_ -match "^(.+?):(\d+?):"} | Foreach-Object {[PSCustomObject]@{time=$Request.payments[$i+1];amount=$Matches[2] / $coinUnits;txid=$Matches[1]};$i+=2})
            LastUpdated = (Get-Date).ToUniversalTime()
        }
    }
}
catch {
    if ($Error.Count){$Error.RemoveAt(0)}
    Write-Log -Level Verbose "Pool Balance API ($Name) for $($Pool_Currency) has failed. "
}
