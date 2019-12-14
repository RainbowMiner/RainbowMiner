param(
    $Config
)

$Name = Get-Item $MyInvocation.MyCommand.Path | Select-Object -ExpandProperty BaseName

$Pools_Data = @(
    [PSCustomObject]@{symbol = "AEON";  port = 10650; fee = 0.9; rpc = "aeon"; region = @("de","fi","hk")}
    [PSCustomObject]@{symbol = "ARQ";   port = 10640; fee = 0.9; rpc = "arqma"; region = @("de","fi","ca","hk","sg")}
    [PSCustomObject]@{symbol = "TUBE";  port = 10280; fee = 0.9; rpc = "tube"; region = @("de","fi","ca","hk","sg")}
    [PSCustomObject]@{symbol = "BLOC";  port = 10430; fee = 0.9; rpc = "bloc"; region = @("de","fi","ca","hk","sg")}
    [PSCustomObject]@{symbol = "CCX";   port = 10360; fee = 0.9; rpc = "conceal"; region = @("fi","de","ca","hk","sg")}
    [PSCustomObject]@{symbol = "XEQ";   port = 10600; fee = 0.9; rpc = "equilibria"; region = @("de","hk")}
    [PSCustomObject]@{symbol = "GRFT";  port = 10100; fee = 0.9; rpc = "graft"; region = @("de","fi","ca","hk","sg")}
    [PSCustomObject]@{symbol = "XHV";   port = 10450; fee = 0.9; rpc = "haven"; region = @("de","fi","ca","hk","sg")}
    [PSCustomObject]@{symbol = "IRD";   port = 10670; fee = 0.9; rpc = "iridium"; region = @("de","fi","ca","hk","sg")}
    [PSCustomObject]@{symbol = "LOKI";  port = 10110; fee = 0.9; rpc = "loki"; region = @("de","fi","ca","hk","sg")}
    [PSCustomObject]@{symbol = "MSR";   port = 10150; fee = 0.9; rpc = "masari"; region = @("de","fi","ca","hk","sg")}
    [PSCustomObject]@{symbol = "XMR";   port = 10190; fee = 0.9; rpc = "monero"; region = @("de","fi","ca","hk","sg")}
    [PSCustomObject]@{symbol = "QRL";   port = 10370; fee = 0.9; rpc = "qrl"; region = @("de")}
    [PSCustomObject]@{symbol = "RYO";   port = 10270; fee = 0.9; rpc = "ryo"; region = @("de","fi")}
    [PSCustomObject]@{symbol = "XLA";   port = 10130; fee = 0.9; rpc = "scala"; region = @("de","fi","hk")}
    [PSCustomObject]@{symbol = "SUMO";  port = 10610; fee = 0.9; rpc = "sumo"; region = @("de","fi")}
    [PSCustomObject]@{symbol = "XWP";   port = 10440; fee = 0.9; rpc = "swap"; divisor = 32; region = @("de","fi","ca","hk","sg")}
    [PSCustomObject]@{symbol = "TRTL";  port = 10380; fee = 0.9; rpc = "turtlecoin"; region = @("de","fi","ca","hk","sg")}
    [PSCustomObject]@{symbol = "UPX";   port = 10470; fee = 0.9; rpc = "uplexa"; region = @("fi","de","ca","hk","sg")}
    [PSCustomObject]@{symbol = "WOW";   port = 10660; fee = 0.9; rpc = "wownero"; region = @("de","fi","hk")}
    [PSCustomObject]@{symbol = "XCASH"; port = 10490; fee = 0.9; rpc = "xcash"; region = @("fi","de","ca","hk","sg")}
)

$Pools_Data | Where-Object {$Config.Pools.$Name.Wallets."$($_.symbol)" -and (-not $_.symbol2 -or $Config.Pools.$Name.Wallets."$($_.symbol2)")} | Foreach-Object {
    $Pool_Currency = $_.symbol
    $Pool_Currency2 = $_.symbol2
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
