using module ..\Modules\Include.psm1

param(
    $Config
)

$Name = Get-Item $MyInvocation.MyCommand.Path | Select-Object -ExpandProperty BaseName

$Pools_Data = @(
    [PSCustomObject]@{symbol = "AEON";  port = 1145; fee = 0.9; rpc = "aeon"; region = @("de","fi","hk")}
    [PSCustomObject]@{symbol = "ALPH";  port = 1199; fee = 0.0; rpc = "alephium"; region = @("de","fi","ca","us","hk","sg","tr")}
    [PSCustomObject]@{symbol = "ARQ";   port = 1143; fee = 0.9; rpc = "arqma"; region = @("de","fi","ca","us","hk","sg","tr")}
    [PSCustomObject]@{symbol = "BEAM";  port = 1130; fee = 0.9; rpc = "beam"; region = @("de","fi","ca","us","hk","sg","tr")}
    [PSCustomObject]@{symbol = "TUBE";  port = 1120; fee = 0.9; rpc = "bittube"; region = @("de","fi","ca","us","hk","sg","tr"); diffFactor = 40}
    [PSCustomObject]@{symbol = "CCX";   port = 1115; fee = 0.9; rpc = "conceal"; region = @("de","fi","ca","us","hk","sg","tr")}
    [PSCustomObject]@{symbol = "CFX";   port = 1170; fee = 0.9; rpc = "conflux"; region = @("de","fi","ca","us","hk","sg","tr")}
    [PSCustomObject]@{symbol = "CTXC";  port = 1155; fee = 0.9; rpc = "cortex"; region = @("de","fi","ca","hk","sg","tr"); diffFactor = 42}
    [PSCustomObject]@{symbol = "XEQ";   port = 1195; fee = 0.9; rpc = "equilibria"; region = @("de","fi","ca","hk","sg","tr")}
    [PSCustomObject]@{symbol = "ERG";   port = 1180; fee = 0.9; rpc = "ergo"; region = @("de","fi","ca","us","hk","sg","tr")}
    [PSCustomObject]@{symbol = "ETC";   port = 1150; fee = 0.9; rpc = "etc"; region = @("de","fi","ca","us","hk","sg","tr")}
    [PSCustomObject]@{symbol = "ETH";   port = 1147; fee = 0.9; rpc = "ethereum"; region = @("de","fi","ca","us","hk","sg","tr")}
    [PSCustomObject]@{symbol = "FLUX";  port = 1200; fee = 0.9; rpc = "flux"; region = @("de","fi","ca","us","hk","sg","tr")}
    [PSCustomObject]@{symbol = "GRIN-PRI";port = 1125; fee = 0.9; rpc = "grin"; region = @("de","fi","ca","us","hk","sg","tr"); cycles = 32}
    [PSCustomObject]@{symbol = "XHV";   port = 1110; fee = 0.9; rpc = "haven"; region = @("de","fi","ca","us","hk","sg","tr")}
    [PSCustomObject]@{symbol = "KVA";   port = 1163; fee = 0.9; rpc = "kevacoin"; region = @("de","fi","ca","hk","sg")}
    [PSCustomObject]@{symbol = "XMR";   port = 1111; fee = 0.9; rpc = "monero"; region = @("de","fi","ca","us","hk","sg","tr")}
    [PSCustomObject]@{symbol = "MWC-PRI";port = 1128; fee = 0.9; rpc = "mwc"; region = @("de","fi","ca","us","hk","sg","tr"); cycles = 31}
    [PSCustomObject]@{symbol = "QRL";   port = 1166; fee = 0.9; rpc = "qrl"; region = @("de","fi","ca","us","hk","sg","tr")}
    [PSCustomObject]@{symbol = "RVN";   port = 1140; fee = 0.9; rpc = "ravencoin"; region = @("de","fi","ca","us","hk","sg","tr"); diffFactor = [Math]::Pow(2,32)}
    [PSCustomObject]@{symbol = "XLA";   port = 1190; fee = 0.9; rpc = "scala"; region = @("de","fi","ca","us","hk","sg","tr")}
    [PSCustomObject]@{symbol = "XWP";   port = 1123; fee = 0.9; rpc = "swap"; region = @("de","fi","ca","us","hk","sg","tr"); diffFactor = 32}
    [PSCustomObject]@{symbol = "TRTL";  port = 1160; fee = 0.9; rpc = "turtlecoin"; region = @("de","fi","ca","us","hk","sg","tr")}
    [PSCustomObject]@{symbol = "UPX";   port = 1177; fee = 0.9; rpc = "uplexa"; region = @("de","fi","ca","us","hk","sg","tr")}

    #[PSCustomObject]@{symbol = "DERO";  port = 1117; fee = 0.9; rpc = "dero"; region = @("de","fi","ca","us","hk","sg","tr")}
    #[PSCustomObject]@{symbol = "EXP";   port = 10181; fee = 0.9; rpc = "expanse"; region = @("de","fi","ca","us","hk","sg","tr")}
    #[PSCustomObject]@{symbol = "GRIN-SEC";port = 10301; fee = 0.9; rpc = "grin"; region = @("de","fi","ca","us","hk","sg","tr")}
    #[PSCustomObject]@{symbol = "XMV";   port = 10151; fee = 0.9; rpc = "monerov"; region = @("de","fi","ca","us","hk","sg","tr"); diffFactor = 16}
    #[PSCustomObject]@{symbol = "MWC-SEC";port = 10311; fee = 0.9; rpc = "mwc"; region = @("de","fi","ca","us","hk","sg","tr")}
    #[PSCustomObject]@{symbol = "WOW";   port = 10661; fee = 0.9; rpc = "wownero"; region = @("de","fi","ca","us","hk","sg")}
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
