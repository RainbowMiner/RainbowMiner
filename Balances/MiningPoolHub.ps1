param(
    $Config
)

$Name = Get-Item $MyInvocation.MyCommand.Path | Select-Object -ExpandProperty BaseName
$PoolConfig = $Config.Pools.$Name

if(-not $PoolConfig.API_Key) {
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

$Pool_Request = [PSCustomObject]@{}

try {
    $Pool_Request = Invoke-RestMethodAsync "https://miningpoolhub.com/index.php?page=api&action=getminingandprofitsstatistics&{timestamp}" -tag $Name -cycletime 120
}
catch {
    if ($Error.Count){$Error.RemoveAt(0)}
    Write-Log -Level Warn "Pool API ($Name) has failed. "
    return
}

if (($Pool_Request.return | Measure-Object).Count -le 1) {
    Write-Log -Level Warn "Pool API ($Name) returned nothing. "
    return
}

$Request.getuserallbalances.data | Where-Object {$_.coin} | Foreach-Object {

    $Pool_CoinName = $_.coin
    $Currency = ($Pool_Request.return | Where-Object {$_.coin_name -eq $Pool_CoinName}).symbol
    if (-not $Currency) {
        Write-Log -Level Warn "Cannot determine currency for coin ($($_.coin)) - cannot convert some balances to BTC or other currencies. "
    }

    if (-not $Config.ExcludeCoinsymbolBalances.Count -or $Config.ExcludeCoinsymbolBalances -notcontains $Currency) {
        [PSCustomObject]@{
            Caption     = "$($Name) ($($Currency))"
		    BaseName    = $Name
            Currency    = $Currency
            Balance     = [Decimal]$_.confirmed
            Pending     = [Decimal]$_.unconfirmed + [Decimal]$_.ae_confirmed + [Decimal]$_.ae_unconfirmed + [Decimal]$_.exchange
            Total       = [Decimal]$_.confirmed + [Decimal]$_.unconfirmed + [Decimal]$_.ae_confirmed + [Decimal]$_.ae_unconfirmed + [Decimal]$_.exchange
            Paid        = [Decimal]0
		    Payouts     = @()
            Lastupdated = (Get-Date).ToUniversalTime()
        }
    }
}