param(
    $Config
)

$Name = Get-Item $MyInvocation.MyCommand.Path | Select-Object -ExpandProperty BaseName

$Pools_Data = @(
    [PSCustomObject]@{coin = "EthereumClassic"; algo = "Ethash";        symbol = "ETC"; port = 19999; fee = 1; divisor = 1000000; ssl = $false; protocol = "stratum+tcp"}
    [PSCustomObject]@{coin = "Ethereum";        algo = "Ethash";        symbol = "ETH"; port = 9999;  fee = 1; divisor = 1000000; ssl = $false; protocol = "stratum+tcp"}
    [PSCustomObject]@{coin = "Zcash";           algo = "Equihash";      symbol = "ZEC"; port = 6666;  fee = 1; divisor = 1;       ssl = $true;  protocol = "stratum+ssl"}
    [PSCustomObject]@{coin = "Monero";          algo = "CrypotnightV7"; symbol = "XMR"; port = 14444; fee = 1; divisor = 1;       ssl = $true;  protocol = "stratum+ssl"}
    [PSCustomObject]@{coin = "Electroneum";     algo = "Cryptonight";   symbol = "ETN"; port = 13333; fee = 2; divisor = 1;       ssl = $true;  protocol = "stratum+ssl"}
)

$Count = 0
$Pools_Data | Where-Object {$Config.Pools.$Name.Wallets."$($_.symbol)"} | Foreach-Object {
    $Pool_Currency = $_.symbol
    try {
        $Request = Invoke-RestMethodAsync "https://api.nanopool.org/v1/$($Pool_Currency.ToLower())/user/$($Config.Pools.$Name.Wallets.$Pool_Currency)" -delay $(if ($Count){500} else {0}) -cycletime ($Config.BalanceUpdateMinutes*60) -retry 5 -retrywait 200
        $Count++
        if (-not $Request.status) {
            Write-Log -Level Info "Pool Balance API ($Name) for $($Pool_Currency) returned $($Request.error). "
        } else {
            [PSCustomObject]@{
                Caption     = "$($Name) ($Pool_Currency)"
                Currency    = $Pool_Currency
                Balance     = [Math]::Max([double]$Request.data.balance,0)
                Pending     = [double]$Request.data.unconfirmed_balance
                Total       = [Math]::Max([double]$Request.data.balance,0) + [double]$Request.data.unconfirmed_balance
                Payed       = 0
                Earned      = 0
                Payouts     = @()
                LastUpdated = (Get-Date).ToUniversalTime()
            }
        }
    }
    catch {
        if ($Error.Count){$Error.RemoveAt(0)}
        Write-Log -Level Warn "Pool Balance API ($Name) for $($Pool_Currency) has failed. "
    }
}
