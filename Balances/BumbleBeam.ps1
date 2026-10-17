using module ..\Modules\Include.psm1

param(
    [String]$Name,
    $Config,
    $UsePools
)

# $Name = Get-Item $MyInvocation.MyCommand.Path | Select-Object -ExpandProperty BaseName

# PPLNS and solo share one account per address on BumbleBeam
$Pool_Wallet = @(foreach ($PoolExt in "","Solo") {
    if (-not $UsePools -or "$Name$PoolExt" -in $UsePools) {
        $Config.Pools."$Name$PoolExt".Wallets.BEAM
    }
}) | Where-Object {$_} | Select-Object -First 1

if (-not $Pool_Wallet -or ($Config.ExcludeCoinsymbolBalances.Count -and $Config.ExcludeCoinsymbolBalances -contains "BEAM")) {
    Write-Log -Level Verbose "Cannot get balance on pool ($Name) - no wallet address specified. "
    return
}

$Pool_Currency = "BEAM"
$Divisor       = [Decimal]1e8

$Request = [PSCustomObject]@{}

try {
    $Request = Invoke-RestMethodAsync "https://pool.bumblebeam.org/api/miners/$(Get-UrlEncode (Get-WalletWithPaymentId $Pool_Wallet -pidchar '.'))" -cycletime ($Config.BalanceUpdateMinutes*60) -timeout 15
    if ($Request.balance -eq $null) {
        Write-Log -Level Info "Pool Balance API ($Name) for $($Pool_Currency) returned nothing. "
    } else {
        [PSCustomObject]@{
            Caption     = "$($Name) ($Pool_Currency)"
            BaseName    = $Name
            Name        = $Name
            Currency    = $Pool_Currency
            Balance     = [Decimal]$Request.balance / $Divisor
            Pending     = ([Decimal]$Request.immature + [Decimal]$Request.sending) / $Divisor
            Total       = ([Decimal]$Request.balance + [Decimal]$Request.immature + [Decimal]$Request.sending) / $Divisor
            Paid        = [Decimal]$Request.paid / $Divisor
            Payouts     = @(Get-BalancesPayouts $Request.payments -Divisor $Divisor -DateTimeField "ts" -TxField "kernel" | Select-Object)
            LastUpdated = (Get-Date).ToUniversalTime()
        }
    }
}
catch {
    Write-Log -Level Verbose "Pool Balance API ($Name) for $($Pool_Currency) has failed. "
}
