param(
    $Config
)

$Name = Get-Item $MyInvocation.MyCommand.Path | Select-Object -ExpandProperty BaseName

$Request = [PSCustomObject]@{}

$Payout_Currencies = $Config.Pools.$Name.Wallets.PSObject.Properties | Where-Object Value | Select-Object Name,Value -Unique | Sort-Object Name,Value

if (-not $Payout_Currencies) {
    Write-Log -Level Verbose "Cannot get balance on pool ($Name) - no wallet address specified. "
    return
}

$PoolCoins_Request = [PSCustomObject]@{}

$ok = $false
try {
    $PoolCoins_Request = Invoke-RestMethodAsync "https://hashpool.com/api/coins" -tag $Name -cycletime 120
    if ($PoolCoins_Request.code -eq 0 -and ($PoolCoins_Request.data | Measure-Object).Count) {$ok = $true}
}
catch {
    if ($Error.Count){$Error.RemoveAt(0)}
}

if (-not $ok) {
    Write-Log -Level Warn "Pool API ($Name) has failed. "
    return
}

$Pool_Coins = @{}
$PoolCoins_Request.data | Foreach-Object {
    $Pool_Coins."$($_.coin -replace "DGBODO","DBG")" = $_.coin
}

$Count = 0
$Payout_Currencies | Where-Object {$Pool_Coins.ContainsKey($_.Name)} | Foreach-Object {
    $Pool_Currency   = $_.Name
    $Pool_CoinSymbol = $Pool_Coins.$Pool_Currency

    try {
        $Request = Invoke-RestMethodAsync "https://hashpool.com/api/worker/base-info/$($Pool_CoinSymbol)?address=$($_.Value)" -delay $(if ($Count){500} else {0}) -cycletime ($Config.BalanceUpdateMinutes*60)
        $Count++
        if ($Request.code -ne 0 -or $Request.data.address -eq $null) {
            Write-Log -Level Info "Pool Balance API ($Name) for $($_.Name) returned nothing. "
        } else {
            [PSCustomObject]@{
                Caption     = "$($Name) ($($Pool_Currency))"
				BaseName    = $Name
                Currency    = $Pool_Currency
                Balance     = [Decimal]$Request.data.balance
                Pending     = 0
                Total       = [Decimal]$Request.data.balance
                Earned      = [Decimal]$Request.data.earnAmount
                Payouts     = @()
                LastUpdated = (Get-Date).ToUniversalTime()
            }
        }
    }
    catch {
        if ($Error.Count){$Error.RemoveAt(0)}
        Write-Log -Level Verbose "Pool Balance API ($Name) for $($_.Name) has failed. "
    }
}
