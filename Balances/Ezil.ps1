using module ..\Modules\Include.psm1

param(
    $Config
)

$Name = Get-Item $MyInvocation.MyCommand.Path | Select-Object -ExpandProperty BaseName

if (-not $Config.Pools.$Name.Wallets.ZIL) {return}

$Zil = [ordered]@{}

@("ETH","ETC") | Where-Object {$Config.Pools.$Name.Wallets.$_ -and (-not $Config.ExcludeCoinsymbolBalances.Count -or $Config.ExcludeCoinsymbolBalances -notcontains $_)} | Foreach-Object {
    $Request = [PSCustomObject]@{}
    try {
        $Request = Invoke-RestMethodAsync "https://billing.ezil.me/balances/$($Config.Pools.$Name.Wallets.$_).$($Config.Pools.$Name.Wallets.ZIL)" -cycletime ($Config.BalanceUpdateMinutes*60)
        [PSCustomObject]@{
            Caption     = "$($Name) ($($_))"
			BaseName    = $Name
            Currency    = $_
            Balance     = [Decimal]$Request.$_
            Pending     = 0
            Total       = [Decimal]$Request.$_
            Paid        = [Decimal]0
            Earned      = [Decimal]0
            Payouts     = @()
            LastUpdated = (Get-Date).ToUniversalTime()
        }
        $Zil["$($Request.zil_wallet)"] = $Request.zil
    }
    catch {
        if ($Error.Count){$Error.RemoveAt(0)}
        Write-Log -Level Warn "Pool Balance API ($Name) for $($_.Name) has failed. "
    }
}

if ($Zil.Count) {
    $Zil.GetEnumerator() | Foreach-Object {
        [PSCustomObject]@{
            Caption     = "$($Name) (ZIL)"
			BaseName    = $Name
            Info        = if ($Zil.Count -gt 1) {" $($_.Name.Substring(0,3))..$($_.Name.Substring($_.Name.Length-3,3))"} else {$null}
            Currency    = "ZIL"
            Balance     = [Decimal]$_.Value
            Pending     = 0
            Total       = [Decimal]$_.Value
            Paid        = [Decimal]0
            Earned      = [Decimal]0
            Payouts     = @()
            LastUpdated = (Get-Date).ToUniversalTime()
        }
    }
}
