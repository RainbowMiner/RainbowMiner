using module ..\Modules\Include.psm1

param(
    [String]$Name,
    $Config
)

# $Name = Get-Item $MyInvocation.MyCommand.Path | Select-Object -ExpandProperty BaseName

$Pools_Data = @(
    [PSCustomObject]@{symbol = "BEAM";  port = 3333; fee = 0.5; rpc = "beam"; region = @("us","eu","asia"); coinUnits = 100000000; ssl = $true}
    [PSCustomObject]@{symbol = "ERG";   port = @(1111,2288); fee = 0.0; rpc = "ergo";   region = @("us-central","us-west","eu","asia"); coinUnits = 1000000000}
    [PSCustomObject]@{symbol = "ZP";    port = 8811; fee = 2.0; rpc = "zp";   region = @("us-east","eu","asia")}
)

$Pools_Data | Where-Object {$Config.Pools.$Name.Wallets."$($_.symbol)" -and (-not $Config.ExcludeCoinsymbolBalances.Count -or $Config.ExcludeCoinsymbolBalances -notcontains "$($_.symbol)")} | Foreach-Object {
    $Pool_Currency = $_.symbol
    $Pool_RpcPath  = $_.rpc

    $Pool_Request = [PSCustomObject]@{}
    $Request = [PSCustomObject]@{}

    try {
        if ($_.endpoint) {
            $Pool_Request = Invoke-RestMethodAsync $_.host -tag $Name -timeout 15 -cycletime 120
            $coinUnits = [Decimal]$Pool_Request.config.coinUnits

            $Request = Invoke-RestMethodAsync "https://api-$($Pool_RpcPath).leafpool.com/stats_address?address=$(Get-UrlEncode (Get-WalletWithPaymentId $Config.Pools.$Name.Wallets.$Pool_Currency))" -delay 100 -cycletime ($Config.BalanceUpdateMinutes*60) -timeout 15
            if (-not $Request.stats -or -not $coinUnits) {
                Write-Log -Level Info "Pool Balance API ($Name) for $($Pool_Currency) returned nothing. "
            } else {
                $Pending = ($Request.blocks | Where-Object {$_ -match "^\d+?:\d+?:\d+?:\d+?:\d+?:(\d+?):"} | Foreach-Object {[int64]$Matches[1]} | Measure-Object -Sum).Sum / $coinUnits
			    $Payouts = @($i=0;$Request.payments | Where-Object {$_ -match "^(.+?):(\d+?):"} | Foreach-Object {[PSCustomObject]@{time=$Request.payments[$i+1];amount=[Decimal]$Matches[2] / $coinUnits;txid=$Matches[1]};$i+=2})
                [PSCustomObject]@{
                    Caption     = "$($Name) ($Pool_Currency)"
				    BaseName    = $Name
                    Name        = $Name
                    Currency    = $Pool_Currency
                    Balance     = [Decimal]$Request.stats.balance / $coinUnits
                    Pending     = [Decimal]$Pending
                    Total       = [Decimal]$Request.stats.balance / $coinUnits + [Decimal]$Pending
                    Paid        = [Decimal]$Request.stats.paid / $coinUnits
                    Payouts     = @(Get-BalancesPayouts $Payouts | Select-Object)
                    LastUpdated = (Get-Date).ToUniversalTime()
                }
			    Remove-Variable "Payouts"
            }
        } else {
            $Request = Invoke-RestMethodAsync "https://api-$($Pool_RpcPath).leafpool.com/api/worker_stats?$($Config.Pools.$Name.Wallets.$Pool_Currency)" -delay 100 -cycletime ($Config.BalanceUpdateMinutes*60) -timeout 15
            if ($Request.balance -eq $null) {
                Write-Log -Level Info "Pool Balance API ($Name) for $($Pool_Currency) returned nothing. "
            } else {
                [PSCustomObject]@{
                    Caption     = "$($Name) ($Pool_Currency)"
				    BaseName    = $Name
                    Name        = $Name
                    Currency    = $Pool_Currency
                    Balance     = [Decimal]$Request.balance / $_.coinUnits
                    Pending     = [Decimal]$Pending
                    Total       = [Decimal]$Request.balance / $_.coinUnits
                    Paid        = [Decimal]$Request.paid / $_.coinUnits
                    Payouts     = @()
                    LastUpdated = (Get-Date).ToUniversalTime()
                }
            }
        }
    }
    catch {
        Write-Log -Level Verbose "Pool Balance API ($Name) for $($Pool_Currency) has failed. "
    }
}
