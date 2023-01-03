using module ..\Modules\Include.psm1

param(
    $Config
)

$Name = Get-Item $MyInvocation.MyCommand.Path | Select-Object -ExpandProperty BaseName
$PoolConfigDefault = $Config.Pools.$Name
$PoolConfigCoins   = $Config.Pools."$($Name)Coins"

if(-not $PoolConfigDefault.API_Key -and -not $PoolConfigCoins.API_Key) {
    Write-Log -Level Verbose "Cannot get balance on pool ($Name) - no API key specified. "
    return
}


$PoolConfigs = @()

if ($PoolConfigDefault.API_Key) {$PoolConfigs += $PoolConfigDefault}
if ($PoolConfigCoins.API_Key -and $PoolConfigCoins.API_Key -ne $PoolConfigDefault.API_Key) {$PoolConfigs += $PoolConfigCoins}

foreach ($PoolConfig in $PoolConfigs) {

    $PoolCoins = if ($PoolConfigs.Count -eq 1) {"$($PoolConfigDefault.BalanceCoinSymbol)$(if ($PoolConfigDefault.BalanceCoinSymbol -ne '' -and $PoolConfigCoins.BalanceCoinSymbol -ne '') {","})$($PoolConfigCoins.BalanceCoinSymbol)"} else {"$($PoolConfig.BalanceCoinSymbol)"}
    $PoolCoins = @($PoolCoins -replace "[^A-Z0-9,;]+" -split "[,;]+" | Where-Object {$_} | Select-Object -Unique)

    $Request = [PSCustomObject]@{}

    # Get user balances
    try {
        $Request = Invoke-RestMethodAsync "https://miningpoolhub.com/index.php?page=api&action=getuserallbalances&api_key=$($PoolConfig.API_Key)" -cycletime ($Config.BalanceUpdateMinutes*60)
    }
    catch {
        if ($Error.Count){$Error.RemoveAt(0)}
        Write-Warning "Pool Balance API ($Name) has failed. "
        continue
    }

    if (($Request.getuserallbalances.data | Get-Member -MemberType NoteProperty -ErrorAction Ignore | Measure-Object Name).Count -le 1) {
        Write-Log -Level Info "Pool Balance API ($Name) returned nothing. "
        continue
    }

    $Pool_Request = [PSCustomObject]@{}

    try {
        $Pool_Request = Invoke-RestMethodAsync "https://miningpoolhub.com/index.php?page=api&action=getminingandprofitsstatistics&{timestamp}" -tag $Name -cycletime 120
    }
    catch {
        if ($Error.Count){$Error.RemoveAt(0)}
        Write-Log -Level Warn "Pool API ($Name) has failed. "
        continue
    }

    if (($Pool_Request.return | Measure-Object).Count -le 1) {
        Write-Log -Level Warn "Pool API ($Name) returned nothing. "
        continue
    }

    if (-not ($Request.getuserallbalances.data | Measure-Object).Count) {continue}

    $CoinsEmpty = $true

    $Request.getuserallbalances.data | Where-Object {$_.coin} | Foreach-Object {

        $CoinsEmpty = $false

        $Pool_CoinName = $_.coin
        $Currency = ($Pool_Request.return | Where-Object {$_.coin_name -eq $Pool_CoinName}).symbol
        if (-not $Currency) {
            Write-Log -Level Warn "Cannot determine currency for coin ($($_.coin)) - cannot convert some balances to BTC or other currencies. "
        }

        if ((-not $Config.ExcludeCoinsymbolBalances.Count -or $Config.ExcludeCoinsymbolBalances -notcontains $Currency) -and (-not $PoolCoins.Count -or $PoolCoins -contains $Currency)) {
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

    # Workaround for empty coin parameter, error in MPH API
    if ($CoinsEmpty) {

        $PoolCoins | Where-Object {$Currency = $_;$Pool_Data = $Pool_Request.return | Where-Object {$_.symbol -eq $Currency} | Select-Object -First 1;$Pool_Data -and (-not $Config.ExcludeCoinsymbolBalances.Count -or $Config.ExcludeCoinsymbolBalances -notcontains $Currency) -and (-not $PoolCoins.Count -or $PoolCoins -contains $Currency)} | Foreach-Object {
            try {
                $Request = Invoke-RestMethodAsync "http://$($Pool_Data.coin_name).miningpoolhub.com/index.php?page=api&action=getuserbalance&api_key=$($PoolConfig.API_Key)&id=$($PoolConfig.API_ID)" -cycletime ($Config.BalanceUpdateMinutes*60)
            }
            catch {
                if ($Error.Count){$Error.RemoveAt(0)}
                Write-Warning "Pool Balance API ($Name) for coin $($Currency) has failed. "
                return
            }

            [PSCustomObject]@{
                Caption     = "$($Name) ($($Currency))"
		        BaseName    = $Name
                Currency    = $Currency
                Balance     = [Decimal]$Request.getuserbalance.data.confirmed
                Pending     = [Decimal]$Request.getuserbalance.data.unconfirmed
                Total       = [Decimal]$Request.getuserbalance.data.confirmed + [Decimal]$Request.getuserbalance.data.unconfirmed
                Paid        = [Decimal]0
		        Payouts     = @()
                Lastupdated = (Get-Date).ToUniversalTime()
            }

        }

    }
}