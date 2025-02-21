using module ..\Modules\Include.psm1

param(
    $Config,
    $UsePools
)

$Name = Get-Item $MyInvocation.MyCommand.Path | Select-Object -ExpandProperty BaseName

$Request = [PSCustomObject]@{}

$Payout_Currencies = @()
$Payout_CurrenciesSolo = @()

foreach($PoolExt in @("","Solo")) {
    if (-not $UsePools -or "$($Name)$($PoolExt)" -in $UsePools) {
        if ($PoolExt -eq "Solo") {
            $Payout_CurrenciesSolo += @($Config.Pools."$($Name)$($PoolExt)".Wallets.PSObject.Properties | Select-Object)
        } else {
            $Payout_Currencies += @($Config.Pools."$($Name)".Wallets.PSObject.Properties | Select-Object)
        }
    }
}

$Payout_Currencies = $Payout_Currencies | Where-Object Value | Select-Object Name,Value -Unique | Sort-Object Name,Value
$Payout_CurrenciesSolo = $Payout_CurrenciesSolo | Where-Object Value | Select-Object Name,Value -Unique | Sort-Object Name,Value

if (-not $Payout_Currencies -and -not $Payout_CurrenciesSolo) {
    Write-Log -Level Verbose "Cannot get balance on pool ($Name) - no wallet address specified. "
    return    
}


$Pool_Request = [PSCustomObject]@{}

try {
    $Pool_Request = Invoke-RestMethodAsync "https://mining4people.com/api/pools" -retry 3 -retrywait 500 -tag $Name -cycletime 120
}
catch {
    Write-Log -Level Warn "Pool API ($Name) in balance module has failed. "
    return
}

if (-not $Pool_Request -or ($Pool_Request | Measure-Object).Count -le 5) {
    Write-Log -Level Warn "Pool API ($Name) in balance module returned nothing. "
    return
}

if ($Payout_Currencies) {

    $Count = 0
    $Payout_Currencies | Where-Object {$Currency = $_.Name;$Pool = $Pool_Request | Where-Object {$_.feeType -eq "PPLNSBF" -and $_.coin -eq $Currency};$Pool -and (-not $Config.ExcludeCoinsymbolBalances.Count -or $Config.ExcludeCoinsymbolBalances -notcontains $Currency)} | Foreach-Object {
        try {
            $Request = Invoke-RestMethodAsync "https://mining4people.com/api/pools/$($Pool.id)/account/$($_.Value)?perfMode=1" -delay $(if ($Count){250} else {0}) -cycletime ($Config.BalanceUpdateMinutes*60)
            $Count++

            $page = 0
            $Payments = @()
            while ($page -ge 0) {
                $Payments_Request = Invoke-RestMethodAsync "https://mining4people.com/api/pools/$($Pool.id)/account/$($_.Value)/payments?page=$($page)&pageSize=50" -delay 250 -cycletime ($Config.BalanceUpdateMinutes*60)
                if ($Payments_Request.success) {
                    $Payments += $Payments_Request.result
                    if ($page -lt $Payments_Request.pageCount) {
                        $page++
                    } else {
                        $page = -1
                    }
                } else {$page = -1}
            }

            if (-not $Request.success) {
                Write-Log -Level Info "Pool Balance API ($Name) for $($Currency) returned nothing. "
            } else {
                [PSCustomObject]@{
                    Caption     = "$($Name) ($($Currency))"
				    BaseName    = $Name
                    Currency    = $Currency
                    Balance     = [Decimal]$Request.result.pendingBalance
                    Pending     = [Decimal]$Request.result.estimatedBalance
                    Total       = [Decimal]$Request.result.pendingBalance + [Decimal]$Request.result.estimatedBalance
                    Paid        = [Decimal]$Request.result.totalPaid
                    Earned      = [Decimal]$Request.result.totalPaid + [Decimal]$Request.result.pendingBalance + [Decimal]$Request.estimatedBalance
                    Payouts     = @(Get-BalancesPayouts $Payments -DateTimeField "created" -AmountField "amount" | Select-Object)
                    LastUpdated = (Get-Date).ToUniversalTime()
                }
            }
        }
        catch {
            Write-Log -Level Verbose "Pool Balance API ($Name) for $($_.Name) has failed. "
        }
    }
}

if ($Payout_CurrenciesSolo) {

    $Count = 0
    $Payout_CurrenciesSolo | Where-Object {$Currency = $_.Name;$Pool = $Pool_Request | Where-Object {$_.feeType -eq "PPLNSBF70" -and $_.coin -eq $Currency};$Pool -and (-not $Config.ExcludeCoinsymbolBalances.Count -or $Config.ExcludeCoinsymbolBalances -notcontains $Currency)} | Foreach-Object {
        try {
            $Request = Invoke-RestMethodAsync "https://mining4people.com/api/pools/$($Pool.id)/account/$($_.Value)?perfMode=1" -delay $(if ($Count){500} else {0}) -cycletime ($Config.BalanceUpdateMinutes*60)
            $Count++

            $page = 0
            $Payments = @()
            while ($page -ge 0) {
                $Payments_Request = Invoke-RestMethodAsync "https://mining4people.com/api/pools/$($Pool.id)/account/$($_.Value)/payments?page=$($page)&pageSize=50" -delay 250 -cycletime ($Config.BalanceUpdateMinutes*60)
                if ($Payments_Request.success) {
                    $Payments += $Payments_Request.result
                    if ($page -lt $Payments_Request.pageCount) {
                        $page++
                    } else {
                        $page = -1
                    }
                } else {$page = -1}
            }

            if (-not $Request.success) {
                Write-Log -Level Info "Pool Balance API ($Name) for $($Currency) returned nothing. "
            } else {
                [PSCustomObject]@{
                    Caption     = "$($Name)Solo ($($Currency))"
				    BaseName    = "$($Name)Solo"
                    Currency    = $Currency
                    Balance     = [Decimal]$Request.result.pendingBalance
                    Pending     = [Decimal]$Request.result.estimatedBalance
                    Total       = [Decimal]$Request.result.pendingBalance + [Decimal]$Request.result.estimatedBalance
                    Paid        = [Decimal]$Request.result.totalPaid
                    Earned      = [Decimal]$Request.result.totalPaid + [Decimal]$Request.result.pendingBalance + [Decimal]$Request.estimatedBalance
                    Payouts     = @(Get-BalancesPayouts $Payments -DateTimeField "created" -AmountField "amount" | Select-Object)
                    LastUpdated = (Get-Date).ToUniversalTime()
                }
            }
        }
        catch {
            Write-Log -Level Verbose "Pool Balance API ($Name) for $($_.Name) has failed. "
        }
    }
}