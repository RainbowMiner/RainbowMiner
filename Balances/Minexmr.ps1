using module ..\Modules\Include.psm1

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
    $Request = Invoke-RestMethodAsync "https://minexmr.com/api/main/user/stats?address=$($Config.Pools.$Name.Wallets.$Pool_Currency)" -delay 100 -cycletime ($Config.BalanceUpdateMinutes*60)
    if (-not $Request.stats) {
        Write-Log -Level Info "Pool Balance API ($Name) for $($Pool_Currency) returned nothing. "
    } else {
        [PSCustomObject]@{
            Caption     = "$($Name) ($Pool_Currency)"
			BaseName    = $Name
            Currency    = $Pool_Currency
            Balance     = [Decimal]$Request.balance / 1e12
            Pending     = 0
            Total       = [Decimal]$Request.balance / 1e12
            Paid        = [Decimal]$Request.paid / 1e12
            Payouts     = @()
            LastUpdated = (Get-Date).ToUniversalTime()
        }
    }
}
catch {
    if ($Error.Count){$Error.RemoveAt(0)}
    Write-Log -Level Verbose "Pool Balance API ($Name) for $($Pool_Currency) has failed. "
}
