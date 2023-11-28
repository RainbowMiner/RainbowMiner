using module ..\Modules\Include.psm1

param(
    $Config
)

$Name = Get-Item $MyInvocation.MyCommand.Path | Select-Object -ExpandProperty BaseName

$Pools_Data = @(
    [PSCustomObject]@{symbol = "CCX";   port = 30041; fee = 0.9; rpc = "conceal"; regions = @("fr")}
    [PSCustomObject]@{symbol = "DERO";  port = 30182; fee = 0.9; rpc = "dero";   regions =@("fr","ca","sg"); solo = $true}
    [PSCustomObject]@{symbol = "XHV";   port = 30031; fee = 0.9; rpc = "haven"; regions = @("fr","ca","us-w","br","sg","za")}
    [PSCustomObject]@{symbol = "RYO";   port = 30172; fee = 1.2; rpc = "ryo"; regions = @("fr","ca","us-w","br","sg","za")}
    [PSCustomObject]@{symbol = "UPX";   port = 30022; fee = 0.9; rpc = "uplexa"; regions = @("fr")}
)

$Pools_Data | Where-Object {$Config.Pools.$Name.Wallets."$($_.symbol)" -and (-not $Config.ExcludeCoinsymbolBalances.Count -or $Config.ExcludeCoinsymbolBalances -notcontains "$($_.symbol)")} | Foreach-Object {
    $Pool_Coin     = Get-Coin $_.symbol
    $Pool_Currency = $_.symbol
    $Pool_RpcPath  = $_.rpc

    $Pool_Algorithm_Norm = Get-Algorithm $Pool_Coin.Algo

    if (-not $_.algo -or ($_.algo -eq $Pool_Algorithm_Norm)) {
        $Pool_Request = [PSCustomObject]@{}
        $Request = [PSCustomObject]@{}
        try {
            $Pool_Request = Invoke-RestMethodAsync "https://$($Pool_RpcPath).miner.rocks/api/stats" -tag $Name
            $coinUnits = [Decimal]$Pool_Request.config.coinUnits

            $Request = Invoke-RestMethodAsync "https://$($Pool_RpcPath).miner.rocks/api/stats_address?address=$(Get-WalletWithPaymentId $Config.Pools.$Name.Wallets.$Pool_Currency -pidchar '.')" -delay 100 -cycletime ($Config.BalanceUpdateMinutes*60)
            if ($Request -is [string] -and $Request -match "{.+}") {
                try {
                    $Request = $Request -replace '"workers":{".+}}','"workers":{ }' -replace '"charts":{".+]]}','"charts":{ }' | ConvertFrom-Json -ErrorAction Ignore
                } catch {
                    if ($Error.Count){$Error.RemoveAt(0)}
                }
            }
            if (-not $Request.stats -or -not $coinUnits) {
                Write-Log -Level Info "Pool Balance API ($Name) for $($_.Name) returned nothing. "
            } else {
			    $Payouts = @($i=0;$Request.payments | Where-Object {$_ -match "^(.+?):(\d+?):"} | Foreach-Object {[PSCustomObject]@{time=$Request.payments[$i+1];amount=[Decimal]$Matches[2] / $coinUnits;txid=$Matches[1]};$i+=2})
                [PSCustomObject]@{
                    Caption     = "$($Name) ($Pool_Currency)"
				    BaseName    = $Name
                    Currency    = $Pool_Currency
                    Balance     = [Decimal]$Request.stats.balance / $coinUnits
                    Pending     = [Decimal]$Request.stats.pendingIncome / $coinUnits
                    Total       = [Decimal]$Request.stats.balance / $coinUnits + [Decimal]$Request.stats.pendingIncome / $coinUnits
                    Paid        = [Decimal]$Request.stats.paid / $coinUnits
                    Paid24h     = [Decimal]$Request.stats.paid24h / $coinUnits
                    Payouts     = @(Get-BalancesPayouts $Payouts | Select-Object)
                    LastUpdated = (Get-Date).ToUniversalTime()
                }
			    Remove-Variable "Payouts"
            }
        }
        catch {
            if ($Error.Count){$Error.RemoveAt(0)}
            Write-Log -Level Verbose "Pool Balance API ($Name) for $($_.Name) has failed. "
        }
    }
}
