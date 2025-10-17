using module ..\Modules\Include.psm1

param(
    [String]$Name,
    $Config,
    $UsePools
)

# $Name = Get-Item $MyInvocation.MyCommand.Path | Select-Object -ExpandProperty BaseName

$Payout_Currencies = @(foreach ($PoolExt in "","Solo") {
    if (-not $UsePools -or "$Name$PoolExt" -in $UsePools) {
        $Config.Pools."$Name$PoolExt".Wallets.PSObject.Properties | Where-Object Value
    }
}) | Sort-Object Name, Value -Unique

if (-not $Payout_Currencies) {
    Write-Log -Level Verbose "Cannot get balance on pool ($Name) - no wallet address specified. "
    return
}

if ($Payout_Currencies -contains "SKYDOGE") {$Payout_Currencies[$Payout_Currencies.indexOf("SKYDOGE")] = "SKY"}

try {
    $Pools_Request = Invoke-RestMethodAsync "https://pool.rplant.xyz/api/dash" -tag $Name -timeout 30 -cycletime 120
}
catch {
    Write-Log -Level Warn "Pool API ($Name) has failed. "
    return
}

$Pool_Coins = @($Pools_Request.tbs.PSObject.Properties.Value | Select-Object -ExpandProperty symbol -Unique) 

$Count = 0
$Payout_Currencies | Where-Object {$Pool_Coins -contains $_.Name -and (-not $Config.ExcludeCoinsymbolBalances.Count -or $Config.ExcludeCoinsymbolBalances -notcontains $_.Name)} | Foreach-Object {
    $Pool_Currency = $_.Name
    $Pool_Name = "$($Pools_Request.tbs.PSObject.Properties | Where-Object {$_.Value.symbol -eq $Pool_Currency} | Foreach-Object {$_.Name} | Select-Object -First 1)"
    if ($Pool_Name) {
        $Request = [PSCustomObject]@{}
        try {
            $Request = Invoke-RestMethodAsync "https://pool.rplant.xyz/api/wallet/$($Pool_Name)/$($_.Value)" -delay $(if ($Count){500} else {0}) -cycletime ($Config.BalanceUpdateMinutes*60)
            $Count++
            if ($Pool_Currency -eq "SKY") {$Pool_Currency = "SKYDOGE"}
            if (-not $Request.address) {
                Write-Log -Level Info "Pool Balance API ($Name) for $($Pool_Currency) returned nothing. "
            } else {
                $Divisor = [Math]::Pow(10,$Pools_Request.tbs.$Pool_Name.info.div2)
                [PSCustomObject]@{
                    Caption     = "$($Name) ($($Pool_Currency))"
				    BaseName    = $Name
                    Name        = $Name
                    Currency    = $Pool_Currency
                    Balance     = [Decimal]$Request.balance / $Divisor
                    Pending     = [Decimal]$Request.unsold / $Divisor
                    Total       = [Decimal]$Request.unpaid / $Divisor
                    Paid        = [Decimal]$Request.total / $Divisor
                    Payouts     = @()
                    LastUpdated = (Get-Date).ToUniversalTime()
                }
            }
        }
        catch {
            Write-Log -Level Verbose "Pool Balance API ($Name) for $($_.Name) has failed. "
        }
    }
}
