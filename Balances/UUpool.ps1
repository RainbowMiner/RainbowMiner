param(
    $Config
)

$Name = Get-Item $MyInvocation.MyCommand.Path | Select-Object -ExpandProperty BaseName

$Pool_Request = [PSCustomObject]@{}
try {
    $Pool_Request = (Invoke-RestMethodAsync "https://uupool.cn/getCoins" -retry 3 -retrywait 500 -tag $Name -cycletime 3600).pow
}
catch {
    if ($Error.Count){$Error.RemoveAt(0)}
    Write-Log -Level Warn "Pool API ($Name) has failed. "
    return
}

if (-not $Pool_Request -or -not ($Pool_Request | Measure-Object).Count) {
    Write-Log -Level Warn "Pool API ($Name) returned nothing. "
    return
}

$Count = 0
$Pool_Request | Where-Object {$Pool_Currency = $_.coin -replace "(29|31)" -replace "^VDS$","VOLLAR";$Config.Pools.$Name.Wallets.$Pool_Currency -or $Config.Pools.$Name.Wallets."$($_.coin)"} | ForEach-Object {
    try {
        $Request = Invoke-RestMethodAsync "https://uupool.cn/api/getWallet.php?coin=$($_.coin)&address=$(if ($Config.Pools.$Name.Wallets.$Pool_Currency) {$Config.Pools.$Name.Wallets.$Pool_Currency} else {$Config.Pools.$Name.Wallets."$($_.coin)"})" -delay $(if ($Count){500} else {0}) -cycletime ($Config.BalanceUpdateMinutes*60)
        $Count++
        if (-not $Request) {
            Write-Log -Level Info "Pool Balance API ($Name) for $($_.Name) returned nothing. "            
        } else {
            [PSCustomObject]@{
                Caption     = "$($Name) ($($_.Name))"
                Currency    = if ($Session.Rates."$($_.coin)") {$_.coin} else {$Pool_Currency}
                Balance     = [double]$Request.balance / 1e8
                Pending     = 0
                Total       = [double]$Request.balance / 1e8
                Paid        = [double]$Request.paid / 1e8
                Earned      = 0
                Payouts     = @()
                LastUpdated = (Get-Date).ToUniversalTime()
            }
        }
    }
    catch {
        if ($Error.Count){$Error.RemoveAt(0)}
        Write-Log -Level Warn "Pool Balance API ($Name) for $($_.Name) has failed. "
    }
}
