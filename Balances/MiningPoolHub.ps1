param(
    $Config
)

$Name = Get-Item $MyInvocation.MyCommand.Path | Select-Object -ExpandProperty BaseName
$PoolConfig = $Config.Pools.$Name

if(!$PoolConfig.API_Key) {
    Write-Log -Level Verbose "Cannot get balance on pool ($Name) - no API key specified. "
    return
}

$Request = [PSCustomObject]@{}

# Get user balances
try {
    $Request = Invoke-RestMethodAsync "https://miningpoolhub.com/index.php?page=api&action=getuserallbalances&api_key=$($PoolConfig.API_Key)" -cycletime ($Config.BalanceUpdateMinutes*60)
}
catch {
    if ($Error.Count){$Error.RemoveAt(0)}
    Write-Warning "Pool Balance API ($Name) has failed. "
    return
}

if (($Request.getuserallbalances.data | Get-Member -MemberType NoteProperty -ErrorAction Ignore | Measure-Object Name).Count -le 1) {
    Write-Log -Level Info "Pool Balance API ($Name) returned nothing. "
    return
}

$Request.getuserallbalances.data | Foreach-Object {

    $Currency = Get-CoinSymbol $_.coin
    if (-not $Currency -and $_.coin -match '-') {$Currency = Get-CoinSymbol ($_.coin -replace '\-.*$')}
    if (-not $Currency) {
        $Currency = $_.coin
        Write-Log -Level Warn "Cannot determine currency for coin ($($_.coin)) - cannot convert some balances to BTC or other currencies. "
    }

    [PSCustomObject]@{
        Caption     = "$($Name) ($($Currency))"
        Currency    = $Currency
        Balance     = [Decimal]$_.confirmed
        Pending     = [Decimal]$_.unconfirmed + [Decimal]$_.ae_confirmed + [Decimal]$_.ae_unconfirmed + [Decimal]$_.exchange
        Total       = [Decimal]$_.confirmed + [Decimal]$_.unconfirmed + [Decimal]$_.ae_confirmed + [Decimal]$_.ae_unconfirmed + [Decimal]$_.exchange
        Paid        = [Decimal]0
        Lastupdated = (Get-Date).ToUniversalTime()
    }
}