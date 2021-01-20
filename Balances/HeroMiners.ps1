using module ..\Modules\Include.psm1

param(
    $Config
)

$Name = Get-Item $MyInvocation.MyCommand.Path | Select-Object -ExpandProperty BaseName

$Pools_Data = @(
    [PSCustomObject]@{symbol = "AEON";  port = 10651; fee = 0.9; rpc = "aeon"; region = @("de","fi","hk")}
    [PSCustomObject]@{symbol = "ARQ";   port = 10641; fee = 0.9; rpc = "arqma"; region = @("de","fi","ca","hk","sg")}
    [PSCustomObject]@{symbol = "BEAM";  port = 10231; fee = 0.9; rpc = "beam"; region = @("de","fi","ca","hk","sg")}
    [PSCustomObject]@{symbol = "TUBE";  port = 10281; fee = 0.9; rpc = "bittube"; region = @("de","fi","ca","hk","sg")}
    [PSCustomObject]@{symbol = "CLO";   port = 10211; fee = 0.9; rpc = "callisto"; region = @("de","fi","ca","hk","sg")}
    [PSCustomObject]@{symbol = "CCX";   port = 10361; fee = 0.9; rpc = "conceal"; region = @("de","fi","ca","hk","sg")}
    [PSCustomObject]@{symbol = "CFX";   port = 10221; fee = 0.9; rpc = "conflux"; region = @("de","fi","ca","hk","sg")}
    [PSCustomObject]@{symbol = "CTXC";  port = 10321; fee = 0.9; rpc = "cortex"; region = @("de","fi","ca","hk","sg")}
    [PSCustomObject]@{symbol = "DERO";  port = 10121; fee = 0.9; rpc = "dero"; region = @("de","fi","ca","hk","sg")}
    [PSCustomObject]@{symbol = "ETH";   port = 10201; fee = 0.9; rpc = "ethereum"; region = @("de","fi","ca","hk","sg")}
    [PSCustomObject]@{symbol = "ETC";   port = 10161; fee = 0.9; rpc = "etc"; region = @("de","fi","ca","hk","sg")}
    [PSCustomObject]@{symbol = "EXP";   port = 10181; fee = 0.9; rpc = "expanse"; region = @("de","fi","ca","hk","sg")}
    [PSCustomObject]@{symbol = "GRIN-SEC";port = 10301; fee = 0.9; rpc = "grin"; region = @("de","fi","ca","hk","sg")}
    [PSCustomObject]@{symbol = "GRIN-PRI";port = 10301; fee = 0.9; rpc = "grin"; region = @("de","fi","ca","hk","sg")}
    [PSCustomObject]@{symbol = "XHV";   port = 10451; fee = 0.9; rpc = "haven"; region = @("de","fi","ca","hk","sg")}
    [PSCustomObject]@{symbol = "KVA";   port = 10141; fee = 0.9; rpc = "kevacoin"; region = @("de","fi","ca","hk","sg")}
    [PSCustomObject]@{symbol = "MSR";   port = 10151; fee = 0.9; rpc = "masari"; region = @("de","fi","ca","hk","sg")}
    [PSCustomObject]@{symbol = "XMR";   port = 10191; fee = 0.9; rpc = "monero"; region = @("de","fi","ca","hk","sg")}
    [PSCustomObject]@{symbol = "MWC-SEC";port = 10311; fee = 0.9; rpc = "mwc"; region = @("de","fi","ca","hk","sg")}
    [PSCustomObject]@{symbol = "MWC-PRI";port = 10311; fee = 0.9; rpc = "mwc"; region = @("de","fi","ca","hk","sg")}
    [PSCustomObject]@{symbol = "QRL";   port = 10371; fee = 0.9; rpc = "qrl"; region = @("de","fi","ca","hk","sg")}
    [PSCustomObject]@{symbol = "RVN";   port = 10241; fee = 0.9; rpc = "ravencoin"; region = @("de","fi","ca","hk","sg")}
    [PSCustomObject]@{symbol = "RYO";   port = 10271; fee = 0.9; rpc = "ryo"; region = @("de","fi")}
    [PSCustomObject]@{symbol = "XLA";   port = 10131; fee = 0.9; rpc = "scala"; region = @("de","fi","ca","hk","sg")}
    [PSCustomObject]@{symbol = "SUMO";  port = 10611; fee = 0.9; rpc = "sumo"; region = @("de","fi","ca","hk","sg")}
    [PSCustomObject]@{symbol = "XWP";   port = 10441; fee = 0.9; rpc = "swap"; region = @("de","fi","ca","hk","sg")}
    [PSCustomObject]@{symbol = "TRTL";  port = 10381; fee = 0.9; rpc = "turtlecoin"; region = @("de","fi","ca","hk","sg")}
    [PSCustomObject]@{symbol = "UPX";   port = 10471; fee = 0.9; rpc = "uplexa"; region = @("de","fi","ca","hk","sg")}
    [PSCustomObject]@{symbol = "WOW";   port = 10661; fee = 0.9; rpc = "wownero"; region = @("de","fi","ca","hk","sg")}
    [PSCustomObject]@{symbol = "XCASH"; port = 10491; fee = 0.9; rpc = "xcash"; region = @("de","fi","ca","hk","sg")}
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
