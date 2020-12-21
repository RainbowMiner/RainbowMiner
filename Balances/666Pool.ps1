using module ..\Modules\Include.psm1

param(
    $Config
)

$Name = Get-Item $MyInvocation.MyCommand.Path | Select-Object -ExpandProperty BaseName

$Payout_Currencies = $Config.Pools.$Name.Wallets.PSObject.Properties | Where-Object {$_.Name -in @("ETC","ETH","PGN","PMEER","RVN","UFO","VDS") -and $_.Value} | Select-Object Name,Value -Unique | Sort-Object Name,Value

if (-not $Payout_Currencies) {
    Write-Log -Level Verbose "Cannot get balance on pool ($Name) - no wallet address specified. "
    return
}

$Payout_Currencies | Where-Object {-not $Config.ExcludeCoinsymbolBalances.Count -or $Config.ExcludeCoinsymbolBalances -notcontains "$($_.Name)"} | Foreach-Object {
    $Pool_Currency = $_.Name

    $Pool_Wallet = $_.Value -replace "@(pps|pplns)$"

    try {
        $Request = Invoke-RestMethodAsync "https://666pool.cn/pool2/main/$($Pool_Currency)/$($Pool_Wallet)" -delay $(if ($Count){1000} else {0}) -cycletime ($Config.BalanceUpdateMinutes*60)
        $Count++
        if (-not ($Data = ([regex]'(?si)<div class="col djs-bord">(.+?)</div>').Matches($Request)) -or $Data.Count -lt 2) {
            Write-Log -Level Info "Pool Balance API ($Name) for $($Pool_Currency) returned nothing. "
        } else {
            $BalanceStr = $Data[0].Groups[1] -replace '&nbsp;'
            $PaidStr    = $Data[1].Groups[1] -replace '&nbsp;'

            $Balance = [Decimal]$(if ($BalanceStr -match "<p[^>]*>([\d\.]+)<") {$Matches[1]} else {0})
            $Total   = [Decimal]$(if ($BalanceStr -match "<small>([\d\.]+)<") {$Matches[1]} else {0})
            $Paid    = [Decimal]$(if ($PaidStr    -match "<p[^>]*>([\d\.]+)<") {$Matches[1]} else {0})
            if ($Total -lt $Balance) {$Total = $Balance}

            [PSCustomObject]@{
                Caption     = "$($Name) ($Pool_Currency))"
				BaseName    = $Name
                Currency    = $Pool_Currency
                Balance     = $Balance
                Pending     = $Total - $Balance
                Total       = $Total
                Paid        = $Paid
                Earned      = $Paid + $Balance
                Payouts     = @()
                LastUpdated = (Get-Date).ToUniversalTime()
            }
        }
    }
    catch {
        if ($Error.Count){$Error.RemoveAt(0)}
        Write-Log -Level Verbose "Pool Balance API ($Name) for $($Pool_Currency) has failed. "
    }
}
