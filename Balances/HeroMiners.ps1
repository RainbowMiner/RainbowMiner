using module ..\Modules\Include.psm1

param(
    $Config
)

$Name = Get-Item $MyInvocation.MyCommand.Path | Select-Object -ExpandProperty BaseName

$Pools_Data = @(
    [PSCustomObject]@{symbol = "AIPG";  port = 1128; fee = 0.9; rpc = "aipg"; region = $Pool_AllRegions}
    [PSCustomObject]@{symbol = "ALPH";  port = 1199; fee = 0.0; rpc = "alephium"; region = $Pool_AllRegions; pass = "x"}
    [PSCustomObject]@{symbol = "BEAM";  port = 1130; fee = 0.9; rpc = "beam"; region = $Pool_AllRegions}
    [PSCustomObject]@{symbol = "CLORE"; port = 1163; fee = 0.9; rpc = "clore"; region = $Pool_AllRegions}
    [PSCustomObject]@{symbol = "CFX";   port = 1170; fee = 0.9; rpc = "conflux"; region = $Pool_AllRegions}
    [PSCustomObject]@{symbol = "CTXC";  port = 1155; fee = 0.9; rpc = "cortex"; region = $Pool_AllRegions; cycles = 42}
    [PSCustomObject]@{symbol = "DNX";   port = 1120; fee = 0.9; rpc = "dynex"; region = $Pool_AllRegions; MallobPort = 1119}
    [PSCustomObject]@{symbol = "ERG";   port = 1180; fee = 0.9; rpc = "ergo"; region = $Pool_AllRegions}
    [PSCustomObject]@{symbol = "ETC";   port = 1150; fee = 0.9; rpc = "etc"; region = $Pool_AllRegions}
    [PSCustomObject]@{symbol = "FLUX";  port = 1200; fee = 0.9; rpc = "flux"; region = $Pool_AllRegions; wtmmode = "WTM"}
    [PSCustomObject]@{symbol = "IRON";  port = 1145; fee = 0.0; rpc = "ironfish"; region = $Pool_AllRegions; pass = "x"}
    [PSCustomObject]@{symbol = "KLS";   port = 1195; fee = 0.9; rpc = "karlsen"; region = $Pool_AllRegions}
    [PSCustomObject]@{symbol = "KAS";   port = 1206; fee = 0.9; rpc = "kaspa"; region = $Pool_AllRegions}
    [PSCustomObject]@{symbol = "XMR";   port = 1111; fee = 0.9; rpc = "monero"; region = $Pool_AllRegions}
    [PSCustomObject]@{symbol = "NEOX";  port = 1202; fee = 0.9; rpc = "neoxa"; region = $Pool_AllRegions}
    [PSCustomObject]@{symbol = "NXL";   port = 1143; fee = 0.9; rpc = "nexellia"; region = $Pool_AllRegions}
    [PSCustomObject]@{symbol = "XNA";   port = 1160; fee = 0.9; rpc = "neurai"; region = $Pool_AllRegions}
    [PSCustomObject]@{symbol = "PYI";   port = 1177; fee = 0.9; rpc = "pyrin"; region = $Pool_AllRegions}
    [PSCustomObject]@{symbol = "QRL";   port = 1166; fee = 0.9; rpc = "qrl"; region = $Pool_AllRegions}
    [PSCustomObject]@{symbol = "RVN";   port = 1140; fee = 0.9; rpc = "ravencoin"; region = $Pool_AllRegions; diffFactor = [Math]::Pow(2,32)}
    [PSCustomObject]@{symbol = "SDR";   port = 1213; fee = 0.9; rpc = "sedra"; region = $Pool_AllRegions}
    [PSCustomObject]@{symbol = "XEL";   port = 1225; fee = 0.0; rpc = "xelis"; region = $Pool_AllRegions}
    [PSCustomObject]@{symbol = "ZEPH";  port = 1123; fee = 0.9; rpc = "zephyr"; region = $Pool_AllRegions}
)

$Pools_Data | Where-Object {$Config.Pools.$Name.Wallets."$($_.symbol)" -and (-not $Config.ExcludeCoinsymbolBalances.Count -or $Config.ExcludeCoinsymbolBalances -notcontains "$($_.symbol)")} | Foreach-Object {
    $Pool_Currency = $_.symbol
    $Pool_RpcPath  = $_.rpc

    $Pool_Request = [PSCustomObject]@{}
    $Request = [PSCustomObject]@{}

    try {
        $Pool_Request = Invoke-RestMethodAsync "https://$($Pool_RpcPath).herominers.com/api/stats" -tag $Name -timeout 15 -cycletime 120
        $coinUnits = [Decimal]$Pool_Request.config.coinUnits

        $Request = Invoke-RestMethodAsync "https://$($Pool_RpcPath).herominers.com/api/stats_address?address=$(Get-UrlEncode (Get-WalletWithPaymentId ($Config.Pools.$Name.Wallets.$Pool_Currency -replace "^solo:")))&longpoll=false" -delay 100 -cycletime ($Config.BalanceUpdateMinutes*60) -timeout 15
        if ($Request -is [string] -and $Request -match "{.+}") {
            try {
                $Request = $Request -replace '"workers":{".+}}','"workers":{ }' -replace '"charts":{".+]]}','"charts":{ }' | ConvertFrom-Json -ErrorAction Ignore
            } catch {
                if ($Error.Count){$Error.RemoveAt(0)}
            }
        }
        if (-not $Request.stats -or -not $coinUnits) {
            Write-Log -Level Info "Pool Balance API ($Name) for $($Pool_Currency) returned nothing. "
        } else {
            $Pending = ($Request.blocks | Where-Object {$_ -match "^\d+?:\d+?:\d+?:\d+?:\d+?:(\d+?):"} | Foreach-Object {[int64]$Matches[1]} | Measure-Object -Sum).Sum / $coinUnits
			$Payouts = @($i=0;$Request.payments | Where-Object {$_ -match "^(.+?):(\d+?):"} | Foreach-Object {[PSCustomObject]@{time=$Request.payments[$i+1];amount=[Decimal]$Matches[2] / $coinUnits;txid=$Matches[1]};$i+=2})
            [PSCustomObject]@{
                Caption     = "$($Name) ($Pool_Currency)"
				BaseName    = $Name
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
    }
    catch {
        if ($Error.Count){$Error.RemoveAt(0)}
        Write-Log -Level Verbose "Pool Balance API ($Name) for $($Pool_Currency) has failed. "
    }
}
