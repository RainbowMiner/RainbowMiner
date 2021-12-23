using module ..\Modules\Include.psm1

param(
    $Config
)

$Name = Get-Item $MyInvocation.MyCommand.Path | Select-Object -ExpandProperty BaseName

$Payout_Currencies = @($Config.Pools.$Name.Wallets.PSObject.Properties | Select-Object) | Where-Object Value | Select-Object Name,Value -Unique | Sort-Object Name,Value
$Payout_Currencies_Solo = @($Config.Pools."$($Name)Solo".Wallets.PSObject.Properties | Select-Object) | Where-Object Value | Select-Object Name,Value -Unique | Sort-Object Name,Value

#https://rvn.minerpool.org/api/worker_stats?address=REMkW2wqvLrKiH8ANPfoVtVQ8d4A8UdavD&window_days=0

$Pools_Data = @(
    [PSCustomObject]@{symbol = "FLUX";  port = 2033;  fee = 1.0; rpc = "flux"; rewards = "hourlyRewardsPerSol"}
    [PSCustomObject]@{symbol = "RVN";   port = 16059; fee = 1.0; rpc = "rvn";  rewards = "hourlyRewardsPerHash"}
    [PSCustomObject]@{symbol = "TENT";  port = 3034;  fee = 4.0; rpc = "tent"; rewards = "hourlyRewardsPerSol"}
    [PSCustomObject]@{symbol = "ZER";   port = 15058; fee = 1.0; rpc = "zer";  rewards = "hourlyRewardsPerSol"}
)

$Count = 0

$Pools_Data | Where-Object {-not $Config.ExcludeCoinsymbolBalances.Count -or $Config.ExcludeCoinsymbolBalances -notcontains "$($_.symbol)"} | Foreach-Object {
    $Pool_Currency = $_.symbol
    $Pool_RpcPath  = $_.rpc

    $Pool_Data = @($Payout_Currencies | Where-Object {$_.Name -eq $Pool_Currency} | Foreach-Object {[PSCustomObject]@{solo=$false;wallet=$_.Value}} | Select-Object) + @($Payout_Currencies_Solo | Where-Object {$_.Name -eq $Pool_Currency} | Foreach-Object {[PSCustomObject]@{solo=$true;wallet=$_.Value}} | Select-Object)

    if ($Pool_Data) {

        $Wallet_Balance  = 0
        $Wallet_Immature = 0
        $Wallet_Paid     = 0

        $Pool_Data | Foreach-Object {
            $Request = [PSCustomObject]@{}

            try {
                $Request = Invoke-RestMethodAsync "https://$(if ($_.solo) {"solo-"})$($Pool_RpcPath).minerpool.org/api/worker_stats?address=$($_.wallet)&window_days=0" -tag $Name -timeout 15 -delay $(if ($Count){500} else {0}) -cycletime ($Config.BalanceUpdateMinutes*60)
                if ($Request.miner) {
                    $Wallet_Balance  += [Decimal]$Request.balance
                    $Wallet_Immature += [Decimal]$Request.immature
                    $Wallet_Paid     += [Decimal]$Request.paid
                } else {
                    Write-Log -Level Info "Pool Balance API ($Name) for $($Pool_Currency)$(if ($_.solo) {" (solo)"})  returned nothing. "
                }
            }
            catch {
                if ($Error.Count){$Error.RemoveAt(0)}
                Write-Log -Level Verbose "Pool Balance API ($Name) for $($Pool_Currency)$(if ($_.solo) {" (solo)"}) has failed. "
            }
            $Count++
        }

        [PSCustomObject]@{
            Caption     = "$($Name) ($Pool_Currency)"
		    BaseName    = $Name
            Currency    = $Pool_Currency
            Balance     = [Decimal]$Wallet_Balance
            Pending     = [Decimal]$Wallet_Immature
            Total       = [Decimal]$Wallet_Balance + [Decimal]$Wallet_Immature
            Paid        = [Decimal]$Wallet_Paid
            Payouts     = @()
            LastUpdated = (Get-Date).ToUniversalTime()
        }
    }
}
