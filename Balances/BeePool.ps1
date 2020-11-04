using module ..\Include.psm1

param(
    $Config
)

$Name = Get-Item $MyInvocation.MyCommand.Path | Select-Object -ExpandProperty BaseName

$Pool_Request = [PSCustomObject]@{}
$ok = $false
try {
    $Pool_Request = Invoke-RestMethodAsync "https://www.beepool.org/pool_status" -tag $Name -cycletime 120
    $ok = "$($Pool_Request.code)" -eq "0"
}
catch {
    if ($Error.Count){$Error.RemoveAt(0)}
}

if (-not $ok) {
    Write-Log -Level Warn "Pool API ($Name) has failed. "
    return
}

$Pool_Request.data.data | Where-Object {$Config.Pools.$Name.Wallets."$($_.coin)" -and (-not $Config.ExcludeCoinsymbolBalances.Count -or $Config.ExcludeCoinsymbolBalances -notcontains "$($_.coin)")} | Foreach-Object {
    $Pool_Currency = "$($_.coin)".ToUpper()

    $Request = [PSCustomObject]@{}

    try {
        $Request = Invoke-RestMethodAsync "https://www.beepool.org/get_miner" -delay 100 -cycletime ($Config.BalanceUpdateMinutes*60) -timeout 15 -body @{coin=$_.coin;wallet=$($Config.Pools.$Name.Wallets.$Pool_Currency -replace "^0x")}
        if ("$($Request.code)" -ne "0" -or -not $Request.data.account) {
            Write-Log -Level Info "Pool Balance API ($Name) for $($Pool_Currency) returned nothing. "
        } else {
            [PSCustomObject]@{
                Caption     = "$($Name) ($Pool_Currency)"
				BaseName    = $Name
                Currency    = $Pool_Currency
                Balance     = [Decimal]$Request.data.account.balance
                Pending     = [Decimal]0
                Total       = [Decimal]$Request.data.account.balance
                Paid        = [Decimal]$Request.data.account.pay_balance
                Payouts     = @()
                LastUpdated = (Get-Date).ToUniversalTime()
            }
        }
    }
    catch {
        if ($Error.Count){$Error.RemoveAt(0)}
        Write-Log -Level Verbose "Pool Balance API ($Name) for $($Pool_Currency) has failed. "
    }
}
