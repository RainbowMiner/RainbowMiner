using module ..\Modules\Include.psm1

param(
    [String]$Name,
    $Config
)

# $Name = Get-Item $MyInvocation.MyCommand.Path | Select-Object -ExpandProperty BaseName

$Pools_Data = @(
    [PSCustomObject]@{symbol = "XCB";   port = 3118; fee = 0.9; rpc = "corecoin";   user = "{wallet}{=diff}.{worker}"; pass="x"}
    [PSCustomObject]@{symbol = "XCC";   port = 4481; fee = 0.9; rpc = "cyberchain"; user = "{wallet}{=diff}.{worker}"; pass="x"}
    [PSCustomObject]@{symbol = "LAX";   port = 2200; fee = 0.9; rpc = "parallax";   user = "{wallet}{=diff}.{worker}"; pass="x"}
    [PSCustomObject]@{symbol = "LBRT";  port = 4118; fee = 0.9; rpc = "liberty";    user = "{wallet}{=diff}.{worker}"; pass="x"}
    [PSCustomObject]@{symbol = "MCM";   port = 3336; fee = 0.9; rpc = "mochimo";    user = "{wallet}{=diff}.{worker}"; pass="x"}
    [PSCustomObject]@{symbol = "NIR";   port = 3377; fee = 0.9; rpc = "nirmata";    user = "{wallet}.{worker}{.diff}"; pass="x"}
    [PSCustomObject]@{symbol = "QUAI";  port = 3333; fee = 0.9; rpc = "quai";       user = "{wallet}{=diff}.{worker}"; pass="x"}
    [PSCustomObject]@{symbol = "QTC";   port = 8611; fee = 0.9; rpc = "qubitcoin";  user = "{wallet}{=diff}.{worker}"; pass="x"}
    [PSCustomObject]@{symbol = "R5";    port = 2118; fee = 0.9; rpc = "r5";         user = "{wallet}{=diff}.{worker}"; pass="x"}
    [PSCustomObject]@{symbol = "XTM";   port = 9118; fee = 0.9; rpc = "tarirx";     user = "{wallet}{=diff}.{worker}"; pass="x"; algorithm = "RandomX"}
    [PSCustomObject]@{symbol = "XTM";   port = 6118; fee = 0.9; rpc = "tari";       user = "{wallet}{=diff}.{worker}"; pass="x"; algorithm = "SHA3x"}
    [PSCustomObject]@{symbol = "XE";    port = 3381; fee = 0.9; rpc = "xechain";    user = "{wallet}{=diff}.{worker}"; pass="x"}
    [PSCustomObject]@{symbol = "XEL";   port = 2666; fee = 0.9; rpc = "xelis";      user = "{wallet}{=diff}.{worker}"; pass="x"}
    [PSCustomObject]@{symbol = "ZANO";  port = 8877; fee = 0.9; rpc = "zano";       user = "{wallet}.{worker}";        pass="x{diff}"}
)

$Pools_Data | Where-Object {$Config.Pools.$Name.Wallets."$($_.symbol)" -and (-not $Config.ExcludeCoinsymbolBalances.Count -or $Config.ExcludeCoinsymbolBalances -notcontains "$($_.symbol)")} | Foreach-Object {
    $Pool_Currency = $_.symbol
    $Pool_RpcPath = $_.rpc

    $Pool_Request = [PSCustomObject]@{}
    $Request = [PSCustomObject]@{}

    try {
        $Pool_Request = Invoke-RestMethodAsync "https://$($Pool_RpcPath).luckypool.io/api/stats" -tag $Name -cycletime 120
        $Divisor = [Decimal]$Pool_Request.config.coinUnits

        $Request = Invoke-RestMethodAsync "https://$($Pool_RpcPath).luckypool.io/api/stats_address?address=$(Get-WalletWithPaymentId $Config.Pools.$Name.Wallets.$Pool_Currency -pidchar '')" -delay 100 -cycletime ($Config.BalanceUpdateMinutes*60) -timeout 15
        if (-not $Request.stats -or -not $Divisor) {
            Write-Log -Level Info "Pool Balance API ($Name) for $($Pool_Currency) returned nothing. "
        } else {
            if ($Request.stats.balance -eq $null -and ($Request.stats.locked -ne $null -or $Request.stats.unlocked -ne $null)) {
                $Balance = [Decimal]$Request.stats.unlocked / $Divisor
                $Pending = [Decimal]$Request.stats.locked / $Divisor
            } else {
                $Balance = [Decimal]$Request.stats.balance / $Divisor
                $Pending = ($Request.blocks | Where-Object {$_ -match "^\d+?:\d+?:\d+?:\d+?:\d+?:(\d+?):"} | Foreach-Object {[int64]$Matches[1]} | Measure-Object -Sum).Sum / $Divisor
            }
			$Payouts = @($i=0;$Request.payments | Where-Object {$_ -match "^(.+?):(\d+?):"} | Foreach-Object {[PSCustomObject]@{time=$Request.payments[$i+1];amount=[Decimal]$Matches[2] / $Divisor;txid=$Matches[1]};$i+=2})
            [PSCustomObject]@{
                Caption     = "$($Name) ($Pool_Currency)"
				BaseName    = $Name
                Name        = $Name
                Currency    = $Pool_Currency
                Balance     = [Decimal]$Balance
                Pending     = [Decimal]$Pending
                Total       = [Decimal]$Balance + [Decimal]$Pending
                Paid        = [Decimal]$Request.stats.paid / $Divisor
                Payouts     = @(Get-BalancesPayouts $Payouts | Select-Object)
                LastUpdated = (Get-Date).ToUniversalTime()
            }
			Remove-Variable "Payouts"
        }
    }
    catch {
        Write-Log -Level Verbose "Pool Balance API ($Name) for $($Pool_Currency) has failed. "
    }
}
