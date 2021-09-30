using module ..\Modules\Include.psm1

param(
    $Config
)

$Name = Get-Item $MyInvocation.MyCommand.Path | Select-Object -ExpandProperty BaseName

if ((Get-Date).ToUniversalTime() -ge [DateTime]::new(2021, 10, 15, 16, 0, 0, 0, 'Utc')) {
    return
}

$Pools_Data = @(
    [PSCustomObject]@{symbol = "ETH";  coin = "eth";  port = @(9530,9531); fee = 1.0; fee_pplns = 1.0}
    [PSCustomObject]@{symbol = "ETC";  coin = "etc";  port = @(9518,9519); fee = 1.0; fee_pplns = 1.0}
    [PSCustomObject]@{symbol = "RVN";  coin = "rvn";  port = @(9531,9532); fee = 2.0; fee_pplns = 1.0}
    [PSCustomObject]@{symbol = "CFX";  coin = "cfx";  port = @(9555,9556); fee = 2.0; fee_pplns = $null}
    [PSCustomObject]@{symbol = "SERO"; coin = "sero"; port = @(9515,9516); fee = 2.0; fee_pplns = $null}
    [PSCustomObject]@{symbol = "AE";   coin = "ae";   port = @(9505,9506); fee = 2.0; fee_pplns = 1.0}
    [PSCustomObject]@{symbol = "ERG";  coin = "ergo"; port = @(9545,9546); fee = 2.0; fee_pplns = 1.0}
)

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

$Pools_Data | Where-Object {$Config.Pools.$Name.Wallets."$($_.symbol)" -and (-not $Config.ExcludeCoinsymbolBalances.Count -or $Config.ExcludeCoinsymbolBalances -notcontains "$($_.symbol)")} | Foreach-Object {

    $PoolData_Coin = $_.coin

    if (-not ($Pool_Data = $Pool_Request.data.data | Where-Object {$_.coin -eq $PoolData_Coin})) {return}

    $Pool_Currency = $_.symbol

    $Request = [PSCustomObject]@{}

    try {
        $Request = Invoke-RestMethodAsync "https://www.beepool.org/get_miner" -delay 100 -cycletime ($Config.BalanceUpdateMinutes*60) -timeout 15 -body @{coin=$Pool_Data.coin;wallet=$($Config.Pools.$Name.Wallets.$Pool_Currency -replace "^0x")}
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
