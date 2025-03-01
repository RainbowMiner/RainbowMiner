using module ..\Modules\Include.psm1

param(
    [String]$Name,
    $Config,
    $UsePools
)

# $Name = Get-Item $MyInvocation.MyCommand.Path | Select-Object -ExpandProperty BaseName

$Pool_Currency = "BLOCX"

if ($Config.ExcludeCoinsymbolBalances.Count -and $Config.ExcludeCoinsymbolBalances -contains $Pool_Currency) {return}

foreach($PoolExt in @("","Solo")) {

    $Pool_Wallet = $Config.Pools."$($Name)$($PoolExt)".Wallets.$Pool_Currency
    
    if ($Pool_Wallet -and (-not $UsePools -or "$($Name)$($PoolExt)" -in $UsePools)) {

        $Request = [PSCustomObject]@{}
        try {
            $Request = Invoke-RestMethodAsync "https://api.thepool.zone/v1/blocx/miner/paymentDetails?address=$($Pool_Wallet)&currency=usd" -cycletime ($Config.BalanceUpdateMinutes*60)
        }
        catch {
        }

        if ($Request.error -or -not $Request.result) {
            Write-Log -Level Info "Pool Balance API ($Name) returned nothing. "
            return
        }

        [PSCustomObject]@{
                Caption     = "$($Name) ($($Pool_Currency))"
		        BaseName    = $Name
                Name        = $Name
                Currency    = $Pool_Currency
                Balance     = [Decimal]$Request.result.immatureBalance
                Pending     = [Decimal]0
                Total       = [Decimal]$Request.result.totalBalance + [Decimal]$Request.result.immatureBalance
                Paid        = [Decimal]$Request.result.sumPayments
                Payouts     = @()
                LastUpdated = (Get-Date).ToUniversalTime()
        }
    }
}
