using module ..\Modules\Include.psm1

param(
    $Config
)

$Name = Get-Item $MyInvocation.MyCommand.Path | Select-Object -ExpandProperty BaseName

$Pools_Data = @(
    #[PSCustomObject]@{symbol = "YEC";   port = @(3456,3458); fee = 0.0; rpc = "ycash"; region = @("na","eu","ap")}
    [PSCustomObject]@{symbol = "VRSC";  port = @(3956);      fee = 1.0; rpc = "verus"; region = @("na","eu","ap"); allow_difficulty = $true}
    [PSCustomObject]@{symbol = "ZEN";   port = @(3056,3058); fee = 1.0; rpc = "zen"; region = @("na","eu","ap"); allow_difficulty = $true}
    [PSCustomObject]@{symbol = "KMD";   port = @(3856,3858); fee = 1.0; rpc = "komodo"; region = @("na","eu","ap"); allow_difficulty = $true}
    [PSCustomObject]@{symbol = "HUSH";  port = @(3756,3758); fee = 1.0; rpc = "hush"; region = @("na","eu","ap"); allow_difficulty = $true}
    [PSCustomObject]@{symbol = "ZEC";   port = @(3356,3358); fee = 1.0; rpc = "zcash"; region = @("na","eu","ap"); allow_difficulty = $true}
)

$Pools_Data | Where-Object {$Config.Pools.$Name.Wallets."$($_.symbol)" -and (-not $Config.ExcludeCoinsymbolBalances.Count -or $Config.ExcludeCoinsymbolBalances -notcontains "$($_.symbol)")} | Foreach-Object {
    $Pool_Currency = $_.symbol
    $Pool_RpcPath  = $_.rpc

    $Request = [PSCustomObject]@{}

    try {
        $Request = Invoke-RestMethodAsync "https://luckpool.net/$($Pool_RpcPath)/miner/$($Config.Pools.$Name.Wallets.$Pool_Currency)" -delay 100 -cycletime ($Config.BalanceUpdateMinutes*60) -timeout 15
        if ($Request.balance -eq $null) {
            Write-Log -Level Info "Pool Balance API ($Name) for $($Pool_Currency) returned nothing. "
        } else {
            [PSCustomObject]@{
                Caption     = "$($Name) ($Pool_Currency)"
				BaseName    = $Name
                Currency    = $Pool_Currency
                Balance     = [Decimal]$Request.balance
                Pending     = [Decimal]$Request.immature
                Total       = [Decimal]$Request.balance + [Decimal]$Request.immature
                Paid        = [Decimal]$Request.paid
                Earned      = [Decimal]$Request.paid + [Decimal]$Request.balance
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
