param(
    $Config
)

$Name = Get-Item $MyInvocation.MyCommand.Path | Select-Object -ExpandProperty BaseName

$Pools_Data = @(
    [PSCustomObject]@{coin = "EthereumClassic"; algo = "Ethash";        symbol = "ETC";  port = 19999; fee = 1; divisor = 1e6; ssl = $false; protocol = "stratum+tcp"; useemail = $true; usepid = $false}
    [PSCustomObject]@{coin = "Ethereum";        algo = "Ethash";        symbol = "ETH";  port = 9999;  fee = 1; divisor = 1e6; ssl = $false; protocol = "stratum+tcp"; useemail = $true; usepid = $false}
    [PSCustomObject]@{coin = "Zcash";           algo = "Equihash";      symbol = "ZEC";  port = 6666;  fee = 1; divisor = 1;   ssl = $true;  protocol = "stratum+ssl"; useemail = $true; usepid = $false}
    [PSCustomObject]@{coin = "Monero";          algo = "CrypotnightR";  symbol = "XMR";  port = 14444; fee = 1; divisor = 1;   ssl = $true;  protocol = "stratum+ssl"; useemail = $true; usepid = $true}
    [PSCustomObject]@{coin = "Electroneum";     algo = "Cryptonight";   symbol = "ETN";  port = 13333; fee = 2; divisor = 1;   ssl = $true;  protocol = "stratum+ssl"; useemail = $true; usepid = $false}
    [PSCustomObject]@{coin = "RavenCoin";       algo = "X16r";          symbol = "RVN";  port = 12222; fee = 1; divisor = 1e6; ssl = $false; protocol = "stratum+tcp"; useemail = $true; usepid = $false}
    [PSCustomObject]@{coin = "PascalCoin";      algo = "Randomhash";    symbol = "PASC"; port = 15556; fee = 2; divisor = 1;   ssl = $false; protocol = "stratum+tcp"; useemail = $true; usepid = $true}
    [PSCustomObject]@{coin = "Grin";            algo = "Cuckarood29";   symbol = "GRIN"; port = 12111; fee = 2; divisor = 1;   ssl = $false; protocol = "stratum+tcp"; useemail = $false; walletsymbol = "GRIN29"}
)

$Count = 0
$Pools_Data | Where-Object {$Config.Pools.$Name.Wallets."$($_.symbol)"} | Foreach-Object {
    $Pool_Currency = $_.symbol
    $Pool_User = $Config.Pools.$Name.Wallets.$Pool_Currency
    if ($Pool_Currency -eq "PASC") {$Pool_User = $Pool_User -replace '-.+$'}
    $Pool_User = "$($Pool_User)$(if ($_.usepid -and $Pool_User -notmatch "^.+?\.[^\.]+$") {".0"})"
    try {
        $Request = Invoke-RestMethodAsync "https://api.nanopool.org/v1/$($Pool_Currency.ToLower())/user/$($Pool_User)" -delay $(if ($Count){500} else {0}) -cycletime ($Config.BalanceUpdateMinutes*60) -retry 5 -retrywait 200
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
                Paid        = 0
                Earned      = 0
                Payouts     = @(try {Invoke-RestMethodAsync "https://api.nanopool.org/v1/$($Pool_Currency.ToLower())/payments/$($Pool_User)/0/50" -delay $(if ($Count){500} else {0}) -cycletime ($Config.BalanceUpdateMinutes*60) -retry 5 -retrywait 200 | Where-Object status | Select-Object -ExpandProperty data} catch {})
                LastUpdated = (Get-Date).ToUniversalTime()
            }
        }
    }
    catch {
        if ($Error.Count){$Error.RemoveAt(0)}
        Write-Log -Level Warn "Pool Balance API ($Name) for $($Pool_Currency) has failed. "
    }
}
