using module ..\Modules\Include.psm1

param(
    $Config
)

$Name = Get-Item $MyInvocation.MyCommand.Path | Select-Object -ExpandProperty BaseName

$Pool_Request = [PSCustomObject]@{}

try {
    $Pool_Request = Invoke-RestMethodAsync "https://master.vipor.net/api/pools" -tag $Name -cycletime 120
}
catch {
    if ($Global:Error.Count){$Global:Error.RemoveAt(0)}
    Write-Log -Level Info "Pool API ($Name) has failed. "
    return
}

if (($Pool_Request.pools | Measure-Object).Count -le 1) {
    Write-Log -Level Info "Pool API ($Name) returned nothing. "
    return
}

$Pool_Request.pools | Where-Object {$Pool_Name = "$($Name)$(if ($_.paymentProcessing.payoutScheme -eq "SOLO") {"Solo"})";$Pool_Currency = $_.coin.symbol;$Config.Pools.$Pool_Name.Wallets.$Pool_Currency -and (-not $Config.ExcludeCoinsymbolBalances.Count -or $Config.ExcludeCoinsymbolBalances -notcontains $Pool_Currency)} | Foreach-Object {

    $Pool_Wallet   = $Config.Pools.$Pool_Name.Wallets.$Pool_Currency

    $Request = [PSCustomObject]@{}

    try {
        $Request = Invoke-RestMethodAsync "https://master.vipor.net/api/pools/$($_.id)/miners/$($Pool_Wallet)" -tag $Name -timeout 15 -cycletime ($Config.BalanceUpdateMinutes*60) -delay 100
        if ($Request.Gettype() -is [string]) {
            $Request = [Regex]::Replace($Request,'(")(":)', "`$1$("tmp")`$2") | ConvertFrom-Json -ErrorAction Stop
        }
        [PSCustomObject]@{
            Caption     = "$($Pool_Name) ($Pool_Currency)"
			BaseName    = $Pool_Name
            Currency    = $Pool_Currency
            Balance     = [Decimal]$Request.pendingBalance
            Pending     = 0
            Total       = [Decimal]$Request.pendingBalance
            Paid        = [Decimal]$Request.totalPaid
            Payouts     = @()
            LastUpdated = (Get-Date).ToUniversalTime()
        }
    }
    catch {
        if ($Global:Error.Count){$Global:Error.RemoveAt(0)}
        Write-Log -Level Verbose "Pool Balance API ($Name) for $($Pool_Currency) has failed. "
    }
}
