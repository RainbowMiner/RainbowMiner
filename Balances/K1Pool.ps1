using module ..\Modules\Include.psm1

param(
    $Config
)

$Name = Get-Item $MyInvocation.MyCommand.Path | Select-Object -ExpandProperty BaseName

$Pool_Request = [PSCustomObject]@{}

try {
    $Pool_Request = Invoke-RestMethodAsync "https://api.rbminer.net/data/k1pool.json" -tag $Name -timeout 30 -cycletime 3600
}
catch {
    if ($Error.Count){$Error.RemoveAt(0)}
    Write-Log -Level Info "Pool API ($Name) has failed. "
    return
}

$Pool_Request | Where-Object {$Pool_Name = "$($Name)$(if ($_.name -match "solo$") {"Solo"})";$Pool_Currency = $_.symbol;$Config.Pools.$Pool_Name.Wallets.$Pool_Currency -and (-not $Config.ExcludeCoinsymbolBalances.Count -or $Config.ExcludeCoinsymbolBalances -notcontains $Pool_Currency)} | Foreach-Object {

    $Pool_Wallet   = $Config.Pools.$Pool_Name.Wallets.$Pool_Currency

    $Request = [PSCustomObject]@{}

    try {
        $Request = Invoke-RestMethodAsync "https://k1pool.com/api/miner/$($_.name)/$($Pool_Wallet)" -tag $Name -timeout 15 -cycletime ($Config.BalanceUpdateMinutes*60) -delay 100
        [PSCustomObject]@{
            Caption     = "$($Pool_Name) ($Pool_Currency)"
			BaseName    = $Pool_Name
            Currency    = $Pool_Currency
            Balance     = [Decimal]$Request.miner.pendingBalance
            Pending     = [Decimal]$Request.miner.immatureBalance
            Total       = [Decimal]$Request.miner.immatureBalance + [Decimal]$Request.miner.pendingBalance
            Paid        = [Decimal]$Request.miner.paidBalance
            Payouts     = @(Get-BalancesPayouts $Request.miner.payments | Select-Object)
            LastUpdated = (Get-Date).ToUniversalTime()
        }
    }
    catch {
        if ($Error.Count){$Error.RemoveAt(0)}
        Write-Log -Level Verbose "Pool Balance API ($Name) for $($Pool_Currency) has failed. "
    }
}
